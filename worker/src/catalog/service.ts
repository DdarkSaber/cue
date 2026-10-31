import type { Env } from "../env";
import {
  ANILIST_KINDS,
  byMalIds,
  discoverAniList,
  searchAniList,
  searchManyAniList,
  titleAniList,
} from "./anilist";
import { TTL, cached } from "./cache";
import {
  type TmdbType,
  discoverTmdb,
  providersTmdb,
  searchTmdb,
  titleTmdb,
} from "./tmdb";
import { aliasesFor, type AliasCandidate } from "./mangadex";
import { aliasesFromMangaUpdates, titleMangaUpdates } from "./mangaupdates";
import { CINEMETA_KINDS, cinemetaType, discoverCinemeta, searchCinemeta, titleCinemeta } from "./cinemeta";
import { discoverTvmaze, searchTvmaze, titleTvmaze, tvmazeLastPage } from "./tvmaze";
import type { CatalogItem, CatalogPage, CatalogProvider, MediaKind } from "./types";

type Mood = "hype" | "comfort" | "gripping" | "feels";

export function discover(env: Env, kind: MediaKind, mood: Mood | undefined, page: number) {
  return cached<CatalogPage>(
    env.CATALOG_CACHE,
    `discover:${kind}:${mood ?? "-"}:${page}`,
    TTL.discover,
    async () => {
      if (ANILIST_KINDS.has(kind)) return discoverAniList(kind, mood, page);
      // A TMDB key, when there is one, is richer; without it the key-free
      // sources serve dramas, series and movies.
      if (env.TMDB_API_KEY) return discoverTmdb(env.TMDB_API_KEY, kind, mood, page);
      if (CINEMETA_KINDS.has(kind)) return discoverCinemeta("movie", mood, page);
      const last = await cachedLastPage(env);
      return discoverTvmaze(kind, mood, page, last);
    },
  );
}

/** The newest TVmaze page, remembered for three days. */
async function cachedLastPage(env: Env): Promise<number> {
  const { value } = await cached<number>(env.CATALOG_CACHE, "tvmaze:last", 3 * 24 * 60 * 60, () =>
    tvmazeLastPage(),
  );
  return value;
}

export type TitleType = TmdbType | "series";

export function title(env: Env, provider: CatalogProvider, id: string, type: TitleType) {
  return cached<CatalogItem | null>(
    env.CATALOG_CACHE,
    `title:${provider}:${provider === "tmdb" ? type : "-"}:${id}`,
    TTL.title,
    () => {
      switch (provider) {
        case "anilist":
          return titleAniList(id);
        case "tmdb":
          return titleTmdb(env.TMDB_API_KEY, id, type === "series" ? "tv" : type);
        case "cinemeta":
          return titleCinemeta(id, type === "movie" ? "movie" : "series");
        case "mangaupdates":
          return titleMangaUpdates(id);
        case "tvmaze":
          return titleTvmaze(id);
      }
    },
  );
}

/**
 * Match candidates for imports. Anime and reading go to AniList; dramas,
 * series and movies go to TMDB when keyed, else TVmaze (series only).
 * With no kind, both sides are asked.
 */
export function search(env: Env, q: string, kind: MediaKind | undefined) {
  const norm = q.toLowerCase().replace(/\s+/g, " ");
  return cached<CatalogItem[]>(
    env.CATALOG_CACHE,
    `search:${kind ?? "-"}:${norm}`,
    TTL.search,
    async () => {
      const screen = () => searchScreen(env, q, kind);
      if (kind && ANILIST_KINDS.has(kind)) return searchAniList(q, kind);
      if (kind) return screen();
      const [a, b] = await Promise.allSettled([searchAniList(q, undefined), screen()]);
      return [
        ...(a.status === "fulfilled" ? a.value.slice(0, 6) : []),
        ...(b.status === "fulfilled" ? b.value.slice(0, 6) : []),
      ];
    },
  );
}

/**
 * Screen titles: a TMDB key when there is one, otherwise TVmaze for series
 * and dramas and Cinemeta for movies. With no kind, both free sources.
 */
export async function searchScreen(
  env: Env,
  q: string,
  kind: MediaKind | undefined,
): Promise<CatalogItem[]> {
  if (env.TMDB_API_KEY) return searchTmdb(env.TMDB_API_KEY, q, kind);
  if (kind === "movie") return searchCinemeta(q, "movie");
  if (kind) {
    // TVmaze first; Cinemeta's IMDb-style titles catch the English names
    // TVmaze lacks (a K-drama's licensed title versus its fan title).
    const [tv, imdb] = await Promise.allSettled([searchTvmaze(q), searchCinemeta(q, "series")]);
    const seen = new Set<string>();
    return [
      ...(tv.status === "fulfilled" ? tv.value : []),
      ...(imdb.status === "fulfilled" ? imdb.value : []),
    ].filter((i) => {
      const k = `${(i.titleEn ?? "").toLowerCase()}|${i.year ?? ""}`;
      return seen.has(k) ? false : (seen.add(k), true);
    });
  }
  const [tv, film] = await Promise.allSettled([searchTvmaze(q), searchCinemeta(q, "movie")]);
  return [
    ...(tv.status === "fulfilled" ? tv.value.slice(0, 4) : []),
    ...(film.status === "fulfilled" ? film.value.slice(0, 3) : []),
  ];
}

/**
 * Other names for comics, from MangaDex, cached a week per name. A failed
 * lookup is an empty list for that name, so one bad title never sinks a batch.
 */
export async function aliases(
  env: Env,
  queries: string[],
  source: "mangadex" | "mangaupdates" = "mangadex",
): Promise<AliasCandidate[][]> {
  const out: AliasCandidate[][] = queries.map(() => []);
  for (let s = 0; s < queries.length; s += 4) {
    await Promise.all(
      queries.slice(s, s + 4).map(async (q, j) => {
        const key = `alias:${source}:${q.toLowerCase().replace(/\s+/g, " ")}`;
        try {
          const { value } = await cached<AliasCandidate[]>(env.CATALOG_CACHE, key, 7 * 24 * 60 * 60, () =>
            source === "mangaupdates" ? aliasesFromMangaUpdates(q) : aliasesFor(q),
          );
          out[s + j] = value;
        } catch {
          // Left empty.
        }
      }),
    );
  }
  return out;
}

export function providers(env: Env, id: string, type: TitleType, region: string) {
  const t: TmdbType = type === "series" ? "tv" : type;
  return cached(
    env.CATALOG_CACHE,
    `providers:${t}:${id}:${region}`,
    TTL.providers,
    () => providersTmdb(env.TMDB_API_KEY, id, t, region),
  );
}

/**
 * Batch match for imports. Reading and anime titles go to AniList in one
 * aliased query; screen titles go to TMDB (if keyed) or TVmaze one by one,
 * staying well under the per-request subrequest limit.
 */
export async function match(
  env: Env,
  items: { q: string; kind?: MediaKind }[],
  malAnime: number[],
  malManga: number[],
) {
  const isScreen = (k?: MediaKind) => !!k && !ANILIST_KINDS.has(k);
  // A title with no kind is searched as a screen title only: the app asks
  // AniList itself, and AniList refuses requests from Cloudflare.
  const aniIdx = items.map((it, i) => (it.kind && !isScreen(it.kind) ? i : -1)).filter((i) => i >= 0);
  const screenIdx = items.map((it, i) => (isScreen(it.kind) || !it.kind ? i : -1)).filter((i) => i >= 0);
  const results: CatalogItem[][] = items.map(() => []);

  const [ani, malA, malM] = await Promise.all([
    searchManyAniList(aniIdx.map((i) => items[i]!)),
    byMalIds(malAnime, "ANIME"),
    byMalIds(malManga, "MANGA"),
  ]);
  aniIdx.forEach((i, j) => results[i]!.push(...(ani[j] ?? [])));

  // Five at a time: well inside TVmaze's rate limit and the subrequest cap.
  for (let s = 0; s < screenIdx.length; s += 5) {
    await Promise.all(
      screenIdx.slice(s, s + 5).map(async (i) => {
        const it = items[i]!;
        try {
          const found = await searchScreen(env, it.q, it.kind);
          results[i]!.push(...found.slice(0, 6));
        } catch {
          // One failed lookup leaves that title unresolved, not the batch.
        }
      }),
    );
  }
  return { results, mal: [...malA, ...malM] };
}
