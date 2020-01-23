import Vue from 'vue'

import App from './App.vue'
import vuetify from './plugins/vuetify'

import './plugins/axios'
import './plugins/dc'
import './plugins/leaflet'
import './plugins/moment'
import './plugins/vue-tour'

Vue.config.productionTip = false

new Vue({
  vuetify,
  render: h => h(App)
}).$mount('#app')
