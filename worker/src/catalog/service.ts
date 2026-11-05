import type { Env } from "../env";
import { TTL, cached } from "./cache";
import {
  type TmdbType,
  discoverTmdb,
  providersTmdb,
  recommendationsTmdb,
  searchTmdb,
  titleTmdb,
} from "./tmdb";
import { aliasesFor, type AliasCandidate } from "./mangadex";
import { aliasesFromMangaUpdates, titleMangaUpdates } from "./mangaupdates";
import { CINEMETA_KINDS, cinemetaType, discoverCinemeta, searchCinemeta, titleCinemeta } from "./cinemeta";
import { discoverMal, searchMal, type MalSearchItem } from "./mal";
import { wikiNames, type WikiName } from "./wikipedia";
import { discoverTvmaze, searchTvmaze, titleTvmaze, tvmazeLastPage } from "./tvmaze";
import { type CatalogItem, type CatalogPage, type CatalogProvider, type MediaKind, NotConfiguredError } from "./types";

type Mood = "hype" | "comfort" | "gripping" | "feels";

/**
 * Anime and comics come from AniList, which refuses Cloudflare's IPs, so the
 * app asks AniList itself. The Worker serves only screen titles.
 */
const DEVICE_KINDS = new Set<MediaKind>(["anime", "manga", "manhwa", "manhua"]);

export function discover(
  env: Env,
  kind: MediaKind,
  mood: Mood | undefined,
  page: number,
  source: "default" | "mal" = "default",
) {
  // MAL's ranking has no genre filter, so its pages are shared by every mood.
  if (source === "mal") {
    return cached<CatalogPage>(env.CATALOG_CACHE, `discover:mal:${kind}:${page}`, TTL.discover, () =>
      discoverMal(env.MAL_CLIENT_ID, kind, page),
    );
  }
  return cached<CatalogPage>(
    env.CATALOG_CACHE,
    `discover:${kind}:${mood ?? "-"}:${page}`,
    TTL.discover,
    async () => {
      if (DEVICE_KINDS.has(kind)) return { items: [], hasNext: false };
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
        case "tmdb":
          return titleTmdb(env.TMDB_API_KEY, id, type === "series" ? "tv" : type);
        case "cinemeta":
          return titleCinemeta(id, type === "movie" ? "movie" : "series");
        case "mangaupdates":
          return titleMangaUpdates(id);
        case "tvmaze":
          return titleTvmaze(id);
        case "mal":
          // Backup listings only: the app refreshes these through AniList by MAL id.
          return Promise.resolve(null);
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
      if (kind && DEVICE_KINDS.has(kind)) return [];
      return screen();
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

/** Lookup results are kept a week: names and their matches rarely change. */
const LOOKUP_TTL = 7 * 24 * 60 * 60;

/**
 * Runs one cached lookup per name, four at a time. A failed lookup is an
 * empty list for that name, so one bad title never sinks a batch.
 */
async function perName<Q extends { q: string }, T>(
  env: Env,
  queries: Q[],
  keyOf: (norm: string, query: Q) => string,
  load: (query: Q) => Promise<T[]>,
): Promise<T[][]> {
  const out: T[][] = queries.map(() => []);
  for (let s = 0; s < queries.length; s += 4) {
    await Promise.all(
      queries.slice(s, s + 4).map(async (query, j) => {
        try {
          const norm = query.q.toLowerCase().replace(/\s+/g, " ").trim();
          const { value } = await cached<T[]>(env.CATALOG_CACHE, keyOf(norm, query), LOOKUP_TTL, () =>
            load(query),
          );
          out[s + j] = value;
        } catch (e) {
          // A missing key is the whole route's answer, not one name's.
          if (e instanceof NotConfiguredError) throw e;
        }
      }),
    );
  }
  return out;
}

/**
 * MyAnimeList title search for imports: the second opinion after AniList.
 * Each name searches anime or comics (MAL keeps manga, manhwa and manhua in
 * one list).
 */
export function malSearch(
  env: Env,
  queries: { q: string; type: "anime" | "manga" }[],
): Promise<MalSearchItem[][]> {
  if (!env.MAL_CLIENT_ID) throw new NotConfiguredError("mal");
  return perName(
    env,
    queries,
    (n, { type }) => `malsearch:${type}:${n}`,
    ({ q, type }) => searchMal(env.MAL_CLIENT_ID, q, type),
  );
}

/**
 * Canonical names from Wikipedia for names no catalog recognised, so the app
 * can ask AniList and MAL again with the title an article uses.
 */
export function names(env: Env, queries: string[], kind: MediaKind | undefined): Promise<WikiName[][]> {
  return perName(
    env,
    queries.map((q) => ({ q })),
    (n) => `wiki:${kind ?? "-"}:${n}`,
    ({ q }) => wikiNames(q, kind),
  );
}

/**
 * Titles a provider itself lists as "more like this", for taste-seeded
 * retrieval. Only TMDB offers such a list; without a key the answer is an
 * empty list marked unconfigured, so the app simply skips this route.
 */
export async function recommendations(
  env: Env,
  provider: CatalogProvider,
  id: string,
  type: TitleType,
): Promise<{ items: CatalogItem[]; configured: boolean }> {
  if (provider !== "tmdb" || !env.TMDB_API_KEY) return { items: [], configured: false };
  const t: TmdbType = type === "series" ? "tv" : type;
  const { value } = await cached<CatalogItem[]>(
    env.CATALOG_CACHE,
    `recommendations:${t}:${id}`,
    TTL.title,
    () => recommendationsTmdb(env.TMDB_API_KEY, id, t),
  );
  return { items: value, configured: true };
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
 * Batch match for imports: screen titles only (TMDB if keyed, else TVmaze and
 * Cinemeta), one by one, well under the per-request subrequest limit. Anime
 * and comics are matched by the app against AniList directly.
 */
export async function match(env: Env, items: { q: string; kind?: MediaKind }[]) {
  const screenIdx = items.map((it, i) => (it.kind && DEVICE_KINDS.has(it.kind) ? -1 : i)).filter((i) => i >= 0);
  const results: CatalogItem[][] = items.map(() => []);
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
  return { results, mal: [] as CatalogItem[] };
}
