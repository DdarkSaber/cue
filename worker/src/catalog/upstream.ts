import { backoffMs, isOpen, recordFailure, recordSuccess, retryAfterMs, sleep } from "../resilience";
import { AuthRejectedError, UpstreamError } from "./types";

export const UPSTREAM_TIMEOUT_MS = 5000;

/** Providers behind bot protection refuse requests with no User-Agent. */
export const USER_AGENT = "Cue/1.0 (personal non-commercial app; +https://cue-next.cue-worker.workers.dev)";
const MAX_JSON_BYTES = 2 * 1024 * 1024;
/** One retry at most: a Worker request has little wall time to spend. */
const MAX_RETRIES = 1;
const MAX_RETRY_WAIT_MS = 1500;

const retryable = (status: number) => status === 429 || (status >= 500 && status <= 599);

export interface FetchOptions {
  /**
   * Statuses meaning "the person's credentials were refused" (only for calls
   * made with their token). Thrown as AuthRejectedError, never retried, and
   * never counted against the circuit: the provider answered, so it is up.
   */
  authRejected?: readonly number[];
}

/**
 * Fetches JSON from a fixed provider URL with a timeout and a size cap.
 * Redirects are refused so a provider can never bounce us elsewhere.
 * Idempotent GETs retry once on a network error, 429 or 5xx, with jittered
 * backoff that honors Retry-After. A host that keeps failing is skipped for a
 * short while (fast 502) instead of being waited on.
 */
export async function fetchJson(
  url: string,
  init: RequestInit = {},
  opts: FetchOptions = {},
): Promise<unknown> {
  const host = new URL(url).hostname;
  const retries = (init.method ?? "GET").toUpperCase() === "GET" ? MAX_RETRIES : 0;
  for (let attempt = 0; ; attempt++) {
    if (isOpen(host)) throw new UpstreamError("circuit open");
    let res: Response | null;
    try {
      res = await fetch(url, {
        ...init,
        headers: { "User-Agent": USER_AGENT, ...(init.headers as Record<string, string> | undefined) },
        redirect: "manual",
        signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
      });
    } catch {
      res = null;
    }
    if (res === null || retryable(res.status)) {
      recordFailure(host);
      if (attempt < retries && !isOpen(host)) {
        const wait = res ? retryAfterMs(res.headers.get("Retry-After"), MAX_RETRY_WAIT_MS) : null;
        void res?.body?.cancel();
        await sleep(wait ?? backoffMs(attempt));
        continue;
      }
      throw new UpstreamError(res ? `status ${res.status}` : "fetch");
    }
    recordSuccess(host);
    if (opts.authRejected?.includes(res.status)) {
      void res.body?.cancel();
      throw new AuthRejectedError(`status ${res.status}`);
    }
    if (res.status === 404) return null;
    if (!res.ok) throw new UpstreamError(`status ${res.status}`);
    const length = Number(res.headers.get("Content-Length") ?? 0);
    if (length > MAX_JSON_BYTES) throw new UpstreamError("too large");
    const text = await res.text();
    if (text.length > MAX_JSON_BYTES) throw new UpstreamError("too large");
    try {
      return JSON.parse(text);
    } catch {
      throw new UpstreamError("json");
    }
  }
}
