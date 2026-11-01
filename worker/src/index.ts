import { createApp } from "./app";
import type { Env } from "./env";
import { SyncStore } from "./sync/store";

const app = createApp();

/** Encrypted copies untouched this long are abandoned (sync turned on again
 * with a new code, or a device gone). Nobody can open them anyway. */
export const SYNC_MAX_AGE_MS = 180 * 24 * 60 * 60 * 1000;

export default {
  fetch: app.fetch,
  async scheduled(_event, env) {
    const removed = await new SyncStore(env.SYNC_DB).prune(Date.now(), SYNC_MAX_AGE_MS);
    console.log(JSON.stringify({ e: "sync_prune", removed }));
  },
} satisfies ExportedHandler<Env>;
