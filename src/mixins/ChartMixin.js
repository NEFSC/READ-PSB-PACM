import * as dc from 'dc'

import evt from '@/lib/events'

export default {
  props: ['yAxisLabel'],
  watch: {
    yAxisLabel (val) {
      if (!this.chart) return
      this.chart
        .yAxisLabel(this.yAxisLabel)
    }
  },
  mounted () {
    evt.on('reset:filters', this.reset)
  },
  beforeUnmount () {
    if (!this.chart) return
    this.chart.dimension().dispose()
    dc.chartRegistry.deregister(this.chart)
    dc.redrawAll()
    evt.off('reset:filters', this.reset)
  },
  methods: {
    reset () {
      this.chart.filterAll()
      dc.redrawAll()
    }
  }
}
