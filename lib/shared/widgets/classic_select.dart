import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// One row of a [ClassicSelect] / [ClassicSelectChip].
@immutable
class ClassicOption<T> {
  const ClassicOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Opens a classic Material menu anchored to the widget that calls it.
///
/// `DropdownButton` sizes its menu to the *button*, so an `isExpanded` field
/// inside a wide row produced a menu as wide as the page, glued to the window
/// edge. This helper instead:
///  * keeps a readable menu width (112–320dp by default, never the page width);
///  * keeps a 16dp margin to the window edge on every side;
///  * anchors the menu under the trigger, left-aligned, flipping up only when
///    there is genuinely no room below.
Future<T?> showClassicMenu<T>({
  required BuildContext context,
  required BuildContext anchorContext,
  required List<ClassicOption<T>> options,
  T? current,
  double minWidth = 160,
  double maxWidth = 320,
}) async {
  final ThemeData theme = Theme.of(context);
  final Size window = MediaQuery.sizeOf(context);
  const double margin = 16;

  Offset topLeft = Offset.zero;
  double anchorWidth = minWidth;
  double anchorHeight = 0;
  final RenderObject? render = anchorContext.findRenderObject();
  if (render is RenderBox && render.hasSize) {
    topLeft = render.localToGlobal(Offset.zero);
    anchorWidth = render.size.width;
    anchorHeight = render.size.height;
  }

  final double available = (window.width - margin * 2).clamp(
    minWidth,
    window.width,
  );
  final double width = anchorWidth
      .clamp(minWidth, maxWidth)
      .clamp(minWidth, available);
  final double maxLeft = (window.width - margin - width).clamp(
    margin,
    window.width,
  );
  final double left = topLeft.dx.clamp(margin, maxLeft);
  final double top = topLeft.dy + anchorHeight + 4;

  final T? result = await showMenu<T>(
    context: context,
    position: RelativeRect.fromLTRB(left, top, window.width - left - width, 0),
    constraints: BoxConstraints(minWidth: width, maxWidth: width),
    items: <PopupMenuEntry<T>>[
      for (final ClassicOption<T> option in options)
        PopupMenuItem<T>(
          value: option.value,
          height: 48,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (option.value == current) ...<Widget>[
                AppSpacing.w8,
                Icon(
                  Icons.check,
                  size: AppDimens.iconSizeSmall,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
    ],
  );
  return result;
}

/// Classic select field: outlined box, label, current value, drop-down arrow.
///
/// Used everywhere a `DropdownButtonFormField` used to be, so every selector in
/// the app opens the same constrained menu instead of a full-width one.
class ClassicSelect<T> extends StatelessWidget {
  const ClassicSelect({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final List<ClassicOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  ClassicOption<T>? get _selected {
    for (final ClassicOption<T> option in options) {
      if (option.value == value) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ClassicOption<T>? selected = _selected;
    return Builder(
      builder: (BuildContext anchorContext) => InkWell(
        onTap: !enabled || onChanged == null
            ? null
            : () async {
                final T? picked = await showClassicMenu<T>(
                  context: context,
                  anchorContext: anchorContext,
                  options: options,
                  current: value,
                );
                if (picked != null) onChanged!(picked);
              },
        child: InputDecorator(
          isEmpty: selected == null,
          decoration: InputDecoration(
            labelText: label,
            enabled: enabled,
            suffixIcon: Icon(
              Icons.arrow_drop_down,
              color: enabled ? theme.textTheme.bodySmall?.color : null,
            ),
          ),
          child: Text(
            selected?.label ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

/// Compact rectangular selector for toolbar/filter rows.
///
/// A 36dp outlined box with a 2dp radius: the trigger looks like a filter, not
/// like a chip *and* a text field, and the menu it opens is the shared one.
class ClassicSelectChip<T> extends StatelessWidget {
  const ClassicSelectChip({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  /// Shown while the first option ("all"/"any") is selected.
  final String label;
  final List<ClassicOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    ClassicOption<T>? selected;
    for (final ClassicOption<T> option in options) {
      if (option.value == value) selected = option;
    }
    final bool active = selected != null && selected != options.first;
    final String text = active ? selected.label : label;

    return Builder(
      builder: (BuildContext anchorContext) => Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.chipRadius),
          side: BorderSide(
            color: active ? theme.colorScheme.primary : theme.dividerColor,
          ),
        ),
        child: InkWell(
          onTap: onChanged == null
              ? null
              : () async {
                  final T? picked = await showClassicMenu<T>(
                    context: context,
                    anchorContext: anchorContext,
                    options: options,
                    current: value,
                    minWidth: 200,
                  );
                  if (picked != null) onChanged!(picked);
                },
          child: Container(
            height: 36,
            constraints: const BoxConstraints(minWidth: 72),
            padding: const EdgeInsets.only(left: 10, right: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(
                    icon,
                    size: 16,
                    color: active
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodySmall?.color,
                  ),
                  AppSpacing.w4,
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: active ? theme.colorScheme.primary : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: active
                      ? theme.colorScheme.primary
                      : theme.textTheme.bodySmall?.color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
