import { beforeEach } from "vitest";

import { resetBreakers } from "../src/resilience";

// Circuit state is per isolate; tests must not leak an open circuit into each other.
beforeEach(() => resetBreakers());
