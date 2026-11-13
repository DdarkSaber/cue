import { NotConfiguredError, UpstreamError } from "../catalog/types";
import { fetchJson, type FetchOptions } from "../catalog/upstream";
import type { Env } from "../env";

/**
 * One list entry as the app receives it from a sign-in or username import.
 * Tokens are forwarded once per request, never stored or logged.
 */
export interface ListEntry {
  malId: number | null;
  title: string;
  kind: "anime" | "manga" | "manhwa" | "manhua" | "series" | "movie" | null;
  status: string;
  score: number | null;
  scoreScale: string | null;
  progress: number | null;
  repeat: number | null;
  completedAt: string | null;
  /** When the person last changed this entry (YYYY-MM-DD), a recency hint. */
  updatedAt?: string | null;
}

const MAX_ENTRIES = 20000;

/**
 * MAL answers 401 (sometimes 403) when the person's access token expired or
 * was revoked. That must reach the app as token_expired, not as an outage,
 * so the app renews or signs out only when the sign-in is really gone.
 */
const BEARER_REJECTED: FetchOptions = { authRejected: [401, 403] };
/** The token endpoint refuses a used, expired or revoked grant with 400/401 (invalid_grant). */
const GRANT_REJECTED: FetchOptions = { authRejected: [400, 401] };

type Row = Record<string, any>;

// --- MyAnimeList -------------------------------------------------------------

async function malPages(
  first: string,
  headers: Record<string, string>,
  type: "anime" | "manga",
  opts: FetchOptions = {},
): Promise<ListEntry[]> {
  const out: ListEntry[] = [];
  let url: string | null = first;
  // MAL paging links are followed only on the MAL API host.
  for (let page = 0; url && page < 20; page++) {
    const u = new URL(url);
    if (u.hostname !== "api.myanimelist.net") break;
    const body = (await fetchJson(url, { headers }, opts)) as Row | null;
    for (const d of body?.data ?? []) {
      const n = d.node ?? {};
      const s = d.list_status ?? {};
      out.push({
        malId: n.id ?? null,
        title: n.title ?? "",
        kind: type === "anime" ? "anime" : mangaKind(n.media_type),
        status: String(s.status ?? "").toLowerCase(),
        score: s.score > 0 ? s.score : null,
        scoreScale: s.score > 0 ? "10" : null,
        progress: (type === "anime" ? s.num_episodes_watched : s.num_chapters_read) || null,
        repeat: s.is_rewatching || s.num_times_rewatched > 0 ? Math.max(1, s.num_times_rewatched ?? 1) : null,
        completedAt: typeof s.finish_date === "string" && s.finish_date.length === 10 ? s.finish_date : null,
        updatedAt: isoDay(s.updated_at),
      });
      if (out.length >= MAX_ENTRIES) return out;
    }
    url = body?.paging?.next ?? null;
  }
  return out;
}

const MAL_FIELDS =
  "media_type,list_status{status,score,num_episodes_watched,num_chapters_read,is_rewatching,num_times_rewatched,finish_date,updated_at}";

/** MAL's manga media_type names the format; novels stay unknown (and are filtered later). */
function mangaKind(t: unknown): ListEntry["kind"] {
  return t === "manhwa" ? "manhwa" : t === "manhua" ? "manhua" : t === "manga" || t === "one_shot" || t === "doujinshi" ? "manga" : null;
}

/** "2026-10-12T08:00:00+00:00" -> "2026-10-12"; anything else -> null. */
function isoDay(v: unknown): string | null {
  return typeof v === "string" && /^\d{4}-\d{2}-\d{2}/.test(v) ? v.slice(0, 10) : null;
}

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
    malPages(malUrl("@me", "anime"), headers, "anime", BEARER_REJECTED),
    malPages(malUrl("@me", "manga"), headers, "manga", BEARER_REJECTED),
  ]);
  return [...a, ...m];
}

/** The signed-in MAL user's name, to show which account Cue is using. */
export async function malMe(token: string): Promise<string | null> {
  const me = (await fetchJson("https://api.myanimelist.net/v2/users/@me", {
    headers: { Authorization: `Bearer ${token}` },
  }, BEARER_REJECTED)) as Row | null;
  return typeof me?.name === "string" ? me.name : null;
}

// --- OAuth token exchange ----------------------------------------------------

export interface OAuthConfig {
  mal: string | null;
}

export function oauthConfig(env: Env): OAuthConfig {
  return {
    mal: env.MAL_CLIENT_ID || null,
  };
}

export interface Tokens {
  accessToken: string;
  /** Longer-lived; lets the app renew without a new sign-in. */
  refreshToken: string | null;
  /** Seconds until the access token expires. */
  expiresIn: number | null;
}

async function malToken(env: Env, params: Record<string, string | undefined>): Promise<Tokens> {
  if (!env.MAL_CLIENT_ID) throw new NotConfiguredError("mal");
  const body = new URLSearchParams();
  for (const [k, v] of Object.entries({
    client_id: env.MAL_CLIENT_ID,
    client_secret: env.MAL_CLIENT_SECRET,
    ...params,
  })) {
    if (v) body.set(k, v);
  }
  const res = (await fetchJson("https://myanimelist.net/v1/oauth2/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  }, GRANT_REJECTED)) as Row | null;
  const token = res?.access_token;
  if (typeof token !== "string" || token.length === 0) throw new UpstreamError("token");
  return {
    accessToken: token,
    refreshToken: typeof res?.refresh_token === "string" ? res.refresh_token : null,
    expiresIn: typeof res?.expires_in === "number" ? res.expires_in : null,
  };
}

/** Exchanges an authorization code. Tokens pass through; none are kept. */
export function exchange(
  env: Env,
  _provider: "mal",
  code: string,
  redirectUri: string,
  codeVerifier?: string,
): Promise<Tokens> {
  return malToken(env, {
    grant_type: "authorization_code",
    code,
    redirect_uri: redirectUri,
    code_verifier: codeVerifier,
  });
}

/** Renews tokens with a refresh token. Nothing is kept. */
export function refresh(env: Env, _provider: "mal", refreshToken: string): Promise<Tokens> {
  return malToken(env, { grant_type: "refresh_token", refresh_token: refreshToken });
}
