import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Animation length that respects the system "reduce motion" setting.
Duration motionDuration(BuildContext context, [int milliseconds = 250]) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: milliseconds);

/// White rounded card with a hairline border and a soft shadow.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final radius = BorderRadius.circular(kCardRadius);
    final padded = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: radius,
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.primary.withAlpha(22),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: onTap == null
          ? padded
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: padded,
              ),
            ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Soft blue rounded square holding an icon.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.size = 40,
    this.color,
    this.background,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? c.primarySoft,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.52, color: color ?? c.primaryStrong),
    );
  }
}

/// Thin animated progress bar. [value] is 0..1.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
    this.semanticsLabel,
  });

  final double value;
  final Color? color;
  final double height;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final double target = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: semanticsLabel,
      value: '${(target * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: target),
        duration: motionDuration(context, 400),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: LinearProgressIndicator(
            value: v,
            minHeight: height,
            backgroundColor: c.primarySoft,
            color: color ?? c.primary,
          ),
        ),
      ),
    );
  }
}

/// Friendly placeholder for screens or sections without data.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon: icon, size: 56),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, height: 1.4),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pill-shaped single-choice chip used for filters and option pickers.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final fg = selected ? Theme.of(context).colorScheme.onPrimary : c.text;
    return ChoiceChip(
      label: Text(label),
      avatar: icon == null ? null : Icon(icon, size: 18, color: fg),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      selectedColor: c.primaryStrong,
      backgroundColor: c.card,
      side: BorderSide(color: selected ? c.primaryStrong : c.border),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: fg, fontWeight: FontWeight.w600),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

/// Summary tile: label, big value and an optional caption.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return SoftCard(
      child: Semantics(
        container: true,
        label: '$label: $value${caption == null ? '' : ', $caption'}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(icon: icon, size: 34, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(caption!,
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Scrolling, centered, width-limited page body used by every screen.
class ScreenBody extends StatelessWidget {
  const ScreenBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final pad = wide ? 24.0 : 16.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 16),
          itemCount: children.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, i) => children[i],
        ),
      ),
    );
  }
}

/// Standard text-field look with visible borders and focus state.
InputDecoration fieldDecoration(
  BuildContext context, {
  String? label,
  String? hint,
  String? helper,
  Widget? suffix,
  String? prefixText,
}) {
  final c = context.hc;
  OutlineInputBorder border(Color color, [double width = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(kControlRadius),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    suffixIcon: suffix,
    prefixText: prefixText,
    filled: true,
    fillColor: c.card,
    labelStyle: TextStyle(color: c.textSecondary),
    hintStyle: TextStyle(color: c.textSecondary),
    helperStyle: TextStyle(color: c.textSecondary),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(c.border),
    enabledBorder: border(c.border),
    focusedBorder: border(c.primaryStrong, 2),
    errorBorder: border(Theme.of(context).colorScheme.error),
    focusedErrorBorder: border(Theme.of(context).colorScheme.error, 2),
  );
}

void showAppSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Asks for confirmation. Returns true only if the user confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: kDestructive,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// App logo: a blue wave tile followed by the HabitTech wordmark.
class HabitTechLogo extends StatelessWidget {
  const HabitTechLogo({super.key, this.size = 34, this.showText = true});

  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Semantics(
      label: 'HabitTech',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: c.primaryStrong,
                borderRadius: BorderRadius.circular(size * 0.3),
              ),
              child: Icon(Icons.waves, size: size * 0.62, color: onPrimary),
            ),
            if (showText) ...[
              SizedBox(width: size * 0.3),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Habit',
                      style: TextStyle(
                          color: c.text, fontWeight: FontWeight.w800),
                    ),
                    TextSpan(
                      text: 'Tech',
                      style: TextStyle(
                          color: c.primaryStrong, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: size * 0.56),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
