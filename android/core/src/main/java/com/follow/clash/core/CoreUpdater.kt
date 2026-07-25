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

    /** SO 文件名：CMake 编译的 JNI 桥 */
    private const val CORE_SO = "libcore.so"
    /** SO 文件名：Go CGO 编译的核心 */
    private const val CLASH_SO = "libclash.so"

    /**
     * 确保 [filesDir/libs/] 下存在两个 .so 文件。
     * 首次调用会从 APK 的 nativeLibDir 拷贝到目标目录。
     * @return 包含两个 .so 文件的目录 [File]
    */
    fun ensureSoFiles(context: Context): File {
        val libDir = File(context.filesDir, LIBS_DIR)
        if (!libDir.exists()) libDir.mkdirs()

        // 诊断：记录当前 .so 文件大小
        val existingClash = File(libDir, CLASH_SO)
        Log.d(TAG, "ensureSoFiles: libclash.so exists=${existingClash.exists()} size=${existingClash.length()} (skip if present)")

        // libcore.so（JNI 桥）每次都从 APK 提取，因为编译版本决定 JNI 函数签名
        extractBundledIfPresent(context, libDir, CORE_SO)
        // libclash.so（Go 核心）只在首次缺失时提取，保留手动替换的版本化文件
        extractIfMissing(context, libDir, CLASH_SO)

        // 提取后再次记录
        val afterClash = existingClash
        Log.d(TAG, "ensureSoFiles: after ensure libclash.so size=${afterClash.length()}")
        return libDir
    }

    /**
     * 如果 [fileName] 在 [targetDir] 中不存在，则从 APK native lib 目录提取。
     * 与旧版的「缺一补全」不同：每个 .so 独立检查，避免覆盖用户已下载的新版 libclash.so。
     */
    /**
     * 从 APK 提取 [fileName] 到 [targetDir]（总是覆盖，用于 libcore.so）。
     * 与 extractIfMissing 不同：总是提取，确保 JNI 函数签名匹配当前编译版本。
     */
    private fun extractBundledIfPresent(context: Context, targetDir: File, fileName: String) {
        val nativeDir = File(context.applicationInfo.nativeLibraryDir)
        val src = File(nativeDir, fileName)
        if (src.exists()) {
            src.copyTo(File(targetDir, fileName), overwrite = true)
            Log.d(TAG, "Extracted $fileName (${src.length()} bytes) to $targetDir (always)")
        } else {
            Log.w(TAG, "Bundled $fileName not found at $src")
        }
    }

    private fun extractIfMissing(context: Context, targetDir: File, fileName: String) {
        val target = File(targetDir, fileName)
        if (target.exists()) return
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
     * 文件名格式：libclashn{major}{minor}{patch}.so（无前导零），
     * 如 libclashn1928.so = v1.9.28。
     * 提取文件名中 "libclashn" 之后 ".so" 之前的部分，
     * 按字符拆分后做逐段数值比较，避免字符串排序陷阱
     * （"libclashn123.so" > "libclashn1100.so"）。
     */
    fun findVersionedClash(libDir: File): String? {
        val files = libDir.listFiles { f ->
            f.isFile && f.name.startsWith("libclashn") && f.name.endsWith(".so")
        } ?: return null
        if (files.isEmpty()) return null

        // 将文件名解析为 "数字列表" 用于逐段数值比较
        // libclashn1928.so → [1, 9, 28]；libclashn010203.so → [1, 2, 3]
        fun parseVersionSegments(name: String): List<Int>? {
            val core = name.removePrefix("libclashn").removeSuffix(".so")
            if (core.isEmpty()) return null
            // 按前导零规则分组：每个非零数字段为一个版本段
            val segments = mutableListOf<Int>()
            var i = 0
            while (i < core.length) {
                if (!core[i].isDigit()) return null
                // 找到这一段的末尾
                var j = i
                while (j < core.length && core[j].isDigit()) j++
                segments.add(core.substring(i, j).toInt())
                i = j
            }
            return if (segments.isEmpty()) null else segments
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
     * 将下载的临时 .so 保存为版本化文件名（如 libclashn1928.so）。
     * 文件写入完成后删除所有的旧版本化核心库（同一命名模式的其他文件）。
     *
     * @param context         上下文
     * @param localPath       下载的临时文件路径
     * @param targetFileName  目标文件名（如 "libclashn1928.so"）
     * @return null = 成功，非 null = 错误信息
     */
    fun replaceCoreVersionedFile(context: Context, localPath: String, targetFileName: String): String? {
        return try {
            val tmpFile = File(localPath)
            if (!tmpFile.exists()) return "File not found: $localPath"
            val fileLen = tmpFile.length()
            if (fileLen < 5 * 1024 * 1024) return "File too small: ${fileLen} bytes"

            val libDir = File(context.filesDir, LIBS_DIR)
            if (!libDir.exists()) libDir.mkdirs()
            val target = File(libDir, targetFileName)

            tmpFile.copyTo(target, overwrite = true)
            Log.d(TAG, "Saved versioned core: ${target.absolutePath} (${fileLen} bytes)")
            tmpFile.delete()

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
