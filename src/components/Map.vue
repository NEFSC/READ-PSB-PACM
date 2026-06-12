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
    <CitationsDialog v-model="citationDialog"></CitationsDialog>
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
import CitationsDialog from '@/components/dialogs/CitationsDialog'

import ZoomMin from '@/lib/leaflet/L.Control.ZoomMin'
import '@/lib/leaflet/L.Control.ZoomMin.css'
import evt from '@/lib/events'
import { mapGetters } from 'vuex'
import { xf } from '@/lib/crossfilter'

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
    ...mapGetters(['isLoading', 'activeTheme', 'deployments']),
    showOrganizationAttribution () {
      return this.activeTheme && !this.isLoading && this.deployments
    },
    organizationAttributionLabel () {
      return this.visibleOrganizationCodes.length > 0
        ? this.visibleOrganizationCodes.join(', ')
        : 'None in current view'
    }
  },
  watch: {
    activeTheme () {
      this.updateVisibleOrganizations()
    },
    deployments () {
      this.updateVisibleOrganizations()
    }
  },
  components: {
    Legend,
    CitationsDialog,

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
    },
    normalizeOrganizationCode (code) {
      return code || 'UNKNOWN'
    },
    getFilteredOrganizationCodes () {
      const codes = new Set()
      xf.allFiltered().forEach(detection => {
        codes.add(this.normalizeOrganizationCode(detection.deployment_organization_code))
        codes.add(this.normalizeOrganizationCode(detection.analysis_organization_code))
      })
      return Array.from(codes).sort()
    },
    updateVisibleOrganizations () {
      if (!this.map || !this.activeTheme || this.isLoading || !this.deployments) {
        this.visibleOrganizationCodes = []
        return
      }

      this.visibleOrganizationCodes = this.getFilteredOrganizationCodes()
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
