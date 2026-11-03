import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models/title.dart';

/// One title the person liked or disliked, as sent to the AI route.
class AiTasteItem {
  const AiTasteItem(this.title, this.kind, {this.year, this.rating});
  final String title;
  final MediaKind kind;
  final int? year;

  /// 0-10, only for explicit ratings.
  final int? rating;
}

/// The compact profile sent to `/ai/recommend`. Names only: no ids, dates,
/// notes or anything else from the library.
class AiTasteProfile {
  const AiTasteProfile({
    required this.liked,
    required this.disliked,
    required this.kinds,
    this.mood,
  });
  final List<AiTasteItem> liked;
  final List<AiTasteItem> disliked;
  final Set<MediaKind> kinds;
  final String? mood;

  Map<String, dynamic> toJson() => {
    'liked': [
      for (final l in liked)
        {
          'title': l.title,
          'kind': l.kind.name,
          'year': ?l.year,
          'rating': ?l.rating,
        },
    ],
    'disliked': [
      for (final d in disliked) {'title': d.title, 'kind': d.kind.name},
    ],
    'kinds': [for (final k in kinds) k.name],
    if (mood != null && mood!.isNotEmpty) 'mood': mood,
  };
}

/// A suggestion by name only; it must still be found in the real catalog.
class AiSuggestion {
  const AiSuggestion({
    required this.title,
    required this.kind,
    required this.because,
    required this.why,
    this.year,
  });
  final String title;
  final MediaKind kind;
  final int? year;
  final String because;
  final String why;
}

class AiRecommendationUnavailable implements Exception {
  const AiRecommendationUnavailable(this.code);
  final String code;
  @override
  String toString() => 'AiRecommendationUnavailable($code)';
}

abstract class AiRecommendationClient {
  Future<List<AiSuggestion>> recommend(AiTasteProfile profile);
}

class HttpAiRecommendationClient implements AiRecommendationClient {
  HttpAiRecommendationClient(this.base, {http.Client? client})
    : _client = client ?? http.Client();
  final String base;
  final http.Client _client;

  @override
  Future<List<AiSuggestion>> recommend(AiTasteProfile profile) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$base/ai/recommend'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(profile.toJson()),
          )
          .timeout(const Duration(seconds: 40));
    } on Exception {
      throw const AiRecommendationUnavailable('offline');
    }
    Object? body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw const AiRecommendationUnavailable('bad_response');
    }
    if (res.statusCode != 200) {
      final code = body is Map ? body['error'] as String? : null;
      throw AiRecommendationUnavailable(code ?? 'http_${res.statusCode}');
    }
    return parseSuggestions(body, profile);
  }

  /// Keeps only well-formed items that cite a title we actually sent.
  static List<AiSuggestion> parseSuggestions(
    Object? body,
    AiTasteProfile profile,
  ) {
    if (body is! Map || body['suggestions'] is! List) return const [];
    final liked = {
      for (final l in profile.liked) l.title.toLowerCase(): l.title,
    };
    final out = <AiSuggestion>[];
    for (final raw in body['suggestions'] as List) {
      if (raw is! Map) continue;
      final title = raw['title'], because = raw['because'], why = raw['why'];
      if (title is! String || because is! String || why is! String) continue;
      final kind = MediaKind.parse(raw['kind'] as String?);
      final cite = liked[because.trim().toLowerCase()];
      if (kind == MediaKind.unknown ||
          !profile.kinds.contains(kind) ||
          cite == null ||
          title.trim().isEmpty ||
          why.trim().isEmpty) {
        continue;
      }
      out.add(
        AiSuggestion(
          title: title.trim(),
          kind: kind,
          year: (raw['year'] as num?)?.toInt(),
          because: cite,
          why: why.trim(),
        ),
      );
      if (out.length >= 30) break;
    }
    return out;
  }
}
