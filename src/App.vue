<template>
  <v-app>
    <v-navigation-drawer
      v-model="drawer"
      app
      clipped
      width="500">
      <v-list>
        <v-list-item>
          <v-list-item-content>
            <v-subheader>Filter Count: {{ count.toLocaleString() }}</v-subheader>
          </v-list-item-content>
        </v-list-item>
        <v-list-item>
          <v-list-item-content>
            <v-subheader>Filter by Year</v-subheader>
            <div id="dc-year"></div>
          </v-list-item-content>
        </v-list-item>
        <v-list-item>
          <v-list-item-content>
            <v-subheader>Filter by Month</v-subheader>
            <div id="dc-month"></div>
          </v-list-item-content>
        </v-list-item>
        <v-list-item>
          <v-list-item-content>
            <v-subheader>Filter by Presence/Absence</v-subheader>
            <div id="dc-presence"></div>
          </v-list-item-content>
        </v-list-item>
        <!-- <v-list-item>
          <v-list-item-content>
            <v-subheader>Select Year Span</v-subheader>
            <v-range-slider
              min="2004"
              max="2019"
              step="1"
              ticks
              tick-size="2"
              thumb-label="always"
              :tick-labels="[2004, '', '', '', '', '', '', '', '', '', '', '', '', '', '', 2019]"
              v-model="yearSpan"
              @input="inputYear"
              class="px-4 pt-8">
            </v-range-slider>
          </v-list-item-content>
        </v-list-item>
        <v-list-item>
          <v-list-item-content>
            <v-subheader>Select Day Span</v-subheader>
            <v-range-slider
              min="1"
              max="365"
              step="1"
              thumb-label="always"
              thumb-size="32"
              v-model="daySpan"
              @input="inputDay"
              class="px-4 pt-8">
              <template v-slot:thumb-label="{ value }">
                <div class="text-center" v-html="dayLabel(value)"></div>
              </template>
            </v-range-slider>
          </v-list-item-content>
        </v-list-item> -->
      </v-list>
    </v-navigation-drawer>
    <v-app-bar
      app
      color="primary"
      clipped-left
      dark>
      <v-toolbar-title>North American Right Whale PAM</v-toolbar-title>
    </v-app-bar>

    <v-content>
      <v-container class="fill-height" fluid align-start v-if="!auth.dialog">
        <v-row v-if="loading">
          <v-col xs="12">
            <v-progress-circular
              :size="50"
              :width="7"
              color="primary"
              indeterminate
            ></v-progress-circular>
            <h1>Loading</h1>
          </v-col>
        </v-row>
        <v-row>
          <v-col xs="12">
            <l-map
              ref="map"
              style="width:1000px;height:600px"
              :center="[39, -68]"
              :zoom="5"
              @moveend="draw"
              @zoomend="draw">
              <l-tile-layer url="//{s}.tile.osm.org/{z}/{x}/{y}.png"></l-tile-layer>
            </l-map>
          </v-col>
        </v-row>
        <v-row align="start">
          <v-col xs="12" >
            <div id="dc-stack"></div>
          </v-col>
        </v-row>
      </v-container>
      <v-dialog
        v-model="auth.dialog"
        fullscreen
        hide-overlay
        persistent
        transition="dialog-bottom-transition"
        style="z-index:50000">
        <v-card>
          <v-card-text>
            <v-container class="fill-height" fluid>
              <v-row align="center" justify="center">
                <v-col cols="12" sm="8" md="4">
                  <v-card class="elevation-12">
                    <v-toolbar
                      color="primary"
                      dark
                      flat>
                      <v-toolbar-title>Login Required</v-toolbar-title>
                    </v-toolbar>
                    <v-form @submit.prevent="login">
                      <v-card-text>
                        <v-text-field
                          id="password"
                          label="Password"
                          name="password"
                          v-model="auth.password"
                          prepend-icon="mdi-lock"
                          type="password"
                          required />
                      </v-card-text>
                      <v-card-actions>
                        <v-spacer />
                        <v-btn color="primary" @click="login">Login</v-btn>
                      </v-card-actions>
                    </v-form>
                    <v-alert type="error" :value="auth.error">
                      Password is incorrect
                    </v-alert>
                  </v-card>
                </v-col>
              </v-row>
            </v-container>
          </v-card-text>
        </v-card>
      </v-dialog>
    </v-content>

    <v-footer app>
      <span>&copy; 2019</span>
    </v-footer>
  </v-app>
</template>

<script>
import moment from 'moment'
import axios from 'axios'
import * as d3 from 'd3'
import d3Tip from 'd3-tip'
import L from 'leaflet'
import crossfilter from 'crossfilter2'
import dc from 'dc'

import { LMap, LTileLayer } from 'vue2-leaflet'

const xf = crossfilter()

const yearDim = xf.dimension(d => d.year)
const dayDim = xf.dimension(d => d.day)
const deploymentDim = xf.dimension(d => d.deployment_id)
const deploymentGroup = deploymentDim.group().reduce(
  (p, v) => {
    p.project = v.project
    p.site_id = v.site_id
    p.latitude = v.latitude
    p.longitude = v.longitude
    p.count += 1
    p.detections += v.detections
    return p
  },
  (p, v) => {
    p.count -= 1
    p.detections -= v.detections
    return p
  },
  () => ({
    latitude: null,
    longitude: null,
    count: 0,
    detections: 0
  })
)

const colorScale = d3.scaleSequential(d3.interpolateViridis).domain([0, 50])

export default {
  name: 'App',
  components: {
    LMap,
    LTileLayer
  },
  data: () => ({
    loading: true,
    drawer: true,
    yearSpan: [2008, 2016],
    daySpan: [1, 365],
    count: 0,
    auth: {
      dialog: true,
      password: null,
      error: false
    }
  }),
  mounted () {
  },
  methods: {
    init () {
      const map = this.$refs.map.mapObject
      const svgLayer = L.svg()
      map.addLayer(svgLayer)

      const svg = d3.select(svgLayer.getPane()).select('svg')
        .classed('leaflet-zoom-animated', false)
        .classed('leaflet-zoom-hide', true)
        .classed('map', true)
        .attr('pointer-events', null)
      this.container = svg.select('g')

      this.tip = d3Tip()
        .attr('class', 'd3-tip')
        .direction('e')
        .html(d => `
          Project: ${d.value.project}<br>
          Site ID: ${d.value.site_id}<br>
          Latitude: ${d.value.latitude.toFixed(4)}<br>
          Longitude: ${d.value.longitude.toFixed(4)}<br>
        `)
      this.container.call(this.tip)

      xf.onChange(() => {
        this.count = xf.allFiltered().length
      })

      this.loadData()
        .then(this.draw)
        .then(() => {
          this.loading = false
        })
    },
    inputYear (v) {
      yearDim.filterRange(v)
      this.updateFill()
    },
    inputDay (v) {
      dayDim.filterRange(v)
      this.updateFill()
    },
    loadData () {
      return axios.get('data/narw.csv')
        .then((response) => response.data)
        .then(this.parseData)
        .then((data) => {
          xf.add(data)
        })
        .then(() => {
          const dim = xf.dimension(d => d.year)
          const group = dim.group().reduceCount()
          const timeExtent = d3.extent(xf.all().map(d => d.year))
          timeExtent[0] = timeExtent[0] - 1
          timeExtent[1] = timeExtent[1] + 1

          const chart = dc.barChart('#dc-year')
            .width(468)
            .height(160)
            .margins({ top: 0, right: 40, bottom: 40, left: 40 })
            .dimension(dim)
            .group(group)
            .elasticY(true)
            .x(d3.scaleLinear().domain(timeExtent))
            .round(dc.round.floor)
            .on('filtered', this.updateFill)
          chart.xAxis().ticks(10).tickFormat(v => {
            return (v % 2 > 0) ? '' : d3.format('d')(v)
          })
          // chart.yAxis().ticks(0)

          chart.render()
        })
        .then(() => {
          const dim = xf.dimension(d => d.month)
          const group = dim.group().reduceCount()
          const timeExtent = [1, 12]

          const chart = dc.barChart('#dc-month')
            .width(468)
            .height(160)
            .margins({ top: 0, right: 40, bottom: 40, left: 40 })
            .dimension(dim)
            .group(group)
            .elasticY(true)
            .x(d3.scaleLinear().domain(timeExtent))
            .round(dc.round.round)
            .on('filtered', this.updateFill)

          chart.render()
        })
        .then(() => {
          const dim = xf.dimension(d => d.presence)
          const group = dim.group().reduceCount()

          const chart = dc.rowChart('#dc-presence')
            .width(468)
            .height(160)
            // .margins({ top: 20, right: 20, bottom: 0, left: 20 })
            .dimension(dim)
            .group(group)
            .elasticX(true)
            .ordinalColors(d3.range(3).map(d => d3.schemeCategory10[0]))
            // .gap(5)
            // .fixedBarHeight(20)
            .on('filtered', this.updateFill)

          chart.render()
        })
        .then(() => {
          const dim = xf.dimension(d => d.day)
          const group = dim.group().reduce(
            (p, v) => {
              p[v.presence] = (p[v.presence] || 0) + 1
              return p
            },
            (p, v) => {
              p[v.presence] = (p[v.presence] || 0) - 1
              return p
            },
            () => {
              return {
                yes: 0,
                no: 0,
                maybe: 0
              }
            }
          )

          const chart = dc.barChart('#dc-stack')
            .width(1000)
            .height(300)
            .margins({ top: 0, right: 75, bottom: 40, left: 40 })
            .dimension(dim)
            .group(group, 'yes', (d) => d.value.yes)
            .colors(d3.scaleOrdinal().range(['red', 'orange', 'gray']))
            .elasticY(true)
            // .brushOn(false)
            .x(d3.scaleLinear().domain([1, 366]))
            .xAxisLabel('Day of the Year')
            .yAxisLabel('# Recorders')
            .round(dc.round.round)
            .gap(0)
            // .title(function (d) {
            //   return d.key + '[' + this.layer + ']: ' + d.value[this.layer]
            // })
            .on('filtered', this.updateFill)

          chart.legend(dc.legend().x(950).y(100))

          dc.override(chart, 'legendables', () => {
            return chart._legendables().reverse()
          })

          chart.stack(group, 'maybe', d => d.value.maybe)
          chart.stack(group, 'no', d => d.value.no)

          chart.render()
        })
    },
    parseData (csv) {
      const data = d3.csvParse(csv, (d, i) => {
        d.$index = i
        d.latitude = +d.latitude
        d.longitude = +d.longitude
        d.detections = +d.detections
        d.duration_sec = +d.duration_sec
        d.start = moment.utc(d.start)
        d.end = moment.utc(d.end)
        d.year = d.start.year()
        d.day = d.start.dayOfYear()
        d.month = d.start.month()
        return d
      })
      return data
    },
    dayLabel (value) {
      return moment('2000-12-31').add(value, 'days').format('MMM D').replace(' ', '<br>')
    },
    draw () {
      if (!this.container) return
      const map = this.$refs.map.mapObject
      const zoom = map.getZoom()

      this.container
        .selectAll('circle')
        // .data(coord.slice(0, Math.floor(Math.random() * coord.length)))
        .data(deploymentGroup.all(), d => d.key)
        .join(
          enter => enter.append('circle'),
          update => update,
          exit => exit.remove()
        )
        .attr('r', zoom)
        .attr('cx', (d) => map.latLngToLayerPoint(new L.LatLng(d.value.latitude, d.value.longitude)).x)
        .attr('cy', (d) => map.latLngToLayerPoint(new L.LatLng(d.value.latitude, d.value.longitude)).y)
        // .on('click', d => console.log(d.value))
        .on('mouseenter', this.tip.show)
        .on('mouseout', this.tip.hide)
      this.updateFill()
    },
    updateFill () {
      this.container
        .selectAll('circle')
        .style('opacity', (d) => d.value.detections > 0 ? 0.9 : 0.2)
        .style('fill', (d) => d.value.detections > 0 ? colorScale(d.value.detections) : '#CCCCCC')
    },
    login () {
      if (this.auth.password === 'narw123') {
        this.auth.error = false
        this.auth.dialog = false
        setTimeout(() => {
          this.init()
        }, 500)
      } else {
        this.auth.error = true
      }
    }
  }
}
</script>

<style>
svg.map > g {
  pointer-events: visible;
  cursor: pointer;
}

.d3-tip {
  line-height: 1;
  padding: 10px;
  background: rgba(255, 255, 255, 0.5);
  color: #000;
  border-radius: 2px;
  pointer-events: none;
  font-family: sans-serif;
  z-index: 1000;
  margin-left: 20px;
}
</style>
