import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { nodePolyfills } from "vite-plugin-node-polyfills";
import { fileURLToPath, URL } from "node:url";

const processShimPath = fileURLToPath(
  new URL("./src/shims/process.ts", import.meta.url),
);

// https://vite.dev/config/
export default defineConfig({
  resolve: {
    alias: {
      process: processShimPath,
      "process/browser": processShimPath,
      "process/browser.js": processShimPath,
      "node:process": processShimPath,
    },
  },
  plugins: [
    react(),
    nodePolyfills({
      include: ["util", "assert"],
      globals: {
        process: true,
        global: true,
        Buffer: true,
      },
      protocolImports: true,
    }),
  ],
});
