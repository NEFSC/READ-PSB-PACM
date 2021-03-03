module.exports = {
  transpileDependencies: [
    'vuetify'
  ],
  publicPath: process.env.NODE_ENV === 'production'
    ? '/projects/nefsc/pam/'
    : '/',
  configureWebpack: {
    devtool: 'source-map'
  }
}
