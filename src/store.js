import { createStore } from 'vuex'
// import moment from 'moment'
import { nest } from 'd3-collection'
// import { timeDay } from 'd3'

import { fetchData } from '@/lib/fetch'
import { setData, setRawDetections, getRawDetections, aggregateByDate } from '@/lib/crossfilter'

export default createStore({
  state: {
    loading: false,
    loadingFailed: false,
    theme: null,
    deployments: null,
    sites: null,
    tracks: null,
    organizations: null,
    citations: null,
    selectedDeployments: [],
    normalizeEffort: false,
    useSizeScale: true
  },
  getters: {
    isLoading: state => state.loading,
    loadingFailed: state => state.loadingFailed,
    activeTheme: state => state.theme,
    themeId: state => state.theme ? state.theme.id : null,
    deployments: state => state.deployments,
    sites: state => state.sites,
    tracks: state => state.tracks,
    organizations: state => state.organizations,
    citations: state => state.citations,
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
    SET_ORGANIZATIONS (state, organizations) {
      state.organizations = Object.freeze(organizations)
    },
    SET_CITATIONS (state, citations) {
      state.citations = Object.freeze(citations)
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
        .then(([sites, tracks, deployments, detections, organizations, citations]) => {
          // deployments.json is analysis-grained for species themes (one row per
          // analysis), so its metadata must be keyed by analysis_id, not by
          // deployment id. Keying by id collapsed multi-analysis deployments via
          // Object.fromEntries and mis-attributed their detections' analysis
          // metadata (T5.2). Every theme's detections and deployments now carry
          // a unique analysis_id, so this one code path works for all of them.
          const deploymentsByAnalysis = Object.fromEntries(deployments.map(d => [d.analysis_id, d]))
          detections.forEach((d, i) => {
            d.$index = i
            const dep = deploymentsByAnalysis[d.analysis_id]
            d.site_id = dep.site_id || '__none__'
            d.platform_type = dep.platform_type
            d.analysis_organization_code = dep.analysis_organization_code
            d.deployment_organization_code = dep.deployment_organization_code
            d.instrument_type = dep.instrument_type || 'UNKNOWN'
            d.dynamic_management_platform = dep.dynamic_management_platform || false
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
                  species: d.species,
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
          commit('SET_ORGANIZATIONS', organizations)
          commit('SET_CITATIONS', citations)
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
        if (selectedIds.every(id => ids.includes(id))) {
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
      console.log('[reloadSpeciesFilter] called', { selectedSpecies })
      const raw = getRawDetections()
      const filtered = raw.filter(d => selectedSpecies.includes(d.species))
      const aggregated = aggregateByDate(filtered)
      aggregated.forEach((d, i) => { d.$index = i })
      console.log('[reloadSpeciesFilter] aggregated', aggregated[0])

      const trackDetections = aggregated.map(d =>
        d.locations
          ? d.locations.map(l => ({
              $index: d.$index,
              id: d.id,
              presence: d.presence,
              ...l
            }))
          : []
      ).flat()
      console.log('[reloadSpeciesFilter] trackDetections', trackDetections[0])
      const trackNest = nest().key(d => d.id).map(trackDetections)
      state.deployments.forEach(d => {
        d.trackDetections = trackNest.get(d.id) || []
      })

      setData(aggregated)
    }
  }
})
