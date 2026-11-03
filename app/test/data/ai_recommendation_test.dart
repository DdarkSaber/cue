import 'dart:async';
import 'dart:convert';

import 'package:cue/app/providers.dart';
import 'package:cue/data/ai_recommendation_client.dart';
import 'package:cue/data/ai_recommendation_repository.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/ai_taste.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/settings.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/ranker.dart';
import 'package:cue/features/deck/candidate_sources.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fakes.dart';

class _FakeClient implements AiRecommendationClient {
  _FakeClient(this.out);
  List<AiSuggestion> out;
  final profiles = <AiTasteProfile>[];
  @override
  Future<List<AiSuggestion>> recommend(AiTasteProfile profile) async {
    profiles.add(profile);
    return out;
  }
}

AiSuggestion sug(
  String t,
  String because, {
  MediaKind kind = MediaKind.anime,
}) =>
    AiSuggestion(title: t, kind: kind, because: because, why: 'Shares a mood.');

Map<String, dynamic> hit(int id, String name, {String kind = 'anime'}) => {
  ...item(id, kind: kind),
  'titleEn': name,
};

void main() {
  test('settings round-trip and default to off', () {
    expect(const AppSettings().aiPicks, isFalse);
    expect(AppSettings.fromEntries(const {}).aiPicks, isFalse);
    final s = const AppSettings(aiPicks: true).toEntries();
    expect(AppSettings.fromEntries(s).aiPicks, isTrue);
  });

  test('client parses only suggestions citing a sent liked title', () {
    const profile = AiTasteProfile(
      liked: [AiTasteItem('Frieren', MediaKind.anime)],
      disliked: [],
      kinds: {MediaKind.anime},
    );
    final out = HttpAiRecommendationClient.parseSuggestions({
      'suggestions': [
        {'title': 'A', 'kind': 'anime', 'because': 'frieren', 'why': 'ok'},
        {'title': 'B', 'kind': 'anime', 'because': 'Unknown', 'why': 'ok'},
        {'title': 'C', 'kind': 'movie', 'because': 'Frieren', 'why': 'ok'},
        {'title': 'D', 'kind': 'anime', 'because': 'Frieren'},
        'junk',
      ],
    }, profile);
    expect([for (final s in out) s.title], ['A']);
    expect(out.single.because, 'Frieren');
  });

  test('client posts a names-only profile and surfaces 503', () async {
    late Map<String, dynamic> sent;
    final client = HttpAiRecommendationClient(
      'https://api.test',
      client: MockClient((req) async {
        expect(req.url.path, '/ai/recommend');
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{"error":"not_configured"}', 503);
      }),
    );
    await expectLater(
      client.recommend(
        const AiTasteProfile(
          liked: [
            AiTasteItem('Frieren', MediaKind.anime, year: 2023, rating: 10),
          ],
          disliked: [AiTasteItem('Nope', MediaKind.movie)],
          kinds: {MediaKind.anime},
        ),
      ),
      throwsA(
        isA<AiRecommendationUnavailable>().having(
          (e) => e.code,
          'code',
          'not_configured',
        ),
      ),
    );
    expect(sent.keys.toSet(), {'liked', 'disliked', 'kinds'});
    expect(sent['liked'], [
      {'title': 'Frieren', 'kind': 'anime', 'year': 2023, 'rating': 10},
    ]);
  });

  group('repository', () {
    late FakeGateway gateway;
    late CatalogRepository catalog;
    late LibraryRepository library;
    late ProfileRepository profiles;
    late _FakeClient client;
    late AiRecommendationRepository repo;
    late String pid;
    var now = DateTime(2026, 11, 3, 12);

    setUp(() async {
      now = DateTime(2026, 11, 3, 12);
      final db = memoryDb();
      addTearDown(db.close);
      gateway = FakeGateway();
      catalog = CatalogRepository(db, gateway);
      library = LibraryRepository(db);
      profiles = ProfileRepository(db);
      pid = (await profiles.ensureActive()).id;
      client = _FakeClient([]);
      repo = AiRecommendationRepository(
        client: client,
        catalog: catalog,
        profiles: profiles,
        clock: () => now,
      );
      // Six liked titles (4 rated high, 1 completed import, 1 disliked).
      await catalog.upsert([
        for (var i = 1; i <= 7; i++)
          CatalogItemDto({
            ...item(i, franchiseKey: 'f$i'),
            'titleEn': 'Liked $i',
          }),
      ]);
      Future<void> save(int i, LibraryState s, [Rating? r]) =>
          library.saveEntry(pid, 'anilist:$i', state: s, rating: r);
      await save(1, LibraryState.completed, Rating.favourite);
      await save(2, LibraryState.completed, Rating.enjoyed);
      await save(3, LibraryState.completed, Rating.enjoyed);
      await save(4, LibraryState.completed, Rating.wouldRewatch);
      await save(5, LibraryState.completed);
      await save(6, LibraryState.dropped, Rating.disliked);
    });

    test('profile puts explicit ratings first and keeps names only', () async {
      gateway.matchCatalog['new one'] = [hit(20, 'New One')];
      client.out = [sug('New One', 'Liked 1')];
      final signals = await library.signals(pid);
      expect(await repo.refreshIfDue(pid, signals, {MediaKind.anime}), isTrue);
      final p = client.profiles.single;
      expect(p.liked.first.title, 'Liked 1');
      expect(p.liked.first.rating, 10);
      expect(p.liked.last.title, 'Liked 5');
      expect(p.liked.last.rating, isNull);
      expect([for (final d in p.disliked) d.title], ['Liked 6']);
      final picks = await repo.picks(pid);
      expect(
        picks['anilist:20']!.reason,
        startsWith('Because you loved Liked 1: '),
      );
      expect(await catalog.titleById('anilist:20'), isNotNull);
    });

    test(
      'drops unresolved, similar, library and disliked suggestions',
      () async {
        gateway.matchCatalog['good one'] = [hit(30, 'Good One')];
        gateway.matchCatalog['liked 2'] = [hit(2, 'Liked 2')];
        gateway.matchCatalog['liked 6'] = [hit(6, 'Liked 6')];
        gateway.matchCatalog['almost there'] = [hit(31, 'Almost There Now')];
        gateway.matchCatalog['adult one'] = [
          {...hit(32, 'Adult One'), 'adult': true},
        ];
        gateway.matchCatalog['a novel'] = [
          {...hit(33, 'A Novel'), 'format': 'NOVEL'},
        ];
        client.out = [
          sug('Good One', 'Liked 1'),
          sug('Never Heard Of It', 'Liked 1'),
          sug('Liked 2', 'Liked 1'),
          sug('Liked 6', 'Liked 1'),
          sug('Almost There', 'Liked 1'),
          sug('Adult One', 'Liked 1'),
          sug('A Novel', 'Liked 1'),
        ];
        final signals = await library.signals(pid);
        await repo.refreshIfDue(pid, signals, {MediaKind.anime});
        expect((await repo.picks(pid)).keys, ['anilist:30']);
      },
    );

    test('refreshes only when old or after enough new ratings', () async {
      gateway.matchCatalog['good one'] = [hit(30, 'Good One')];
      client.out = [sug('Good One', 'Liked 1')];
      var signals = await library.signals(pid);
      await repo.refreshIfDue(pid, signals, {MediaKind.anime});
      expect(client.profiles, hasLength(1));

      now = now.add(const Duration(hours: 1));
      expect(await repo.refreshIfDue(pid, signals, {MediaKind.anime}), isFalse);
      expect(client.profiles, hasLength(1));

      now = now.add(const Duration(hours: 4));
      await repo.refreshIfDue(pid, signals, {MediaKind.anime});
      expect(client.profiles, hasLength(2));

      // Five new ratings inside the window force a refresh.
      await catalog.upsert([
        for (var i = 40; i < 45; i++) CatalogItemDto(item(i)),
      ]);
      for (var i = 40; i < 45; i++) {
        await library.saveEntry(
          pid,
          'anilist:$i',
          state: LibraryState.completed,
          rating: Rating.enjoyed,
        );
      }
      signals = await library.signals(pid);
      await repo.refreshIfDue(pid, signals, {MediaKind.anime});
      expect(client.profiles, hasLength(3));
    });

    test('too little taste sends nothing', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final p2 = ProfileRepository(db);
      final id2 = (await p2.ensureActive()).id;
      final r2 = AiRecommendationRepository(
        client: client,
        catalog: CatalogRepository(db, FakeGateway()),
        profiles: p2,
      );
      expect(
        await r2.refreshIfDue(id2, await LibraryRepository(db).signals(id2), {
          MediaKind.anime,
        }),
        isFalse,
      );
      expect(client.profiles, isEmpty);
    });

    test('a failing service keeps old picks and does not throw', () async {
      final failing = AiRecommendationRepository(
        client: _Throwing(),
        catalog: catalog,
        profiles: profiles,
      );
      final signals = await library.signals(pid);
      expect(
        await failing.refreshIfDue(pid, signals, {MediaKind.anime}),
        isFalse,
      );
    });

    test(
      'forgetting deletes stored picks and beats an in-flight refresh',
      () async {
        gateway.matchCatalog['good one'] = [hit(30, 'Good One')];
        client.out = [sug('Good One', 'Liked 1')];
        final signals = await library.signals(pid);
        expect(
          await repo.refreshIfDue(pid, signals, {MediaKind.anime}),
          isTrue,
        );
        expect(await profiles.rawSetting(pid, 'aiPicks.v1'), isNotNull);
        await AiRecommendationRepository.forget(profiles, pid);
        expect(await profiles.rawSetting(pid, 'aiPicks.v1'), isNull);
        expect(await repo.picks(pid), isEmpty);

        // An answer already on its way when the toggle went off is dropped.
        final slow = _SlowClient();
        final racing = AiRecommendationRepository(
          client: slow,
          catalog: catalog,
          profiles: profiles,
          clock: () => now,
        );
        final pending = racing.refreshIfDue(pid, signals, {MediaKind.anime});
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await AiRecommendationRepository.forget(profiles, pid);
        slow.gate.complete([sug('Good One', 'Liked 1')]);
        expect(await pending, isFalse);
        expect(await profiles.rawSetting(pid, 'aiPicks.v1'), isNull);
      },
    );

    test('turning the setting off deletes the stored picks', () async {
      gateway.matchCatalog['good one'] = [hit(30, 'Good One')];
      client.out = [sug('Good One', 'Liked 1')];
      final signals = await library.signals(pid);
      await repo.refreshIfDue(pid, signals, {MediaKind.anime});
      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(profiles),
          profileIdProvider.overrideWith((ref) async => pid),
        ],
      );
      addTearDown(container.dispose);
      final settings = container.read(settingsProvider.notifier);
      await container.read(settingsProvider.future);
      await settings.change((x) => x.copyWith(aiPicks: true));
      expect(await profiles.rawSetting(pid, 'aiPicks.v1'), isNotNull);
      await settings.change((x) => x.copyWith(aiPicks: false));
      expect(await profiles.rawSetting(pid, 'aiPicks.v1'), isNull);
    });

    test('source is inert while the toggle is off', () async {
      final source = AiTasteSource(repo);
      final signals = await library.signals(pid);
      source.refill(pid, signals, {MediaKind.anime}, const AppSettings());
      await Future<void>.delayed(Duration.zero);
      expect(client.profiles, isEmpty);
      expect(await source.provenance(pid, const AppSettings()), isEmpty);
    });
  });

  group('mixing', () {
    Title t(int i) => Title(id: 't$i', kind: MediaKind.anime, titleEn: 'T$i');
    List<RankedCard> cards(String p, int n, double top) => [
      for (var i = 0; i < n; i++)
        RankedCard(
          Title(id: '$p$i', kind: MediaKind.anime, titleEn: '$p$i'),
          top - i * 0.01,
          'main',
        ),
    ];

    test('AI cards are capped at 30% and carry the because line', () {
      final picks = {
        for (var i = 0; i < 10; i++) 'a$i': AiPick('a$i', 'Frieren', 'Quiet.'),
      };
      final out = mixAiCards(
        cards('m', 10, 0.5),
        cards('a', 10, 0.9),
        picks,
        size: 10,
      );
      expect(out, hasLength(10));
      final ai = out.where((c) => c.title.id.startsWith('a')).toList();
      expect(ai, hasLength(3));
      expect(ai.first.reason, 'Because you loved Frieren: Quiet.');
    });

    test(
      'a card with a seed reason and an AI pick shows exactly one reason',
      () {
        final picks = {'a0': const AiPick('a0', 'Frieren', 'Quiet.')};
        const seeded = RankedCard(
          Title(id: 'a0', kind: MediaKind.anime, titleEn: 'A0'),
          0.9,
          'Because you liked Steins;Gate. Strong rating.',
          becauseOf: ['seed1'],
        );
        final out = mixAiCards(const [], [seeded], picks, size: 10);
        expect(out.single.reason, 'Because you loved Frieren: Quiet.');
        expect(out.single.reason, isNot(contains('Because you liked')));
        expect('Because you'.allMatches(out.single.reason), hasLength(1));
        expect(out.single.becauseOf, ['seed1']);
      },
    );

    test('boost is bounded: a much weaker AI card does not jump the deck', () {
      final picks = {'a0': const AiPick('a0', 'X', 'y')};
      final out = mixAiCards(
        cards('m', 10, 0.9),
        cards('a', 1, 0.1),
        picks,
        size: 10,
      );
      expect(out.first.title.id, 'm0');
      expect(out.where((c) => c.title.id == 'a0'), isEmpty);
    });

    test('dealWithPicks without picks is the plain deal', () {
      final pool = [t(1), t(2)];
      final out = dealWithPicks(
        (p, n) => [for (final x in p.take(n)) RankedCard(x, 1, 'r')],
        pool,
        const {},
        size: 10,
      );
      expect(out, hasLength(2));
    });
  });
}

class _SlowClient implements AiRecommendationClient {
  final gate = Completer<List<AiSuggestion>>();
  @override
  Future<List<AiSuggestion>> recommend(AiTasteProfile profile) => gate.future;
}

class _Throwing implements AiRecommendationClient {
  @override
  Future<List<AiSuggestion>> recommend(AiTasteProfile profile) async =>
      throw const AiRecommendationUnavailable('offline');
}
