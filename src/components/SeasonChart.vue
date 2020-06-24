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
    // console.log('SeasonChart:mounted')

    const dim = xf.dimension(d => moment('2000-01-01').add(Math.floor(moment(d.date).dayOfYear() / 6) * 6, 'days').toDate())
    const group = dim.group().reduce(
      (p, v) => {
        p[v.detection] = (p[v.detection] || 0) + 1
        return p
      },
      (p, v) => {
        p[v.detection] = (p[v.detection] || 0) - 1
        return p
      },
      () => {
        return {
          yes: 0,
          no: 0,
          maybe: 0
        }
      }
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
          ${pad(10, detectionTypesMap.get('no').label, '&nbsp;')}: ${d.data.value.no.toLocaleString()}<br>
          ${pad(10, detectionTypesMap.get('maybe').label, '&nbsp;')}: ${d.data.value.maybe.toLocaleString()}<br>
          ${pad(10, detectionTypesMap.get('yes').label, '&nbsp;')}: ${d.data.value.yes.toLocaleString()}
        `
      })

    this.chart = dc.barChart(this.$el.appendChild(document.createElement('div')))
      .width(450)
      .height(120)
      .margins({ top: 10, right: 20, bottom: 5, left: 60 })
      .dimension(dim)
      .group(group, 'yes', (d) => d.value.yes)
      .x(d3.scaleTime().domain([new Date(2000, 0, 1), new Date(2000, 11, 31)]))
      .xUnits(() => 61)
      .colors(d3.scaleOrdinal().range(detectionTypes.map(d => d.color)))
      .elasticY(true)
      .brushOn(false)
      .yAxisLabel('# Days Recorded')
      .gap(0)
      .barPadding(0.3)
      .renderTitle(false)
      .on('filtered', this.updateFill)
      .on('postRender', (chart) => {
        chart.g().call(this.tip)
        chart.selectAll('rect.bar')
          .on('mouseenter', this.tip.show)
          .on('mouseout', this.tip.hide)
      })

    dc.override(this.chart, 'legendables', () => {
      return this.chart._legendables().reverse()
    })
    this.chart.stack(group, 'maybe', d => d.value.maybe)
    this.chart.stack(group, 'no', d => d.value.no)
    // this.chart.yAxis().ticks(4).tickFormat(d3.format('.2s'))
    this.chart.yAxis().ticks(4)
    this.chart.render()
  },
  beforeDestroy () {
    d3.selectAll('.d3-tip.season-chart').remove()
  }
}
</script>
