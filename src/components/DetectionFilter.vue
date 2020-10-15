<template>
  <div class="detection-filter">
    <v-btn icon x-small class="mt-1 float-right" color="grey" @click="reset"><v-icon>mdi-sync</v-icon></v-btn>
    <div class="subtitle-1 font-weight-medium">Total <span v-if="isTowed">Detections</span><span v-else>Detection Days</span></div>
  </div>
</template>

<script>
import dc from 'dc'

import ChartMixin from '@/mixins/ChartMixin'
import { xf } from '@/lib/crossfilter'
import { detectionTypesMap, detectionTypes } from '@/lib/constants'
import { mapGetters } from 'vuex'

export default {
  name: 'DetectionFilter',
  mixins: [ChartMixin],
  data () {
    return {
      chart: null
    }
  },
  computed: {
    ...mapGetters(['isTowed'])
  },
  mounted () {
    // console.log('DetectionFilter mounted')
    const dim = xf.dimension(d => detectionTypesMap.get(d.presence).label)
    const group = dim.group().reduceCount()

    this.chart = dc.rowChart(this.$el.appendChild(document.createElement('div')))
      .width(450)
      .height(140)
      .margins({ top: 10, right: 20, bottom: 40, left: 90 })
      .dimension(dim)
      .group(group)
      .elasticX(true)
      .labelOffsetX(-10)
      .ordering(d => {
        return detectionTypes.map(d => d.label).indexOf(d.key)
      })
      .ordinalColors(['#CC3833', '#78B334', '#0277BD'])
      .on('postRender', () => {
        if (this.chart.svg().selectAll('.x-axis-label').nodes().length > 0) return
        const textSelection = this.chart.svg()
          .append('text')
          .attr('class', 'x-axis-label')
          .attr('text-anchor', 'middle')
          .attr('x', this.chart.width() / 2)
          .attr('y', this.chart.height() - 10)
          .text(this.yAxisLabel)
        const textDims = textSelection.node().getBBox()
        const chartMargins = this.chart.margins()

        textSelection
          .attr('x', chartMargins.left + (this.chart.width() - chartMargins.left - chartMargins.right) / 2)
          .attr('y', this.chart.height() - Math.ceil(textDims.height) / 2)
      })

    this.chart.xAxis().ticks(5)

    this.chart.render()
    this.$nextTick(() => {
      this.chart.render()
    })
  },
  methods: {
    reset () {
      this.chart.filterAll()
      dc.redrawAll()
    }
  }
}
</script>

<style>
.detection-filter .row text{
  font-weight: 600 !important;
  font-size: 10pt !important;
  text-anchor: end;
}
.detection-filter .x-axis-label {
  fill: hsl(0, 0%, 90%) !important;
  font-weight: 600 !important;
  font-size: 10pt !important;
}
</style>
