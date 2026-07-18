import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

//  The NockApp http driver mounts WEB_DIR at a hardcoded `/static` prefix
//  (`nest_service("/static", ServeDir::new(web_dir))`), so every emitted asset
//  URL has to carry that prefix. `index.html` itself is baked into the kernel
//  and served from `/`, so it must reference `/static/assets/...` — which is
//  exactly what this base gives us.
export default defineConfig({
  plugins: [react()],
  base: '/static/',
  build: { outDir: 'dist' },
  server: {
    //  In dev, vite serves the app and proxies the API to the running binary.
    proxy: {
      '/api': { target: 'http://127.0.0.1:8080', changeOrigin: true },
    },
  },
})
