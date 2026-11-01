import { createApp } from "./app";
import type { Env } from "./env";
import { SYNC_MAX_AGE_MS, SyncStore } from "./sync/store";

const app = createApp();

export default {
  fetch: app.fetch,
  async scheduled(_event, env) {
    const removed = await new SyncStore(env.SYNC_DB).prune(Date.now(), SYNC_MAX_AGE_MS);
    console.log(JSON.stringify({ e: "sync_prune", removed }));
  },
} satisfies ExportedHandler<Env>;
