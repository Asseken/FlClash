package com.follow.clash.core

import android.content.Context
import android.util.Log
import java.io.File
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.URI
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

object Core {
    private const val TAG = "Core"
    private const val INIT_TIMEOUT_MS = 15_000L

    private val startLock = Any()

    @Volatile
    private var initLatch: CountDownLatch? = null

    @Volatile
    private var loaded = false

    @Volatile
    private var initError: Throwable? = null

    private external fun nativeInitClash(libPath: String): Boolean

    // Opening the Core starts a Go runtime, so it must not run on the caller's thread.
    fun initialize(context: Context) {
        val latch = synchronized(startLock) {
            if (loaded || initLatch != null) {
                return
            }
            CountDownLatch(1).also { initLatch = it }
        }
        Thread {
            try {
                loadCore(context.applicationContext)
            } catch (error: Throwable) {
                initError = error
                Log.e(TAG, "Unable to open the Core", error)
            } finally {
                latch.countDown()
            }
        }.apply { isDaemon = true }.start()
    }

    private fun loadCore(context: Context) {
        System.loadLibrary("core")
        val libDir = CoreUpdater.libsDir(context)
        val candidates = buildList {
            CoreUpdater.findVersionedCore(libDir)?.let { add(File(libDir, it)) }
            add(File(CoreUpdater.bundledCorePath(context)))
        }
        for (candidate in candidates) {
            if (!candidate.isFile) {
                Log.w(TAG, "No Core at ${candidate.absolutePath}")
                continue
            }
            Log.d(TAG, "Opening Core ${candidate.absolutePath}")
            if (nativeInitClash(candidate.absolutePath)) {
                loaded = true
                Log.d(TAG, "Core ready from ${candidate.name}")
                return
            }
            // A downloaded Core that will not open must not keep the app from starting.
            if (candidate.parentFile == libDir) {
                CoreUpdater.deleteVersionedCore(libDir, candidate.name)
            }
        }
        throw IllegalStateException("Unable to open any Core library")
    }

    private fun ensureLoaded() {
        if (!loaded) {
            initLatch?.await(INIT_TIMEOUT_MS, TimeUnit.MILLISECONDS)
        }
        if (!loaded) {
            throw IllegalStateException("Core is not initialized", initError)
        }
    }

    private external fun nativeStartTun(
        fd: Int,
        cb: TunInterface,
        stack: String,
        address: String,
        dns: String,
    ): Boolean

    private fun parseInetSocketAddress(address: String): InetSocketAddress {
        val uri = URI("tcp://$address")
        val host = requireNotNull(uri.host) { "Missing host in address: $address" }
        require(uri.port >= 0) { "Missing port in address: $address" }
        return InetSocketAddress(InetAddress.getByName(host), uri.port)
    }

    fun startTun(
        fd: Int,
        protect: (Int) -> Boolean,
        resolveUid: (protocol: Int, source: InetSocketAddress, target: InetSocketAddress) -> Int,
        resolvePackage: (uid: Int) -> String,
        stack: String,
        address: String,
        dns: String,
    ): Boolean {
        ensureLoaded()
        return nativeStartTun(
            fd,
            object : TunInterface {
                override fun protect(fd: Int): Boolean = protect(fd)

                override fun resolveUid(
                    protocol: Int,
                    source: String,
                    target: String,
                ): Int {
                    return resolveUid(
                        protocol,
                        parseInetSocketAddress(source),
                        parseInetSocketAddress(target),
                    )
                }

                override fun resolvePackage(uid: Int): String = resolvePackage(uid)
            },
            stack,
            address,
            dns,
        )
    }

    private external fun nativeSuspended(suspended: Boolean)

    fun suspended(suspended: Boolean) {
        ensureLoaded()
        nativeSuspended(suspended)
    }

    private external fun nativeInvokeMethod(
        data: String,
        cb: InvokeInterface,
    )

    fun invokeMethod(
        data: String,
        cb: (result: String?) -> Unit,
    ) {
        ensureLoaded()
        nativeInvokeMethod(
            data,
            object : InvokeInterface {
                override fun onResult(result: String?) {
                    cb(result)
                }
            },
        )
    }

    private external fun nativeSetEventListener(cb: InvokeInterface?)

    fun updateEventListener(
        callback: ((result: String?) -> Unit)?,
    ) {
        ensureLoaded()
        if (callback == null) {
            nativeSetEventListener(null)
        } else {
            nativeSetEventListener(
                object : InvokeInterface {
                    override fun onResult(result: String?) {
                        callback(result)
                    }
                },
            )
        }
    }

    private external fun nativeQuickSetup(
        initParamsString: String,
        setupParamsString: String,
        cb: InvokeInterface,
    )

    fun quickSetup(
        initParamsString: String,
        setupParamsString: String,
        callback: (result: String?) -> Unit,
    ) {
        ensureLoaded()
        nativeQuickSetup(
            initParamsString,
            setupParamsString,
            object : InvokeInterface {
                override fun onResult(result: String?) {
                    callback(result)
                }
            },
        )
    }

    private external fun nativeStopTun()

    fun stopTun() {
        ensureLoaded()
        nativeStopTun()
    }

    private external fun nativeForceGC()

    fun forceGC() {
        ensureLoaded()
        nativeForceGC()
    }

    private external fun nativeUpdateDNS(dns: String)

    fun updateDNS(dns: String) {
        ensureLoaded()
        nativeUpdateDNS(dns)
    }

    private external fun nativeGetTraffic(onlyStatisticsProxy: Boolean): String

    fun getTraffic(onlyStatisticsProxy: Boolean): String {
        ensureLoaded()
        return nativeGetTraffic(onlyStatisticsProxy)
    }

    private external fun nativeGetTotalTraffic(onlyStatisticsProxy: Boolean): String

    fun getTotalTraffic(onlyStatisticsProxy: Boolean): String {
        ensureLoaded()
        return nativeGetTotalTraffic(onlyStatisticsProxy)
    }

    private external fun nativeGetDirectTraffic(): String

    fun getDirectTraffic(): String {
        ensureLoaded()
        return nativeGetDirectTraffic()
    }

    private external fun nativeGetDirectTotalTraffic(): String

    fun getDirectTotalTraffic(): String {
        ensureLoaded()
        return nativeGetDirectTotalTraffic()
    }
}
