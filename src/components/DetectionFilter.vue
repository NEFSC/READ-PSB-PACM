<template>
  <div class="detection-filter">
    <v-btn icon x-small class="mt-1 float-right" color="grey" @click="reset"><v-icon>mdi-sync</v-icon></v-btn>
    <div class="subtitle-1 font-weight-medium">Filter By Detection Result</div>
  </div>
</template>

<script>
import * as d3 from 'd3'
import dc from 'dc'

import ChartMixin from '@/mixins/ChartMixin'
import evt from '@/lib/events'
import { xf } from '@/lib/crossfilter'

export default {
  name: 'DetectionFilter',
  mixins: [ChartMixin],
  data () {
    return {
      chart: null
    }
  },
  mounted () {
    const detectionLabels = {
      no: 'Negative',
      yes: 'Positive',
      maybe: 'Possible'
    }
    const dim = xf.dimension(d => detectionLabels[d.detection])
    const group = dim.group().reduceCount()

    this.chart = dc.rowChart(this.$el.appendChild(document.createElement('div')))
      .width(468)
      .height(140)
      .margins({ top: 10, right: 10, bottom: 40, left: 60 })
      .dimension(dim)
      .group(group)
      .elasticX(true)
      .labelOffsetX(-60)
      .ordering(d => {
        return ['Positive', 'Possible', 'Negative'].indexOf(d.key)
      })
      .ordinalColors(['#CC3833', '#78B334', '#0277BD'])
      .on('filtered', () => evt.$emit('render:map'))
      .on('postRender', () => {
        if (this.chart.svg().selectAll('.x-axis-label').nodes().length > 0) return
        const textSelection = this.chart.svg()
          .append('text')
          .attr('class', 'x-axis-label')
          .attr('text-anchor', 'middle')
          .attr('x', this.chart.width() / 2)
          .attr('y', this.chart.height() - 10)
          .text('# Days Recorded')
        const textDims = textSelection.node().getBBox()
        const chartMargins = this.chart.margins()

        textSelection
          .attr('x', chartMargins.left + (this.chart.width() - chartMargins.left - chartMargins.right) / 2)
          .attr('y', this.chart.height() - Math.ceil(textDims.height) / 2)
      })

    this.chart.xAxis().ticks(5).tickFormat(d3.format('.0s'))

    this.chart.render()
  },
  methods: {
    reset () {
      this.chart.filterAll()
      this.chart.redraw()
    }
  }
}
</script>

<style>
.detection-filter .row text{
  font-weight: 600 !important;
  font-size: 10pt !important;
}
.detection-filter .x-axis-label {
  fill: hsl(0, 0%, 90%) !important;
  font-weight: 600 !important;
  font-size: 10pt !important;
}
</style>
