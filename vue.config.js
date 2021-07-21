const fs = require('fs')
const webpack = require('webpack')
const packageJson = fs.readFileSync('./package.json')
const version = JSON.parse(packageJson).version || 0

module.exports = {
  transpileDependencies: [
    'vuetify'
  ],
  publicPath: '',
  filenameHashing: true,
  configureWebpack: {
    devtool: 'source-map',
    devServer: {
      watchOptions: {
        ignored: [/node_modules/, /public/, /dist/]
      }
    },
    plugins: [
      new webpack.DefinePlugin({
        'process.env': {
          PACKAGE_VERSION: '"' + version + '"'
        }
      })
    ]
  }
}
