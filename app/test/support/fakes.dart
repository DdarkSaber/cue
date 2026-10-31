import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/domain/models/title.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';

CueDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return CueDatabase(NativeDatabase.memory());
}

/// Synthetic catalog item in the Worker's shape. Never real personal data.
Map<String, dynamic> item(
  int id, {
  String provider = 'anilist',
  String? providerKind,
  String kind = 'anime',
  String title = 'Synthetic',
  int? year = 2024,
  List<String> genres = const ['Action'],
  List<String> tags = const [],
  int? score = 75,
  int? episodes = 12,
  int? idMal,
  bool adult = false,
  String? franchiseKey,
  String status = 'finished',
  String? country = 'JP',
}) => {
  'provider': provider,
  'providerId': '$id',
  'providerKind': providerKind,
  'idMal': idMal,
  'kind': kind,
  'titleEn': '$title $id',
  'titleRomaji': null,
  'titleNative': null,
  'year': year,
  'country': country,
  'format': 'TV',
  'status': status,
  'episodes': episodes,
  'chapters': null,
  'seasons': <Object>[],
  'genres': genres,
  'tags': tags,
  'score': score,
  'posterUrl': null,
  'backdropUrl': null,
  'synopsis': 'A synthetic story.',
  'adult': adult,
  'franchiseKey': franchiseKey,
};

/// In-memory Worker: pages of synthetic items per kind.
class FakeGateway implements CatalogGateway {
  FakeGateway({this.pages = const {}, this.offline = false});

  final Map<MediaKind, List<List<Map<String, dynamic>>>> pages;
  bool offline;
  final calls = <String>[];
  final searchResults = <String, List<Map<String, dynamic>>>{};

  @override
  Future<CatalogPageDto> discover(
    MediaKind kind, {
    String? mood,
    int page = 1,
  }) async {
    calls.add('discover:${kind.name}:${mood ?? '-'}:$page');
    if (offline) throw const CatalogUnavailable('offline');
    final list = pages[kind];
    if (list == null) throw const CatalogUnavailable('not_configured');
    if (page > list.length) return const CatalogPageDto([], false);
    return CatalogPageDto(
      list[page - 1].map(CatalogItemDto.new).toList(),
      page < list.length,
    );
  }

  @override
  Future<CatalogItemDto?> title(
    String provider,
    String id, {
    String? type,
  }) async {
    calls.add('title:$provider:$id');
    if (offline) throw const CatalogUnavailable('offline');
    for (final list in pages.values) {
      for (final page in list) {
        for (final i in page) {
          if (i['provider'] == provider && i['providerId'] == id) {
            return CatalogItemDto({
              ...i,
              'seasons': [
                {'number': 1, 'episodes': i['episodes'], 'year': i['year']},
              ],
            });
          }
        }
      }
    }
    return null;
  }

  @override
  Future<List<CatalogItemDto>> search(String query, {MediaKind? kind}) async {
    calls.add('search:$query');
    if (offline) throw const CatalogUnavailable('offline');
    return (searchResults[query.toLowerCase()] ?? const [])
        .map(CatalogItemDto.new)
        .toList();
  }

  @override
  Future<WatchProvidersDto> providers(
    String tmdbId,
    String type,
    String region,
  ) async => const WatchProvidersDto(
    link: null,
    stream: ['Synthetic Stream'],
    free: [],
    rent: [],
    buy: [],
  );

  @override
  String imageUrl(String posterUrl) => posterUrl;
}
