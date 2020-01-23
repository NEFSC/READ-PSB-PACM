<template>
  <v-app>
    <v-app-bar
      app
      color="light-blue darken-3"
      clipped-left
      dark>
      <v-icon color="white" dark class="mr-4">$whale</v-icon>
      <v-toolbar-title>Passive Acoustic Whale Map</v-toolbar-title>

      <v-spacer></v-spacer>

      <v-dialog v-model="dialogs.about" max-width="800">
        <template v-slot:activator="{ on }">
          <v-btn color="default" dark text max-width="120" class="mr-4" v-on="on">
            <v-icon left>mdi-information</v-icon> About
          </v-btn>
        </template>
        <v-card>
          <v-img src="./assets/img/noaa-logo.gif" height="54px" width="54px" style="float:right" class="ma-2"></v-img>
          <v-list-item>
            <v-list-item-content>
              <v-list-item-title class="headline">Welcome to the Passive Acoustic Whale Map</v-list-item-title>
              <v-list-item-subtitle>by the <a href="https://www.nefsc.noaa.gov/psb/acoustics/index.html">NOAA Northeast Fisheries Science Center</a></v-list-item-subtitle>
            </v-list-item-content>
          </v-list-item>
          <v-img
            src="./assets/img/whale.jpg"
            height="200px">
          </v-img>
          <v-card-text class="mt-8 body-1 grey--text text--darken-4">
            <p class="font-weight-medium">
              The Passive Acoustic Whale Map shows you when and where specific whale species were observed in the Atlantic Ocean
              based on Passive Acoustic Monitoring (PAM).
            </p>
            <p>
              This application provides interactive data visualization tools for exploring PAM-based whale detection data.
            </p>
            <p>
              The dataset was compiled by the NOAA NEFSC Passive Acoustic Research Lab using observations collected from many collaborators.
            </p>
            <p>Designed and built by <a href="https://walkerenvres.com" target="_blank">Walker Environmental Research LLC</a>.</p>
          </v-card-text>
          <v-card-actions>
            <v-spacer></v-spacer>
            <v-btn color="primary" text @click.native="dialogs.about = false">Close</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>

      <v-btn color="default" dark text max-width="120" @click="startTour" data-v-step="3">
        <v-icon left>mdi-help-circle</v-icon> Help
      </v-btn>

      <div>
        <v-img src="./assets/img/noaa-logo.gif" height="50px" width="50px" class="ma-2"></v-img>
      </div>
    </v-app-bar>

    <v-navigation-drawer
      app
      dark
      clipped
      permanent
      color="blue-grey darken-4"
      width="500"
      v-if="auth.isAuth">
      <v-list v-if="!loading">
        <v-list-item class="mt-3" data-v-step="1">
          <v-list-item-content>
            <v-select
              outlined
              :items="species.options"
              v-model="species.selected"
              label="Select a species"
              item-text="label"
              item-value="id"
              hide-details
            ></v-select>
          </v-list-item-content>
        </v-list-item>

        <v-divider class="my-4"></v-divider>

        <v-list-item class="mt-3" data-v-step="1">
          <v-list-item-content>
            <v-select
              outlined
              :items="platforms.options"
              v-model="platforms.selected"
              label="Select platform type(s)"
              item-text="label"
              item-value="id"
              hide-details
              multiple
              chips
              deletable-chips
            ></v-select>
          </v-list-item-content>
        </v-list-item>

        <v-list-item class="mt-2">
          <v-list-item-content>
            <SeasonFilter @update="setSeason"></SeasonFilter>
          </v-list-item-content>
        </v-list-item>

        <v-list-item data-v-step="2" class="mt-2">
          <v-list-item-content class="py-0">
            <YearFilter></YearFilter>
          </v-list-item-content>
        </v-list-item>

        <!-- <v-list-item>
          <v-list-item-content class="py-2">
            <div class="subtitle-1 font-weight-bold">Filter By Month</div>
            <MonthFilter></MonthFilter>
          </v-list-item-content>
        </v-list-item> -->

        <v-list-item class="mt-2">
          <v-list-item-content class="py-0">
            <DetectionFilter></DetectionFilter>
          </v-list-item-content>
        </v-list-item>

        <v-list-item class="mt-2">
          <v-list-item-content class="py-0">
            <v-list-item-title class="subtitle-1 font-weight-medium">Dataset Summary</v-list-item-title>
            <div class="ml-4 body-2">
              {{ counts.detections.filtered.toLocaleString() }} of {{ counts.detections.total.toLocaleString() }} Recorded Days
            </div>
            <div class="ml-4 body-2">
              {{ counts.deployments.filtered.toLocaleString() }} of {{ counts.deployments.total.toLocaleString() }} Monitoring Stations
            </div>
          </v-list-item-content>
        </v-list-item>

        <!-- DEBUG -->
        <!-- <v-list-item>
          <v-list-item-content>
            <pre>species: {{ species.selected }}</pre>
            <pre>deployments: {{ deployments.length }}</pre>
            <pre>counts: {{ counts }}</pre>
          </v-list-item-content>
        </v-list-item> -->
      </v-list>
      <v-list v-else>
        <v-list-item>
          <v-progress-circular
            indeterminate
            :size="40"
            :width="10"
            color="white"
            class="mr-4"
          ></v-progress-circular>
          <v-list-item-content>
            <v-list-item-title class="title">Loading</v-list-item-title>
          </v-list-item-content>
        </v-list-item>
      </v-list>
    </v-navigation-drawer>

    <v-content data-v-step="0" style="z-index:0">
      <Map :points="deployments.data" v-if="auth.isAuth"></Map>
      <div v-else>
        <v-card class="mx-auto mt-8" max-width="600px" elevation="12">
          <v-toolbar
            color="light-blue darken-3"
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
              <v-btn color="light-blue darken-3" dark @click="login">Login</v-btn>
            </v-card-actions>
          </v-form>
          <v-alert type="error" :value="auth.error">
            Password is incorrect
          </v-alert>
        </v-card>
      </div>
    </v-content>

    <v-tour name="tour" :steps="steps"></v-tour>
  </v-app>
</template>

<script>
import dc from 'dc'
import * as d3 from 'd3'
import moment from 'moment'
import debounce from 'debounce'

import Map from '@/components/Map'
import YearFilter from '@/components/YearFilter'
// import MonthFilter from '@/components/MonthFilter'
import SeasonFilter from '@/components/SeasonFilter'
import DetectionFilter from '@/components/DetectionFilter'

import evt from '@/lib/events'
import { fetchData } from '@/lib/utils'
import { xf, setData, speciesDim } from '@/lib/crossfilter'
import { speciesTypes, platformTypes } from '@/lib/constants'

export default {
  name: 'App',
  components: {
    Map,
    YearFilter,
    // MonthFilter,
    SeasonFilter,
    DetectionFilter
  },
  data () {
    return {
      auth: {
        isAuth: false,
        password: null,
        error: null
      },
      loading: true,
      deployments: {
        data: [],
        dim: null
      },
      counts: {
        detections: {
          filtered: 0,
          total: 0,
          totals: {}
        },
        deployments: {
          filtered: 0,
          total: 0,
          totals: {}
        }
      },
      season: {
        start: 1,
        end: 365,
        dim: null
      },
      species: {
        selected: speciesTypes[0].id,
        options: speciesTypes
      },
      platforms: {
        selected: platformTypes.map(d => d.id),
        options: platformTypes
      },
      dialogs: {
        about: false
      },
      steps: [
        {
          target: '[data-v-step="0"]',
          content: `
          <h1 class="title">Welcome!</h1>
          The map shows which stations the whales were detected.<br>
          <i>Hover over a station to view its metadata.</i>
          `,
          params: {
            highlight: false,
            placement: 'bottom'
          }
        },
        {
          target: '[data-v-step="1"]',
          content: `Switch species here`,
          params: {
            highlight: true,
            placement: 'bottom'
          }
        },
        {
          target: '[data-v-step="2"]',
          content: 'Click and drag on the charts to filter dataset for a specific time period',
          params: {
            highlight: true,
            placement: 'bottom'
          }
        },
        {
          target: '[data-v-step="3"]',
          content: 'Click here to start the tour again',
          params: {
            highlight: true,
            placement: 'bottom'
          }
        }
      ]
    }
  },
  mounted () {
    if (process.env.NODE_ENV === 'development') {
      this.auth.isAuth = true
      this.init()
    }
    evt.$on('render:map', this.updateCounts)
  },
  beforeDestroy () {
    evt.$off('render:map', this.updateCounts)
    this.season.dim && this.season.dim.dispose()
    this.deployments.dim && this.deployments.dim.dispose()
  },
  watch: {
    'species.selected' () {
      this.setSpecies()
    }
  },
  methods: {
    init () {
      fetchData()
        .then(([deployments, detections]) => {
          this.deployments.data = deployments

          d3.nest()
            .key(d => d.species)
            .rollup(v => v.length)
            .entries(detections)
            .forEach(d => {
              this.counts.detections.totals[d.key] = d.value
            })

          d3.nest()
            .key(d => d.species)
            .key(d => d.deployment)
            .rollup(v => v.length)
            .entries(detections)
            .forEach(d => {
              this.counts.deployments.totals[d.key] = d.values.length
            })

          setData(detections)

          this.season.dim = xf.dimension(d => moment(d.date).dayOfYear())
          this.deployments.dim = xf.dimension(d => d.deployment)
          this.deployments.group = this.deployments.dim.group().reduceCount()

          this.loading = false
          this.setSpecies()

          this.$nextTick(() => {
            evt.$emit('render:filter')
            evt.$emit('render:map')
            // this.startTour()
          })
        })
    },
    setSpecies () {
      speciesDim.filterExact(this.species.selected)
      evt.$emit('render:map')
      dc.redrawAll()
      this.counts.detections.total = this.counts.detections.totals[this.species.selected]
      this.counts.deployments.total = this.counts.deployments.totals[this.species.selected]
      this.updateCounts()
    },
    setSeason: debounce(function ([start, end]) {
      this.season.start = start
      this.season.end = end === 365 ? 366 : end
      if (this.season.start <= this.season.end) {
        this.season.dim.filterRange([this.season.start, this.season.end + 0.01])
      } else {
        this.season.dim.filterFunction(d => d >= this.season.start || d <= this.season.end)
      }
      evt.$emit('render:map')
      dc.redrawAll()
    }, 1, true),
    updateCounts () {
      this.counts.detections.filtered = xf.allFiltered().length
      this.counts.deployments.filtered = this.deployments.group.all().filter(d => d.value > 0).length
    },
    startTour () {
      this.$tours['tour'].start()
    },
    login () {
      if (this.auth.password === 'narw123') {
        this.auth.isAuth = true
        this.auth.error = false
        this.init()
      } else {
        this.auth.error = true
      }
    }
  }
}
</script>

<style>
a {
  text-decoration:none;
}
.dc-chart .axis path, .dc-chart .axis line {
  stroke: hsl(0, 0%, 75%) !important;
}
.dc-chart rect.bar {
  fill: #CFD8DC !important;
}
.dc-chart rect.bar.deselected {
  fill: #455A64 !important;
}
.dc-chart rect {
  fill-opacity: 0.8;
}
.dc-chart .row rect.deselected {
  fill: #455A64 !important;
}
.dc-chart .y-axis-label.y-label {
  fill: hsl(0, 0%, 90%) !important;
  font-weight: 600 !important;
  font-size: 10pt !important;
}
.dc-chart .x-axis-label {
  fill: hsl(0, 0%, 90%) !important;
  font-weight: 600 !important;
  font-size: 10pt !important;
}
.dc-chart .axis.y text {
  fill: hsl(0, 0%, 90%) !important;
  font-weight: 600 !important;
}
.dc-chart .axis.x text {
  fill: hsl(0, 0%, 90%) !important;
  font-weight: 400 !important;
  font-size: 10pt !important;
  text-anchor: middle;
}
</style>
