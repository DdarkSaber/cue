import 'package:flutter/material.dart';

import '../../data/library_rating_service.dart';
import '../../domain/models/library.dart';

/// Opened only from Library. Nothing is saved until a labelled answer is tapped.
class LibraryRatingCards extends StatefulWidget {
  const LibraryRatingCards({
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
  State<LibraryRatingCards> createState() => _LibraryRatingCardsState();
}

class _LibraryRatingCardsState extends State<LibraryRatingCards> {
  List<RatingCandidate>? _cards;
  final Set<String> _skipped = {};
  RatingUndo? _undo;
  String? _lastSkipped;
  String? _message;
  bool _busy = false;
  bool _includeDismissed = false;
  bool _includeRated = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cards = await widget.service.candidates(
        widget.profileId,
        followUp: widget.followUp,
        includeDismissed: _includeDismissed,
        includeRated: _includeRated,
      );
      if (mounted) setState(() => _cards = cards);
    } catch (_) {
      if (mounted) setState(() => _message = 'Your library could not be read.');
    }
  }

  Future<void> _save(
    RatingCandidate card,
    Rating? rating,
    FollowUpAnswer? answer,
  ) async {
    setState(() => _busy = true);
    try {
      var overwrite = false;
      if (card.before?.rating != null) {
        overwrite =
            await showDialog<bool>(
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
            ) ??
            false;
        if (!overwrite) return;
      }
      final undo = answer != null
          ? await widget.service.answer(
              widget.profileId,
              card,
              answer,
              overwrite: overwrite,
            )
          : await widget.service.rate(
              widget.profileId,
              card,
              rating!,
              overwrite: overwrite,
            );
      widget.onChanged();
      if (!mounted) return;
      setState(() {
        _undo = undo;
        _lastSkipped = null;
        _skipped.add(card.title.id);
        _message = undo == null
            ? 'No rating added. Review it later whenever you want.'
            : widget.followUp
            ? 'Rating saved and removed from Will try. Your status, progress and dates are unchanged.'
            : 'Rating saved. Your other library details are unchanged.';
      });
      await _load();
    } on RatingConflict {
      if (mounted) {
        setState(
          () => _message = 'This title changed elsewhere. Nothing was overwritten; reopen the cards to review it.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not save this answer. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _skip(RatingCandidate card) {
    setState(() {
      _skipped.add(card.title.id);
      _lastSkipped = card.title.id;
      _undo = null;
      _message = 'Skipped. No rating added.';
    });
  }

  Future<void> _dismiss(RatingCandidate card) async {
    setState(() => _busy = true);
    try {
      await widget.service.dismiss(widget.profileId, card.title.id);
      widget.onChanged();
      if (mounted) {
        setState(() {
          _skipped.add(card.title.id);
          _undo = null;
          _lastSkipped = null;
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
    final skipped = _lastSkipped;
    if (skipped != null) {
      setState(() {
        _skipped.remove(skipped);
        _lastSkipped = null;
        _message = 'Skip undone. No rating changed.';
      });
      return;
    }
    final token = _undo;
    if (token == null) return;
    setState(() => _busy = true);
    try {
      final restored = await widget.service.undo(widget.profileId, token);
      if (restored) widget.onChanged();
      if (!mounted) return;
      setState(() {
        _undo = null;
        if (restored) _skipped.remove(token.after.titleId);
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
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _cards
        ?.where((c) => !_skipped.contains(c.title.id))
        .toList();
    final card = remaining == null || remaining.isEmpty
        ? null
        : remaining.first;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.followUp
                        ? 'Tried a shortlist pick?'
                        : 'Rate your library',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Close rating cards',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              widget.followUp
                  ? 'Optional: only answer if you have tried it. A pick is not a watch, and no completion or date is assumed.'
                  : 'Optional: rate what you have tried. Unrated and planned titles are not likes. Only your rating changes.',
            ),
            const SizedBox(height: 20),
            if (_cards == null && _message == null)
              const LinearProgressIndicator(),
            if (_message != null)
              Semantics(liveRegion: true, child: Text(_message!)),
            if (card != null) ...[
              Text(
                card.title.displayTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (card.before != null)
                Text('Status: ${LibraryState.parse(card.before!.state).label}'),
              if (card.before?.rating != null)
                Text(
                  'Current rating: ${Rating.parse(card.before!.rating)?.label ?? card.before!.rating}',
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: widget.followUp
                    ? [
                        for (final choice in const [
                          (FollowUpAnswer.loved, 'Loved'),
                          (FollowUpAnswer.enjoyed, 'Enjoyed'),
                          (FollowUpAnswer.notForMe, 'Not for me'),
                          (FollowUpAnswer.haventStarted, "Haven't started"),
                        ])
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              visualDensity: VisualDensity.standard,
                              tapTargetSize: MaterialTapTargetSize.padded,
                            ),
                            onPressed: _busy
                                ? null
                                : () => _save(card, null, choice.$1),
                            child: Text(choice.$2),
                          ),
                      ]
                    : [
                        for (final choice in const [
                          (Rating.favourite, 'Loved'),
                          (Rating.enjoyed, 'Enjoyed'),
                          (Rating.once, 'One-time'),
                          (Rating.dropped, 'Dropped'),
                        ])
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              visualDensity: VisualDensity.standard,
                              tapTargetSize: MaterialTapTargetSize.padded,
                            ),
                            onPressed: _busy
                                ? null
                                : () => _save(card, choice.$1, null),
                            child: Text(choice.$2),
                          ),
                      ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => _skip(card),
                    child: const Text('Skip'),
                  ),
                  if (widget.followUp)
                    TextButton(
                      onPressed: _busy ? null : () => _dismiss(card),
                      child: const Text('Dismiss follow-up'),
                    ),
                ],
              ),
            ] else if (_cards != null)
              const Text(
                'Nothing more to rate here. Come back whenever you want.',
              ),
            if (_undo != null || _lastSkipped != null)
              TextButton(
                onPressed: _busy ? null : _undoLast,
                child: const Text('Undo'),
              ),
            if (widget.followUp && !_includeDismissed)
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          _includeDismissed = true;
                          _skipped.clear();
                        });
                        _load();
                      },
                child: const Text('Review dismissed picks'),
              ),
            if (!widget.followUp && !_includeRated)
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          _includeRated = true;
                          _skipped.clear();
                        });
                        _load();
                      },
                child: const Text('Review existing ratings'),
              ),
          ],
        ),
      ),
    );
  }
}
