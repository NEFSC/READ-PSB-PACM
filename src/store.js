import { defineStore } from 'pinia'
import { nest } from 'd3-collection'

import { fetchData, fetchReferences } from '@/lib/fetch'
import { setData, setRawDetections, getRawDetections, aggregateByDate } from '@/lib/crossfilter'

export const useStore = defineStore('main', {
  state: () => ({
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
  }),
  getters: {
    themeId: (state) => state.theme ? state.theme.id : null,
    deploymentById: (state) => (id) => state.deployments.find(d => d.id === id)
  },
  actions: {
    fetchReferences () {
      return fetchReferences()
        .then(references => {
          console.log('references', references)
          this.species = Object.freeze(references.species)
          this.platformTypes = Object.freeze(references.platformTypes)
        })
    },
    setTheme (theme) {
      if (this.theme && this.theme.id === theme.id) {
        return Promise.resolve(this.theme)
      }
      this.loadingFailed = false
      this.loading = true
      this.selectedDeployments = []
      return fetchData(theme)
        .then(([sites, tracks, deployments, detections]) => {
          const deploymentsMap = Object.fromEntries(deployments.map(d => [d.id, d]))

          detections.forEach((d, i) => {
            d.$index = i
            d.site_id = deploymentsMap[d.id].site_id || deploymentsMap[d.id].id
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
          this.deployments = Object.freeze(deployments)
          this.sites = Object.freeze(sites)
          this.tracks = Object.freeze(tracks)
          if (theme.deploymentsOnly) {
            this.useSizeScale = false
          } else {
            this.useSizeScale = true
          }
          this.theme = theme
          this.loading = false
          return theme
        })
        .catch((e) => {
          console.log('setTheme failed', e)
          this.loadingFailed = true
          this.loading = false
        })
    },
    selectDeployments (ids) {
      if (!ids || ids.length === 0) {
        this.selectedDeployments = []
        return
      }

      if (this.selectedDeployments.length > 0) {
        const selectedIds = this.selectedDeployments.map(d => d.id)
        if (selectedIds.some(id => ids.includes(id))) {
          this.selectedDeployments = []
          return
        }
      }

      this.selectedDeployments = this.deployments.filter(d => ids.includes(d.id))
    },
    setNormalizeEffort (normalizeEffort) {
      this.normalizeEffort = normalizeEffort
    },
    setUseSizeScale (useSizeScale) {
      this.useSizeScale = useSizeScale
    },
    reloadSpeciesFilter (selectedSpecies) {
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
      this.deployments.forEach(d => {
        d.trackDetections = trackNest.get(d.id) || []
      })

      setData(aggregated)
    }
  }
})
