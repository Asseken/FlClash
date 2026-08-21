package com.follow.clash.core

import android.content.Context
import android.os.Build
import android.util.Log
import java.io.File

/**
 * 核心 .so 文件管理工具。
 *
 * 职责：
 * 1) 首次使用时从 APK native lib 目录提取 libcore.so + libclash.so 到 [filesDir/libs/]
 * 2) 获取设备运行时 ABI
 */
object CoreUpdater {

    private const val TAG = "CoreUpdater"
    private const val LIBS_DIR = "libs"
    /** 记录保存版本化 core 时的 app versionCode,用于 APK 升级后清理旧版本化 core */
    private const val VERSION_SIDECAR = "core_update_version.txt"

    /** SO 文件名：CMake 编译的 JNI 桥 */
    private const val CORE_SO = "libcore.so"
    /** SO 文件名：Go CGO 编译的核心 */
    private const val CLASH_SO = "libclash.so"

    /** 版本化 core 文件名模式（libclashn + 数字 + .so），拒绝路径分隔符等非法输入 */
    private val VERSIONED_CORE_FILE = Regex("^libclashn\\d+\\.so$")

    /**
     * 确保 [filesDir/libs/] 下存在两个 .so 文件。
     * 首次调用会从 APK 的 nativeLibDir 拷贝到目标目录。
     * @return 包含两个 .so 文件的目录 [File]
    */
    fun ensureSoFiles(context: Context): File {
        val libDir = File(context.filesDir, LIBS_DIR)
        if (!libDir.exists()) libDir.mkdirs()

        // APK 升级后打包的 libclash.so 才是新基线：清除手动下载的版本化 core 和旧提取副本
        if (appVersionChanged(context, libDir)) {
            clearDownloadedCores(libDir)
        }

        // libcore.so（JNI 桥）每次都从 APK 提取，因为编译版本决定 JNI 函数签名
        extractSo(context, libDir, CORE_SO, overwrite = true)
        // libclash.so（Go 核心）只在首次缺失时提取，保留手动替换的版本化文件
        extractSo(context, libDir, CLASH_SO, overwrite = false)
        writeVersionSidecar(context, libDir)
        return libDir
    }

    /**
     * 侧车文件记录的 versionCode 与当前不一致 = APK 已升级。
     * 侧车文件不存在（首次安装/旧版本迁移）时不做清理，但会立即写入当前版本。
     */
    private fun appVersionChanged(context: Context, libDir: File): Boolean {
        val sidecar = File(libDir, VERSION_SIDECAR)
        if (!sidecar.exists()) return false
        return sidecar.readText().trim() != currentVersionCode(context).toString()
    }

    /**
     * 删除所有下载的 core（版本化文件 + 提取的 libclash.so 副本）。
     * 删除后 extractIfMissing 会从新 APK 重新提取打包版本。
     */
    private fun clearDownloadedCores(libDir: File) {
        val targets = libDir.listFiles { f ->
            f.isFile && (f.name.startsWith("libclashn") || f.name == CLASH_SO)
        } ?: return
        for (target in targets) {
            if (target.delete()) {
                Log.d(TAG, "Cleared core after app update: ${target.name}")
            } else {
                Log.w(TAG, "Failed to delete core after app update: ${target.name}")
            }
        }
        File(libDir, VERSION_SIDECAR).delete()
    }

    private fun writeVersionSidecar(context: Context, libDir: File) {
        File(libDir, VERSION_SIDECAR).writeText(currentVersionCode(context).toString())
    }

    /**
     * 删除指定的版本化 core 文件（加载失败时回退用）。
     */
    fun deleteVersionedCore(libDir: File, fileName: String) {
        val target = File(libDir, fileName)
        if (target.delete()) {
            Log.d(TAG, "Deleted versioned core: $fileName")
        } else {
            Log.w(TAG, "Failed to delete versioned core: $fileName")
        }
    }

    @Suppress("DEPRECATION")
    private fun currentVersionCode(context: Context): Int {
        return context.packageManager.getPackageInfo(context.packageName, 0).versionCode
    }

    /**
     * 从 APK 提取 [fileName] 到 [targetDir]。
     * [overwrite] 为 true 时总是覆盖（libcore.so：JNI 函数签名随编译版本变化）；
     * 为 false 时仅在缺失时提取（libclash.so：保留手动下载的版本化 core）。
     */
    private fun extractSo(context: Context, targetDir: File, fileName: String, overwrite: Boolean) {
        val target = File(targetDir, fileName)
        if (!overwrite && target.exists()) return
        val nativeDir = File(context.applicationInfo.nativeLibraryDir)
        val src = File(nativeDir, fileName)
        if (src.exists()) {
            src.copyTo(target, overwrite = true)
            Log.d(TAG, "Extracted $fileName (${src.length()} bytes) to $targetDir")
        } else {
            Log.w(TAG, "Bundled $fileName not found at $src")
        }
    }

    /**
     * 返回设备的主 ABI（如 arm64-v8a）。
     * 用于匹配 Github Releases 中对应架构的下载包。
     */
    fun getPrimaryAbi(): String {
        return Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a"
    }

    /**
     * 在 libDir 中查找版本化核心库文件（libclashn*.so）。
     * 按版本号数值降序排序，返回最新的一个（不含路径）。
     * 如果没有找到，返回 null。
     *
     * 文件名格式（零填充双位版本段）：
     *   libclashn010928.so  = v1.9.28
     *   libclashn011928.so  = v1.19.28
     *   libclashn011930.so  = v1.19.30
     *   libclashn020001.so  = v2.0.1
     */
    fun findVersionedClash(libDir: File): String? {
        val files = libDir.listFiles { f ->
            f.isFile && f.name.startsWith("libclashn") && f.name.endsWith(".so")
        } ?: return null
        if (files.isEmpty()) return null

        // 一律按 2 位一组解析版本段，补前导零保证偶数位长度
        fun parseVersionSegments(name: String): List<Int>? {
            val core = name.removePrefix("libclashn").removeSuffix(".so")
            if (core.isEmpty() || !core.all { it.isDigit() }) return null

            val padded = if (core.length % 2 == 0) core else "0$core"
            val segments = padded.chunked(2).map { it.toInt() }

            return if (segments.size in 1..5 && segments.all { it in 0..99 }) segments else null
        }

        // 逐段数值比较
        val comparator = Comparator<File> { a, b ->
            val sa = parseVersionSegments(a.name) ?: return@Comparator 0
            val sb = parseVersionSegments(b.name) ?: return@Comparator 0
            val maxLen = maxOf(sa.size, sb.size)
            for (idx in 0 until maxLen) {
                val va = sa.getOrElse(idx) { 0 }
                val vb = sb.getOrElse(idx) { 0 }
                if (va != vb) return@Comparator va.compareTo(vb)
            }
            0
        }

        return files.sortedWith(comparator).last().name
    }

    /**
     * 将下载的临时 .so 保存为版本化文件名（零填充双位版本段）。
     * 文件写入完成后删除所有的旧版本化核心库（同一命名模式的其他文件）。
     *
     * 文件名格式：libclashn{MM}{mm}{pp}.so
     *   例：v1.19.30 → libclashn011930.so
     *
     * @param context         上下文
     * @param localPath       下载的临时文件路径
     * @param targetFileName  目标文件名（如 "libclashn011930.so"）
     * @return null = 成功，非 null = 错误信息
     */
    fun replaceCoreVersionedFile(context: Context, localPath: String, targetFileName: String): String? {
        return try {
            if (!VERSIONED_CORE_FILE.matches(targetFileName)) {
                return "Invalid target file name: $targetFileName"
            }
            val tmpFile = File(localPath)
            if (!tmpFile.exists()) return "File not found: $localPath"
            val fileLen = tmpFile.length()
            if (fileLen < 1024 * 1024) return "File too small: ${fileLen} bytes"

            val libDir = File(context.filesDir, LIBS_DIR)
            if (!libDir.exists()) libDir.mkdirs()
            val target = File(libDir, targetFileName)

            tmpFile.copyTo(target, overwrite = true)
            Log.d(TAG, "Saved versioned core: ${target.absolutePath} (${fileLen} bytes)")
            tmpFile.delete()

            // 记录当前 app versionCode，供下次启动判断 APK 是否升级
            writeVersionSidecar(context, libDir)

            // 清理旧版本化 .so，只保留最新写入的
            val oldFiles = libDir.listFiles { f ->
                f.isFile && f.name.startsWith("libclashn") && f.name.endsWith(".so") && f.name != targetFileName
            } ?: emptyArray()
            for (old in oldFiles) {
                if (old.delete()) {
                    Log.d(TAG, "Cleaned up old versioned core: ${old.name}")
                } else {
                    Log.w(TAG, "Failed to delete old versioned core: ${old.name}")
                }
            }

            null
        } catch (e: Exception) {
            Log.e(TAG, "replaceCoreVersionedFile failed", e)
            e.message ?: "Unknown error"
        }
    }

}
