<template>
  <v-app>
    <v-app-bar
      color="light-blue-darken-4"
      role="navigation"
    >
      <template v-slot:prepend>
        <v-app-bar-nav-icon v-if="mobile" @click="drawer = !drawer"></v-app-bar-nav-icon>
      </template>
      <v-app-bar-title>
        <v-icon icon="custom:whale" class="mr-4"></v-icon>
        <template v-if="mobile">PACM</template>
        <template v-else>Passive Acoustic Cetacean Map <span style="font-size: 50%;" class="pl-1">v{{ version }}</span></template>
      </v-app-bar-title>
      
      <v-spacer></v-spacer>

      <v-dialog
        v-model="dialogs.about"
        max-width="1000"
        scrollable
        :fullscreen="mobile">
        <template v-slot:activator="{ props }">
          <v-btn
            color="default"
            variant="text"
            v-bind="props"
            data-v-step="about-button"
            aria-label="about page"
          >
            <v-icon :start="!mobile">mdi-information-outline</v-icon>
            <span v-if="!mobile"> About</span>
          </v-btn>
        </template>
        <AboutDialog @close="closeAbout"></AboutDialog>
      </v-dialog>

      <v-dialog
        v-model="dialogs.guide"
        max-width="1200"
        scrollable
        :fullscreen="mobile">
        <template v-slot:activator="{ props }">
          <v-btn color="default" variant="text" v-bind="props" data-v-step="user-guide-button" aria-label="user guide">
            <v-icon :start="!mobile">mdi-book-open-variant</v-icon>
            <span v-if="!mobile"> User Guide</span>
          </v-btn>
        </template>
        <UserGuideDialog @close="closeGuide"></UserGuideDialog>
      </v-dialog>

      <v-btn color="default" variant="text" @click="startTour" data-v-step="tour-button" aria-label="start tour" :disabled="mobile">
        <v-icon :start="!mobile">mdi-cursor-default-click</v-icon>
        <span v-if="!mobile"> Tour</span>
      </v-btn>

      <div>
        <v-img src="./assets/img/noaa-logo.gif" height="40px" width="40px" class="ma-2" alt="NOAA Logo"></v-img>
      </div>
    </v-app-bar>

    <v-navigation-drawer
      :permanent="!mobile"
      color="blue-grey-darken-4"
      theme="dark"
      width="500"
      v-model="drawer"
      role="complementary">
      <v-list class="mt-4 py-0">
        <v-list-item v-if="mobile">
          <div class="d-flex">
            <v-spacer></v-spacer>
            <v-btn icon size="small" class="float-right" color="grey" @click="drawer = !drawer" aria-label="close"><v-icon>mdi-close</v-icon></v-btn>
          </div>
        </v-list-item>
        <v-list-item class="my-1" data-v-step="theme">
          <SelectTheme></SelectTheme>
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
          <v-list-item-title class="text-h6">Loading</v-list-item-title>
          <v-spacer></v-spacer>
        </v-list-item>
      </v-list>
      <v-list class="pt-0" v-else-if="theme">
        <v-list-item class="my-1" v-if="theme.showSpeciesFilter">
          <SpeciesFilter></SpeciesFilter>
        </v-list-item>

        <v-list-item class="my-1" data-v-step="platform">
          <PlatformTypeFilter></PlatformTypeFilter>
        </v-list-item>

        <div class="text-right mx-4">
          <v-dialog
            v-model="dialogs.filters"
            max-width="600"
            scrollable
            persistent
            :fullscreen="mobile">
            <template v-slot:activator="{ props }">
              <v-btn
                color="default"
                size="small"
                variant="text"
                v-bind="props"
                aria-label="advanced filters"
                data-v-step="advanced"
              >Advanced Filters...</v-btn>
            </template>
            <FiltersDialog @close="dialogs.filters = false"></FiltersDialog>
          </v-dialog>
        </div>

        <v-divider class="my-4"></v-divider>

        <v-alert
          color="blue-grey-darken-3"
          border="start"
          density="compact"
          class="mx-4 mb-2 text-body-2 align-center">
          Selected period: {{ periodLabel }}
          <v-tooltip location="end" max-width="300" :open-delay="300">
            <template v-slot:activator="{ props }">
              <v-icon size="small" class="ml-1" v-bind="props">mdi-information-outline</v-icon>
            </template>
            <span>The selected period is determined by the season and year filters below. When the season wraps across years (e.g., Oct 1 – Mar 31), the period begins at the start of the season in the first selected year (Oct 1, 2020) and ends at the end of the season in the last selected year (Mar 31, 2022). This avoids showing partial seasons at the beginning of the first year (Jan 1 - Mar 31, 2020) and end of the last year (Oct 1 - Dec 31, 2022).</span>
          </v-tooltip>
        </v-alert>

        <v-list-item class="mt-0" data-v-step="season">
          <SeasonFilter :y-axis-label="yAxisLabel"></SeasonFilter>
        </v-list-item>

        <v-list-item class="mt-2" data-v-step="year">
          <YearFilter :y-axis-label="yAxisLabel"></YearFilter>
        </v-list-item>

        <v-list-item class="mt-2" data-v-step="detection">
          <div v-if="!theme.deploymentsOnly">
            <DetectionFilter :y-axis-label="yAxisLabel"></DetectionFilter>
          </div>
        </v-list-item>
      </v-list>
    </v-navigation-drawer>

    <div data-v-step="map"></div>
    <v-main style="z-index:0">
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
      <div>
        <v-alert type="error" prominent class="mb-0">
          <div class="text-h6">Failed to Load Dataset</div>
          <p class="text-body-1 mb-0">
            An error occurred fetching the dataset from the server.
            Please refresh and try again.
            If the problem continues, please contact us at <a href="mailto:nmfs.nec.pacmdata@noaa.gov" style="color:white">nmfs.nec.pacmdata@noaa.gov</a>.
          </p>
        </v-alert>
      </div>
    </v-dialog>

    <v-tour name="tour" :steps="tour.steps" :options="tour.options" role="main">
      <template v-slot="tour">
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
import { mapState, mapActions } from 'pinia'
import { useStore } from '@/store'
import { useDisplay } from 'vuetify'
import dayjs from 'dayjs'


import WhaleIcon from '@/components/WhaleIcon.vue'
import Map from '@/components/Map.vue'
import AboutDialog from '@/components/dialogs/About.vue'
import FiltersDialog from '@/components/dialogs/Filters.vue'
import UserGuideDialog from '@/components/dialogs/UserGuide.vue'
import SelectTheme from '@/components/SelectTheme.vue'
import YearFilter from '@/components/YearFilter.vue'
import SpeciesFilter from '@/components/SpeciesFilter.vue'
import PlatformTypeFilter from '@/components/PlatformTypeFilter.vue'
import SeasonFilter from '@/components/SeasonFilter.vue'
import DetectionFilter from '@/components/DetectionFilter.vue'
import DeploymentDetail from '@/components/DeploymentDetail.vue'

import evt from '@/lib/events'
import { xf, deploymentGroup, siteGroup, deploymentMap } from '@/lib/crossfilter'
import { themes } from '@/lib/constants'
import tour from '@/lib/tour'

export default {
  name: 'App',
  components: {
    AboutDialog,
    FiltersDialog,
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
  setup () {
    const { mobile, height } = useDisplay()
    return { mobile, displayHeight: height }
  },
  data () {
    return {
      version: typeof PACKAGE_VERSION !== 'undefined' ? PACKAGE_VERSION : process.env.PACKAGE_VERSION,
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
        },
        sites: {
          filtered: 0,
          total: 0
        }
      },
      dialogs: {
        about: false,
        guide: false,
        filters: false
      },
      period: {
        season: { start: 1, end: 365 },
        year: { start: null, end: null }
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
    ...mapState(useStore, ['theme', 'loading', 'loadingFailed', 'selectedDeployments', 'deployments', 'sites']),
    showDialog () {
      return !!this.deployments?.selected
    },
    yAxisLabel () {
      return '# Days Recorded'
    },
    periodActive () {
      const { season, year } = this.period
      return season.start > season.end && year.start !== null && year.end !== null
    },
    periodLabel () {
      const { season, year } = this.period
      const fmt = doy => dayjs('2000-12-31').add(doy, 'day').format('MMM D')
      const hasYear = year.start !== null && year.end !== null
      const startDate = fmt(season.start)
      const endDate = season.start > season.end && hasYear && year.start === year.end
        ? 'Dec 31'
        : fmt(season.end)
      const startLabel = hasYear ? startDate + ', ' + year.start : startDate
      const endLabel = hasYear ? endDate + ', ' + year.end : endDate
      return startLabel + ' \u2013 ' + endLabel
    }
  },
  mounted () {
    this.init()

    evt.on('xf:filtered', this.onFiltered)
    this._onSeason = (val) => { this.period.season = val; this.updatePeriodFilter() }
    this._onYear = (val) => { this.period.year = val; this.updatePeriodFilter() }
    evt.on('period:season', this._onSeason)
    evt.on('period:year', this._onYear)
  },
  beforeUnmount () {
    evt.off('xf:filtered', this.onFiltered)
    evt.off('period:season', this._onSeason)
    evt.off('period:year', this._onYear)
    if (this.periodDim) { this.periodDim.filterAll(); this.periodDim.dispose() }
  },
  watch: {
    theme () {
      if (this.periodDim) { this.periodDim.filterAll(); this.periodDim.dispose() }
      this.periodDim = xf.dimension(d => d.datekey)
      this.period.season = { start: 1, end: 365 }
      this.period.year = { start: null, end: null }
      evt.emit('reset:filters', 'app:loadData')
      this.counts.detections.total = xf.size()
      this.counts.deployments.total = this.deployments.length
      this.counts.sites.total = this.sites ? this.sites.length : 0
      if (this.$route.path === '/' || !this.theme || this.$route.params.id !== this.theme.id) {
        this.$router.push({ path: '/' + (this.theme.id || '') })
      }
    }
  },
  methods: {
    ...mapActions(useStore, ['setTheme', 'selectDeployments', 'fetchReferences']),
    init () {
      this.fetchReferences()
      if (this.$route.params.id) {
        this.dialogs.about = false
        const theme = themes.find(d => d.id === this.$route.params.id)
        if (!theme) {
          const store = useStore()
          store.loadingFailed = true
          return
        }
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
      this.counts.deployments.total = this.deployments.length
      this.counts.sites.total = this.sites ? this.sites.length : 0
      this.counts.detections.filtered = xf.allFiltered().length
      this.counts.deployments.filtered = deploymentGroup.all().filter(d => d.value.total > 0).length
      const siteIds = new Set((this.sites || []).map(d => d.site_id))
      this.counts.sites.filtered = siteGroup.all().filter(d => siteIds.has(d.key) && d.value.total > 0).length
    },
    updatePeriodFilter () {
      if (!this.periodDim) return
      const { season, year } = this.period
      if (season.start > season.end && year.start !== null && year.end !== null) {
        const startKey = year.start * 1000 + season.start
        const endKey = year.start < year.end
          ? year.end * 1000 + season.end
          : year.end * 1000 + 365
        this.periodDim.filterRange([startKey, endKey + 0.5])
      } else {
        this.periodDim.filterAll()
      }
    },
    startTour () {
      this.$tours.tour.start()
    }
  }
}
</script>
