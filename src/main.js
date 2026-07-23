import { createApp } from 'vue'

import App from './App.vue'
import store from './store'
import router from './router'
import { initConstants } from './lib/constants'

import vuetify from './plugins/vuetify'
import HighchartsVue from './plugins/highcharts'
import Vue3Tour from 'vue3-tour'

import './plugins/dc'
import './plugins/leaflet'

import '@/assets/css/app.css'
import '@/assets/css/dc.css'
import '@/assets/css/vue-tour.css'

window.type = true // https://github.com/Leaflet/Leaflet.draw/issues/1026

// species/platform_types reference data is fetched from the data dir and must
// be ready before any component renders
initConstants()
  .then(() => {
    createApp(App)
      .use(store)
      .use(router)
      .use(vuetify)
      .use(HighchartsVue)
      .use(Vue3Tour)
      .mount('#app')
  })
  .catch(err => {
    console.error('Failed to load reference data (species/platform_types)', err)
  })
