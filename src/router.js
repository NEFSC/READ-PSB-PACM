import Vue from 'vue'
import VueRouter from 'vue-router'

Vue.use(VueRouter)

const routes = [
  {
    name: 'home',
    path: '/:id'
  }
]

const router = new VueRouter({
  routes
})

export default router
