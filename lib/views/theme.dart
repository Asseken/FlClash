import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/font_family.dart';
import 'package:fl_clash/views/theme_preview.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeView extends StatelessWidget {
  const ThemeView({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return BaseScaffold(
      title: appLocalizations.theme,
      body: ListView(
        padding: EdgeInsets.only(top: context.appBarInset, bottom: 32),
        children: const [
          ThemeLivePreview(),
          SizedBox(height: 16),
          _ThemeModeItem(),
          SizedBox(height: 16),
          _PureBlackItem(),
          SizedBox(height: 16),
          _PrimaryColorItem(),
          SizedBox(height: 16),
          _NavigationBarItem(),
          SizedBox(height: 16),
          _TabAnimationItem(),
          SizedBox(height: 16),
          _LiquidGlassItem(),
          SizedBox(height: 16),
          _SidebarBlurItem(),
          _FontFamilyItem(),
          SizedBox(height: 16),
          _TextScaleFactorItem(),
          SizedBox(height: 16),
          _BackgroundImageItem(),
        ],
      ),
    );
  }
}

class _ThemeModeItem extends ConsumerWidget {
  const _ThemeModeItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final themeMode = ref.watch(
      themeSettingProvider.select((state) => state.themeMode),
    );
    final floatingBar = ref.watch(_floatingBarProvider);
    final liquidGlass = ref.watch(_liquidGlassProvider);
    final light = MiniScreen(
      colorScheme: ref.watch(genColorSchemeProvider(Brightness.light)),
      floatingBar: floatingBar,
      liquidGlass: liquidGlass,
    );
    final dark = MiniScreen(
      colorScheme: ref.watch(genColorSchemeProvider(Brightness.dark)),
      floatingBar: floatingBar,
      liquidGlass: liquidGlass,
    );
    return PreviewChoiceGroup<ThemeMode>(
      info: Info(label: appLocalizations.themeMode, glyph: AppGlyphs.sun),
      value: themeMode,
      choices: [
        PreviewChoice(
          value: ThemeMode.system,
          label: appLocalizations.auto,
          pictogram: MiniScreenThumb(
            screen: MiniSplitScreen(light: light, dark: dark),
          ),
        ),
        PreviewChoice(
          value: ThemeMode.light,
          label: appLocalizations.light,
          pictogram: MiniScreenThumb(screen: light),
        ),
        PreviewChoice(
          value: ThemeMode.dark,
          label: appLocalizations.dark,
          pictogram: MiniScreenThumb(screen: dark),
        ),
      ],
      onChanged: (value) {
        ref
            .read(themeSettingProvider.notifier)
            .update((state) => state.copyWith(themeMode: value));
      },
    );
  }
}

class _PrimaryColorItem extends ConsumerWidget {
  const _PrimaryColorItem();

  Future<void> _handleReset(BuildContext context, WidgetRef ref) async {
    final res = await dialogs.showMessage(
      message: TextSpan(text: context.appLocalizations.resetTip),
      destructive: true,
      confirmText: context.appLocalizations.reset,
    );
    if (res != true || !context.mounted) {
      return;
    }
    ref.read(themeSettingProvider.notifier).update((state) {
      return state.copyWith(
        primaryColors: defaultPrimaryColors,
        primaryColor: defaultPrimaryColor,
        colorStyle: ColorStyle.vivid,
      );
    });
  }

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    int color,
  ) async {
    final appLocalizations = context.appLocalizations;
    final res = await dialogs.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.color),
      ),
      destructive: true,
      confirmText: appLocalizations.delete,
    );
    if (res != true || !context.mounted) {
      return;
    }
    ref.read(themeSettingProvider.notifier).update((state) {
      final primaryColors = List<int>.from(state.primaryColors)..remove(color);
      var primaryColor = state.primaryColor;
      if (primaryColor == color) {
        primaryColor = primaryColors.contains(defaultPrimaryColor)
            ? defaultPrimaryColor
            : null;
      }
      return state.copyWith(
        primaryColors: primaryColors,
        primaryColor: primaryColor,
      );
    });
  }

  void _showColorSheet(
    BuildContext context,
    Color initialColor,
    ValueChanged<int> onConfirmed,
  ) {
    showSheet<void>(
      context: context,
      props: const SheetProps(detents: [0.9]),
      builder: (_) => _CustomColorSheet(
        initialColor: initialColor,
        onConfirmed: (color) {
          if (context.mounted) {
            onConfirmed(color);
          }
        },
      ),
    );
  }

  void _handleAdd(BuildContext context, WidgetRef ref) {
    final primaryColor = ref.read(themeSettingProvider).primaryColor;
    _showColorSheet(
      context,
      primaryColor != null
          ? Color(primaryColor)
          : ref.read(dynamicColorProvider).accentColor,
      (color) => _update(
        ref,
        (state) => state.copyWith(
          primaryColors: state.primaryColors.contains(color)
              ? state.primaryColors
              : [...state.primaryColors, color],
          primaryColor: color,
        ),
      ),
    );
  }

  void _handleEdit(BuildContext context, WidgetRef ref, int color) {
    _showColorSheet(
      context,
      Color(color),
      (edited) => _update(ref, (state) {
        final index = state.primaryColors.indexOf(color);
        if (edited == color || index == -1) {
          return state;
        }
        final primaryColors = List<int>.from(state.primaryColors);
        if (primaryColors.contains(edited)) {
          primaryColors.removeAt(index);
        } else {
          primaryColors[index] = edited;
        }
        return state.copyWith(
          primaryColors: primaryColors,
          primaryColor: state.primaryColor == color
              ? edited
              : state.primaryColor,
        );
      }),
    );
  }

  void _update(WidgetRef ref, ThemeProps Function(ThemeProps state) update) {
    ref.read(themeSettingProvider.notifier).update(update);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final themeColors = ref.watch(
      themeSettingProvider.select(
        (state) => ThemeColorsSelectorState(
          primaryColor: state.primaryColor,
          primaryColors: state.primaryColors,
          colorStyle: state.colorStyle,
          isDefault:
              state.primaryColor == defaultPrimaryColor &&
              intListEquality.equals(
                state.primaryColors,
                defaultPrimaryColors,
              ) &&
              state.colorStyle == ColorStyle.vivid,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoHeader(
          info: Info(
            label: appLocalizations.themeColor,
            glyph: AppGlyphs.palette,
          ),
          actions: [
            if (!themeColors.isDefault)
              _ResetButton(onPressed: () => _handleReset(context, ref)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              _ColorSwatches(
                colors: [null, ...themeColors.primaryColors],
                selected: themeColors.primaryColor,
                onSelect: (color) => _update(
                  ref,
                  (state) => state.copyWith(primaryColor: color),
                ),
                onEdit: (color) => _handleEdit(context, ref, color),
                onDelete: (color) => _handleDelete(context, ref, color),
                onAdd: () => _handleAdd(context, ref),
              ),
              generateSection(
                items: [
                  ListItem<ColorStyle>.options(
                    title: Text(appLocalizations.colorStyle),
                    options: ColorStyle.values,
                    value: themeColors.colorStyle,
                    textBuilder: (style) => style.label,
                    onChanged: (style) => _update(
                      ref,
                      (state) => state.copyWith(colorStyle: style),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorSwatches extends ConsumerWidget {
  const _ColorSwatches({
    required this.colors,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  static const double _minGap = 6;

  // Lines the dots, not their selection rings, up with the rows' text.
  static const double _inset = 16 - (_ColorSwatch.size - _ColorSwatch.dot) / 2;

  final List<int?> colors;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final level = context.raisedSurfaceLevel;
    final systemColor = ref
        .watch(dynamicColorProvider)
        .seedOf(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(_inset),
      decoration: ShapeDecoration(
        color: level.colorOf(colorScheme),
        shape: AppShape.xl,
      ),
      child: SurfaceScope(
        level: level,
        child: LayoutBuilder(
          builder: (_, constraints) {
            const cell = _ColorSwatch.size;
            final width = constraints.maxWidth;
            final columns = max(
              1,
              ((width + _minGap) / (cell + _minGap)).floor(),
            );
            final gap = columns > 1
                ? ((width - columns * cell) / (columns - 1)).floorToDouble()
                : 0.0;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final color in colors)
                  _ColorSwatch(
                    color: color == null ? null : Color(color),
                    systemColor: systemColor,
                    isSelected: color == selected,
                    label: color == null
                        ? appLocalizations.followSystem
                        : Color(color).hex,
                    onPressed: () => onSelect(color),
                    menuItems: color == null
                        ? null
                        : [
                            CommonPopupMenuItem(
                              glyph: AppGlyphs.edit,
                              label: appLocalizations.edit,
                              onPressed: () => onEdit(color),
                            ),
                            CommonPopupMenuItem(
                              danger: true,
                              glyph: AppGlyphs.delete,
                              label: appLocalizations.delete,
                              onPressed: () => onDelete(color),
                            ),
                          ],
                  ),
                _AddColorButton(onPressed: onAdd),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatefulWidget {
  const _ColorSwatch({
    required this.color,
    required this.systemColor,
    required this.isSelected,
    required this.label,
    required this.onPressed,
    this.menuItems,
  });

  static const double size = 44;
  static const double dot = 32;
  static const double _ring = 2.5;
  static const _duration = Duration(milliseconds: 200);

  static const double _badge = 20;

  /// Null follows the system's accent color, [systemColor].
  final Color? color;
  final Color systemColor;
  final bool isSelected;
  final String label;
  final VoidCallback onPressed;
  final List<CommonPopupMenuItem>? menuItems;

  @override
  State<_ColorSwatch> createState() => _ColorSwatchState();
}

class _ColorSwatchState extends State<_ColorSwatch> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final fill = color ?? widget.systemColor;
    final selected = widget.isSelected;
    final check = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final swatch = Semantics(
      button: true,
      selected: selected,
      label: widget.label,
      child: SizedBox.square(
        dimension: _ColorSwatch.size,
        child: Material(
          type: MaterialType.transparency,
          shape: AppShape.circle,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: AppShape.circle,
            onTap: widget.onPressed,
            onFocusChange: (value) => setState(() => _focused = value),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  opacity: selected || _focused ? 1 : 0,
                  duration: _ColorSwatch._duration,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: AppShape.circle.copyWith(
                        side: BorderSide(
                          color: selected ? fill : context.colorScheme.primary,
                          width: _ColorSwatch._ring,
                        ),
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                SizedBox.square(
                  dimension: _ColorSwatch.dot,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: fill,
                      shape: AppShape.circle,
                    ),
                  ),
                ),
                if (color == null)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: _EyedropperBadge(size: _ColorSwatch._badge),
                  ),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: _ColorSwatch._duration,
                  curve: Curves.easeOutBack,
                  child: GlyphIcon(
                    AppGlyphs.check,
                    size: 18,
                    fill: 1,
                    color: check,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final menuItems = widget.menuItems;
    if (menuItems == null) {
      return swatch;
    }
    return ContextMenuRegion(menuItems: menuItems, child: swatch);
  }
}

class _EyedropperBadge extends StatelessWidget {
  const _EyedropperBadge({required this.size});

  static const double _gap = 2;

  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(_gap),
      decoration: ShapeDecoration(
        color: context.surfaceLevel.colorOf(colorScheme),
        shape: AppShape.circle,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: context.raisedSurfaceLevel.colorOf(colorScheme),
          shape: AppShape.circle,
        ),
        child: Center(
          child: GlyphIcon(
            AppGlyphs.eyedropper,
            size: size - _gap * 2 - 4,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _AddColorButton extends StatelessWidget {
  const _AddColorButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Tooltip(
      message: context.appLocalizations.add,
      child: Semantics(
        button: true,
        child: SizedBox.square(
          dimension: _ColorSwatch.size,
          child: Material(
            type: MaterialType.transparency,
            shape: AppShape.circle,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: AppShape.circle,
              onTap: onPressed,
              child: Center(
                child: Container(
                  width: _ColorSwatch.dot,
                  height: _ColorSwatch.dot,
                  decoration: ShapeDecoration(
                    color: context.raisedSurfaceLevel.colorOf(colorScheme),
                    shape: AppShape.circle,
                  ),
                  child: GlyphIcon(
                    AppGlyphs.add,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final _floatingBarProvider = appSettingProvider.select(
  (state) => state.floatingNavigationBar,
);

final _liquidGlassProvider = themeSettingProvider.select(
  (state) => state.liquidGlass != LiquidGlassMode.none,
);

class _PureBlackItem extends ConsumerWidget {
  const _PureBlackItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final pureBlack = ref.watch(
      themeSettingProvider.select((state) => state.pureBlack),
    );
    final floatingBar = ref.watch(_floatingBarProvider);
    final liquidGlass = ref.watch(_liquidGlassProvider);
    Widget preview(bool pureBlack) => MiniScreenThumb(
      screen: MiniScreen(
        colorScheme: ref.watch(
          genColorSchemeProvider(Brightness.dark, pureBlack: pureBlack),
        ),
        floatingBar: floatingBar,
        liquidGlass: liquidGlass,
      ),
    );
    return PreviewChoiceGroup<bool>(
      info: Info(
        label: appLocalizations.pureBlackMode,
        glyph: AppGlyphs.pureBlack,
      ),
      value: pureBlack,
      choices: [
        PreviewChoice(
          value: false,
          label: appLocalizations.standard,
          pictogram: preview(false),
        ),
        PreviewChoice(
          value: true,
          label: appLocalizations.pureBlack,
          pictogram: preview(true),
        ),
      ],
      onChanged: (value) {
        ref
            .read(themeSettingProvider.notifier)
            .update((state) => state.copyWith(pureBlack: value));
      },
    );
  }
}

class _NavigationBarItem extends ConsumerWidget {
  const _NavigationBarItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final floatingBar = ref.watch(_floatingBarProvider);
    final liquidGlass = ref.watch(_liquidGlassProvider);
    final colorScheme = context.colorScheme;
    return PreviewChoiceGroup<bool>(
      info: Info(
        label: appLocalizations.navigationBarStyle,
        glyph: AppGlyphs.layers,
      ),
      value: floatingBar,
      choices: [
        PreviewChoice(
          value: true,
          label: appLocalizations.floating,
          pictogram: MiniScreenThumb(
            screen: MiniScreen(
              colorScheme: colorScheme,
              floatingBar: true,
              liquidGlass: liquidGlass,
            ),
          ),
        ),
        PreviewChoice(
          value: false,
          label: appLocalizations.docked,
          pictogram: MiniScreenThumb(
            screen: MiniScreen(colorScheme: colorScheme, floatingBar: false),
          ),
        ),
      ],
      onChanged: (value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(floatingNavigationBar: value));
      },
    );
  }
}

class _TabAnimationItem extends ConsumerWidget {
  const _TabAnimationItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final tabAnimation = ref.watch(
      appSettingProvider.select((state) => state.tabAnimation),
    );
    final floatingBar = ref.watch(_floatingBarProvider);
    final liquidGlass = ref.watch(_liquidGlassProvider);
    final colorScheme = context.colorScheme;
    Widget switching(TabAnimation tabAnimation) => MiniScreenThumb(
      screen: MiniScreen(
        colorScheme: colorScheme,
        floatingBar: floatingBar,
        liquidGlass: liquidGlass,
        selected: 1,
        previous: 0,
        progress: 0.55,
        tabAnimation: tabAnimation,
      ),
    );
    return PreviewChoiceGroup<TabAnimation>(
      info: Info(label: appLocalizations.tabAnimation, glyph: AppGlyphs.motion),
      value: tabAnimation,
      choices: [
        PreviewChoice(
          value: TabAnimation.slide,
          label: appLocalizations.slide,
          pictogram: switching(TabAnimation.slide),
        ),
        PreviewChoice(
          value: TabAnimation.fade,
          label: appLocalizations.fade,
          pictogram: switching(TabAnimation.fade),
        ),
      ],
      onChanged: (value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(tabAnimation: value));
      },
    );
  }
}

class _LiquidGlassItem extends ConsumerWidget {
  const _LiquidGlassItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final mode = ref.watch(
      themeSettingProvider.select((state) => state.liquidGlass),
    );
    final colorScheme = context.colorScheme;
    // Floating either way, as a docked bar stays a fill, over the list page,
    // whose rows run on under the bar where glass shows them.
    Widget preview(bool liquidGlass) => MiniScreenThumb(
      screen: MiniScreen(
        colorScheme: colorScheme,
        floatingBar: true,
        liquidGlass: liquidGlass,
        selected: 1,
      ),
    );
    return PreviewChoiceGroup<LiquidGlassMode>(
      info: Info(
        label: appLocalizations.liquidGlass,
        glyph: AppGlyphs.liquidGlass,
      ),
      value: mode,
      choices: [
        PreviewChoice(
          value: LiquidGlassMode.none,
          label: appLocalizations.none,
          pictogram: preview(false),
        ),
        PreviewChoice(
          value: LiquidGlassMode.standard,
          label: appLocalizations.standard,
          pictogram: preview(true),
        ),
        PreviewChoice(
          value: LiquidGlassMode.ultra,
          label: appLocalizations.ultra,
          pictogram: preview(true),
        ),
      ],
      onChanged: (value) {
        ref
            .read(themeSettingProvider.notifier)
            .update((state) => state.copyWith(liquidGlass: value));
      },
    );
  }
}

class _SidebarBlurItem extends ConsumerWidget {
  const _SidebarBlurItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!feature.sidebarBlur || (!system.isMacOS && !system.isWindows)) {
      return const SizedBox.shrink();
    }
    final appLocalizations = context.appLocalizations;
    final sidebarBlur = ref.watch(
      themeSettingProvider.select((state) => state.sidebarBlur),
    );
    return ListItem.toggle(
      leading: const GlyphIcon(AppGlyphs.blur),
      horizontalTitleGap: 12,
      title: Text(
        appLocalizations.sidebarBlur,
        style: AppTextStyle.subheadline
            .of(context, emphasized: true)
            .copyWith(color: context.colorScheme.onSurfaceVariant),
      ),
      subtitle: Text(appLocalizations.sidebarBlurDesc),
      value: sidebarBlur,
      onChanged: (value) {
        ref
            .read(themeSettingProvider.notifier)
            .update((state) => state.copyWith(sidebarBlur: value));
      },
    );
  }
}

class _FontFamilyItem extends ConsumerWidget {
  const _FontFamilyItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final fontFamily = ref.watch(
      themeSettingProvider.select((state) => state.fontFamily),
    );
    final preview = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        spacing: 12,
        children: [
          Text(
            'Aa',
            style: AppTextStyle.headline
                .of(context)
                .copyWith(fontFamily: fontFamily),
          ),
          Expanded(
            child: Text(
              fontFamily ?? appLocalizations.defaultText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.subheadline
                  .of(context)
                  .copyWith(
                    fontFamily: fontFamily,
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          GlyphIcon(
            AppGlyphs.chevronForward,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
    final cardColor = context.raisedSurfaceLevel.colorOf(colorScheme);
    Widget card(VoidCallback onTap) => Material(
      color: cardColor,
      shape: AppShape.lg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(customBorder: AppShape.lg, onTap: onTap, child: preview),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoHeader(
          info: Info(label: appLocalizations.fontFamily, glyph: AppGlyphs.font),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: context.isMobileView
              ? OpenContainer<void>(
                  closedShape: AppShape.lg,
                  closedColor: cardColor,
                  closedBuilder: (_, open) => card(open),
                  openBuilder: (_, _) => const FontFamilyView(),
                )
              : card(
                  () => showSheet<void>(
                    context: context,
                    builder: (_) => const FontFamilyView(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _TextScaleFactorItem extends ConsumerStatefulWidget {
  const _TextScaleFactorItem();

  static const _step = 0.05;

  @override
  ConsumerState<_TextScaleFactorItem> createState() =>
      _TextScaleFactorItemState();
}

class _TextScaleFactorItemState extends ConsumerState<_TextScaleFactorItem> {
  double? _draft;

  void _update(TextScale Function(TextScale textScale) update) {
    setState(() => _draft = null);
    ref
        .read(themeSettingProvider.notifier)
        .update((state) => state.copyWith(textScale: update(state.textScale)));
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final textScale = ref.watch(
      themeSettingProvider.select((state) => state.textScale),
    );
    final systemScale = systemTextScaleOf(
      context,
    ).clamp(minTextScale, maxTextScale).toDouble();
    final scale = _draft ?? (textScale.enable ? textScale.scale : systemScale);
    final percent = '${(scale * 100).round()}%';
    final level = context.raisedSurfaceLevel;
    final divisions =
        ((maxTextScale - minTextScale) / _TextScaleFactorItem._step).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoHeader(
          info: Info(
            label: appLocalizations.textScale,
            glyph: AppGlyphs.textSize,
          ),
          actions: [
            if (textScale.enable && textScale.scale != 1)
              _ResetButton(
                onPressed: () => _update((state) => state.copyWith(scale: 1)),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            spacing: 8,
            children: [
              SegmentedControl<bool>(
                segments: [
                  (false, appLocalizations.followSystem),
                  (true, appLocalizations.custom),
                ],
                value: textScale.enable,
                onChanged: (value) =>
                    _update((state) => state.copyWith(enable: value)),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: ShapeDecoration(
                  color: level.colorOf(colorScheme),
                  shape: AppShape.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: [
                        Expanded(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topLeft,
                            child: MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(textScaler: TextScaler.linear(scale)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 4,
                                children: [
                                  Text(
                                    'Aa',
                                    style: AppTextStyle.title3.of(context),
                                  ),
                                  Text(
                                    appLocalizations.textScalePreview,
                                    style: AppTextStyle.subheadline
                                        .of(context)
                                        .copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: ShapeDecoration(
                            color: level.next.colorOf(colorScheme),
                            shape: AppShape.full,
                          ),
                          child: Text(
                            percent,
                            style: AppTextStyle.subheadline
                                .of(context, emphasized: true)
                                .copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MediaQuery.withNoTextScaling(
                      child: Row(
                        spacing: 12,
                        children: [
                          ExcludeSemantics(
                            child: Text(
                              'A',
                              style: AppTextStyle.footnote
                                  .of(context)
                                  .copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderDefaultsM3(context),
                              child: Slider(
                                padding: EdgeInsets.zero,
                                min: minTextScale,
                                max: maxTextScale,
                                divisions: divisions,
                                value: scale,
                                label: percent,
                                onChanged: textScale.enable
                                    ? (value) => setState(() => _draft = value)
                                    : null,
                                onChangeEnd: (value) => _update(
                                  (state) => state.copyWith(scale: value),
                                ),
                              ),
                            ),
                          ),
                          ExcludeSemantics(
                            child: Text(
                              'A',
                              style: AppTextStyle.title2
                                  .of(context)
                                  .copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TonalButtonTheme(
      size: TonalButtonSize.section,
      child: ElasticPress(
        child: IconButton(
          tooltip: context.appLocalizations.reset,
          onPressed: onPressed,
          icon: const GlyphIcon(AppGlyphs.reset),
        ),
      ),
    );
  }
}

class _CustomColorSheet extends StatefulWidget {
  const _CustomColorSheet({
    required this.initialColor,
    required this.onConfirmed,
  });

  final Color initialColor;

  /// Runs once the sheet has closed, so retheming every page cannot stall it.
  final ValueChanged<int> onConfirmed;

  @override
  State<_CustomColorSheet> createState() => _CustomColorSheetState();
}

class _CustomColorSheetState extends State<_CustomColorSheet> {
  late final _controller = ValueNotifier<Color>(widget.initialColor);

  void _confirm() {
    final color = _controller.value.toARGB32();
    final onConfirmed = widget.onConfirmed;
    unawaited(
      ModalRoute.of(context)!.completed.whenComplete(() => onConfirmed(color)),
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    // Clears Android's edge back-swipe zone; exclusion rects stop at 200 dp.
    final gestureInsets = MediaQuery.systemGestureInsetsOf(context);
    return CommonScaffold(
      title: appLocalizations.customColor,
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: appLocalizations.confirm,
        onPressed: _confirm,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          max(16, gestureInsets.left),
          context.contentTopPadding,
          max(16, gestureInsets.right),
          20,
        ),
        children: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (_, color, _) => _CustomColorPreview(
              color: color,
              onChanged: (color) => _controller.value = color,
            ),
          ),
          const SizedBox(height: 16),
          Palette(controller: _controller),
        ],
      ),
    );
  }
}

class _CustomColorPreview extends ConsumerWidget {
  const _CustomColorPreview({required this.color, required this.onChanged});

  static const Size _screenSize = Size(96, 128);
  static const double _scale = 0.75;

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floatingBar = ref.watch(_floatingBarProvider);
    final liquidGlass = ref.watch(_liquidGlassProvider);
    final level = context.raisedSurfaceLevel;
    Widget screen(Brightness brightness) => ExcludeSemantics(
      child: SizedBox.fromSize(
        size: _screenSize * _scale,
        child: ClipRSuperellipse(
          borderRadius: AppRadius.md,
          child: FittedBox(
            child: SizedBox.fromSize(
              size: _screenSize,
              child: MiniScreen(
                colorScheme: ref.watch(
                  genColorSchemeProvider(brightness, color: color),
                ),
                floatingBar: floatingBar,
                liquidGlass: liquidGlass,
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: level.colorOf(context.colorScheme),
        shape: AppShape.xl,
      ),
      child: SurfaceScope(
        level: level,
        child: Row(
          spacing: 12,
          children: [
            screen(Brightness.light),
            screen(Brightness.dark),
            Expanded(
              child: HexColorField(color: color, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundImageItem extends ConsumerStatefulWidget {
  const _BackgroundImageItem();

  @override
  ConsumerState<_BackgroundImageItem> createState() =>
      _BackgroundImageItemState();
}

class _BackgroundImageItemState extends ConsumerState<_BackgroundImageItem> {
  Future<void> _handleAdd() async {
    final path = await picker.pickerImage();
    if (path == null) {
      return;
    }
    // The picker hands over a path inside its own cache, which the system may
    // clear between launches; only the copy survives that.
    final storedPath = await globalState.safeRun(
      () => backgroundHelper.persistImage(path),
    );
    if (storedPath == null || !mounted) {
      return;
    }
    ref.read(themeSettingProvider.notifier).update((state) {
      final backgroundImages = List<String>.from(state.backgroundImages);
      if (!backgroundImages.contains(storedPath)) {
        backgroundImages.add(storedPath);
      }
      return state.copyWith(
        backgroundImage: storedPath,
        backgroundImages: backgroundImages,
      );
    });
  }

  Future<void> _handleDel(String imagePath) async {
    final appLocalizations = context.appLocalizations;
    final res = await dialogs.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.backgroundImage),
      ),
      destructive: true,
      confirmText: appLocalizations.delete,
    );
    if (res != true || !mounted) {
      return;
    }
    ref.read(themeSettingProvider.notifier).update((state) {
      final backgroundImages = List<String>.from(state.backgroundImages)
        ..remove(imagePath);
      return state.copyWith(
        backgroundImages: backgroundImages,
        backgroundImage: state.backgroundImage == imagePath
            ? (backgroundImages.isNotEmpty ? backgroundImages.first : '')
            : state.backgroundImage,
      );
    });
    // The setting is already gone; a file that cannot be removed only leaves a
    // copy behind, so it must not fail the interaction.
    await globalState.safeRun(() => backgroundHelper.deleteImage(imagePath));
  }

  void _handleSelect(String imagePath) {
    ref.read(themeSettingProvider.notifier).update((state) {
      if (state.backgroundImage == imagePath) {
        return state;
      }
      return state.copyWith(backgroundImage: imagePath);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final themeProps = ref.watch(themeSettingProvider);
    final backgroundImages = themeProps.backgroundImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListItem.toggle(
          leading: const GlyphIcon(AppGlyphs.photos),
          horizontalTitleGap: 12,
          title: Text(
            appLocalizations.backgroundImage,
            style: AppTextStyle.subheadline
                .of(context, emphasized: true)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          subtitle: Text(appLocalizations.backgroundImageDesc),
          value: themeProps.backgroundImageEnabled,
          onChanged: (value) {
            ref
                .read(themeSettingProvider.notifier)
                .update(
                  (state) => state.copyWith(backgroundImageEnabled: value),
                );
          },
        ),
        if (backgroundImages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              appLocalizations.noBackgroundImage,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _BackgroundImageGrid(
            images: backgroundImages,
            selectedImage: themeProps.backgroundImage,
            onSelect: _handleSelect,
            onDelete: _handleDel,
            onAdd: _handleAdd,
          ),
        ),
        if (backgroundImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          _BackgroundOpacityItem(
            opacity: themeProps.backgroundOpacity,
            enabled: themeProps.backgroundImageEnabled,
          ),
        ],
      ],
    );
  }
}

class _BackgroundImageGrid extends StatelessWidget {
  const _BackgroundImageGrid({
    required this.images,
    required this.selectedImage,
    required this.onSelect,
    required this.onDelete,
    required this.onAdd,
  });

  static const double tile = 88;
  static const double _gap = 8;

  final List<String> images;
  final String selectedImage;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final level = context.raisedSurfaceLevel;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: level.colorOf(colorScheme),
        shape: AppShape.xl,
      ),
      child: SurfaceScope(
        level: level,
        child: LayoutBuilder(
          builder: (_, constraints) {
            final width = constraints.maxWidth;
            final columns = max(1, ((width + _gap) / (tile + _gap)).floor());
            final spacing = columns > 1
                ? ((width - columns * tile) / (columns - 1)).floorToDouble()
                : 0.0;
            return Wrap(
              spacing: spacing,
              runSpacing: _gap,
              children: [
                for (final imagePath in images)
                  _BackgroundImageTile(
                    imagePath: imagePath,
                    isSelected: imagePath == selectedImage,
                    onSelect: () => onSelect(imagePath),
                    onDelete: () => onDelete(imagePath),
                  ),
                _AddBackgroundTile(onPressed: onAdd),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BackgroundImageTile extends StatefulWidget {
  const _BackgroundImageTile({
    required this.imagePath,
    required this.isSelected,
    required this.onSelect,
    required this.onDelete,
  });

  final String imagePath;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  State<_BackgroundImageTile> createState() => _BackgroundImageTileState();
}

class _BackgroundImageTileState extends State<_BackgroundImageTile> {
  static const double _ring = 2.5;
  static const _duration = Duration(milliseconds: 200);

  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    // A thumbnail decodes to its own box; a wallpaper-sized bitmap per tile
    // would stall the frame it appears in.
    final cacheWidth =
        (_BackgroundImageGrid.tile * MediaQuery.devicePixelRatioOf(context))
            .round();
    return ContextMenuRegion(
      menuItems: [
        CommonPopupMenuItem(
          danger: true,
          glyph: AppGlyphs.delete,
          label: appLocalizations.delete,
          onPressed: widget.onDelete,
        ),
      ],
      child: Semantics(
        button: true,
        selected: widget.isSelected,
        label: appLocalizations.backgroundImage,
        child: SizedBox.square(
          dimension: _BackgroundImageGrid.tile,
          child: Material(
            type: MaterialType.transparency,
            shape: AppShape.lg,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: AppShape.lg,
              onTap: widget.onSelect,
              onFocusChange: (value) => setState(() => _focused = value),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.cover,
                    cacheWidth: cacheWidth,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: colorScheme.errorContainer,
                      child: Center(
                        child: GlyphIcon(
                          AppGlyphs.error,
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: widget.isSelected || _focused ? 1 : 0,
                    duration: _duration,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: AppShape.lg.copyWith(
                          side: BorderSide(
                            color: colorScheme.primary,
                            width: _ring,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.isSelected)
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: SelectionBadge(size: 22),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddBackgroundTile extends StatelessWidget {
  const _AddBackgroundTile({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Semantics(
      button: true,
      label: context.appLocalizations.add,
      child: SizedBox.square(
        dimension: _BackgroundImageGrid.tile,
        child: Material(
          type: MaterialType.transparency,
          shape: AppShape.lg,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: AppShape.lg,
            onTap: onPressed,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: ShapeDecoration(
                  color: context.raisedSurfaceLevel.colorOf(colorScheme),
                  shape: AppShape.circle,
                ),
                child: GlyphIcon(
                  AppGlyphs.add,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundOpacityItem extends ConsumerStatefulWidget {
  const _BackgroundOpacityItem({required this.opacity, required this.enabled});

  final double opacity;
  final bool enabled;

  @override
  ConsumerState<_BackgroundOpacityItem> createState() =>
      _BackgroundOpacityItemState();
}

class _BackgroundOpacityItemState
    extends ConsumerState<_BackgroundOpacityItem> {
  double? _draft;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final value = _draft ?? widget.opacity;
    final percent = '${(value * 100).round()}%';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appLocalizations.backgroundOpacity,
            style: AppTextStyle.subheadline
                .of(context, emphasized: true)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          MediaQuery.withNoTextScaling(
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: DisabledMask(
                    status: !widget.enabled,
                    child: ActivateBox(
                      active: widget.enabled,
                      child: SliderTheme(
                        data: SliderDefaultsM3(context),
                        child: Slider(
                          padding: EdgeInsets.zero,
                          min: minBackgroundOpacity,
                          max: maxBackgroundOpacity,
                          divisions: 20,
                          value: value,
                          label: percent,
                          onChanged: widget.enabled
                              ? (value) => setState(() => _draft = value)
                              : null,
                          onChangeEnd: (value) {
                            ref
                                .read(themeSettingProvider.notifier)
                                .update(
                                  (state) =>
                                      state.copyWith(backgroundOpacity: value),
                                );
                            setState(() => _draft = null);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                ExcludeSemantics(
                  child: SizedBox(
                    width: 44,
                    child: Text(
                      percent,
                      textAlign: TextAlign.end,
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
