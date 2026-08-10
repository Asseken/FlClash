import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' hide IconButton, Colors;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LatencyTest extends ConsumerStatefulWidget {
  const LatencyTest({super.key});

  @override
  ConsumerState<LatencyTest> createState() => _LatencyTestState();
}

class _LatencyTestState extends ConsumerState<LatencyTest> {
  static const _sites = <(String, String)>[
    ('GitHub', 'https://github.com'),
    ('Google', 'https://www.google.com'),
    ('YouTube', 'https://www.youtube.com'),
    ('Cloudflare', 'https://www.gstatic.com/generate_204'),
  ];
  late final appLocalizations = context.appLocalizations;
  final Map<String, ValueNotifier<Delay?>> _delayNotifiers = {};

  // 跨 State 重建保留：首次挂载测一次，Grid 重建（切侧边栏/增删卡片）不重测
  static bool _hasAutoTested = false;
  // 跨 State 重建保留测速结果：State 重建后恢复上次的延迟数据
  static final Map<String, Delay?> _cachedDelays = {};
  // 测速版本号：新一轮测试递增，旧轮结果回来时若版本已过时则丢弃
  int _testVersion = 0;
  // 记录上次测试的节点名，切换节点时对比触发重测（static 跨 State 重建保留）
  static String? _lastProxyName;
  // 记录 isStart 上次值：区分"刚开启代理"与"切节点"
  static bool _preIsStart = false;

  void _scheduleTest() {
    debouncer.call(
      'delayTest',
      _test,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void initState() {
    super.initState();
    for (final site in _sites) {
      _delayNotifiers[site.$1] = ValueNotifier<Delay?>(_cachedDelays[site.$1]);
    }
    _preIsStart = ref.read(isStartProvider);
    ref.listenManual(isStartProvider, (prev, next) {
      if (prev == false && next == true) {
        _test();
      }
    });
    if (!_hasAutoTested) {
      _hasAutoTested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _test();
        }
      });
    }
  }

  @override
  void dispose() {
    debouncer.cancel('delayTest');
    for (final notifier in _delayNotifiers.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  Future<Delay> _testHttp(String url, String name) async {
    final stopwatch = Stopwatch()..start();
    final client = HttpClient()..connectionTimeout = httpTimeoutDuration;
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(httpTimeoutDuration);
      await request.close().timeout(httpTimeoutDuration);
      return Delay(name: name, url: url, value: stopwatch.elapsedMilliseconds);
    } catch (_) {
      return Delay(name: name, url: url, value: -1);
    } finally {
      client.close();
    }
  }

  // 计算当前选中的真实节点名（isStart=false 时为 null）
  String? _getCurrentProxyName() {
    final isStart = ref.read(isStartProvider);
    if (!isStart) {
      return null;
    }
    final groups = ref.read(groupsProvider);
    final selectedMap = ref.read(selectedMapProvider);
    final groupName =
        ref.read(currentProfileProvider)?.currentGroupName ??
        GroupName.GLOBAL.name;
    final state = computeRealSelectedProxyState(
      groupName,
      groups: groups,
      selectedMap: selectedMap,
    );
    return state.proxyName.isEmpty ? null : state.proxyName;
  }

  Future<void> _test() async {
    final version = ++_testVersion;
    final isStart = ref.read(isStartProvider);
    final String? proxyName;
    if (isStart) {
      proxyName = _getCurrentProxyName();
      if (proxyName == null) {
        for (final notifier in _delayNotifiers.values) {
          notifier.value = null;
        }
        return;
      }
      _lastProxyName = proxyName;
    } else {
      proxyName = null;
    }
    await Future.wait(
      _sites.map((site) async {
        final notifier = _delayNotifiers.putIfAbsent(
          site.$1,
          () => ValueNotifier<Delay?>(_cachedDelays[site.$1]),
        );
        notifier.value = Delay(name: site.$1, url: site.$2, value: 0);
        final delay = proxyName != null
            ? await coreController.getDelay(site.$2, proxyName)
            : await _testHttp(site.$2, site.$1);
        if (version == _testVersion) {
          _cachedDelays[site.$1] = delay;
          if (mounted) {
            notifier.value = delay;
          }
        }
      }),
    );
  }

  Widget _buildSiteRow((String, String) site, ValueNotifier<Delay?> notifier) {
    final bodyMediumHeight = globalState.measure.bodyMediumHeight;
    return SizedBox(
      height: bodyMediumHeight + 4,
      child: ValueListenableBuilder<Delay?>(
        valueListenable: notifier,
        builder: (_, delay, _) {
          final value = delay?.value;
          final Widget status;
          if (value == null) {
            status = Text(
              '-- ms',
              style: context.textTheme.bodyMedium?.toLight.adjustSize(1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          } else if (value < 0) {
            status = Text(
              'Timeout',
              style: context.textTheme.bodyMedium
                  ?.copyWith(color: Colors.red)
                  .adjustSize(1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          } else {
            status = value == 0
                ? Container(
                    padding: const EdgeInsets.all(2),
                    child: const AspectRatio(
                      aspectRatio: 1,
                      child: CommonCircleLoading(),
                    ),
                  )
                : Text(
                    '$value ms',
                    style: Theme.of(context).textTheme.bodyMedium?.toLight
                        .copyWith(color: utils.getDelayColor(value)),
                  );
          }
          return Padding(
            padding: const EdgeInsets.only(left: 12, right: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: TooltipText(
                    text: Text(
                      site.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                status,
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(selectedMapProvider);
    ref.watch(groupsProvider);
    ref.watch(currentProfileProvider);
    final isStart = ref.read(isStartProvider);
    // isStart 刚变化（开启/关闭代理）时，跳过 proxyName 对比——开启由 isStart 监听触发一次
    if (isStart != _preIsStart) {
      _preIsStart = isStart;
    } else {
      // 首次 build 只初始化 _lastProxyName（首次测速由 _hasAutoTested 处理），避免重复触发
      final proxyName = _getCurrentProxyName();
      if (_lastProxyName == null) {
        _lastProxyName = proxyName;
      } else if (proxyName != _lastProxyName) {
        _lastProxyName = proxyName;
        if (isStart) {
          _scheduleTest();
        }
      }
    }
    final descTextStyle = context.textTheme.titleSmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    return SizedBox(
      height: getWidgetHeight(2),
      child: CommonCard(
        onPressed: () {},
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: globalState.measure.titleMediumHeight + 16,
                padding: baseInfoEdgeInsets.copyWith(
                  bottom: 12,
                  top: 0,
                  left: 12,
                  right: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          WindowsIcons.zero_bars,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        TooltipText(
                          text: Text(
                            appLocalizations.delayTest,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: descTextStyle,
                          ),
                        ),
                      ],
                    ),
                    AspectRatio(
                      aspectRatio: 1,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _test();
                        },
                        icon: Icon(
                          size: 16.ap,
                          WindowsIcons.refresh,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final site in _sites)
                    _buildSiteRow(
                      site,
                      _delayNotifiers.putIfAbsent(
                        site.$1,
                        () => ValueNotifier<Delay?>(_cachedDelays[site.$1]),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
