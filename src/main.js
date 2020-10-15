import Vue from 'vue'

import App from './App.vue'
import store from './store'

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
  vuetify,
  render: h => h(App)
}).$mount('#app')
