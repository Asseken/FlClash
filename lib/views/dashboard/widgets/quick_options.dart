import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Tooltip;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../enum/enum.dart';
import '../../../providers/app.dart';

class TUNButton extends ConsumerStatefulWidget {
  const TUNButton({super.key});

  @override
  ConsumerState<TUNButton> createState() => _TUNButtonState();
}

class _TUNButtonState extends ConsumerState<TUNButton> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(windowsHelperServiceProvider.notifier).refresh();
    });
  }

  Future<void> _handleRegisterService() async {
    if (windows == null) return;
    await windows!.registerService();
    if (mounted) {
      ref.read(windowsHelperServiceProvider.notifier).refresh();
    }
    commonPrint.log(
      'User RegisterWindowsService For Tun',
      logLevel: LogLevel.info,
    );
  }

  Future<void> _handleUnregisterService() async {
    if (windows == null) return;
    await windows!.unregisterService();
    if (mounted) {
      ref.read(windowsHelperServiceProvider.notifier).refresh();
    }
    commonPrint.log(
      'User UnregisterWindowsService For TUN',
      logLevel: LogLevel.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final tunEnable = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.enable),
    );
    final serviceStatus = ref.watch(windowsHelperServiceProvider);

    final settingsDisabled =
        tunEnable || serviceStatus == WindowsHelperServiceStatus.running;
    final deleteDisabled = tunEnable;

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
              if (system.isWindows)
                Flexible(
                  flex: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                      const SizedBox(width: 4),
                      Tooltip(
                        message:
                        '${appLocalizations.settings} (${appLocalizations.tun})',
                        child: InkWell(
                          onTap: settingsDisabled
                              ? null
                              : _handleRegisterService,
                          child: Icon(
                            WindowsIcons.settings,
                            size: 18,
                            color: settingsDisabled
                                ? Theme.of(context).disabledColor
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message:
                        '${appLocalizations.delete} (${appLocalizations.tun})',
                        child: InkWell(
                          onTap: deleteDisabled
                              ? null
                              : _handleUnregisterService,
                          child: Icon(
                            WindowsIcons.delete,
                            size: 18,
                            color: deleteDisabled
                                ? Theme.of(context).disabledColor
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Switch(
                value: tunEnable,
                onChanged: (value) {
                  ref
                      .read(patchClashConfigProvider.notifier)
                      .update((state) => state.copyWith.tun(enable: value));
                  if (value) {
                    _handleRegisterService();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                  return Switch(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: systemProxy,
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
                  return Switch(
                    value: enable,
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
