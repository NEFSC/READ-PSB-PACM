<template>
  <v-app>
    <v-app-bar
      app
      color="light-blue darken-4"
      clipped-left
      dark>
      <v-app-bar-nav-icon v-if="$vuetify.breakpoint.mobile" @click="drawer = !drawer"></v-app-bar-nav-icon>
      <v-icon color="white" dark class="mr-4" v-if="!$vuetify.breakpoint.mobile">$whale</v-icon>
      <v-toolbar-title v-if="!$vuetify.breakpoint.mobile">Passive Acoustic Cetacean Map</v-toolbar-title>
      <v-toolbar-title v-else class="font-weight-bold">PACM</v-toolbar-title>

      <v-spacer></v-spacer>

      <v-dialog
        v-model="dialogs.about"
        max-width="1000"
        scrollable
        :fullscreen="$vuetify.breakpoint.mobile">
        <template v-slot:activator="{ on }">
          <v-btn color="default" dark text v-on="on" data-v-step="about-button" aria-label="about page">
            <v-icon :left="!$vuetify.breakpoint.mobile">mdi-information-outline</v-icon>
            <span v-if="!$vuetify.breakpoint.mobile"> About</span>
          </v-btn>
        </template>
        <AboutDialog @close="closeAbout"></AboutDialog>
      </v-dialog>

      <v-dialog
        v-model="dialogs.guide"
        max-width="1200"
        scrollable
        :fullscreen="$vuetify.breakpoint.mobile">
        <template v-slot:activator="{ on }">
          <v-btn color="default" dark text v-on="on" data-v-step="user-guide-button" aria-label="user guide">
            <v-icon :left="!$vuetify.breakpoint.mobile">mdi-book-open-variant</v-icon>
            <span v-if="!$vuetify.breakpoint.mobile"> User Guide</span>
          </v-btn>
        </template>
        <UserGuideDialog @close="closeGuide"></UserGuideDialog>
      </v-dialog>

      <v-btn color="default" dark text @click="startTour" data-v-step="tour-button" v-if="!$vuetify.breakpoint.mobile" aria-label="start tour">
        <v-icon :left="!$vuetify.breakpoint.mobile">mdi-cursor-default-click</v-icon>
        <span v-if="!$vuetify.breakpoint.mobile"> Tour</span>
      </v-btn>

      <div>
        <v-img src="./assets/img/noaa-logo.gif" height="40px" width="40px" class="ma-2" alt="NOAA Logo"></v-img>
      </div>
    </v-app-bar>

    <v-navigation-drawer
      app
      dark
      clipped
      :permanent="!$vuetify.breakpoint.mobile"
      color="blue-grey darken-4"
      width="500"
      v-model="drawer">
      <v-list class="mt-4 py-0">
        <v-list-item v-if="$vuetify.breakpoint.mobile">
          <v-list-item-content class="pb-0" >
            <div class="d-flex">
              <v-spacer></v-spacer>
              <v-btn icon small class="float-right" color="grey" @click="drawer = !drawer" aria-label="close"><v-icon>mdi-close</v-icon></v-btn>
            </div>
          </v-list-item-content>
        </v-list-item>
        <v-list-item class="my-1" data-v-step="theme">
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

        <v-list-item class="my-1" data-v-step="platform">
          <v-list-item-content>
            <PlatformTypeFilter></PlatformTypeFilter>
          </v-list-item-content>
        </v-list-item>

        <v-divider class="my-4"></v-divider>

        <v-alert
          type="info"
          color="grey darken-3"
          border="left"
          class="my-6 mb-4 py-1 mx-4 body-2"
          v-if="theme.showSpeciesFilter">
          For {{ theme.label }}, recorded days are counted separately for each species. If two species were detected on the same day, then that day would be counted twice in the charts below.
        </v-alert>

        <v-list-item class="mt-0" data-v-step="season">
          <v-list-item-content class="pt-1">
            <SeasonFilter :y-axis-label="yAxisLabel"></SeasonFilter>
          </v-list-item-content>
        </v-list-item>

        <v-list-item class="mt-2" data-v-step="year">
          <v-list-item-content class="py-0">
            <YearFilter :y-axis-label="yAxisLabel"></YearFilter>
          </v-list-item-content>
        </v-list-item>

        <v-list-item class="mt-2" data-v-step="detection">
          <v-list-item-content class="py-0" v-if="!theme.deploymentsOnly">
            <DetectionFilter :y-axis-label="yAxisLabel"></DetectionFilter>
          </v-list-item-content>
        </v-list-item>
      </v-list>
    </v-navigation-drawer>

    <v-main data-v-step="map" style="z-index:0">
      <div style="height:100%;position:relative">
        <Map :counts="counts"></Map>
        <div style="position:absolute;bottom:0;left:0;width:100%;z-index:1000;background:white;max-height:600px" v-if="selectedDeployments.length > 0">
          <DeploymentDetail></DeploymentDetail>
        </div>
      </div>
    </v-main>

    <v-dialog
      v-model="loadingFailed"
      max-width="600"
      scrollable
      persistent>
      <v-alert type="error" :value="true" prominent class="mb-0">
        <div class="text-h6">Failed to Load Dataset</div>
        <p class="body-1">
          An error occurred fetching the dataset from the server.
          Please refresh and try again.
          If the problem continues, please contact us at <a href="mailto:nmfs.pacmdata@noaa.gov">nmfs.pacmdata@noaa.gov</a>.
        </p>
      </v-alert>
    </v-dialog>

    <v-tour name="tour" :steps="tour.steps" :options="tour.options">
      <template slot-scope="tour">
        <transition name="fade">
          <v-step
            v-if="tour.steps[tour.currentStep]"
            :key="tour.currentStep"
            :step="tour.steps[tour.currentStep]"
            :previous-step="tour.previousStep"
            :next-step="tour.nextStep"
            :stop="tour.stop"
            :skip="tour.skip"
            :is-first="tour.isFirst"
            :is-last="tour.isLast"
            :labels="tour.labels"
            :style="{ 'max-width': (tour.currentStep === 0 ? '650px' : '450px') }"
          >
          </v-step>
        </transition>
      </template>
    </v-tour>
  </v-app>
</template>

<script>
import { mapActions, mapGetters } from 'vuex'

import Map from '@/components/Map'
import AboutDialog from '@/components/dialogs/About'
import UserGuideDialog from '@/components/dialogs/UserGuide'
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
import tour from '@/lib/tour'

export default {
  name: 'App',
  components: {
    AboutDialog,
    UserGuideDialog,
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
      drawer: null,
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
        guide: false
      },
      tour: {
        options: {
          labels: {
            buttonSkip: 'Close tour',
            buttonPrevious: 'Previous',
            buttonNext: 'Next',
            buttonStop: 'Finish'
          }
        },
        steps: tour
      }
    }
  },
  computed: {
    ...mapGetters(['theme', 'loading', 'loadingFailed', 'selectedDeployments']),
    showDialog () {
      return !!this.deployments.selected
    },
    yAxisLabel () {
      return '# Days Recorded'
    }
  },
  mounted () {
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
    ...mapActions(['setTheme', 'selectDeployments']),
    init () {
      if (this.$route.params.id) {
        this.dialogs.about = false
        const theme = themes.find(d => d.id === this.$route.params.id)
        if (!theme) return this.$store.commit('SET_LOADING_FAILED', true)
        this.setTheme(theme)
      } else {
        this.dialogs.about = true
      }
    },
    closeAbout (evt) {
      this.dialogs.about = false
      if (evt && evt.guide) {
        this.dialogs.guide = true
      } else if (evt && evt.tour) {
        if (!this.theme) {
          this.setTheme(this.themes[1])
            .then(() => this.startTour())
        } else {
          this.startTour()
        }
      } else if (!this.theme) {
        this.setTheme(this.themes[1])
      }
    },
    closeGuide () {
      this.dialogs.guide = false
      if (!this.theme) {
        this.dialogs.about = true
      }
    },
    onFiltered () {
      // unselect deployments that no longer have any filtered detections
      if (this.selectedDeployments.length > 0) {
        const deploymentCounts = this.selectedDeployments.map(d => ({ id: d.id, ...deploymentMap.get(d.id) }))
        const newSelection = deploymentCounts.filter(d => d.total > 0)
        if (newSelection.length < this.selectedDeployments.length) {
          this.selectDeployments(newSelection.map(d => d.id))
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
      this.$tours.tour.start()
    }
  }
}
</script>
