<template>
  <v-app>
    <v-app-bar color="light-blue-darken-4" role="navigation">
      <v-app-bar-nav-icon v-if="$vuetify.display.mobile" @click="drawer = !drawer"></v-app-bar-nav-icon>
      <v-icon icon="$whale" color="white" class="mx-4" v-if="!$vuetify.display.mobile"></v-icon>
      <h1>
        <v-toolbar-title v-if="!$vuetify.display.mobile">
          Passive Acoustic Cetacean Map <span style="font-size: 50%;" class="pl-1">v{{ version }}</span>
        </v-toolbar-title>
        <v-toolbar-title v-else class="font-weight-bold">PACM</v-toolbar-title>
      </h1>

      <v-spacer></v-spacer>

      <v-dialog v-model="dialogs.about" max-width="1000" scrollable :fullscreen="$vuetify.display.mobile">
        <template v-slot:activator="{ props }">
          <v-btn color="default" v-bind="props" data-v-step="about-button" aria-label="about page">
            <v-icon :start="!$vuetify.display.mobile">mdi-information-outline</v-icon>
            <span v-if="!$vuetify.display.mobile"> About</span>
          </v-btn>
        </template>
        <AboutDialog @close="closeAbout"></AboutDialog>
      </v-dialog>

      <v-dialog v-model="dialogs.guide" max-width="1200" scrollable :fullscreen="$vuetify.display.mobile">
        <template v-slot:activator="{ props }">
          <v-btn color="default" variant="text" v-bind="props" data-v-step="user-guide-button" aria-label="user guide">
            <v-icon :start="!$vuetify.display.mobile">mdi-book-open-variant</v-icon>
            <span v-if="!$vuetify.display.mobile"> User Guide</span>
          </v-btn>
        </template>
        <UserGuideDialog @close="closeGuide"></UserGuideDialog>
      </v-dialog>

      <v-btn
        color="default"
        variant="text"
        data-v-step="tour-button"
        aria-label="start tour"
        :disabled="$vuetify.display.mobile"
        @click="startTour"
      >
        <v-icon :start="!$vuetify.display.mobile">mdi-cursor-default-click</v-icon>
        <span v-if="!$vuetify.display.mobile"> Tour</span>
      </v-btn>

      <div>
        <a href="https://passiveacoustics.fisheries.noaa.gov">
          <v-img src="./assets/img/noaa-logo.gif" height="40px" width="40px" class="ma-2" alt="NOAA Logo"></v-img>
        </a>
      </div>
    </v-app-bar>

    <v-navigation-drawer :permanent="!$vuetify.display.mobile" color="blue-grey-darken-4" width="500"
      v-model="drawer" role="complementary">
      <v-list class="mt-4 py-0">
        <v-list-item class="my-1" data-v-step="theme">
          <SelectTheme></SelectTheme>
        </v-list-item>
      </v-list>
      <v-list class="pt-0" v-if="activeTheme">
        <v-list-item class="my-1" v-if="activeTheme.showSpeciesFilter">
          <SpeciesFilter></SpeciesFilter>
        </v-list-item>

        <v-list-item class="my-1" data-v-step="platform">
          <PlatformTypeFilter></PlatformTypeFilter>
        </v-list-item>

        <div class="text-right mx-4">
          <v-dialog v-model="dialogs.filters" max-width="600" scrollable persistent eager
            :fullscreen="$vuetify.display.mobile">
            <template v-slot:activator="{ props }">
              <v-btn color="default" size="small" variant="text" v-bind="props" aria-label="advanced filters"
                data-v-step="advanced">Advanced Filters...</v-btn>
            </template>
            <FiltersDialog @close="dialogs.filters = false"></FiltersDialog>
          </v-dialog>
        </div>

        <v-divider class="my-4"></v-divider>

        <v-alert color="blue-grey-darken-3" border="start" density="compact" class="mx-4 mb-2 text-body-2 align-center">
          Selected period: {{ periodLabel }}
          <v-tooltip location="right" max-width="300" open-delay="300">
            <template v-slot:activator="{ props }">
              <v-icon size="small" class="ml-1" v-bind="props">mdi-information-outline</v-icon>
            </template>
            <span>The selected period is determined by the season and year filters below. When the season wraps across
              years
              (e.g., Oct 1 – Mar 31), the period begins at the start of the season in the first selected year (Oct 1,
              2020)
              and ends at the end of the season in the last selected year (Mar 31, 2022). This avoids showing partial
              seasons at the beginning of the first year (Jan 1 - Mar 31, 2020) and end of the last year (Oct 1 - Dec
              31,
              2022).</span>
          </v-tooltip>
        </v-alert>

        <v-list-item class="mt-0" data-v-step="season">
          <SeasonFilter :axis-label="yAxisLabel"></SeasonFilter>
        </v-list-item>

        <v-list-item class="mt-2" data-v-step="year">
          <YearFilter :axis-label="yAxisLabel"></YearFilter>
        </v-list-item>

        <v-list-item class="mt-2" data-v-step="detection" v-if="!activeTheme.deploymentsOnly">
          <DetectionFilter :axis-label="yAxisLabel"></DetectionFilter>
        </v-list-item>
      </v-list>
    </v-navigation-drawer>

    <div data-v-step="map"></div>
    <v-main style="z-index:0">
      <div style="height:100%;position:relative">
        <Map :counts="counts"></Map>
        <div style="position:absolute;bottom:0;left:0;width:100%;z-index:1000;background:white;max-height:600px"
          v-if="selectedDeployments.length > 0">
          <DeploymentDetail></DeploymentDetail>
        </div>
      </div>
    </v-main>

    <v-dialog v-model="loadingFailed" max-width="600" scrollable persistent>
      <div>
        <v-alert type="error" prominent class="mb-0">
          <div class="text-h6">Failed to Load Dataset</div>
          <p class="text-body-1 mb-0">
            An error occurred fetching the dataset from the server.
            Please refresh and try again.
            If the problem continues, please contact us at <a href="mailto:passiveacoustics@noaa.gov"
              style="color:white">passiveacoustics@noaa.gov</a>.
          </p>
        </v-alert>
      </div>
    </v-dialog>

    <v-tour name="pacmTour" :steps="tourSteps" :options="tourOptions"></v-tour>
  </v-app>
</template>

<script>
import { mapActions, mapGetters } from 'vuex'
import moment from 'moment'

import Map from '@/components/Map'
import AboutDialog from '@/components/dialogs/About'
import FiltersDialog from '@/components/dialogs/Filters'
import UserGuideDialog from '@/components/dialogs/UserGuide'
import SelectTheme from '@/components/SelectTheme'
import YearFilter from '@/components/YearFilter'
import SpeciesFilter from '@/components/SpeciesFilter'
import PlatformTypeFilter from '@/components/PlatformTypeFilter'
import SeasonFilter from '@/components/SeasonFilter'
import DetectionFilter from '@/components/DetectionFilter'
import DeploymentDetail from '@/components/DeploymentDetail'

import evt from '@/lib/events'
import { xf, deploymentGroup, siteGroup, siteMap, deploymentMap } from '@/lib/crossfilter'
import { themes } from '@/lib/constants'
import tourSteps from '@/lib/tour'

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
  data () {
    return {
      version: process.env.PACKAGE_VERSION,
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
      tourSteps,
      tourOptions: {
        highlight: true,
        labels: {
          buttonSkip: 'Skip',
          buttonPrevious: 'Previous',
          buttonNext: 'Next',
          buttonStop: 'Finish'
        }
      }
    }
  },
  computed: {
    ...mapGetters(['activeTheme', 'isLoading', 'loadingFailed', 'selectedDeployments']),
    showDialog () {
      return !!this.deployments.selected
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
      const fmt = doy => moment('2000-12-31').add(doy, 'days').format('MMM D')
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

    evt.$on('xf:filtered', this.onFiltered)
    evt.$on('period:season', (val) => { this.period.season = val; this.updatePeriodFilter() })
    evt.$on('period:year', (val) => { this.period.year = val; this.updatePeriodFilter() })
  },
  beforeUnmount () {
    evt.$off('xf:filtered', this.onFiltered)
    evt.$off('period:season')
    evt.$off('period:year')
    if (this.periodDim) { this.periodDim.filterAll(); this.periodDim.dispose() }
  },
  watch: {
    activeTheme () {
      if (this.periodDim) { this.periodDim.filterAll(); this.periodDim.dispose() }
      this.periodDim = xf.dimension(d => d.datekey)
      this.period.season = { start: 1, end: 365 }
      this.period.year = { start: null, end: null }
      evt.$emit('reset:filters', 'app:loadData')
      this.counts.detections.total = xf.size()
      this.counts.deployments.total = deploymentGroup.size()
      this.counts.sites.total = siteMap.size
      if (this.activeTheme && this.activeTheme.id && this.$route.params.id !== this.activeTheme.id) {
        this.$router.push({ name: 'home', params: { id: this.activeTheme.id } })
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
        if (!this.activeTheme) {
          this.setTheme(this.themes[1])
        }
        this.startTour()
      } else if (!this.activeTheme) {
        this.setTheme(this.themes[1])
      }
    },
    closeGuide () {
      this.dialogs.guide = false
      if (!this.activeTheme) {
        this.dialogs.about = true
      }
    },
    onFiltered () {
      // unselect deployments that no longer have any filtered detections
      console.log('[onFiltered] selectedDeployments:', this.selectedDeployments)
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
      this.counts.sites.total = siteMap.size
      const siteIds = new Set((this.$store.getters.sites || []).map(d => d.site_id))
      this.counts.sites.filtered = siteGroup.all().filter(d => siteIds.has(d.key) && d.value.total > 0).length
      this.counts.deployments.total = deploymentGroup.size()
      this.counts.deployments.filtered = deploymentGroup.all().filter(d => d.value.total > 0).length
      this.counts.detections.total = xf.size()
      this.counts.detections.filtered = xf.allFiltered().length
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
    async startTour () {
      if (this.$vuetify.display.mobile) return

      if (!this.activeTheme) {
        await this.setTheme(this.themes[1])
      }

      await this.waitForTourTargets()
      this.$tours.pacmTour.start()
    },
    waitForTourTargets () {
      const hasTargets = () => this.activeTheme && !this.isLoading && document.querySelector('[data-v-step="platform"]')
      if (hasTargets()) return this.$nextTick()

      return new Promise(resolve => {
        const check = () => {
          if (hasTargets()) {
            this.$nextTick(resolve)
          } else {
            window.setTimeout(check, 100)
          }
        }
        check()
      })
    }
  }
}
</script>
