import Vue from 'vue'
import axios from 'axios'

axios.defaults.baseURL = process.env.VUE_APP_API_BASEURL || 'http://127.0.0.1:8080'

Vue.prototype.$http = axios
