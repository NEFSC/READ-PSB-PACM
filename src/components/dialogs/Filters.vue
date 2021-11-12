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
      }
    }
  },
  computed: {
    ...mapGetters(['theme'])
  },
  watch: {
    'affiliation.selected' () {
      console.log('watch: affiliation.selected')
      this.setAffiliationFilter()
    },
    theme () {
      this.reset()
    }
  },
  mounted () {
    this.affiliation.dim = xf.dimension(d => d.data_poc_affiliation)
    this.reset()
  },
  beforeDestroy () {
    this.affiliation.dim.dispose()
  },
  methods: {
    clearAll () {
      this.affiliation.selected = null
    },
    reset () {
      const detections = xf.all()

      const affiliations = new Set(detections.map(d => d.data_poc_affiliation))
      this.affiliation.options = [...affiliations].sort()

      this.clearAll()
    },
    setAffiliationFilter () {
      if (this.affiliation.selected) {
        this.affiliation.dim.filter(this.affiliation.selected)
      } else {
        this.affiliation.dim.filterAll()
      }
      dc.redrawAll()
    }
  }
}
</script>
