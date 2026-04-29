import { fileURLToPath, URL } from 'node:url'
import fs from 'node:fs'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'

const packageJson = JSON.parse(fs.readFileSync('./package.json', 'utf8'))

export default defineConfig(({ command }) => ({
  base: command === 'build' ? '/pacm/' : '/',
  plugins: [
    vue({
      template: {
        compilerOptions: {
          compatConfig: {
            MODE: 2
          }
        }
      }
    })
  ],
  resolve: {
    extensions: ['.mjs', '.js', '.ts', '.jsx', '.tsx', '.json', '.vue'],
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
      vue: '@vue/compat'
    }
  },
  define: {
    'process.env.PACKAGE_VERSION': JSON.stringify(packageJson.version || '0')
  },
  build: {
    sourcemap: true
  }
}))
