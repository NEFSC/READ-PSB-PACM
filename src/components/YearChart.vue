<template>
  <div class="year-chart">
  </div>
</template>

<script>
import * as d3 from 'd3'
import dc from 'dc'
import d3Tip from 'd3-tip'
import pad from 'pad'

import ChartMixin from '@/mixins/ChartMixin'
import { xf } from '@/lib/crossfilter'
import { detectionTypes, detectionTypesMap } from '@/lib/constants'
import { mapGetters } from 'vuex'

export default {
  name: 'YearChart',
  mixins: [ChartMixin],
  data () {
    return {
      chart: null
    }
  },
  computed: {
    ...mapGetters(['theme'])
  },
  watch: {
    theme () {
      this.updateChart()
    }
  },
  mounted () {
    const dim = xf.dimension(d => d.year)
    this.group = dim.group().reduce(
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
      .attr('class', 'd3-tip year-chart')
      .attr('role', 'complementary')
      .direction('e')
      .html((d) => {
        const header = `Year: ${d.data.key}<br><br>`

        let body
        if (this.theme.deploymentsOnly) {
          body = `
            ${pad(12, detectionTypesMap.get('d').label, '&nbsp;')}: ${pad(6, d.data.value.d.toLocaleString(), '&nbsp;')}<br>
          `
        } else {
          body = `
            ${pad(12, detectionTypesMap.get('y').label, '&nbsp;')}: ${pad(6, d.data.value.y.toLocaleString(), '&nbsp;')}<br>
            ${pad(12, detectionTypesMap.get('m').label, '&nbsp;')}: ${pad(6, d.data.value.m.toLocaleString(), '&nbsp;')}<br>
            ${pad(12, detectionTypesMap.get('n').label, '&nbsp;')}: ${pad(6, d.data.value.n.toLocaleString(), '&nbsp;')}<br>
            ${pad(12, detectionTypesMap.get('na').label, '&nbsp;')}: ${pad(6, d.data.value.na.toLocaleString(), '&nbsp;')}
          `
        }
        return `${header} ${body}`
      })

    const extent = d3.extent(xf.all().map(d => d.year))
    const filter = [extent[0], extent[1] + 1]

    const el = this.$el.appendChild(document.createElement('div'))
    this.chart = dc.barChart(el)
      .width(450)
      .height(120)
      .margins({ top: 10, right: 20, bottom: 22, left: 60 })
      .dimension(dim)
      .group(this.group, 'y', (d) => d.value.y)
      .x(d3.scaleLinear().domain(filter.slice()))
      .xUnits(() => filter[1] - filter[0])
      .colors(d3.scaleOrdinal().range(detectionTypes.map(d => d.color)))
      .elasticY(true)
      .brushOn(false)
      .yAxisLabel(this.yAxisLabel)
      .gap(0)
      .barPadding(0.1)
      .renderTitle(false)

    setTimeout(() => {
      this.chart.g().call(this.tip)
      this.chart.selectAll('rect.bar')
        .on('mouseenter', this.tip.show)
        .on('mouseout', this.tip.hide)
    }, 500)

    dc.override(this.chart, 'legendables', () => {
      return this.chart._legendables().reverse()
    })
    this.chart.stack(this.group, 'm', d => d.value.m)
    this.chart.stack(this.group, 'n', d => d.value.n)
    this.chart.stack(this.group, 'na', d => d.value.na)
    this.chart.stack(this.group, 'd', d => d.value.d)
    this.chart.xAxis().ticks(6).tickFormat(d3.format('d'))
    this.chart.yAxis().ticks(4)
    this.chart.render()

    this.updateChart()
  },
  beforeDestroy () {
    d3.selectAll('.d3-tip.year-chart').remove()
  },
  methods: {
    updateChart () {
      if (!this.chart || !this.group) return

      this.chart.xAxis().ticks(Math.min(this.group.all().length, 6))
      this.chart.render()
    }
  }
}
</script>
