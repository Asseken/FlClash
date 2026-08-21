part of '../action.dart';

@Riverpod(keepAlive: true)
class CoreAction extends _$CoreAction {
  int _requestedRestartRevision = 0;
  Future<void>? _restartOperation;

  @override
  void build() {}

  Future<void> initCore() async {
    final isInit = await coreController.isInit;

    final version = ref.read(versionProvider);
    if (!isInit) {
      final res = await coreController.init(version);
      commonPrint.log('init result: $res');
    } else {
      await ref.read(proxiesActionProvider.notifier).updateGroups();
    }
    final coreVersionInfoData = await coreController.getCoreVersion();
    if (coreVersionInfoData.isNotEmpty) {
      ref.read(coreVersionInfoDataProvider.notifier).value = coreVersionInfo
          .fromJson(coreVersionInfoData);
    }
  }

  /// 启动 core 并获取版本信息。
  /// 失败时内部已提示错误，返回 false 供调用方判断。
  Future<bool> startCore() async {
    ref.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
    try {
      await coreController.start();
      ref.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await initCore();
      return true;
    } catch (error) {
      ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
      globalState.showNotifier(error.toString());
      return false;
    }
  }

  @protected
  Future<CoreLifecycleResult> restartLifecycle() {
    return coreController.restart();
  }

  Future<void> restartCore() {
    _requestedRestartRevision++;
    final activeOperation = _restartOperation;
    if (activeOperation != null) {
      return activeOperation;
    }

    final operation = _runRestartWorker();
    _restartOperation = operation;
    return operation;
  }

  Future<void> _runRestartWorker() async {
    try {
      ref.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
      await restartLifecycle();
      ref.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await initCore();

      var appliedRevision = 0;
      while (appliedRevision < _requestedRestartRevision) {
        final revision = _requestedRestartRevision;
        if (ref.read(isStartProvider)) {
          await ref
              .read(setupActionProvider.notifier)
              .setRunning(true, initialize: true);
        } else {
          await ref
              .read(setupActionProvider.notifier)
              .applyProfile(force: true);
        }
        appliedRevision = revision;
      }
    } catch (_) {
      ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
      rethrow;
    } finally {
      _restartOperation = null;
    }
  }
}
