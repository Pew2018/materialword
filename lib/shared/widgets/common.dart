import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// True for pointer/keyboard platforms (macOS, Windows, Linux). Mobile UI hides
/// shortcut hints and desktop-only affordances.
bool isDesktopPlatform(BuildContext context) {
  return switch (Theme.of(context).platform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    _ => false,
  };
}

/// Centred placeholder used by every screen that can be empty.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: theme.disabledColor),
            AppSpacing.h12,
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...<Widget>[
              AppSpacing.h8,
              Text(
                message!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...<Widget>[AppSpacing.h16, action!],
          ],
        ),
      ),
    );
  }
}

/// `label  12 / 30` row with a thin linear progress bar underneath.
class ProgressRow extends StatelessWidget {
  const ProgressRow({
    super.key,
    required this.label,
    required this.done,
    required this.total,
    this.color,
    this.hint,
  });

  final String label;
  final int done;
  final int total;
  final Color? color;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double ratio = total <= 0 ? 0 : (done / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(label, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              '$done / $total',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 3,
            backgroundColor: theme.dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? theme.colorScheme.primary,
            ),
          ),
        ),
        if (hint != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(hint!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// A single number with a caption, used on the dashboard and statistics page.
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.value,
    required this.label,
    this.color,
    this.width,
  });

  final String value;
  final String label;
  final Color? color;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Card with a title row and optional actions. Kept for the few places where a
/// card genuinely helps (study summary, dialogs); the settings, dictionary and
/// dashboard screens use [SettingsGroup] instead.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.actions,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.compactGutter),
  });

  final String? title;
  final List<Widget>? actions;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(title!, style: theme.textTheme.titleMedium),
                    ),
                    ...?actions,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Small caps section header, the classic Material "list subheader".
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      height: AppDimens.sectionHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.gutter),
      alignment: Alignment.centerLeft,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Classic grouped list: flat surface, hairline dividers, no nested cards.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            indent: AppDimens.gutter,
            color: theme.dividerColor,
          ),
        );
      }
      rows.add(children[i]);
    }
    return Material(
      color: theme.cardColor,
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}

/// Standard 56dp / 72dp list row with consistent paddings.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.dense = false,
    this.trailingText,
    this.titleStyle,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool dense;
  final String? trailingText;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      dense: dense,
      selected: selected,
      minVerticalPadding: dense ? 4 : 8,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.gutter,
        vertical: 2,
      ),
      leading: leading,
      title: title == null
          ? null
          : Text(
              title!,
              style: titleStyle ?? theme.textTheme.bodyLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing:
          trailing ??
          (trailingText == null
              ? null
              : Text(trailingText!, style: theme.textTheme.bodySmall)),
      onTap: onTap,
      shape: const RoundedRectangleBorder(),
    );
  }
}

/// Small rounded label used for tags ("CET-6", "困难", study stage…).
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.color,
    this.dense = false,
  });

  final String label;
  final Color? color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color base = color ?? theme.colorScheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: base.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: base,
          fontSize: dense ? 11 : 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Constrains content width on wide windows so text lines stay readable.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = AppDimens.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Error banner with retry.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.compactGutter),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.unknown.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.unknown.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppDimens.radius),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.error_outline,
            size: AppDimens.iconSizeSmall,
            color: AppColors.unknown,
          ),
          AppSpacing.w8,
          Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

/// Keyboard shortcut hint that only desktop builds show.
class ShortcutHint extends StatelessWidget {
  const ShortcutHint(this.text, {super.key, this.alignment = Alignment.center});

  final String text;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPlatform(context)) return const SizedBox.shrink();
    return Align(
      alignment: alignment,
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

/// Two-column list/detail layout used by word management on wide windows.
/// Falls back to a single column below [AppDimens.twoPaneBreakpoint].
class AdaptiveTwoPane extends StatelessWidget {
  const AdaptiveTwoPane({
    super.key,
    required this.list,
    required this.detail,
    this.listWidth = 380,
  });

  final Widget list;
  final Widget detail;
  final double listWidth;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    if (width < AppDimens.twoPaneBreakpoint) {
      return list;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(width: listWidth, child: list),
        const VerticalDivider(width: 1),
        Expanded(child: detail),
      ],
    );
  }
}

/// Confirmation dialog helper that matches the app's dialog theme.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool destructive = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: AppColors.unknown)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.unknown : null,
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Small reusable single-line text prompt used when creating/renaming books.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
  String confirmLabel = '确定',
}) async {
  final TextEditingController controller = TextEditingController(
    text: initialValue,
  );
  final String? result = await showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (String value) => Navigator.of(context).pop(value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// Monotonic query generation.
///
/// Every asynchronous search/lookup in the app takes a generation before it
/// starts and drops its result when the generation moved on. This is the fix for
/// "old query overwrites the result of the new word" in quick-add and the
/// dictionary page.
class SearchGeneration {
  int _value = 0;

  int get value => _value;

  int next() => ++_value;

  bool isCurrent(int generation) => generation == _value;

  void invalidate() => _value++;
}
