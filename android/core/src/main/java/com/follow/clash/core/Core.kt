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
     * Initialise the core .so library.
     *
     * 1. Extract libcore.so + libclash.so from the APK into [filesDir/libs/]
     *    on first run (subsequent launches reuse the existing libclash).
     * 2. System.load(libcore.so), then dlopen/dlsym the correct
     *    libclash.so (versioned or fallback).
     *
     * After a core update the new versioned .so is discovered automatically
     * on the next cold start via [CoreUpdater.findVersionedClash].
     */
    fun initialize(context: Context) {
        if (loaded) return
        synchronized(this) {
            if (loaded) return
            val libDir = CoreUpdater.ensureSoFiles(context)
            val libCorePath = File(libDir, "libcore.so").absolutePath

            // Determine which libclash to load:
            // 1) Versioned file libclashn*.so (from previous update)
            // 2) Default libclash.so (bundled / fallback)
            val clashTarget: String = CoreUpdater.findVersionedClash(libDir)
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
        }

    }
    /** Ensure .so has been loaded via [initialize]. All public JNI-facing methods must call this first. */
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

    // traffic / memory 等获取函?

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
