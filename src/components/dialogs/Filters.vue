<template>
  <v-card role="main" aria-label="advanced filters dialog">
    <v-card-title class="d-flex align-center">
      <h1 class="text-h5">Advanced Filters</h1>
      <v-spacer></v-spacer>
      <v-tooltip open-delay="500" location="bottom">
        <template v-slot:activator="{ props }">
          <v-btn icon="mdi-close" variant="flat" size="small" @click="$emit('close')" v-bind="props" aria-label="close"></v-btn>
        </template>
        <span>Close</span>
      </v-tooltip>
    </v-card-title>

    <v-card-text class="text-body-2 text-grey-darken-4 pt-4">
      <v-select
        variant="outlined"
        :items="monitoringOrganization.options"
        v-model="monitoringOrganization.selected"
        label="Select Monitoring Organization"
        hide-details
        clearable
        multiple
        chips
        closable-chips
      ></v-select>
      <v-select
        variant="outlined"
        :items="analysisOrganization.options"
        v-model="analysisOrganization.selected"
        label="Select Analysis Organization"
        hide-details
        clearable
        multiple
        chips
        closable-chips
        class="mt-4"
      ></v-select>
      <v-select
        variant="outlined"
        :items="instrumentType.options"
        v-model="instrumentType.selected"
        label="Select Instrument Type"
        hide-details
        clearable
        multiple
        chips
        closable-chips
        class="mt-4"
      ></v-select>
      <v-checkbox
        v-model="dynamicManagementPlatform.selected"
        label="Dynamic Management Platform Only"
        hide-details
        class="mt-4"
      ></v-checkbox>
    </v-card-text>
    <v-card-actions>
      <v-btn color="primary" variant="text" @click="clearAll" aria-label="reset all">Reset All</v-btn>
      <v-spacer></v-spacer>
      <v-btn color="primary" variant="text" @click="$emit('close')" aria-label="close">Close</v-btn>
    </v-card-actions>
  </v-card>
</template>

<script>
import * as dc from 'dc'
import { mapGetters } from 'vuex'

import { xf } from '@/lib/crossfilter'

export default {
  name: 'FiltersDialog',
  data () {
    return {
      monitoringOrganization: {
        dim: null,
        options: [],
        selected: []
      },
      analysisOrganization: {
        dim: null,
        options: [],
        selected: []
      },
      instrumentType: {
        dim: null,
        options: [],
        selected: null
      },
      dynamicManagementPlatform: {
        selected: false
      }
    }
  },
  computed: {
    ...mapGetters({
      activeTheme: 'activeTheme'
    })
  },
  watch: {
    'monitoringOrganization.selected' () {
      this.setMonitoringOrganizationFilter()
    },
    'analysisOrganization.selected' () {
      this.setAnalysisOrganizationFilter()
    },
    'instrumentType.selected' () {
      this.setInstrumentTypeFilter()
    },
    'dynamicManagementPlatform.selected' () {
      this.setDynamicManagementPlatformFilter()
    },
    activeTheme () {
      this.reset()
    }
  },
  mounted () {
    this.monitoringOrganization.dim = xf.dimension(d => d.deployment_organization_code || 'N/A')
    this.analysisOrganization.dim = xf.dimension(d => d.analysis_organization_code || 'N/A')
    this.instrumentType.dim = xf.dimension(d => d.instrument_type || 'N/A')
    this.dynamicManagementPlatform.dim = xf.dimension(d => d.dynamic_management_platform ? 'T' : 'F')
    this.reset()
  },
  beforeUnmount () {
    this.monitoringOrganization.dim.dispose()
    this.analysisOrganization.dim.dispose()
    this.instrumentType.dim.dispose()
    this.dynamicManagementPlatform.dim.dispose()
  },
  methods: {
    clearAll () {
      this.monitoringOrganization.selected = []
      this.analysisOrganization.selected = []
      this.instrumentType.selected = []
      this.dynamicManagementPlatform.selected = false
    },
    reset () {
      const detections = xf.all()

      const monitoringOrganizations = new Set(detections.map(d => d.deployment_organization_code || 'N/A'))
      this.monitoringOrganization.options = [...monitoringOrganizations].sort()

      const analysisOrganizations = new Set(detections.map(d => d.analysis_organization_code || 'N/A'))
      this.analysisOrganization.options = [...analysisOrganizations].sort()

      const instrumentTypes = new Set(detections.map(d => d.instrument_type || 'N/A'))
      this.instrumentType.options = [...instrumentTypes].sort()

      this.clearAll()
    },
    setMonitoringOrganizationFilter () {
      if (this.monitoringOrganization.selected && this.monitoringOrganization.selected.length > 0) {
        this.monitoringOrganization.dim.filter(d => !d || this.monitoringOrganization.selected.includes(d))
      } else {
        this.monitoringOrganization.dim.filterAll()
      }
      dc.redrawAll()
    },
    setAnalysisOrganizationFilter () {
      if (this.analysisOrganization.selected && this.analysisOrganization.selected.length > 0) {
        this.analysisOrganization.dim.filter(d => !d || this.analysisOrganization.selected.includes(d))
      } else {
        this.analysisOrganization.dim.filterAll()
      }
      dc.redrawAll()
    },
    setInstrumentTypeFilter () {
      if (this.instrumentType.selected && this.instrumentType.selected.length > 0) {
        this.instrumentType.dim.filter(d => !d || this.instrumentType.selected.includes(d))
      } else {
        this.instrumentType.dim.filterAll()
      }
      dc.redrawAll()
    },
    setDynamicManagementPlatformFilter () {
      if (this.dynamicManagementPlatform.selected) {
        this.dynamicManagementPlatform.dim.filter(d => !d || d === 'T')
      } else {
        this.dynamicManagementPlatform.dim.filterAll()
      }
      dc.redrawAll()
    }
  }
}
</script>
