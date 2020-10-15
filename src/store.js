import Vue from 'vue'
import Vuex from 'vuex'

import { fetchData } from '@/lib/utils'
import { setData } from '@/lib/crossfilter'

Vue.use(Vuex)

export default new Vuex.Store({
  state: {
    loading: true,
    theme: null,
    deployments: null,
    selectedDeployment: null,
    tracks: null,
    normalizeEffort: false
  },
  getters: {
    loading: state => state.loading,
    theme: state => state.theme,
    isTowed: state => state.theme === 'beaked' || state.theme === 'kogia',
    deployments: state => state.deployments,
    deploymentById: state => id => state.deployments.find(d => d.id === id),
    selectedDeployment: state => state.selectedDeployment,
    tracks: state => state.tracks,
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
    SET_TRACKS (state, tracks) {
      state.tracks = Object.freeze(tracks)
    },
    SET_SELECTED_DEPLOYMENT (state, selectedDeployment) {
      state.selectedDeployment = selectedDeployment
    },
    SET_NORMALIZE_EFFORT (state, normalizeEffort) {
      state.normalizeEffort = normalizeEffort
    }
  },
  actions: {
    setTheme ({ commit }, theme) {
      commit('SET_LOADING', true)
      commit('SET_SELECTED_DEPLOYMENT', null)
      return fetchData(theme)
        .then(([deployments, detections, tracks]) => {
          setData(detections)
          commit('SET_DEPLOYMENTS', deployments)
          commit('SET_TRACKS', tracks)
          commit('SET_THEME', theme)
          commit('SET_LOADING', false)
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
