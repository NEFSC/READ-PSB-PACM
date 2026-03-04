import Vue from 'vue'
import Vuex from 'vuex'
// import moment from 'moment'
import { nest } from 'd3-collection'
// import { timeDay } from 'd3'

import { fetchData, fetchReferences } from '@/lib/fetch'
import { setData, setRawDetections, getRawDetections, aggregateByDate } from '@/lib/crossfilter'

Vue.use(Vuex)

export default new Vuex.Store({
  state: {
    loading: false,
    loadingFailed: false,
    theme: null,
    deployments: null,
    sites: null,
    tracks: null,
    species: null,
    platformTypes: null,
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
    sites: state => state.sites,
    tracks: state => state.tracks,
    deploymentById: state => id => state.deployments.find(d => d.id === id),
    selectedDeployments: state => state.selectedDeployments,
    normalizeEffort: state => state.normalizeEffort,
    useSizeScale: state => state.useSizeScale,
    species: state => state.species,
    platformTypes: state => state.platformTypes
  },
  mutations: {
    SET_LOADING (state, loading) {
      state.loading = loading
    },
    SET_LOADING_FAILED (state, loadingFailed) {
      state.loadingFailed = loadingFailed
    },
    SET_THEME (state, theme) {
      if (theme.deploymentsOnly) {
        state.useSizeScale = false
      } else {
        state.useSizeScale = true
      }
      state.theme = theme
    },
    SET_SITES (state, sites) {
      state.sites = Object.freeze(sites)
    },
    SET_TRACKS (state, tracks) {
      state.tracks = Object.freeze(tracks)
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
    },
    SET_SPECIES (state, species) {
      state.species = Object.freeze(species)
    },
    SET_PLATFORM_TYPES (state, platformTypes) {
      state.platformTypes = Object.freeze(platformTypes)
    }
  },
  actions: {
    fetchReferences ({ commit }) {
      return fetchReferences()
        .then(references => {
          console.log('references', references)
          commit('SET_SPECIES', references.species)
          commit('SET_PLATFORM_TYPES', references.platformTypes)
        })
    },
    setTheme ({ commit, state }, theme) {
      if (state.theme && state.theme.id === theme.id) {
        return Promise.resolve(state.theme)
      }
      commit('SET_LOADING_FAILED', false)
      commit('SET_LOADING', true)
      commit('SET_SELECTED_DEPLOYMENTS', [])
      return fetchData(theme)
        .then(([sites, tracks, deployments, detections]) => {
          const deploymentsMap = Object.fromEntries(deployments.map(d => [d.id, d]))

          detections.forEach((d, i) => {
            d.$index = i
            d.site_id = deploymentsMap[d.id].site_id || deploymentsMap[d.id].id // TODO: confirm deployments without sites can be shown by id
            d.platform_type = deploymentsMap[d.id].platform_type
            d.organization_code = deploymentsMap[d.id].organization_code || 'UNKNOWN'
            d.instrument_type = deploymentsMap[d.id].instrument_type || 'UNKNOWN'
          })

          // Store raw detections and aggregate for multi-species themes
          setRawDetections(detections, !!theme.showSpeciesFilter)
          const processedDetections = theme.showSpeciesFilter
            ? aggregateByDate(detections)
            : detections
          processedDetections.forEach((d, i) => { d.$index = i })

          const trackDetections = processedDetections.map(d => {
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

          setData(processedDetections)
          commit('SET_DEPLOYMENTS', deployments)
          commit('SET_SITES', sites)
          commit('SET_TRACKS', tracks)
          commit('SET_THEME', theme)
          commit('SET_LOADING', false)
          return theme
        })
        .catch((e) => {
          console.log('setTheme failed', e)
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
    },
    reloadSpeciesFilter ({ state }, selectedSpecies) {
      const raw = getRawDetections()
      const filtered = selectedSpecies && selectedSpecies.length > 0
        ? raw.filter(d => selectedSpecies.includes(d.species))
        : raw
      const aggregated = aggregateByDate(filtered)
      aggregated.forEach((d, i) => { d.$index = i })

      const trackDetections = aggregated.map(d =>
        d.locations
          ? d.locations.map(l => ({
            $index: d.$index, id: d.id, presence: d.presence, ...l
          }))
          : []
      ).flat()
      const trackNest = nest().key(d => d.id).map(trackDetections)
      state.deployments.forEach(d => {
        d.trackDetections = trackNest.get(d.id) || []
      })

      setData(aggregated)
    }
  }
})
