import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    singleThread: true,
    testTimeout: 30000,
    hookTimeout: 30000,
    globals: true
  },
});
