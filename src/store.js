import Vue from 'vue'
import Vuex from 'vuex'
import * as d3 from 'd3'

import { fetchData } from '@/lib/fetch'
import { setData } from '@/lib/crossfilter'

Vue.use(Vuex)

export default new Vuex.Store({
  state: {
    loading: false,
    theme: null,
    deployments: null,
    selectedDeployments: [],
    normalizeEffort: false,
    useSizeScale: true
  },
  getters: {
    loading: state => state.loading,
    theme: state => state.theme,
    themeId: state => state.theme ? state.theme.id : null,
    deployments: state => state.deployments,
    deploymentById: state => id => state.deployments.find(d => d.id === id),
    selectedDeployments: state => state.selectedDeployments,
    normalizeEffort: state => state.normalizeEffort,
    useSizeScale: state => state.useSizeScale
  },
  mutations: {
    SET_LOADING (state, loading) {
      state.loading = loading
    },
    SET_THEME (state, theme) {
      state.theme = theme
    },
    SET_DEPLOYMENTS (state, deployments) {
      state.deployments = Object.freeze(deployments)
    },
    SET_SELECTED_DEPLOYMENTS (state, selectedDeployments) {
      state.selectedDeployments = selectedDeployments || []
    },
    SET_NORMALIZE_EFFORT (state, normalizeEffort) {
      state.normalizeEffort = normalizeEffort
    },
    SET_USE_SIZE_SCALE (state, useSizeScale) {
      state.useSizeScale = useSizeScale
    }
  },
  actions: {
    setTheme ({ commit, state }, theme) {
      if (state.theme && state.theme.id === theme.id) {
        return Promise.resolve(state.theme)
      }
      commit('SET_LOADING', true)
      commit('SET_SELECTED_DEPLOYMENTS', [])
      return fetchData(theme)
        .then(([deployments, detections]) => {
          const deploymentsMap = Object.fromEntries(deployments.map(d => [d.id, d]))

          detections.forEach((d, i) => {
            d.$index = i
            d.platform_type = deploymentsMap[d.id].properties.platform_type
          })
          const trackDetections = detections.map(d => {
            return d.locations
              ? d.locations.map(l => ({
                $index: d.$index,
                id: d.id,
                presence: d.presence,
                ...l
              }))
              : []
          }).flat()

          const trackDetectionsNest = d3.nest()
            .key(d => d.id)
            .map(trackDetections)

          deployments.forEach(d => {
            d.trackDetections = trackDetectionsNest.get(d.id) || []
          })

          setData(detections)
          commit('SET_DEPLOYMENTS', deployments)
          commit('SET_THEME', theme)
          commit('SET_LOADING', false)
          return theme
        })
    },
    selectDeployments ({ commit, getters, state }, ids) {
      if (!ids || ids.length === 0) return commit('SET_SELECTED_DEPLOYMENTS', [])

      if (state.selectedDeployments.length > 0) {
        // clear existing selection if it includes clicked deployment
        const selectedIds = state.selectedDeployments.map(d => d.id)
        if (selectedIds.some(id => ids.includes(id))) {
          return commit('SET_SELECTED_DEPLOYMENTS', [])
        }
      }

      const deployments = getters.deployments.filter(d => ids.includes(d.id))
      commit('SET_SELECTED_DEPLOYMENTS', deployments)
    },
    setNormalizeEffort ({ commit }, normalizeEffort) {
      commit('SET_NORMALIZE_EFFORT', normalizeEffort)
    },
    setUseSizeScale ({ commit }, useSizeScale) {
      commit('SET_USE_SIZE_SCALE', useSizeScale)
    }
  }
})
