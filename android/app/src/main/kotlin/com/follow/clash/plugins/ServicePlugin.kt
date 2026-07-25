package com.follow.clash.plugins

import android.content.Context
import java.io.File
import com.follow.clash.RunState
import com.follow.clash.Service
import com.follow.clash.State
import com.follow.clash.common.Components
import com.follow.clash.common.GlobalState
import com.follow.clash.core.CoreUpdater
import com.follow.clash.invokeMethodOnMainThread
import com.follow.clash.models.SharedState
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit

class ServicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    CoroutineScope by CoroutineScope(SupervisorJob() + Dispatchers.Default) {
    private lateinit var flutterMethodChannel: MethodChannel
    private lateinit var appContext: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
        flutterMethodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger, "${Components.PACKAGE_NAME}/service"
        )
        flutterMethodChannel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        flutterMethodChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) = when (call.method) {
        "init" -> handleInit(result)
        "shutdown" -> handleShutdown(result)
        "invokeAction" -> handleInvokeAction(call, result)
        "getRunTime" -> handleGetRunTime(result)
        "syncState" -> handleSyncState(call, result)
        "start" -> handleStart(result)
        "stop" -> handleStop(result)
        "getRuntimeAbi" -> handleGetRuntimeAbi(result)
        "replaceCoreVersionedFile" -> handleReplaceCoreVersionedFile(call, result)
        else -> result.notImplemented()
    }

    private fun handleInvokeAction(call: MethodCall, result: MethodChannel.Result) {
        launch {
            val data = call.arguments<String>()!!
            Service.invokeAction(data) {
                result.success(it)
            }
        }
    }

    private fun handleShutdown(result: MethodChannel.Result) {
        Service.unbind()
        result.success(true)
    }

    private fun handleStart(result: MethodChannel.Result) {
        State.handleStartService()
        result.success(true)
    }

    private fun handleStop(result: MethodChannel.Result) {
        State.handleStopService()
        result.success(true)
    }

    val semaphore = Semaphore(10)

    fun handleSendEvent(value: String?) {
        launch(Dispatchers.Main) {
            semaphore.withPermit {
                flutterMethodChannel.invokeMethod("event", value)
            }
        }
    }

    private fun onServiceDisconnected(message: String) {
        State.runStateFlow.tryEmit(RunState.STOP)
        flutterMethodChannel.invokeMethodOnMainThread<Any>("crash", message)
    }

    private fun handleSyncState(call: MethodCall, result: MethodChannel.Result) {
        val data = call.arguments<String>()!!
        State.sharedState = Gson().fromJson(data, SharedState::class.java)
        launch {
            State.syncState()
            result.success("")
        }
    }

    fun handleInit(result: MethodChannel.Result) {
        Service.bind()
        launch {
            val maxAttempts = 6  // 每次最多等 5s，总共最多 ~30s
            var lastError = ""
            for (i in 1..maxAttempts) {
                val eventResult = Service.setEventListener {
                    handleSendEvent(it)
                }
                eventResult.onSuccess {
                    result.success("")
                    return@launch
                }
                eventResult.onFailure { e ->
                    lastError = e.message ?: e.toString()
                }
                if (i < maxAttempts) {
                    kotlinx.coroutines.delay(1000)  // 每次失败后等 1s 再试
                }
            }
            result.success(lastError)
        }
        Service.onServiceDisconnected = ::onServiceDisconnected
    }

    private fun handleGetRunTime(result: MethodChannel.Result) {
        launch {
            State.handleSyncState()
            result.success(State.runTime)
        }
    }

    // 返回设备运行时 ABI，用于匹配 Github Releases 中的架构
    private fun handleGetRuntimeAbi(result: MethodChannel.Result) {
        result.success(CoreUpdater.getPrimaryAbi())
    }

    private fun handleReplaceCoreVersionedFile(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val tmpPath = args?.get("tmpPath") as? String ?: run {
            result.error("INVALID_ARGS", "tmpPath required", null)
            return
        }
        val targetName = args?.get("targetName") as? String ?: run {
            result.error("INVALID_ARGS", "targetName required", null)
            return
        }
        val errMsg = CoreUpdater.replaceCoreVersionedFile(appContext, tmpPath, targetName)
        if (errMsg == null) {
            result.success(true)
        } else {
            result.error("REPLACE_FAILED", errMsg, null)
        }
    }
}
