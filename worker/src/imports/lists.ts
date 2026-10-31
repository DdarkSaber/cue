import { NotConfiguredError, UpstreamError } from "../catalog/types";
import { fetchJson } from "../catalog/upstream";
import type { Env } from "../env";

/**
 * One list entry as the app receives it from a sign-in or username import.
 * Tokens are forwarded once per request, never stored or logged.
 */
export interface ListEntry {
  anilistId: number | null;
  malId: number | null;
  traktId: number | null;
  tmdbId: number | null;
  title: string;
  kind: "anime" | "manga" | "manhwa" | "manhua" | "series" | "movie" | null;
  status: string;
  score: number | null;
  scoreScale: string | null;
  progress: number | null;
  repeat: number | null;
  completedAt: string | null;
  plays: number | null;
}

const MAX_ENTRIES = 20000;

// --- AniList ---------------------------------------------------------------

const ANILIST_LIST = `query ($name: String, $type: MediaType) {
  MediaListCollection(userName: $name, type: $type) {
    lists { entries {
      status score(format: POINT_10) progress repeat
      completedAt { year month day }
      media { id idMal countryOfOrigin type title { romaji english native } }
    } }
  }
}`;

const ANILIST_VIEWER = `query { Viewer { name } }`;

type Row = Record<string, any>;

async function anilist(query: string, variables: Row, token?: string) {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    Accept: "application/json",
  };
  if (token) headers.Authorization = `Bearer ${token}`;
  const body = (await fetchJson("https://graphql.anilist.co", {
    method: "POST",
    headers,
    body: JSON.stringify({ query, variables }),
  })) as Row | null;
  return body?.data ?? null;
}

function date(d: Row | null | undefined): string | null {
  if (!d?.year || !d?.month || !d?.day) return null;
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.year}-${p(d.month)}-${p(d.day)}`;
}

function anilistEntries(data: Row | null): ListEntry[] {
  const lists: Row[] = data?.MediaListCollection?.lists ?? [];
  const out: ListEntry[] = [];
  for (const l of lists) {
    for (const e of l.entries ?? []) {
      const m = e.media ?? {};
      const kind =
        m.type === "ANIME"
          ? "anime"
          : m.countryOfOrigin === "KR"
            ? "manhwa"
            : m.countryOfOrigin === "CN" || m.countryOfOrigin === "TW"
              ? "manhua"
              : "manga";
      out.push({
        anilistId: m.id ?? null,
        malId: m.idMal ?? null,
        traktId: null,
        tmdbId: null,
        title: m.title?.english ?? m.title?.romaji ?? m.title?.native ?? "",
        kind,
        status: String(e.status ?? "").toLowerCase(),
        score: e.score > 0 ? e.score : null,
        scoreScale: e.score > 0 ? "10" : null,
        progress: e.progress > 0 ? e.progress : null,
        repeat: e.repeat > 0 ? e.repeat : null,
        completedAt: date(e.completedAt),
        plays: null,
      });
      if (out.length >= MAX_ENTRIES) return out;
    }
  }
  return out;
}

/** Public AniList lists need no key. Private lists return nothing. */
export async function anilistByUser(name: string) {
  const [anime, manga] = await Promise.all([
    anilist(ANILIST_LIST, { name, type: "ANIME" }),
    anilist(ANILIST_LIST, { name, type: "MANGA" }),
  ]);
  return [...anilistEntries(anime), ...anilistEntries(manga)];
}

/** Signed-in AniList: resolves the viewer, then reads both lists. */
export async function anilistViewer(token: string) {
  const viewer = await anilist(ANILIST_VIEWER, {}, token);
  const name = viewer?.Viewer?.name;
  if (!name) throw new UpstreamError("viewer");
  const [anime, manga] = await Promise.all([
    anilist(ANILIST_LIST, { name, type: "ANIME" }, token),
    anilist(ANILIST_LIST, { name, type: "MANGA" }, token),
  ]);
  return [...anilistEntries(anime), ...anilistEntries(manga)];
}

// --- MyAnimeList -------------------------------------------------------------

async function malPages(
  first: string,
  headers: Record<string, string>,
  type: "anime" | "manga",
): Promise<ListEntry[]> {
  const out: ListEntry[] = [];
  let url: string | null = first;
  // MAL paging links are followed only on the MAL API host.
  for (let page = 0; url && page < 20; page++) {
    const u = new URL(url);
    if (u.hostname !== "api.myanimelist.net") break;
    const body = (await fetchJson(url, { headers })) as Row | null;
    for (const d of body?.data ?? []) {
      const n = d.node ?? {};
      const s = d.list_status ?? {};
      out.push({
        anilistId: null,
        malId: n.id ?? null,
        traktId: null,
        tmdbId: null,
        title: n.title ?? "",
        kind: type === "anime" ? "anime" : null,
        status: String(s.status ?? "").toLowerCase(),
        score: s.score > 0 ? s.score : null,
        scoreScale: s.score > 0 ? "10" : null,
        progress: (type === "anime" ? s.num_episodes_watched : s.num_chapters_read) || null,
        repeat: s.is_rewatching || s.num_times_rewatched > 0 ? Math.max(1, s.num_times_rewatched ?? 1) : null,
        completedAt: typeof s.finish_date === "string" && s.finish_date.length === 10 ? s.finish_date : null,
        plays: null,
      });
      if (out.length >= MAX_ENTRIES) return out;
    }
    url = body?.paging?.next ?? null;
  }
  return out;
}

const MAL_FIELDS = "list_status{status,score,num_episodes_watched,num_chapters_read,is_rewatching,num_times_rewatched,finish_date}";

function malUrl(user: string, type: "anime" | "manga") {
  const u = new URL(`https://api.myanimelist.net/v2/users/${encodeURIComponent(user)}/${type}list`);
  u.searchParams.set("fields", MAL_FIELDS);
  u.searchParams.set("limit", "1000");
  u.searchParams.set("nsfw", "true");
  return u.toString();
}

/** A public MAL list by username; needs only Cue's client id. */
export async function malByUser(env: Env, name: string) {
  if (!env.MAL_CLIENT_ID) throw new NotConfiguredError("mal");
  const headers = { "X-MAL-CLIENT-ID": env.MAL_CLIENT_ID };
  const [a, m] = await Promise.all([
    malPages(malUrl(name, "anime"), headers, "anime"),
    malPages(malUrl(name, "manga"), headers, "manga"),
  ]);
  return [...a, ...m];
}

/** The signed-in person's MAL lists. */
export async function malViewer(token: string) {
  const headers = { Authorization: `Bearer ${token}` };
  const [a, m] = await Promise.all([
    malPages(malUrl("@me", "anime"), headers, "anime"),
    malPages(malUrl("@me", "manga"), headers, "manga"),
  ]);
  return [...a, ...m];
}

/** The signed-in MAL user's name, to show which account Cue is using. */
export async function malMe(token: string): Promise<string | null> {
  const me = (await fetchJson("https://api.myanimelist.net/v2/users/@me", {
    headers: { Authorization: `Bearer ${token}` },
  })) as Row | null;
  return typeof me?.name === "string" ? me.name : null;
}

// --- Trakt -------------------------------------------------------------------

export async function traktMe(env: Env, token: string): Promise<string | null> {
  if (!env.TRAKT_CLIENT_ID) throw new NotConfiguredError("trakt");
  const me = (await fetchJson("https://api.trakt.tv/users/settings", {
    headers: {
      Authorization: `Bearer ${token}`,
      "trakt-api-version": "2",
      "trakt-api-key": env.TRAKT_CLIENT_ID,
    },
  })) as Row | null;
  return typeof me?.user?.username === "string" ? me.user.username : null;
}

export async function traktViewer(env: Env, token: string) {
  if (!env.TRAKT_CLIENT_ID) throw new NotConfiguredError("trakt");
  const headers = {
    Authorization: `Bearer ${token}`,
    "trakt-api-version": "2",
    "trakt-api-key": env.TRAKT_CLIENT_ID,
    "Content-Type": "application/json",
  };
  const [shows, movies] = await Promise.all([
    fetchJson("https://api.trakt.tv/sync/watched/shows?extended=noseasons", { headers }),
    fetchJson("https://api.trakt.tv/sync/watched/movies", { headers }),
  ]);
  const out: ListEntry[] = [];
  for (const s of (shows as Row[] | null) ?? []) {
    out.push({
      anilistId: null,
      malId: null,
      traktId: s.show?.ids?.trakt ?? null,
      tmdbId: s.show?.ids?.tmdb ?? null,
      title: s.show?.title ?? "",
      kind: "series",
      status: "watched",
      score: null,
      scoreScale: null,
      progress: null,
      repeat: null,
      completedAt: null,
      plays: s.plays ?? null,
    });
  }
  for (const m of (movies as Row[] | null) ?? []) {
    out.push({
      anilistId: null,
      malId: null,
      traktId: m.movie?.ids?.trakt ?? null,
      tmdbId: m.movie?.ids?.tmdb ?? null,
      title: m.movie?.title ?? "",
      kind: "movie",
      status: "watched",
      score: null,
      scoreScale: null,
      progress: null,
      repeat: null,
      completedAt: typeof m.last_watched_at === "string" ? m.last_watched_at.slice(0, 10) : null,
      plays: m.plays ?? null,
    });
  }
  return out.slice(0, MAX_ENTRIES);
}

// --- OAuth token exchange ----------------------------------------------------

export interface OAuthConfig {
  mal: string | null;
  anilist: string | null;
  trakt: string | null;
}

export function oauthConfig(env: Env): OAuthConfig {
  return {
    mal: env.MAL_CLIENT_ID || null,
    anilist: env.ANILIST_CLIENT_ID || null,
    trakt: env.TRAKT_CLIENT_ID || null,
  };
}

/** Exchanges an authorization code. Returns the access token only. */
export async function exchange(
  env: Env,
  provider: "mal" | "anilist" | "trakt",
  code: string,
  redirectUri: string,
  codeVerifier?: string,
): Promise<{ accessToken: string }> {
  const form = (o: Record<string, string | undefined>) => {
    const p = new URLSearchParams();
    for (const [k, v] of Object.entries(o)) if (v) p.set(k, v);
    return p;
  };
  let res: Row | null;
  switch (provider) {
    case "mal":
      if (!env.MAL_CLIENT_ID) throw new NotConfiguredError("mal");
      res = (await fetchJson("https://myanimelist.net/v1/oauth2/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: form({
          client_id: env.MAL_CLIENT_ID,
          client_secret: env.MAL_CLIENT_SECRET,
          grant_type: "authorization_code",
          code,
          redirect_uri: redirectUri,
          code_verifier: codeVerifier,
        }),
      })) as Row | null;
      break;
    case "anilist":
      if (!env.ANILIST_CLIENT_ID || !env.ANILIST_CLIENT_SECRET) throw new NotConfiguredError("anilist");
      res = (await fetchJson("https://anilist.co/api/v2/oauth/token", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({
          grant_type: "authorization_code",
          client_id: env.ANILIST_CLIENT_ID,
          client_secret: env.ANILIST_CLIENT_SECRET,
          redirect_uri: redirectUri,
          code,
        }),
      })) as Row | null;
      break;
    case "trakt":
      if (!env.TRAKT_CLIENT_ID || !env.TRAKT_CLIENT_SECRET) throw new NotConfiguredError("trakt");
      res = (await fetchJson("https://api.trakt.tv/oauth/token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          code,
          client_id: env.TRAKT_CLIENT_ID,
          client_secret: env.TRAKT_CLIENT_SECRET,
          redirect_uri: redirectUri,
          grant_type: "authorization_code",
          code_verifier: codeVerifier,
        }),
      })) as Row | null;
      break;
  }
  const token = res?.access_token;
  if (typeof token !== "string" || token.length === 0) throw new UpstreamError("token");
  return { accessToken: token };
}
