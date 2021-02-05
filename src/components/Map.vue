<template>
  <div style="height:100%;">
    <v-overlay :value="loading" style="z-index:10000">
      <v-progress-circular
        indeterminate
        size="64"
      ></v-progress-circular>
    </v-overlay>
    <l-map
      ref="map"
      style="width:100%;height:100%"
      :center="[49, -50]"
      :zoom="$vuetify.breakpoint.mobile ? 2 : 4"
      :options="{ zoomControl: false }"
      @zoomend="onZoom">
      <l-control-scale position="bottomleft"></l-control-scale>
      <l-tile-layer
        url="//server.arcgisonline.com/ArcGIS/rest/services/Ocean_Basemap/MapServer/tile/{z}/{y}/{x}"
        attribution="Tiles &copy; Esri &mdash; Sources: GEBCO, NOAA, CHS, OSU, UNH, CSUMB, National Geographic, DeLorme, NAVTEQ, and Esri'">
      </l-tile-layer>
      <l-control position="topright">
        <v-dialog
          v-model="legendDialog"
          scrollable
          :fullscreen="$vuetify.breakpoint.mobile"
          v-if="$vuetify.breakpoint.mobile">
          <template v-slot:activator="{ on }">
            <v-btn color="default" v-on="on">
              Show Legend
            </v-btn>
          </template>

          <v-card>
            <v-card-text class="pt-4">
              <Legend :counts="counts" v-if="theme && !loading"></Legend>
              <div v-else>
                Loading...
              </div>
            </v-card-text>

            <v-card-actions>
              <v-spacer></v-spacer>
              <v-btn color="primary" text @click.native="legendDialog = false">Close</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>
        <Legend :counts="counts" v-if="theme && !loading && !$vuetify.breakpoint.mobile"></Legend>
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
      ready: false,
      legendDialog: false
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

    this.map.addControl(new ZoomMin({ minBounds: this.map.getBounds() }))

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
  },
  methods: {
    onZoom () {
      evt.$emit('map:zoom', this.map.getZoom())
    }
  }
}
</script>

<style>
</style>
