package com.follow.clash.core
import android.content.Context
import android.util.Log
import java.io.File
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.URI

object Core {
    @Volatile
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
                    uid: Int,
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
            dns,
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
     *
     * 提取与加载在后台线程执行，避免首次启动阻塞主线程；
     * 首次 JNI 调用通过 [ensureLoaded] 等待初始化完成。
     */
    fun initialize(context: Context) {
        synchronized(initLock) {
            if (loaded) return
            if (initStarted && !initDone) return
            initStarted = true
            initDone = false
        }
        Thread {
            try {
                doInitialize(context)
            } catch (e: Throwable) {
                initError = e
                Log.e(TAG, "Core initialization failed", e)
            } finally {
                synchronized(initLock) {
                    initDone = true
                    initLock.notifyAll()
                }
            }
        }.apply { isDaemon = true }.start()
    }

    private fun doInitialize(context: Context) {
        synchronized(this) {
            if (loaded) return
            val libDir = CoreUpdater.ensureSoFiles(context)
            val libCorePath = File(libDir, "libcore.so").absolutePath

            // Determine which libclash to load:
            // 1) Versioned file libclashn*.so (from previous update)
            // 2) Default libclash.so (bundled / fallback)
            var clashTarget: String = CoreUpdater.findVersionedClash(libDir)
                ?: "libclash.so"
            var libClashPath = File(libDir, clashTarget).absolutePath

            Log.d(TAG, "Loading clash library: $libClashPath")
            System.load(libCorePath)
            var ok = nativeInitClash(libClashPath)
            if (!ok && clashTarget != "libclash.so") {
                // A corrupted or incompatible versioned core must not block
                // startup: remove it and fall back to the bundled library.
                Log.w(TAG, "Failed to load versioned core $clashTarget, falling back to bundled libclash.so")
                CoreUpdater.deleteVersionedCore(libDir, clashTarget)
                clashTarget = "libclash.so"
                libClashPath = File(libDir, clashTarget).absolutePath
                ok = nativeInitClash(libClashPath)
            }
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
            synchronized(initLock) {
                val deadline = System.currentTimeMillis() + INIT_TIMEOUT_MS
                while (!loaded && !initDone) {
                    val remaining = deadline - System.currentTimeMillis()
                    if (remaining <= 0) break
                    initLock.wait(remaining)
                }
            }
        }
        if (!loaded) {
            throw IllegalStateException("Core not initialized", initError)
        }
    }

    private val initLock = Object()
    private var initStarted = false
    private var initDone = false
    private var initError: Throwable? = null

    private const val INIT_TIMEOUT_MS = 15_000L

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
        if (cb != null) {
            setEventListener(
                object : InvokeInterface {
                    override fun onResult(result: String?) {
                        cb(result)
                    }
                },
            )
        } else {
            setEventListener(null)
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
        val url = URI("https://$address")
        return InetSocketAddress(InetAddress.getByName(url.host), url.port)
    }
}

