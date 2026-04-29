import { fileURLToPath, URL } from 'node:url'
import fs from 'node:fs'
import vue from '@vitejs/plugin-vue'
import vuetify, { transformAssetUrls } from 'vite-plugin-vuetify'
import { defineConfig } from 'vite'

const packageJson = JSON.parse(fs.readFileSync('./package.json', 'utf8'))

export default defineConfig(({ command }) => ({
  base: command === 'build' ? '/pacm/' : '/',
  plugins: [
    vue({
      template: {
        transformAssetUrls,
        compilerOptions: {
          compatConfig: false
        }
      }
    }),
    vuetify()
  ],
  resolve: {
    extensions: ['.mjs', '.js', '.ts', '.jsx', '.tsx', '.json', '.vue'],
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  define: {
    'process.env.PACKAGE_VERSION': JSON.stringify(packageJson.version || '0')
  },
  build: {
    sourcemap: true
  }
}))
