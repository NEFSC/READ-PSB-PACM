<template>
  <v-card role="main" aria-label="advanced filters dialog">
    <v-card-title primary-title>
      <h1 class="headline">Advanced Filters</h1>
      <v-spacer></v-spacer>
      <v-tooltip open-delay="500" bottom>
        <template v-slot:activator="{ on }">
          <v-btn icon small @click.native="$emit('close')" v-on="on" aria-label="close"><v-icon>mdi-close</v-icon></v-btn>
        </template>
        <span>Close</span>
      </v-tooltip>
    </v-card-title>

    <v-card-text class="body-2 grey--text text--darken-4 pt-4">
      <v-select
        outlined
        :items="affiliation.options"
        v-model="affiliation.selected"
        label="Select Data Affiliation"
        hide-details
        clearable
      ></v-select>
      <v-select
        outlined
        :items="instrumentType.options"
        v-model="instrumentType.selected"
        label="Select Instrument Type"
        hide-details
        clearable
        class="mt-4"
      ></v-select>
      <v-select
        outlined
        :items="samplingRate.options"
        v-model="samplingRate.selected"
        label="Select Sampling Rate"
        hide-details
        clearable
        class="mt-4"
      ></v-select>
    </v-card-text>
    <v-card-actions>
      <v-btn color="primary" text @click="clearAll" aria-label="reset all">Reset All</v-btn>
      <v-spacer></v-spacer>
      <v-btn color="primary" text @click.native="$emit('close')" aria-label="close">Close</v-btn>
    </v-card-actions>
  </v-card>
</template>

<script>
import dc from 'dc'
import { mapGetters } from 'vuex'

import { xf } from '@/lib/crossfilter'

export default {
  name: 'FiltersDialog',
  data () {
    return {
      affiliation: {
        dim: null,
        options: [],
        selected: null
      },
      instrumentType: {
        dim: null,
        options: [],
        selected: null
      },
      samplingRate: {
        dim: null,
        options: [],
        selected: null
      }
    }
  },
  computed: {
    ...mapGetters(['theme'])
  },
  watch: {
    'affiliation.selected' () {
      this.setAffiliationFilter()
    },
    'instrumentType.selected' () {
      this.setInstrumentTypeFilter()
    },
    'samplingRate.selected' () {
      this.setSamplingRateFilter()
    },
    theme () {
      this.reset()
    }
  },
  mounted () {
    this.affiliation.dim = xf.dimension(d => d.data_poc_affiliation)
    this.instrumentType.dim = xf.dimension(d => d.instrument_type)
    this.samplingRate.dim = xf.dimension(d => d.sampling_rate)
    this.reset()
  },
  beforeDestroy () {
    this.affiliation.dim.dispose()
    this.instrumentType.dim.dispose()
    this.samplingRate.dim.dispose()
  },
  methods: {
    clearAll () {
      this.affiliation.selected = null
      this.instrumentType.selected = null
      this.samplingRate.selected = null
    },
    reset () {
      const detections = xf.all()

      const affiliations = new Set(detections.map(d => d.data_poc_affiliation))
      this.affiliation.options = [...affiliations].sort()

      const instrumentTypes = new Set(detections.map(d => d.instrument_type))
      this.instrumentType.options = [...instrumentTypes].sort()

      const samplingRates = new Set(detections.map(d => d.sampling_rate))
      const samplingRateLevels = ['Low (1-4 kHz)', 'Medium (5-96 kHz)', 'High (97+ kHz)', 'Unknown'].filter(d => samplingRates.has(d))
      this.samplingRate.options = samplingRateLevels

      this.clearAll()
    },
    setAffiliationFilter () {
      if (this.affiliation.selected) {
        this.affiliation.dim.filter(this.affiliation.selected)
      } else {
        this.affiliation.dim.filterAll()
      }
      dc.redrawAll()
    },
    setInstrumentTypeFilter () {
      if (this.instrumentType.selected) {
        this.instrumentType.dim.filter(this.instrumentType.selected)
      } else {
        this.instrumentType.dim.filterAll()
      }
      dc.redrawAll()
    },
    setSamplingRateFilter () {
      if (this.samplingRate.selected) {
        this.samplingRate.dim.filter(this.samplingRate.selected)
      } else {
        this.samplingRate.dim.filterAll()
      }
      dc.redrawAll()
    }
  }
}
</script>
