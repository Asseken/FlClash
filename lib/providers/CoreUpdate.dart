/// 平台无关的 Core 版本更新检查。
///
/// Android / Windows / macOS / Linux 共用，
/// 具体下载/替换逻辑分别在 [AndroidCoreUpdate] 和 [DesktopCoreUpdate] 中实现。

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/CoreUpdate.g.dart';

/// 单个 GitHub Release 的简要信息，用于版本列表展示
class CoreReleaseItem {
  final String tagName;
  final String body;
  final DateTime? publishedAt;

  const CoreReleaseItem({
    required this.tagName,
    required this.body,
    this.publishedAt,
  });

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

  /// 最新的可用版本 tag_name（可能和当前版本相同）
  String? get latestTagName =>
      releases.isNotEmpty ? releases.first.tagName : null;

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
      // 1) 从已缓存的 coreVersionInfoData 获取当前运行的 core 版本
      //    （coreVersionInfoData 由 initCore 在启动时填充）
      final info = ref.read(coreVersionInfoDataProvider);
      final currentVersion = (info?.coreVersion ?? '').replaceAll(
        RegExp(r'^[vV]'),
        '',
      );

      // 2) 获取所有 releases
      final rawList = await request.listCoreReleases();
      if (rawList == null) {
        state = state.copyWith(currentVersion: currentVersion);
        return;
      }

      // 3) 转换为 CoreReleaseItem 列表，按版本号降序
      final releases =
          rawList
              .map(
                (r) => CoreReleaseItem(
                  tagName: r['tag_name'] as String? ?? '',
                  body: r['body'] as String? ?? '',
                  publishedAt: r['published_at'] != null
                      ? DateTime.tryParse(r['published_at'] as String)
                      : null,
                ),
              )
              .where((item) => item.tagName.isNotEmpty)
              .toList()
            ..sort((a, b) => utils.compareVersions(b.version, a.version));

      // 4) 找出所有比当前版本新的 releases
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
        hasUpdate: newerReleases.isNotEmpty,
      );
    } catch (e) {
      // 静默处理：网络错误等不影响正常使用
      commonPrint.log(
        'CoreUpdate.check failed: $e',
        logLevel: LogLevel.warning,
      );
    }
  }
}
