<template>
  <div class="season-chart">
  </div>
</template>

<script>
import * as d3 from 'd3'
import dc from 'dc'
import moment from 'moment'
import d3Tip from 'd3-tip'
import pad from 'pad'

import ChartMixin from '@/mixins/ChartMixin'
import { xf } from '@/lib/crossfilter'
import { detectionTypes, detectionTypesMap } from '@/lib/constants'

export default {
  name: 'SeasonChart',
  mixins: [ChartMixin],
  data () {
    return {
      chart: null
    }
  },
  mounted () {
    const dim = xf.dimension(d => moment('2000-01-01').add(Math.floor(moment(d.date).dayOfYear() / 6) * 6, 'days').toDate())
    const group = dim.group().reduce(
      (p, v) => {
        p[v.presence] = (p[v.presence] || 0) + 1
        return p
      },
      (p, v) => {
        p[v.presence] = (p[v.presence] || 0) - 1
        return p
      },
      () => detectionTypes.reduce((p, v) => {
        p[v.id] = 0
        return p
      }, {})
    )

    this.tip = d3Tip()
      .attr('class', 'd3-tip season-chart')
      .direction('e')
      .html((d) => {
        const start = d.data.key
        const end = moment(start).add(5, 'days').toDate()
        const formatter = d3.timeFormat('%b %d')
        return `
          ${formatter(start)} to ${formatter(end)}<br><br>
          ${pad(12, detectionTypesMap.get('y').label, '&nbsp;')}: ${pad(6, d.data.value.y.toLocaleString(), '&nbsp;')}<br>
          ${pad(12, detectionTypesMap.get('m').label, '&nbsp;')}: ${pad(6, d.data.value.m.toLocaleString(), '&nbsp;')}<br>
          ${pad(12, detectionTypesMap.get('n').label, '&nbsp;')}: ${pad(6, d.data.value.n.toLocaleString(), '&nbsp;')}<br>
          ${pad(12, detectionTypesMap.get('na').label, '&nbsp;')}: ${pad(6, d.data.value.na.toLocaleString(), '&nbsp;')}
        `
      })

    this.chart = dc.barChart(this.$el.appendChild(document.createElement('div')))
      .width(450)
      .height(120)
      .margins({ top: 10, right: 20, bottom: 5, left: 60 })
      .dimension(dim)
      .group(group, 'y', (d) => d.value.y)
      .x(d3.scaleTime().domain([new Date(2000, 0, 1), new Date(2000, 11, 31)]))
      .xUnits(() => 61)
      .colors(d3.scaleOrdinal().range(detectionTypes.map(d => d.color)))
      .elasticY(true)
      .brushOn(false)
      .yAxisLabel(this.yAxisLabel)
      .gap(0)
      .barPadding(0.3)
      .renderTitle(false)
      // .on('filtered', this.updateFill)
      .on('postRender', (chart) => {
        chart.g().call(this.tip)
        chart.selectAll('rect.bar')
          .on('mouseenter', this.tip.show)
          .on('mouseout', this.tip.hide)
      })

    dc.override(this.chart, 'legendables', () => {
      return this.chart._legendables().reverse()
    })
    this.chart.stack(group, 'm', d => d.value.m)
    this.chart.stack(group, 'n', d => d.value.n)
    this.chart.stack(group, 'na', d => d.value.na)
    // this.chart.yAxis().ticks(4).tickFormat(d3.format('.2s'))
    this.chart.yAxis().ticks(4)
    this.chart.render()
  },
  beforeDestroy () {
    d3.selectAll('.d3-tip.season-chart').remove()
  }
}
</script>
