import 'package:flutter/material.dart' hide Title;

import '../../domain/models/library.dart';
import '../../domain/models/title.dart';

/// How the Library list is ordered.
enum LibrarySort {
  recent('Recent'),
  rating('Rating'),
  title('Title A-Z');

  const LibrarySort(this.label);
  final String label;
}

/// Coarse status buckets for the Library filter.
enum StatusFilter {
  active('In progress'),
  done('Finished'),
  planned('Planned'),
  unrated('Not rated');

  const StatusFilter(this.label);
  final String label;

  bool matches(LibraryEntry e) => switch (this) {
    active =>
      e.state == LibraryState.watching ||
          e.state == LibraryState.reading ||
          e.state == LibraryState.caughtUp ||
          e.state == LibraryState.onHold,
    done =>
      e.state == LibraryState.completed ||
          e.state == LibraryState.seen ||
          e.state == LibraryState.partial ||
          e.state == LibraryState.dropped,
    planned => e.state == LibraryState.planned,
    unrated => e.rating == null,
  };
}

typedef LibraryRow = (LibraryEntry, Title);

/// Search, format and status filters plus a sort, applied together.
@immutable
class LibraryQuery {
  const LibraryQuery({
    this.text = '',
    this.sort = LibrarySort.recent,
    this.kind,
    this.status,
  });

  final String text;
  final LibrarySort sort;
  final MediaKind? kind;
  final StatusFilter? status;

  bool get filtering => text.isNotEmpty || kind != null || status != null;

  LibraryQuery copyWith({
    String? text,
    LibrarySort? sort,
    MediaKind? kind,
    StatusFilter? status,
    bool clearKind = false,
    bool clearStatus = false,
  }) => LibraryQuery(
    text: text ?? this.text,
    sort: sort ?? this.sort,
    kind: clearKind ? null : (kind ?? this.kind),
    status: clearStatus ? null : (status ?? this.status),
  );

  bool matchesText(Title t) {
    final q = text.trim().toLowerCase();
    return q.isEmpty ||
        t.displayTitle.toLowerCase().contains(q) ||
        (t.altTitle?.toLowerCase().contains(q) ?? false);
  }

  bool matches(LibraryRow r) =>
      matchesText(r.$2) &&
      (kind == null || r.$2.kind == kind) &&
      (status == null || status!.matches(r.$1));

  /// Sorted copy. The input is newest first, and sorts are stable.
  List<LibraryRow> apply(Iterable<LibraryRow> rows) {
    final out = rows.where(matches).toList();
    switch (sort) {
      case LibrarySort.recent:
        break;
      case LibrarySort.rating:
        double w(LibraryRow r) => r.$1.rating?.weight ?? -100;
        final indexed = [for (var i = 0; i < out.length; i++) (i, out[i])];
        indexed.sort((a, b) {
          final c = w(b.$2).compareTo(w(a.$2));
          return c != 0 ? c : a.$1.compareTo(b.$1);
        });
        return [for (final p in indexed) p.$2];
      case LibrarySort.title:
        out.sort(
          (a, b) => a.$2.displayTitle.toLowerCase().compareTo(
            b.$2.displayTitle.toLowerCase(),
          ),
        );
    }
    return out;
  }
}

/// What Cue has learned from explicit ratings, in plain terms.
@immutable
class TasteSummary {
  const TasteSummary({
    required this.rated,
    required this.liked,
    required this.genres,
    required this.kinds,
  });

  /// Titles with an explicit rating of any kind.
  final int rated;

  /// Rated positively (the evidence that pulls recommendations towards them).
  final int liked;
  final List<String> genres;
  final List<MediaKind> kinds;

  static TasteSummary from(Iterable<LibraryRow> rows, {int top = 3}) {
    var rated = 0;
    var liked = 0;
    final genreScore = <String, double>{};
    final kindScore = <MediaKind, double>{};
    for (final (e, t) in rows) {
      final r = e.rating;
      if (r == null) continue;
      rated++;
      if (r.weight <= 0) continue;
      liked++;
      for (final g in t.genres) {
        genreScore[g] = (genreScore[g] ?? 0) + r.weight;
      }
      if (t.kind != MediaKind.unknown) {
        kindScore[t.kind] = (kindScore[t.kind] ?? 0) + r.weight;
      }
    }
    List<K> best<K>(Map<K, double> m, String Function(K) name) {
      final keys = m.keys.toList()
        ..sort((a, b) {
          final c = m[b]!.compareTo(m[a]!);
          return c != 0 ? c : name(a).compareTo(name(b));
        });
      return keys.take(top).toList();
    }

    return TasteSummary(
      rated: rated,
      liked: liked,
      genres: best<String>(genreScore, (g) => g),
      kinds: best<MediaKind>(kindScore, (k) => k.label),
    );
  }
}
