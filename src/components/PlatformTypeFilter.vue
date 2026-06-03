<template>
  <v-select
    variant="outlined"
    :items="options"
    v-model="selected"
    label="Select Platform Type(s)"
    item-title="name"
    item-value="code"
    hide-details
    multiple
    chips
    closable-chips
    clearable
    @click:clear="setFilter"
    class="mt-2"
  ></v-select>
</template>

<script>
import * as dc from 'dc'
import { xf } from '@/lib/crossfilter'
import { mapGetters } from 'vuex'
import { platformTypes } from '@/lib/constants'

export default {
  name: 'PlatformTypeFilter',
  data () {
    return {
      selected: [],
      options: [],
      isResetting: false
    }
  },
  computed: {
    ...mapGetters({
      activeTheme: 'activeTheme',
      platformTypes: 'platformTypes'
    })
  },
  watch: {
    selected () {
      this.setFilter()
    },
    activeTheme () {
      this.reset()
    }
  },
  mounted () {
    this.dim = xf.dimension(d => d.platform_type)
    this.reset()
  },
  beforeUnmount () {
    this.dim && this.dim.dispose()
  },
  methods: {
    reset () {
      if (!this.dim) return

      this.isResetting = true
      this.dim.filterAll()

      const datasetTypes = new Set(xf.all().map(d => d.platform_type)) // all types in dataset
      this.options = platformTypes.filter(d => datasetTypes.has(d.code))
      this.selected = this.options.map(d => d.code)

      this.$nextTick(() => {
        this.selected = this.options.map(d => d.code)
        this.dim.filterAll()
        this.isResetting = false
        dc.redrawAll()
      })
    },
    setFilter () {
      if (!this.dim || this.isResetting) return

      if (this.selected.length === this.options.length) {
        this.dim.filterAll()
      } else {
        const selected = new Set(this.selected)
        this.dim.filter(d => !d || selected.has(d))
      }
      dc.redrawAll()
    }
  }
}
</script>
