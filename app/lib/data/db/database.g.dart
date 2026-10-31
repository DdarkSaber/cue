// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CatalogTitlesTable extends CatalogTitles
    with TableInfo<$CatalogTitlesTable, CatalogTitle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogTitlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaKindMeta = const VerificationMeta(
    'mediaKind',
  );
  @override
  late final GeneratedColumn<String> mediaKind = GeneratedColumn<String>(
    'media_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleEnMeta = const VerificationMeta(
    'titleEn',
  );
  @override
  late final GeneratedColumn<String> titleEn = GeneratedColumn<String>(
    'title_en',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleRomajiMeta = const VerificationMeta(
    'titleRomaji',
  );
  @override
  late final GeneratedColumn<String> titleRomaji = GeneratedColumn<String>(
    'title_romaji',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleNativeMeta = const VerificationMeta(
    'titleNative',
  );
  @override
  late final GeneratedColumn<String> titleNative = GeneratedColumn<String>(
    'title_native',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _episodesMeta = const VerificationMeta(
    'episodes',
  );
  @override
  late final GeneratedColumn<int> episodes = GeneratedColumn<int>(
    'episodes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chaptersMeta = const VerificationMeta(
    'chapters',
  );
  @override
  late final GeneratedColumn<int> chapters = GeneratedColumn<int>(
    'chapters',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seasonsJsonMeta = const VerificationMeta(
    'seasonsJson',
  );
  @override
  late final GeneratedColumn<String> seasonsJson = GeneratedColumn<String>(
    'seasons_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _genresJsonMeta = const VerificationMeta(
    'genresJson',
  );
  @override
  late final GeneratedColumn<String> genresJson = GeneratedColumn<String>(
    'genres_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _posterUrlMeta = const VerificationMeta(
    'posterUrl',
  );
  @override
  late final GeneratedColumn<String> posterUrl = GeneratedColumn<String>(
    'poster_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backdropUrlMeta = const VerificationMeta(
    'backdropUrl',
  );
  @override
  late final GeneratedColumn<String> backdropUrl = GeneratedColumn<String>(
    'backdrop_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _synopsisMeta = const VerificationMeta(
    'synopsis',
  );
  @override
  late final GeneratedColumn<String> synopsis = GeneratedColumn<String>(
    'synopsis',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _franchiseIdMeta = const VerificationMeta(
    'franchiseId',
  );
  @override
  late final GeneratedColumn<String> franchiseId = GeneratedColumn<String>(
    'franchise_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _adultMeta = const VerificationMeta('adult');
  @override
  late final GeneratedColumn<bool> adult = GeneratedColumn<bool>(
    'adult',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("adult" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _detailedMeta = const VerificationMeta(
    'detailed',
  );
  @override
  late final GeneratedColumn<bool> detailed = GeneratedColumn<bool>(
    'detailed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("detailed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mediaKind,
    titleEn,
    titleRomaji,
    titleNative,
    year,
    country,
    format,
    status,
    episodes,
    chapters,
    seasonsJson,
    genresJson,
    tagsJson,
    score,
    posterUrl,
    backdropUrl,
    synopsis,
    franchiseId,
    adult,
    detailed,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_titles';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogTitle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('media_kind')) {
      context.handle(
        _mediaKindMeta,
        mediaKind.isAcceptableOrUnknown(data['media_kind']!, _mediaKindMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaKindMeta);
    }
    if (data.containsKey('title_en')) {
      context.handle(
        _titleEnMeta,
        titleEn.isAcceptableOrUnknown(data['title_en']!, _titleEnMeta),
      );
    }
    if (data.containsKey('title_romaji')) {
      context.handle(
        _titleRomajiMeta,
        titleRomaji.isAcceptableOrUnknown(
          data['title_romaji']!,
          _titleRomajiMeta,
        ),
      );
    }
    if (data.containsKey('title_native')) {
      context.handle(
        _titleNativeMeta,
        titleNative.isAcceptableOrUnknown(
          data['title_native']!,
          _titleNativeMeta,
        ),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('episodes')) {
      context.handle(
        _episodesMeta,
        episodes.isAcceptableOrUnknown(data['episodes']!, _episodesMeta),
      );
    }
    if (data.containsKey('chapters')) {
      context.handle(
        _chaptersMeta,
        chapters.isAcceptableOrUnknown(data['chapters']!, _chaptersMeta),
      );
    }
    if (data.containsKey('seasons_json')) {
      context.handle(
        _seasonsJsonMeta,
        seasonsJson.isAcceptableOrUnknown(
          data['seasons_json']!,
          _seasonsJsonMeta,
        ),
      );
    }
    if (data.containsKey('genres_json')) {
      context.handle(
        _genresJsonMeta,
        genresJson.isAcceptableOrUnknown(data['genres_json']!, _genresJsonMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('poster_url')) {
      context.handle(
        _posterUrlMeta,
        posterUrl.isAcceptableOrUnknown(data['poster_url']!, _posterUrlMeta),
      );
    }
    if (data.containsKey('backdrop_url')) {
      context.handle(
        _backdropUrlMeta,
        backdropUrl.isAcceptableOrUnknown(
          data['backdrop_url']!,
          _backdropUrlMeta,
        ),
      );
    }
    if (data.containsKey('synopsis')) {
      context.handle(
        _synopsisMeta,
        synopsis.isAcceptableOrUnknown(data['synopsis']!, _synopsisMeta),
      );
    }
    if (data.containsKey('franchise_id')) {
      context.handle(
        _franchiseIdMeta,
        franchiseId.isAcceptableOrUnknown(
          data['franchise_id']!,
          _franchiseIdMeta,
        ),
      );
    }
    if (data.containsKey('adult')) {
      context.handle(
        _adultMeta,
        adult.isAcceptableOrUnknown(data['adult']!, _adultMeta),
      );
    }
    if (data.containsKey('detailed')) {
      context.handle(
        _detailedMeta,
        detailed.isAcceptableOrUnknown(data['detailed']!, _detailedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatalogTitle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogTitle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mediaKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_kind'],
      )!,
      titleEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_en'],
      ),
      titleRomaji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_romaji'],
      ),
      titleNative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_native'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      episodes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episodes'],
      ),
      chapters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapters'],
      ),
      seasonsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seasons_json'],
      )!,
      genresJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genres_json'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      ),
      posterUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster_url'],
      ),
      backdropUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backdrop_url'],
      ),
      synopsis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synopsis'],
      ),
      franchiseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}franchise_id'],
      ),
      adult: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}adult'],
      )!,
      detailed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}detailed'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CatalogTitlesTable createAlias(String alias) {
    return $CatalogTitlesTable(attachedDatabase, alias);
  }
}

class CatalogTitle extends DataClass implements Insertable<CatalogTitle> {
  final String id;
  final String mediaKind;
  final String? titleEn;
  final String? titleRomaji;
  final String? titleNative;
  final int? year;
  final String? country;
  final String? format;
  final String status;
  final int? episodes;
  final int? chapters;
  final String seasonsJson;
  final String genresJson;
  final String tagsJson;
  final int? score;
  final String? posterUrl;
  final String? backdropUrl;
  final String? synopsis;
  final String? franchiseId;
  final bool adult;

  /// True once the full title (seasons, keywords) has been fetched.
  final bool detailed;
  final DateTime updatedAt;
  const CatalogTitle({
    required this.id,
    required this.mediaKind,
    this.titleEn,
    this.titleRomaji,
    this.titleNative,
    this.year,
    this.country,
    this.format,
    required this.status,
    this.episodes,
    this.chapters,
    required this.seasonsJson,
    required this.genresJson,
    required this.tagsJson,
    this.score,
    this.posterUrl,
    this.backdropUrl,
    this.synopsis,
    this.franchiseId,
    required this.adult,
    required this.detailed,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['media_kind'] = Variable<String>(mediaKind);
    if (!nullToAbsent || titleEn != null) {
      map['title_en'] = Variable<String>(titleEn);
    }
    if (!nullToAbsent || titleRomaji != null) {
      map['title_romaji'] = Variable<String>(titleRomaji);
    }
    if (!nullToAbsent || titleNative != null) {
      map['title_native'] = Variable<String>(titleNative);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(format);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || episodes != null) {
      map['episodes'] = Variable<int>(episodes);
    }
    if (!nullToAbsent || chapters != null) {
      map['chapters'] = Variable<int>(chapters);
    }
    map['seasons_json'] = Variable<String>(seasonsJson);
    map['genres_json'] = Variable<String>(genresJson);
    map['tags_json'] = Variable<String>(tagsJson);
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<int>(score);
    }
    if (!nullToAbsent || posterUrl != null) {
      map['poster_url'] = Variable<String>(posterUrl);
    }
    if (!nullToAbsent || backdropUrl != null) {
      map['backdrop_url'] = Variable<String>(backdropUrl);
    }
    if (!nullToAbsent || synopsis != null) {
      map['synopsis'] = Variable<String>(synopsis);
    }
    if (!nullToAbsent || franchiseId != null) {
      map['franchise_id'] = Variable<String>(franchiseId);
    }
    map['adult'] = Variable<bool>(adult);
    map['detailed'] = Variable<bool>(detailed);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CatalogTitlesCompanion toCompanion(bool nullToAbsent) {
    return CatalogTitlesCompanion(
      id: Value(id),
      mediaKind: Value(mediaKind),
      titleEn: titleEn == null && nullToAbsent
          ? const Value.absent()
          : Value(titleEn),
      titleRomaji: titleRomaji == null && nullToAbsent
          ? const Value.absent()
          : Value(titleRomaji),
      titleNative: titleNative == null && nullToAbsent
          ? const Value.absent()
          : Value(titleNative),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      country: country == null && nullToAbsent
          ? const Value.absent()
          : Value(country),
      format: format == null && nullToAbsent
          ? const Value.absent()
          : Value(format),
      status: Value(status),
      episodes: episodes == null && nullToAbsent
          ? const Value.absent()
          : Value(episodes),
      chapters: chapters == null && nullToAbsent
          ? const Value.absent()
          : Value(chapters),
      seasonsJson: Value(seasonsJson),
      genresJson: Value(genresJson),
      tagsJson: Value(tagsJson),
      score: score == null && nullToAbsent
          ? const Value.absent()
          : Value(score),
      posterUrl: posterUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(posterUrl),
      backdropUrl: backdropUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropUrl),
      synopsis: synopsis == null && nullToAbsent
          ? const Value.absent()
          : Value(synopsis),
      franchiseId: franchiseId == null && nullToAbsent
          ? const Value.absent()
          : Value(franchiseId),
      adult: Value(adult),
      detailed: Value(detailed),
      updatedAt: Value(updatedAt),
    );
  }

  factory CatalogTitle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogTitle(
      id: serializer.fromJson<String>(json['id']),
      mediaKind: serializer.fromJson<String>(json['mediaKind']),
      titleEn: serializer.fromJson<String?>(json['titleEn']),
      titleRomaji: serializer.fromJson<String?>(json['titleRomaji']),
      titleNative: serializer.fromJson<String?>(json['titleNative']),
      year: serializer.fromJson<int?>(json['year']),
      country: serializer.fromJson<String?>(json['country']),
      format: serializer.fromJson<String?>(json['format']),
      status: serializer.fromJson<String>(json['status']),
      episodes: serializer.fromJson<int?>(json['episodes']),
      chapters: serializer.fromJson<int?>(json['chapters']),
      seasonsJson: serializer.fromJson<String>(json['seasonsJson']),
      genresJson: serializer.fromJson<String>(json['genresJson']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      score: serializer.fromJson<int?>(json['score']),
      posterUrl: serializer.fromJson<String?>(json['posterUrl']),
      backdropUrl: serializer.fromJson<String?>(json['backdropUrl']),
      synopsis: serializer.fromJson<String?>(json['synopsis']),
      franchiseId: serializer.fromJson<String?>(json['franchiseId']),
      adult: serializer.fromJson<bool>(json['adult']),
      detailed: serializer.fromJson<bool>(json['detailed']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mediaKind': serializer.toJson<String>(mediaKind),
      'titleEn': serializer.toJson<String?>(titleEn),
      'titleRomaji': serializer.toJson<String?>(titleRomaji),
      'titleNative': serializer.toJson<String?>(titleNative),
      'year': serializer.toJson<int?>(year),
      'country': serializer.toJson<String?>(country),
      'format': serializer.toJson<String?>(format),
      'status': serializer.toJson<String>(status),
      'episodes': serializer.toJson<int?>(episodes),
      'chapters': serializer.toJson<int?>(chapters),
      'seasonsJson': serializer.toJson<String>(seasonsJson),
      'genresJson': serializer.toJson<String>(genresJson),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'score': serializer.toJson<int?>(score),
      'posterUrl': serializer.toJson<String?>(posterUrl),
      'backdropUrl': serializer.toJson<String?>(backdropUrl),
      'synopsis': serializer.toJson<String?>(synopsis),
      'franchiseId': serializer.toJson<String?>(franchiseId),
      'adult': serializer.toJson<bool>(adult),
      'detailed': serializer.toJson<bool>(detailed),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CatalogTitle copyWith({
    String? id,
    String? mediaKind,
    Value<String?> titleEn = const Value.absent(),
    Value<String?> titleRomaji = const Value.absent(),
    Value<String?> titleNative = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> country = const Value.absent(),
    Value<String?> format = const Value.absent(),
    String? status,
    Value<int?> episodes = const Value.absent(),
    Value<int?> chapters = const Value.absent(),
    String? seasonsJson,
    String? genresJson,
    String? tagsJson,
    Value<int?> score = const Value.absent(),
    Value<String?> posterUrl = const Value.absent(),
    Value<String?> backdropUrl = const Value.absent(),
    Value<String?> synopsis = const Value.absent(),
    Value<String?> franchiseId = const Value.absent(),
    bool? adult,
    bool? detailed,
    DateTime? updatedAt,
  }) => CatalogTitle(
    id: id ?? this.id,
    mediaKind: mediaKind ?? this.mediaKind,
    titleEn: titleEn.present ? titleEn.value : this.titleEn,
    titleRomaji: titleRomaji.present ? titleRomaji.value : this.titleRomaji,
    titleNative: titleNative.present ? titleNative.value : this.titleNative,
    year: year.present ? year.value : this.year,
    country: country.present ? country.value : this.country,
    format: format.present ? format.value : this.format,
    status: status ?? this.status,
    episodes: episodes.present ? episodes.value : this.episodes,
    chapters: chapters.present ? chapters.value : this.chapters,
    seasonsJson: seasonsJson ?? this.seasonsJson,
    genresJson: genresJson ?? this.genresJson,
    tagsJson: tagsJson ?? this.tagsJson,
    score: score.present ? score.value : this.score,
    posterUrl: posterUrl.present ? posterUrl.value : this.posterUrl,
    backdropUrl: backdropUrl.present ? backdropUrl.value : this.backdropUrl,
    synopsis: synopsis.present ? synopsis.value : this.synopsis,
    franchiseId: franchiseId.present ? franchiseId.value : this.franchiseId,
    adult: adult ?? this.adult,
    detailed: detailed ?? this.detailed,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CatalogTitle copyWithCompanion(CatalogTitlesCompanion data) {
    return CatalogTitle(
      id: data.id.present ? data.id.value : this.id,
      mediaKind: data.mediaKind.present ? data.mediaKind.value : this.mediaKind,
      titleEn: data.titleEn.present ? data.titleEn.value : this.titleEn,
      titleRomaji: data.titleRomaji.present
          ? data.titleRomaji.value
          : this.titleRomaji,
      titleNative: data.titleNative.present
          ? data.titleNative.value
          : this.titleNative,
      year: data.year.present ? data.year.value : this.year,
      country: data.country.present ? data.country.value : this.country,
      format: data.format.present ? data.format.value : this.format,
      status: data.status.present ? data.status.value : this.status,
      episodes: data.episodes.present ? data.episodes.value : this.episodes,
      chapters: data.chapters.present ? data.chapters.value : this.chapters,
      seasonsJson: data.seasonsJson.present
          ? data.seasonsJson.value
          : this.seasonsJson,
      genresJson: data.genresJson.present
          ? data.genresJson.value
          : this.genresJson,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      score: data.score.present ? data.score.value : this.score,
      posterUrl: data.posterUrl.present ? data.posterUrl.value : this.posterUrl,
      backdropUrl: data.backdropUrl.present
          ? data.backdropUrl.value
          : this.backdropUrl,
      synopsis: data.synopsis.present ? data.synopsis.value : this.synopsis,
      franchiseId: data.franchiseId.present
          ? data.franchiseId.value
          : this.franchiseId,
      adult: data.adult.present ? data.adult.value : this.adult,
      detailed: data.detailed.present ? data.detailed.value : this.detailed,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogTitle(')
          ..write('id: $id, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('titleEn: $titleEn, ')
          ..write('titleRomaji: $titleRomaji, ')
          ..write('titleNative: $titleNative, ')
          ..write('year: $year, ')
          ..write('country: $country, ')
          ..write('format: $format, ')
          ..write('status: $status, ')
          ..write('episodes: $episodes, ')
          ..write('chapters: $chapters, ')
          ..write('seasonsJson: $seasonsJson, ')
          ..write('genresJson: $genresJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('score: $score, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('synopsis: $synopsis, ')
          ..write('franchiseId: $franchiseId, ')
          ..write('adult: $adult, ')
          ..write('detailed: $detailed, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    mediaKind,
    titleEn,
    titleRomaji,
    titleNative,
    year,
    country,
    format,
    status,
    episodes,
    chapters,
    seasonsJson,
    genresJson,
    tagsJson,
    score,
    posterUrl,
    backdropUrl,
    synopsis,
    franchiseId,
    adult,
    detailed,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogTitle &&
          other.id == this.id &&
          other.mediaKind == this.mediaKind &&
          other.titleEn == this.titleEn &&
          other.titleRomaji == this.titleRomaji &&
          other.titleNative == this.titleNative &&
          other.year == this.year &&
          other.country == this.country &&
          other.format == this.format &&
          other.status == this.status &&
          other.episodes == this.episodes &&
          other.chapters == this.chapters &&
          other.seasonsJson == this.seasonsJson &&
          other.genresJson == this.genresJson &&
          other.tagsJson == this.tagsJson &&
          other.score == this.score &&
          other.posterUrl == this.posterUrl &&
          other.backdropUrl == this.backdropUrl &&
          other.synopsis == this.synopsis &&
          other.franchiseId == this.franchiseId &&
          other.adult == this.adult &&
          other.detailed == this.detailed &&
          other.updatedAt == this.updatedAt);
}

class CatalogTitlesCompanion extends UpdateCompanion<CatalogTitle> {
  final Value<String> id;
  final Value<String> mediaKind;
  final Value<String?> titleEn;
  final Value<String?> titleRomaji;
  final Value<String?> titleNative;
  final Value<int?> year;
  final Value<String?> country;
  final Value<String?> format;
  final Value<String> status;
  final Value<int?> episodes;
  final Value<int?> chapters;
  final Value<String> seasonsJson;
  final Value<String> genresJson;
  final Value<String> tagsJson;
  final Value<int?> score;
  final Value<String?> posterUrl;
  final Value<String?> backdropUrl;
  final Value<String?> synopsis;
  final Value<String?> franchiseId;
  final Value<bool> adult;
  final Value<bool> detailed;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CatalogTitlesCompanion({
    this.id = const Value.absent(),
    this.mediaKind = const Value.absent(),
    this.titleEn = const Value.absent(),
    this.titleRomaji = const Value.absent(),
    this.titleNative = const Value.absent(),
    this.year = const Value.absent(),
    this.country = const Value.absent(),
    this.format = const Value.absent(),
    this.status = const Value.absent(),
    this.episodes = const Value.absent(),
    this.chapters = const Value.absent(),
    this.seasonsJson = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.score = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.synopsis = const Value.absent(),
    this.franchiseId = const Value.absent(),
    this.adult = const Value.absent(),
    this.detailed = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogTitlesCompanion.insert({
    required String id,
    required String mediaKind,
    this.titleEn = const Value.absent(),
    this.titleRomaji = const Value.absent(),
    this.titleNative = const Value.absent(),
    this.year = const Value.absent(),
    this.country = const Value.absent(),
    this.format = const Value.absent(),
    this.status = const Value.absent(),
    this.episodes = const Value.absent(),
    this.chapters = const Value.absent(),
    this.seasonsJson = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.score = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.synopsis = const Value.absent(),
    this.franchiseId = const Value.absent(),
    this.adult = const Value.absent(),
    this.detailed = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mediaKind = Value(mediaKind),
       updatedAt = Value(updatedAt);
  static Insertable<CatalogTitle> custom({
    Expression<String>? id,
    Expression<String>? mediaKind,
    Expression<String>? titleEn,
    Expression<String>? titleRomaji,
    Expression<String>? titleNative,
    Expression<int>? year,
    Expression<String>? country,
    Expression<String>? format,
    Expression<String>? status,
    Expression<int>? episodes,
    Expression<int>? chapters,
    Expression<String>? seasonsJson,
    Expression<String>? genresJson,
    Expression<String>? tagsJson,
    Expression<int>? score,
    Expression<String>? posterUrl,
    Expression<String>? backdropUrl,
    Expression<String>? synopsis,
    Expression<String>? franchiseId,
    Expression<bool>? adult,
    Expression<bool>? detailed,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mediaKind != null) 'media_kind': mediaKind,
      if (titleEn != null) 'title_en': titleEn,
      if (titleRomaji != null) 'title_romaji': titleRomaji,
      if (titleNative != null) 'title_native': titleNative,
      if (year != null) 'year': year,
      if (country != null) 'country': country,
      if (format != null) 'format': format,
      if (status != null) 'status': status,
      if (episodes != null) 'episodes': episodes,
      if (chapters != null) 'chapters': chapters,
      if (seasonsJson != null) 'seasons_json': seasonsJson,
      if (genresJson != null) 'genres_json': genresJson,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (score != null) 'score': score,
      if (posterUrl != null) 'poster_url': posterUrl,
      if (backdropUrl != null) 'backdrop_url': backdropUrl,
      if (synopsis != null) 'synopsis': synopsis,
      if (franchiseId != null) 'franchise_id': franchiseId,
      if (adult != null) 'adult': adult,
      if (detailed != null) 'detailed': detailed,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogTitlesCompanion copyWith({
    Value<String>? id,
    Value<String>? mediaKind,
    Value<String?>? titleEn,
    Value<String?>? titleRomaji,
    Value<String?>? titleNative,
    Value<int?>? year,
    Value<String?>? country,
    Value<String?>? format,
    Value<String>? status,
    Value<int?>? episodes,
    Value<int?>? chapters,
    Value<String>? seasonsJson,
    Value<String>? genresJson,
    Value<String>? tagsJson,
    Value<int?>? score,
    Value<String?>? posterUrl,
    Value<String?>? backdropUrl,
    Value<String?>? synopsis,
    Value<String?>? franchiseId,
    Value<bool>? adult,
    Value<bool>? detailed,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CatalogTitlesCompanion(
      id: id ?? this.id,
      mediaKind: mediaKind ?? this.mediaKind,
      titleEn: titleEn ?? this.titleEn,
      titleRomaji: titleRomaji ?? this.titleRomaji,
      titleNative: titleNative ?? this.titleNative,
      year: year ?? this.year,
      country: country ?? this.country,
      format: format ?? this.format,
      status: status ?? this.status,
      episodes: episodes ?? this.episodes,
      chapters: chapters ?? this.chapters,
      seasonsJson: seasonsJson ?? this.seasonsJson,
      genresJson: genresJson ?? this.genresJson,
      tagsJson: tagsJson ?? this.tagsJson,
      score: score ?? this.score,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      synopsis: synopsis ?? this.synopsis,
      franchiseId: franchiseId ?? this.franchiseId,
      adult: adult ?? this.adult,
      detailed: detailed ?? this.detailed,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mediaKind.present) {
      map['media_kind'] = Variable<String>(mediaKind.value);
    }
    if (titleEn.present) {
      map['title_en'] = Variable<String>(titleEn.value);
    }
    if (titleRomaji.present) {
      map['title_romaji'] = Variable<String>(titleRomaji.value);
    }
    if (titleNative.present) {
      map['title_native'] = Variable<String>(titleNative.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (episodes.present) {
      map['episodes'] = Variable<int>(episodes.value);
    }
    if (chapters.present) {
      map['chapters'] = Variable<int>(chapters.value);
    }
    if (seasonsJson.present) {
      map['seasons_json'] = Variable<String>(seasonsJson.value);
    }
    if (genresJson.present) {
      map['genres_json'] = Variable<String>(genresJson.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (posterUrl.present) {
      map['poster_url'] = Variable<String>(posterUrl.value);
    }
    if (backdropUrl.present) {
      map['backdrop_url'] = Variable<String>(backdropUrl.value);
    }
    if (synopsis.present) {
      map['synopsis'] = Variable<String>(synopsis.value);
    }
    if (franchiseId.present) {
      map['franchise_id'] = Variable<String>(franchiseId.value);
    }
    if (adult.present) {
      map['adult'] = Variable<bool>(adult.value);
    }
    if (detailed.present) {
      map['detailed'] = Variable<bool>(detailed.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogTitlesCompanion(')
          ..write('id: $id, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('titleEn: $titleEn, ')
          ..write('titleRomaji: $titleRomaji, ')
          ..write('titleNative: $titleNative, ')
          ..write('year: $year, ')
          ..write('country: $country, ')
          ..write('format: $format, ')
          ..write('status: $status, ')
          ..write('episodes: $episodes, ')
          ..write('chapters: $chapters, ')
          ..write('seasonsJson: $seasonsJson, ')
          ..write('genresJson: $genresJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('score: $score, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('synopsis: $synopsis, ')
          ..write('franchiseId: $franchiseId, ')
          ..write('adult: $adult, ')
          ..write('detailed: $detailed, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogIdentitiesTable extends CatalogIdentities
    with TableInfo<$CatalogIdentitiesTable, CatalogIdentity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogIdentitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_titles (id)',
    ),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerKindMeta = const VerificationMeta(
    'providerKind',
  );
  @override
  late final GeneratedColumn<String> providerKind = GeneratedColumn<String>(
    'provider_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    titleId,
    provider,
    providerId,
    providerKind,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_identities';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogIdentity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('provider_kind')) {
      context.handle(
        _providerKindMeta,
        providerKind.isAcceptableOrUnknown(
          data['provider_kind']!,
          _providerKindMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {provider, providerId, providerKind};
  @override
  CatalogIdentity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogIdentity(
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      providerKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_kind'],
      )!,
    );
  }

  @override
  $CatalogIdentitiesTable createAlias(String alias) {
    return $CatalogIdentitiesTable(attachedDatabase, alias);
  }
}

class CatalogIdentity extends DataClass implements Insertable<CatalogIdentity> {
  final String titleId;
  final String provider;
  final String providerId;
  final String providerKind;
  const CatalogIdentity({
    required this.titleId,
    required this.provider,
    required this.providerId,
    required this.providerKind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title_id'] = Variable<String>(titleId);
    map['provider'] = Variable<String>(provider);
    map['provider_id'] = Variable<String>(providerId);
    map['provider_kind'] = Variable<String>(providerKind);
    return map;
  }

  CatalogIdentitiesCompanion toCompanion(bool nullToAbsent) {
    return CatalogIdentitiesCompanion(
      titleId: Value(titleId),
      provider: Value(provider),
      providerId: Value(providerId),
      providerKind: Value(providerKind),
    );
  }

  factory CatalogIdentity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogIdentity(
      titleId: serializer.fromJson<String>(json['titleId']),
      provider: serializer.fromJson<String>(json['provider']),
      providerId: serializer.fromJson<String>(json['providerId']),
      providerKind: serializer.fromJson<String>(json['providerKind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'titleId': serializer.toJson<String>(titleId),
      'provider': serializer.toJson<String>(provider),
      'providerId': serializer.toJson<String>(providerId),
      'providerKind': serializer.toJson<String>(providerKind),
    };
  }

  CatalogIdentity copyWith({
    String? titleId,
    String? provider,
    String? providerId,
    String? providerKind,
  }) => CatalogIdentity(
    titleId: titleId ?? this.titleId,
    provider: provider ?? this.provider,
    providerId: providerId ?? this.providerId,
    providerKind: providerKind ?? this.providerKind,
  );
  CatalogIdentity copyWithCompanion(CatalogIdentitiesCompanion data) {
    return CatalogIdentity(
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      provider: data.provider.present ? data.provider.value : this.provider,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      providerKind: data.providerKind.present
          ? data.providerKind.value
          : this.providerKind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogIdentity(')
          ..write('titleId: $titleId, ')
          ..write('provider: $provider, ')
          ..write('providerId: $providerId, ')
          ..write('providerKind: $providerKind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(titleId, provider, providerId, providerKind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogIdentity &&
          other.titleId == this.titleId &&
          other.provider == this.provider &&
          other.providerId == this.providerId &&
          other.providerKind == this.providerKind);
}

class CatalogIdentitiesCompanion extends UpdateCompanion<CatalogIdentity> {
  final Value<String> titleId;
  final Value<String> provider;
  final Value<String> providerId;
  final Value<String> providerKind;
  final Value<int> rowid;
  const CatalogIdentitiesCompanion({
    this.titleId = const Value.absent(),
    this.provider = const Value.absent(),
    this.providerId = const Value.absent(),
    this.providerKind = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogIdentitiesCompanion.insert({
    required String titleId,
    required String provider,
    required String providerId,
    this.providerKind = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : titleId = Value(titleId),
       provider = Value(provider),
       providerId = Value(providerId);
  static Insertable<CatalogIdentity> custom({
    Expression<String>? titleId,
    Expression<String>? provider,
    Expression<String>? providerId,
    Expression<String>? providerKind,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (titleId != null) 'title_id': titleId,
      if (provider != null) 'provider': provider,
      if (providerId != null) 'provider_id': providerId,
      if (providerKind != null) 'provider_kind': providerKind,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogIdentitiesCompanion copyWith({
    Value<String>? titleId,
    Value<String>? provider,
    Value<String>? providerId,
    Value<String>? providerKind,
    Value<int>? rowid,
  }) {
    return CatalogIdentitiesCompanion(
      titleId: titleId ?? this.titleId,
      provider: provider ?? this.provider,
      providerId: providerId ?? this.providerId,
      providerKind: providerKind ?? this.providerKind,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (providerKind.present) {
      map['provider_kind'] = Variable<String>(providerKind.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogIdentitiesCompanion(')
          ..write('titleId: $titleId, ')
          ..write('provider: $provider, ')
          ..write('providerId: $providerId, ')
          ..write('providerKind: $providerKind, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogPagesTable extends CatalogPages
    with TableInfo<$CatalogPagesTable, CatalogPage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogPagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaKindMeta = const VerificationMeta(
    'mediaKind',
  );
  @override
  late final GeneratedColumn<String> mediaKind = GeneratedColumn<String>(
    'media_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<String> mood = GeneratedColumn<String>(
    'mood',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pageMeta = const VerificationMeta('page');
  @override
  late final GeneratedColumn<int> page = GeneratedColumn<int>(
    'page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hasNextMeta = const VerificationMeta(
    'hasNext',
  );
  @override
  late final GeneratedColumn<bool> hasNext = GeneratedColumn<bool>(
    'has_next',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_next" IN (0, 1))',
    ),
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mediaKind,
    mood,
    page,
    hasNext,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogPage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_kind')) {
      context.handle(
        _mediaKindMeta,
        mediaKind.isAcceptableOrUnknown(data['media_kind']!, _mediaKindMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaKindMeta);
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    }
    if (data.containsKey('page')) {
      context.handle(
        _pageMeta,
        page.isAcceptableOrUnknown(data['page']!, _pageMeta),
      );
    } else if (isInserting) {
      context.missing(_pageMeta);
    }
    if (data.containsKey('has_next')) {
      context.handle(
        _hasNextMeta,
        hasNext.isAcceptableOrUnknown(data['has_next']!, _hasNextMeta),
      );
    } else if (isInserting) {
      context.missing(_hasNextMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaKind, mood, page};
  @override
  CatalogPage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogPage(
      mediaKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_kind'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mood'],
      )!,
      page: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page'],
      )!,
      hasNext: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_next'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $CatalogPagesTable createAlias(String alias) {
    return $CatalogPagesTable(attachedDatabase, alias);
  }
}

class CatalogPage extends DataClass implements Insertable<CatalogPage> {
  final String mediaKind;
  final String mood;
  final int page;
  final bool hasNext;
  final DateTime fetchedAt;
  const CatalogPage({
    required this.mediaKind,
    required this.mood,
    required this.page,
    required this.hasNext,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_kind'] = Variable<String>(mediaKind);
    map['mood'] = Variable<String>(mood);
    map['page'] = Variable<int>(page);
    map['has_next'] = Variable<bool>(hasNext);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CatalogPagesCompanion toCompanion(bool nullToAbsent) {
    return CatalogPagesCompanion(
      mediaKind: Value(mediaKind),
      mood: Value(mood),
      page: Value(page),
      hasNext: Value(hasNext),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CatalogPage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogPage(
      mediaKind: serializer.fromJson<String>(json['mediaKind']),
      mood: serializer.fromJson<String>(json['mood']),
      page: serializer.fromJson<int>(json['page']),
      hasNext: serializer.fromJson<bool>(json['hasNext']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaKind': serializer.toJson<String>(mediaKind),
      'mood': serializer.toJson<String>(mood),
      'page': serializer.toJson<int>(page),
      'hasNext': serializer.toJson<bool>(hasNext),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CatalogPage copyWith({
    String? mediaKind,
    String? mood,
    int? page,
    bool? hasNext,
    DateTime? fetchedAt,
  }) => CatalogPage(
    mediaKind: mediaKind ?? this.mediaKind,
    mood: mood ?? this.mood,
    page: page ?? this.page,
    hasNext: hasNext ?? this.hasNext,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  CatalogPage copyWithCompanion(CatalogPagesCompanion data) {
    return CatalogPage(
      mediaKind: data.mediaKind.present ? data.mediaKind.value : this.mediaKind,
      mood: data.mood.present ? data.mood.value : this.mood,
      page: data.page.present ? data.page.value : this.page,
      hasNext: data.hasNext.present ? data.hasNext.value : this.hasNext,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogPage(')
          ..write('mediaKind: $mediaKind, ')
          ..write('mood: $mood, ')
          ..write('page: $page, ')
          ..write('hasNext: $hasNext, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mediaKind, mood, page, hasNext, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogPage &&
          other.mediaKind == this.mediaKind &&
          other.mood == this.mood &&
          other.page == this.page &&
          other.hasNext == this.hasNext &&
          other.fetchedAt == this.fetchedAt);
}

class CatalogPagesCompanion extends UpdateCompanion<CatalogPage> {
  final Value<String> mediaKind;
  final Value<String> mood;
  final Value<int> page;
  final Value<bool> hasNext;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CatalogPagesCompanion({
    this.mediaKind = const Value.absent(),
    this.mood = const Value.absent(),
    this.page = const Value.absent(),
    this.hasNext = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogPagesCompanion.insert({
    required String mediaKind,
    this.mood = const Value.absent(),
    required int page,
    required bool hasNext,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : mediaKind = Value(mediaKind),
       page = Value(page),
       hasNext = Value(hasNext),
       fetchedAt = Value(fetchedAt);
  static Insertable<CatalogPage> custom({
    Expression<String>? mediaKind,
    Expression<String>? mood,
    Expression<int>? page,
    Expression<bool>? hasNext,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaKind != null) 'media_kind': mediaKind,
      if (mood != null) 'mood': mood,
      if (page != null) 'page': page,
      if (hasNext != null) 'has_next': hasNext,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogPagesCompanion copyWith({
    Value<String>? mediaKind,
    Value<String>? mood,
    Value<int>? page,
    Value<bool>? hasNext,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return CatalogPagesCompanion(
      mediaKind: mediaKind ?? this.mediaKind,
      mood: mood ?? this.mood,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaKind.present) {
      map['media_kind'] = Variable<String>(mediaKind.value);
    }
    if (mood.present) {
      map['mood'] = Variable<String>(mood.value);
    }
    if (page.present) {
      map['page'] = Variable<int>(page.value);
    }
    if (hasNext.present) {
      map['has_next'] = Variable<bool>(hasNext.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogPagesCompanion(')
          ..write('mediaKind: $mediaKind, ')
          ..write('mood: $mood, ')
          ..write('page: $page, ')
          ..write('hasNext: $hasNext, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchProvidersTable extends WatchProviders
    with TableInfo<$WatchProvidersTable, WatchProvider> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchProvidersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_titles (id)',
    ),
  );
  static const VerificationMeta _regionMeta = const VerificationMeta('region');
  @override
  late final GeneratedColumn<String> region = GeneratedColumn<String>(
    'region',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providersJsonMeta = const VerificationMeta(
    'providersJson',
  );
  @override
  late final GeneratedColumn<String> providersJson = GeneratedColumn<String>(
    'providers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    titleId,
    region,
    providersJson,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_providers';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchProvider> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('region')) {
      context.handle(
        _regionMeta,
        region.isAcceptableOrUnknown(data['region']!, _regionMeta),
      );
    } else if (isInserting) {
      context.missing(_regionMeta);
    }
    if (data.containsKey('providers_json')) {
      context.handle(
        _providersJsonMeta,
        providersJson.isAcceptableOrUnknown(
          data['providers_json']!,
          _providersJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providersJsonMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {titleId, region};
  @override
  WatchProvider map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchProvider(
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      region: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region'],
      )!,
      providersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}providers_json'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $WatchProvidersTable createAlias(String alias) {
    return $WatchProvidersTable(attachedDatabase, alias);
  }
}

class WatchProvider extends DataClass implements Insertable<WatchProvider> {
  final String titleId;
  final String region;
  final String providersJson;
  final DateTime fetchedAt;
  const WatchProvider({
    required this.titleId,
    required this.region,
    required this.providersJson,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title_id'] = Variable<String>(titleId);
    map['region'] = Variable<String>(region);
    map['providers_json'] = Variable<String>(providersJson);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  WatchProvidersCompanion toCompanion(bool nullToAbsent) {
    return WatchProvidersCompanion(
      titleId: Value(titleId),
      region: Value(region),
      providersJson: Value(providersJson),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory WatchProvider.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchProvider(
      titleId: serializer.fromJson<String>(json['titleId']),
      region: serializer.fromJson<String>(json['region']),
      providersJson: serializer.fromJson<String>(json['providersJson']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'titleId': serializer.toJson<String>(titleId),
      'region': serializer.toJson<String>(region),
      'providersJson': serializer.toJson<String>(providersJson),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  WatchProvider copyWith({
    String? titleId,
    String? region,
    String? providersJson,
    DateTime? fetchedAt,
  }) => WatchProvider(
    titleId: titleId ?? this.titleId,
    region: region ?? this.region,
    providersJson: providersJson ?? this.providersJson,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  WatchProvider copyWithCompanion(WatchProvidersCompanion data) {
    return WatchProvider(
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      region: data.region.present ? data.region.value : this.region,
      providersJson: data.providersJson.present
          ? data.providersJson.value
          : this.providersJson,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchProvider(')
          ..write('titleId: $titleId, ')
          ..write('region: $region, ')
          ..write('providersJson: $providersJson, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(titleId, region, providersJson, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchProvider &&
          other.titleId == this.titleId &&
          other.region == this.region &&
          other.providersJson == this.providersJson &&
          other.fetchedAt == this.fetchedAt);
}

class WatchProvidersCompanion extends UpdateCompanion<WatchProvider> {
  final Value<String> titleId;
  final Value<String> region;
  final Value<String> providersJson;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const WatchProvidersCompanion({
    this.titleId = const Value.absent(),
    this.region = const Value.absent(),
    this.providersJson = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchProvidersCompanion.insert({
    required String titleId,
    required String region,
    required String providersJson,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : titleId = Value(titleId),
       region = Value(region),
       providersJson = Value(providersJson),
       fetchedAt = Value(fetchedAt);
  static Insertable<WatchProvider> custom({
    Expression<String>? titleId,
    Expression<String>? region,
    Expression<String>? providersJson,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (titleId != null) 'title_id': titleId,
      if (region != null) 'region': region,
      if (providersJson != null) 'providers_json': providersJson,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchProvidersCompanion copyWith({
    Value<String>? titleId,
    Value<String>? region,
    Value<String>? providersJson,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return WatchProvidersCompanion(
      titleId: titleId ?? this.titleId,
      region: region ?? this.region,
      providersJson: providersJson ?? this.providersJson,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (region.present) {
      map['region'] = Variable<String>(region.value);
    }
    if (providersJson.present) {
      map['providers_json'] = Variable<String>(providersJson.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchProvidersCompanion(')
          ..write('titleId: $titleId, ')
          ..write('region: $region, ')
          ..write('providersJson: $providersJson, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regionMeta = const VerificationMeta('region');
  @override
  late final GeneratedColumn<String> region = GeneratedColumn<String>(
    'region',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('IN'),
  );
  static const VerificationMeta _showAdultMeta = const VerificationMeta(
    'showAdult',
  );
  @override
  late final GeneratedColumn<bool> showAdult = GeneratedColumn<bool>(
    'show_adult',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_adult" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    region,
    showAdult,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Profile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('region')) {
      context.handle(
        _regionMeta,
        region.isAcceptableOrUnknown(data['region']!, _regionMeta),
      );
    }
    if (data.containsKey('show_adult')) {
      context.handle(
        _showAdultMeta,
        showAdult.isAcceptableOrUnknown(data['show_adult']!, _showAdultMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      region: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region'],
      )!,
      showAdult: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_adult'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class Profile extends DataClass implements Insertable<Profile> {
  final String id;
  final String? displayName;
  final String region;
  final bool showAdult;
  final DateTime createdAt;
  const Profile({
    required this.id,
    this.displayName,
    required this.region,
    required this.showAdult,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['region'] = Variable<String>(region);
    map['show_adult'] = Variable<bool>(showAdult);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      region: Value(region),
      showAdult: Value(showAdult),
      createdAt: Value(createdAt),
    );
  }

  factory Profile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      region: serializer.fromJson<String>(json['region']),
      showAdult: serializer.fromJson<bool>(json['showAdult']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String?>(displayName),
      'region': serializer.toJson<String>(region),
      'showAdult': serializer.toJson<bool>(showAdult),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Profile copyWith({
    String? id,
    Value<String?> displayName = const Value.absent(),
    String? region,
    bool? showAdult,
    DateTime? createdAt,
  }) => Profile(
    id: id ?? this.id,
    displayName: displayName.present ? displayName.value : this.displayName,
    region: region ?? this.region,
    showAdult: showAdult ?? this.showAdult,
    createdAt: createdAt ?? this.createdAt,
  );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      region: data.region.present ? data.region.value : this.region,
      showAdult: data.showAdult.present ? data.showAdult.value : this.showAdult,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('region: $region, ')
          ..write('showAdult: $showAdult, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, displayName, region, showAdult, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.region == this.region &&
          other.showAdult == this.showAdult &&
          other.createdAt == this.createdAt);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<String> id;
  final Value<String?> displayName;
  final Value<String> region;
  final Value<bool> showAdult;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.region = const Value.absent(),
    this.showAdult = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    this.displayName = const Value.absent(),
    this.region = const Value.absent(),
    this.showAdult = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt);
  static Insertable<Profile> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? region,
    Expression<bool>? showAdult,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (region != null) 'region': region,
      if (showAdult != null) 'show_adult': showAdult,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<String?>? displayName,
    Value<String>? region,
    Value<bool>? showAdult,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      region: region ?? this.region,
      showAdult: showAdult ?? this.showAdult,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (region.present) {
      map['region'] = Variable<String>(region.value);
    }
    if (showAdult.present) {
      map['show_adult'] = Variable<bool>(showAdult.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('region: $region, ')
          ..write('showAdult: $showAdult, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfileSettingsTable extends ProfileSettings
    with TableInfo<$ProfileSettingsTable, ProfileSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfileSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [profileId, key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profile_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, key};
  @override
  ProfileSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileSetting(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $ProfileSettingsTable createAlias(String alias) {
    return $ProfileSettingsTable(attachedDatabase, alias);
  }
}

class ProfileSetting extends DataClass implements Insertable<ProfileSetting> {
  final String profileId;
  final String key;
  final String value;
  const ProfileSetting({
    required this.profileId,
    required this.key,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  ProfileSettingsCompanion toCompanion(bool nullToAbsent) {
    return ProfileSettingsCompanion(
      profileId: Value(profileId),
      key: Value(key),
      value: Value(value),
    );
  }

  factory ProfileSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileSetting(
      profileId: serializer.fromJson<String>(json['profileId']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  ProfileSetting copyWith({String? profileId, String? key, String? value}) =>
      ProfileSetting(
        profileId: profileId ?? this.profileId,
        key: key ?? this.key,
        value: value ?? this.value,
      );
  ProfileSetting copyWithCompanion(ProfileSettingsCompanion data) {
    return ProfileSetting(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileSetting(')
          ..write('profileId: $profileId, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileSetting &&
          other.profileId == this.profileId &&
          other.key == this.key &&
          other.value == this.value);
}

class ProfileSettingsCompanion extends UpdateCompanion<ProfileSetting> {
  final Value<String> profileId;
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const ProfileSettingsCompanion({
    this.profileId = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfileSettingsCompanion.insert({
    required String profileId,
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       key = Value(key),
       value = Value(value);
  static Insertable<ProfileSetting> custom({
    Expression<String>? profileId,
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfileSettingsCompanion copyWith({
    Value<String>? profileId,
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return ProfileSettingsCompanion(
      profileId: profileId ?? this.profileId,
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfileSettingsCompanion(')
          ..write('profileId: $profileId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserTitlesTable extends UserTitles
    with TableInfo<$UserTitlesTable, UserTitle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserTitlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<String> rating = GeneratedColumn<String>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rewatchMoodMeta = const VerificationMeta(
    'rewatchMood',
  );
  @override
  late final GeneratedColumn<String> rewatchMood = GeneratedColumn<String>(
    'rewatch_mood',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _progressUnitMeta = const VerificationMeta(
    'progressUnit',
  );
  @override
  late final GeneratedColumn<String> progressUnit = GeneratedColumn<String>(
    'progress_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _progressValueMeta = const VerificationMeta(
    'progressValue',
  );
  @override
  late final GeneratedColumn<double> progressValue = GeneratedColumn<double>(
    'progress_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latestKnownMeta = const VerificationMeta(
    'latestKnown',
  );
  @override
  late final GeneratedColumn<double> latestKnown = GeneratedColumn<double>(
    'latest_known',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualWatchedAtMeta = const VerificationMeta(
    'actualWatchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> actualWatchedAt =
      GeneratedColumn<DateTime>(
        'actual_watched_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('user'),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    titleId,
    state,
    rating,
    rewatchMood,
    progressUnit,
    progressValue,
    latestKnown,
    actualWatchedAt,
    updatedAt,
    source,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_titles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserTitle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('rewatch_mood')) {
      context.handle(
        _rewatchMoodMeta,
        rewatchMood.isAcceptableOrUnknown(
          data['rewatch_mood']!,
          _rewatchMoodMeta,
        ),
      );
    }
    if (data.containsKey('progress_unit')) {
      context.handle(
        _progressUnitMeta,
        progressUnit.isAcceptableOrUnknown(
          data['progress_unit']!,
          _progressUnitMeta,
        ),
      );
    }
    if (data.containsKey('progress_value')) {
      context.handle(
        _progressValueMeta,
        progressValue.isAcceptableOrUnknown(
          data['progress_value']!,
          _progressValueMeta,
        ),
      );
    }
    if (data.containsKey('latest_known')) {
      context.handle(
        _latestKnownMeta,
        latestKnown.isAcceptableOrUnknown(
          data['latest_known']!,
          _latestKnownMeta,
        ),
      );
    }
    if (data.containsKey('actual_watched_at')) {
      context.handle(
        _actualWatchedAtMeta,
        actualWatchedAt.isAcceptableOrUnknown(
          data['actual_watched_at']!,
          _actualWatchedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, titleId};
  @override
  UserTitle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserTitle(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rating'],
      ),
      rewatchMood: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rewatch_mood'],
      ),
      progressUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}progress_unit'],
      ),
      progressValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress_value'],
      ),
      latestKnown: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latest_known'],
      ),
      actualWatchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}actual_watched_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $UserTitlesTable createAlias(String alias) {
    return $UserTitlesTable(attachedDatabase, alias);
  }
}

class UserTitle extends DataClass implements Insertable<UserTitle> {
  final String profileId;
  final String titleId;
  final String state;
  final String? rating;
  final String? rewatchMood;
  final String? progressUnit;
  final double? progressValue;
  final double? latestKnown;
  final DateTime? actualWatchedAt;
  final DateTime updatedAt;

  /// "user" or "import:`batchId`".
  final String source;

  /// Free text from a Cue backup; never shown to the ranker.
  final String? note;
  const UserTitle({
    required this.profileId,
    required this.titleId,
    required this.state,
    this.rating,
    this.rewatchMood,
    this.progressUnit,
    this.progressValue,
    this.latestKnown,
    this.actualWatchedAt,
    required this.updatedAt,
    required this.source,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['title_id'] = Variable<String>(titleId);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<String>(rating);
    }
    if (!nullToAbsent || rewatchMood != null) {
      map['rewatch_mood'] = Variable<String>(rewatchMood);
    }
    if (!nullToAbsent || progressUnit != null) {
      map['progress_unit'] = Variable<String>(progressUnit);
    }
    if (!nullToAbsent || progressValue != null) {
      map['progress_value'] = Variable<double>(progressValue);
    }
    if (!nullToAbsent || latestKnown != null) {
      map['latest_known'] = Variable<double>(latestKnown);
    }
    if (!nullToAbsent || actualWatchedAt != null) {
      map['actual_watched_at'] = Variable<DateTime>(actualWatchedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  UserTitlesCompanion toCompanion(bool nullToAbsent) {
    return UserTitlesCompanion(
      profileId: Value(profileId),
      titleId: Value(titleId),
      state: Value(state),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      rewatchMood: rewatchMood == null && nullToAbsent
          ? const Value.absent()
          : Value(rewatchMood),
      progressUnit: progressUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(progressUnit),
      progressValue: progressValue == null && nullToAbsent
          ? const Value.absent()
          : Value(progressValue),
      latestKnown: latestKnown == null && nullToAbsent
          ? const Value.absent()
          : Value(latestKnown),
      actualWatchedAt: actualWatchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(actualWatchedAt),
      updatedAt: Value(updatedAt),
      source: Value(source),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory UserTitle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserTitle(
      profileId: serializer.fromJson<String>(json['profileId']),
      titleId: serializer.fromJson<String>(json['titleId']),
      state: serializer.fromJson<String>(json['state']),
      rating: serializer.fromJson<String?>(json['rating']),
      rewatchMood: serializer.fromJson<String?>(json['rewatchMood']),
      progressUnit: serializer.fromJson<String?>(json['progressUnit']),
      progressValue: serializer.fromJson<double?>(json['progressValue']),
      latestKnown: serializer.fromJson<double?>(json['latestKnown']),
      actualWatchedAt: serializer.fromJson<DateTime?>(json['actualWatchedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      source: serializer.fromJson<String>(json['source']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'titleId': serializer.toJson<String>(titleId),
      'state': serializer.toJson<String>(state),
      'rating': serializer.toJson<String?>(rating),
      'rewatchMood': serializer.toJson<String?>(rewatchMood),
      'progressUnit': serializer.toJson<String?>(progressUnit),
      'progressValue': serializer.toJson<double?>(progressValue),
      'latestKnown': serializer.toJson<double?>(latestKnown),
      'actualWatchedAt': serializer.toJson<DateTime?>(actualWatchedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'source': serializer.toJson<String>(source),
      'note': serializer.toJson<String?>(note),
    };
  }

  UserTitle copyWith({
    String? profileId,
    String? titleId,
    String? state,
    Value<String?> rating = const Value.absent(),
    Value<String?> rewatchMood = const Value.absent(),
    Value<String?> progressUnit = const Value.absent(),
    Value<double?> progressValue = const Value.absent(),
    Value<double?> latestKnown = const Value.absent(),
    Value<DateTime?> actualWatchedAt = const Value.absent(),
    DateTime? updatedAt,
    String? source,
    Value<String?> note = const Value.absent(),
  }) => UserTitle(
    profileId: profileId ?? this.profileId,
    titleId: titleId ?? this.titleId,
    state: state ?? this.state,
    rating: rating.present ? rating.value : this.rating,
    rewatchMood: rewatchMood.present ? rewatchMood.value : this.rewatchMood,
    progressUnit: progressUnit.present ? progressUnit.value : this.progressUnit,
    progressValue: progressValue.present
        ? progressValue.value
        : this.progressValue,
    latestKnown: latestKnown.present ? latestKnown.value : this.latestKnown,
    actualWatchedAt: actualWatchedAt.present
        ? actualWatchedAt.value
        : this.actualWatchedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    source: source ?? this.source,
    note: note.present ? note.value : this.note,
  );
  UserTitle copyWithCompanion(UserTitlesCompanion data) {
    return UserTitle(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      state: data.state.present ? data.state.value : this.state,
      rating: data.rating.present ? data.rating.value : this.rating,
      rewatchMood: data.rewatchMood.present
          ? data.rewatchMood.value
          : this.rewatchMood,
      progressUnit: data.progressUnit.present
          ? data.progressUnit.value
          : this.progressUnit,
      progressValue: data.progressValue.present
          ? data.progressValue.value
          : this.progressValue,
      latestKnown: data.latestKnown.present
          ? data.latestKnown.value
          : this.latestKnown,
      actualWatchedAt: data.actualWatchedAt.present
          ? data.actualWatchedAt.value
          : this.actualWatchedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      source: data.source.present ? data.source.value : this.source,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserTitle(')
          ..write('profileId: $profileId, ')
          ..write('titleId: $titleId, ')
          ..write('state: $state, ')
          ..write('rating: $rating, ')
          ..write('rewatchMood: $rewatchMood, ')
          ..write('progressUnit: $progressUnit, ')
          ..write('progressValue: $progressValue, ')
          ..write('latestKnown: $latestKnown, ')
          ..write('actualWatchedAt: $actualWatchedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('source: $source, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    titleId,
    state,
    rating,
    rewatchMood,
    progressUnit,
    progressValue,
    latestKnown,
    actualWatchedAt,
    updatedAt,
    source,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserTitle &&
          other.profileId == this.profileId &&
          other.titleId == this.titleId &&
          other.state == this.state &&
          other.rating == this.rating &&
          other.rewatchMood == this.rewatchMood &&
          other.progressUnit == this.progressUnit &&
          other.progressValue == this.progressValue &&
          other.latestKnown == this.latestKnown &&
          other.actualWatchedAt == this.actualWatchedAt &&
          other.updatedAt == this.updatedAt &&
          other.source == this.source &&
          other.note == this.note);
}

class UserTitlesCompanion extends UpdateCompanion<UserTitle> {
  final Value<String> profileId;
  final Value<String> titleId;
  final Value<String> state;
  final Value<String?> rating;
  final Value<String?> rewatchMood;
  final Value<String?> progressUnit;
  final Value<double?> progressValue;
  final Value<double?> latestKnown;
  final Value<DateTime?> actualWatchedAt;
  final Value<DateTime> updatedAt;
  final Value<String> source;
  final Value<String?> note;
  final Value<int> rowid;
  const UserTitlesCompanion({
    this.profileId = const Value.absent(),
    this.titleId = const Value.absent(),
    this.state = const Value.absent(),
    this.rating = const Value.absent(),
    this.rewatchMood = const Value.absent(),
    this.progressUnit = const Value.absent(),
    this.progressValue = const Value.absent(),
    this.latestKnown = const Value.absent(),
    this.actualWatchedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserTitlesCompanion.insert({
    required String profileId,
    required String titleId,
    this.state = const Value.absent(),
    this.rating = const Value.absent(),
    this.rewatchMood = const Value.absent(),
    this.progressUnit = const Value.absent(),
    this.progressValue = const Value.absent(),
    this.latestKnown = const Value.absent(),
    this.actualWatchedAt = const Value.absent(),
    required DateTime updatedAt,
    this.source = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       titleId = Value(titleId),
       updatedAt = Value(updatedAt);
  static Insertable<UserTitle> custom({
    Expression<String>? profileId,
    Expression<String>? titleId,
    Expression<String>? state,
    Expression<String>? rating,
    Expression<String>? rewatchMood,
    Expression<String>? progressUnit,
    Expression<double>? progressValue,
    Expression<double>? latestKnown,
    Expression<DateTime>? actualWatchedAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? source,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (titleId != null) 'title_id': titleId,
      if (state != null) 'state': state,
      if (rating != null) 'rating': rating,
      if (rewatchMood != null) 'rewatch_mood': rewatchMood,
      if (progressUnit != null) 'progress_unit': progressUnit,
      if (progressValue != null) 'progress_value': progressValue,
      if (latestKnown != null) 'latest_known': latestKnown,
      if (actualWatchedAt != null) 'actual_watched_at': actualWatchedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (source != null) 'source': source,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserTitlesCompanion copyWith({
    Value<String>? profileId,
    Value<String>? titleId,
    Value<String>? state,
    Value<String?>? rating,
    Value<String?>? rewatchMood,
    Value<String?>? progressUnit,
    Value<double?>? progressValue,
    Value<double?>? latestKnown,
    Value<DateTime?>? actualWatchedAt,
    Value<DateTime>? updatedAt,
    Value<String>? source,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return UserTitlesCompanion(
      profileId: profileId ?? this.profileId,
      titleId: titleId ?? this.titleId,
      state: state ?? this.state,
      rating: rating ?? this.rating,
      rewatchMood: rewatchMood ?? this.rewatchMood,
      progressUnit: progressUnit ?? this.progressUnit,
      progressValue: progressValue ?? this.progressValue,
      latestKnown: latestKnown ?? this.latestKnown,
      actualWatchedAt: actualWatchedAt ?? this.actualWatchedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(rating.value);
    }
    if (rewatchMood.present) {
      map['rewatch_mood'] = Variable<String>(rewatchMood.value);
    }
    if (progressUnit.present) {
      map['progress_unit'] = Variable<String>(progressUnit.value);
    }
    if (progressValue.present) {
      map['progress_value'] = Variable<double>(progressValue.value);
    }
    if (latestKnown.present) {
      map['latest_known'] = Variable<double>(latestKnown.value);
    }
    if (actualWatchedAt.present) {
      map['actual_watched_at'] = Variable<DateTime>(actualWatchedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserTitlesCompanion(')
          ..write('profileId: $profileId, ')
          ..write('titleId: $titleId, ')
          ..write('state: $state, ')
          ..write('rating: $rating, ')
          ..write('rewatchMood: $rewatchMood, ')
          ..write('progressUnit: $progressUnit, ')
          ..write('progressValue: $progressValue, ')
          ..write('latestKnown: $latestKnown, ')
          ..write('actualWatchedAt: $actualWatchedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('source: $source, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DecisionEventsTable extends DecisionEvents
    with TableInfo<$DecisionEventsTable, DecisionEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DecisionEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contextMeta = const VerificationMeta(
    'context',
  );
  @override
  late final GeneratedColumn<String> context = GeneratedColumn<String>(
    'context',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('deck'),
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<String> mood = GeneratedColumn<String>(
    'mood',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reversesEventIdMeta = const VerificationMeta(
    'reversesEventId',
  );
  @override
  late final GeneratedColumn<String> reversesEventId = GeneratedColumn<String>(
    'reverses_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _beforeJsonMeta = const VerificationMeta(
    'beforeJson',
  );
  @override
  late final GeneratedColumn<String> beforeJson = GeneratedColumn<String>(
    'before_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    titleId,
    action,
    context,
    mood,
    createdAt,
    reversesEventId,
    beforeJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'decision_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<DecisionEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('context')) {
      context.handle(
        _contextMeta,
        this.context.isAcceptableOrUnknown(data['context']!, _contextMeta),
      );
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('reverses_event_id')) {
      context.handle(
        _reversesEventIdMeta,
        reversesEventId.isAcceptableOrUnknown(
          data['reverses_event_id']!,
          _reversesEventIdMeta,
        ),
      );
    }
    if (data.containsKey('before_json')) {
      context.handle(
        _beforeJsonMeta,
        beforeJson.isAcceptableOrUnknown(data['before_json']!, _beforeJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DecisionEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DecisionEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      context: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mood'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      reversesEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reverses_event_id'],
      ),
      beforeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before_json'],
      ),
    );
  }

  @override
  $DecisionEventsTable createAlias(String alias) {
    return $DecisionEventsTable(attachedDatabase, alias);
  }
}

class DecisionEvent extends DataClass implements Insertable<DecisionEvent> {
  final String id;
  final String profileId;
  final String titleId;
  final String action;
  final String context;
  final String? mood;
  final DateTime createdAt;
  final String? reversesEventId;

  /// Rows this event replaced, so undo works after a restart.
  final String? beforeJson;
  const DecisionEvent({
    required this.id,
    required this.profileId,
    required this.titleId,
    required this.action,
    required this.context,
    this.mood,
    required this.createdAt,
    this.reversesEventId,
    this.beforeJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['title_id'] = Variable<String>(titleId);
    map['action'] = Variable<String>(action);
    map['context'] = Variable<String>(context);
    if (!nullToAbsent || mood != null) {
      map['mood'] = Variable<String>(mood);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || reversesEventId != null) {
      map['reverses_event_id'] = Variable<String>(reversesEventId);
    }
    if (!nullToAbsent || beforeJson != null) {
      map['before_json'] = Variable<String>(beforeJson);
    }
    return map;
  }

  DecisionEventsCompanion toCompanion(bool nullToAbsent) {
    return DecisionEventsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      titleId: Value(titleId),
      action: Value(action),
      context: Value(context),
      mood: mood == null && nullToAbsent ? const Value.absent() : Value(mood),
      createdAt: Value(createdAt),
      reversesEventId: reversesEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(reversesEventId),
      beforeJson: beforeJson == null && nullToAbsent
          ? const Value.absent()
          : Value(beforeJson),
    );
  }

  factory DecisionEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DecisionEvent(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      titleId: serializer.fromJson<String>(json['titleId']),
      action: serializer.fromJson<String>(json['action']),
      context: serializer.fromJson<String>(json['context']),
      mood: serializer.fromJson<String?>(json['mood']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      reversesEventId: serializer.fromJson<String?>(json['reversesEventId']),
      beforeJson: serializer.fromJson<String?>(json['beforeJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'titleId': serializer.toJson<String>(titleId),
      'action': serializer.toJson<String>(action),
      'context': serializer.toJson<String>(context),
      'mood': serializer.toJson<String?>(mood),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'reversesEventId': serializer.toJson<String?>(reversesEventId),
      'beforeJson': serializer.toJson<String?>(beforeJson),
    };
  }

  DecisionEvent copyWith({
    String? id,
    String? profileId,
    String? titleId,
    String? action,
    String? context,
    Value<String?> mood = const Value.absent(),
    DateTime? createdAt,
    Value<String?> reversesEventId = const Value.absent(),
    Value<String?> beforeJson = const Value.absent(),
  }) => DecisionEvent(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    titleId: titleId ?? this.titleId,
    action: action ?? this.action,
    context: context ?? this.context,
    mood: mood.present ? mood.value : this.mood,
    createdAt: createdAt ?? this.createdAt,
    reversesEventId: reversesEventId.present
        ? reversesEventId.value
        : this.reversesEventId,
    beforeJson: beforeJson.present ? beforeJson.value : this.beforeJson,
  );
  DecisionEvent copyWithCompanion(DecisionEventsCompanion data) {
    return DecisionEvent(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      action: data.action.present ? data.action.value : this.action,
      context: data.context.present ? data.context.value : this.context,
      mood: data.mood.present ? data.mood.value : this.mood,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      reversesEventId: data.reversesEventId.present
          ? data.reversesEventId.value
          : this.reversesEventId,
      beforeJson: data.beforeJson.present
          ? data.beforeJson.value
          : this.beforeJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DecisionEvent(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('titleId: $titleId, ')
          ..write('action: $action, ')
          ..write('context: $context, ')
          ..write('mood: $mood, ')
          ..write('createdAt: $createdAt, ')
          ..write('reversesEventId: $reversesEventId, ')
          ..write('beforeJson: $beforeJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    titleId,
    action,
    context,
    mood,
    createdAt,
    reversesEventId,
    beforeJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DecisionEvent &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.titleId == this.titleId &&
          other.action == this.action &&
          other.context == this.context &&
          other.mood == this.mood &&
          other.createdAt == this.createdAt &&
          other.reversesEventId == this.reversesEventId &&
          other.beforeJson == this.beforeJson);
}

class DecisionEventsCompanion extends UpdateCompanion<DecisionEvent> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> titleId;
  final Value<String> action;
  final Value<String> context;
  final Value<String?> mood;
  final Value<DateTime> createdAt;
  final Value<String?> reversesEventId;
  final Value<String?> beforeJson;
  final Value<int> rowid;
  const DecisionEventsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.titleId = const Value.absent(),
    this.action = const Value.absent(),
    this.context = const Value.absent(),
    this.mood = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.reversesEventId = const Value.absent(),
    this.beforeJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DecisionEventsCompanion.insert({
    required String id,
    required String profileId,
    required String titleId,
    required String action,
    this.context = const Value.absent(),
    this.mood = const Value.absent(),
    required DateTime createdAt,
    this.reversesEventId = const Value.absent(),
    this.beforeJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       titleId = Value(titleId),
       action = Value(action),
       createdAt = Value(createdAt);
  static Insertable<DecisionEvent> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? titleId,
    Expression<String>? action,
    Expression<String>? context,
    Expression<String>? mood,
    Expression<DateTime>? createdAt,
    Expression<String>? reversesEventId,
    Expression<String>? beforeJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (titleId != null) 'title_id': titleId,
      if (action != null) 'action': action,
      if (context != null) 'context': context,
      if (mood != null) 'mood': mood,
      if (createdAt != null) 'created_at': createdAt,
      if (reversesEventId != null) 'reverses_event_id': reversesEventId,
      if (beforeJson != null) 'before_json': beforeJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DecisionEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? titleId,
    Value<String>? action,
    Value<String>? context,
    Value<String?>? mood,
    Value<DateTime>? createdAt,
    Value<String?>? reversesEventId,
    Value<String?>? beforeJson,
    Value<int>? rowid,
  }) {
    return DecisionEventsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      titleId: titleId ?? this.titleId,
      action: action ?? this.action,
      context: context ?? this.context,
      mood: mood ?? this.mood,
      createdAt: createdAt ?? this.createdAt,
      reversesEventId: reversesEventId ?? this.reversesEventId,
      beforeJson: beforeJson ?? this.beforeJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (context.present) {
      map['context'] = Variable<String>(context.value);
    }
    if (mood.present) {
      map['mood'] = Variable<String>(mood.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (reversesEventId.present) {
      map['reverses_event_id'] = Variable<String>(reversesEventId.value);
    }
    if (beforeJson.present) {
      map['before_json'] = Variable<String>(beforeJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DecisionEventsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('titleId: $titleId, ')
          ..write('action: $action, ')
          ..write('context: $context, ')
          ..write('mood: $mood, ')
          ..write('createdAt: $createdAt, ')
          ..write('reversesEventId: $reversesEventId, ')
          ..write('beforeJson: $beforeJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShortlistTable extends Shortlist
    with TableInfo<$ShortlistTable, ShortlistEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShortlistTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [profileId, titleId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shortlist';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShortlistEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, titleId};
  @override
  ShortlistEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShortlistEntry(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $ShortlistTable createAlias(String alias) {
    return $ShortlistTable(attachedDatabase, alias);
  }
}

class ShortlistEntry extends DataClass implements Insertable<ShortlistEntry> {
  final String profileId;
  final String titleId;
  final DateTime addedAt;
  const ShortlistEntry({
    required this.profileId,
    required this.titleId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['title_id'] = Variable<String>(titleId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  ShortlistCompanion toCompanion(bool nullToAbsent) {
    return ShortlistCompanion(
      profileId: Value(profileId),
      titleId: Value(titleId),
      addedAt: Value(addedAt),
    );
  }

  factory ShortlistEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShortlistEntry(
      profileId: serializer.fromJson<String>(json['profileId']),
      titleId: serializer.fromJson<String>(json['titleId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'titleId': serializer.toJson<String>(titleId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  ShortlistEntry copyWith({
    String? profileId,
    String? titleId,
    DateTime? addedAt,
  }) => ShortlistEntry(
    profileId: profileId ?? this.profileId,
    titleId: titleId ?? this.titleId,
    addedAt: addedAt ?? this.addedAt,
  );
  ShortlistEntry copyWithCompanion(ShortlistCompanion data) {
    return ShortlistEntry(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShortlistEntry(')
          ..write('profileId: $profileId, ')
          ..write('titleId: $titleId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, titleId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShortlistEntry &&
          other.profileId == this.profileId &&
          other.titleId == this.titleId &&
          other.addedAt == this.addedAt);
}

class ShortlistCompanion extends UpdateCompanion<ShortlistEntry> {
  final Value<String> profileId;
  final Value<String> titleId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const ShortlistCompanion({
    this.profileId = const Value.absent(),
    this.titleId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShortlistCompanion.insert({
    required String profileId,
    required String titleId,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       titleId = Value(titleId),
       addedAt = Value(addedAt);
  static Insertable<ShortlistEntry> custom({
    Expression<String>? profileId,
    Expression<String>? titleId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (titleId != null) 'title_id': titleId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShortlistCompanion copyWith({
    Value<String>? profileId,
    Value<String>? titleId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return ShortlistCompanion(
      profileId: profileId ?? this.profileId,
      titleId: titleId ?? this.titleId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShortlistCompanion(')
          ..write('profileId: $profileId, ')
          ..write('titleId: $titleId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeferralsTable extends Deferrals
    with TableInfo<$DeferralsTable, Deferral> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeferralsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eligibleAfterMeta = const VerificationMeta(
    'eligibleAfter',
  );
  @override
  late final GeneratedColumn<DateTime> eligibleAfter =
      GeneratedColumn<DateTime>(
        'eligible_after',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [profileId, titleId, eligibleAfter];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deferrals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Deferral> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('eligible_after')) {
      context.handle(
        _eligibleAfterMeta,
        eligibleAfter.isAcceptableOrUnknown(
          data['eligible_after']!,
          _eligibleAfterMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_eligibleAfterMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, titleId};
  @override
  Deferral map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Deferral(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      eligibleAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}eligible_after'],
      )!,
    );
  }

  @override
  $DeferralsTable createAlias(String alias) {
    return $DeferralsTable(attachedDatabase, alias);
  }
}

class Deferral extends DataClass implements Insertable<Deferral> {
  final String profileId;
  final String titleId;
  final DateTime eligibleAfter;
  const Deferral({
    required this.profileId,
    required this.titleId,
    required this.eligibleAfter,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['title_id'] = Variable<String>(titleId);
    map['eligible_after'] = Variable<DateTime>(eligibleAfter);
    return map;
  }

  DeferralsCompanion toCompanion(bool nullToAbsent) {
    return DeferralsCompanion(
      profileId: Value(profileId),
      titleId: Value(titleId),
      eligibleAfter: Value(eligibleAfter),
    );
  }

  factory Deferral.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Deferral(
      profileId: serializer.fromJson<String>(json['profileId']),
      titleId: serializer.fromJson<String>(json['titleId']),
      eligibleAfter: serializer.fromJson<DateTime>(json['eligibleAfter']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'titleId': serializer.toJson<String>(titleId),
      'eligibleAfter': serializer.toJson<DateTime>(eligibleAfter),
    };
  }

  Deferral copyWith({
    String? profileId,
    String? titleId,
    DateTime? eligibleAfter,
  }) => Deferral(
    profileId: profileId ?? this.profileId,
    titleId: titleId ?? this.titleId,
    eligibleAfter: eligibleAfter ?? this.eligibleAfter,
  );
  Deferral copyWithCompanion(DeferralsCompanion data) {
    return Deferral(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      eligibleAfter: data.eligibleAfter.present
          ? data.eligibleAfter.value
          : this.eligibleAfter,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Deferral(')
          ..write('profileId: $profileId, ')
          ..write('titleId: $titleId, ')
          ..write('eligibleAfter: $eligibleAfter')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, titleId, eligibleAfter);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Deferral &&
          other.profileId == this.profileId &&
          other.titleId == this.titleId &&
          other.eligibleAfter == this.eligibleAfter);
}

class DeferralsCompanion extends UpdateCompanion<Deferral> {
  final Value<String> profileId;
  final Value<String> titleId;
  final Value<DateTime> eligibleAfter;
  final Value<int> rowid;
  const DeferralsCompanion({
    this.profileId = const Value.absent(),
    this.titleId = const Value.absent(),
    this.eligibleAfter = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeferralsCompanion.insert({
    required String profileId,
    required String titleId,
    required DateTime eligibleAfter,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       titleId = Value(titleId),
       eligibleAfter = Value(eligibleAfter);
  static Insertable<Deferral> custom({
    Expression<String>? profileId,
    Expression<String>? titleId,
    Expression<DateTime>? eligibleAfter,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (titleId != null) 'title_id': titleId,
      if (eligibleAfter != null) 'eligible_after': eligibleAfter,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeferralsCompanion copyWith({
    Value<String>? profileId,
    Value<String>? titleId,
    Value<DateTime>? eligibleAfter,
    Value<int>? rowid,
  }) {
    return DeferralsCompanion(
      profileId: profileId ?? this.profileId,
      titleId: titleId ?? this.titleId,
      eligibleAfter: eligibleAfter ?? this.eligibleAfter,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (eligibleAfter.present) {
      map['eligible_after'] = Variable<DateTime>(eligibleAfter.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeferralsCompanion(')
          ..write('profileId: $profileId, ')
          ..write('titleId: $titleId, ')
          ..write('eligibleAfter: $eligibleAfter, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExclusionsTable extends Exclusions
    with TableInfo<$ExclusionsTable, Exclusion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExclusionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [profileId, titleId, active, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exclusions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Exclusion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, titleId};
  @override
  Exclusion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Exclusion(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExclusionsTable createAlias(String alias) {
    return $ExclusionsTable(attachedDatabase, alias);
  }
}

class Exclusion extends DataClass implements Insertable<Exclusion> {
  final String profileId;
  final String titleId;
  final bool active;
  final DateTime createdAt;
  const Exclusion({
    required this.profileId,
    required this.titleId,
    required this.active,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['title_id'] = Variable<String>(titleId);
    map['active'] = Variable<bool>(active);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ExclusionsCompanion toCompanion(bool nullToAbsent) {
    return ExclusionsCompanion(
      profileId: Value(profileId),
      titleId: Value(titleId),
      active: Value(active),
      createdAt: Value(createdAt),
    );
  }

  factory Exclusion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Exclusion(
      profileId: serializer.fromJson<String>(json['profileId']),
      titleId: serializer.fromJson<String>(json['titleId']),
      active: serializer.fromJson<bool>(json['active']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'titleId': serializer.toJson<String>(titleId),
      'active': serializer.toJson<bool>(active),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Exclusion copyWith({
    String? profileId,
    String? titleId,
    bool? active,
    DateTime? createdAt,
  }) => Exclusion(
    profileId: profileId ?? this.profileId,
    titleId: titleId ?? this.titleId,
    active: active ?? this.active,
    createdAt: createdAt ?? this.createdAt,
  );
  Exclusion copyWithCompanion(ExclusionsCompanion data) {
    return Exclusion(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      active: data.active.present ? data.active.value : this.active,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Exclusion(')
          ..write('profileId: $profileId, ')
          ..write('titleId: $titleId, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, titleId, active, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exclusion &&
          other.profileId == this.profileId &&
          other.titleId == this.titleId &&
          other.active == this.active &&
          other.createdAt == this.createdAt);
}

class ExclusionsCompanion extends UpdateCompanion<Exclusion> {
  final Value<String> profileId;
  final Value<String> titleId;
  final Value<bool> active;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ExclusionsCompanion({
    this.profileId = const Value.absent(),
    this.titleId = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExclusionsCompanion.insert({
    required String profileId,
    required String titleId,
    this.active = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       titleId = Value(titleId),
       createdAt = Value(createdAt);
  static Insertable<Exclusion> custom({
    Expression<String>? profileId,
    Expression<String>? titleId,
    Expression<bool>? active,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (titleId != null) 'title_id': titleId,
      if (active != null) 'active': active,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExclusionsCompanion copyWith({
    Value<String>? profileId,
    Value<String>? titleId,
    Value<bool>? active,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ExclusionsCompanion(
      profileId: profileId ?? this.profileId,
      titleId: titleId ?? this.titleId,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExclusionsCompanion(')
          ..write('profileId: $profileId, ')
          ..write('titleId: $titleId, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagWeightsTable extends TagWeights
    with TableInfo<$TagWeightsTable, TagWeight> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagWeightsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidenceCountMeta = const VerificationMeta(
    'evidenceCount',
  );
  @override
  late final GeneratedColumn<int> evidenceCount = GeneratedColumn<int>(
    'evidence_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    tag,
    weight,
    evidenceCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_weights';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagWeight> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    } else if (isInserting) {
      context.missing(_weightMeta);
    }
    if (data.containsKey('evidence_count')) {
      context.handle(
        _evidenceCountMeta,
        evidenceCount.isAcceptableOrUnknown(
          data['evidence_count']!,
          _evidenceCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_evidenceCountMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, tag};
  @override
  TagWeight map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagWeight(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      )!,
      evidenceCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}evidence_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TagWeightsTable createAlias(String alias) {
    return $TagWeightsTable(attachedDatabase, alias);
  }
}

class TagWeight extends DataClass implements Insertable<TagWeight> {
  final String profileId;
  final String tag;
  final double weight;
  final int evidenceCount;
  final DateTime updatedAt;
  const TagWeight({
    required this.profileId,
    required this.tag,
    required this.weight,
    required this.evidenceCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['tag'] = Variable<String>(tag);
    map['weight'] = Variable<double>(weight);
    map['evidence_count'] = Variable<int>(evidenceCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TagWeightsCompanion toCompanion(bool nullToAbsent) {
    return TagWeightsCompanion(
      profileId: Value(profileId),
      tag: Value(tag),
      weight: Value(weight),
      evidenceCount: Value(evidenceCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory TagWeight.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagWeight(
      profileId: serializer.fromJson<String>(json['profileId']),
      tag: serializer.fromJson<String>(json['tag']),
      weight: serializer.fromJson<double>(json['weight']),
      evidenceCount: serializer.fromJson<int>(json['evidenceCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'tag': serializer.toJson<String>(tag),
      'weight': serializer.toJson<double>(weight),
      'evidenceCount': serializer.toJson<int>(evidenceCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TagWeight copyWith({
    String? profileId,
    String? tag,
    double? weight,
    int? evidenceCount,
    DateTime? updatedAt,
  }) => TagWeight(
    profileId: profileId ?? this.profileId,
    tag: tag ?? this.tag,
    weight: weight ?? this.weight,
    evidenceCount: evidenceCount ?? this.evidenceCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TagWeight copyWithCompanion(TagWeightsCompanion data) {
    return TagWeight(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      tag: data.tag.present ? data.tag.value : this.tag,
      weight: data.weight.present ? data.weight.value : this.weight,
      evidenceCount: data.evidenceCount.present
          ? data.evidenceCount.value
          : this.evidenceCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagWeight(')
          ..write('profileId: $profileId, ')
          ..write('tag: $tag, ')
          ..write('weight: $weight, ')
          ..write('evidenceCount: $evidenceCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(profileId, tag, weight, evidenceCount, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagWeight &&
          other.profileId == this.profileId &&
          other.tag == this.tag &&
          other.weight == this.weight &&
          other.evidenceCount == this.evidenceCount &&
          other.updatedAt == this.updatedAt);
}

class TagWeightsCompanion extends UpdateCompanion<TagWeight> {
  final Value<String> profileId;
  final Value<String> tag;
  final Value<double> weight;
  final Value<int> evidenceCount;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TagWeightsCompanion({
    this.profileId = const Value.absent(),
    this.tag = const Value.absent(),
    this.weight = const Value.absent(),
    this.evidenceCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagWeightsCompanion.insert({
    required String profileId,
    required String tag,
    required double weight,
    required int evidenceCount,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       tag = Value(tag),
       weight = Value(weight),
       evidenceCount = Value(evidenceCount),
       updatedAt = Value(updatedAt);
  static Insertable<TagWeight> custom({
    Expression<String>? profileId,
    Expression<String>? tag,
    Expression<double>? weight,
    Expression<int>? evidenceCount,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (tag != null) 'tag': tag,
      if (weight != null) 'weight': weight,
      if (evidenceCount != null) 'evidence_count': evidenceCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagWeightsCompanion copyWith({
    Value<String>? profileId,
    Value<String>? tag,
    Value<double>? weight,
    Value<int>? evidenceCount,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TagWeightsCompanion(
      profileId: profileId ?? this.profileId,
      tag: tag ?? this.tag,
      weight: weight ?? this.weight,
      evidenceCount: evidenceCount ?? this.evidenceCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (evidenceCount.present) {
      map['evidence_count'] = Variable<int>(evidenceCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagWeightsCompanion(')
          ..write('profileId: $profileId, ')
          ..write('tag: $tag, ')
          ..write('weight: $weight, ')
          ..write('evidenceCount: $evidenceCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportBatchesTable extends ImportBatches
    with TableInfo<$ImportBatchesTable, ImportBatche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportBatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id)',
    ),
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _adapterVersionMeta = const VerificationMeta(
    'adapterVersion',
  );
  @override
  late final GeneratedColumn<String> adapterVersion = GeneratedColumn<String>(
    'adapter_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileFingerprintMeta = const VerificationMeta(
    'fileFingerprint',
  );
  @override
  late final GeneratedColumn<String> fileFingerprint = GeneratedColumn<String>(
    'file_fingerprint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countsJsonMeta = const VerificationMeta(
    'countsJson',
  );
  @override
  late final GeneratedColumn<String> countsJson = GeneratedColumn<String>(
    'counts_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    sourceType,
    adapterVersion,
    fileFingerprint,
    state,
    countsJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_batches';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportBatche> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('adapter_version')) {
      context.handle(
        _adapterVersionMeta,
        adapterVersion.isAcceptableOrUnknown(
          data['adapter_version']!,
          _adapterVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_adapterVersionMeta);
    }
    if (data.containsKey('file_fingerprint')) {
      context.handle(
        _fileFingerprintMeta,
        fileFingerprint.isAcceptableOrUnknown(
          data['file_fingerprint']!,
          _fileFingerprintMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('counts_json')) {
      context.handle(
        _countsJsonMeta,
        countsJson.isAcceptableOrUnknown(data['counts_json']!, _countsJsonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImportBatche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportBatche(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      adapterVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}adapter_version'],
      )!,
      fileFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_fingerprint'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      countsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counts_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ImportBatchesTable createAlias(String alias) {
    return $ImportBatchesTable(attachedDatabase, alias);
  }
}

class ImportBatche extends DataClass implements Insertable<ImportBatche> {
  final String id;
  final String profileId;
  final String sourceType;
  final String adapterVersion;
  final String? fileFingerprint;
  final String state;
  final String countsJson;
  final DateTime createdAt;
  const ImportBatche({
    required this.id,
    required this.profileId,
    required this.sourceType,
    required this.adapterVersion,
    this.fileFingerprint,
    required this.state,
    required this.countsJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['source_type'] = Variable<String>(sourceType);
    map['adapter_version'] = Variable<String>(adapterVersion);
    if (!nullToAbsent || fileFingerprint != null) {
      map['file_fingerprint'] = Variable<String>(fileFingerprint);
    }
    map['state'] = Variable<String>(state);
    map['counts_json'] = Variable<String>(countsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ImportBatchesCompanion toCompanion(bool nullToAbsent) {
    return ImportBatchesCompanion(
      id: Value(id),
      profileId: Value(profileId),
      sourceType: Value(sourceType),
      adapterVersion: Value(adapterVersion),
      fileFingerprint: fileFingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(fileFingerprint),
      state: Value(state),
      countsJson: Value(countsJson),
      createdAt: Value(createdAt),
    );
  }

  factory ImportBatche.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportBatche(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      adapterVersion: serializer.fromJson<String>(json['adapterVersion']),
      fileFingerprint: serializer.fromJson<String?>(json['fileFingerprint']),
      state: serializer.fromJson<String>(json['state']),
      countsJson: serializer.fromJson<String>(json['countsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'sourceType': serializer.toJson<String>(sourceType),
      'adapterVersion': serializer.toJson<String>(adapterVersion),
      'fileFingerprint': serializer.toJson<String?>(fileFingerprint),
      'state': serializer.toJson<String>(state),
      'countsJson': serializer.toJson<String>(countsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ImportBatche copyWith({
    String? id,
    String? profileId,
    String? sourceType,
    String? adapterVersion,
    Value<String?> fileFingerprint = const Value.absent(),
    String? state,
    String? countsJson,
    DateTime? createdAt,
  }) => ImportBatche(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    sourceType: sourceType ?? this.sourceType,
    adapterVersion: adapterVersion ?? this.adapterVersion,
    fileFingerprint: fileFingerprint.present
        ? fileFingerprint.value
        : this.fileFingerprint,
    state: state ?? this.state,
    countsJson: countsJson ?? this.countsJson,
    createdAt: createdAt ?? this.createdAt,
  );
  ImportBatche copyWithCompanion(ImportBatchesCompanion data) {
    return ImportBatche(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      adapterVersion: data.adapterVersion.present
          ? data.adapterVersion.value
          : this.adapterVersion,
      fileFingerprint: data.fileFingerprint.present
          ? data.fileFingerprint.value
          : this.fileFingerprint,
      state: data.state.present ? data.state.value : this.state,
      countsJson: data.countsJson.present
          ? data.countsJson.value
          : this.countsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportBatche(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('sourceType: $sourceType, ')
          ..write('adapterVersion: $adapterVersion, ')
          ..write('fileFingerprint: $fileFingerprint, ')
          ..write('state: $state, ')
          ..write('countsJson: $countsJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    sourceType,
    adapterVersion,
    fileFingerprint,
    state,
    countsJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportBatche &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.sourceType == this.sourceType &&
          other.adapterVersion == this.adapterVersion &&
          other.fileFingerprint == this.fileFingerprint &&
          other.state == this.state &&
          other.countsJson == this.countsJson &&
          other.createdAt == this.createdAt);
}

class ImportBatchesCompanion extends UpdateCompanion<ImportBatche> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> sourceType;
  final Value<String> adapterVersion;
  final Value<String?> fileFingerprint;
  final Value<String> state;
  final Value<String> countsJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ImportBatchesCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.adapterVersion = const Value.absent(),
    this.fileFingerprint = const Value.absent(),
    this.state = const Value.absent(),
    this.countsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportBatchesCompanion.insert({
    required String id,
    required String profileId,
    required String sourceType,
    required String adapterVersion,
    this.fileFingerprint = const Value.absent(),
    required String state,
    this.countsJson = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       sourceType = Value(sourceType),
       adapterVersion = Value(adapterVersion),
       state = Value(state),
       createdAt = Value(createdAt);
  static Insertable<ImportBatche> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? sourceType,
    Expression<String>? adapterVersion,
    Expression<String>? fileFingerprint,
    Expression<String>? state,
    Expression<String>? countsJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (sourceType != null) 'source_type': sourceType,
      if (adapterVersion != null) 'adapter_version': adapterVersion,
      if (fileFingerprint != null) 'file_fingerprint': fileFingerprint,
      if (state != null) 'state': state,
      if (countsJson != null) 'counts_json': countsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportBatchesCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? sourceType,
    Value<String>? adapterVersion,
    Value<String?>? fileFingerprint,
    Value<String>? state,
    Value<String>? countsJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ImportBatchesCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      sourceType: sourceType ?? this.sourceType,
      adapterVersion: adapterVersion ?? this.adapterVersion,
      fileFingerprint: fileFingerprint ?? this.fileFingerprint,
      state: state ?? this.state,
      countsJson: countsJson ?? this.countsJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (adapterVersion.present) {
      map['adapter_version'] = Variable<String>(adapterVersion.value);
    }
    if (fileFingerprint.present) {
      map['file_fingerprint'] = Variable<String>(fileFingerprint.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (countsJson.present) {
      map['counts_json'] = Variable<String>(countsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportBatchesCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('sourceType: $sourceType, ')
          ..write('adapterVersion: $adapterVersion, ')
          ..write('fileFingerprint: $fileFingerprint, ')
          ..write('state: $state, ')
          ..write('countsJson: $countsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SourceObservationsTable extends SourceObservations
    with TableInfo<$SourceObservationsTable, SourceObservation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceObservationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _batchIdMeta = const VerificationMeta(
    'batchId',
  );
  @override
  late final GeneratedColumn<String> batchId = GeneratedColumn<String>(
    'batch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES import_batches (id)',
    ),
  );
  static const VerificationMeta _sourceEntryKeyMeta = const VerificationMeta(
    'sourceEntryKey',
  );
  @override
  late final GeneratedColumn<String> sourceEntryKey = GeneratedColumn<String>(
    'source_entry_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawTitleMeta = const VerificationMeta(
    'rawTitle',
  );
  @override
  late final GeneratedColumn<String> rawTitle = GeneratedColumn<String>(
    'raw_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _matchClassMeta = const VerificationMeta(
    'matchClass',
  );
  @override
  late final GeneratedColumn<String> matchClass = GeneratedColumn<String>(
    'match_class',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratingOriginalMeta = const VerificationMeta(
    'ratingOriginal',
  );
  @override
  late final GeneratedColumn<String> ratingOriginal = GeneratedColumn<String>(
    'rating_original',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingScaleMeta = const VerificationMeta(
    'ratingScale',
  );
  @override
  late final GeneratedColumn<String> ratingScale = GeneratedColumn<String>(
    'rating_scale',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activityDateMeta = const VerificationMeta(
    'activityDate',
  );
  @override
  late final GeneratedColumn<DateTime> activityDate = GeneratedColumn<DateTime>(
    'activity_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _includedMeta = const VerificationMeta(
    'included',
  );
  @override
  late final GeneratedColumn<bool> included = GeneratedColumn<bool>(
    'included',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("included" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    batchId,
    sourceEntryKey,
    rawTitle,
    titleId,
    matchClass,
    status,
    ratingOriginal,
    ratingScale,
    progress,
    activityDate,
    included,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_observations';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceObservation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('batch_id')) {
      context.handle(
        _batchIdMeta,
        batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_batchIdMeta);
    }
    if (data.containsKey('source_entry_key')) {
      context.handle(
        _sourceEntryKeyMeta,
        sourceEntryKey.isAcceptableOrUnknown(
          data['source_entry_key']!,
          _sourceEntryKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceEntryKeyMeta);
    }
    if (data.containsKey('raw_title')) {
      context.handle(
        _rawTitleMeta,
        rawTitle.isAcceptableOrUnknown(data['raw_title']!, _rawTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_rawTitleMeta);
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    }
    if (data.containsKey('match_class')) {
      context.handle(
        _matchClassMeta,
        matchClass.isAcceptableOrUnknown(data['match_class']!, _matchClassMeta),
      );
    } else if (isInserting) {
      context.missing(_matchClassMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('rating_original')) {
      context.handle(
        _ratingOriginalMeta,
        ratingOriginal.isAcceptableOrUnknown(
          data['rating_original']!,
          _ratingOriginalMeta,
        ),
      );
    }
    if (data.containsKey('rating_scale')) {
      context.handle(
        _ratingScaleMeta,
        ratingScale.isAcceptableOrUnknown(
          data['rating_scale']!,
          _ratingScaleMeta,
        ),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('activity_date')) {
      context.handle(
        _activityDateMeta,
        activityDate.isAcceptableOrUnknown(
          data['activity_date']!,
          _activityDateMeta,
        ),
      );
    }
    if (data.containsKey('included')) {
      context.handle(
        _includedMeta,
        included.isAcceptableOrUnknown(data['included']!, _includedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SourceObservation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceObservation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      batchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}batch_id'],
      )!,
      sourceEntryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_entry_key'],
      )!,
      rawTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_title'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      ),
      matchClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_class'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      ratingOriginal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rating_original'],
      ),
      ratingScale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rating_scale'],
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      ),
      activityDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}activity_date'],
      ),
      included: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}included'],
      )!,
    );
  }

  @override
  $SourceObservationsTable createAlias(String alias) {
    return $SourceObservationsTable(attachedDatabase, alias);
  }
}

class SourceObservation extends DataClass
    implements Insertable<SourceObservation> {
  final String id;
  final String batchId;
  final String sourceEntryKey;
  final String rawTitle;
  final String? titleId;
  final String matchClass;
  final String status;
  final String? ratingOriginal;
  final String? ratingScale;
  final double? progress;
  final DateTime? activityDate;
  final bool included;
  const SourceObservation({
    required this.id,
    required this.batchId,
    required this.sourceEntryKey,
    required this.rawTitle,
    this.titleId,
    required this.matchClass,
    required this.status,
    this.ratingOriginal,
    this.ratingScale,
    this.progress,
    this.activityDate,
    required this.included,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['batch_id'] = Variable<String>(batchId);
    map['source_entry_key'] = Variable<String>(sourceEntryKey);
    map['raw_title'] = Variable<String>(rawTitle);
    if (!nullToAbsent || titleId != null) {
      map['title_id'] = Variable<String>(titleId);
    }
    map['match_class'] = Variable<String>(matchClass);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || ratingOriginal != null) {
      map['rating_original'] = Variable<String>(ratingOriginal);
    }
    if (!nullToAbsent || ratingScale != null) {
      map['rating_scale'] = Variable<String>(ratingScale);
    }
    if (!nullToAbsent || progress != null) {
      map['progress'] = Variable<double>(progress);
    }
    if (!nullToAbsent || activityDate != null) {
      map['activity_date'] = Variable<DateTime>(activityDate);
    }
    map['included'] = Variable<bool>(included);
    return map;
  }

  SourceObservationsCompanion toCompanion(bool nullToAbsent) {
    return SourceObservationsCompanion(
      id: Value(id),
      batchId: Value(batchId),
      sourceEntryKey: Value(sourceEntryKey),
      rawTitle: Value(rawTitle),
      titleId: titleId == null && nullToAbsent
          ? const Value.absent()
          : Value(titleId),
      matchClass: Value(matchClass),
      status: Value(status),
      ratingOriginal: ratingOriginal == null && nullToAbsent
          ? const Value.absent()
          : Value(ratingOriginal),
      ratingScale: ratingScale == null && nullToAbsent
          ? const Value.absent()
          : Value(ratingScale),
      progress: progress == null && nullToAbsent
          ? const Value.absent()
          : Value(progress),
      activityDate: activityDate == null && nullToAbsent
          ? const Value.absent()
          : Value(activityDate),
      included: Value(included),
    );
  }

  factory SourceObservation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceObservation(
      id: serializer.fromJson<String>(json['id']),
      batchId: serializer.fromJson<String>(json['batchId']),
      sourceEntryKey: serializer.fromJson<String>(json['sourceEntryKey']),
      rawTitle: serializer.fromJson<String>(json['rawTitle']),
      titleId: serializer.fromJson<String?>(json['titleId']),
      matchClass: serializer.fromJson<String>(json['matchClass']),
      status: serializer.fromJson<String>(json['status']),
      ratingOriginal: serializer.fromJson<String?>(json['ratingOriginal']),
      ratingScale: serializer.fromJson<String?>(json['ratingScale']),
      progress: serializer.fromJson<double?>(json['progress']),
      activityDate: serializer.fromJson<DateTime?>(json['activityDate']),
      included: serializer.fromJson<bool>(json['included']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'batchId': serializer.toJson<String>(batchId),
      'sourceEntryKey': serializer.toJson<String>(sourceEntryKey),
      'rawTitle': serializer.toJson<String>(rawTitle),
      'titleId': serializer.toJson<String?>(titleId),
      'matchClass': serializer.toJson<String>(matchClass),
      'status': serializer.toJson<String>(status),
      'ratingOriginal': serializer.toJson<String?>(ratingOriginal),
      'ratingScale': serializer.toJson<String?>(ratingScale),
      'progress': serializer.toJson<double?>(progress),
      'activityDate': serializer.toJson<DateTime?>(activityDate),
      'included': serializer.toJson<bool>(included),
    };
  }

  SourceObservation copyWith({
    String? id,
    String? batchId,
    String? sourceEntryKey,
    String? rawTitle,
    Value<String?> titleId = const Value.absent(),
    String? matchClass,
    String? status,
    Value<String?> ratingOriginal = const Value.absent(),
    Value<String?> ratingScale = const Value.absent(),
    Value<double?> progress = const Value.absent(),
    Value<DateTime?> activityDate = const Value.absent(),
    bool? included,
  }) => SourceObservation(
    id: id ?? this.id,
    batchId: batchId ?? this.batchId,
    sourceEntryKey: sourceEntryKey ?? this.sourceEntryKey,
    rawTitle: rawTitle ?? this.rawTitle,
    titleId: titleId.present ? titleId.value : this.titleId,
    matchClass: matchClass ?? this.matchClass,
    status: status ?? this.status,
    ratingOriginal: ratingOriginal.present
        ? ratingOriginal.value
        : this.ratingOriginal,
    ratingScale: ratingScale.present ? ratingScale.value : this.ratingScale,
    progress: progress.present ? progress.value : this.progress,
    activityDate: activityDate.present ? activityDate.value : this.activityDate,
    included: included ?? this.included,
  );
  SourceObservation copyWithCompanion(SourceObservationsCompanion data) {
    return SourceObservation(
      id: data.id.present ? data.id.value : this.id,
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
      sourceEntryKey: data.sourceEntryKey.present
          ? data.sourceEntryKey.value
          : this.sourceEntryKey,
      rawTitle: data.rawTitle.present ? data.rawTitle.value : this.rawTitle,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      matchClass: data.matchClass.present
          ? data.matchClass.value
          : this.matchClass,
      status: data.status.present ? data.status.value : this.status,
      ratingOriginal: data.ratingOriginal.present
          ? data.ratingOriginal.value
          : this.ratingOriginal,
      ratingScale: data.ratingScale.present
          ? data.ratingScale.value
          : this.ratingScale,
      progress: data.progress.present ? data.progress.value : this.progress,
      activityDate: data.activityDate.present
          ? data.activityDate.value
          : this.activityDate,
      included: data.included.present ? data.included.value : this.included,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceObservation(')
          ..write('id: $id, ')
          ..write('batchId: $batchId, ')
          ..write('sourceEntryKey: $sourceEntryKey, ')
          ..write('rawTitle: $rawTitle, ')
          ..write('titleId: $titleId, ')
          ..write('matchClass: $matchClass, ')
          ..write('status: $status, ')
          ..write('ratingOriginal: $ratingOriginal, ')
          ..write('ratingScale: $ratingScale, ')
          ..write('progress: $progress, ')
          ..write('activityDate: $activityDate, ')
          ..write('included: $included')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    batchId,
    sourceEntryKey,
    rawTitle,
    titleId,
    matchClass,
    status,
    ratingOriginal,
    ratingScale,
    progress,
    activityDate,
    included,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceObservation &&
          other.id == this.id &&
          other.batchId == this.batchId &&
          other.sourceEntryKey == this.sourceEntryKey &&
          other.rawTitle == this.rawTitle &&
          other.titleId == this.titleId &&
          other.matchClass == this.matchClass &&
          other.status == this.status &&
          other.ratingOriginal == this.ratingOriginal &&
          other.ratingScale == this.ratingScale &&
          other.progress == this.progress &&
          other.activityDate == this.activityDate &&
          other.included == this.included);
}

class SourceObservationsCompanion extends UpdateCompanion<SourceObservation> {
  final Value<String> id;
  final Value<String> batchId;
  final Value<String> sourceEntryKey;
  final Value<String> rawTitle;
  final Value<String?> titleId;
  final Value<String> matchClass;
  final Value<String> status;
  final Value<String?> ratingOriginal;
  final Value<String?> ratingScale;
  final Value<double?> progress;
  final Value<DateTime?> activityDate;
  final Value<bool> included;
  final Value<int> rowid;
  const SourceObservationsCompanion({
    this.id = const Value.absent(),
    this.batchId = const Value.absent(),
    this.sourceEntryKey = const Value.absent(),
    this.rawTitle = const Value.absent(),
    this.titleId = const Value.absent(),
    this.matchClass = const Value.absent(),
    this.status = const Value.absent(),
    this.ratingOriginal = const Value.absent(),
    this.ratingScale = const Value.absent(),
    this.progress = const Value.absent(),
    this.activityDate = const Value.absent(),
    this.included = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourceObservationsCompanion.insert({
    required String id,
    required String batchId,
    required String sourceEntryKey,
    required String rawTitle,
    this.titleId = const Value.absent(),
    required String matchClass,
    required String status,
    this.ratingOriginal = const Value.absent(),
    this.ratingScale = const Value.absent(),
    this.progress = const Value.absent(),
    this.activityDate = const Value.absent(),
    this.included = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       batchId = Value(batchId),
       sourceEntryKey = Value(sourceEntryKey),
       rawTitle = Value(rawTitle),
       matchClass = Value(matchClass),
       status = Value(status);
  static Insertable<SourceObservation> custom({
    Expression<String>? id,
    Expression<String>? batchId,
    Expression<String>? sourceEntryKey,
    Expression<String>? rawTitle,
    Expression<String>? titleId,
    Expression<String>? matchClass,
    Expression<String>? status,
    Expression<String>? ratingOriginal,
    Expression<String>? ratingScale,
    Expression<double>? progress,
    Expression<DateTime>? activityDate,
    Expression<bool>? included,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (batchId != null) 'batch_id': batchId,
      if (sourceEntryKey != null) 'source_entry_key': sourceEntryKey,
      if (rawTitle != null) 'raw_title': rawTitle,
      if (titleId != null) 'title_id': titleId,
      if (matchClass != null) 'match_class': matchClass,
      if (status != null) 'status': status,
      if (ratingOriginal != null) 'rating_original': ratingOriginal,
      if (ratingScale != null) 'rating_scale': ratingScale,
      if (progress != null) 'progress': progress,
      if (activityDate != null) 'activity_date': activityDate,
      if (included != null) 'included': included,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourceObservationsCompanion copyWith({
    Value<String>? id,
    Value<String>? batchId,
    Value<String>? sourceEntryKey,
    Value<String>? rawTitle,
    Value<String?>? titleId,
    Value<String>? matchClass,
    Value<String>? status,
    Value<String?>? ratingOriginal,
    Value<String?>? ratingScale,
    Value<double?>? progress,
    Value<DateTime?>? activityDate,
    Value<bool>? included,
    Value<int>? rowid,
  }) {
    return SourceObservationsCompanion(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      sourceEntryKey: sourceEntryKey ?? this.sourceEntryKey,
      rawTitle: rawTitle ?? this.rawTitle,
      titleId: titleId ?? this.titleId,
      matchClass: matchClass ?? this.matchClass,
      status: status ?? this.status,
      ratingOriginal: ratingOriginal ?? this.ratingOriginal,
      ratingScale: ratingScale ?? this.ratingScale,
      progress: progress ?? this.progress,
      activityDate: activityDate ?? this.activityDate,
      included: included ?? this.included,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (batchId.present) {
      map['batch_id'] = Variable<String>(batchId.value);
    }
    if (sourceEntryKey.present) {
      map['source_entry_key'] = Variable<String>(sourceEntryKey.value);
    }
    if (rawTitle.present) {
      map['raw_title'] = Variable<String>(rawTitle.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (matchClass.present) {
      map['match_class'] = Variable<String>(matchClass.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (ratingOriginal.present) {
      map['rating_original'] = Variable<String>(ratingOriginal.value);
    }
    if (ratingScale.present) {
      map['rating_scale'] = Variable<String>(ratingScale.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (activityDate.present) {
      map['activity_date'] = Variable<DateTime>(activityDate.value);
    }
    if (included.present) {
      map['included'] = Variable<bool>(included.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourceObservationsCompanion(')
          ..write('id: $id, ')
          ..write('batchId: $batchId, ')
          ..write('sourceEntryKey: $sourceEntryKey, ')
          ..write('rawTitle: $rawTitle, ')
          ..write('titleId: $titleId, ')
          ..write('matchClass: $matchClass, ')
          ..write('status: $status, ')
          ..write('ratingOriginal: $ratingOriginal, ')
          ..write('ratingScale: $ratingScale, ')
          ..write('progress: $progress, ')
          ..write('activityDate: $activityDate, ')
          ..write('included: $included, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportChangesTable extends ImportChanges
    with TableInfo<$ImportChangesTable, ImportChange> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _batchIdMeta = const VerificationMeta(
    'batchId',
  );
  @override
  late final GeneratedColumn<String> batchId = GeneratedColumn<String>(
    'batch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES import_batches (id)',
    ),
  );
  static const VerificationMeta _tableName_Meta = const VerificationMeta(
    'tableName_',
  );
  @override
  late final GeneratedColumn<String> tableName_ = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowKeyMeta = const VerificationMeta('rowKey');
  @override
  late final GeneratedColumn<String> rowKey = GeneratedColumn<String>(
    'row_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beforeJsonMeta = const VerificationMeta(
    'beforeJson',
  );
  @override
  late final GeneratedColumn<String> beforeJson = GeneratedColumn<String>(
    'before_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _afterJsonMeta = const VerificationMeta(
    'afterJson',
  );
  @override
  late final GeneratedColumn<String> afterJson = GeneratedColumn<String>(
    'after_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    batchId,
    tableName_,
    rowKey,
    beforeJson,
    afterJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportChange> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('batch_id')) {
      context.handle(
        _batchIdMeta,
        batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_batchIdMeta);
    }
    if (data.containsKey('table_name')) {
      context.handle(
        _tableName_Meta,
        tableName_.isAcceptableOrUnknown(data['table_name']!, _tableName_Meta),
      );
    } else if (isInserting) {
      context.missing(_tableName_Meta);
    }
    if (data.containsKey('row_key')) {
      context.handle(
        _rowKeyMeta,
        rowKey.isAcceptableOrUnknown(data['row_key']!, _rowKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_rowKeyMeta);
    }
    if (data.containsKey('before_json')) {
      context.handle(
        _beforeJsonMeta,
        beforeJson.isAcceptableOrUnknown(data['before_json']!, _beforeJsonMeta),
      );
    }
    if (data.containsKey('after_json')) {
      context.handle(
        _afterJsonMeta,
        afterJson.isAcceptableOrUnknown(data['after_json']!, _afterJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  ImportChange map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportChange(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      batchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}batch_id'],
      )!,
      tableName_: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      rowKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_key'],
      )!,
      beforeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before_json'],
      ),
      afterJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after_json'],
      ),
    );
  }

  @override
  $ImportChangesTable createAlias(String alias) {
    return $ImportChangesTable(attachedDatabase, alias);
  }
}

class ImportChange extends DataClass implements Insertable<ImportChange> {
  final int seq;
  final String batchId;
  final String tableName_;
  final String rowKey;
  final String? beforeJson;
  final String? afterJson;
  const ImportChange({
    required this.seq,
    required this.batchId,
    required this.tableName_,
    required this.rowKey,
    this.beforeJson,
    this.afterJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['batch_id'] = Variable<String>(batchId);
    map['table_name'] = Variable<String>(tableName_);
    map['row_key'] = Variable<String>(rowKey);
    if (!nullToAbsent || beforeJson != null) {
      map['before_json'] = Variable<String>(beforeJson);
    }
    if (!nullToAbsent || afterJson != null) {
      map['after_json'] = Variable<String>(afterJson);
    }
    return map;
  }

  ImportChangesCompanion toCompanion(bool nullToAbsent) {
    return ImportChangesCompanion(
      seq: Value(seq),
      batchId: Value(batchId),
      tableName_: Value(tableName_),
      rowKey: Value(rowKey),
      beforeJson: beforeJson == null && nullToAbsent
          ? const Value.absent()
          : Value(beforeJson),
      afterJson: afterJson == null && nullToAbsent
          ? const Value.absent()
          : Value(afterJson),
    );
  }

  factory ImportChange.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportChange(
      seq: serializer.fromJson<int>(json['seq']),
      batchId: serializer.fromJson<String>(json['batchId']),
      tableName_: serializer.fromJson<String>(json['tableName_']),
      rowKey: serializer.fromJson<String>(json['rowKey']),
      beforeJson: serializer.fromJson<String?>(json['beforeJson']),
      afterJson: serializer.fromJson<String?>(json['afterJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'batchId': serializer.toJson<String>(batchId),
      'tableName_': serializer.toJson<String>(tableName_),
      'rowKey': serializer.toJson<String>(rowKey),
      'beforeJson': serializer.toJson<String?>(beforeJson),
      'afterJson': serializer.toJson<String?>(afterJson),
    };
  }

  ImportChange copyWith({
    int? seq,
    String? batchId,
    String? tableName_,
    String? rowKey,
    Value<String?> beforeJson = const Value.absent(),
    Value<String?> afterJson = const Value.absent(),
  }) => ImportChange(
    seq: seq ?? this.seq,
    batchId: batchId ?? this.batchId,
    tableName_: tableName_ ?? this.tableName_,
    rowKey: rowKey ?? this.rowKey,
    beforeJson: beforeJson.present ? beforeJson.value : this.beforeJson,
    afterJson: afterJson.present ? afterJson.value : this.afterJson,
  );
  ImportChange copyWithCompanion(ImportChangesCompanion data) {
    return ImportChange(
      seq: data.seq.present ? data.seq.value : this.seq,
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
      tableName_: data.tableName_.present
          ? data.tableName_.value
          : this.tableName_,
      rowKey: data.rowKey.present ? data.rowKey.value : this.rowKey,
      beforeJson: data.beforeJson.present
          ? data.beforeJson.value
          : this.beforeJson,
      afterJson: data.afterJson.present ? data.afterJson.value : this.afterJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportChange(')
          ..write('seq: $seq, ')
          ..write('batchId: $batchId, ')
          ..write('tableName_: $tableName_, ')
          ..write('rowKey: $rowKey, ')
          ..write('beforeJson: $beforeJson, ')
          ..write('afterJson: $afterJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(seq, batchId, tableName_, rowKey, beforeJson, afterJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportChange &&
          other.seq == this.seq &&
          other.batchId == this.batchId &&
          other.tableName_ == this.tableName_ &&
          other.rowKey == this.rowKey &&
          other.beforeJson == this.beforeJson &&
          other.afterJson == this.afterJson);
}

class ImportChangesCompanion extends UpdateCompanion<ImportChange> {
  final Value<int> seq;
  final Value<String> batchId;
  final Value<String> tableName_;
  final Value<String> rowKey;
  final Value<String?> beforeJson;
  final Value<String?> afterJson;
  const ImportChangesCompanion({
    this.seq = const Value.absent(),
    this.batchId = const Value.absent(),
    this.tableName_ = const Value.absent(),
    this.rowKey = const Value.absent(),
    this.beforeJson = const Value.absent(),
    this.afterJson = const Value.absent(),
  });
  ImportChangesCompanion.insert({
    this.seq = const Value.absent(),
    required String batchId,
    required String tableName_,
    required String rowKey,
    this.beforeJson = const Value.absent(),
    this.afterJson = const Value.absent(),
  }) : batchId = Value(batchId),
       tableName_ = Value(tableName_),
       rowKey = Value(rowKey);
  static Insertable<ImportChange> custom({
    Expression<int>? seq,
    Expression<String>? batchId,
    Expression<String>? tableName_,
    Expression<String>? rowKey,
    Expression<String>? beforeJson,
    Expression<String>? afterJson,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (batchId != null) 'batch_id': batchId,
      if (tableName_ != null) 'table_name': tableName_,
      if (rowKey != null) 'row_key': rowKey,
      if (beforeJson != null) 'before_json': beforeJson,
      if (afterJson != null) 'after_json': afterJson,
    });
  }

  ImportChangesCompanion copyWith({
    Value<int>? seq,
    Value<String>? batchId,
    Value<String>? tableName_,
    Value<String>? rowKey,
    Value<String?>? beforeJson,
    Value<String?>? afterJson,
  }) {
    return ImportChangesCompanion(
      seq: seq ?? this.seq,
      batchId: batchId ?? this.batchId,
      tableName_: tableName_ ?? this.tableName_,
      rowKey: rowKey ?? this.rowKey,
      beforeJson: beforeJson ?? this.beforeJson,
      afterJson: afterJson ?? this.afterJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (batchId.present) {
      map['batch_id'] = Variable<String>(batchId.value);
    }
    if (tableName_.present) {
      map['table_name'] = Variable<String>(tableName_.value);
    }
    if (rowKey.present) {
      map['row_key'] = Variable<String>(rowKey.value);
    }
    if (beforeJson.present) {
      map['before_json'] = Variable<String>(beforeJson.value);
    }
    if (afterJson.present) {
      map['after_json'] = Variable<String>(afterJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportChangesCompanion(')
          ..write('seq: $seq, ')
          ..write('batchId: $batchId, ')
          ..write('tableName_: $tableName_, ')
          ..write('rowKey: $rowKey, ')
          ..write('beforeJson: $beforeJson, ')
          ..write('afterJson: $afterJson')
          ..write(')'))
        .toString();
  }
}

abstract class _$CueDatabase extends GeneratedDatabase {
  _$CueDatabase(QueryExecutor e) : super(e);
  $CueDatabaseManager get managers => $CueDatabaseManager(this);
  late final $CatalogTitlesTable catalogTitles = $CatalogTitlesTable(this);
  late final $CatalogIdentitiesTable catalogIdentities =
      $CatalogIdentitiesTable(this);
  late final $CatalogPagesTable catalogPages = $CatalogPagesTable(this);
  late final $WatchProvidersTable watchProviders = $WatchProvidersTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $ProfileSettingsTable profileSettings = $ProfileSettingsTable(
    this,
  );
  late final $UserTitlesTable userTitles = $UserTitlesTable(this);
  late final $DecisionEventsTable decisionEvents = $DecisionEventsTable(this);
  late final $ShortlistTable shortlist = $ShortlistTable(this);
  late final $DeferralsTable deferrals = $DeferralsTable(this);
  late final $ExclusionsTable exclusions = $ExclusionsTable(this);
  late final $TagWeightsTable tagWeights = $TagWeightsTable(this);
  late final $ImportBatchesTable importBatches = $ImportBatchesTable(this);
  late final $SourceObservationsTable sourceObservations =
      $SourceObservationsTable(this);
  late final $ImportChangesTable importChanges = $ImportChangesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    catalogTitles,
    catalogIdentities,
    catalogPages,
    watchProviders,
    profiles,
    profileSettings,
    userTitles,
    decisionEvents,
    shortlist,
    deferrals,
    exclusions,
    tagWeights,
    importBatches,
    sourceObservations,
    importChanges,
  ];
}

typedef $$CatalogTitlesTableCreateCompanionBuilder =
    CatalogTitlesCompanion Function({
      required String id,
      required String mediaKind,
      Value<String?> titleEn,
      Value<String?> titleRomaji,
      Value<String?> titleNative,
      Value<int?> year,
      Value<String?> country,
      Value<String?> format,
      Value<String> status,
      Value<int?> episodes,
      Value<int?> chapters,
      Value<String> seasonsJson,
      Value<String> genresJson,
      Value<String> tagsJson,
      Value<int?> score,
      Value<String?> posterUrl,
      Value<String?> backdropUrl,
      Value<String?> synopsis,
      Value<String?> franchiseId,
      Value<bool> adult,
      Value<bool> detailed,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CatalogTitlesTableUpdateCompanionBuilder =
    CatalogTitlesCompanion Function({
      Value<String> id,
      Value<String> mediaKind,
      Value<String?> titleEn,
      Value<String?> titleRomaji,
      Value<String?> titleNative,
      Value<int?> year,
      Value<String?> country,
      Value<String?> format,
      Value<String> status,
      Value<int?> episodes,
      Value<int?> chapters,
      Value<String> seasonsJson,
      Value<String> genresJson,
      Value<String> tagsJson,
      Value<int?> score,
      Value<String?> posterUrl,
      Value<String?> backdropUrl,
      Value<String?> synopsis,
      Value<String?> franchiseId,
      Value<bool> adult,
      Value<bool> detailed,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$CatalogTitlesTableReferences
    extends BaseReferences<_$CueDatabase, $CatalogTitlesTable, CatalogTitle> {
  $$CatalogTitlesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$CatalogIdentitiesTable, List<CatalogIdentity>>
  _catalogIdentitiesRefsTable(_$CueDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.catalogIdentities,
        aliasName: 'catalog_titles__id__catalog_identities__title_id',
      );

  $$CatalogIdentitiesTableProcessedTableManager get catalogIdentitiesRefs {
    final manager = $$CatalogIdentitiesTableTableManager(
      $_db,
      $_db.catalogIdentities,
    ).filter((f) => f.titleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _catalogIdentitiesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WatchProvidersTable, List<WatchProvider>>
  _watchProvidersRefsTable(_$CueDatabase db) => MultiTypedResultKey.fromTable(
    db.watchProviders,
    aliasName: 'catalog_titles__id__watch_providers__title_id',
  );

  $$WatchProvidersTableProcessedTableManager get watchProvidersRefs {
    final manager = $$WatchProvidersTableTableManager(
      $_db,
      $_db.watchProviders,
    ).filter((f) => f.titleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_watchProvidersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CatalogTitlesTableFilterComposer
    extends Composer<_$CueDatabase, $CatalogTitlesTable> {
  $$CatalogTitlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleEn => $composableBuilder(
    column: $table.titleEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleRomaji => $composableBuilder(
    column: $table.titleRomaji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleNative => $composableBuilder(
    column: $table.titleNative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodes => $composableBuilder(
    column: $table.episodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapters => $composableBuilder(
    column: $table.chapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seasonsJson => $composableBuilder(
    column: $table.seasonsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posterUrl => $composableBuilder(
    column: $table.posterUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get synopsis => $composableBuilder(
    column: $table.synopsis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get franchiseId => $composableBuilder(
    column: $table.franchiseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get adult => $composableBuilder(
    column: $table.adult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get detailed => $composableBuilder(
    column: $table.detailed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> catalogIdentitiesRefs(
    Expression<bool> Function($$CatalogIdentitiesTableFilterComposer f) f,
  ) {
    final $$CatalogIdentitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.catalogIdentities,
      getReferencedColumn: (t) => t.titleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogIdentitiesTableFilterComposer(
            $db: $db,
            $table: $db.catalogIdentities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> watchProvidersRefs(
    Expression<bool> Function($$WatchProvidersTableFilterComposer f) f,
  ) {
    final $$WatchProvidersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.watchProviders,
      getReferencedColumn: (t) => t.titleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchProvidersTableFilterComposer(
            $db: $db,
            $table: $db.watchProviders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CatalogTitlesTableOrderingComposer
    extends Composer<_$CueDatabase, $CatalogTitlesTable> {
  $$CatalogTitlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleEn => $composableBuilder(
    column: $table.titleEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleRomaji => $composableBuilder(
    column: $table.titleRomaji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleNative => $composableBuilder(
    column: $table.titleNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodes => $composableBuilder(
    column: $table.episodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapters => $composableBuilder(
    column: $table.chapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seasonsJson => $composableBuilder(
    column: $table.seasonsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posterUrl => $composableBuilder(
    column: $table.posterUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get synopsis => $composableBuilder(
    column: $table.synopsis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get franchiseId => $composableBuilder(
    column: $table.franchiseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get adult => $composableBuilder(
    column: $table.adult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get detailed => $composableBuilder(
    column: $table.detailed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogTitlesTableAnnotationComposer
    extends Composer<_$CueDatabase, $CatalogTitlesTable> {
  $$CatalogTitlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mediaKind =>
      $composableBuilder(column: $table.mediaKind, builder: (column) => column);

  GeneratedColumn<String> get titleEn =>
      $composableBuilder(column: $table.titleEn, builder: (column) => column);

  GeneratedColumn<String> get titleRomaji => $composableBuilder(
    column: $table.titleRomaji,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleNative => $composableBuilder(
    column: $table.titleNative,
    builder: (column) => column,
  );

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get episodes =>
      $composableBuilder(column: $table.episodes, builder: (column) => column);

  GeneratedColumn<int> get chapters =>
      $composableBuilder(column: $table.chapters, builder: (column) => column);

  GeneratedColumn<String> get seasonsJson => $composableBuilder(
    column: $table.seasonsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get posterUrl =>
      $composableBuilder(column: $table.posterUrl, builder: (column) => column);

  GeneratedColumn<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get synopsis =>
      $composableBuilder(column: $table.synopsis, builder: (column) => column);

  GeneratedColumn<String> get franchiseId => $composableBuilder(
    column: $table.franchiseId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get adult =>
      $composableBuilder(column: $table.adult, builder: (column) => column);

  GeneratedColumn<bool> get detailed =>
      $composableBuilder(column: $table.detailed, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> catalogIdentitiesRefs<T extends Object>(
    Expression<T> Function($$CatalogIdentitiesTableAnnotationComposer a) f,
  ) {
    final $$CatalogIdentitiesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.catalogIdentities,
          getReferencedColumn: (t) => t.titleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CatalogIdentitiesTableAnnotationComposer(
                $db: $db,
                $table: $db.catalogIdentities,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> watchProvidersRefs<T extends Object>(
    Expression<T> Function($$WatchProvidersTableAnnotationComposer a) f,
  ) {
    final $$WatchProvidersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.watchProviders,
      getReferencedColumn: (t) => t.titleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchProvidersTableAnnotationComposer(
            $db: $db,
            $table: $db.watchProviders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CatalogTitlesTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $CatalogTitlesTable,
          CatalogTitle,
          $$CatalogTitlesTableFilterComposer,
          $$CatalogTitlesTableOrderingComposer,
          $$CatalogTitlesTableAnnotationComposer,
          $$CatalogTitlesTableCreateCompanionBuilder,
          $$CatalogTitlesTableUpdateCompanionBuilder,
          (CatalogTitle, $$CatalogTitlesTableReferences),
          CatalogTitle,
          PrefetchHooks Function({
            bool catalogIdentitiesRefs,
            bool watchProvidersRefs,
          })
        > {
  $$CatalogTitlesTableTableManager(_$CueDatabase db, $CatalogTitlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogTitlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogTitlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogTitlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> mediaKind = const Value.absent(),
                Value<String?> titleEn = const Value.absent(),
                Value<String?> titleRomaji = const Value.absent(),
                Value<String?> titleNative = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> episodes = const Value.absent(),
                Value<int?> chapters = const Value.absent(),
                Value<String> seasonsJson = const Value.absent(),
                Value<String> genresJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<int?> score = const Value.absent(),
                Value<String?> posterUrl = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<String?> synopsis = const Value.absent(),
                Value<String?> franchiseId = const Value.absent(),
                Value<bool> adult = const Value.absent(),
                Value<bool> detailed = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogTitlesCompanion(
                id: id,
                mediaKind: mediaKind,
                titleEn: titleEn,
                titleRomaji: titleRomaji,
                titleNative: titleNative,
                year: year,
                country: country,
                format: format,
                status: status,
                episodes: episodes,
                chapters: chapters,
                seasonsJson: seasonsJson,
                genresJson: genresJson,
                tagsJson: tagsJson,
                score: score,
                posterUrl: posterUrl,
                backdropUrl: backdropUrl,
                synopsis: synopsis,
                franchiseId: franchiseId,
                adult: adult,
                detailed: detailed,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String mediaKind,
                Value<String?> titleEn = const Value.absent(),
                Value<String?> titleRomaji = const Value.absent(),
                Value<String?> titleNative = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> episodes = const Value.absent(),
                Value<int?> chapters = const Value.absent(),
                Value<String> seasonsJson = const Value.absent(),
                Value<String> genresJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<int?> score = const Value.absent(),
                Value<String?> posterUrl = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<String?> synopsis = const Value.absent(),
                Value<String?> franchiseId = const Value.absent(),
                Value<bool> adult = const Value.absent(),
                Value<bool> detailed = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatalogTitlesCompanion.insert(
                id: id,
                mediaKind: mediaKind,
                titleEn: titleEn,
                titleRomaji: titleRomaji,
                titleNative: titleNative,
                year: year,
                country: country,
                format: format,
                status: status,
                episodes: episodes,
                chapters: chapters,
                seasonsJson: seasonsJson,
                genresJson: genresJson,
                tagsJson: tagsJson,
                score: score,
                posterUrl: posterUrl,
                backdropUrl: backdropUrl,
                synopsis: synopsis,
                franchiseId: franchiseId,
                adult: adult,
                detailed: detailed,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogTitlesTable, CatalogTitle>(table),
                  $$CatalogTitlesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({catalogIdentitiesRefs = false, watchProvidersRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (catalogIdentitiesRefs) db.catalogIdentities,
                    if (watchProvidersRefs) db.watchProviders,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (catalogIdentitiesRefs)
                        await $_getPrefetchedDataByColumns<
                          CatalogTitle,
                          $CatalogTitlesTable,
                          CatalogIdentity,
                          $CatalogIdentitiesTable
                        >(
                          currentTable: table,
                          referencedTable: $$CatalogTitlesTableReferences
                              ._catalogIdentitiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CatalogTitlesTableReferences(
                                db,
                                table,
                                p0,
                              ).catalogIdentitiesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'title_id',
                          typedResults: items,
                        ),
                      if (watchProvidersRefs)
                        await $_getPrefetchedDataByColumns<
                          CatalogTitle,
                          $CatalogTitlesTable,
                          WatchProvider,
                          $WatchProvidersTable
                        >(
                          currentTable: table,
                          referencedTable: $$CatalogTitlesTableReferences
                              ._watchProvidersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CatalogTitlesTableReferences(
                                db,
                                table,
                                p0,
                              ).watchProvidersRefs,
                          currentColumn: 'id',
                          referencedColumn: 'title_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CatalogTitlesTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $CatalogTitlesTable,
      CatalogTitle,
      $$CatalogTitlesTableFilterComposer,
      $$CatalogTitlesTableOrderingComposer,
      $$CatalogTitlesTableAnnotationComposer,
      $$CatalogTitlesTableCreateCompanionBuilder,
      $$CatalogTitlesTableUpdateCompanionBuilder,
      (CatalogTitle, $$CatalogTitlesTableReferences),
      CatalogTitle,
      PrefetchHooks Function({
        bool catalogIdentitiesRefs,
        bool watchProvidersRefs,
      })
    >;
typedef $$CatalogIdentitiesTableCreateCompanionBuilder =
    CatalogIdentitiesCompanion Function({
      required String titleId,
      required String provider,
      required String providerId,
      Value<String> providerKind,
      Value<int> rowid,
    });
typedef $$CatalogIdentitiesTableUpdateCompanionBuilder =
    CatalogIdentitiesCompanion Function({
      Value<String> titleId,
      Value<String> provider,
      Value<String> providerId,
      Value<String> providerKind,
      Value<int> rowid,
    });

final class $$CatalogIdentitiesTableReferences
    extends
        BaseReferences<
          _$CueDatabase,
          $CatalogIdentitiesTable,
          CatalogIdentity
        > {
  $$CatalogIdentitiesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CatalogTitlesTable _titleIdTable(_$CueDatabase db) => db.catalogTitles
      .createAlias('catalog_identities__title_id__catalog_titles__id');

  $$CatalogTitlesTableProcessedTableManager get titleId {
    final $_column = $_itemColumn<String>('title_id')!;

    final manager = $$CatalogTitlesTableTableManager(
      $_db,
      $_db.catalogTitles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_titleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CatalogIdentitiesTableFilterComposer
    extends Composer<_$CueDatabase, $CatalogIdentitiesTable> {
  $$CatalogIdentitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerKind => $composableBuilder(
    column: $table.providerKind,
    builder: (column) => ColumnFilters(column),
  );

  $$CatalogTitlesTableFilterComposer get titleId {
    final $$CatalogTitlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.catalogTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogTitlesTableFilterComposer(
            $db: $db,
            $table: $db.catalogTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatalogIdentitiesTableOrderingComposer
    extends Composer<_$CueDatabase, $CatalogIdentitiesTable> {
  $$CatalogIdentitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerKind => $composableBuilder(
    column: $table.providerKind,
    builder: (column) => ColumnOrderings(column),
  );

  $$CatalogTitlesTableOrderingComposer get titleId {
    final $$CatalogTitlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.catalogTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogTitlesTableOrderingComposer(
            $db: $db,
            $table: $db.catalogTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatalogIdentitiesTableAnnotationComposer
    extends Composer<_$CueDatabase, $CatalogIdentitiesTable> {
  $$CatalogIdentitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerKind => $composableBuilder(
    column: $table.providerKind,
    builder: (column) => column,
  );

  $$CatalogTitlesTableAnnotationComposer get titleId {
    final $$CatalogTitlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.catalogTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogTitlesTableAnnotationComposer(
            $db: $db,
            $table: $db.catalogTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatalogIdentitiesTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $CatalogIdentitiesTable,
          CatalogIdentity,
          $$CatalogIdentitiesTableFilterComposer,
          $$CatalogIdentitiesTableOrderingComposer,
          $$CatalogIdentitiesTableAnnotationComposer,
          $$CatalogIdentitiesTableCreateCompanionBuilder,
          $$CatalogIdentitiesTableUpdateCompanionBuilder,
          (CatalogIdentity, $$CatalogIdentitiesTableReferences),
          CatalogIdentity,
          PrefetchHooks Function({bool titleId})
        > {
  $$CatalogIdentitiesTableTableManager(
    _$CueDatabase db,
    $CatalogIdentitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogIdentitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogIdentitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogIdentitiesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> titleId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> providerKind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogIdentitiesCompanion(
                titleId: titleId,
                provider: provider,
                providerId: providerId,
                providerKind: providerKind,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String titleId,
                required String provider,
                required String providerId,
                Value<String> providerKind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogIdentitiesCompanion.insert(
                titleId: titleId,
                provider: provider,
                providerId: providerId,
                providerKind: providerKind,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogIdentitiesTable, CatalogIdentity>(table),
                  $$CatalogIdentitiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({titleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (titleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.titleId,
                        referencedTable: $$CatalogIdentitiesTableReferences
                            ._titleIdTable(db),
                        referencedColumn: $$CatalogIdentitiesTableReferences
                            ._titleIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CatalogIdentitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $CatalogIdentitiesTable,
      CatalogIdentity,
      $$CatalogIdentitiesTableFilterComposer,
      $$CatalogIdentitiesTableOrderingComposer,
      $$CatalogIdentitiesTableAnnotationComposer,
      $$CatalogIdentitiesTableCreateCompanionBuilder,
      $$CatalogIdentitiesTableUpdateCompanionBuilder,
      (CatalogIdentity, $$CatalogIdentitiesTableReferences),
      CatalogIdentity,
      PrefetchHooks Function({bool titleId})
    >;
typedef $$CatalogPagesTableCreateCompanionBuilder =
    CatalogPagesCompanion Function({
      required String mediaKind,
      Value<String> mood,
      required int page,
      required bool hasNext,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$CatalogPagesTableUpdateCompanionBuilder =
    CatalogPagesCompanion Function({
      Value<String> mediaKind,
      Value<String> mood,
      Value<int> page,
      Value<bool> hasNext,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$CatalogPagesTableFilterComposer
    extends Composer<_$CueDatabase, $CatalogPagesTable> {
  $$CatalogPagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasNext => $composableBuilder(
    column: $table.hasNext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatalogPagesTableOrderingComposer
    extends Composer<_$CueDatabase, $CatalogPagesTable> {
  $$CatalogPagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasNext => $composableBuilder(
    column: $table.hasNext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogPagesTableAnnotationComposer
    extends Composer<_$CueDatabase, $CatalogPagesTable> {
  $$CatalogPagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mediaKind =>
      $composableBuilder(column: $table.mediaKind, builder: (column) => column);

  GeneratedColumn<String> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<int> get page =>
      $composableBuilder(column: $table.page, builder: (column) => column);

  GeneratedColumn<bool> get hasNext =>
      $composableBuilder(column: $table.hasNext, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CatalogPagesTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $CatalogPagesTable,
          CatalogPage,
          $$CatalogPagesTableFilterComposer,
          $$CatalogPagesTableOrderingComposer,
          $$CatalogPagesTableAnnotationComposer,
          $$CatalogPagesTableCreateCompanionBuilder,
          $$CatalogPagesTableUpdateCompanionBuilder,
          (
            CatalogPage,
            BaseReferences<_$CueDatabase, $CatalogPagesTable, CatalogPage>,
          ),
          CatalogPage,
          PrefetchHooks Function()
        > {
  $$CatalogPagesTableTableManager(_$CueDatabase db, $CatalogPagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogPagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogPagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogPagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mediaKind = const Value.absent(),
                Value<String> mood = const Value.absent(),
                Value<int> page = const Value.absent(),
                Value<bool> hasNext = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogPagesCompanion(
                mediaKind: mediaKind,
                mood: mood,
                page: page,
                hasNext: hasNext,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mediaKind,
                Value<String> mood = const Value.absent(),
                required int page,
                required bool hasNext,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatalogPagesCompanion.insert(
                mediaKind: mediaKind,
                mood: mood,
                page: page,
                hasNext: hasNext,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogPagesTable, CatalogPage>(table),
                  BaseReferences<
                    _$CueDatabase,
                    $CatalogPagesTable,
                    CatalogPage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatalogPagesTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $CatalogPagesTable,
      CatalogPage,
      $$CatalogPagesTableFilterComposer,
      $$CatalogPagesTableOrderingComposer,
      $$CatalogPagesTableAnnotationComposer,
      $$CatalogPagesTableCreateCompanionBuilder,
      $$CatalogPagesTableUpdateCompanionBuilder,
      (
        CatalogPage,
        BaseReferences<_$CueDatabase, $CatalogPagesTable, CatalogPage>,
      ),
      CatalogPage,
      PrefetchHooks Function()
    >;
typedef $$WatchProvidersTableCreateCompanionBuilder =
    WatchProvidersCompanion Function({
      required String titleId,
      required String region,
      required String providersJson,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$WatchProvidersTableUpdateCompanionBuilder =
    WatchProvidersCompanion Function({
      Value<String> titleId,
      Value<String> region,
      Value<String> providersJson,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

final class $$WatchProvidersTableReferences
    extends BaseReferences<_$CueDatabase, $WatchProvidersTable, WatchProvider> {
  $$WatchProvidersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CatalogTitlesTable _titleIdTable(_$CueDatabase db) => db.catalogTitles
      .createAlias('watch_providers__title_id__catalog_titles__id');

  $$CatalogTitlesTableProcessedTableManager get titleId {
    final $_column = $_itemColumn<String>('title_id')!;

    final manager = $$CatalogTitlesTableTableManager(
      $_db,
      $_db.catalogTitles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_titleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WatchProvidersTableFilterComposer
    extends Composer<_$CueDatabase, $WatchProvidersTable> {
  $$WatchProvidersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providersJson => $composableBuilder(
    column: $table.providersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CatalogTitlesTableFilterComposer get titleId {
    final $$CatalogTitlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.catalogTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogTitlesTableFilterComposer(
            $db: $db,
            $table: $db.catalogTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchProvidersTableOrderingComposer
    extends Composer<_$CueDatabase, $WatchProvidersTable> {
  $$WatchProvidersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providersJson => $composableBuilder(
    column: $table.providersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CatalogTitlesTableOrderingComposer get titleId {
    final $$CatalogTitlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.catalogTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogTitlesTableOrderingComposer(
            $db: $db,
            $table: $db.catalogTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchProvidersTableAnnotationComposer
    extends Composer<_$CueDatabase, $WatchProvidersTable> {
  $$WatchProvidersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get region =>
      $composableBuilder(column: $table.region, builder: (column) => column);

  GeneratedColumn<String> get providersJson => $composableBuilder(
    column: $table.providersJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  $$CatalogTitlesTableAnnotationComposer get titleId {
    final $$CatalogTitlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.catalogTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogTitlesTableAnnotationComposer(
            $db: $db,
            $table: $db.catalogTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchProvidersTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $WatchProvidersTable,
          WatchProvider,
          $$WatchProvidersTableFilterComposer,
          $$WatchProvidersTableOrderingComposer,
          $$WatchProvidersTableAnnotationComposer,
          $$WatchProvidersTableCreateCompanionBuilder,
          $$WatchProvidersTableUpdateCompanionBuilder,
          (WatchProvider, $$WatchProvidersTableReferences),
          WatchProvider,
          PrefetchHooks Function({bool titleId})
        > {
  $$WatchProvidersTableTableManager(
    _$CueDatabase db,
    $WatchProvidersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchProvidersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchProvidersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchProvidersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> titleId = const Value.absent(),
                Value<String> region = const Value.absent(),
                Value<String> providersJson = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchProvidersCompanion(
                titleId: titleId,
                region: region,
                providersJson: providersJson,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String titleId,
                required String region,
                required String providersJson,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => WatchProvidersCompanion.insert(
                titleId: titleId,
                region: region,
                providersJson: providersJson,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WatchProvidersTable, WatchProvider>(table),
                  $$WatchProvidersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({titleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (titleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.titleId,
                        referencedTable: $$WatchProvidersTableReferences
                            ._titleIdTable(db),
                        referencedColumn: $$WatchProvidersTableReferences
                            ._titleIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WatchProvidersTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $WatchProvidersTable,
      WatchProvider,
      $$WatchProvidersTableFilterComposer,
      $$WatchProvidersTableOrderingComposer,
      $$WatchProvidersTableAnnotationComposer,
      $$WatchProvidersTableCreateCompanionBuilder,
      $$WatchProvidersTableUpdateCompanionBuilder,
      (WatchProvider, $$WatchProvidersTableReferences),
      WatchProvider,
      PrefetchHooks Function({bool titleId})
    >;
typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  Value<String?> displayName,
  Value<String> region,
  Value<bool> showAdult,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<String?> displayName,
  Value<String> region,
  Value<bool> showAdult,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$ProfilesTableReferences
    extends BaseReferences<_$CueDatabase, $ProfilesTable, Profile> {
  $$ProfilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProfileSettingsTable, List<ProfileSetting>>
  _profileSettingsRefsTable(_$CueDatabase db) => MultiTypedResultKey.fromTable(
    db.profileSettings,
    aliasName: 'profiles__id__profile_settings__profile_id',
  );

  $$ProfileSettingsTableProcessedTableManager get profileSettingsRefs {
    final manager = $$ProfileSettingsTableTableManager(
      $_db,
      $_db.profileSettings,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _profileSettingsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$UserTitlesTable, List<UserTitle>>
  _userTitlesRefsTable(_$CueDatabase db) => MultiTypedResultKey.fromTable(
    db.userTitles,
    aliasName: 'profiles__id__user_titles__profile_id',
  );

  $$UserTitlesTableProcessedTableManager get userTitlesRefs {
    final manager = $$UserTitlesTableTableManager(
      $_db,
      $_db.userTitles,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_userTitlesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DecisionEventsTable, List<DecisionEvent>>
  _decisionEventsRefsTable(_$CueDatabase db) => MultiTypedResultKey.fromTable(
    db.decisionEvents,
    aliasName: 'profiles__id__decision_events__profile_id',
  );

  $$DecisionEventsTableProcessedTableManager get decisionEventsRefs {
    final manager = $$DecisionEventsTableTableManager(
      $_db,
      $_db.decisionEvents,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_decisionEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ShortlistTable, List<ShortlistEntry>>
  _shortlistRefsTable(_$CueDatabase db) => MultiTypedResultKey.fromTable(
    db.shortlist,
    aliasName: 'profiles__id__shortlist__profile_id',
  );

  $$ShortlistTableProcessedTableManager get shortlistRefs {
    final manager = $$ShortlistTableTableManager(
      $_db,
      $_db.shortlist,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_shortlistRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DeferralsTable, List<Deferral>>
  _deferralsRefsTable(_$CueDatabase db) => MultiTypedResultKey.fromTable(
    db.deferrals,
    aliasName: 'profiles__id__deferrals__profile_id',
  );

  $$DeferralsTableProcessedTableManager get deferralsRefs {
    final manager = $$DeferralsTableTableManager(
      $_db,
      $_db.deferrals,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_deferralsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExclusionsTable, List<Exclusion>>
  _exclusionsRefsTable(_$CueDatabase db) => MultiTypedResultKey.fromTable(
    db.exclusions,
    aliasName: 'profiles__id__exclusions__profile_id',
  );

  $$ExclusionsTableProcessedTableManager get exclusionsRefs {
    final manager = $$ExclusionsTableTableManager(
      $_db,
      $_db.exclusions,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_exclusionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TagWeightsTable, List<TagWeight>>
  _tagWeightsRefsTable(_$CueDatabase db) => MultiTypedResultKey.fromTable(
    db.tagWeights,
    aliasName: 'profiles__id__tag_weights__profile_id',
  );

  $$TagWeightsTableProcessedTableManager get tagWeightsRefs {
    final manager = $$TagWeightsTableTableManager(
      $_db,
      $_db.tagWeights,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tagWeightsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ImportBatchesTable, List<ImportBatche>>
  _importBatchesRefsTable(_$CueDatabase db) => MultiTypedResultKey.fromTable(
    db.importBatches,
    aliasName: 'profiles__id__import_batches__profile_id',
  );

  $$ImportBatchesTableProcessedTableManager get importBatchesRefs {
    final manager = $$ImportBatchesTableTableManager(
      $_db,
      $_db.importBatches,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_importBatchesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProfilesTableFilterComposer
    extends Composer<_$CueDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showAdult => $composableBuilder(
    column: $table.showAdult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> profileSettingsRefs(
    Expression<bool> Function($$ProfileSettingsTableFilterComposer f) f,
  ) {
    final $$ProfileSettingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.profileSettings,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfileSettingsTableFilterComposer(
            $db: $db,
            $table: $db.profileSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> userTitlesRefs(
    Expression<bool> Function($$UserTitlesTableFilterComposer f) f,
  ) {
    final $$UserTitlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userTitles,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserTitlesTableFilterComposer(
            $db: $db,
            $table: $db.userTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> decisionEventsRefs(
    Expression<bool> Function($$DecisionEventsTableFilterComposer f) f,
  ) {
    final $$DecisionEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.decisionEvents,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecisionEventsTableFilterComposer(
            $db: $db,
            $table: $db.decisionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> shortlistRefs(
    Expression<bool> Function($$ShortlistTableFilterComposer f) f,
  ) {
    final $$ShortlistTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shortlist,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShortlistTableFilterComposer(
            $db: $db,
            $table: $db.shortlist,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> deferralsRefs(
    Expression<bool> Function($$DeferralsTableFilterComposer f) f,
  ) {
    final $$DeferralsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deferrals,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeferralsTableFilterComposer(
            $db: $db,
            $table: $db.deferrals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> exclusionsRefs(
    Expression<bool> Function($$ExclusionsTableFilterComposer f) f,
  ) {
    final $$ExclusionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exclusions,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExclusionsTableFilterComposer(
            $db: $db,
            $table: $db.exclusions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tagWeightsRefs(
    Expression<bool> Function($$TagWeightsTableFilterComposer f) f,
  ) {
    final $$TagWeightsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tagWeights,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagWeightsTableFilterComposer(
            $db: $db,
            $table: $db.tagWeights,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> importBatchesRefs(
    Expression<bool> Function($$ImportBatchesTableFilterComposer f) f,
  ) {
    final $$ImportBatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importBatches,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportBatchesTableFilterComposer(
            $db: $db,
            $table: $db.importBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$CueDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showAdult => $composableBuilder(
    column: $table.showAdult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$CueDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get region =>
      $composableBuilder(column: $table.region, builder: (column) => column);

  GeneratedColumn<bool> get showAdult =>
      $composableBuilder(column: $table.showAdult, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> profileSettingsRefs<T extends Object>(
    Expression<T> Function($$ProfileSettingsTableAnnotationComposer a) f,
  ) {
    final $$ProfileSettingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.profileSettings,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfileSettingsTableAnnotationComposer(
            $db: $db,
            $table: $db.profileSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> userTitlesRefs<T extends Object>(
    Expression<T> Function($$UserTitlesTableAnnotationComposer a) f,
  ) {
    final $$UserTitlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userTitles,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserTitlesTableAnnotationComposer(
            $db: $db,
            $table: $db.userTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> decisionEventsRefs<T extends Object>(
    Expression<T> Function($$DecisionEventsTableAnnotationComposer a) f,
  ) {
    final $$DecisionEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.decisionEvents,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecisionEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.decisionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> shortlistRefs<T extends Object>(
    Expression<T> Function($$ShortlistTableAnnotationComposer a) f,
  ) {
    final $$ShortlistTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shortlist,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShortlistTableAnnotationComposer(
            $db: $db,
            $table: $db.shortlist,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> deferralsRefs<T extends Object>(
    Expression<T> Function($$DeferralsTableAnnotationComposer a) f,
  ) {
    final $$DeferralsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deferrals,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeferralsTableAnnotationComposer(
            $db: $db,
            $table: $db.deferrals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> exclusionsRefs<T extends Object>(
    Expression<T> Function($$ExclusionsTableAnnotationComposer a) f,
  ) {
    final $$ExclusionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exclusions,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExclusionsTableAnnotationComposer(
            $db: $db,
            $table: $db.exclusions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tagWeightsRefs<T extends Object>(
    Expression<T> Function($$TagWeightsTableAnnotationComposer a) f,
  ) {
    final $$TagWeightsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tagWeights,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagWeightsTableAnnotationComposer(
            $db: $db,
            $table: $db.tagWeights,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> importBatchesRefs<T extends Object>(
    Expression<T> Function($$ImportBatchesTableAnnotationComposer a) f,
  ) {
    final $$ImportBatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importBatches,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportBatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.importBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $ProfilesTable,
          Profile,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (Profile, $$ProfilesTableReferences),
          Profile,
          PrefetchHooks Function({
            bool profileSettingsRefs,
            bool userTitlesRefs,
            bool decisionEventsRefs,
            bool shortlistRefs,
            bool deferralsRefs,
            bool exclusionsRefs,
            bool tagWeightsRefs,
            bool importBatchesRefs,
          })
        > {
  $$ProfilesTableTableManager(_$CueDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String> region = const Value.absent(),
                Value<bool> showAdult = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                displayName: displayName,
                region: region,
                showAdult: showAdult,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> displayName = const Value.absent(),
                Value<String> region = const Value.absent(),
                Value<bool> showAdult = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                displayName: displayName,
                region: region,
                showAdult: showAdult,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfilesTable, Profile>(table),
                  $$ProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                profileSettingsRefs = false,
                userTitlesRefs = false,
                decisionEventsRefs = false,
                shortlistRefs = false,
                deferralsRefs = false,
                exclusionsRefs = false,
                tagWeightsRefs = false,
                importBatchesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (profileSettingsRefs) db.profileSettings,
                    if (userTitlesRefs) db.userTitles,
                    if (decisionEventsRefs) db.decisionEvents,
                    if (shortlistRefs) db.shortlist,
                    if (deferralsRefs) db.deferrals,
                    if (exclusionsRefs) db.exclusions,
                    if (tagWeightsRefs) db.tagWeights,
                    if (importBatchesRefs) db.importBatches,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (profileSettingsRefs)
                        await $_getPrefetchedDataByColumns<
                          Profile,
                          $ProfilesTable,
                          ProfileSetting,
                          $ProfileSettingsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._profileSettingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).profileSettingsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'profile_id',
                          typedResults: items,
                        ),
                      if (userTitlesRefs)
                        await $_getPrefetchedDataByColumns<
                          Profile,
                          $ProfilesTable,
                          UserTitle,
                          $UserTitlesTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._userTitlesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).userTitlesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'profile_id',
                          typedResults: items,
                        ),
                      if (decisionEventsRefs)
                        await $_getPrefetchedDataByColumns<
                          Profile,
                          $ProfilesTable,
                          DecisionEvent,
                          $DecisionEventsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._decisionEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).decisionEventsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'profile_id',
                          typedResults: items,
                        ),
                      if (shortlistRefs)
                        await $_getPrefetchedDataByColumns<
                          Profile,
                          $ProfilesTable,
                          ShortlistEntry,
                          $ShortlistTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._shortlistRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).shortlistRefs,
                          currentColumn: 'id',
                          referencedColumn: 'profile_id',
                          typedResults: items,
                        ),
                      if (deferralsRefs)
                        await $_getPrefetchedDataByColumns<
                          Profile,
                          $ProfilesTable,
                          Deferral,
                          $DeferralsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._deferralsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).deferralsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'profile_id',
                          typedResults: items,
                        ),
                      if (exclusionsRefs)
                        await $_getPrefetchedDataByColumns<
                          Profile,
                          $ProfilesTable,
                          Exclusion,
                          $ExclusionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._exclusionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).exclusionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'profile_id',
                          typedResults: items,
                        ),
                      if (tagWeightsRefs)
                        await $_getPrefetchedDataByColumns<
                          Profile,
                          $ProfilesTable,
                          TagWeight,
                          $TagWeightsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._tagWeightsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).tagWeightsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'profile_id',
                          typedResults: items,
                        ),
                      if (importBatchesRefs)
                        await $_getPrefetchedDataByColumns<
                          Profile,
                          $ProfilesTable,
                          ImportBatche,
                          $ImportBatchesTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._importBatchesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).importBatchesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'profile_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $ProfilesTable,
      Profile,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (Profile, $$ProfilesTableReferences),
      Profile,
      PrefetchHooks Function({
        bool profileSettingsRefs,
        bool userTitlesRefs,
        bool decisionEventsRefs,
        bool shortlistRefs,
        bool deferralsRefs,
        bool exclusionsRefs,
        bool tagWeightsRefs,
        bool importBatchesRefs,
      })
    >;
typedef $$ProfileSettingsTableCreateCompanionBuilder =
    ProfileSettingsCompanion Function({
      required String profileId,
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$ProfileSettingsTableUpdateCompanionBuilder =
    ProfileSettingsCompanion Function({
      Value<String> profileId,
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

final class $$ProfileSettingsTableReferences
    extends
        BaseReferences<_$CueDatabase, $ProfileSettingsTable, ProfileSetting> {
  $$ProfileSettingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProfilesTable _profileIdTable(_$CueDatabase db) =>
      db.profiles.createAlias('profile_settings__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProfileSettingsTableFilterComposer
    extends Composer<_$CueDatabase, $ProfileSettingsTable> {
  $$ProfileSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProfileSettingsTableOrderingComposer
    extends Composer<_$CueDatabase, $ProfileSettingsTable> {
  $$ProfileSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProfileSettingsTableAnnotationComposer
    extends Composer<_$CueDatabase, $ProfileSettingsTable> {
  $$ProfileSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProfileSettingsTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $ProfileSettingsTable,
          ProfileSetting,
          $$ProfileSettingsTableFilterComposer,
          $$ProfileSettingsTableOrderingComposer,
          $$ProfileSettingsTableAnnotationComposer,
          $$ProfileSettingsTableCreateCompanionBuilder,
          $$ProfileSettingsTableUpdateCompanionBuilder,
          (ProfileSetting, $$ProfileSettingsTableReferences),
          ProfileSetting,
          PrefetchHooks Function({bool profileId})
        > {
  $$ProfileSettingsTableTableManager(
    _$CueDatabase db,
    $ProfileSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfileSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfileSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfileSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfileSettingsCompanion(
                profileId: profileId,
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => ProfileSettingsCompanion.insert(
                profileId: profileId,
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfileSettingsTable, ProfileSetting>(table),
                  $$ProfileSettingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.profileId,
                        referencedTable: $$ProfileSettingsTableReferences
                            ._profileIdTable(db),
                        referencedColumn: $$ProfileSettingsTableReferences
                            ._profileIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProfileSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $ProfileSettingsTable,
      ProfileSetting,
      $$ProfileSettingsTableFilterComposer,
      $$ProfileSettingsTableOrderingComposer,
      $$ProfileSettingsTableAnnotationComposer,
      $$ProfileSettingsTableCreateCompanionBuilder,
      $$ProfileSettingsTableUpdateCompanionBuilder,
      (ProfileSetting, $$ProfileSettingsTableReferences),
      ProfileSetting,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$UserTitlesTableCreateCompanionBuilder = UserTitlesCompanion Function({
  required String profileId,
  required String titleId,
  Value<String> state,
  Value<String?> rating,
  Value<String?> rewatchMood,
  Value<String?> progressUnit,
  Value<double?> progressValue,
  Value<double?> latestKnown,
  Value<DateTime?> actualWatchedAt,
  required DateTime updatedAt,
  Value<String> source,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$UserTitlesTableUpdateCompanionBuilder = UserTitlesCompanion Function({
  Value<String> profileId,
  Value<String> titleId,
  Value<String> state,
  Value<String?> rating,
  Value<String?> rewatchMood,
  Value<String?> progressUnit,
  Value<double?> progressValue,
  Value<double?> latestKnown,
  Value<DateTime?> actualWatchedAt,
  Value<DateTime> updatedAt,
  Value<String> source,
  Value<String?> note,
  Value<int> rowid,
});

final class $$UserTitlesTableReferences
    extends BaseReferences<_$CueDatabase, $UserTitlesTable, UserTitle> {
  $$UserTitlesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$CueDatabase db) =>
      db.profiles.createAlias('user_titles__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$UserTitlesTableFilterComposer
    extends Composer<_$CueDatabase, $UserTitlesTable> {
  $$UserTitlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rewatchMood => $composableBuilder(
    column: $table.rewatchMood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get progressUnit => $composableBuilder(
    column: $table.progressUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progressValue => $composableBuilder(
    column: $table.progressValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latestKnown => $composableBuilder(
    column: $table.latestKnown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get actualWatchedAt => $composableBuilder(
    column: $table.actualWatchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserTitlesTableOrderingComposer
    extends Composer<_$CueDatabase, $UserTitlesTable> {
  $$UserTitlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rewatchMood => $composableBuilder(
    column: $table.rewatchMood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get progressUnit => $composableBuilder(
    column: $table.progressUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progressValue => $composableBuilder(
    column: $table.progressValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latestKnown => $composableBuilder(
    column: $table.latestKnown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get actualWatchedAt => $composableBuilder(
    column: $table.actualWatchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserTitlesTableAnnotationComposer
    extends Composer<_$CueDatabase, $UserTitlesTable> {
  $$UserTitlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get rewatchMood => $composableBuilder(
    column: $table.rewatchMood,
    builder: (column) => column,
  );

  GeneratedColumn<String> get progressUnit => $composableBuilder(
    column: $table.progressUnit,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progressValue => $composableBuilder(
    column: $table.progressValue,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latestKnown => $composableBuilder(
    column: $table.latestKnown,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get actualWatchedAt => $composableBuilder(
    column: $table.actualWatchedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserTitlesTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $UserTitlesTable,
          UserTitle,
          $$UserTitlesTableFilterComposer,
          $$UserTitlesTableOrderingComposer,
          $$UserTitlesTableAnnotationComposer,
          $$UserTitlesTableCreateCompanionBuilder,
          $$UserTitlesTableUpdateCompanionBuilder,
          (UserTitle, $$UserTitlesTableReferences),
          UserTitle,
          PrefetchHooks Function({bool profileId})
        > {
  $$UserTitlesTableTableManager(_$CueDatabase db, $UserTitlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserTitlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserTitlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserTitlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> titleId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> rating = const Value.absent(),
                Value<String?> rewatchMood = const Value.absent(),
                Value<String?> progressUnit = const Value.absent(),
                Value<double?> progressValue = const Value.absent(),
                Value<double?> latestKnown = const Value.absent(),
                Value<DateTime?> actualWatchedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserTitlesCompanion(
                profileId: profileId,
                titleId: titleId,
                state: state,
                rating: rating,
                rewatchMood: rewatchMood,
                progressUnit: progressUnit,
                progressValue: progressValue,
                latestKnown: latestKnown,
                actualWatchedAt: actualWatchedAt,
                updatedAt: updatedAt,
                source: source,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String titleId,
                Value<String> state = const Value.absent(),
                Value<String?> rating = const Value.absent(),
                Value<String?> rewatchMood = const Value.absent(),
                Value<String?> progressUnit = const Value.absent(),
                Value<double?> progressValue = const Value.absent(),
                Value<double?> latestKnown = const Value.absent(),
                Value<DateTime?> actualWatchedAt = const Value.absent(),
                required DateTime updatedAt,
                Value<String> source = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserTitlesCompanion.insert(
                profileId: profileId,
                titleId: titleId,
                state: state,
                rating: rating,
                rewatchMood: rewatchMood,
                progressUnit: progressUnit,
                progressValue: progressValue,
                latestKnown: latestKnown,
                actualWatchedAt: actualWatchedAt,
                updatedAt: updatedAt,
                source: source,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserTitlesTable, UserTitle>(table),
                  $$UserTitlesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.profileId,
                        referencedTable: $$UserTitlesTableReferences
                            ._profileIdTable(db),
                        referencedColumn: $$UserTitlesTableReferences
                            ._profileIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$UserTitlesTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $UserTitlesTable,
      UserTitle,
      $$UserTitlesTableFilterComposer,
      $$UserTitlesTableOrderingComposer,
      $$UserTitlesTableAnnotationComposer,
      $$UserTitlesTableCreateCompanionBuilder,
      $$UserTitlesTableUpdateCompanionBuilder,
      (UserTitle, $$UserTitlesTableReferences),
      UserTitle,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$DecisionEventsTableCreateCompanionBuilder =
    DecisionEventsCompanion Function({
      required String id,
      required String profileId,
      required String titleId,
      required String action,
      Value<String> context,
      Value<String?> mood,
      required DateTime createdAt,
      Value<String?> reversesEventId,
      Value<String?> beforeJson,
      Value<int> rowid,
    });
typedef $$DecisionEventsTableUpdateCompanionBuilder =
    DecisionEventsCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> titleId,
      Value<String> action,
      Value<String> context,
      Value<String?> mood,
      Value<DateTime> createdAt,
      Value<String?> reversesEventId,
      Value<String?> beforeJson,
      Value<int> rowid,
    });

final class $$DecisionEventsTableReferences
    extends BaseReferences<_$CueDatabase, $DecisionEventsTable, DecisionEvent> {
  $$DecisionEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProfilesTable _profileIdTable(_$CueDatabase db) =>
      db.profiles.createAlias('decision_events__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DecisionEventsTableFilterComposer
    extends Composer<_$CueDatabase, $DecisionEventsTable> {
  $$DecisionEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reversesEventId => $composableBuilder(
    column: $table.reversesEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DecisionEventsTableOrderingComposer
    extends Composer<_$CueDatabase, $DecisionEventsTable> {
  $$DecisionEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reversesEventId => $composableBuilder(
    column: $table.reversesEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DecisionEventsTableAnnotationComposer
    extends Composer<_$CueDatabase, $DecisionEventsTable> {
  $$DecisionEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get context =>
      $composableBuilder(column: $table.context, builder: (column) => column);

  GeneratedColumn<String> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get reversesEventId => $composableBuilder(
    column: $table.reversesEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => column,
  );

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DecisionEventsTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $DecisionEventsTable,
          DecisionEvent,
          $$DecisionEventsTableFilterComposer,
          $$DecisionEventsTableOrderingComposer,
          $$DecisionEventsTableAnnotationComposer,
          $$DecisionEventsTableCreateCompanionBuilder,
          $$DecisionEventsTableUpdateCompanionBuilder,
          (DecisionEvent, $$DecisionEventsTableReferences),
          DecisionEvent,
          PrefetchHooks Function({bool profileId})
        > {
  $$DecisionEventsTableTableManager(
    _$CueDatabase db,
    $DecisionEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DecisionEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DecisionEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DecisionEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> titleId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> context = const Value.absent(),
                Value<String?> mood = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> reversesEventId = const Value.absent(),
                Value<String?> beforeJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DecisionEventsCompanion(
                id: id,
                profileId: profileId,
                titleId: titleId,
                action: action,
                context: context,
                mood: mood,
                createdAt: createdAt,
                reversesEventId: reversesEventId,
                beforeJson: beforeJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String titleId,
                required String action,
                Value<String> context = const Value.absent(),
                Value<String?> mood = const Value.absent(),
                required DateTime createdAt,
                Value<String?> reversesEventId = const Value.absent(),
                Value<String?> beforeJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DecisionEventsCompanion.insert(
                id: id,
                profileId: profileId,
                titleId: titleId,
                action: action,
                context: context,
                mood: mood,
                createdAt: createdAt,
                reversesEventId: reversesEventId,
                beforeJson: beforeJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DecisionEventsTable, DecisionEvent>(table),
                  $$DecisionEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.profileId,
                        referencedTable: $$DecisionEventsTableReferences
                            ._profileIdTable(db),
                        referencedColumn: $$DecisionEventsTableReferences
                            ._profileIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DecisionEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $DecisionEventsTable,
      DecisionEvent,
      $$DecisionEventsTableFilterComposer,
      $$DecisionEventsTableOrderingComposer,
      $$DecisionEventsTableAnnotationComposer,
      $$DecisionEventsTableCreateCompanionBuilder,
      $$DecisionEventsTableUpdateCompanionBuilder,
      (DecisionEvent, $$DecisionEventsTableReferences),
      DecisionEvent,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$ShortlistTableCreateCompanionBuilder = ShortlistCompanion Function({
  required String profileId,
  required String titleId,
  required DateTime addedAt,
  Value<int> rowid,
});
typedef $$ShortlistTableUpdateCompanionBuilder = ShortlistCompanion Function({
  Value<String> profileId,
  Value<String> titleId,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

final class $$ShortlistTableReferences
    extends BaseReferences<_$CueDatabase, $ShortlistTable, ShortlistEntry> {
  $$ShortlistTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$CueDatabase db) =>
      db.profiles.createAlias('shortlist__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShortlistTableFilterComposer
    extends Composer<_$CueDatabase, $ShortlistTable> {
  $$ShortlistTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShortlistTableOrderingComposer
    extends Composer<_$CueDatabase, $ShortlistTable> {
  $$ShortlistTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShortlistTableAnnotationComposer
    extends Composer<_$CueDatabase, $ShortlistTable> {
  $$ShortlistTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShortlistTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $ShortlistTable,
          ShortlistEntry,
          $$ShortlistTableFilterComposer,
          $$ShortlistTableOrderingComposer,
          $$ShortlistTableAnnotationComposer,
          $$ShortlistTableCreateCompanionBuilder,
          $$ShortlistTableUpdateCompanionBuilder,
          (ShortlistEntry, $$ShortlistTableReferences),
          ShortlistEntry,
          PrefetchHooks Function({bool profileId})
        > {
  $$ShortlistTableTableManager(_$CueDatabase db, $ShortlistTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShortlistTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShortlistTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShortlistTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> titleId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShortlistCompanion(
                profileId: profileId,
                titleId: titleId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String titleId,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => ShortlistCompanion.insert(
                profileId: profileId,
                titleId: titleId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShortlistTable, ShortlistEntry>(table),
                  $$ShortlistTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.profileId,
                        referencedTable: $$ShortlistTableReferences
                            ._profileIdTable(db),
                        referencedColumn: $$ShortlistTableReferences
                            ._profileIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShortlistTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $ShortlistTable,
      ShortlistEntry,
      $$ShortlistTableFilterComposer,
      $$ShortlistTableOrderingComposer,
      $$ShortlistTableAnnotationComposer,
      $$ShortlistTableCreateCompanionBuilder,
      $$ShortlistTableUpdateCompanionBuilder,
      (ShortlistEntry, $$ShortlistTableReferences),
      ShortlistEntry,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$DeferralsTableCreateCompanionBuilder = DeferralsCompanion Function({
  required String profileId,
  required String titleId,
  required DateTime eligibleAfter,
  Value<int> rowid,
});
typedef $$DeferralsTableUpdateCompanionBuilder = DeferralsCompanion Function({
  Value<String> profileId,
  Value<String> titleId,
  Value<DateTime> eligibleAfter,
  Value<int> rowid,
});

final class $$DeferralsTableReferences
    extends BaseReferences<_$CueDatabase, $DeferralsTable, Deferral> {
  $$DeferralsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$CueDatabase db) =>
      db.profiles.createAlias('deferrals__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DeferralsTableFilterComposer
    extends Composer<_$CueDatabase, $DeferralsTable> {
  $$DeferralsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eligibleAfter => $composableBuilder(
    column: $table.eligibleAfter,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeferralsTableOrderingComposer
    extends Composer<_$CueDatabase, $DeferralsTable> {
  $$DeferralsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eligibleAfter => $composableBuilder(
    column: $table.eligibleAfter,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeferralsTableAnnotationComposer
    extends Composer<_$CueDatabase, $DeferralsTable> {
  $$DeferralsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<DateTime> get eligibleAfter => $composableBuilder(
    column: $table.eligibleAfter,
    builder: (column) => column,
  );

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeferralsTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $DeferralsTable,
          Deferral,
          $$DeferralsTableFilterComposer,
          $$DeferralsTableOrderingComposer,
          $$DeferralsTableAnnotationComposer,
          $$DeferralsTableCreateCompanionBuilder,
          $$DeferralsTableUpdateCompanionBuilder,
          (Deferral, $$DeferralsTableReferences),
          Deferral,
          PrefetchHooks Function({bool profileId})
        > {
  $$DeferralsTableTableManager(_$CueDatabase db, $DeferralsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeferralsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeferralsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeferralsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> titleId = const Value.absent(),
                Value<DateTime> eligibleAfter = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeferralsCompanion(
                profileId: profileId,
                titleId: titleId,
                eligibleAfter: eligibleAfter,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String titleId,
                required DateTime eligibleAfter,
                Value<int> rowid = const Value.absent(),
              }) => DeferralsCompanion.insert(
                profileId: profileId,
                titleId: titleId,
                eligibleAfter: eligibleAfter,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DeferralsTable, Deferral>(table),
                  $$DeferralsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.profileId,
                        referencedTable: $$DeferralsTableReferences
                            ._profileIdTable(db),
                        referencedColumn: $$DeferralsTableReferences
                            ._profileIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DeferralsTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $DeferralsTable,
      Deferral,
      $$DeferralsTableFilterComposer,
      $$DeferralsTableOrderingComposer,
      $$DeferralsTableAnnotationComposer,
      $$DeferralsTableCreateCompanionBuilder,
      $$DeferralsTableUpdateCompanionBuilder,
      (Deferral, $$DeferralsTableReferences),
      Deferral,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$ExclusionsTableCreateCompanionBuilder = ExclusionsCompanion Function({
  required String profileId,
  required String titleId,
  Value<bool> active,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$ExclusionsTableUpdateCompanionBuilder = ExclusionsCompanion Function({
  Value<String> profileId,
  Value<String> titleId,
  Value<bool> active,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$ExclusionsTableReferences
    extends BaseReferences<_$CueDatabase, $ExclusionsTable, Exclusion> {
  $$ExclusionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$CueDatabase db) =>
      db.profiles.createAlias('exclusions__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExclusionsTableFilterComposer
    extends Composer<_$CueDatabase, $ExclusionsTable> {
  $$ExclusionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExclusionsTableOrderingComposer
    extends Composer<_$CueDatabase, $ExclusionsTable> {
  $$ExclusionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExclusionsTableAnnotationComposer
    extends Composer<_$CueDatabase, $ExclusionsTable> {
  $$ExclusionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExclusionsTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $ExclusionsTable,
          Exclusion,
          $$ExclusionsTableFilterComposer,
          $$ExclusionsTableOrderingComposer,
          $$ExclusionsTableAnnotationComposer,
          $$ExclusionsTableCreateCompanionBuilder,
          $$ExclusionsTableUpdateCompanionBuilder,
          (Exclusion, $$ExclusionsTableReferences),
          Exclusion,
          PrefetchHooks Function({bool profileId})
        > {
  $$ExclusionsTableTableManager(_$CueDatabase db, $ExclusionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExclusionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExclusionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExclusionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> titleId = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExclusionsCompanion(
                profileId: profileId,
                titleId: titleId,
                active: active,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String titleId,
                Value<bool> active = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ExclusionsCompanion.insert(
                profileId: profileId,
                titleId: titleId,
                active: active,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExclusionsTable, Exclusion>(table),
                  $$ExclusionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.profileId,
                        referencedTable: $$ExclusionsTableReferences
                            ._profileIdTable(db),
                        referencedColumn: $$ExclusionsTableReferences
                            ._profileIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ExclusionsTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $ExclusionsTable,
      Exclusion,
      $$ExclusionsTableFilterComposer,
      $$ExclusionsTableOrderingComposer,
      $$ExclusionsTableAnnotationComposer,
      $$ExclusionsTableCreateCompanionBuilder,
      $$ExclusionsTableUpdateCompanionBuilder,
      (Exclusion, $$ExclusionsTableReferences),
      Exclusion,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$TagWeightsTableCreateCompanionBuilder = TagWeightsCompanion Function({
  required String profileId,
  required String tag,
  required double weight,
  required int evidenceCount,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$TagWeightsTableUpdateCompanionBuilder = TagWeightsCompanion Function({
  Value<String> profileId,
  Value<String> tag,
  Value<double> weight,
  Value<int> evidenceCount,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$TagWeightsTableReferences
    extends BaseReferences<_$CueDatabase, $TagWeightsTable, TagWeight> {
  $$TagWeightsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$CueDatabase db) =>
      db.profiles.createAlias('tag_weights__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TagWeightsTableFilterComposer
    extends Composer<_$CueDatabase, $TagWeightsTable> {
  $$TagWeightsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get evidenceCount => $composableBuilder(
    column: $table.evidenceCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TagWeightsTableOrderingComposer
    extends Composer<_$CueDatabase, $TagWeightsTable> {
  $$TagWeightsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get evidenceCount => $composableBuilder(
    column: $table.evidenceCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TagWeightsTableAnnotationComposer
    extends Composer<_$CueDatabase, $TagWeightsTable> {
  $$TagWeightsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<int> get evidenceCount => $composableBuilder(
    column: $table.evidenceCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TagWeightsTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $TagWeightsTable,
          TagWeight,
          $$TagWeightsTableFilterComposer,
          $$TagWeightsTableOrderingComposer,
          $$TagWeightsTableAnnotationComposer,
          $$TagWeightsTableCreateCompanionBuilder,
          $$TagWeightsTableUpdateCompanionBuilder,
          (TagWeight, $$TagWeightsTableReferences),
          TagWeight,
          PrefetchHooks Function({bool profileId})
        > {
  $$TagWeightsTableTableManager(_$CueDatabase db, $TagWeightsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagWeightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagWeightsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagWeightsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<int> evidenceCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagWeightsCompanion(
                profileId: profileId,
                tag: tag,
                weight: weight,
                evidenceCount: evidenceCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String tag,
                required double weight,
                required int evidenceCount,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TagWeightsCompanion.insert(
                profileId: profileId,
                tag: tag,
                weight: weight,
                evidenceCount: evidenceCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagWeightsTable, TagWeight>(table),
                  $$TagWeightsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.profileId,
                        referencedTable: $$TagWeightsTableReferences
                            ._profileIdTable(db),
                        referencedColumn: $$TagWeightsTableReferences
                            ._profileIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TagWeightsTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $TagWeightsTable,
      TagWeight,
      $$TagWeightsTableFilterComposer,
      $$TagWeightsTableOrderingComposer,
      $$TagWeightsTableAnnotationComposer,
      $$TagWeightsTableCreateCompanionBuilder,
      $$TagWeightsTableUpdateCompanionBuilder,
      (TagWeight, $$TagWeightsTableReferences),
      TagWeight,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$ImportBatchesTableCreateCompanionBuilder =
    ImportBatchesCompanion Function({
      required String id,
      required String profileId,
      required String sourceType,
      required String adapterVersion,
      Value<String?> fileFingerprint,
      required String state,
      Value<String> countsJson,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ImportBatchesTableUpdateCompanionBuilder =
    ImportBatchesCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> sourceType,
      Value<String> adapterVersion,
      Value<String?> fileFingerprint,
      Value<String> state,
      Value<String> countsJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ImportBatchesTableReferences
    extends BaseReferences<_$CueDatabase, $ImportBatchesTable, ImportBatche> {
  $$ImportBatchesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProfilesTable _profileIdTable(_$CueDatabase db) =>
      db.profiles.createAlias('import_batches__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SourceObservationsTable, List<SourceObservation>>
  _sourceObservationsRefsTable(_$CueDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.sourceObservations,
        aliasName: 'import_batches__id__source_observations__batch_id',
      );

  $$SourceObservationsTableProcessedTableManager get sourceObservationsRefs {
    final manager = $$SourceObservationsTableTableManager(
      $_db,
      $_db.sourceObservations,
    ).filter((f) => f.batchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _sourceObservationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ImportChangesTable, List<ImportChange>>
  _importChangesRefsTable(_$CueDatabase db) => MultiTypedResultKey.fromTable(
    db.importChanges,
    aliasName: 'import_batches__id__import_changes__batch_id',
  );

  $$ImportChangesTableProcessedTableManager get importChangesRefs {
    final manager = $$ImportChangesTableTableManager(
      $_db,
      $_db.importChanges,
    ).filter((f) => f.batchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_importChangesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ImportBatchesTableFilterComposer
    extends Composer<_$CueDatabase, $ImportBatchesTable> {
  $$ImportBatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get adapterVersion => $composableBuilder(
    column: $table.adapterVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileFingerprint => $composableBuilder(
    column: $table.fileFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get countsJson => $composableBuilder(
    column: $table.countsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> sourceObservationsRefs(
    Expression<bool> Function($$SourceObservationsTableFilterComposer f) f,
  ) {
    final $$SourceObservationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sourceObservations,
      getReferencedColumn: (t) => t.batchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceObservationsTableFilterComposer(
            $db: $db,
            $table: $db.sourceObservations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> importChangesRefs(
    Expression<bool> Function($$ImportChangesTableFilterComposer f) f,
  ) {
    final $$ImportChangesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importChanges,
      getReferencedColumn: (t) => t.batchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportChangesTableFilterComposer(
            $db: $db,
            $table: $db.importChanges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ImportBatchesTableOrderingComposer
    extends Composer<_$CueDatabase, $ImportBatchesTable> {
  $$ImportBatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get adapterVersion => $composableBuilder(
    column: $table.adapterVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileFingerprint => $composableBuilder(
    column: $table.fileFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get countsJson => $composableBuilder(
    column: $table.countsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportBatchesTableAnnotationComposer
    extends Composer<_$CueDatabase, $ImportBatchesTable> {
  $$ImportBatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get adapterVersion => $composableBuilder(
    column: $table.adapterVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileFingerprint => $composableBuilder(
    column: $table.fileFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get countsJson => $composableBuilder(
    column: $table.countsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> sourceObservationsRefs<T extends Object>(
    Expression<T> Function($$SourceObservationsTableAnnotationComposer a) f,
  ) {
    final $$SourceObservationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.sourceObservations,
          getReferencedColumn: (t) => t.batchId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SourceObservationsTableAnnotationComposer(
                $db: $db,
                $table: $db.sourceObservations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> importChangesRefs<T extends Object>(
    Expression<T> Function($$ImportChangesTableAnnotationComposer a) f,
  ) {
    final $$ImportChangesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importChanges,
      getReferencedColumn: (t) => t.batchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportChangesTableAnnotationComposer(
            $db: $db,
            $table: $db.importChanges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ImportBatchesTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $ImportBatchesTable,
          ImportBatche,
          $$ImportBatchesTableFilterComposer,
          $$ImportBatchesTableOrderingComposer,
          $$ImportBatchesTableAnnotationComposer,
          $$ImportBatchesTableCreateCompanionBuilder,
          $$ImportBatchesTableUpdateCompanionBuilder,
          (ImportBatche, $$ImportBatchesTableReferences),
          ImportBatche,
          PrefetchHooks Function({
            bool profileId,
            bool sourceObservationsRefs,
            bool importChangesRefs,
          })
        > {
  $$ImportBatchesTableTableManager(_$CueDatabase db, $ImportBatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportBatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportBatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportBatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> adapterVersion = const Value.absent(),
                Value<String?> fileFingerprint = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String> countsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportBatchesCompanion(
                id: id,
                profileId: profileId,
                sourceType: sourceType,
                adapterVersion: adapterVersion,
                fileFingerprint: fileFingerprint,
                state: state,
                countsJson: countsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String sourceType,
                required String adapterVersion,
                Value<String?> fileFingerprint = const Value.absent(),
                required String state,
                Value<String> countsJson = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ImportBatchesCompanion.insert(
                id: id,
                profileId: profileId,
                sourceType: sourceType,
                adapterVersion: adapterVersion,
                fileFingerprint: fileFingerprint,
                state: state,
                countsJson: countsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImportBatchesTable, ImportBatche>(table),
                  $$ImportBatchesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                profileId = false,
                sourceObservationsRefs = false,
                importChangesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sourceObservationsRefs) db.sourceObservations,
                    if (importChangesRefs) db.importChanges,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (profileId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.profileId,
                            referencedTable: $$ImportBatchesTableReferences
                                ._profileIdTable(db),
                            referencedColumn: $$ImportBatchesTableReferences
                                ._profileIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sourceObservationsRefs)
                        await $_getPrefetchedDataByColumns<
                          ImportBatche,
                          $ImportBatchesTable,
                          SourceObservation,
                          $SourceObservationsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ImportBatchesTableReferences
                              ._sourceObservationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ImportBatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).sourceObservationsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'batch_id',
                          typedResults: items,
                        ),
                      if (importChangesRefs)
                        await $_getPrefetchedDataByColumns<
                          ImportBatche,
                          $ImportBatchesTable,
                          ImportChange,
                          $ImportChangesTable
                        >(
                          currentTable: table,
                          referencedTable: $$ImportBatchesTableReferences
                              ._importChangesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ImportBatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).importChangesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'batch_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ImportBatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $ImportBatchesTable,
      ImportBatche,
      $$ImportBatchesTableFilterComposer,
      $$ImportBatchesTableOrderingComposer,
      $$ImportBatchesTableAnnotationComposer,
      $$ImportBatchesTableCreateCompanionBuilder,
      $$ImportBatchesTableUpdateCompanionBuilder,
      (ImportBatche, $$ImportBatchesTableReferences),
      ImportBatche,
      PrefetchHooks Function({
        bool profileId,
        bool sourceObservationsRefs,
        bool importChangesRefs,
      })
    >;
typedef $$SourceObservationsTableCreateCompanionBuilder =
    SourceObservationsCompanion Function({
      required String id,
      required String batchId,
      required String sourceEntryKey,
      required String rawTitle,
      Value<String?> titleId,
      required String matchClass,
      required String status,
      Value<String?> ratingOriginal,
      Value<String?> ratingScale,
      Value<double?> progress,
      Value<DateTime?> activityDate,
      Value<bool> included,
      Value<int> rowid,
    });
typedef $$SourceObservationsTableUpdateCompanionBuilder =
    SourceObservationsCompanion Function({
      Value<String> id,
      Value<String> batchId,
      Value<String> sourceEntryKey,
      Value<String> rawTitle,
      Value<String?> titleId,
      Value<String> matchClass,
      Value<String> status,
      Value<String?> ratingOriginal,
      Value<String?> ratingScale,
      Value<double?> progress,
      Value<DateTime?> activityDate,
      Value<bool> included,
      Value<int> rowid,
    });

final class $$SourceObservationsTableReferences
    extends
        BaseReferences<
          _$CueDatabase,
          $SourceObservationsTable,
          SourceObservation
        > {
  $$SourceObservationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ImportBatchesTable _batchIdTable(_$CueDatabase db) => db.importBatches
      .createAlias('source_observations__batch_id__import_batches__id');

  $$ImportBatchesTableProcessedTableManager get batchId {
    final $_column = $_itemColumn<String>('batch_id')!;

    final manager = $$ImportBatchesTableTableManager(
      $_db,
      $_db.importBatches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_batchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SourceObservationsTableFilterComposer
    extends Composer<_$CueDatabase, $SourceObservationsTable> {
  $$SourceObservationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceEntryKey => $composableBuilder(
    column: $table.sourceEntryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawTitle => $composableBuilder(
    column: $table.rawTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchClass => $composableBuilder(
    column: $table.matchClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ratingOriginal => $composableBuilder(
    column: $table.ratingOriginal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ratingScale => $composableBuilder(
    column: $table.ratingScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get activityDate => $composableBuilder(
    column: $table.activityDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get included => $composableBuilder(
    column: $table.included,
    builder: (column) => ColumnFilters(column),
  );

  $$ImportBatchesTableFilterComposer get batchId {
    final $$ImportBatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batchId,
      referencedTable: $db.importBatches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportBatchesTableFilterComposer(
            $db: $db,
            $table: $db.importBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SourceObservationsTableOrderingComposer
    extends Composer<_$CueDatabase, $SourceObservationsTable> {
  $$SourceObservationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceEntryKey => $composableBuilder(
    column: $table.sourceEntryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawTitle => $composableBuilder(
    column: $table.rawTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchClass => $composableBuilder(
    column: $table.matchClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ratingOriginal => $composableBuilder(
    column: $table.ratingOriginal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ratingScale => $composableBuilder(
    column: $table.ratingScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get activityDate => $composableBuilder(
    column: $table.activityDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get included => $composableBuilder(
    column: $table.included,
    builder: (column) => ColumnOrderings(column),
  );

  $$ImportBatchesTableOrderingComposer get batchId {
    final $$ImportBatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batchId,
      referencedTable: $db.importBatches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportBatchesTableOrderingComposer(
            $db: $db,
            $table: $db.importBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SourceObservationsTableAnnotationComposer
    extends Composer<_$CueDatabase, $SourceObservationsTable> {
  $$SourceObservationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceEntryKey => $composableBuilder(
    column: $table.sourceEntryKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawTitle =>
      $composableBuilder(column: $table.rawTitle, builder: (column) => column);

  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<String> get matchClass => $composableBuilder(
    column: $table.matchClass,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get ratingOriginal => $composableBuilder(
    column: $table.ratingOriginal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ratingScale => $composableBuilder(
    column: $table.ratingScale,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<DateTime> get activityDate => $composableBuilder(
    column: $table.activityDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get included =>
      $composableBuilder(column: $table.included, builder: (column) => column);

  $$ImportBatchesTableAnnotationComposer get batchId {
    final $$ImportBatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batchId,
      referencedTable: $db.importBatches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportBatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.importBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SourceObservationsTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $SourceObservationsTable,
          SourceObservation,
          $$SourceObservationsTableFilterComposer,
          $$SourceObservationsTableOrderingComposer,
          $$SourceObservationsTableAnnotationComposer,
          $$SourceObservationsTableCreateCompanionBuilder,
          $$SourceObservationsTableUpdateCompanionBuilder,
          (SourceObservation, $$SourceObservationsTableReferences),
          SourceObservation,
          PrefetchHooks Function({bool batchId})
        > {
  $$SourceObservationsTableTableManager(
    _$CueDatabase db,
    $SourceObservationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceObservationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourceObservationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourceObservationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> batchId = const Value.absent(),
                Value<String> sourceEntryKey = const Value.absent(),
                Value<String> rawTitle = const Value.absent(),
                Value<String?> titleId = const Value.absent(),
                Value<String> matchClass = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> ratingOriginal = const Value.absent(),
                Value<String?> ratingScale = const Value.absent(),
                Value<double?> progress = const Value.absent(),
                Value<DateTime?> activityDate = const Value.absent(),
                Value<bool> included = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourceObservationsCompanion(
                id: id,
                batchId: batchId,
                sourceEntryKey: sourceEntryKey,
                rawTitle: rawTitle,
                titleId: titleId,
                matchClass: matchClass,
                status: status,
                ratingOriginal: ratingOriginal,
                ratingScale: ratingScale,
                progress: progress,
                activityDate: activityDate,
                included: included,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String batchId,
                required String sourceEntryKey,
                required String rawTitle,
                Value<String?> titleId = const Value.absent(),
                required String matchClass,
                required String status,
                Value<String?> ratingOriginal = const Value.absent(),
                Value<String?> ratingScale = const Value.absent(),
                Value<double?> progress = const Value.absent(),
                Value<DateTime?> activityDate = const Value.absent(),
                Value<bool> included = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourceObservationsCompanion.insert(
                id: id,
                batchId: batchId,
                sourceEntryKey: sourceEntryKey,
                rawTitle: rawTitle,
                titleId: titleId,
                matchClass: matchClass,
                status: status,
                ratingOriginal: ratingOriginal,
                ratingScale: ratingScale,
                progress: progress,
                activityDate: activityDate,
                included: included,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SourceObservationsTable, SourceObservation>(
                    table,
                  ),
                  $$SourceObservationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({batchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (batchId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.batchId,
                        referencedTable: $$SourceObservationsTableReferences
                            ._batchIdTable(db),
                        referencedColumn: $$SourceObservationsTableReferences
                            ._batchIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SourceObservationsTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $SourceObservationsTable,
      SourceObservation,
      $$SourceObservationsTableFilterComposer,
      $$SourceObservationsTableOrderingComposer,
      $$SourceObservationsTableAnnotationComposer,
      $$SourceObservationsTableCreateCompanionBuilder,
      $$SourceObservationsTableUpdateCompanionBuilder,
      (SourceObservation, $$SourceObservationsTableReferences),
      SourceObservation,
      PrefetchHooks Function({bool batchId})
    >;
typedef $$ImportChangesTableCreateCompanionBuilder =
    ImportChangesCompanion Function({
      Value<int> seq,
      required String batchId,
      required String tableName_,
      required String rowKey,
      Value<String?> beforeJson,
      Value<String?> afterJson,
    });
typedef $$ImportChangesTableUpdateCompanionBuilder =
    ImportChangesCompanion Function({
      Value<int> seq,
      Value<String> batchId,
      Value<String> tableName_,
      Value<String> rowKey,
      Value<String?> beforeJson,
      Value<String?> afterJson,
    });

final class $$ImportChangesTableReferences
    extends BaseReferences<_$CueDatabase, $ImportChangesTable, ImportChange> {
  $$ImportChangesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ImportBatchesTable _batchIdTable(_$CueDatabase db) => db.importBatches
      .createAlias('import_changes__batch_id__import_batches__id');

  $$ImportBatchesTableProcessedTableManager get batchId {
    final $_column = $_itemColumn<String>('batch_id')!;

    final manager = $$ImportBatchesTableTableManager(
      $_db,
      $_db.importBatches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_batchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ImportChangesTableFilterComposer
    extends Composer<_$CueDatabase, $ImportChangesTable> {
  $$ImportChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tableName_ => $composableBuilder(
    column: $table.tableName_,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowKey => $composableBuilder(
    column: $table.rowKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afterJson => $composableBuilder(
    column: $table.afterJson,
    builder: (column) => ColumnFilters(column),
  );

  $$ImportBatchesTableFilterComposer get batchId {
    final $$ImportBatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batchId,
      referencedTable: $db.importBatches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportBatchesTableFilterComposer(
            $db: $db,
            $table: $db.importBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportChangesTableOrderingComposer
    extends Composer<_$CueDatabase, $ImportChangesTable> {
  $$ImportChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tableName_ => $composableBuilder(
    column: $table.tableName_,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowKey => $composableBuilder(
    column: $table.rowKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afterJson => $composableBuilder(
    column: $table.afterJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$ImportBatchesTableOrderingComposer get batchId {
    final $$ImportBatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batchId,
      referencedTable: $db.importBatches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportBatchesTableOrderingComposer(
            $db: $db,
            $table: $db.importBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportChangesTableAnnotationComposer
    extends Composer<_$CueDatabase, $ImportChangesTable> {
  $$ImportChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get tableName_ => $composableBuilder(
    column: $table.tableName_,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rowKey =>
      $composableBuilder(column: $table.rowKey, builder: (column) => column);

  GeneratedColumn<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afterJson =>
      $composableBuilder(column: $table.afterJson, builder: (column) => column);

  $$ImportBatchesTableAnnotationComposer get batchId {
    final $$ImportBatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batchId,
      referencedTable: $db.importBatches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportBatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.importBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportChangesTableTableManager
    extends
        RootTableManager<
          _$CueDatabase,
          $ImportChangesTable,
          ImportChange,
          $$ImportChangesTableFilterComposer,
          $$ImportChangesTableOrderingComposer,
          $$ImportChangesTableAnnotationComposer,
          $$ImportChangesTableCreateCompanionBuilder,
          $$ImportChangesTableUpdateCompanionBuilder,
          (ImportChange, $$ImportChangesTableReferences),
          ImportChange,
          PrefetchHooks Function({bool batchId})
        > {
  $$ImportChangesTableTableManager(_$CueDatabase db, $ImportChangesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> batchId = const Value.absent(),
                Value<String> tableName_ = const Value.absent(),
                Value<String> rowKey = const Value.absent(),
                Value<String?> beforeJson = const Value.absent(),
                Value<String?> afterJson = const Value.absent(),
              }) => ImportChangesCompanion(
                seq: seq,
                batchId: batchId,
                tableName_: tableName_,
                rowKey: rowKey,
                beforeJson: beforeJson,
                afterJson: afterJson,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String batchId,
                required String tableName_,
                required String rowKey,
                Value<String?> beforeJson = const Value.absent(),
                Value<String?> afterJson = const Value.absent(),
              }) => ImportChangesCompanion.insert(
                seq: seq,
                batchId: batchId,
                tableName_: tableName_,
                rowKey: rowKey,
                beforeJson: beforeJson,
                afterJson: afterJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImportChangesTable, ImportChange>(table),
                  $$ImportChangesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({batchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (batchId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.batchId,
                        referencedTable: $$ImportChangesTableReferences
                            ._batchIdTable(db),
                        referencedColumn: $$ImportChangesTableReferences
                            ._batchIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ImportChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$CueDatabase,
      $ImportChangesTable,
      ImportChange,
      $$ImportChangesTableFilterComposer,
      $$ImportChangesTableOrderingComposer,
      $$ImportChangesTableAnnotationComposer,
      $$ImportChangesTableCreateCompanionBuilder,
      $$ImportChangesTableUpdateCompanionBuilder,
      (ImportChange, $$ImportChangesTableReferences),
      ImportChange,
      PrefetchHooks Function({bool batchId})
    >;

class $CueDatabaseManager {
  final _$CueDatabase _db;
  $CueDatabaseManager(this._db);
  $$CatalogTitlesTableTableManager get catalogTitles =>
      $$CatalogTitlesTableTableManager(_db, _db.catalogTitles);
  $$CatalogIdentitiesTableTableManager get catalogIdentities =>
      $$CatalogIdentitiesTableTableManager(_db, _db.catalogIdentities);
  $$CatalogPagesTableTableManager get catalogPages =>
      $$CatalogPagesTableTableManager(_db, _db.catalogPages);
  $$WatchProvidersTableTableManager get watchProviders =>
      $$WatchProvidersTableTableManager(_db, _db.watchProviders);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$ProfileSettingsTableTableManager get profileSettings =>
      $$ProfileSettingsTableTableManager(_db, _db.profileSettings);
  $$UserTitlesTableTableManager get userTitles =>
      $$UserTitlesTableTableManager(_db, _db.userTitles);
  $$DecisionEventsTableTableManager get decisionEvents =>
      $$DecisionEventsTableTableManager(_db, _db.decisionEvents);
  $$ShortlistTableTableManager get shortlist =>
      $$ShortlistTableTableManager(_db, _db.shortlist);
  $$DeferralsTableTableManager get deferrals =>
      $$DeferralsTableTableManager(_db, _db.deferrals);
  $$ExclusionsTableTableManager get exclusions =>
      $$ExclusionsTableTableManager(_db, _db.exclusions);
  $$TagWeightsTableTableManager get tagWeights =>
      $$TagWeightsTableTableManager(_db, _db.tagWeights);
  $$ImportBatchesTableTableManager get importBatches =>
      $$ImportBatchesTableTableManager(_db, _db.importBatches);
  $$SourceObservationsTableTableManager get sourceObservations =>
      $$SourceObservationsTableTableManager(_db, _db.sourceObservations);
  $$ImportChangesTableTableManager get importChanges =>
      $$ImportChangesTableTableManager(_db, _db.importChanges);
}
