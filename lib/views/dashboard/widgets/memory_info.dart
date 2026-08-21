import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _memoryStateNotifier = ValueNotifier<num>(0);
final _coreMemoryStateNotifier = ValueNotifier<num>(0);

class MemoryInfo extends StatefulWidget {
  final Future<num> Function()? memoryReader;

  const MemoryInfo({super.key, @visibleForTesting this.memoryReader});

  @override
  State<MemoryInfo> createState() => _MemoryInfoState();
}

class _MemoryInfoState extends State<MemoryInfo>
    with WidgetsBindingObserver, ActivePollingMixin<MemoryInfo> {
  @override
  Duration get pollInterval => const Duration(seconds: 2);

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

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: getWidgetHeight(1),
      child: RepaintBoundary(
        child: CommonCard(
          info: Info(
            iconData: WindowsIcons.cpu,
            label: appLocalizations.memoryInfo,
          ),
          onPressed: () {
            coreController.requestGc();
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
                                              const FlutterLogo(size: 17),
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
                                              const FlutterLogo(size: 14),
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
                                              Image.asset(
                                                'assets/images/Meta.png',
                                                width: 17,
                                                height: 17,
                                              ),
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
                                              Image.asset(
                                                'assets/images/Meta.png',
                                                width: 14,
                                                height: 14,
                                              ),
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

Future<num> _readTotal() async {
  final rss = ProcessInfo.currentRss;
  final coreConnected =
      globalState.container.read(coreStatusProvider) == CoreStatus.connected;
  _coreMemoryStateNotifier.value = await coreController.getMemory();
  if (system.isDesktop && coreConnected) {
    return _coreMemoryStateNotifier.value + rss;
  }
  return rss;
}
