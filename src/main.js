import { createApp } from 'vue'
import { createPinia } from 'pinia'

import App from './App.vue'
import router from './router'
import vuetify from './plugins/vuetify'

import './plugins/dc'
import './plugins/highcharts'
import HighchartsVue from 'highcharts-vue'
import './plugins/leaflet'
import './plugins/dayjs'
import Vue3Tour from 'vue3-tour'
import './plugins/vue-tour'

import '@/assets/css/app.css'
import '@/assets/css/dc.css'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(router)
app.use(vuetify)
app.use(HighchartsVue)
app.use(Vue3Tour)

app.mount('#app')
