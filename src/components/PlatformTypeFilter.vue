<template>
  <v-select
    outlined
    :items="options"
    v-model="selected"
    label="Select platform type(s)"
    item-text="label"
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
import { platformTypes } from '@/lib/constants'
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
    ...mapGetters(['theme', 'loading'])
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
      const datasetTypes = [...new Set(xf.all().map(d => d.platform_type))] // all types in dataset
      this.options = platformTypes.filter(d => datasetTypes.includes(d.id))
      this.selected = this.options.map(d => d.id)
    },
    setFilter () {
      // console.log(`setFilter(${this.selected})`)
      if (!this.dim) return

      this.dim.filter(d => !d || this.selected.includes(d))
      dc.redrawAll()
    }
  }
}
</script>
