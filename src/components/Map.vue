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
      <l-tile-layer
        url="//server.arcgisonline.com/ArcGIS/rest/services/Ocean_Basemap/MapServer/tile/{z}/{y}/{x}"
        attribution="Tiles &copy; Esri &mdash; Sources: GEBCO, NOAA, CHS, OSU, UNH, CSUMB, National Geographic, DeLorme, NAVTEQ, and Esri'">
      </l-tile-layer>
      <l-control position="topright">
        <Legend :counts="counts" v-if="theme && !loading"></Legend>
      </l-control>
    </l-map>
    <MapLayer v-if="ready && !loading"></MapLayer>
    <MapSelector v-if="ready"></MapSelector>
  </div>
</template>

<script>
import { LMap, LTileLayer, LControlScale, LControl } from 'vue2-leaflet'
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
      ready: false
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
    LTileLayer,
    LControlScale,
    LControl
  },
  mounted () {
    this.map = this.$refs.map.mapObject

    this.zoomMinControl = new ZoomMin({ minBounds: this.map.getBounds() })
    this.map.addControl(this.zoomMinControl)

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
    setBounds (bounds) {
      this.map.invalidateSize()
      const latLngBounds = new L.latLngBounds([ // eslint-disable-line
        [bounds[0][1], bounds[0][0]],
        [bounds[1][1], bounds[1][0]]
      ])
      this.zoomMinControl.options.minBounds = latLngBounds
      this.map.fitBounds(latLngBounds)
    },
    onZoom () {
      evt.$emit('map:zoom', this.map.getZoom())
    }
  }
}
</script>
