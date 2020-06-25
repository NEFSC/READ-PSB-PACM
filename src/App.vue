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

      <v-btn color="default" dark text max-width="120" @click="startTour" data-v-step="6">
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
        <v-list-item class="my-1" data-v-step="1">
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

        <v-list-item class="my-1" data-v-step="2">
          <v-list-item-content>
            <PlatformTypeFilter @update="setPlatformTypes"></PlatformTypeFilter>
          </v-list-item-content>
        </v-list-item>

        <v-divider class="my-4"></v-divider>

        <v-list-item class="mt-0" data-v-step="3">
          <v-list-item-content class="pt-1">
            <SeasonFilter @update="setSeason"></SeasonFilter>
          </v-list-item-content>
        </v-list-item>

        <v-list-item class="mt-2" data-v-step="4">
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

        <v-list-item class="mt-2" data-v-step="5">
          <v-list-item-content class="py-0">
            <DetectionFilter></DetectionFilter>
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
            :size="32"
            :width="4"
            color="white"
            class="mr-4"
          ></v-progress-circular>
          <v-list-item-content>
            <v-list-item-title class="title">Loading</v-list-item-title>
          </v-list-item-content>
        </v-list-item>
      </v-list>
    </v-navigation-drawer>

    <v-main data-v-step="0" style="z-index:0">
      <div v-if="auth.isAuth" style="height:100%;position:relative">
        <Map :points="deployments.data" :tracks="tracks.data" :counts="counts" @select="selectDeployment"></Map>
        <div style="position:absolute;bottom:0;left:0;width:100%;z-index:1000;background:white" v-if="!!deployments.selected">
          <DeploymentDetail :selected="deployments.selected" @close="selectDeployment()"></DeploymentDetail>
        </div>
      </div>
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
    </v-main>

    <v-tour name="tour" :steps="steps"></v-tour>
  </v-app>
</template>

<script>
import dc from 'dc'
import moment from 'moment'
import debounce from 'debounce'

import Map from '@/components/Map'
import YearFilter from '@/components/YearFilter'
import PlatformTypeFilter from '@/components/PlatformTypeFilter'
import SeasonFilter from '@/components/SeasonFilter'
import DetectionFilter from '@/components/DetectionFilter'
import DeploymentDetail from '@/components/DeploymentDetail'

import evt from '@/lib/events'
import { fetchData } from '@/lib/utils'
import { xf, setData } from '@/lib/crossfilter'
import { speciesTypes } from '@/lib/constants'

export default {
  name: 'App',
  components: {
    Map,
    YearFilter,
    PlatformTypeFilter,
    SeasonFilter,
    DetectionFilter,
    DeploymentDetail
  },
  data () {
    return {
      auth: {
        isAuth: false,
        password: null,
        error: null
      },
      sheet: true,
      loading: true,
      deployments: {
        data: [],
        dim: null,
        selected: undefined
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
      tracks: {
        data: []
      },
      dialogs: {
        about: false
      },
      steps: [
        {
          target: '[data-v-step="0"]',
          content: `
          <h1 class="title">Welcome!</h1>
          This map shows the locations where whales were detected using passive acoustic monitoring.<br><br>
          Each point represents either a fixed location station (buoy or mooring), or the location of a positive detection along a glider or towed array track.<br><br>
          The fixed location stations are sized by the number of detection days over the current season and year span.<br><br>
          <i>Hover over a point to view metadata about that project, or click on it to view a timeseries of detections.</i>
          `,
          params: {
            highlight: false,
            placement: 'bottom'
          }
        },
        {
          target: '[data-v-step="1"]',
          content: `Switch to a different species`,
          params: {
            highlight: true,
            placement: 'left'
          }
        },
        {
          target: '[data-v-step="2"]',
          content: 'Choose which platform types to include in the dataset',
          params: {
            highlight: true,
            placement: 'left'
          }
        },
        {
          target: '[data-v-step="3"]',
          content: `
            This chart shows the number of detections per week among all stations and over all years.<br>
            <i>Click and drag on the bottom timeline to filter dataset for a specific seasonal period.</i>
          `,
          params: {
            highlight: true,
            placement: 'left'
          }
        },
        {
          target: '[data-v-step="4"]',
          content: `
            Chart shows the number of detections per year among all stations.<br>
            <i>Click and drag on the chart to select a specific range of years.</i>
          `,
          params: {
            highlight: true,
            placement: 'left'
          }
        },
        {
          target: '[data-v-step="5"]',
          content: `
            Chart shows the total number of days for each detection type among all stations.<br>
            <i>Click on one or more bars to filter the dataset for specific detection type(s).</i>
          `,
          params: {
            highlight: true,
            placement: 'left'
          }
        },
        {
          target: '[data-v-step="6"]',
          content: 'Click here to start the tour again',
          params: {
            highlight: true,
            placement: 'bottom'
          }
        }
      ]
    }
  },
  computed: {
    showDialog () {
      return !!this.deployments.selected
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
      this.season.dim = xf.dimension(d => moment(d.date).dayOfYear())
      this.deployments.dim = xf.dimension(d => d.deployment)
      this.deployments.group = this.deployments.dim.group().reduceCount()
      this.loadData()
    },
    loadData () {
      console.log('app: loadData')
      if (!this.species.selected) return
      this.loading = true
      evt.$emit('reset:filters', 'app:loadData')
      this.selectDeployment()
      return fetchData(this.species.selected)
        .then(([deployments, detections, tracks]) => {
          this.deployments.data = Object.freeze(deployments)

          this.counts.detections.total = detections.length
          this.counts.deployments.total = deployments.length

          this.tracks.data = Object.freeze(tracks)

          setData(detections)

          this.loading = false
          // this.setSpecies()
          this.updateCounts()

          dc.redrawAll()

          // this.$nextTick(() => {
          //   evt.$emit('render:filter')
          //   evt.$emit('render:map')
          //   // this.startTour()
          // })
        })
    },
    selectDeployment (id) {
      console.log('app:selectDeployment()', id)
      if (!id) {
        this.deployments.selected = undefined
        return
      }
      if (this.deployments.selected && this.deployments.selected.id === id) {
        // unselect
        this.deployments.selected = undefined
        return
      }
      const deployment = this.deployments.data.find(d => d.deployment === id)
      const detections = xf.all().filter(d => d.deployment === id)
      const track = this.tracks.data.filter(d => d.deployment === id)
      this.deployments.selected = {
        id,
        deployment,
        detections,
        track
      }
    },
    setSpecies () {
      console.log('app: setSpecies')
      this.loadData()
    },
    setPlatformTypes () {
      console.log('app: setPlatformTypes')
      evt.$emit('render:map', 'setPlatformTypes')
      dc.redrawAll()
      this.updateCounts()
    },
    setSeason: debounce(function ([start, end]) {
      console.log('app: setSeason')
      this.season.start = start
      this.season.end = end === 365 ? 366 : end
      if (this.season.start <= this.season.end) {
        this.season.dim.filterRange([this.season.start, this.season.end + 0.01])
      } else {
        this.season.dim.filterFunction(d => d >= this.season.start || d <= this.season.end)
      }
      evt.$emit('render:map', 'setSeason')
      dc.redrawAll()
    }, 1, true),
    updateCounts () {
      console.log('app: updateCounts')
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

.filter-value {
  border-bottom: 1px solid #546E7A;
  border-bottom-style: dashed;
}
</style>
