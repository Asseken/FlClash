// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../CoreUpdate.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Core 更新检查 Provider。
///
/// 在应用启动时由 [_initApp] 调用 [check] 方法后台检查，
/// 如果发现新版本，[ShowCoreInfo] 会显示红点徽标。

@ProviderFor(CoreUpdate)
final coreUpdateProvider = CoreUpdateProvider._();

/// Core 更新检查 Provider。
///
/// 在应用启动时由 [_initApp] 调用 [check] 方法后台检查，
/// 如果发现新版本，[ShowCoreInfo] 会显示红点徽标。
final class CoreUpdateProvider
    extends $NotifierProvider<CoreUpdate, CoreUpdateData> {
  /// Core 更新检查 Provider。
  ///
  /// 在应用启动时由 [_initApp] 调用 [check] 方法后台检查，
  /// 如果发现新版本，[ShowCoreInfo] 会显示红点徽标。
  CoreUpdateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coreUpdateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coreUpdateHash();

  @$internal
  @override
  CoreUpdate create() => CoreUpdate();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoreUpdateData value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoreUpdateData>(value),
    );
  }
}

String _$coreUpdateHash() => r'39d221f1f7085bc9046b05fab7e6f083148f0766';

/// Core 更新检查 Provider。
///
/// 在应用启动时由 [_initApp] 调用 [check] 方法后台检查，
/// 如果发现新版本，[ShowCoreInfo] 会显示红点徽标。

abstract class _$CoreUpdate extends $Notifier<CoreUpdateData> {
  CoreUpdateData build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CoreUpdateData, CoreUpdateData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CoreUpdateData, CoreUpdateData>,
              CoreUpdateData,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
