package com.follow.clash.core

import android.content.Context
import android.util.Log
import java.io.File
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.URL

data object Core {
    private var loaded = false

    private const val TAG = "Core"


    private var _manualClashPath: String? = null

    /** Set by ServicePlugin when Flutter passes a specific version tag */
    fun setManualClashPath(path: String) {
        _manualClashPath = path
    }

    fun clearManualClashPath() {
        _manualClashPath = null
    }

    // JNI: dlopen + dlsym the specified libclash*.so
    private external fun nativeInitClash(libPath: String): Boolean

    private external fun startTun(
        fd: Int,
        cb: TunInterface,
        stack: String,
        address: String,
        dns: String,
    )

    fun startTun(
        fd: Int,
        protect: (Int) -> Boolean,
        resolverProcess: (protocol: Int, source: InetSocketAddress, target: InetSocketAddress, uid: Int) -> String,
        stack: String,
        address: String,
        dns: String,
    ) {
        ensureLoaded()
        startTun(
            fd,
            object : TunInterface {
                override fun protect(fd: Int) {
                    protect(fd)
                }

                override fun resolverProcess(
                    protocol: Int,
                    source: String,
                    target: String,
                    uid: Int
                ): String {
                    return resolverProcess(
                        protocol,
                        parseInetSocketAddress(source),
                        parseInetSocketAddress(target),
                        uid,
                    )
                }
            },
            stack,
            address,
            dns
        )
    }

    /**
     * 初始化核�?.so 加载�?
     * 1) 确保 [filesDir/libs/] 下存�?libcore.so + libclash.so（首次从 APK 提取�?
     * 2) 通过 System.load 从同一目录加载,链接器解析DT_NEEDED时找到已加载的libclash，保证后续替�?libclash.so 后重启进程即可生�?
     */
    fun initialize(context: Context) {
        if (loaded) return
        synchronized(this) {
            if (loaded) return
            val libDir = CoreUpdater.ensureSoFiles(context)
            val libCorePath = File(libDir, "libcore.so").absolutePath

            // Determine which libclash to load:
            // 1) Manual path set via setManualClashPath (from Flutter update)
            // 2) Versioned file libclashn*.so (from previous update)
            // 3) Default libclash.so (bundled / replaced by replaceCoreFile)
            val clashTarget: String = _manualClashPath?.takeIf { it.isNotEmpty() }
                ?: CoreUpdater.findVersionedClash(libDir)
                ?: "libclash.so"
            val libClashPath = File(libDir, clashTarget).absolutePath

            Log.d(TAG, "Loading clash library: $libClashPath")
            System.load(libCorePath)
            val ok = nativeInitClash(libClashPath)
            if (!ok) {
                throw RuntimeException("nativeInitClash failed: $libClashPath")
            }
            Log.d(TAG, "libcore.so loaded successfully")
            Log.d(TAG, "nativeInitClash completed for $clashTarget")
            loaded = true

            _manualClashPath = null
    }

    }
    /** 确保 .so 已加载，否则�?IllegalStateException。所�?JNI 入口前调用�?*/
    private fun ensureLoaded() {
        if (!loaded) {
            throw IllegalStateException(
                "Core not initialized \u2014 call Core.initialize(context) first"
            )
        }
    }

    // 以下 external fun 保持原签名，通过携带守卫的公开方法暴露

    external fun forceGC()

    fun callForceGC() {
        ensureLoaded()
        forceGC()
    }

    external fun updateDNS(dns: String)

    fun callUpdateDNS(dns: String) {
        ensureLoaded()
        updateDNS(dns)
    }

    external fun suspended(suspended: Boolean)

    fun callSuspended(suspended: Boolean) {
        ensureLoaded()
        suspended(suspended)
    }

    external fun stopTun()

    fun callStopTun() {
        ensureLoaded()
        stopTun()
    }

    // invokeAction

    private external fun invokeAction(
        data: String,
        cb: InvokeInterface
    )

    fun invokeAction(
        data: String,
        cb: (result: String?) -> Unit
    ) {
        ensureLoaded()
        invokeAction(
            data,
            object : InvokeInterface {
                override fun onResult(result: String?) {
                    cb(result)
                }
            },
        )
    }

    // setEventListener

    private external fun setEventListener(cb: InvokeInterface?)

    fun callSetEventListener(
        cb: ((result: String?) -> Unit)?
    ) {
        ensureLoaded()
        when (cb != null) {
            true -> setEventListener(
                object : InvokeInterface {
                    override fun onResult(result: String?) {
                        cb(result)
                    }
                },
            )

            false -> setEventListener(null)
        }
    }

    // quickSetup

    private external fun quickSetup(
        initParamsString: String,
        setupParamsString: String,
        cb: InvokeInterface
    )

    fun quickSetup(
        initParamsString: String,
        setupParamsString: String,
        cb: (result: String?) -> Unit,
    ) {
        ensureLoaded()
        quickSetup(
            initParamsString,
            setupParamsString,
            object : InvokeInterface {
                override fun onResult(result: String?) {
                    cb(result)
                }
            },
        )
    }

    // traffic / memory 等获取函�?

    external fun getTraffic(onlyStatisticsProxy: Boolean): String

    fun callGetTraffic(onlyStatisticsProxy: Boolean): String {
        ensureLoaded()
        return getTraffic(onlyStatisticsProxy)
    }

    external fun getTotalTraffic(onlyStatisticsProxy: Boolean): String

    fun callGetTotalTraffic(onlyStatisticsProxy: Boolean): String {
        ensureLoaded()
        return getTotalTraffic(onlyStatisticsProxy)
    }

    external fun getDirectTraffic(): String

    fun callGetDirectTraffic(): String {
        ensureLoaded()
        return getDirectTraffic()
    }

    external fun getDirectTotalTraffic(): String

    fun callGetDirectTotalTraffic(): String {
        ensureLoaded()
        return getDirectTotalTraffic()
    }

    // 辅助方法

    private fun parseInetSocketAddress(address: String): InetSocketAddress {
        val url = URL("https://$address")
        return InetSocketAddress(InetAddress.getByName(url.host), url.port)
    }
}
