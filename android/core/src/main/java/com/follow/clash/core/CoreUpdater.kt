package com.follow.clash.core

import android.content.Context
import android.os.Build
import android.util.Log
import java.io.File

object CoreUpdater {
    private const val TAG = "CoreUpdater"
    private const val LIBS_DIR = "libs"
    private const val CORE_SO = "libclash.so"

    private const val VERSION_SIDECAR = "core_update_version.txt"
    private const val MIN_CORE_BYTES = 1024 * 1024

    private val VERSIONED_CORE_FILE = Regex("^libclashn\\d+\\.so$")

    // A Core downloaded before an app update was built against the previous JNI
    // signatures, so the baseline in the new APK has to win over it.
    fun libsDir(context: Context): File {
        val dir = File(context.filesDir, LIBS_DIR)
        if (!dir.exists() && !dir.mkdirs()) {
            Log.w(TAG, "Unable to create Core directory $dir")
        }
        if (appVersionChanged(context, dir)) {
            clearVersionedCores(dir)
        }
        writeVersionSidecar(context, dir)
        return dir
    }

    fun bundledCorePath(context: Context): String =
        File(context.applicationInfo.nativeLibraryDir, CORE_SO).absolutePath

    fun getPrimaryAbi(): String = Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a"

    // Segments, not the whole number: libclashn011930.so (v1.19.30) outranks
    // libclashn010928.so (v1.9.28).
    fun findVersionedCore(dir: File): String? {
        val files = dir.listFiles { file ->
            file.isFile && VERSIONED_CORE_FILE.matches(file.name)
        } ?: return null
        return files.maxWithOrNull { a, b ->
            compareSegments(versionSegments(a.name), versionSegments(b.name))
        }?.name
    }

    fun deleteVersionedCore(dir: File, fileName: String) {
        val target = File(dir, fileName)
        if (target.delete()) {
            Log.d(TAG, "Deleted versioned Core $fileName")
        } else {
            Log.w(TAG, "Unable to delete versioned Core $fileName")
        }
    }

    // Returns null on success, otherwise a message for the caller to surface.
    fun replaceCoreVersionedFile(
        context: Context,
        localPath: String,
        targetFileName: String,
    ): String? {
        if (!VERSIONED_CORE_FILE.matches(targetFileName)) {
            return "Invalid Core file name: $targetFileName"
        }
        val source = File(localPath)
        if (!source.isFile) {
            return "Downloaded Core not found: $localPath"
        }
        val size = source.length()
        if (size < MIN_CORE_BYTES) {
            return "Downloaded Core is too small: $size bytes"
        }
        return try {
            val dir = libsDir(context)
            val target = File(dir, targetFileName)
            source.copyTo(target, overwrite = true)
            source.delete()
            Log.d(TAG, "Saved versioned Core ${target.absolutePath} ($size bytes)")
            val previous = dir.listFiles { file ->
                file.isFile && VERSIONED_CORE_FILE.matches(file.name) &&
                    file.name != targetFileName
            } ?: emptyArray()
            for (old in previous) {
                deleteVersionedCore(dir, old.name)
            }
            null
        } catch (error: Exception) {
            Log.e(TAG, "Unable to save $targetFileName", error)
            error.message ?: "Unknown error"
        }
    }

    private fun versionSegments(fileName: String): List<Int>? {
        val version = fileName.removePrefix("libclashn").removeSuffix(".so")
        if (version.isEmpty() || !version.all { it.isDigit() }) {
            return null
        }
        val padded = if (version.length % 2 == 0) version else "0$version"
        val segments = padded.chunked(2).map { it.toInt() }
        return if (segments.size in 1..5 && segments.all { it in 0..99 }) segments else null
    }

    private fun compareSegments(a: List<Int>?, b: List<Int>?): Int {
        if (a == null || b == null) {
            return 0
        }
        for (index in 0 until maxOf(a.size, b.size)) {
            val difference = (a.getOrElse(index) { 0 }) - (b.getOrElse(index) { 0 })
            if (difference != 0) {
                return difference
            }
        }
        return 0
    }

    private fun appVersionChanged(context: Context, dir: File): Boolean {
        val sidecar = File(dir, VERSION_SIDECAR)
        if (!sidecar.isFile) {
            return false
        }
        return sidecar.readText().trim() != versionCode(context).toString()
    }

    private fun clearVersionedCores(dir: File) {
        val files = dir.listFiles { file ->
            file.isFile && VERSIONED_CORE_FILE.matches(file.name)
        } ?: return
        for (file in files) {
            deleteVersionedCore(dir, file.name)
        }
    }

    private fun writeVersionSidecar(context: Context, dir: File) {
        runCatching {
            File(dir, VERSION_SIDECAR).writeText(versionCode(context).toString())
        }.onFailure { error ->
            Log.w(TAG, "Unable to record the Core version marker: $error")
        }
    }

    @Suppress("DEPRECATION")
    private fun versionCode(context: Context): Long {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }
    }
}
