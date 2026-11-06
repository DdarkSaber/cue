import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/models/title.dart';

/// Chapter counts for ongoing comics. AniList leaves chapters empty while a
/// series is releasing; MangaUpdates tracks the latest chapter. Called from
/// the device: MangaUpdates refuses Cloudflare Workers and browser origins,
/// so the web build goes without.
class MangaUpdatesClient {
  MangaUpdatesClient({http.Client? client, this.enabled = !kIsWeb})
    : _client = client ?? http.Client();

  final http.Client _client;
  final bool enabled;
  static const _api = 'https://api.mangaupdates.com/v1';
  static final _memo = <String, int?>{};

  static const _types = {
    MediaKind.manhwa: 'Manhwa',
    MediaKind.manhua: 'Manhua',
    MediaKind.manga: 'Manga',
  };

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9぀-￿]'), '');

  /// The latest chapter, when one series clearly is this title.
  Future<int?> latestChapter(Title t) async {
    final type = _types[t.kind];
    if (!enabled || type == null) return null;
    if (_memo.containsKey(t.id)) return _memo[t.id];
    final names = {
      for (final n in [t.titleEn, t.titleRomaji, t.titleNative])
        if (n != null && _norm(n).isNotEmpty) _norm(n),
    };
    int? found;
    try {
      final res = await _client
          .post(
            Uri.parse('$_api/series/search'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'search': t.titleEn ?? t.titleRomaji ?? t.titleNative,
              'per_page': 5,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final results =
          ((jsonDecode(res.body) as Map)['results'] as List?) ?? const [];
      String? id;
      for (final r in results) {
        final rec = (r as Map)['record'] as Map? ?? const {};
        if (rec['type'] != type) continue;
        final named =
            names.contains(_norm('${rec['title']}')) ||
            names.contains(_norm('${r['hit_title'] ?? ''}'));
        final sameYear = '${rec['year']}' == '${t.year}';
        if (named || (sameYear && id == null)) {
          id = '${rec['series_id']}';
          if (named) break;
        }
      }
      if (id != null) {
        final d = await _client
            .get(Uri.parse('$_api/series/$id'))
            .timeout(const Duration(seconds: 8));
        if (d.statusCode == 200) {
          final latest = (jsonDecode(d.body) as Map)['latest_chapter'];
          final n = latest is num ? latest.toInt() : int.tryParse('$latest');
          if (n != null && n > 0) found = n;
        }
      }
    } on Object catch (e) {
      debugPrint('Chapter lookup failed (${e.runtimeType}).');
      return null;
    }
    return _memo[t.id] = found;
  }
}
