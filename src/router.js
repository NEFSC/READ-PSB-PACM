import { createRouter, createWebHashHistory, createWebHistory } from 'vue-router'

const RoutePlaceholder = {
  render: () => null
}

const routes = [
  {
    name: 'home',
    path: '/:id?',
    component: RoutePlaceholder
  }
]

const router = createRouter({
  history: createWebHashHistory(import.meta.env.BASE_URL),
  routes
})

export default router
