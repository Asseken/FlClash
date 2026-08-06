import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fluent_ui/fluent_ui.dart' hide IconButton, Colors;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

class AppStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(checkIpProvider, (prev, next) {
      if (prev != next && next.a && next.c) {
        ref.read(networkDetectionProvider.notifier).startCheck();
      }
    });
    ref.listenManual(configProvider, (prev, next) {
      if (prev != next) {
        globalState.container
            .read(storeActionProvider.notifier)
            .savePreferencesDebounce();
      }
    });
    ref.listenManual(needUpdateGroupsProvider, (prev, next) {
      if (prev != next) {
        globalState.container
            .read(proxiesActionProvider.notifier)
            .updateGroupsDebounce();
      }
    });
    ref.listenManual(suspendProvider, (prev, next) {
      final isStart = ref.read(isStartProvider);
      if (prev != next && isStart) {
        debouncer.call(FunctionTag.suspend, () async {
          if (next == true) {
            await coreController.stopListener();
          } else {
            await coreController.startListener();
          }
          ref.read(checkIpNumProvider.notifier).add();
        });
      }
    });
    if (system.isMacOS) {
      ref.listenManual(autoSetSystemDnsStateProvider, (prev, next) async {
        if (prev == next) {
          return;
        }
        if (next.a == true && next.b == true) {
          macOS?.updateDns(false);
        } else {
          macOS?.updateDns(true);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    commonPrint.log('$state');
    if (state == AppLifecycleState.resumed) {
      permissions.check();
      render?.resume();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ref = globalState.container;
        ref.read(setupActionProvider.notifier).tryCheckIp();
      });
    }
  }

  @override
  void didChangePlatformBrightness() {
    globalState.container.read(themeActionProvider.notifier).updateBrightness();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (_) {
        render?.resume();
      },
      child: widget.child,
    );
  }
}

class AppEnvManager extends StatelessWidget {
  final Widget child;

  const AppEnvManager({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      if (globalState.isPre) {
        return Banner(
          message: 'DEBUG',
          location: BannerLocation.topEnd,
          child: child,
        );
      }
    }
    if (globalState.isPre) {
      return Banner(
        message: globalState.appEnv.toUpperCase(),
        location: BannerLocation.topEnd,
        child: child,
      );
    }
    return child;
  }
}

class AppSidebarContainer extends ConsumerWidget {
  final Widget child;
  // static：跨 build 保留置顶状态，且构造器可恢复 const
  static final isPinNotifier = ValueNotifier<bool>(false);
  const AppSidebarContainer({super.key, required this.child});

  void _updateSideBarWidth(WidgetRef ref, double contentWidth) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sideWidthProvider.notifier).value =
          ref.read(viewSizeProvider.select((state) => state.width)) -
          contentWidth;
    });
  }

  void _handleToPage(PageLabel pageLabel) {
    final focusNode = FocusManager.instance.primaryFocus;
    final preserveNavigationFocus =
        focusNode?.context?.findAncestorWidgetOfExactType<NavigationRail>() !=
        null;
    globalState.container
        .read(currentPageLabelProvider.notifier)
        .toPage(pageLabel);
    if (!preserveNavigationFocus || focusNode == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNode.context != null && focusNode.canRequestFocus) {
        focusNode.requestFocus();
      }
    });
  }

  Future<void> _updatePin() async {
    try {
      final isAlwaysOnTop = await windowManager.isAlwaysOnTop();
      await windowManager.setAlwaysOnTop(!isAlwaysOnTop);
      isPinNotifier.value = await windowManager.isAlwaysOnTop();
    } catch (e) {
      commonPrint.log('updatePin failed: $e', logLevel: LogLevel.warning);
    }
  }

  List<NavigationPaneItem> _buildPaneItems(
    BuildContext context,
    List<NavigationItem> items,
  ) {
    final cs = Theme.of(context).colorScheme;
    return items
        .map(
          (e) => PaneItem(
            icon: IconTheme.merge(
              data: const IconThemeData(size: 22),
              child: e.icon,
            ),
            title: Text(
              Intl.message(e.label.name),
              style: context.textTheme.bodyLarge,
            ),
            body: const SizedBox.shrink(),
            tileColor: WidgetStateProperty.resolveWith((states) {
              if (states.isPressed) {
                return cs.onSurface.opacity12;
              }
              if (states.isHovered) {
                return cs.onSurface.opacity10;
              }
              return Colors.transparent;
            }),
            // selectedTileColor: WidgetStatePropertyAll(cs.secondaryContainer),
          ),
        )
        .toList();
  }

  Widget _wrapContent(WidgetRef ref, Widget content) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (_, constraints) {
          _updateSideBarWidth(ref, constraints.maxWidth);
          return content;
        },
      ),
    );
  }

  Widget _buildFluentShell({
    required BuildContext context,
    required WidgetRef ref,
    required List<NavigationItem> navigationItems,
    required int currentIndex,
    required bool showLabel,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return NavigationPaneTheme(
      data: NavigationPaneThemeData(
        backgroundColor: cs.surfaceContainer,
        overlayBackgroundColor: cs.surfaceContainerHigh,
        highlightColor: cs.secondaryContainer,
        tileColor: WidgetStateProperty.resolveWith((states) {
          if (states.isPressed) {
            return cs.onSurface.opacity12;
          }
          if (states.isHovered) {
            return cs.onSurface.opacity10;
          }
          return Colors.transparent;
        }),
        selectedIconColor: WidgetStatePropertyAll(cs.onSecondaryContainer),
        unselectedIconColor: WidgetStatePropertyAll(cs.onSurfaceVariant),
        selectedTextStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(color: cs.onSecondaryContainer),
        ),
        unselectedTextStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
      child: NavigationView(
        titleBar: system.isMacOS
            ? SizedBox(
                height: 26,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 22,
                      onPressed: () async {
                        _updatePin();
                      },
                      icon: ValueListenableBuilder(
                        valueListenable: isPinNotifier,
                        builder: (_, value, _) {
                          return value
                              ? const Icon(Icons.push_pin)
                              : const Icon(Icons.push_pin_outlined);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              )
            : const SizedBox.shrink(),
        contentShape: const RoundedRectangleBorder(),
        pane: NavigationPane(
          displayMode: showLabel
              ? PaneDisplayMode.expanded
              : PaneDisplayMode.compact,
          size: const NavigationPaneSize(compactWidth: 60, openWidth: 130),
          selected: currentIndex,
          onChanged: (i) {
            _handleToPage(navigationItems[i].label);
          },
          indicator: StickyNavigationIndicator(
            indicatorSize: 3,
            leftPadding: 6,
            color: Theme.of(context).colorScheme.primary,
          ),
          items: [
            PaneItem(
              icon: SizedBox(
                width: 22,
                height: 22,
                child: Image.asset(
                  'assets/images/icon.png',
                  fit: BoxFit.contain,
                ),
              ),
              title: Text('FlClash', style: context.textTheme.bodyLarge),
              enabled: false,
            ),
            ..._buildPaneItems(context, navigationItems),
          ],
          footerItems: [
            PaneItemAction(
              icon: const Icon(WindowsIcons.global_nav_button, size: 22),
              onTap: () {
                ref
                    .read(appSettingProvider.notifier)
                    .update(
                      (state) => state.copyWith(showLabel: !state.showLabel),
                    );
              },
            ),
          ],
        ),
        paneBodyBuilder: (_, _) => _wrapContent(ref, child),
        onDisplayModeChanged: (mode) {
          ref
              .read(appSettingProvider.notifier)
              .update(
                (state) =>
                    state.copyWith(showLabel: mode == PaneDisplayMode.expanded),
              );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationStateProvider);
    final navigationItems = navigationState.navigationItems;
    final isMobileView = navigationState.viewMode == ViewMode.mobile;
    if (isMobileView) {
      return child;
    }
    final currentIndex = navigationState.currentIndex;
    final showLabel = ref.watch(appSettingProvider).showLabel;
    return _buildFluentShell(
      context: context,
      ref: ref,
      navigationItems: navigationItems,
      currentIndex: currentIndex,
      showLabel: showLabel,
      child: child,
    );
  }
}
