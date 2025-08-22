import tailwindcss from "@tailwindcss/vite";
import { sveltekit } from "@sveltejs/kit/vite";
import { defineConfig } from "vite";

const host = process.env.TAURI_DEV_HOST;

export default defineConfig({
    plugins: [tailwindcss(), sveltekit()],
    clearScreen: false,
    server: {
        host: host || false,
        port: 5173,
        strictPort: true,
        hmr: host
            ? {
                  protocol: "ws",
                  host: host,
                  port: 5173
              }
            : undefined
    }
});
