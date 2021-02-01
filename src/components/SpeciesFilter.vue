<template>
  <v-select
    outlined
    :items="options"
    v-model="selected"
    :label="`Select Species of ${theme.label}`"
    item-text="id"
    item-value="id"
    hide-details
    multiple
    chips
    deletable-chips
  ></v-select>
</template>

<script>
import dc from 'dc'
import { xf } from '@/lib/crossfilter'
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
    ...mapGetters(['theme'])
  },
  watch: {
    selected () {
      this.setFilter()
    },
    theme () {
      this.reset()
    }
  },
  mounted () {
    this.dim = xf.dimension(d => d.species)
    this.reset()
  },
  beforeDestroy () {
    this.dim && this.dim.dispose()
  },
  methods: {
    reset () {
      this.options = [...new Set(xf.all().filter(d => !!d.species).map(d => d.species))].sort().map(d => ({ id: d }))
      this.selected = this.options.map(d => d.id)
    },
    setFilter () {
      // console.log(`setFilter(${this.selected})`)
      if (!this.dim) return

      if (this.selected.length === this.options.length) {
        this.dim.filterAll()
      } else {
        this.dim.filter(d => !d || this.selected.includes(d))
      }
      dc.redrawAll()
    }
  }
}
</script>
