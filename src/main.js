import Vue from 'vue'

import App from './App.vue'
import store from './store'
import router from './router'

import vuetify from './plugins/vuetify'

import './plugins/axios'
import './plugins/dc'
import './plugins/highcharts'
import './plugins/leaflet'
import './plugins/moment'
import './plugins/vue-tour'

Vue.config.productionTip = false

new Vue({
  store,
  router,
  vuetify,
  render: h => h(App)
}).$mount('#app')
