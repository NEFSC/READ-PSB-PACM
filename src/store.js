import Vue from 'vue'
import Vuex from 'vuex'
import moment from 'moment'
import { nest } from 'd3-collection'
import { timeDay } from 'd3'

import { fetchData } from '@/lib/fetch'
import { setData } from '@/lib/crossfilter'

Vue.use(Vuex)

export default new Vuex.Store({
  state: {
    loading: false,
    loadingFailed: false,
    theme: null,
    deployments: null,
    selectedDeployments: [],
    normalizeEffort: false,
    useSizeScale: true
  },
  getters: {
    loading: state => state.loading,
    loadingFailed: state => state.loadingFailed,
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
    SET_LOADING_FAILED (state, loadingFailed) {
      state.loadingFailed = loadingFailed
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
      commit('SET_LOADING_FAILED', false)
      commit('SET_LOADING', true)
      commit('SET_SELECTED_DEPLOYMENTS', [])
      return fetchData(theme)
        .then(([deployments, detections]) => {
          const deploymentsMap = Object.fromEntries(deployments.map(d => [d.id, d]))

          let activeDetections = []
          if (theme.deploymentsOnly) {
            activeDetections = deployments
              .filter(d => d.properties.monitoring_end_datetime === null)
              .map(d => {
                const start = new Date(d.properties.monitoring_start_datetime)
                const end = new Date()
                return timeDay.range(start, end).map(t => {
                  const m = moment(t.toISOString().substr(0, 10))
                  const x = {
                    id: d.id,
                    year: m.year(),
                    doy: m.isLeapYear() && m.dayOfYear() >= 60
                      ? m.dayOfYear() - 1
                      : m.dayOfYear(),
                    species: null,
                    presence: 'd',
                    locations: null
                  }
                  x.doySeason = Math.floor((x.doy - 1) / 5) * 5 + 1
                  return x
                })
              }).flat()
          }

          detections = [detections, activeDetections].flat()
          detections.forEach((d, i) => {
            d.$index = i
            d.platform_type = deploymentsMap[d.id].properties.platform_type
            d.data_poc_affiliation = deploymentsMap[d.id].properties.data_poc_affiliation || 'Unknown'
            d.instrument_type = deploymentsMap[d.id].properties.instrument_type || 'Unknown'
            const hz = deploymentsMap[d.id].properties.sampling_rate_hz
            d.sampling_rate = !hz
              ? 'Unknown'
              : hz <= 4000
                ? 'Low (1-4 kHz)'
                : hz < 96000
                  ? 'Medium (5-96 kHz)'
                  : 'High (97+ kHz)'
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

          const trackDetectionsNest = nest()
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
        .catch(() => {
          commit('SET_LOADING_FAILED', true)
          commit('SET_LOADING', false)
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
