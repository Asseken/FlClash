import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract mixin class ServiceListener {
  void onServiceEvent(CoreEvent event) {}

  void onServiceCrash(String message) {}
}

class Service {
  static Service? _instance;
  late MethodChannel methodChannel;
  ReceivePort? receiver;

  final ObserverList<ServiceListener> _listeners =
      ObserverList<ServiceListener>();

  factory Service() {
    _instance ??= Service._internal();
    return _instance!;
  }

  Service._internal() {
    methodChannel = const MethodChannel('$packageName/service');
    methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'event':
          final data = call.arguments as String? ?? '';
          final result = ActionResult.fromJson(json.decode(data));
          for (final listener in _listeners) {
            listener.onServiceEvent(CoreEvent.fromJson(result.data));
          }
          break;
        case 'crash':
          final message = call.arguments as String? ?? '';
          for (final listener in _listeners) {
            listener.onServiceCrash(message);
          }
          break;
        default:
          throw MissingPluginException();
      }
    });
  }

  Future<ActionResult?> invokeAction(Action action) async {
    final data = await methodChannel.invokeMethod<String>(
      'invokeAction',
      json.encode(action),
    );
    if (data == null) {
      return null;
    }
    final dataJson = await data.commonToJSON<dynamic>();
    return ActionResult.fromJson(dataJson);
  }

  Future<bool> start() async {
    return await methodChannel.invokeMethod<bool>('start') ?? false;
  }

  Future<bool> stop() async {
    return await methodChannel.invokeMethod<bool>('stop') ?? false;
  }

  Future<String> init() async {
    return await methodChannel.invokeMethod<String>('init') ?? '';
  }

  Future<String> syncState(SharedState state) async {
    return await methodChannel.invokeMethod<String>(
          'syncState',
          json.encode(state),
        ) ??
        '';
  }

  Future<bool> shutdown() async {
    return await methodChannel.invokeMethod<bool>('shutdown') ?? true;
  }

  Future<DateTime?> getRunTime() async {
    final ms = await methodChannel.invokeMethod<int>('getRunTime') ?? 0;
    if (ms == 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void addListener(ServiceListener listener) {
    _listeners.add(listener);
  }

  void removeListener(ServiceListener listener) {
    _listeners.remove(listener);
  }

  // 获取设备运行时 ABI（如 arm64-v8a），用于匹配核心下载包
  Future<String> getRuntimeAbi() async {
    return await methodChannel.invokeMethod<String>('getRuntimeAbi') ?? '';
  }

  // 将已下载的 .so 保存为零填充版本化文件名（如 libclashn011930.so）
  // 写入同时清理旧版本化 .so 文件
  Future<bool> replaceCoreVersionedFile(
    String tmpPath,
    String targetName,
  ) async {
    final result = await methodChannel.invokeMethod<bool>(
      'replaceCoreVersionedFile',
      {'tmpPath': tmpPath, 'targetName': targetName},
    );
    return result ?? false;
  }
}

Service? get service => system.isAndroid ? Service() : null;
