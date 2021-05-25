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
    }
  }
}
