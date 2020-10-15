import dc from 'dc'

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
  //   console.log('ChartMixin: mounted', this.chart && this.chart.chartID())
    evt.$on('reset:filters', this.reset)
  },
  beforeDestroy () {
    // console.log('ChartMixin: destroy', this.chart && this.chart.chartID())
    if (!this.chart) return
    this.chart.dimension().dispose()
    dc.chartRegistry.deregister(this.chart)
    dc.redrawAll()
    evt.$off('reset:filters', this.reset)
  },
  methods: {
    reset () {
      this.chart.filterAll()
      dc.redrawAll()
    }
  }
}
