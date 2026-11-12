import 'package:flutter/material.dart';

import '../../app/sheets.dart' show CueSectionLabel;
import '../../app/tokens.dart';
import '../../data/outcome_stats_repository.dart';
import '../../domain/learning/replay.dart';

/// How well the dealt cards are landing, in plain words. Presentational
/// only: the caller loads the numbers and passes them in.
class RecommendationQualityCard extends StatelessWidget {
  const RecommendationQualityCard({
    super.key,
    required this.recent,
    this.earlier,
    this.daily = const [],
    this.learned,
    this.baseline,
  });

  /// The newest stretch of deck decisions (the last 50).
  final OutcomeStats recent;

  /// The stretch before [recent], for the trend phrase.
  final OutcomeStats? earlier;

  /// Saved and rejected per day, oldest first.
  final List<({DateTime day, int saved, int rejected})> daily;

  /// Replay of the learned scorer and of the baseline it is compared with.
  final ReplayReport? learned;
  final ReplayReport? baseline;

  static const emptyText =
      'Swipe a few cards and Cue will show how well its picks are landing.';

  /// A format, or the earlier stretch, needs this many yes/no answers before
  /// its rate is worth showing.
  static const minDecisions = 5;

  static const _body = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: CueColors.textMuted,
  );
  static const _headline = TextStyle(
    fontSize: 17,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: CueColors.text,
  );

  static int _percent(double share) => (share * 100).round();

  static int _answered(OutcomeStats s) => s.saved + s.notInterested;

  /// "Saved 14 of the last 50 cards (28%)". The count is cards answered
  /// Will try or Not interested; watched and Not now say little about the
  /// pick, so they are named on their own line.
  static String headline(OutcomeStats s) =>
      'Saved ${s.saved} of the last ${_answered(s)} '
      '${_answered(s) == 1 ? 'card' : 'cards'} '
      '(${_percent(s.saveRate)}%)';

  /// "Not counting 6 you had already watched and 4 set aside for later."
  static String? aside(OutcomeStats s) {
    final parts = [
      if (s.watched > 0) '${s.watched} you had already watched or read',
      if (s.notNow > 0) '${s.notNow} set aside for later',
    ];
    return parts.isEmpty ? null : 'Not counting ${parts.join(' and ')}.';
  }

  /// "Up from 22%", "Down from 31%", or null without enough earlier data.
  static String? trend(OutcomeStats recent, OutcomeStats? earlier) {
    if (earlier == null || _answered(earlier) < minDecisions) return null;
    final now = _percent(recent.saveRate);
    final was = _percent(earlier.saveRate);
    if (now > was) return 'Up from $was%';
    if (now < was) return 'Down from $was%';
    return 'About the same as before';
  }

  /// One line per format with enough answers, busiest first.
  static List<String> formatLines(OutcomeStats s) {
    final kinds =
        [
          for (final e in s.byKind.entries)
            if (e.value.saved + e.value.rejected >= minDecisions) e,
        ]..sort((a, b) {
          final byCount = (b.value.saved + b.value.rejected).compareTo(
            a.value.saved + a.value.rejected,
          );
          return byCount != 0 ? byCount : a.key.index.compareTo(b.key.index);
        });
    return [
      for (final e in kinds)
        '${e.key.label}: saved ${e.value.saved} of '
            '${e.value.saved + e.value.rejected} '
            '(${_percent(e.value.saved / (e.value.saved + e.value.rejected))}%)',
    ];
  }

  /// The replay comparison in one plain sentence; null unless both ran.
  static String? comparison(ReplayReport? learned, ReplayReport? baseline) {
    if (learned == null || baseline == null || learned.events == 0) return null;
    return 'Learning from your swipes would have ranked a card you saved '
        'above one you skipped ${_percent(learned.auc)}% of the time, '
        'against ${_percent(baseline.auc)}% before.';
  }

  @override
  Widget build(BuildContext context) {
    final empty = _answered(recent) == 0;
    final trendText = empty ? null : trend(recent, earlier);
    final asideText = empty ? null : aside(recent);
    final lines = empty ? const <String>[] : formatLines(recent);
    final compare = empty ? null : comparison(learned, baseline);
    final days = [
      for (final d in daily)
        if (d.saved + d.rejected > 0) d,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const CueSectionLabel('How picks are landing'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(CueSpace.lg),
          decoration: BoxDecoration(
            color: CueColors.surface,
            borderRadius: BorderRadius.circular(CueRadius.cardPhone),
            border: Border.all(color: CueColors.line),
          ),
          child: empty
              ? const Text(emptyText, style: _body)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(headline(recent), style: _headline),
                    if (trendText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: CueSpace.xs),
                        child: Text(
                          trendText,
                          style: _body.copyWith(
                            color: CueColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (asideText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: CueSpace.xs),
                        child: Text(asideText, style: _body),
                      ),
                    if (lines.isNotEmpty) ...[
                      const SizedBox(height: CueSpace.md),
                      for (final line in lines) Text(line, style: _body),
                    ],
                    if (days.isNotEmpty) ...[
                      const SizedBox(height: CueSpace.lg),
                      _DailyBars(days),
                    ],
                    if (compare != null) ...[
                      const SizedBox(height: CueSpace.lg),
                      Text(compare, style: _body),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// One bar per day with decisions: its height is that day's save rate.
class _DailyBars extends StatelessWidget {
  const _DailyBars(this.days);

  final List<({DateTime day, int saved, int rejected})> days;

  static const double _height = 44;
  static const _caption = TextStyle(fontSize: 12, color: CueColors.textMuted);
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _date(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  static double _rate(({DateTime day, int saved, int rejected}) d) =>
      d.saved / (d.saved + d.rejected);

  @override
  Widget build(BuildContext context) {
    final spoken = [
      for (final d in days)
        '${_date(d.day)}: saved ${d.saved} of ${d.saved + d.rejected}',
    ].join(', ');
    return Semantics(
      container: true,
      label: 'Share of cards saved each day. $spoken.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share saved each day', style: _caption),
            const SizedBox(height: CueSpace.sm),
            SizedBox(
              height: _height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              constraints: const BoxConstraints(maxWidth: 18),
                              height: _height,
                              decoration: BoxDecoration(
                                color: CueColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 18),
                              // A day with nothing saved still shows a sliver.
                              height: 2 + (_height - 2) * _rate(d),
                              decoration: BoxDecoration(
                                color: CueColors.willTry,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: CueSpace.xs),
            Text(
              days.length == 1
                  ? _date(days.first.day)
                  : '${_date(days.first.day)} to ${_date(days.last.day)}',
              style: _caption,
            ),
          ],
        ),
      ),
    );
  }
}
