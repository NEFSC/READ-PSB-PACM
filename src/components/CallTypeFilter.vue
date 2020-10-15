<template>
  <v-select
    outlined
    :items="options"
    v-model="selected"
    label="Select beaked whale species"
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
  name: 'CallTypeFilter',
  data () {
    return {
      selected: [],
      options: [
        { id: 'Cuvier\'s' },
        { id: 'Blainville\'s' },
        { id: 'Gervais\'' },
        { id: 'True\'s' },
        { id: 'Gervais\'/True\'s' },
        { id: 'Sowerby\'s' },
        { id: 'Unid. Mesoplodon' }
      ]
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
    this.dim = xf.dimension(d => d.call_type)
    this.reset()
  },
  beforeDestroy () {
    this.dim && this.dim.dispose()
  },
  methods: {
    reset () {
      this.selected = this.options.map(d => d.id)
    },
    setFilter () {
      // console.log(`setFilter(${this.selected})`)
      if (!this.dim) return

      if (this.selected.length === this.options.length) {
        this.dim.filterAll()
      } else {
        this.dim.filter(d => this.selected.includes(d))
      }
      dc.redrawAll()
    }
  }
}
</script>
