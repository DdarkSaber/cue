import 'package:flutter/material.dart' hide Title;

import '../../app/icons.dart';
import '../../app/layout.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../domain/models/title.dart';
import 'poster.dart';

/// The recommendation card face. Phone: poster fills the card with the
/// title block in the lower third. Desktop: text left, artwork right.
class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.title,
    required this.reason,
    this.onDetails,
  });

  final Title title;
  final String reason;
  final VoidCallback? onDetails;

  /// The scrim behind the copy: [scrimMin] (about 85% near-black) where the
  /// text starts, deepening to [scrimMax] at the card's bottom edge.
  static const scrimMin = Color(0xD9080D12);
  static const scrimMax = Color(0xF2080D12);

  /// Height of the fade from transparent to [scrimMin] above the text.
  static const double scrimFade = 48;

  static const scrimKey = ValueKey('story-card-scrim');
  static const scrimBodyKey = ValueKey('story-card-scrim-body');

  /// A soft shadow under the title, for edges the scrim fades into.
  static const titleShadows = [
    Shadow(color: Color(0x99000000), blurRadius: 12, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final desktop = context.cueLayout == CueLayout.desktop;
    final radius = desktop ? CueRadius.cardDesktop : CueRadius.cardPhone;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 48,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: desktop ? _desktop(context) : _phone(context),
      ),
    );
  }

  Widget _phone(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Poster(title: title),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.24, 0.42, 0.69, 0.88, 1],
              colors: [
                Color(0x4205090D),
                Color(0x00000000),
                Color(0x05080D12),
                Color(0xBA080D12),
                Color(0xF5080D12),
                Color(0xFF080D12),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _TextScrim(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
            child: _CardCopy(title: title, reason: reason, desktop: false),
          ),
        ),
        // Last, so the kind chip and the details button stay on top of
        // the scrim when large text makes the copy tall.
        Positioned(
          left: 13,
          right: 13,
          top: 12,
          child: _CardTop(title: title, onDetails: onDetails),
        ),
      ],
    );
  }

  Widget _desktop(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dim, static wash of the artwork behind the text side. No blur:
        // a full-card blur is too heavy to composite every frame.
        Opacity(opacity: 0.16, child: Poster(title: title)),
        Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.58,
            heightFactor: 1,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(
                colors: [Color(0x00000000), Color(0xFF000000)],
                stops: [0, 0.17],
              ).createShader(r),
              child: Poster(title: title, alignment: const Alignment(0, -0.4)),
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              stops: [0.02, 0.24, 0.39, 0.6, 0.8],
              colors: [
                Color(0xFF0B1118),
                Color(0xFB0B1118),
                Color(0xD90B1118),
                Color(0x430B1118),
                Color(0x000B1118),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _TextScrim(
            padding: const EdgeInsets.fromLTRB(56, 0, 26, 70),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(
                width: (MediaQuery.sizeOf(context).width * 0.43).clamp(
                  320,
                  530,
                ),
                child: _CardCopy(title: title, reason: reason, desktop: true),
              ),
            ),
          ),
        ),
        Positioned(
          left: 32,
          right: 26,
          top: 26,
          child: _CardTop(title: title, onDetails: onDetails),
        ),
      ],
    );
  }
}

/// A dark band behind the card copy, so white text stays readable on any
/// artwork, a pure white poster included. It fades in above the text and
/// grows with it (long titles, large text); the text itself always sits on
/// at least [StoryCard.scrimMin].
class _TextScrim extends StatelessWidget {
  const _TextScrim({required this.padding, required this.child});
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: StoryCard.scrimKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Soft edge: transparent to the scrim's lightest tone.
        const SizedBox(
          height: StoryCard.scrimFade,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00080D12), StoryCard.scrimMin],
              ),
            ),
          ),
        ),
        DecoratedBox(
          key: StoryCard.scrimBodyKey,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [StoryCard.scrimMin, StoryCard.scrimMax],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ],
    );
  }
}

class _CardTop extends StatelessWidget {
  const _CardTop({required this.title, required this.onDetails});
  final Title title;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xBB10171B),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0x30FFFFFF)),
          ),
          child: Text(
            title.kind.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: CueColors.text,
            ),
          ),
        ),
        const Spacer(),
        CueRoundButton(
          icon: CueIcons.info,
          tooltip: 'Story and details',
          visualSize: 40,
          iconSize: 19,
          onPressed: onDetails,
        ),
      ],
    );
  }
}

class _CardCopy extends StatelessWidget {
  const _CardCopy({
    required this.title,
    required this.reason,
    required this.desktop,
  });

  final Title title;
  final String reason;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final titleSize = desktop
        ? (MediaQuery.sizeOf(context).width * 0.057).clamp(52.0, 80.0)
        : (height * 0.062).clamp(32.0, 55.0);
    final meta = [if (title.year != null) '${title.year}', ?title.lengthLabel];
    final era = title.artEra;
    final alt = title.altTitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (desktop && title.genres.isNotEmpty) ...[
          // The one place all caps are allowed: the cinematic eyebrow.
          Text(
            title.genres.take(3).join(' · ').toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: Color(0xFFDAE4EE),
            ),
          ),
          const SizedBox(height: 22),
        ],
        Text(
          title.displayTitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            height: 1.03,
            letterSpacing: -titleSize * 0.04,
            color: CueColors.text,
            shadows: StoryCard.titleShadows,
          ),
        ),
        SizedBox(height: desktop ? 20 : 8),
        Wrap(
          spacing: 9,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final m in meta)
              Text(
                m,
                style: TextStyle(
                  fontSize: desktop ? 14 : 12,
                  color: const Color(0xFFC3CEDA),
                ),
              ),
            if (era != null) _EraTag(era),
          ],
        ),
        if (alt != null) ...[
          const SizedBox(height: 6),
          Text(
            alt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: desktop ? 14 : 12,
              color: const Color(0xFFC3CEDA),
            ),
          ),
        ],
        if (reason.isNotEmpty) ...[
          SizedBox(height: desktop ? 14 : 8),
          Text(
            reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: desktop ? 19 : 14,
              height: 1.45,
              color: const Color(0xFFE6F1FB),
            ),
          ),
        ],
      ],
    );
  }
}

class _EraTag extends StatelessWidget {
  const _EraTag(this.era);
  final String era;

  @override
  Widget build(BuildContext context) {
    final fresh = era == 'New art';
    final color = fresh ? CueColors.willTry : CueColors.notNow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(era, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}
