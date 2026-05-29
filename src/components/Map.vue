<template>
  <div style="height:100%">
    <v-overlay :model-value="isLoading" style="z-index:10000;width:100%;height:100%;" class="d-flex align-center justify-center">
      <v-progress-circular
        indeterminate
        size="128"
        width="10"
        color="white"
      ></v-progress-circular>
    </v-overlay>
    <l-map
      ref="map"
      style="width:100%;height:100%"
      :center="[50, -20]"
      :zoom="$vuetify.display.mobile ? 2 : 3"
      :options="{ zoomControl: false, attributionControl: false }"
      @ready="onMapReady"
      @moveend="updateVisibleOrganizations"
      @zoomend="onZoom">
      <l-control-attribution position="bottomright" prefix="">
      </l-control-attribution>
      <l-control position="bottomright" class="mx-0">
        <div
          v-if="showOrganizationAttribution"
          class="leaflet-control-organization-attribution"
          aria-live="polite"
        >
          <span>Passive Acoustic Data Contributors: {{ organizationAttributionLabel }}</span>&nbsp;<br>
          <v-btn
            color="primary"
            variant="outlined"
            size="x-small"
            @click.stop="citationDialog = true"
            @mousedown.stop
            @dblclick.stop
          >
            <v-icon start>mdi-file-document-outline</v-icon>
            Generate Citations
          </v-btn>
        </div>
      </l-control>
      <l-control-scale position="bottomleft"></l-control-scale>
      <l-control position="topright">
        <Legend :counts="counts" v-if="activeTheme && !isLoading"></Legend>
      </l-control>
    </l-map>
    <v-dialog v-model="citationDialog" max-width="900" scrollable>
      <v-card>
        <v-card-title class="d-flex align-center">
          <h2 class="text-h5">Citations</h2>
          <v-spacer></v-spacer>
          <v-btn icon="mdi-close" variant="flat" size="small" aria-label="close citations" @click="citationDialog = false"></v-btn>
        </v-card-title>
        <v-card-text class="text-body-1 text-grey-darken-4">
          <p class="mb-4">
            If you use data from the Passive Acoustic Cetacean Map (PACM) in a publication, presentation, or other work, please include the PACM citation below and the list of data contributor citations.
          </p>
          <p class="mb-4">
            The data contributor list is generated automatically based on which datasets currently visible on the map. Changing any of the dropdown selections or filters may change this list. Please verify that you have the correct selections and filters applied to the map before copying the citations.
          </p>
          <p class="mb-4">
            Please note that this list may include preferred citations, which can be provided by data contributors upon submission to the <a href="https://passiveacoustics.fisheries.noaa.gov/pars/">Passive Acoustic Reporting System (PARS)</a>. If a dataset does not have a preferred citation, PACM generates a generic citation for the entire organization. Please include both the preferred and generic citations to ensure proper attribution of all data contributors.
          </p>
          <p>
             If you have questions about how to cite data from PACM, please contact <a href="mailto:passiveacoustics@noaa.gov">passiveacoustics@noaa.gov</a>.
          </p>
          <h3 class="text-h6 mt-6 mb-2">PACM Citation</h3>
          <p class="font-weight-bold text-grey-darken-2 text-body-2 mb-4 ml-4">
            {{ pacmCitation }}
          </p>

          <h3 class="text-h6 mt-6 mb-2">Data Contributors</h3>
          <p v-if="contributorCitations.length === 0" class="text-medium-emphasis">
            No data contributors are visible in the current map view.
          </p>
          <p class="font-weight-bold text-grey-darken-2 text-body-2 ml-4 mb-4" v-for="citation in contributorCitations" :key="citation.organizationCode">
            {{ citation.text }}
          </p>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn color="primary" variant="text" @click="citationDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
    <MapLayer v-if="ready && !isLoading"></MapLayer>
    <MapSelector v-if="ready"></MapSelector>
  </div>
</template>

<script>
import { LMap, LControlAttribution, LControlScale, LControl } from '@vue-leaflet/vue-leaflet'
import * as d3 from 'd3'
import L from 'leaflet'

import Legend from '@/components/Legend'
import MapLayer from '@/components/MapLayer'
import MapSelector from '@/components/MapSelector'

import ZoomMin from '@/lib/leaflet/L.Control.ZoomMin'
import '@/lib/leaflet/L.Control.ZoomMin.css'
import evt from '@/lib/events'
import { mapGetters } from 'vuex'
import { deploymentMap, xf } from '@/lib/crossfilter'

export default {
  name: 'Map',
  props: ['points', 'counts'],
  data () {
    return {
      ready: false,
      citationDialog: false,
      visibleOrganizationCodes: [],
      layers: {
        wind: {
          data: null
        }
      }
    }
  },
  computed: {
    ...mapGetters(['isLoading', 'activeTheme', 'deployments', 'sites', 'tracks']),
    showOrganizationAttribution () {
      return this.activeTheme && !this.isLoading && this.deployments
    },
    organizationAttributionLabel () {
      return this.visibleOrganizationCodes.length > 0
        ? this.visibleOrganizationCodes.join(', ')
        : 'None in current view'
    },
    accessedDate () {
      return new Date().toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      })
    },
    pacmCitation () {
      return `Passive Acoustic Cetacean Map (PACM). 2026. Woods Hole (MA): NOAA Northeast Fisheries Science Center v${process.env.PACKAGE_VERSION || 'Unknown'}. Accessed on ${this.accessedDate}. https://passiveacoustics.fisheries.noaa.gov/pacm/`
    },
    contributorCitations () {
      return this.visibleOrganizationCodes.map(organizationCode => ({
        organizationCode,
        text: `${organizationCode}. 2026. Passive acoustic detection data submitted to the Passive Acoustic Reporting System (PARS) at https://passiveacoustics.fisheries.noaa.gov/pars/. Accessed on ${this.accessedDate} via the Passive Acoustic Cetacean Map (PACM) at https://passiveacoustics.fisheries.noaa.gov/pacm/.`
      }))
    }
  },
  watch: {
    activeTheme () {
      this.updateVisibleOrganizations()
    },
    deployments () {
      this.updateVisibleOrganizations()
    },
    sites () {
      this.updateVisibleOrganizations()
    },
    tracks () {
      this.updateVisibleOrganizations()
    }
  },
  components: {
    Legend,

    MapLayer,
    MapSelector,

    LMap,
    LControlScale,
    LControl,
    LControlAttribution
  },
  beforeUnmount () {
    evt.$off('map:setBounds', this.setBounds)
    evt.$off('xf:filtered', this.updateVisibleOrganizations)
    evt.$off('xf:dataAdded', this.updateVisibleOrganizations)
    evt.$off('xf:dataRemoved', this.updateVisibleOrganizations)
  },
  methods: {
    async onMapReady (map) {
      if (this.ready) return

      this.map = map

      this.zoomMinControl = new ZoomMin({ minBounds: this.map.getBounds() })
      this.map.addControl(this.zoomMinControl)

      const basemaps = {
        'No Basemap': L.tileLayer(''),
        'ESRI Ocean': L.tileLayer(
          '//server.arcgisonline.com/ArcGIS/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{z}/{y}/{x}',
          {
            attribution: 'Basemap: &copy; Esri &mdash; Sources: GEBCO, NOAA, CHS, OSU, UNH, CSUMB, National Geographic, DeLorme, NAVTEQ, and Esri'
          }
        ).addTo(this.map),
        'NOAA Nautical Charts': L.tileLayer.wms('https://gis.charttools.noaa.gov/arcgis/rest/services/MCS/ENCOnline/MapServer/exts/MaritimeChartService/WMSServer', {
          layers: '1,2,4',
          attribution: 'NOAA Office of Coast Survey <a href="https://nauticalcharts.noaa.gov/data/gis-data-and-services.html" _target="_blank">ECDIS Display Service</a>'
        })
      }
      const overlays = {
        'Lobster Management Areas': await this.createLobsterLayer(),
        'Wind Energy Areas': await this.createWindEnergyLayer()
      }
      L.control.layers(basemaps, overlays, { position: 'topleft' })
        .addTo(this.map)

      const svgLayer = L.svg()
      this.map.addLayer(svgLayer)

      this.svg = d3.select(svgLayer.getPane()).select('svg')
        .classed('leaflet-zoom-animated', false)
        .classed('leaflet-zoom-hide', true)
        .classed('map', true)
        .attr('pointer-events', 'none')
        .style('z-index', 500)
      this.container = this.svg.select('g')
      this.ready = true

      evt.$on('map:setBounds', this.setBounds)
      evt.$on('xf:filtered', this.updateVisibleOrganizations)
      evt.$on('xf:dataAdded', this.updateVisibleOrganizations)
      evt.$on('xf:dataRemoved', this.updateVisibleOrganizations)
      this.$nextTick(() => this.map.invalidateSize())
      this.updateVisibleOrganizations()
    },
    async createLobsterLayer () {
      const layerGroup = L.layerGroup()
      const response = await fetch('gis/lobster-management-areas.geojson')
      const json = await response.json()
      const styles = {
        'EEZ Nearshore Outer Cape Lobster Management Area': {
          color: '#f792f0'
        },
        'Nearshore Management Area 6': {
          color: '#77e054'
        },
        'EEZ Nearshore Management Area 5': {
          color: '#579ae8'
        },
        'EEZ Nearshore Management Area 4': {
          color: '#d74a58'
        },
        'Area 2/3 Overlap': {
          color: '#7f61f4'
        },
        'EEZ Offshore Management Area 3': {
          color: '#ffaa00'
        },
        'EEZ Nearshore Management Area 2': {
          color: '#785bf2'
        },
        'EEZ Nearshore Management Area 1': {
          color: '#55e0dd'
        }
      }
      L.geoJSON(json, {
        onEachFeature (feature, layer) {
          const tooltip = L.tooltip()
          tooltip.setContent('text')
          layer.bindTooltip(`
            <strong>Lobster Management Area</strong><br>
            ${feature.properties.AREANAME}
          `)

          layer.on('mouseover', (e) => {
            layer.openTooltip(e.latlng)
          })
          layer.on('mousemove', (e) => {
            layer.openTooltip(e.latlng)
          })
          layer.on('mouseout', (e) => {
            layer.closePopup()
          })

          layer.setStyle(styles[feature.properties.AREANAME])
          layerGroup.addLayer(layer)
        }
      })
      return layerGroup
    },
    async createWindEnergyLayer () {
      const layerGroup = L.layerGroup()
      const response = await fetch('gis/wind-energy-areas.json')
      const json = await response.json()

      L.geoJSON(json, {
        onEachFeature (feature, layer) {
          const tooltip = L.tooltip()
          tooltip.setContent('text')

          if (feature.properties.type === 'lease') {
            layer.bindTooltip(`
              <strong>Wind Energy Lease Area</strong><br>
              ID: ${feature.properties.id}<br>
              Type: ${feature.properties.lease_type}<br>
              Company: ${feature.properties.lease_company}<br>
              Lease Date: ${feature.properties.lease_date}<br>
              Lease Term: ${feature.properties.lease_term}<br>
              State: ${feature.properties.state}
            `)
          } else if (feature.properties.type === 'plan') {
            layer.bindTooltip(`
              <strong>Wind Energy Planning Area</strong><br>
              ID: ${feature.properties.id}<br>
              Name: ${feature.properties.plan_name}<br>
              Category: ${feature.properties.plan_category}<br>
            `)
          }

          layer.on('mouseover', (e) => {
            layer.openTooltip(e.latlng)
          })
          layer.on('mousemove', (e) => {
            layer.openTooltip(e.latlng)
          })
          layer.on('mouseout', (e) => {
            layer.closePopup()
          })

          layer.setStyle({
            color: feature.properties.type === 'lease' ? '#4B0055' : 'darkorange'
          })
          layerGroup.addLayer(layer)
        }
      })
      return layerGroup
    },
    setBounds (bounds) {
      this.map.invalidateSize()
      const latLngBounds = new L.latLngBounds([
        [bounds[0][1], bounds[0][0]],
        [bounds[1][1], bounds[1][0]]
      ])
      this.map.fitBounds(latLngBounds, { maxZoom: 10 })
      this.zoomMinControl.options.minBounds = this.map.getBounds()
    },
    onZoom () {
      evt.$emit('map:zoom', this.map.getZoom())
      this.updateVisibleOrganizations()
    },
    normalizeOrganizationCode (code) {
      return code || 'UNKNOWN'
    },
    deploymentTotal (id) {
      return deploymentMap.get(id)?.total ?? 0
    },
    getDeploymentCode (id) {
      const deployment = this.deployments?.find(d => d.id === id)
      return this.normalizeOrganizationCode(deployment?.organization_code)
    },
    pointInCurrentBounds (latitude, longitude) {
      if (!this.map) return false
      const lat = Number(latitude)
      const lng = Number(longitude)
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return false

      const bounds = this.map.getBounds()
      return [-360, 0, 360].some(offset => bounds.contains([lat, lng + offset]))
    },
    flattenCoordinates (coordinates) {
      if (!Array.isArray(coordinates)) return []
      if (coordinates.length >= 2 && Number.isFinite(Number(coordinates[0])) && Number.isFinite(Number(coordinates[1]))) {
        return [coordinates]
      }
      return coordinates.flatMap(d => this.flattenCoordinates(d))
    },
    trackIntersectsCurrentBounds (track) {
      if (!this.map || !track?.geometry?.coordinates) return false
      const coordinates = this.flattenCoordinates(track.geometry.coordinates)
      if (coordinates.length === 0) return false

      const mapBounds = this.map.getBounds()
      return [-360, 0, 360].some(offset => {
        const trackBounds = L.latLngBounds(
          coordinates
            .map(([longitude, latitude]) => [Number(latitude), Number(longitude) + offset])
            .filter(([latitude, longitude]) => Number.isFinite(latitude) && Number.isFinite(longitude))
        )
        return trackBounds.isValid() && mapBounds.intersects(trackBounds)
      })
    },
    collectStationaryOrganizations (codes) {
      const siteLookup = new Map((this.sites || []).map(site => [site.site_id, site]))

      ;(this.deployments || [])
        .filter(deployment => deployment.deployment_type === 'STATIONARY')
        .forEach(deployment => {
          if (this.deploymentTotal(deployment.id) <= 0) return

          const site = deployment.site_id ? siteLookup.get(deployment.site_id) : null
          const latitude = site ? site.site_latitude : deployment.latitude
          const longitude = site ? site.site_longitude : deployment.longitude
          if (this.pointInCurrentBounds(latitude, longitude)) {
            codes.add(this.normalizeOrganizationCode(deployment.organization_code))
          }
        })
    },
    collectTrackOrganizations (codes) {
      ;(this.tracks || []).forEach(track => {
        const id = track.properties?.deployment_id || track.id
        if (!id || this.deploymentTotal(id) <= 0) return
        if (!this.trackIntersectsCurrentBounds(track)) return

        codes.add(this.normalizeOrganizationCode(track.properties?.organization_code || this.getDeploymentCode(id)))
      })
    },
    collectDetectionPointOrganizations (codes) {
      if (!this.activeTheme || this.activeTheme.deploymentsOnly) return

      const deploymentCodeLookup = new Map(
        (this.deployments || []).map(deployment => [
          deployment.id,
          this.normalizeOrganizationCode(deployment.organization_code)
        ])
      )

      ;(this.deployments || [])
        .filter(deployment => deployment.deployment_type === 'MOBILE')
        .flatMap(deployment => deployment.trackDetections || [])
        .forEach(point => {
          if (!xf.isElementFiltered(point.$index)) return
          if (this.pointInCurrentBounds(point.latitude, point.longitude)) {
            codes.add(deploymentCodeLookup.get(point.id) || 'UNKNOWN')
          }
        })
    },
    updateVisibleOrganizations () {
      if (!this.map || !this.activeTheme || this.isLoading || !this.deployments) {
        this.visibleOrganizationCodes = []
        return
      }

      const codes = new Set()
      this.collectStationaryOrganizations(codes)
      this.collectTrackOrganizations(codes)
      this.collectDetectionPointOrganizations(codes)
      this.visibleOrganizationCodes = Array.from(codes).sort()
    }
  }
}
</script>

<style>
.leaflet-control-layers-toggle {
  background-image: url('../assets/img/leaflet-control-layers.png') !important;
  width: 30px !important;
  height: 30px !important;
}
</style>
