import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Tooltip, Colors, IconButton;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TUNButton extends StatelessWidget {
  const TUNButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: () {
          showSheet(
            context: context,
            builder: (_) {
              return Builder(
                builder: (context) {
                  return AdaptiveSheetScaffold(
                    body: generateListView(
                      generateSection(
                        items: [
                          if (system.isDesktop) const TUNItem(),
                          if (system.isMacOS) const AutoSetSystemDnsItem(),
                          const TunStackItem(),
                        ],
                      ),
                    ),
                    title: appLocalizations.tun,
                  );
                },
              );
            },
          );
        },
        info: Info(
          label: appLocalizations.tun,
          iconData: WindowsIcons.ethernet,
        ),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 4, bottom: 8, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TooltipText(
                text: Text(
                  appLocalizations.options,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.adjustSize(-2).toLight,
                ),
              ),
              if (system.isWindows)
                const Flexible(flex: 1, child: _TunServiceButtons()),
              Consumer(
                builder: (_, ref, _) {
                  final enable = ref.watch(
                    patchClashConfigProvider.select(
                      (state) => state.tun.enable,
                    ),
                  );
                  return ToggleSwitch(
                    checked: enable,
                    onChanged: (value) async {
                      if (value) {
                        final ok = await _ensureServiceInstalled();
                        if (!ok || !context.mounted) {
                          return;
                        }
                      }
                      ref
                          .read(patchClashConfigProvider.notifier)
                          .update((state) => state.copyWith.tun(enable: value));
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TunServiceButtons extends ConsumerStatefulWidget {
  const _TunServiceButtons();

  @override
  ConsumerState<_TunServiceButtons> createState() => _TunServiceButtonsState();
}

class _TunServiceButtonsState extends ConsumerState<_TunServiceButtons> {
  @override
  void initState() {
    super.initState();
    ref.read(windowsHelperServiceInstalledProvider.notifier).refresh();
  }

  Future<void> _handleInstallService() async {
    final previous = ref.read(windowsHelperServiceInstalledProvider);
    final notifier = ref.read(windowsHelperServiceInstalledProvider.notifier);
    notifier.set(null);
    final ok = await _promptInstallService();
    notifier.set(ok ?? previous);
  }

  Future<void> _handleUninstallService() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.showMessage(
      title: appLocalizations.uninstallService,
      message: TextSpan(text: appLocalizations.uninstallServiceTip),
    );
    if (res != true) return;
    commonPrint.log('User UnregisterWindowsService', logLevel: LogLevel.info);
    final notifier = ref.read(windowsHelperServiceInstalledProvider.notifier);
    notifier.set(null);
    final ok = await windows!.uninstallService();
    notifier.set(!ok);
    globalState.showNotifier(
      ok
          ? appLocalizations.uninstallServiceSuccess
          : appLocalizations.uninstallServiceFailed,
    );
  }

  Widget _buildButton({
    required String tooltip,
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        iconSize: 18,
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(patchClashConfigProvider.select((state) => state.tun.enable), (
      _,
      _,
    ) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(windowsHelperServiceInstalledProvider.notifier).refresh();
        }
      });
    });
    final appLocalizations = context.appLocalizations;
    final isInstalled = ref.watch(windowsHelperServiceInstalledProvider);
    final tunEnabled = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.enable),
    );
    final canManage = !tunEnabled;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 4),
        _buildButton(
          tooltip: appLocalizations.installService,
          icon: WindowsIcons.settings,
          enabled: canManage && isInstalled == false,
          onPressed: _handleInstallService,
        ),
        const SizedBox(width: 4),
        _buildButton(
          tooltip: appLocalizations.uninstallService,
          icon: WindowsIcons.delete,
          enabled: canManage && isInstalled == true,
          onPressed: _handleUninstallService,
        ),
      ],
    );
  }
}

Future<bool?> _promptInstallService() async {
  final appLocalizations = currentAppLocalizations;
  final res = await globalState.showMessage(
    title: appLocalizations.installService,
    message: TextSpan(text: appLocalizations.installServiceTip),
  );
  if (res != true) return null;
  commonPrint.log('User RegisterWindowsService', logLevel: LogLevel.info);
  final ok = await windows!.installService();
  globalState.showNotifier(
    ok
        ? appLocalizations.installServiceSuccess
        : appLocalizations.installServiceFailed,
  );
  return ok;
}

Future<bool> _ensureServiceInstalled() async {
  if (!system.isWindows) {
    return true;
  }
  if (await windows!.isServiceInstalled()) {
    return true;
  }
  final ok = await _promptInstallService();
  return ok == true;
}

class SystemProxyButton extends StatelessWidget {
  const SystemProxyButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: () {
          showSheet(
            context: context,
            builder: (_) {
              return AdaptiveSheetScaffold(
                body: generateListView(
                  generateSection(
                    items: [const SystemProxyItem(), const BypassDomainItem()],
                  ),
                ),
                title: appLocalizations.systemProxy,
              );
            },
          );
        },
        info: Info(
          label: appLocalizations.systemProxy,
          iconData: FluentIcons.internet_sharing,
        ),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 4, bottom: 8, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: TooltipText(
                  text: Text(
                    appLocalizations.options,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.adjustSize(-2).toLight,
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, _) {
                  final systemProxy = ref.watch(
                    networkSettingProvider.select((state) => state.systemProxy),
                  );
                  return ToggleSwitch(
                    checked: systemProxy,
                    onChanged: (value) {
                      ref
                          .read(networkSettingProvider.notifier)
                          .update(
                            (state) => state.copyWith(systemProxy: value),
                          );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VpnButton extends StatelessWidget {
  const VpnButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: () {
          showSheet(
            context: context,
            builder: (_) {
              return AdaptiveSheetScaffold(
                body: generateListView(
                  generateSection(
                    items: [
                      const VPNItem(),
                      const VpnSystemProxyItem(),
                      const TunStackItem(),
                    ],
                  ),
                ),
                title: 'VPN',
              );
            },
          );
        },
        info: const Info(label: 'VPN', iconData: WindowsIcons.vpn),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 4, bottom: 8, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: TooltipText(
                  text: Text(
                    appLocalizations.options,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.adjustSize(-2).toLight,
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, _) {
                  final enable = ref.watch(
                    vpnSettingProvider.select((state) => state.enable),
                  );
                  return ToggleSwitch(
                    checked: enable,
                    onChanged: (value) {
                      ref
                          .read(vpnSettingProvider.notifier)
                          .update((state) => state.copyWith(enable: value));
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
