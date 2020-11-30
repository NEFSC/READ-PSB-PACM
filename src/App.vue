<template>
  <v-app>
    <v-app-bar
      app
      color="light-blue darken-3"
      clipped-left
      dark>
      <v-icon color="white" dark class="mr-4">$whale</v-icon>
      <v-toolbar-title>Passive Acoustic Cetacean Map</v-toolbar-title>

      <v-spacer></v-spacer>

      <v-dialog v-model="dialogs.about" max-width="1000" scrollable v-if="auth.isAuth">
        <template v-slot:activator="{ on }">
          <v-btn color="default" dark text max-width="120" class="mr-4" v-on="on">
            <v-icon left>mdi-information-outline</v-icon> About
          </v-btn>
        </template>
        <AboutDialog @close="closeAbout"></AboutDialog>
      </v-dialog>

      <v-dialog v-model="dialogs.help" max-width="1000" scrollable v-if="auth.isAuth">
        <template v-slot:activator="{ on }">
          <v-btn color="default" dark text max-width="120" class="mr-4" v-on="on">
            <v-icon left>mdi-video</v-icon> Tutorial
          </v-btn>
        </template>
        <HelpDialog @close="closeHelp"></HelpDialog>
      </v-dialog>

      <v-btn color="default" dark text max-width="120" @click="startTour" data-v-step="6" v-if="auth.isAuth">
        <v-icon left>mdi-cursor-default-click</v-icon> Tour
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
      <v-list class="pb-0">
        <v-list-item class="my-1" data-v-step="1">
          <v-list-item-content>
            <SelectTheme></SelectTheme>
          </v-list-item-content>
        </v-list-item>
      </v-list>
      <v-list class="pa-4" v-if="loading">
        <v-list-item>
          <v-spacer></v-spacer>
          <v-progress-circular
            indeterminate
            :size="32"
            :width="4"
            color="white"
            class="mr-4">
          </v-progress-circular>
          <v-list-item-content>
            <v-list-item-title class="title">Loading</v-list-item-title>
          </v-list-item-content>
          <v-spacer></v-spacer>
        </v-list-item>
      </v-list>
      <v-list class="pt-0" v-else-if="theme">
        <v-list-item class="my-1" v-if="theme.showSpeciesFilter">
          <v-list-item-content>
            <SpeciesFilter></SpeciesFilter>
          </v-list-item-content>
        </v-list-item>

        <v-list-item class="my-1" data-v-step="2">
          <v-list-item-content>
            <PlatformTypeFilter></PlatformTypeFilter>
          </v-list-item-content>
        </v-list-item>

        <v-divider class="my-4"></v-divider>

        <v-list-item class="mt-0" data-v-step="3">
          <v-list-item-content class="pt-1">
            <SeasonFilter :y-axis-label="yAxisLabel"></SeasonFilter>
          </v-list-item-content>
        </v-list-item>

        <v-list-item class="mt-2" data-v-step="4">
          <v-list-item-content class="py-0">
            <YearFilter :y-axis-label="yAxisLabel"></YearFilter>
          </v-list-item-content>
        </v-list-item>

        <v-list-item class="mt-2" data-v-step="5" v-if="!theme.deploymentsOnly">
          <v-list-item-content class="py-0">
            <DetectionFilter :y-axis-label="yAxisLabel"></DetectionFilter>
          </v-list-item-content>
        </v-list-item>

        <!-- DEBUG -->
        <v-list-item>
          <v-list-item-content>
            <!-- <pre>path: {{ $router.params.id }}</pre> -->
          </v-list-item-content>
        </v-list-item>
      </v-list>
    </v-navigation-drawer>

    <v-main data-v-step="0" style="z-index:0">
      <div v-if="auth.isAuth" style="height:100%;position:relative">
        <Map :counts="counts"></Map>
        <div style="position:absolute;bottom:0;left:0;width:100%;z-index:1000;background:white" v-if="!!selectedDeployment">
          <DeploymentDetail></DeploymentDetail>
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
import { mapActions, mapGetters } from 'vuex'

import Map from '@/components/Map'
import AboutDialog from '@/components/AboutDialog'
import HelpDialog from '@/components/HelpDialog'
import SelectTheme from '@/components/SelectTheme'
import YearFilter from '@/components/YearFilter'
import SpeciesFilter from '@/components/SpeciesFilter'
import PlatformTypeFilter from '@/components/PlatformTypeFilter'
import SeasonFilter from '@/components/SeasonFilter'
import DetectionFilter from '@/components/DetectionFilter'
import DeploymentDetail from '@/components/DeploymentDetail'

import evt from '@/lib/events'
import { xf, deploymentGroup, deploymentMap } from '@/lib/crossfilter'
import { themes } from '@/lib/constants'

export default {
  name: 'App',
  components: {
    AboutDialog,
    HelpDialog,
    Map,
    SelectTheme,
    YearFilter,
    PlatformTypeFilter,
    SpeciesFilter,
    SeasonFilter,
    DetectionFilter,
    DeploymentDetail
  },
  data () {
    return {
      themes,
      auth: {
        isAuth: false,
        password: null,
        error: null
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
      dialogs: {
        about: false,
        help: false
      },
      steps: [
        {
          target: '[data-v-step="0"]',
          content: `
          <h1 class="title">Welcome!</h1>
          This map shows the locations where whales were detected using passive acoustic monitoring.<br><br>
          Each circle represents a fixed location station (buoy or mooring). The color and size reflect the number of detection days at that station.<br><br>
          Detections using gliders or towed arrays are shown using square symbols.<br><br>
          For gliders, detections are aggregated by day. Each square shows the average location of all detections that occured during a single day.<br><br>
          For towed arrays, detections are <b>not</b> aggregated by day. Each square shows the location of a single detection.<br><br>
          <i>Hover over a point to view metadata about that project, or click on it to view a timeseries of detections.</i>
          `,
          params: {
            highlight: false,
            placement: 'bottom'
          }
        },
        {
          target: '[data-v-step="1"]',
          content: `<i>Switch to a different species or group.</i>`,
          params: {
            highlight: true,
            placement: 'top'
          }
        },
        {
          target: '[data-v-step="2"]',
          content: '<i>Choose which platform types to include.</i>',
          params: {
            highlight: true,
            placement: 'top'
          }
        },
        {
          target: '[data-v-step="3"]',
          content: `
            Chart shows the total number of detection days among all deployments and over all years during each week of the year.<br><br>
            <i>Click and drag on the bottom slider to filter for a specific seasonal period. Or click the start/end dates in the title to manually adjust.</i>
          `,
          params: {
            highlight: true,
            placement: 'bottom'
          }
        },
        {
          target: '[data-v-step="4"]',
          content: `
            Chart shows the number of detection days per year among all stations.<br><br>
            <i>Click and drag on the chart to filter for a specific range of years. Or click the start/end years in the title to manually adjust.</i>
          `,
          params: {
            highlight: true,
            placement: 'bottom'
          }
        },
        {
          target: '[data-v-step="5"]',
          content: `
            Chart shows the total number of days for each detection type among all stations.<br><br>
            <i>Click on one or more bars to filter the dataset for specific detection type(s).</i>
          `,
          params: {
            highlight: true,
            placement: 'bottom'
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
    ...mapGetters(['theme', 'loading', 'selectedDeployment']),
    showDialog () {
      return !!this.deployments.selected
    },
    yAxisLabel () {
      return '# Days Recorded'
    }
  },
  mounted () {
    if (process.env.NODE_ENV === 'development') {
      this.auth.isAuth = true
    }
    this.init()

    evt.$on('xf:filtered', this.onFiltered)
  },
  beforeDestroy () {
    evt.$off('xf:filtered', this.onFiltered)
  },
  watch: {
    theme () {
      evt.$emit('reset:filters', 'app:loadData')
      this.counts.detections.total = xf.size()
      this.counts.deployments.total = this.$store.getters.deployments.length
      if (this.$route.path === '/' || !this.theme || this.$route.params.id !== this.theme.id) {
        this.$router.push({ path: this.theme.id || '/' })
      }
    }
  },
  methods: {
    ...mapActions(['setTheme', 'selectDeployment']),
    init () {
      if (!this.auth.isAuth) return
      if (this.$route.params.id) {
        this.dialogs.about = false
        const theme = themes.find(d => d.id === this.$route.params.id)
        if (!theme) return alert(`Invalid URL, theme ${theme} not found`)
        this.setTheme(theme)
      } else {
        this.dialogs.about = true
      }
    },
    closeAbout (evt) {
      this.dialogs.about = false
      if (evt && evt.tutorial) {
        this.dialogs.help = true
      } else if (evt && evt.tour) {
        if (!this.theme) {
          this.setTheme(this.themes[0])
            .then(() => this.startTour())
        } else {
          this.startTour()
        }
      } else if (!this.theme) {
        this.setTheme(this.themes[0])
      }
    },
    closeHelp () {
      this.dialogs.help = false
      if (!this.theme) {
        this.dialogs.about = true
      }
    },
    onFiltered () {
      // unselect deployment if no longer has any filtered detections
      if (this.selectedDeployment) {
        let deployment = deploymentMap.get(this.selectedDeployment.id)
        if (deployment.total === 0) {
          this.selectDeployment()
        }
      }
      this.updateCounts()
    },
    updateCounts () {
      this.counts.detections.total = xf.size()
      this.counts.deployments.total = this.$store.getters.deployments.length
      this.counts.detections.filtered = xf.allFiltered().length
      this.counts.deployments.filtered = deploymentGroup.all().filter(d => d.value.total > 0).length
    },
    startTour () {
      this.$tours['tour'].start()
    },
    login () {
      if (this.auth.password === 'narw123') {
        this.auth.isAuth = true
        this.auth.error = false
        this.$nextTick(() => this.init())
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
  cursor: pointer;
}

.v-step {
  max-width: 400px !important;
  text-align: left !important;
}
</style>
