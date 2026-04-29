<template>
  <v-select
    variant="outlined"
    :items="options"
    v-model="selected"
    :label="`Select ${activeTheme.label}`"
    item-title="name"
    item-value="code"
    hide-details
    multiple
    chips
    closable-chips
    clearable
    @click:clear="onSelect"
    class="mt-2"
  ></v-select>
</template>

<script>
import * as dc from 'dc'
import { getRawDetections } from '@/lib/crossfilter'
import { mapGetters } from 'vuex'
import { species } from '@/lib/constants'

export default {
  name: 'SpeciesFilter',
  data () {
    return {
      selected: [],
      options: []
    }
  },
  computed: {
    ...mapGetters({
      activeTheme: 'activeTheme',
      species: 'species'
    })
  },
  watch: {
    selected () {
      this.onSelect()
    },
    activeTheme () {
      this.reset()
    }
  },
  mounted () {
    this.reset()
  },
  methods: {
    onSelect () {
      console.log('[onSelect] called', { selected: this.selected })
      this.$store.dispatch('reloadSpeciesFilter', this.selected)
        .then(() => dc.redrawAll())
    },
    reset () {
      const raw = getRawDetections()
      const speciesCodes = new Set(raw.map(d => d.species))
      this.options = species.filter(d => speciesCodes.has(d.code))
      this.selected = this.options.map(d => d.code)
    }
  }
}
</script>
