import { UpstreamError } from "./types";

export const UPSTREAM_TIMEOUT_MS = 5000;
const MAX_JSON_BYTES = 2 * 1024 * 1024;

/**
 * Fetches JSON from a fixed provider URL with a timeout and a size cap.
 * Redirects are refused so a provider can never bounce us elsewhere.
 */
export async function fetchJson(
  url: string,
  init: RequestInit = {},
): Promise<unknown> {
  let res: Response;
  try {
    res = await fetch(url, {
      ...init,
      redirect: "manual",
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
    });
  } catch {
    throw new UpstreamError("fetch");
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
