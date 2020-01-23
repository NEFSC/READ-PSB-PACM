<template>
  <div class="year-filter">
    <v-btn icon x-small class="mt-1 float-right" color="grey" @click="reset"><v-icon>mdi-sync</v-icon></v-btn>
    <div class="subtitle-1 font-weight-medium">Filter by Years ({{ filter[0] }} to {{ filter[1] - 1 }})</div>
  </div>
</template>

<script>
import * as d3 from 'd3'
import dc from 'dc'

import ChartMixin from '@/mixins/ChartMixin'
import evt from '@/lib/events'
import { xf } from '@/lib/crossfilter'

export default {
  name: 'YearFilter',
  mixins: [ChartMixin],
  data () {
    return {
      chart: null,
      filter: [2004, 2020]
    }
  },
  mounted () {
    console.log('YearFilter:mounted', this.chart, this.$el)
    const dim = xf.dimension(d => d.date.getFullYear())
    const group = dim.group().reduceCount()
    const timeExtent = d3.extent(xf.all().map(d => d.date.getFullYear()))
    timeExtent[1] += 1
    this.filter = timeExtent

    this.chart = dc.barChart(this.$el.appendChild(document.createElement('div')))
      .width(468)
      .height(160)
      .margins({ top: 10, right: 10, bottom: 40, left: 40 })
      .dimension(dim)
      .group(group)
      .elasticY(true)
      .x(d3.scaleLinear().domain(timeExtent))
      .xAxisLabel('Year')
      .yAxisLabel('# Days Recorded')
      .round(dc.round.round)
      .on('filtered', () => {
        const filter = this.chart.filter() || timeExtent
        this.filter = [filter[0], filter[1]]
        evt.$emit('render:map')
      })
      .on('postRender', (chart) => {
        const n = chart.xUnitCount()
        const width = chart.effectiveWidth()
        chart.selectAll('.axis.x .tick line')
          .attr('transform', `translate(${Math.floor(width / n / 2)} 0)`)
        chart.selectAll('.axis.x .tick text')
          .attr('transform', `translate(${Math.floor(width / n / 2)} 0)`)
      })

    this.chart.xAxis().ticks(20).tickFormat(v => {
      return (v % 2 > 0) || v >= timeExtent[1] ? '' : d3.format('d')(v)
    })
    this.chart.yAxis().ticks(4).tickFormat(d3.format('.0s'))
    this.chart.render()
  }
}
</script>

<style>
</style>
