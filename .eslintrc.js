module.exports = {
  root: true,
  env: {
    node: true
  },
  extends: [
    'plugin:vue/essential',
    '@vue/standard'
  ],
  rules: {
    'no-console': 'off',
    'no-debugger': 'off',
    'new-cap': 'off',
    'vue/multi-word-component-names': 'off'
  },
  parserOptions: {
    parser: '@babel/eslint-parser'
  }
}
