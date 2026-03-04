<template>
  <v-select
    outlined
    :items="options"
    v-model="selected"
    label="Select Platform Type(s)"
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
import { xf } from '@/lib/crossfilter'
import { mapGetters } from 'vuex'

export default {
  name: 'PlatformTypeFilter',
  data () {
    return {
      selected: [],
      options: []
    }
  },
  computed: {
    ...mapGetters(['theme', 'loading', 'platformTypes'])
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
    this.dim = xf.dimension(d => d.platform_type)
    this.reset()
  },
  beforeDestroy () {
    this.dim && this.dim.dispose()
  },
  methods: {
    reset () {
      const datasetTypes = new Set(xf.all().map(d => d.platform_type)) // all types in dataset
      this.options = this.platformTypes.filter(d => datasetTypes.has(d.code))
      this.selected = this.options.map(d => d.code)
    },
    setFilter () {
      if (!this.dim) return

      this.dim.filter(d => !d || this.selected.includes(d))
      dc.redrawAll()
    }
  }
}
</script>
