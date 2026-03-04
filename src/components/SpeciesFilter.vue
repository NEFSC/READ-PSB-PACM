<template>
  <v-select
    outlined
    :items="options"
    v-model="selected"
    :label="`Select ${theme.label}`"
    item-text="name"
    item-value="code"
    hide-details
    multiple
    chips
    deletable-chips
  ></v-select>
</template>

<script>
import * as dc from 'dc'
import { getRawDetections } from '@/lib/crossfilter'
import { mapGetters } from 'vuex'

export default {
  name: 'SpeciesFilter',
  data () {
    return {
      selected: [],
      options: []
    }
  },
  computed: {
    ...mapGetters(['theme', 'species'])
  },
  watch: {
    selected () {
      this.$store.dispatch('reloadSpeciesFilter', this.selected)
        .then(() => dc.redrawAll())
    },
    theme () {
      this.reset()
    }
  },
  mounted () {
    this.reset()
  },
  methods: {
    reset () {
      const raw = getRawDetections()
      const speciesCodes = new Set(raw.map(d => d.species))
      this.options = this.species.filter(d => speciesCodes.has(d.code))
      this.selected = this.options.map(d => d.code)
    }
  }
}
</script>
