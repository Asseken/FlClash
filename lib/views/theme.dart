// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart'
    hide IconButton, FilledButton, Colors, Slider, SliderTheme;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_color_utilities/hct/hct.dart';

int _calcGridColumns(double maxWidth) {
  return max((maxWidth / 96).ceil(), 3);
}

class ThemeModeItem {
  final ThemeMode themeMode;
  final IconData iconData;
  final String label;

  const ThemeModeItem({
    required this.themeMode,
    required this.iconData,
    required this.label,
  });
}

class FontFamilyItem {
  final FontFamily fontFamily;
  final String label;

  const FontFamilyItem({required this.fontFamily, required this.label});
}

class ThemeView extends StatelessWidget {
  const ThemeView({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return BaseScaffold(
      title: appLocalizations.theme,
      body: const CustomScrollView(
        slivers: [
          _ThemeModeItem(),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          _PrimaryColorItem(),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          _PrueBlackItem(),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          _TextScaleFactorItem(),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          _BackgroundImageItem(),
          SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
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
  String? _removableImage;

  Future<void> _handleAdd() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final persisted = await backgroundHelper.persistImage(image.path);
    if (!mounted) {
      // 组件已卸载：本次若复制了新文件则清理掉，避免孤儿文件
      if (persisted.created) {
        await backgroundHelper.deleteImage(persisted.path);
      }
      return;
    }
    final state = ref.read(themeSettingProvider);
    final newList = List<String>.from(state.backgroundImages)
      ..remove(persisted.path)
      ..insert(0, persisted.path);
    ref
        .read(themeSettingProvider.notifier)
        .update(
          (s) => s.copyWith(
            backgroundImage: persisted.path,
            backgroundImages: newList,
          ),
        );
  }

  Future<void> _handleDel(String path) async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.backgroundImage),
      ),
    );
    if (res != true) return;

    // deleteImage 内部有目录守卫，仅删除 background 目录内的文件
    await backgroundHelper.deleteImage(path);

    if (!mounted) return;
    setState(() {
      _removableImage = null;
    });
    ref.read(themeSettingProvider.notifier).update((state) {
      final newList = List<String>.from(state.backgroundImages)..remove(path);
      String newSelected = state.backgroundImage;
      if (state.backgroundImage == path) {
        newSelected = newList.isNotEmpty ? newList.first : '';
      }
      return state.copyWith(
        backgroundImage: newSelected,
        backgroundImages: newList,
        backgroundOpacity: newList.isEmpty ? 1.0 : state.backgroundOpacity,
      );
    });
  }

  void _handleSelect(String path) {
    setState(() {
      _removableImage = null;
    });
    ref.read(themeSettingProvider.notifier).update((state) {
      if (state.backgroundImage == path) return state;
      return state.copyWith(backgroundImage: path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final backgroundImage = ref.watch(
      themeSettingProvider.select((state) => state.backgroundImage),
    );
    final backgroundImages = ref.watch(
      themeSettingProvider.select((state) => state.backgroundImages),
    );
    final backgroundOpacity = ref.watch(
      themeSettingProvider.select((state) => state.backgroundOpacity),
    );
    final process = '${(backgroundOpacity * 100).round()}%';

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListItem.toggle(
              horizontalTitleGap: 12,
              leading: const Icon(WindowsIcons.picture),
              title: Text(
                appLocalizations.backgroundImageDesc,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              value: ref.watch(
                themeSettingProvider.select((s) => s.backgroundImageEnabled),
              ),
              onChanged: (value) {
                ref
                    .read(themeSettingProvider.notifier)
                    .update(
                      (state) => state.copyWith(backgroundImageEnabled: value),
                    );
              },
            ),
          ),
          if (backgroundImages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                appLocalizations.noBackgroundImage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (_, constraints) {
                final columns = _calcGridColumns(constraints.maxWidth);
                final itemWidth =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final imagePath in backgroundImages)
                      Container(
                        clipBehavior: Clip.none,
                        width: itemWidth,
                        height: itemWidth,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            EffectGestureDetector(
                              onTap: () => _handleSelect(imagePath),
                              onLongPress: () {
                                setState(() {
                                  _removableImage = imagePath;
                                });
                              },
                              child: CommonCard(
                                isSelected: imagePath == backgroundImage,
                                child: Stack(
                                  children: [
                                    SizedBox(
                                      width: itemWidth,
                                      height: itemWidth,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(imagePath),
                                          fit: BoxFit.cover,
                                          cacheWidth: 200,
                                          errorBuilder: (_, _, _) => Container(
                                            color: context
                                                .colorScheme
                                                .errorContainer,
                                            child: Center(
                                              child: Icon(
                                                Icons.broken_image,
                                                color: context
                                                    .colorScheme
                                                    .onErrorContainer,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (imagePath == backgroundImage)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: context.colorScheme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            WindowsIcons.check_mark,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            if (_removableImage != null &&
                                _removableImage == imagePath)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: context.colorScheme.surface
                                        .withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: IconButton.filledTonal(
                                      onPressed: () => _handleDel(imagePath),
                                      padding: const EdgeInsets.all(12),
                                      iconSize: 30,
                                      icon: Icon(
                                        color: context.colorScheme.primary,
                                        WindowsIcons.delete,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (_removableImage == null)
                      Container(
                        width: itemWidth,
                        height: itemWidth,
                        padding: const EdgeInsets.all(4),
                        child: IconButton.filledTonal(
                          onPressed: _handleAdd,
                          iconSize: 32,
                          icon: Icon(
                            color: context.colorScheme.primary,
                            WindowsIcons.add,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (backgroundImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                spacing: 32,
                children: [
                  Expanded(
                    child: Text(
                      appLocalizations.backgroundOpacity,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: DisabledMask(
                      status: !ref.watch(
                        themeSettingProvider.select(
                          (s) => s.backgroundImageEnabled,
                        ),
                      ),
                      child: ActivateBox(
                        active: ref.watch(
                          themeSettingProvider.select(
                            (s) => s.backgroundImageEnabled,
                          ),
                        ),
                        child: SliderTheme(
                          data: SliderDefaultsM3(context),
                          child: Slider(
                            padding: EdgeInsets.zero,
                            min: 0.1,
                            max: 1.0,
                            value: backgroundOpacity,
                            onChanged: (value) {
                              ref
                                  .read(themeSettingProvider.notifier)
                                  .update(
                                    (state) => state.copyWith(
                                      backgroundOpacity: value,
                                    ),
                                  );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(process, style: context.textTheme.titleMedium),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final Widget child;
  final Info info;
  final List<Widget> actions;

  const ItemCard({
    super.key,
    required this.info,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 16,
      children: [
        InfoHeader(info: info, actions: actions),
        child,
      ],
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
    final List<ThemeModeItem> themeModeItems = [
      ThemeModeItem(
        iconData: WindowsIcons.repeat_all,
        label: appLocalizations.auto,
        themeMode: ThemeMode.system,
      ),
      ThemeModeItem(
        iconData: FluentIcons.lightbulb,
        label: appLocalizations.light,
        themeMode: ThemeMode.light,
      ),
      ThemeModeItem(
        iconData: FluentIcons.lightbulb_solid,
        label: appLocalizations.dark,
        themeMode: ThemeMode.dark,
      ),
    ];
    return SliverToBoxAdapter(
      child: ItemCard(
        info: Info(
          label: appLocalizations.themeMode,
          iconData: WindowsIcons.developer_tools,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: themeModeItems.length,
            itemBuilder: (_, index) {
              final themeModeItem = themeModeItems[index];
              return CommonCard(
                isSelected: themeModeItem.themeMode == themeMode,
                onPressed: () {
                  ref
                      .read(themeSettingProvider.notifier)
                      .update(
                        (state) =>
                            state.copyWith(themeMode: themeModeItem.themeMode),
                      );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Flexible(child: Icon(themeModeItem.iconData)),
                      const SizedBox(width: 8),
                      Flexible(child: Text(themeModeItem.label)),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, _) {
              return const SizedBox(width: 16);
            },
          ),
        ),
      ),
    );
  }
}

class _PrimaryColorItem extends ConsumerStatefulWidget {
  const _PrimaryColorItem();

  @override
  ConsumerState<_PrimaryColorItem> createState() => _PrimaryColorItemState();
}

class _PrimaryColorItemState extends ConsumerState<_PrimaryColorItem> {
  int? _removablePrimaryColor;

  Future<void> _handleReset() async {
    final res = await globalState.showMessage(
      message: TextSpan(text: context.appLocalizations.resetTip),
    );
    if (res != true) {
      return;
    }
    ref.read(themeSettingProvider.notifier).update((state) {
      return state.copyWith(
        primaryColors: defaultPrimaryColors,
        primaryColor: defaultPrimaryColor,
        schemeVariant: DynamicSchemeVariant.content,
      );
    });
  }

  Future<void> _handleDel() async {
    final appLocalizations = context.appLocalizations;
    if (_removablePrimaryColor == null) {
      return;
    }
    final res = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.colorSchemes),
      ),
    );
    if (res != true) {
      return;
    }
    ref.read(themeSettingProvider.notifier).update((state) {
      final newPrimaryColors = List<int>.from(state.primaryColors)
        ..remove(_removablePrimaryColor);
      int? newPrimaryColor = state.primaryColor;
      if (state.primaryColor == _removablePrimaryColor) {
        if (newPrimaryColors.contains(defaultPrimaryColor)) {
          newPrimaryColor = defaultPrimaryColor;
        } else {
          newPrimaryColor = null;
        }
      }
      return state.copyWith(
        primaryColors: newPrimaryColors,
        primaryColor: newPrimaryColor,
      );
    });
    setState(() {
      _removablePrimaryColor = null;
    });
  }

  Future<void> _handleAdd() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.showCommonDialog<int>(
      child: const _PaletteDialog(),
    );
    if (res == null) {
      return;
    }
    final isExists = ref.read(
      themeSettingProvider.select((state) => state.primaryColors.contains(res)),
    );
    if (isExists && mounted) {
      context.showNotifier(
        appLocalizations.existsTip(appLocalizations.colorSchemes),
      );
      return;
    }
    ref.read(themeSettingProvider.notifier).update((state) {
      return state.copyWith(
        primaryColors: List.from(state.primaryColors)..add(res),
      );
    });
  }

  Future<void> _handleChangeSchemeVariant() async {
    final schemeVariant = ref.read(
      themeSettingProvider.select((state) => state.schemeVariant),
    );
    final value = await globalState.showCommonDialog<DynamicSchemeVariant>(
      child: OptionsDialog<DynamicSchemeVariant>(
        title: context.appLocalizations.colorSchemes,
        options: DynamicSchemeVariant.values,
        textBuilder: (item) => Intl.message('${item.name}Scheme'),
        value: schemeVariant,
      ),
    );
    if (value == null) {
      return;
    }
    ref.read(themeSettingProvider.notifier).update((state) {
      return state.copyWith(schemeVariant: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final vm4 = ref.watch(
      themeSettingProvider.select(
        (state) => VM4(
          state.primaryColor,
          state.primaryColors,
          state.schemeVariant,
          state.primaryColor == defaultPrimaryColor &&
              intListEquality.equals(
                state.primaryColors,
                defaultPrimaryColors,
              ) &&
              state.schemeVariant == DynamicSchemeVariant.content,
        ),
      ),
    );
    final primaryColor = vm4.a;
    final primaryColors = [null, ...vm4.b];
    final schemeVariant = vm4.c;
    final isEquals = vm4.d;

    return SliverToBoxAdapter(
      child: CommonPopScope(
        onPop: (context) {
          if (_removablePrimaryColor != null) {
            setState(() {
              _removablePrimaryColor = null;
            });
            return false;
          }
          return true;
        },
        child: ItemCard(
          info: Info(
            label: appLocalizations.themeColor,
            iconData: WindowsIcons.color,
          ),
          actions: genActions([
            if (_removablePrimaryColor == null)
              FilledButton(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _handleChangeSchemeVariant,
                child: Text(Intl.message('${schemeVariant.name}Scheme')),
              ),
            if (_removablePrimaryColor != null)
              FilledButton(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  setState(() {
                    _removablePrimaryColor = null;
                  });
                },
                child: Text(appLocalizations.cancel),
              ),
            if (_removablePrimaryColor == null && !isEquals)
              IconButton.filledTonal(
                iconSize: 20,
                padding: const EdgeInsets.all(4),
                visualDensity: VisualDensity.compact,
                onPressed: _handleReset,
                icon: const Icon(WindowsIcons.update_restore),
              ),
          ], space: 8),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (_, constraints) {
                final columns = _calcGridColumns(constraints.maxWidth);
                final itemWidth =
                    (constraints.maxWidth - (columns - 1) * 16) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final color in primaryColors)
                      Container(
                        clipBehavior: Clip.none,
                        width: itemWidth,
                        height: itemWidth,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            EffectGestureDetector(
                              child: ColorSchemeBox(
                                isSelected: color == primaryColor,
                                primaryColor: color != null
                                    ? Color(color)
                                    : null,
                                onPressed: () {
                                  setState(() {
                                    _removablePrimaryColor = null;
                                  });
                                  ref
                                      .read(themeSettingProvider.notifier)
                                      .update(
                                        (state) =>
                                            state.copyWith(primaryColor: color),
                                      );
                                },
                              ),
                              onLongPress: () {
                                setState(() {
                                  _removablePrimaryColor = color;
                                });
                              },
                            ),
                            if (_removablePrimaryColor != null &&
                                _removablePrimaryColor == color)
                              Container(
                                color: Colors.white.opacity0,
                                padding: const EdgeInsets.all(8),
                                child: IconButton.filledTonal(
                                  onPressed: _handleDel,
                                  padding: const EdgeInsets.all(12),
                                  iconSize: 30,
                                  icon: Icon(
                                    color: context.colorScheme.primary,
                                    WindowsIcons.delete,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (_removablePrimaryColor == null)
                      Container(
                        width: itemWidth,
                        height: itemWidth,
                        padding: const EdgeInsets.all(4),
                        child: IconButton.filledTonal(
                          onPressed: _handleAdd,
                          iconSize: 32,
                          icon: Icon(
                            color: context.colorScheme.primary,
                            WindowsIcons.add,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PrueBlackItem extends ConsumerWidget {
  const _PrueBlackItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final prueBlack = ref.watch(
      themeSettingProvider.select((state) => state.pureBlack),
    );
    return SliverToBoxAdapter(
      child: ListItem.toggle(
        leading: const Icon(WindowsIcons.contrast),
        horizontalTitleGap: 12,
        title: Text(
          appLocalizations.pureBlackMode,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        value: prueBlack,
        onChanged: (value) {
          ref
              .read(themeSettingProvider.notifier)
              .update((state) => state.copyWith(pureBlack: value));
        },
      ),
    );
  }
}

class _TextScaleFactorItem extends ConsumerWidget {
  const _TextScaleFactorItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final textScale = ref.watch(
      themeSettingProvider.select((state) => state.textScale),
    );
    final String process = '${(textScale.scale * 100).round()}%';
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListItem.toggle(
              leading: const Icon(FluentIcons.text_field),
              horizontalTitleGap: 12,
              title: Text(
                appLocalizations.textScale,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              value: textScale.enable,
              onChanged: (value) {
                ref
                    .read(themeSettingProvider.notifier)
                    .update((state) => state.copyWith.textScale(enable: value));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              spacing: 32,
              children: [
                Expanded(
                  child: DisabledMask(
                    status: !textScale.enable,
                    child: ActivateBox(
                      active: textScale.enable,
                      child: SliderTheme(
                        data: SliderDefaultsM3(context),
                        child: Slider(
                          padding: EdgeInsets.zero,
                          min: minTextScale,
                          max: maxTextScale,
                          value: textScale.scale,
                          onChanged: (value) {
                            ref
                                .read(themeSettingProvider.notifier)
                                .update(
                                  (state) =>
                                      state.copyWith.textScale(scale: value),
                                );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(process, style: context.textTheme.titleMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteDialog extends StatefulWidget {
  const _PaletteDialog();

  @override
  State<_PaletteDialog> createState() => _PaletteDialogState();
}

class _PaletteDialogState extends State<_PaletteDialog> {
  final _controller = ValueNotifier<Color>(Color(Hct.from(0, 0, 60).toInt()));

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.palette,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_controller.value.toARGB32());
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 300, child: Palette(controller: _controller)),
        ],
      ),
    );
  }
}
