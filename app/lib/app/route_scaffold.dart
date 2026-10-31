import 'package:flutter/material.dart';

import 'icons.dart';
import 'layout.dart';
import 'tokens.dart';
import 'widgets.dart';

/// Scrollable route body with the Cinema header and an optional back
/// button. Routes leave room for the desktop nav pill at the top.
class RouteScaffold extends StatelessWidget {
  const RouteScaffold({
    super.key,
    required this.kicker,
    required this.title,
    required this.children,
    this.onBack,
    this.maxWidth = 680,
  });

  final String kicker;
  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final desktop = context.cueLayout == CueLayout.desktop;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        desktop ? 4 : 10,
        desktop ? 96 : CueSpace.lg,
        desktop ? 4 : 10,
        CueSpace.xl,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onBack != null) ...[
              CueRoundButton(
                icon: CueIcons.back,
                tooltip: 'Back',
                visualSize: 40,
                iconSize: 18,
                onPressed: onBack,
              ),
              const SizedBox(width: CueSpace.sm),
            ],
            Expanded(
              child: CueRouteHeader(kicker: kicker, title: title),
            ),
          ],
        ),
        const SizedBox(height: CueSpace.lg),
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// A tappable settings-style row with a summary and chevron.
class CueListRow extends StatelessWidget {
  const CueListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(CueRadius.chip),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: CueColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
                if (trailing == null && onTap != null)
                  const CueIcon(
                    CueIcons.arrow,
                    size: 16,
                    color: CueColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grouped card holding list rows.
class CueGroup extends StatelessWidget {
  const CueGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: CueColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CueColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: CueColors.line),
            children[i],
          ],
        ],
      ),
    );
  }
}
