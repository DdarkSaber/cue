import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/icons.dart';
import '../../app/layout.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../data/library_rating_service.dart';
import '../../domain/models/decision.dart';
import '../../domain/models/library.dart';
import '../../domain/ranker.dart';
import '../deck/action_bar.dart';
import '../deck/decision_style.dart';
import '../deck/loading_card.dart';
import '../deck/poster.dart';
import '../deck/swipe_deck.dart';
import '../details/details_sheet.dart';

/// One answer on the rating deck: the direction that gives it, how it looks,
/// and what it saves (a rating, or a shortlist follow-up answer).
class RatingAnswer {
  const RatingAnswer(this.direction, this.choice, {this.rating, this.followUp});

  final SwipeDirection direction;
  final SwipeChoice choice;
  final Rating? rating;
  final FollowUpAnswer? followUp;
}

final _lovedStyle = DecisionStyle.of(Decision.willTry).withIcon(CueIcons.heart);
final _enjoyedStyle = DecisionStyle.of(Decision.watched);
final _laterStyle = DecisionStyle.of(Decision.notNow);
final _noStyle = DecisionStyle.of(Decision.notInterested);

/// Rating your library: up Loved, right Enjoyed, down One-time, left Dropped.
final libraryRatingAnswers = [
  RatingAnswer(
    SwipeDirection.up,
    SwipeChoice(label: 'Loved', style: _lovedStyle, primary: true),
    rating: Rating.favourite,
  ),
  RatingAnswer(
    SwipeDirection.right,
    SwipeChoice(label: 'Enjoyed', style: _enjoyedStyle),
    rating: Rating.enjoyed,
  ),
  RatingAnswer(
    SwipeDirection.down,
    SwipeChoice(label: 'One-time', style: _laterStyle),
    rating: Rating.once,
  ),
  RatingAnswer(
    SwipeDirection.left,
    SwipeChoice(label: 'Dropped', style: _noStyle),
    rating: Rating.dropped,
  ),
];

/// Shortlist follow-up: up Loved, right Enjoyed, left Not for me,
/// down Haven't started.
final followUpAnswers = [
  RatingAnswer(
    SwipeDirection.up,
    SwipeChoice(label: 'Loved', style: _lovedStyle, primary: true),
    followUp: FollowUpAnswer.loved,
  ),
  RatingAnswer(
    SwipeDirection.right,
    SwipeChoice(label: 'Enjoyed', style: _enjoyedStyle),
    followUp: FollowUpAnswer.enjoyed,
  ),
  RatingAnswer(
    SwipeDirection.down,
    SwipeChoice(label: "Haven't started", style: _laterStyle),
    followUp: FollowUpAnswer.haventStarted,
  ),
  RatingAnswer(
    SwipeDirection.left,
    SwipeChoice(label: 'Not for me', style: _noStyle),
    followUp: FollowUpAnswer.notForMe,
  ),
];

/// Buttons read low to high, with the strongest answer last like the deck's
/// Will try.
const _buttonOrder = [
  SwipeDirection.left,
  SwipeDirection.down,
  SwipeDirection.right,
  SwipeDirection.up,
];

const _arrows = {
  SwipeDirection.right: '→',
  SwipeDirection.left: '←',
  SwipeDirection.up: '↑',
  SwipeDirection.down: '↓',
};

/// Opens the full-screen rating deck over everything (the shell included).
/// The only way to rate titles in bulk; Library and the import summary use it.
Future<void> openLibraryRating(
  BuildContext context,
  WidgetRef ref, {
  bool followUp = false,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final id = await ref.read(profileIdProvider.future);
  if (!context.mounted) return;
  final service = LibraryRatingService(
    container.read(databaseProvider),
    container.read(libraryRepositoryProvider),
    container.read(recommendationRepositoryProvider),
    clock: container.read(clockProvider),
  );
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => LibraryRatingDeck(
        service: service,
        profileId: id,
        followUp: followUp,
        onChanged: () {
          container.read(libraryVersionProvider.notifier).bump();
          container.read(decisionVersionProvider.notifier).bump();
        },
      ),
    ),
  );
}

/// The last thing Undo can take back: a saved rating or a skip.
class _Last {
  const _Last(this.titleId, {this.token, this.direction});
  final String titleId;

  /// Null for a skip.
  final RatingUndo? token;
  final SwipeDirection? direction;
}

/// Story cards from your own library, swiped to rate. Nothing is saved
/// until an answer is given; skipping and leaving never change anything.
class LibraryRatingDeck extends ConsumerStatefulWidget {
  const LibraryRatingDeck({
    super.key,
    required this.service,
    required this.profileId,
    required this.onChanged,
    this.followUp = false,
  });

  final LibraryRatingService service;
  final String profileId;
  final VoidCallback onChanged;
  final bool followUp;

  @override
  ConsumerState<LibraryRatingDeck> createState() => _LibraryRatingDeckState();
}

class _LibraryRatingDeckState extends ConsumerState<LibraryRatingDeck> {
  final _deckKey = GlobalKey<SwipeDeckState>();
  final _focus = FocusNode(debugLabel: 'rating deck');
  List<RatingCandidate>? _cards;
  bool _loadFailed = false;

  /// Answered or skipped in this pass; they leave the deck.
  final Set<String> _done = {};

  /// A card brought back by Undo goes on top.
  String? _front;
  _Last? _last;
  String? _message;
  bool _busy = false;
  bool _includeDismissed = false;
  bool _includeRated = false;

  List<RatingAnswer> get _answers =>
      widget.followUp ? followUpAnswers : libraryRatingAnswers;

  RatingAnswer _answerFor(SwipeDirection d) =>
      _answers.firstWhere((a) => a.direction == d);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cards = await widget.service.candidates(
        widget.profileId,
        followUp: widget.followUp,
        includeDismissed: _includeDismissed,
        includeRated: _includeRated,
      );
      if (mounted) {
        setState(() {
          _cards = cards;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _message = 'Your library could not be read.';
        });
      }
    }
  }

  List<RatingCandidate> get _remaining {
    final list = [
      for (final c in _cards ?? const <RatingCandidate>[])
        if (!_done.contains(c.title.id)) c,
    ];
    final i = list.indexWhere((c) => c.title.id == _front);
    if (i > 0) list.insert(0, list.removeAt(i));
    return list;
  }

  RatingCandidate? get _top => _remaining.firstOrNull;

  bool get _canUndo => _last != null && !_busy;

  void _close() => Navigator.of(context).maybePop();

  /// Every way in (swipe, button, key, screen reader) lands here once the
  /// card has left.
  Future<void> _onSwipe(SwipeDirection dir) async {
    final card = _top;
    if (card == null || _busy) return;
    final id = card.title.id;
    // The card has already flown out: keep it out while saving.
    setState(() {
      _busy = true;
      _done.add(id);
      _front = null;
    });
    final saved = await _save(card, _answerFor(dir));
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) return;
    // Nothing was saved: the same card returns from where it left.
    setState(() {
      _done.remove(id);
      _front = id;
    });
    if (_top?.title.id == id) await _deckKey.currentState?.bringBack(dir);
  }

  Future<bool?> _confirmReplace() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Replace your existing rating?'),
      content: const Text(
        'Only the rating changes. Your status, progress and history stay as they are.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep rating'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Replace rating'),
        ),
      ],
    ),
  );

  Future<bool> _save(RatingCandidate card, RatingAnswer answer) async {
    try {
      var overwrite = false;
      if (card.before?.rating != null) {
        overwrite = await _confirmReplace() ?? false;
        if (!overwrite) {
          if (mounted) {
            setState(() => _message = 'Kept your rating. Nothing changed.');
          }
          return false;
        }
      }
      final followUp = answer.followUp;
      final undo = followUp != null
          ? await widget.service.answer(
              widget.profileId,
              card,
              followUp,
              overwrite: overwrite,
            )
          : await widget.service.rate(
              widget.profileId,
              card,
              answer.rating!,
              overwrite: overwrite,
            );
      widget.onChanged();
      if (!mounted) return true;
      setState(() {
        _last = undo == null
            ? null
            : _Last(card.title.id, token: undo, direction: answer.direction);
        _message = undo == null
            ? 'No rating added. Review it later whenever you want.'
            : widget.followUp
            ? '${answer.choice.label} saved and removed from Will try. Your status, progress and dates are unchanged.'
            : '${answer.choice.label} saved. Your other library details are unchanged.';
      });
      await _load();
      return true;
    } on RatingConflict {
      if (mounted) {
        setState(
          () => _message =
              'This title changed elsewhere. Nothing was overwritten.',
        );
        await _load();
      }
      return false;
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not save this answer. Please try again.',
        );
      }
      return false;
    }
  }

  void _skip() {
    final card = _top;
    if (card == null || _busy) return;
    setState(() {
      _done.add(card.title.id);
      _front = null;
      _last = _Last(card.title.id);
      _message = 'Skipped. No rating added.';
    });
  }

  Future<void> _dismiss() async {
    final card = _top;
    if (card == null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.service.dismiss(widget.profileId, card.title.id);
      widget.onChanged();
      if (mounted) {
        setState(() {
          _done.add(card.title.id);
          _front = null;
          _last = null;
          _message = 'Dismissed. No rating added. You can review it later.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not dismiss this follow-up.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undoLast() async {
    final last = _last;
    if (last == null || _busy) return;
    final token = last.token;
    if (token == null) {
      setState(() {
        _done.remove(last.titleId);
        _front = last.titleId;
        _last = null;
        _message = 'Skip undone. No rating changed.';
      });
      return;
    }
    setState(() => _busy = true);
    var restored = false;
    try {
      restored = await widget.service.undo(widget.profileId, token);
      if (restored) widget.onChanged();
      if (!mounted) return;
      setState(() {
        _last = null;
        if (restored) {
          _done.remove(last.titleId);
          _front = last.titleId;
        }
        _message = restored
            ? 'Previous library details restored.'
            : 'This title changed elsewhere. Undo did not overwrite it.';
      });
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not undo. Your saved answer remains.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    final from = last.direction;
    if (restored && mounted && from != null && _top?.title.id == last.titleId) {
      await _deckKey.currentState?.bringBack(from);
    }
  }

  /// Buttons and keys animate like a swipe; the deck then reports back.
  void _answer(SwipeDirection dir) {
    if (_busy || _top == null) return;
    _deckKey.currentState?.swipe(dir);
  }

  void _review() {
    setState(() {
      if (widget.followUp) {
        _includeDismissed = true;
      } else {
        _includeRated = true;
      }
      _done.clear();
      _front = null;
      _cards = null;
      _message = null;
    });
    _load();
  }

  Future<void> _openDetails() async {
    final card = _top;
    if (card == null) return;
    await showDetailsSheet(
      context,
      card.title,
      reason: _reason(card),
      showActions: false,
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyU ||
        (key == LogicalKeyboardKey.keyZ &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed))) {
      if (!_canUndo) return KeyEventResult.ignored;
      unawaited(_undoLast());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyS) {
      if (_top == null || _busy) return KeyEventResult.ignored;
      _skip();
      return KeyEventResult.handled;
    }
    final dir = switch (key) {
      LogicalKeyboardKey.arrowLeft => SwipeDirection.left,
      LogicalKeyboardKey.arrowRight => SwipeDirection.right,
      LogicalKeyboardKey.arrowUp => SwipeDirection.up,
      LogicalKeyboardKey.arrowDown => SwipeDirection.down,
      _ => null,
    };
    if (dir == null || _top == null || _busy) return KeyEventResult.ignored;
    _answer(dir);
    return KeyEventResult.handled;
  }

  /// What the card says under the title: where it stands in the library.
  String _reason(RatingCandidate c) {
    final before = c.before;
    final state = before == null ? null : LibraryState.parse(before.state);
    final rating = Rating.parse(before?.rating);
    return [
      if (state != null && state != LibraryState.none) 'Status: ${state.label}',
      if (rating != null)
        'Current rating: ${rating.label}'
      else if (before?.rating != null)
        'Current rating: ${before!.rating}',
      if (widget.followUp && c.shortlist != null) 'On your Will try list',
      if (!widget.followUp && rating == null) 'Not rated yet',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final desktop = context.cueLayout == CueLayout.desktop;
    final settings = ref.watch(currentSettingsProvider);
    final remaining = _remaining;
    final top = remaining.firstOrNull;
    final total = _done.length + remaining.length;
    final loading = _cards == null && !_loadFailed;

    if (remaining.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          predecodePosters(
            context,
            ref,
            remaining.skip(1).take(2).map((c) => c.title),
          );
        }
      });
    }

    final Widget cardArea;
    if (top != null) {
      cardArea = SwipeDeck(
        key: _deckKey,
        cards: [
          for (final c in remaining.take(2)) RankedCard(c.title, 0, _reason(c)),
        ],
        choices: {for (final a in _answers) a.direction: a.choice},
        cardLabel: widget.followUp ? 'Did you try it' : 'Rate',
        onSwipe: (d) => unawaited(_onSwipe(d)),
        onDetails: _openDetails,
        enabled: !_busy,
        reduceMotion: settings.reduceMotion,
        haptics: settings.haptics,
      );
    } else if (loading) {
      cardArea = const LoadingCard(loadingLabel: 'Loading your library');
    } else {
      cardArea = LoadingCard(
        message: _loadFailed
            ? 'Your library could not be read.'
            : total == 0
            ? (widget.followUp
                  ? 'No shortlist picks to follow up on right now. Come back whenever you want.'
                  : 'Nothing to rate here right now. Titles you finished, saw or dropped show up here.')
            : 'All done. Nothing more to rate here. Come back whenever you want.',
        action: _EndActions(
          onDone: _close,
          onRetry: _loadFailed ? _load : null,
          reviewLabel: _loadFailed
              ? null
              : widget.followUp
              ? (_includeDismissed ? null : 'Review dismissed picks')
              : (_includeRated ? null : 'Review existing ratings'),
          onReview: _review,
        ),
      );
    }

    final hints = [
      for (final a in _answers)
        '${_arrows[a.direction]} ${a.choice.label.toLowerCase()}',
    ].join(' · ');

    return Scaffold(
      backgroundColor: CueColors.bg,
      body: SafeArea(
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          includeSemantics: false,
          onKeyEvent: _onKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 24 : 12,
                  desktop ? 16 : 6,
                  desktop ? 24 : 12,
                  desktop ? 16 : 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      title: widget.followUp
                          ? 'Tried a shortlist pick?'
                          : 'Rate your library',
                      progress: top == null
                          ? (total == 0 ? null : 'All $total done')
                          : '${_done.length + 1} of $total',
                      onClose: _close,
                    ),
                    // Capped so large text never squeezes out the card;
                    // it scrolls instead.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.18,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_message != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _message!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: CueColors.accent,
                                    ),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                              child: Text(
                                widget.followUp
                                    ? 'Optional: answer only if you tried it. Swipe $hints.'
                                    : 'Optional: only your rating changes. Swipe $hints.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: CueColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: desktop ? 16 : 10),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: desktop ? 760 : 790,
                          ),
                          child: cardArea,
                        ),
                      ),
                    ),
                    SizedBox(height: desktop ? 18 : 12),
                    ChoiceBar(
                      items: [
                        for (final d in _buttonOrder)
                          ChoiceBarItem(
                            choice: _answerFor(d).choice,
                            keyHint: _arrows[d],
                            onPressed: top == null || _busy
                                ? null
                                : () => _answer(d),
                          ),
                      ],
                    ),
                    const SizedBox(height: CueSpace.xs),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: CueSpace.md,
                      children: [
                        _TextAction(
                          icon: CueIcons.arrow,
                          label: desktop ? 'Skip (S)' : 'Skip',
                          semanticsLabel: 'Skip',
                          onPressed: top == null || _busy ? null : _skip,
                        ),
                        _TextAction(
                          icon: CueIcons.undo,
                          label: desktop ? 'Undo (U)' : 'Undo',
                          semanticsLabel: 'Undo',
                          onPressed: _canUndo ? _undoLast : null,
                        ),
                        if (widget.followUp)
                          _TextAction(
                            icon: CueIcons.close,
                            label: 'Dismiss follow-up',
                            onPressed: top == null || _busy ? null : _dismiss,
                          ),
                        if (desktop)
                          const Text(
                            'Keys: arrows rate · Esc exit',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9FADBD),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.progress,
    required this.onClose,
  });

  final String title;
  final String? progress;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: CueSpace.sm,
      children: [
        CueRoundButton(
          icon: CueIcons.close,
          tooltip: 'Exit rating',
          onPressed: onClose,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: CueColors.text,
                  ),
                ),
              ),
              if (progress != null)
                Text(
                  progress!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CueColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.semanticsLabel,
  });

  final CueIcons icon;
  final String label;
  final String? semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: CueIcon(icon, size: 16),
      label: Text(label, semanticsLabel: semanticsLabel),
      style: TextButton.styleFrom(
        minimumSize: const Size(CueSize.minTarget, CueSize.minTarget),
        foregroundColor: const Color(0xFFC1CEDD),
        disabledForegroundColor: const Color(0x66C1CEDD),
        textStyle: const TextStyle(fontFamily: cueFontFamily, fontSize: 13),
      ),
    );
  }
}

/// Finished, empty or failed: always a way out, never a dead end.
class _EndActions extends StatelessWidget {
  const _EndActions({
    required this.onDone,
    required this.onRetry,
    required this.reviewLabel,
    required this.onReview,
  });

  final VoidCallback onDone;
  final VoidCallback? onRetry;
  final String? reviewLabel;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CueSpace.md,
      runSpacing: CueSpace.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CuePrimaryButton(label: 'Done', onPressed: onDone),
        if (onRetry != null)
          CueSecondaryButton(label: 'Try again', onPressed: onRetry),
        if (reviewLabel != null)
          TextButton(
            onPressed: onReview,
            style: TextButton.styleFrom(
              minimumSize: const Size(CueSize.minTarget, CueSize.minTarget),
              foregroundColor: CueColors.accent,
            ),
            child: Text(reviewLabel!),
          ),
      ],
    );
  }
}
