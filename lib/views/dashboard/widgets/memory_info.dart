import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemoryInfo extends ConsumerStatefulWidget {
  final Future<num> Function()? memoryReader;

  const MemoryInfo({super.key, @visibleForTesting this.memoryReader});

  @override
  ConsumerState<MemoryInfo> createState() => _MemoryInfoState();
}

class _MemoryInfoState extends ConsumerState<MemoryInfo>
    with WidgetsBindingObserver, ActivePollingMixin<MemoryInfo> {
  final _memoryStateNotifier = ValueNotifier<num>(0);
  final _coreMemoryStateNotifier = ValueNotifier<num>(0);

  CoreController get _core => ref.read(coreHandlerProvider);

  @override
  Duration get pollInterval => const Duration(seconds: 2);

  @override
  void dispose() {
    _memoryStateNotifier.dispose();
    _coreMemoryStateNotifier.dispose();
    super.dispose();
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    final memory = await _readMemory();
    if (memory == null || !isCurrent()) {
      return;
    }
    _memoryStateNotifier.value = memory;
  }

  Future<num?> _readMemory() async {
    try {
      final memoryReader = widget.memoryReader;
      return memoryReader != null ? await memoryReader() : await _readTotal();
    } catch (error) {
      commonPrint.log(
        'updateMemory error: $error',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
  }

  Future<num> _readTotal() async {
    final rss = ProcessInfo.currentRss;
    // The Core answers only while it is up; asking anyway spends a request
    // budget on a socket nothing is listening to.
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      _coreMemoryStateNotifier.value = 0;
      return rss;
    }
    _coreMemoryStateNotifier.value = await _core.getMemory();
    return rss;
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: getWidgetHeight(1),
      child: RepaintBoundary(
        child: CommonCard(
          radius: AppCorner.lg,
          info: Info(
            iconData: WindowsIcons.cpu,
            label: appLocalizations.memoryInfo,
          ),
          onPressed: () {
            _core.requestGc();
          },
          child: Container(
            padding: baseInfoEdgeInsets.copyWith(top: 0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer(
                  builder: (_, ref, _) {
                    final view = ref.watch(viewModeProvider);
                    return SizedBox(
                      height: globalState.measure.bodyMediumHeight + 2,
                      child: view == ViewMode.desktop || system.isDesktop
                          ? Row(
                              key: const ValueKey('desktop'),
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ValueListenableBuilder(
                                  valueListenable: _memoryStateNotifier,
                                  builder: (_, memory, _) {
                                    final traffic = memory.traffic;
                                    return view == ViewMode.desktop
                                        ? Row(
                                            children: [
                                              const FlutterLogo(size: 16),
                                              Text(
                                                traffic.value,
                                                style: context
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.toLight
                                                    .adjustSize(1),
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                traffic.unit,
                                                style: context
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.toLight
                                                    .adjustSize(1),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              const FlutterLogo(size: 13),
                                              Text(
                                                traffic.value,
                                                style: context
                                                    .textTheme
                                                    .bodySmall
                                                    ?.toLight
                                                    .adjustSize(1)
                                                    .copyWith(
                                                      fontSize:
                                                          (context
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.fontSize ??
                                                              12) -
                                                          0.5,
                                                    ),
                                              ),
                                              // const SizedBox(width: 3),
                                              Text(
                                                traffic.unit,
                                                style: context
                                                    .textTheme
                                                    .bodySmall
                                                    ?.toLight
                                                    .adjustSize(1)
                                                    .copyWith(
                                                      fontSize:
                                                          (context
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.fontSize ??
                                                              12) -
                                                          0.5,
                                                    ),
                                              ),
                                            ],
                                          );
                                  },
                                ),
                                ValueListenableBuilder(
                                  valueListenable: _coreMemoryStateNotifier,
                                  builder: (_, core, _) {
                                    final coreMemory = core.traffic;
                                    return view == ViewMode.desktop
                                        ? Row(
                                            children: [
                                              const _CoreBrandMark(size: 16),
                                              coreMemory.value == '0'
                                                  ? Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            2,
                                                          ),
                                                      child: const AspectRatio(
                                                        aspectRatio: 1,
                                                        child:
                                                            CommonCircleLoading(),
                                                      ),
                                                    )
                                                  : Text(
                                                      coreMemory.value,
                                                      style: context
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.toLight
                                                          .adjustSize(1),
                                                    ),
                                              const SizedBox(width: 2),
                                              Text(
                                                coreMemory.unit,
                                                style: context
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.toLight
                                                    .adjustSize(1),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              const _CoreBrandMark(size: 13),
                                              coreMemory.value == '0'
                                                  ? Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            2,
                                                          ),
                                                      child: const AspectRatio(
                                                        aspectRatio: 1,
                                                        child:
                                                            CommonCircleLoading(),
                                                      ),
                                                    )
                                                  : Text(
                                                      coreMemory.value,
                                                      style: context
                                                          .textTheme
                                                          .bodySmall
                                                          ?.toLight
                                                          .adjustSize(1)
                                                          .copyWith(
                                                            fontSize:
                                                                (context
                                                                        .textTheme
                                                                        .bodySmall
                                                                        ?.fontSize ??
                                                                    12) -
                                                                0.5,
                                                          ),
                                                    ),
                                              // const SizedBox(width: 3),
                                              Text(
                                                coreMemory.unit,
                                                style: context
                                                    .textTheme
                                                    .bodySmall
                                                    ?.toLight
                                                    .adjustSize(1)
                                                    .copyWith(
                                                      fontSize:
                                                          (context
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.fontSize ??
                                                              12) -
                                                          0.5,
                                                    ),
                                              ),
                                            ],
                                          );
                                  },
                                ),
                              ],
                            )
                          : ValueListenableBuilder(
                              key: const ValueKey('mobile'),
                              valueListenable: _memoryStateNotifier,
                              builder: (_, memory, _) {
                                final traffic = memory.traffic;
                                return Row(
                                  children: [
                                    const FlutterLogo(size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      traffic.value,
                                      style: context
                                          .textTheme
                                          .bodyMedium
                                          ?.toLight
                                          .adjustSize(1),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      traffic.unit,
                                      style: context
                                          .textTheme
                                          .bodyMedium
                                          ?.toLight
                                          .adjustSize(1),
                                    ),
                                  ],
                                );
                              },
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Core's own brand mark. A desktop bundle built before the image was added
/// has no entry for it, and an unhandled asset failure would take the whole
/// dashboard card down with it.
class _CoreBrandMark extends StatelessWidget {
  const _CoreBrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/Meta.png',
      width: size,
      height: size,
      errorBuilder: (context, _, _) {
        return FlutterLogo(size: size);
      },
    );
  }
}
