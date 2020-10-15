<template>
  <div class="month-filter">
  </div>
</template>

<script>
import * as d3 from 'd3'
import dc from 'dc'

import ChartMixin from '@/mixins/ChartMixin'
import evt from '@/lib/events'
import { xf } from '@/lib/crossfilter'

export default {
  name: 'MonthFilter',
  mixins: [ChartMixin],
  data () {
    return {
      chart: null
    }
  },
  mounted () {
    // console.log('MonthFilter:mounted')
    const dim = xf.dimension(d => d.date.getMonth())
    const group = dim.group().reduceCount()

    this.chart = dc.barChart(this.$el.appendChild(document.createElement('div')))
      .width(468)
      .height(160)
      .margins({ top: 10, right: 10, bottom: 40, left: 40 })
      .dimension(dim)
      .group(group)
      .elasticY(true)
      .x(d3.scaleLinear().domain([0, 12]))
      .xAxisLabel('Month')
      .yAxisLabel('# Days Recorded')
      .round(dc.round.round)
      // .on('filtered', () => evt.$emit('render:map', 'monthFilter:filtered'))
      .on('postRender', (chart) => {
        const n = chart.xUnitCount()
        const width = chart.effectiveWidth()
        chart.selectAll('.axis.x .tick line')
          .attr('transform', `translate(${Math.floor(width / n / 2)} 0)`)
        chart.selectAll('.axis.x .tick text')
          .attr('transform', `translate(${Math.floor(width / n / 2)} 0)`)
      })

    const monthAbb = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

    this.chart.xAxis().ticks(12).tickFormat(v => monthAbb[v])
    this.chart.yAxis().ticks(4).tickFormat(d3.format('.0s'))

    this.chart.render()
  }
}
</script>

<style>
</style>
