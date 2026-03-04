<template>
  <v-select
    variant="outlined"
    :items="options"
    v-model="selected"
    :label="`Select ${theme.label}`"
    item-title="name"
    item-value="code"
    hide-details
    multiple
    chips
    closable-chips
  ></v-select>
</template>

<script>
import * as dc from 'dc'
import { getRawDetections } from '@/lib/crossfilter'
import { mapState, mapActions } from 'pinia'
import { useStore } from '@/store'

export default {
  name: 'SpeciesFilter',
  data () {
    return {
      selected: [],
      options: []
    }
  },
  computed: {
    ...mapState(useStore, ['theme', 'species'])
  },
  watch: {
    selected () {
      useStore().reloadSpeciesFilter(this.selected)
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
