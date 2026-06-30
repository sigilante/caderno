import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { urbitPlugin as urbit } from '@urbit/vite-plugin-urbit'

const SHIP_URL = process.env.SHIP_URL || 'http://192.168.4.48:8080'

export default defineConfig({
  plugins: [
    react(),
    urbit({
      base: 'caderno',
      target: SHIP_URL,
    }),
  ],
  build: { outDir: 'dist' },
})
