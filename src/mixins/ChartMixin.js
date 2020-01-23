import dc from 'dc'

export default {
  mounted () {
    console.log('ChartMixin: mounted', this.chart && this.chart.chartID())
  },
  beforeDestroy () {
    console.log('ChartMixin: destroy', this.chart && this.chart.chartID())

    if (!this.chart) return
    this.chart.dimension().dispose()
    dc.chartRegistry.deregister(this.chart)
    dc.redrawAll()
  },
  methods: {
    reset () {
      this.chart.filterAll()
    }
  }
}
