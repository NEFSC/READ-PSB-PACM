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
    selectedDeployment: null,
    // tracks: null,
    // points: null,
    normalizeEffort: false
  },
  getters: {
    loading: state => state.loading,
    theme: state => state.theme,
    themeId: state => state.theme ? state.theme.id : null,
    // isTowed: state => state.theme === 'beaked' || state.theme === 'kogia',
    deployments: state => state.deployments,
    deploymentById: state => id => state.deployments.find(d => d.id === id),
    selectedDeployment: state => state.selectedDeployment,
    // tracks: state => state.tracks,
    // points: state => state.points,
    normalizeEffort: state => state.normalizeEffort
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
    // SET_TRACKS (state, tracks) {
    //   state.tracks = Object.freeze(tracks)
    // },
    // SET_POINTS (state, points) {
    //   state.points = Object.freeze(points)
    // },
    SET_SELECTED_DEPLOYMENT (state, selectedDeployment) {
      state.selectedDeployment = selectedDeployment
    },
    SET_NORMALIZE_EFFORT (state, normalizeEffort) {
      state.normalizeEffort = normalizeEffort
    }
  },
  actions: {
    setTheme ({ commit, state }, theme) {
      if (state.theme && state.theme.id === theme.id) {
        return Promise.resolve(state.theme)
      }
      commit('SET_LOADING', true)
      commit('SET_SELECTED_DEPLOYMENT', null)
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
    selectDeployment ({ commit }, deployment) {
      commit('SET_SELECTED_DEPLOYMENT', deployment)
    },
    selectDeploymentById ({ commit, getters, state }, id) {
      const deployment = getters.deploymentById(id)
      if (getters.selectedDeployment && getters.selectedDeployment === deployment) {
        return commit('SET_SELECTED_DEPLOYMENT', null)
      }
      commit('SET_SELECTED_DEPLOYMENT', deployment)
    },
    setNormalizeEffort ({ commit }, normalizeEffort) {
      commit('SET_NORMALIZE_EFFORT', normalizeEffort)
    }
  }
})
