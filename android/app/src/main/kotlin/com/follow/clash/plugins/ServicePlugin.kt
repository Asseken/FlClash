package com.follow.clash.plugins
import android.content.Context
import com.follow.clash.ServiceController
import com.follow.clash.ServiceState
import com.follow.clash.common.Components
import com.follow.clash.common.GlobalState
import com.follow.clash.core.Core
import com.follow.clash.core.CoreUpdater
import com.follow.clash.models.SharedState
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class ServicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private lateinit var scope: CoroutineScope
    private val gson = Gson()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        appContext = binding.applicationContext
        // 加载 core .so（提取 + System.load + dlopen 版本化 libclash）
        runCatching { Core.initialize(appContext) }
            .onFailure { error ->
                GlobalState.log("Core initialization failed: $error")
            }
        channel = MethodChannel(binding.binaryMessenger, "${Components.PACKAGE_NAME}/service")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
        ServiceController.setEventListener(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> initialize(result)
            "shutdown" -> shutdown(result)
            "invokeMethod" -> invokeMethod(call, result)
            "getRunTime" -> getRunTime(result)
            "syncState" -> syncState(call, result)
            "start" -> start(result)
            "stop" -> stop(result)
            "getRuntimeAbi" -> handleGetRuntimeAbi(result)
            "replaceCoreVersionedFile" -> {
                handleReplaceCoreVersionedFile(call, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun initialize(result: MethodChannel.Result) {
        ServiceController.setEventListener(::sendEvent)
            .onSuccess { result.success("") }
            .onFailure { error -> result.success(error.message.orEmpty()) }
    }

    private fun shutdown(result: MethodChannel.Result) {
        scope.launch {
            ServiceController.unbind()
            result.success(true)
        }
    }

    private fun invokeMethod(call: MethodCall, result: MethodChannel.Result) {
        val data = call.arguments as? String
        if (data == null) {
            result.error("INVALID_ARGUMENT", "Method call payload must be a string", null)
            return
        }
        scope.launch {
            ServiceController.invokeMethod(data) { response ->
                result.success(response)
            }.onFailure { error ->
                result.error("CORE_ERROR", error.message, null)
            }
        }
    }

    private fun getRunTime(result: MethodChannel.Result) {
        scope.launch {
            result.success(ServiceState.refresh())
        }
    }

    private fun syncState(call: MethodCall, result: MethodChannel.Result) {
        val data = call.arguments as? String
        val state = runCatching {
            gson.fromJson(data, SharedState::class.java)
        }.getOrNull()
        if (state == null) {
            result.success("Invalid shared state")
            return
        }
        scope.launch {
            ServiceState.syncSharedState(state)
            result.success("")
        }
    }

    private fun start(result: MethodChannel.Result) {
        ServiceState.requestStart()
        result.success(true)
    }

    private fun stop(result: MethodChannel.Result) {
        ServiceState.requestStop()
        result.success(true)
    }

    private fun sendEvent(value: String?) {
        scope.launch(Dispatchers.Main) {
            channel.invokeMethod("event", value)
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
        val targetName = args.get("targetName") as? String ?: run {
            result.error("INVALID_ARGS", "targetName required", null)
            return
        }
        // .so 拷贝是几十 MB 的 IO，放到后台线程，避免阻塞平台主线程
        scope.launch {
            val errMsg = withContext(Dispatchers.IO) {
                CoreUpdater.replaceCoreVersionedFile(appContext, tmpPath, targetName)
            }
            if (errMsg == null) {
                result.success(true)
            } else {
                result.error("REPLACE_FAILED", errMsg, null)
            }
        }
    }
}
