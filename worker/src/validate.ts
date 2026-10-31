import type { Context } from "hono";
import type { z } from "zod";

import { fail } from "./errors";

type Parsed<T> = { ok: true; data: T } | { ok: false; res: Response };

/** Validates input with zod. Errors name the fields, never their values. */
export function check<S extends z.ZodType>(
  c: Context,
  schema: S,
  input: unknown,
): Parsed<z.infer<S>> {
  const result = schema.safeParse(input);
  if (result.success) return { ok: true, data: result.data };
  const fields = [...new Set(result.error.issues.map((i) => i.path.join(".")))];
  return { ok: false, res: fail(c, 400, "invalid_request", { fields }) };
}

/** Reads a JSON body. Anything not sent as application/json is treated as missing. */
export async function jsonBody(c: Context): Promise<unknown> {
  const type = c.req.header("Content-Type") ?? "";
  if (!/^application\/json(\s*;|$)/i.test(type)) return undefined;
  try {
    return await c.req.json();
  } catch {
    return undefined;
  }
}
