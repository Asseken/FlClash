import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' hide IconButton, VisualDensity;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/action.dart';

class _QuickSwitchCard extends StatelessWidget {
  const _QuickSwitchCard({
    required this.label,
    required this.iconData,
    required this.items,
    required this.selector,
    required this.onChanged,
    this.actions = const [],
  });

  final String label;
  final IconData iconData;
  final List<Widget> items;
  final ProviderListenable<bool> selector;
  final void Function(WidgetRef ref, bool value) onChanged;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        radius: AppCorner.lg,
        onPressed: () {
          showSheet(
            context: context,
            builder: (_) {
              return AdaptiveSheetScaffold(
                body: generateListView(generateSection(items: items)),
                title: label,
              );
            },
          );
        },
        info: Info(label: label, iconData: iconData),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 4, bottom: 8, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TooltipText(
                text: Text(
                  context.appLocalizations.options,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.adjustSize(-2).toLight,
                ),
              ),
              ...actions,
              Consumer(
                builder: (_, ref, _) {
                  return ToggleSwitch(
                    checked: ref.watch(selector),
                    onChanged: (value) => onChanged(ref, value),
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

/// Only Windows ties TUN to a service that outlives the app; every other
/// desktop reaches the Core through the Helper socket the packaging installed,
/// so there is nothing here for the user to add or remove.
class _HelperServiceActions extends ConsumerWidget {
  const _HelperServiceActions({required this.blocked});

  /// TUN cannot be reconfigured while it is on, and that includes the service
  /// underneath it, so the switches stay inert instead of queueing a
  /// transition the running Core would not survive.
  final bool blocked;

  void _handleInstall(WidgetRef ref) {
    ref.read(windowsHelperServiceProvider.notifier).install();
    commonPrint.log('User RegisterWindowsService', logLevel: LogLevel.info);
  }

  Future<void> _handleUninstall(BuildContext context, WidgetRef ref) async {
    final appLocalizations = context.appLocalizations;
    final confirmed = await dialogs.showMessage(
      title: appLocalizations.uninstallService,
      message: TextSpan(text: appLocalizations.uninstallServiceTip),
    );
    if (confirmed != true) {
      return;
    }
    commonPrint.log(
      'User UnregisterWindowsService',
      logLevel: LogLevel.warning,
    );
    await ref.read(windowsHelperServiceProvider.notifier).uninstall();
    await ref.read(coreActionProvider.notifier).restartCore();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final serviceState = ref.watch(windowsHelperServiceProvider);
    final isBusy = serviceState.isLoading;
    final state = serviceState.value;

    // A record this install cannot claim still occupies the service name, so
    // removing it stays the only useful action.
    final hasService =
        state != null && state != WindowsHelperServiceState.notInstalled;
    final isEnabled = !blocked && !isBusy;
    return Flexible(
      flex: 1,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 4),
          _HelperServiceAction(
            tooltip: appLocalizations.installService,
            iconData: WindowsIcons.repair,
            onPressed: isEnabled && !hasService
                ? () => _handleInstall(ref)
                : null,
          ),
          const SizedBox(width: 6),
          _HelperServiceAction(
            tooltip: appLocalizations.uninstallService,
            iconData: WindowsIcons.delete,
            onPressed: isEnabled && hasService
                ? () => _handleUninstall(context, ref)
                : null,
          ),
        ],
      ),
    );
  }
}

class _HelperServiceAction extends StatelessWidget {
  const _HelperServiceAction({
    required this.tooltip,
    required this.iconData,
    required this.onPressed,
  });

  final String tooltip;
  final IconData iconData;
  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      iconSize: 18,
      onPressed: onPressed,
      icon: Icon(
        iconData,
        // color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class TUNButton extends ConsumerWidget {
  const TUNButton({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final tunEnable = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.enable),
    );
    return _QuickSwitchCard(
      label: context.appLocalizations.tun,
      iconData: WindowsIcons.ethernet,
      items: [
        if (system.isDesktop) const TUNItem(),
        if (system.isMacOS) const AutoSetSystemDnsItem(),
        const TunStackItem(),
      ],
      selector: patchClashConfigProvider.select((state) => state.tun.enable),
      actions: system.isWindows
          ? [_HelperServiceActions(blocked: tunEnable)]
          : const [],
      onChanged: (ref, value) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(enable: value));
      },
    );
  }
}

class SystemProxyButton extends StatelessWidget {
  const SystemProxyButton({super.key});

  @override
  Widget build(BuildContext context) {
    return _QuickSwitchCard(
      label: context.appLocalizations.systemProxy,
      iconData: FluentIcons.internet_sharing,
      items: const [SystemProxyItem(), BypassDomainItem()],
      selector: networkSettingProvider.select((state) => state.systemProxy),
      onChanged: (ref, value) {
        ref
            .read(networkSettingProvider.notifier)
            .update((state) => state.copyWith(systemProxy: value));
      },
    );
  }
}

class VpnButton extends StatelessWidget {
  const VpnButton({super.key});

  @override
  Widget build(BuildContext context) {
    return _QuickSwitchCard(
      label: 'VPN',
      iconData: WindowsIcons.vpn,
      items: const [VPNItem(), VpnSystemProxyItem(), TunStackItem()],
      selector: vpnSettingProvider.select((state) => state.enable),
      onChanged: (ref, value) {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(enable: value));
      },
    );
  }
}
