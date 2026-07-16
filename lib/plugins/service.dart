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

  /// 获取设备运行时 ABI（如 arm64-v8a），用于匹配核心下载包
  Future<String> getRuntimeAbi() async {
    return await methodChannel.invokeMethod<String>('getRuntimeAbi') ?? '';
  }

  /// 获取 Android 上最终会被替换的 libclash.so 目标路径
  Future<String> getCoreFilePath() async {
    return await methodChannel.invokeMethod<String>('getCoreFilePath') ?? '';
  }

  /// 通知 Native 层将已下载的临时 .so 文件替换到正确位置并写标记
  Future<bool> replaceCoreFile(String localPath) async {
    final result = await methodChannel.invokeMethod<bool>(
      'replaceCoreFile',
      localPath,
    );
    return result ?? false;
  }

  /// 将已下载的 .so 保存为版本化文件名（如 libclashn1928.so）
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

  /// 删除 Android 核心备份文件 libclash.so.bak
  Future<bool> deleteCoreBackup() async {
    final result = await methodChannel.invokeMethod<bool>(
      'deleteCoreBackup',
    );
    return result ?? false;
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
}

Service? get service => system.isAndroid ? Service() : null;
