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
import { xf } from '@/lib/crossfilter'
import { platformTypes } from '@/lib/constants'

export default {
  name: 'PlatformTypeFilter',
  data () {
    return {
      selected: platformTypes.map(d => d.id),
      options: platformTypes,
      dim: null
    }
  },
  watch: {
    'selected' () {
      this.setFilter()
    }
  },
  mounted () {
    this.dim = xf.dimension(d => d.platform_type)
    this.setFilter()
  },
  beforeDestroy () {
    this.dim && this.dim.dispose()
  },
  methods: {
    setFilter () {
      console.log(`platformTypeFilter: setFilter(${this.selected})`)
      if (!this.dim) return

      this.dim.filter(d => this.selected.includes(d))
      this.$emit('update', this.selected)
    }
  }
}
</script>
