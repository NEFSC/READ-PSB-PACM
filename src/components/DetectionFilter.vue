<template>
  <div class="detection-filter">
    <v-tooltip open-delay="500" right>
      <template v-slot:activator="{ on }">
        <v-btn
          icon
          x-small
          class="mt-1 float-right"
          color="grey"
          @click="reset"
          v-on="on"
          aria-label="reset"
        >
          <v-icon>mdi-sync</v-icon>
        </v-btn>
      </template>
      <span>Reset</span>
    </v-tooltip>

    <div class="subtitle-1 font-weight-medium">Detection Results</div>
    <div ref="chart"></div>
  </div>
</template>

<script>
import dc from 'dc'
import * as d3 from 'd3'
import d3Tip from 'd3-tip'

import ChartMixin from '@/mixins/ChartMixin'
import { xf } from '@/lib/crossfilter'
import { detectionTypesMap, detectionTypes } from '@/lib/constants'

export default {
  name: 'DetectionFilter',
  mixins: [ChartMixin],
  data () {
    return {
      chart: null,
      types: detectionTypes.map(d => ({ id: d.id, checked: true }))
    }
  },
  mounted () {
    // console.log('DetectionFilter mounted')
    const dim = xf.dimension(d => detectionTypesMap.get(d.presence).label)
    const group = dim.group().reduceCount()

    this.tip = d3Tip()
      .attr('class', 'd3-tip detection-filter')
      .attr('role', 'complementary')
      .direction('e')
      .html(d => d.value.toLocaleString())

    const colorScale = d3.scaleOrdinal()
      .domain(detectionTypes.map(d => d.label))
      .range(detectionTypes.map(d => d.color))

    // const el = this.$el.appendChild(document.createElement('div'))
    const margins = { top: 20, right: 70, bottom: 40, left: 90 }
    this.chart = dc.rowChart(this.$refs.chart)
      .width(450)
      .height(150)
      .margins(margins)
      .dimension(dim)
      .group(group)
      .elasticX(true)
      .labelOffsetX(-10)
      .ordering(d => detectionTypes.map(d => d.label).indexOf(d.key))
      .colors(colorScale)
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

        this.chart.svg().append('text')
          .attr('class', 'toggle')
          .attr('x', this.chart.width() - 30)
          .attr('y', 12)
          .text('Show/Hide')

        this.chart.selectAll('g.row')
          .append('circle')
          .attr('class', 'toggle')
          .attr('r', 8)
          .attr('cy', 8)
          .attr('cx', this.chart.width() - margins.left - margins.right + 40)
          .on('click', d => {
            this.chart.onClick(d)
          })

        this.renderToggles()
      })

    setTimeout(() => {
      this.chart.svg().call(this.tip)
      this.chart.selectAll('.row > rect')
        .on('mouseenter', this.tip.show)
        .on('mouseout', this.tip.hide)
    }, 500)

    this.chart.xAxis().ticks(5)

    this.chart.on('filtered', () => {
      this.renderToggles()
    })

    this.chart.render()
    this.$nextTick(() => {
      this.chart.render()
    })
  },
  beforeDestroy () {
    d3.selectAll('.d3-tip.detection-filter').remove()
    this.chart && this.chart.selectAll('circle.toggle').remove()
  },
  methods: {
    renderToggles () {
      if (!this.chart) return
      this.chart.selectAll('circle.toggle')
        .classed('on', d => !this.chart.hasFilter() || this.chart.hasFilter(d.key))
    },
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
.detection-filter .dc-chart {
  position: relative;
}
.detection-filter .row-checkbox {
  position: absolute;
  right: 20px;
}
.detection-filter text.toggle {
  fill: hsl(0, 0%, 90%);
  font-weight: 600;
  font-size: 9pt;
  text-anchor: middle;
}
.detection-filter circle.toggle {
  cursor: pointer;
  pointer-events: auto;
  fill: #eee;
  fill-opacity: 0;
  stroke-opacity: 0.5;
  stroke-width: 2.5px;
  stroke: white;
}
.detection-filter circle.toggle.on {
  fill-opacity: 1;
}
</style>
