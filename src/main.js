import { createApp } from 'vue'

import App from './App.vue'
import store from './store'
import router from './router'

import vuetify from './plugins/vuetify'
import HighchartsVue from './plugins/highcharts'

import './plugins/dc'
import './plugins/leaflet'

import '@/assets/css/app.css'
import '@/assets/css/dc.css'

window.type = true // https://github.com/Leaflet/Leaflet.draw/issues/1026

createApp(App)
  .use(store)
  .use(router)
  .use(vuetify)
  .use(HighchartsVue)
  .mount('#app')
