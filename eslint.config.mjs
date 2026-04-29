import babelParser from '@babel/eslint-parser'
import standard from '@vue/eslint-config-standard'
import globals from 'globals'
import pluginVue from 'eslint-plugin-vue'
import vuetify from 'eslint-plugin-vuetify'

export default [
  {
    ignores: ['dist/**']
  },
  ...pluginVue.configs['flat/essential'],
  ...vuetify.configs['flat/base'],
  ...standard,
  {
    files: ['**/*.{js,vue}'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        ...globals.browser,
        ...globals.node
      }
    },
    rules: {
      'no-console': 'off',
      'no-debugger': 'off',
      'new-cap': 'off',
      'vue/no-reserved-component-names': 'off',
      'vue/multi-word-component-names': 'off'
    }
  },
  {
    files: ['**/*.js'],
    languageOptions: {
      parser: babelParser,
      parserOptions: {
        requireConfigFile: false
      }
    }
  },
  {
    files: ['**/*.vue'],
    languageOptions: {
      parserOptions: {
        parser: babelParser,
        requireConfigFile: false
      }
    }
  }
]
