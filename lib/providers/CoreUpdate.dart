/// 平台无关的 Core 版本更新检查。
///
/// Android / Windows / macOS / Linux 共用，
/// 具体下载/替换逻辑分别在 [AndroidCoreUpdate] 和 [DesktopCoreUpdate] 中实现。

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/CoreUpdate.g.dart';

/// 稳定版本 tag 模式：可选 v/V 前缀 + 数字点分段（如 v1.19.31）。
/// pre-release 后缀（-beta 等）会被过滤，避免版本比较时解析失败。
final _stableTagPattern = RegExp(r'^[vV]?\d+(\.\d+)+$');

/// 单个 GitHub Release 的简要信息，用于版本列表展示
class CoreReleaseItem {
  final String tagName;
  final String body;

  const CoreReleaseItem({required this.tagName, required this.body});

  /// 从 tag_name 提取纯净版本号（去掉 v/V 前缀）
  String get version => tagName.replaceAll(RegExp(r'^[vV]'), '');
}

/// Core 更新检查结果
class CoreUpdateData {
  /// 所有获取到的 release（按版本号降序）
  final List<CoreReleaseItem> releases;

  /// 比当前版本更新的 release（按版本号降序，第一个是最新）
  final List<CoreReleaseItem> newerReleases;

  /// 当前运行的 core 版本号（去除 v 前缀）
  final String currentVersion;

  /// 是否有新版本可用
  final bool hasUpdate;

  const CoreUpdateData({
    this.releases = const [],
    this.newerReleases = const [],
    this.currentVersion = '',
    this.hasUpdate = false,
  });

  CoreUpdateData copyWith({
    List<CoreReleaseItem>? releases,
    List<CoreReleaseItem>? newerReleases,
    String? currentVersion,
    bool? hasUpdate,
  }) {
    return CoreUpdateData(
      releases: releases ?? this.releases,
      newerReleases: newerReleases ?? this.newerReleases,
      currentVersion: currentVersion ?? this.currentVersion,
      hasUpdate: hasUpdate ?? this.hasUpdate,
    );
  }
}

/// Core 更新检查 Provider。
///
/// 在应用启动时由 [_initApp] 调用 [check] 方法后台检查，
/// 如果发现新版本，[ShowCoreInfo] 会显示红点徽标。
@Riverpod(keepAlive: true)
class CoreUpdate extends _$CoreUpdate {
  @override
  CoreUpdateData build() {
    return const CoreUpdateData();
  }

  /// 后台检查更新。
  /// 不阻塞启动流程，静默处理错误。
  Future<void> check() async {
    if (!system.isAndroid && !system.isDesktop) return;

    try {
      final rawList = await request.listCoreReleases();
      if (rawList == null) {
        state = state.copyWith(currentVersion: _coreVersion);
        return;
      }

      // 只保留纯数字版本号 tag（如 v1.19.31），
      // 避免 pre-release 后缀（如 v1.19.31-beta）在版本比较时抛异常。
      final releases =
          rawList
              .map(
                (r) => CoreReleaseItem(
                  tagName: r['tag_name'] as String? ?? '',
                  body: r['body'] as String? ?? '',
                ),
              )
              .where(
                (item) =>
                    item.tagName.isNotEmpty &&
                    _stableTagPattern.hasMatch(item.tagName),
              )
              .toList()
            ..sort((a, b) => utils.compareVersions(b.version, a.version));

      _apply(releases, _coreVersion);
    } catch (e) {
      commonPrint.log(
        'CoreUpdate.check failed: $e',
        logLevel: LogLevel.warning,
      );
    }
  }

  /// core 更新完成后重算更新状态（不请求网络）。
  /// 运行版本已由 startCore 重新获取，基于缓存的 release 列表重算红点。
  void refreshCurrentVersion() {
    _apply(state.releases, _coreVersion);
  }

  String get _coreVersion =>
      (ref.read(coreVersionInfoDataProvider)?.coreVersion ?? '').replaceAll(
        RegExp(r'^[vV]'),
        '',
      );

  void _apply(List<CoreReleaseItem> releases, String currentVersion) {
    final newerReleases = currentVersion.isEmpty
        ? releases
        : releases
              .where(
                (r) => utils.compareVersions(r.version, currentVersion) > 0,
              )
              .toList();
    state = CoreUpdateData(
      releases: releases,
      newerReleases: newerReleases,
      currentVersion: currentVersion,
      hasUpdate: currentVersion.isNotEmpty && newerReleases.isNotEmpty,
    );
  }
}
