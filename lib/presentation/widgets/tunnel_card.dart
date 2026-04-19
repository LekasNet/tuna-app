import 'package:flutter/material.dart';

class TunnelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color activityColor;
  final String? activityHint;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final Widget? footer;
  final CrossAxisAlignment rowCrossAxisAlignment;

  const TunnelCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.activityColor,
    this.activityHint,
    this.actions = const <Widget>[],
    this.onTap,
    this.footer,
    this.rowCrossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final cardBody = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: rowCrossAxisAlignment,
        children: [
          TunnelActivityDot(color: activityColor, tooltip: activityHint),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
                if (footer != null) ...[const SizedBox(height: 6), footer!],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 8),
            Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return cardBody;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: cardBody,
      ),
    );
  }
}

class TunnelActivityDot extends StatelessWidget {
  final Color color;
  final String? tooltip;

  const TunnelActivityDot({super.key, required this.color, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );

    if (tooltip == null || tooltip!.trim().isEmpty) {
      return dot;
    }

    return Tooltip(message: tooltip!, child: dot);
  }
}
