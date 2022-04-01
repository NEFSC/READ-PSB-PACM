<template>
  <div style="height:100%">
    <v-overlay :value="loading" style="z-index:10000">
      <v-progress-circular
        indeterminate
        size="64"
      ></v-progress-circular>
    </v-overlay>
    <l-map
      ref="map"
      style="width:100%;height:100%"
      :center="[50, -20]"
      :zoom="$vuetify.breakpoint.mobile ? 2 : 3"
      :options="{ zoomControl: false }"
      @zoomend="onZoom">
      <l-control-scale position="bottomleft"></l-control-scale>
      <l-control position="topright">
        <Legend :counts="counts" v-if="theme && !loading"></Legend>
      </l-control>
    </l-map>
    <MapLayer v-if="ready && !loading"></MapLayer>
    <MapSelector v-if="ready"></MapSelector>
  </div>
</template>

<script>
import { LMap, LControlScale, LControl } from 'vue2-leaflet'
import * as d3 from 'd3'
import L from 'leaflet'

import Legend from '@/components/Legend'
import MapLayer from '@/components/MapLayer'
import MapSelector from '@/components/MapSelector'

import ZoomMin from '@/lib/leaflet/L.Control.ZoomMin'
import '@/lib/leaflet/L.Control.ZoomMin.css'
import evt from '@/lib/events'
import { mapGetters } from 'vuex'

export default {
  name: 'Map',
  props: ['points', 'counts'],
  data () {
    return {
      ready: false,
      layers: {
        wind: {
          data: null
        }
      }
    }
  },
  computed: {
    ...mapGetters(['loading', 'theme'])
  },
  components: {
    Legend,

    MapLayer,
    MapSelector,

    LMap,
    LControlScale,
    LControl
  },
  async mounted () {
    this.map = this.$refs.map.mapObject

    this.zoomMinControl = new ZoomMin({ minBounds: this.map.getBounds() })
    this.map.addControl(this.zoomMinControl)

    const basemaps = {
      'No Basemap': L.tileLayer(''),
      'ESRI Ocean': L.tileLayer(
        '//server.arcgisonline.com/ArcGIS/rest/services/Ocean_Basemap/MapServer/tile/{z}/{y}/{x}',
        {
          attribution: 'Tiles &copy; Esri &mdash; Sources: GEBCO, NOAA, CHS, OSU, UNH, CSUMB, National Geographic, DeLorme, NAVTEQ, and Esri'
        }
      ).addTo(this.map)
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
  },
  beforeDestroy () {
    evt.$off('map:setBounds', this.setBounds)
  },
  methods: {
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
      const latLngBounds = new L.latLngBounds([ // eslint-disable-line
        [bounds[0][1], bounds[0][0]],
        [bounds[1][1], bounds[1][0]]
      ])
      this.map.fitBounds(latLngBounds, { maxZoom: 10 })
      this.zoomMinControl.options.minBounds = this.map.getBounds()
    },
    onZoom () {
      evt.$emit('map:zoom', this.map.getZoom())
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
