import { createRouter, createWebHashHistory } from 'vue-router'

const routes = [
  {
    name: 'home',
    path: '/:id?'
  }
]

const router = createRouter({
  history: createWebHashHistory(),
  routes
})

export default router
