package com.follow.clash.service

import android.app.Service
import android.content.Intent
import android.os.IBinder
import com.follow.clash.common.GlobalState
import com.follow.clash.common.ServiceDelegate
import com.follow.clash.common.chunkedForAidl
import com.follow.clash.common.intent
import com.follow.clash.core.Core
import com.follow.clash.service.State.delegate
import com.follow.clash.service.State.intent
import com.follow.clash.service.State.runLock
import com.follow.clash.service.models.NotificationParams
import com.follow.clash.service.models.VpnOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.withLock
import java.util.UUID
import kotlin.coroutines.resume

class RemoteService : Service(),
    CoroutineScope by CoroutineScope(SupervisorJob() + Dispatchers.Default) {

    /** Send a nullable result string chunked for AIDL through [block]. */
    private fun sendChunkedAidl(
        result: String?,
        block: (chunk: ByteArray, isLast: Boolean, ack: IAckInterface) -> Unit,
    ) {
        launch {
            runCatching {
                val chunks = result?.chunkedForAidl() ?: listOf()
                for ((index, chunk) in chunks.withIndex()) {
                    suspendCancellableCoroutine { cont ->
                        block(
                            chunk,
                            index == chunks.lastIndex,
                            object : IAckInterface.Stub() {
                                override fun onAck() { cont.resume(Unit) }
                            },
                        )
                    }
                }
            }
        }
    }

    private fun handleStopService(result: IResultInterface) {
        launch {
            runLock.withLock {
                delegate?.useService { service ->
                    service.stop()
                    delegate?.unbind()
                }
                State.runTime = 0
                result.onResult(0)
            }
        }
    }

    private fun handleServiceDisconnected(message: String) {
        GlobalState.log("Background service disconnected: $message")
        intent = null
        delegate = null
    }

    private fun handleStartService(runTime: Long, result: IResultInterface) {
        launch {
            runLock.withLock {
                val nextIntent = when (State.options?.enable == true) {
                    true -> VpnService::class.intent
                    false -> CommonService::class.intent
                }
                if (intent != nextIntent) {
                    delegate?.unbind()
                    delegate = ServiceDelegate(nextIntent, ::handleServiceDisconnected) { binder ->
                        when (binder) {
                            is VpnService.LocalBinder -> binder.getService()
                            is CommonService.LocalBinder -> binder.getService()
                            else -> throw IllegalArgumentException("Invalid binder type")
                        }
                    }
                    intent = nextIntent
                    delegate?.bind()
                }
                delegate?.useService { service ->
                    service.start()
                }
                State.runTime = when (runTime != 0L) {
                    true -> runTime
                    false -> System.currentTimeMillis()
                }
                result.onResult(State.runTime)
            }
        }
    }

    private val binder = object : IRemoteInterface.Stub() {
        override fun invokeAction(data: String, callback: ICallbackInterface) {
            Core.invokeAction(data) { sendChunkedAidl(it) { chunk, isLast, ack -> callback.onResult(chunk, isLast, ack) } }
        }

        override fun quickSetup(
            initParamsString: String,
            setupParamsString: String,
            callback: ICallbackInterface,
            onStarted: IVoidInterface
        ) {
            Core.quickSetup(initParamsString, setupParamsString) {
                sendChunkedAidl(it) { chunk, isLast, ack -> callback.onResult(chunk, isLast, ack) }
            }
            onStarted()
        }

        override fun updateNotificationParams(params: NotificationParams?) {
            State.notificationParamsFlow.tryEmit(params)
        }


        override fun startService(
            options: VpnOptions,
            runtime: Long,
            result: IResultInterface,
        ) {
            GlobalState.log("remote startService")
            State.options = options
            handleStartService(runtime, result)
        }

        override fun stopService(result: IResultInterface) {
            handleStopService(result)
        }

        override fun setEventListener(eventListener: IEventInterface?) {
            GlobalState.log("RemoveEventListener ${eventListener == null}")
            when (eventListener != null) {
                true -> Core.callSetEventListener {
                    sendChunkedAidl(it) { chunk, isLast, ack ->
                        val id = UUID.randomUUID().toString()
                        eventListener.onEvent(id, chunk, isLast, ack)
                    }
                }

                false -> Core.callSetEventListener(null)
            }
        }

        override fun setCrashlytics(enable: Boolean) {
            GlobalState.setCrashlytics(enable)
        }

        override fun getRunTime(): Long {
            return State.runTime
        }
    }
    override fun onCreate() {
        super.onCreate()
        Core.initialize(this)
    }
    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    override fun onDestroy() {
        GlobalState.log("Remote service destroy")
        super.onDestroy()
    }
}