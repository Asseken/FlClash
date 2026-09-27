import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/core_update.g.dart';

// Pre-release tags would make the version comparison below meaningless.
final _stableTagPattern = RegExp(r'^[vV]?\d+(\.\d+)+$');

class CoreRelease {
  final String tagName;
  final String body;

  const CoreRelease({required this.tagName, this.body = ''});

  String get version => tagName.replaceAll(RegExp(r'^[vV]'), '');
}

class CoreUpdateData {
  final List<CoreRelease> releases;
  final List<CoreRelease> newerReleases;
  final String currentVersion;
  final bool hasUpdate;

  const CoreUpdateData({
    this.releases = const [],
    this.newerReleases = const [],
    this.currentVersion = '',
    this.hasUpdate = false,
  });

  CoreRelease? get latest => releases.isEmpty ? null : releases.first;
}

@Riverpod(keepAlive: true)
class CoreUpdate extends _$CoreUpdate {
  @override
  CoreUpdateData build() {
    return const CoreUpdateData();
  }

  Future<void> check() async {
    if (!system.isAndroid && !system.isDesktop) {
      return;
    }
    final rawReleases = await request.listCoreReleases();
    final releases = parseReleases(rawReleases);
    _apply(releases.isEmpty ? state.releases : releases, _runningVersion);
  }

  // A Core that was just replaced must stop advertising itself as an update.
  void refreshCurrentVersion() {
    _apply(state.releases, _runningVersion);
  }

  String get _runningVersion =>
      (ref.read(coreVersionInfoDataProvider)?.coreVersion ?? '').replaceAll(
        RegExp(r'^[vV]'),
        '',
      );

  void _apply(List<CoreRelease> releases, String currentVersion) {
    state = resolve(releases, currentVersion);
  }

  @visibleForTesting
  static List<CoreRelease> parseReleases(List<Map<String, dynamic>>? raw) {
    if (raw == null) {
      return const [];
    }
    final releases =
        raw
            .map(
              (item) => CoreRelease(
                tagName: item['tag_name'] as String? ?? '',
                body: item['body'] as String? ?? '',
              ),
            )
            .where(
              (release) =>
                  release.tagName.isNotEmpty &&
                  _stableTagPattern.hasMatch(release.tagName),
            )
            .toList()
          ..sort((a, b) => compareVersions(b.version, a.version));
    return releases;
  }

  @visibleForTesting
  static CoreUpdateData resolve(
    List<CoreRelease> releases,
    String currentVersion,
  ) {
    final newerReleases = currentVersion.isEmpty
        ? releases
        : releases
              .where(
                (release) =>
                    compareVersions(release.version, currentVersion) > 0,
              )
              .toList();
    return CoreUpdateData(
      releases: releases,
      newerReleases: newerReleases,
      currentVersion: currentVersion,
      hasUpdate: currentVersion.isNotEmpty && newerReleases.isNotEmpty,
    );
  }
}
