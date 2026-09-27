// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../core_update.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CoreUpdate)
final coreUpdateProvider = CoreUpdateProvider._();

final class CoreUpdateProvider
    extends $NotifierProvider<CoreUpdate, CoreUpdateData> {
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

String _$coreUpdateHash() => r'd4f1a9f4ba3bcf6746dfab23bb728aca510c35fc';

abstract class _$CoreUpdate extends $Notifier<CoreUpdateData> {
  CoreUpdateData build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CoreUpdateData, CoreUpdateData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CoreUpdateData, CoreUpdateData>,
              CoreUpdateData,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
