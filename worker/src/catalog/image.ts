import { UpstreamError } from "./types";
import { UPSTREAM_TIMEOUT_MS } from "./upstream";

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const IMAGE_TYPES = /^image\/(jpeg|png|webp|gif|avif)$/;

/**
 * Fetches an allowlisted poster for the web app (browsers need CORS to draw
 * images into a canvas). The URL is validated by the route schema first;
 * redirects are refused so the allowlist cannot be bypassed.
 */
export async function proxyImage(url: string): Promise<Response> {
  let res: Response;
  try {
    res = await fetch(url, {
      redirect: "manual",
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
      cf: { cacheTtl: 7 * 24 * 60 * 60, cacheEverything: true },
    } as RequestInit);
  } catch {
    throw new UpstreamError("fetch");
  }
  if (!res.ok) throw new UpstreamError(`status ${res.status}`);
  const type = (res.headers.get("Content-Type") ?? "").split(";")[0]?.trim() ?? "";
  if (!IMAGE_TYPES.test(type)) throw new UpstreamError("type");
  const declared = Number(res.headers.get("Content-Length") ?? 0);
  if (declared > MAX_IMAGE_BYTES) throw new UpstreamError("too large");
  const bytes = await res.arrayBuffer();
  if (bytes.byteLength > MAX_IMAGE_BYTES) throw new UpstreamError("too large");
  return new Response(bytes, {
    headers: {
      "Content-Type": type,
      "Cache-Control": "public, max-age=604800, immutable",
    },
  });
}
