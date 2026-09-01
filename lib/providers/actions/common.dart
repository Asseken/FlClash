part of '../action.dart';

@Riverpod(keepAlive: true)
class CommonAction extends _$CommonAction {
  @override
  void build() {}

  void toggleRunning() {
    final running = !ref.read(isStartProvider);
    ref
        .read(setupActionProvider.notifier)
        .setRunning(running, initialize: running && !ref.read(initProvider));
  }

  void updateSpeedStatistics() {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(showTrayTitle: !state.showTrayTitle));
  }

  void updateMode() {
    ref.read(patchClashConfigProvider.notifier).update((state) {
      final index = Mode.values.indexWhere((item) => item == state.mode);
      if (index == -1) return state;
      final nextIndex = index + 1 > Mode.values.length - 1 ? 0 : index + 1;
      return state.copyWith(mode: Mode.values[nextIndex]);
    });
  }

  Future<void> updateTraffic() async {
    if (!ref.read(isStartProvider)) return;
    final onlyStatisticsProxy = ref.read(
      appSettingProvider.select((state) => state.onlyStatisticsProxy),
    );
    try {
      final traffic = await coreController.getTraffic(onlyStatisticsProxy);
      final total = await coreController.getTotalTraffic(onlyStatisticsProxy);
      final direct = await coreController.getDirectTraffic();
      final directTotal = await coreController.getDirectTotalTraffic();
      // 停止竞态守卫:取数期间用户关闭代理时,丢弃整批结果,
      // 避免旧值在 _stop 清零之后被写回
      if (!ref.read(isStartProvider)) return;
      ref.read(trafficsProvider.notifier).addTraffic(traffic);
      ref.read(totalTrafficProvider.notifier).value = total;
      ref.read(directTrafficProvider.notifier).addTraffic(direct);
      ref.read(totalDirectTrafficProviderProvider.notifier).value = directTotal;
    } catch (error) {
      commonPrint.log(
        'updateTraffic error: $error',
        logLevel: coreFailureLogLevel(error),
      );
    }
  }

  Future<void> autoCheckUpdate() async {
    if (!ref.read(appSettingProvider).autoCheckUpdate) return;
    final res = await request.checkForUpdate();
    checkUpdateResultHandle(data: res);
  }

  Future<void> checkUpdateResultHandle({
    Map<String, dynamic>? data,
    bool isUser = false,
  }) async {
    if (data != null) {
      final tagName = data['tag_name'];
      final body = data['body'];
      final submits = utils.parseReleaseBody(body);
      final context = globalState.navigatorKey.currentContext!;
      final textTheme = context.textTheme;
      final res = await globalState.showMessage(
        title: currentAppLocalizations.discoverNewVersion,
        message: TextSpan(
          text: '$tagName \n',
          style: textTheme.headlineSmall,
          children: [
            TextSpan(text: '\n', style: textTheme.bodyMedium),
            for (final submit in submits)
              TextSpan(text: '- $submit \n', style: textTheme.bodyMedium),
          ],
        ),
        confirmText: currentAppLocalizations.goDownload,
        cancelText: isUser ? null : currentAppLocalizations.noLongerRemind,
      );
      if (res == true) {
        launchUrl(Uri.parse('https://github.com/$repository/releases/latest'));
      } else if (!isUser && res == false) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(autoCheckUpdate: false));
      }
    } else if (isUser) {
      globalState.showMessage(
        title: currentAppLocalizations.checkUpdate,
        message: TextSpan(text: currentAppLocalizations.checkUpdateError),
      );
    }
  }
}
