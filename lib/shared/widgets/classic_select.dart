import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// One row of a [ClassicSelect] / [ClassicSelectChip].
@immutable
class ClassicOption<T> {
  const ClassicOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Height of one menu row. Also the value the layout maths assumes when it
/// decides whether the menu fits below the trigger.
const double _kMenuItemHeight = 48;

/// Vertical padding `PopupMenu` adds above the first row and below the last.
const double _kMenuPadding = 8;

/// Opens a classic Material menu anchored to the widget that calls it.
///
/// `DropdownButton` sizes its menu to the *button*, so an `isExpanded` field
/// inside a wide row produced a menu as wide as the page, glued to the window
/// edge. This helper instead:
///  * keeps a readable menu width (160–320dp by default, never the page width);
///  * keeps a 16dp margin to the visible edge on every side;
///  * left-aligns the menu with the trigger and opens it below, flipping above
///    only when there is genuinely no room underneath;
///  * caps the height to the space it actually has, leaving the menu scrollable
///    instead of letting it run off-screen.
///
/// All geometry is measured against the **overlay** that will host the menu,
/// not against the window: inside an `AlertDialog`, under a nested `Navigator`
/// or in a resized macOS window the overlay is the coordinate space that
/// `showMenu` positions within, and `MediaQuery.sizeOf` is not.
Future<T?> showClassicMenu<T>({
  required BuildContext context,
  required BuildContext anchorContext,
  required List<ClassicOption<T>> options,
  T? current,
  double minWidth = 160,
  double maxWidth = 320,
}) async {
  final ThemeData theme = Theme.of(context);
  const double edge = 16;
  const double gap = 4;

  final Rect anchor = _anchorRect(context, anchorContext);
  final Size surface = _menuSurfaceSize(context);

  // Defensive arithmetic: every clamp below must have a valid (low <= high)
  // range even in a 200dp-wide window, and no length may go negative.
  final double availableWidth = math.max(0, surface.width - edge * 2);
  final double width = math.max(
    0,
    math.min(
      math.min(math.max(anchor.width, minWidth), maxWidth),
      availableWidth,
    ),
  );
  final double maxLeft = math.max(edge, surface.width - edge - width);
  final double left = math.min(math.max(anchor.left, edge), maxLeft);

  final double contentHeight =
      options.length * _kMenuItemHeight + _kMenuPadding * 2;
  final double belowTop = anchor.bottom + gap;
  final double spaceBelow = math.max(0, surface.height - edge - belowTop);
  final double spaceAbove = math.max(0, anchor.top - gap - edge);

  final bool fitsBelow = contentHeight <= spaceBelow;
  final bool fitsAbove = contentHeight <= spaceAbove;
  final bool opensBelow = fitsBelow || (!fitsAbove && spaceBelow >= spaceAbove);

  final double top = opensBelow
      ? belowTop
      : math.max(edge, anchor.top - gap - contentHeight);
  final double maxHeight = math.max(
    0,
    math.min(contentHeight, opensBelow ? spaceBelow : anchor.top - gap - top),
  );

  final T? result = await showMenu<T>(
    context: context,
    // `showMenu` reads `left`/`top` from this rect and then nudges the menu
    // back inside the safe area; `bottom` only feeds the "which edge is the
    // trigger closer to" heuristic, so an already-clamped `right` keeps the
    // menu left-aligned in both branches.
    position: RelativeRect.fromLTRB(left, top, surface.width - left - width, 0),
    constraints: BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: maxHeight,
    ),
    items: <PopupMenuEntry<T>>[
      for (final ClassicOption<T> option in options)
        PopupMenuItem<T>(
          value: option.value,
          height: _kMenuItemHeight,
          child: Row(
            children: <Widget>[
              // Expanded + ellipsis: a long label can never push the check mark
              // out of the menu, and the full text stays available as a tooltip.
              Expanded(
                child: Tooltip(
                  message: option.label,
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
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

/// The trigger's rectangle in the coordinate space the menu is laid out in.
Rect _anchorRect(BuildContext context, BuildContext anchorContext) {
  final RenderObject? render = anchorContext.findRenderObject();
  final RenderObject? overlay = Overlay.maybeOf(
    context,
    rootOverlay: false,
  )?.context.findRenderObject();
  if (render is RenderBox &&
      render.hasSize &&
      overlay is RenderBox &&
      overlay.hasSize) {
    final Matrix4 transform = render.getTransformTo(overlay);
    return MatrixUtils.transformRect(transform, Offset.zero & render.size);
  }
  // Fallback for a widget pumped without an overlay (a unit test of a single
  // field): the window coordinates are the best available approximation.
  if (render is RenderBox && render.hasSize) {
    return render.localToGlobal(Offset.zero) & render.size;
  }
  return Rect.zero;
}

/// The usable size of the surface the menu will be drawn on.
Size _menuSurfaceSize(BuildContext context) {
  final RenderObject? overlay = Overlay.maybeOf(
    context,
    rootOverlay: false,
  )?.context.findRenderObject();
  if (overlay is RenderBox && overlay.hasSize) return overlay.size;
  return MediaQuery.sizeOf(context);
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
                // The menu may outlive the field (a dialog closed while it was
                // open); a change callback on a disposed widget is a crash.
                if (picked != null && context.mounted) onChanged!(picked);
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
          borderRadius: theme.chipRadius,
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
                  if (picked != null && context.mounted) onChanged!(picked);
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
