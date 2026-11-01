import 'package:flutter/material.dart';

import 'icons.dart';
import 'tokens.dart';
import 'widgets.dart';

/// Focus ring used by every Cue control: a 2 px ice-blue outline.
const _focusSide = BorderSide(color: CueColors.accent, width: 2);

WidgetStateProperty<BorderSide?> _side(BorderSide rest) =>
    WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.focused) ? _focusSide : rest,
    );

/// The one white primary action ("Show 12 picks", "Import 309").
class CuePrimaryButton extends StatelessWidget {
  const CuePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(CueSize.minTarget, CueSize.minTarget),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? const Color(0x33F3F5F8)
              : CueColors.actionPrimary,
        ),
        foregroundColor: const WidgetStatePropertyAll(
          CueColors.onActionPrimary,
        ),
        shape: WidgetStateProperty.resolveWith(
          (s) => RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CueRadius.chip),
            side: s.contains(WidgetState.focused)
                ? _focusSide
                : BorderSide.none,
          ),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Text(label),
    );
    return PressScale(
      enabled: onPressed != null,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// Quiet outlined action next to a primary one ("Reset", "Cancel").
class CueSecondaryButton extends StatelessWidget {
  const CueSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? CueColors.notInterested : CueColors.text;
    final button = OutlinedButton(
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(CueSize.minTarget, CueSize.minTarget),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18),
        ),
        foregroundColor: WidgetStatePropertyAll(color),
        backgroundColor: const WidgetStatePropertyAll(Color(0x08FFFFFF)),
        side: _side(
          BorderSide(
            color: destructive
                ? const Color(0x66E8C7D0)
                : const Color(0x26FFFFFF),
          ),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(CueRadius.chip)),
          ),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: 'DM Sans', fontSize: 15),
        ),
      ),
      child: Text(label),
    );
    return PressScale(
      enabled: onPressed != null,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// Selectable chip with text, outline and a check (never colour alone).
class CueChoiceChip extends StatelessWidget {
  const CueChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        child: OutlinedButton(
          onPressed: onTap,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
            tapTargetSize: MaterialTapTargetSize.padded,
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 14),
            ),
            backgroundColor: WidgetStatePropertyAll(
              selected ? CueColors.actionPrimary : const Color(0x08FFFFFF),
            ),
            foregroundColor: WidgetStatePropertyAll(
              selected ? CueColors.onActionPrimary : const Color(0xFFC5CFDB),
            ),
            side: _side(
              BorderSide(
                color: selected
                    ? CueColors.actionPrimary
                    : const Color(0x22FFFFFF),
              ),
            ),
            shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(CueRadius.chip)),
              ),
            ),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontFamily: 'DM Sans', fontSize: 13),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const CueIcon(
                  CueIcons.check,
                  size: 14,
                  color: CueColors.onActionPrimary,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(child: Text(label)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a Cinema sheet: a bottom sheet on phones, a right side sheet on
/// desktop. The body scrolls; the footer stays visible at large text.
Future<T?> showCueSheet<T>(
  BuildContext context, {
  required String kicker,
  required String title,
  required WidgetBuilder body,
  WidgetBuilder? footer,
}) {
  final desktop = MediaQuery.sizeOf(context).width >= CueSize.desktopBreakpoint;
  final reduce = MediaQuery.disableAnimationsOf(context);
  Widget sheet(BuildContext ctx) => CueSheet(
    kicker: kicker,
    title: title,
    body: body(ctx),
    footer: footer?.call(ctx),
  );
  if (desktop) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0xC7030609),
      transitionDuration: reduce
          ? Duration.zero
          : const Duration(milliseconds: 260),
      pageBuilder: (ctx, _, _) => Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 40, 24),
          child: SizedBox(
            width: 480,
            height: (MediaQuery.sizeOf(ctx).height * 0.92).clamp(0, 890),
            child: sheet(ctx),
          ),
        ),
      ),
      transitionBuilder: (ctx, a, _, child) => SlideTransition(
        position: Tween(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: a, child: child),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xC7030609),
    sheetAnimationStyle: reduce
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 280),
            reverseDuration: Duration(milliseconds: 200),
          ),
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
      ),
      child: sheet(ctx),
    ),
  );
}

class CueSheet extends StatelessWidget {
  const CueSheet({
    super.key,
    required this.kicker,
    required this.title,
    required this.body,
    this.footer,
  });

  final String kicker;
  final String title;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scrollTogether = MediaQuery.textScalerOf(context).scale(16) >= 24;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 12, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CueRouteHeader(kicker: kicker, title: title),
              ),
              CueRoundButton(
                icon: CueIcons.close,
                tooltip: 'Close',
                visualSize: 40,
                iconSize: 18,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        if (scrollTogether)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
            child: body,
          )
        else
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
              child: body,
            ),
          ),
        if (footer != null)
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: CueColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
                child: footer,
              ),
            ),
          ),
      ],
    );
    return Material(
      color: CueColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CueRadius.sheet),
        side: const BorderSide(color: Color(0x1AFFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: scrollTogether ? SingleChildScrollView(child: content) : content,
    );
  }
}

/// Small section label inside sheets and routes.
class CueSectionLabel extends StatelessWidget {
  const CueSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFFA7B5C5),
        ),
      ),
    ),
  );
}

/// Asks before something hard to reverse. Returns true on confirm.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xC7030609),
    builder: (ctx) => AlertDialog(
      backgroundColor: CueColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CueRadius.sheet),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      content: Text(
        body,
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
          color: CueColors.textMuted,
        ),
      ),
      actions: [
        CueSecondaryButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        destructive
            ? CueSecondaryButton(
                label: confirmLabel,
                destructive: true,
                onPressed: () => Navigator.of(ctx).pop(true),
              )
            : CuePrimaryButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
      ],
    ),
  );
  return ok ?? false;
}
