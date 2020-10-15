<template>
  <div class="year-filter">
    <v-btn icon x-small class="mt-1 float-right" color="grey" @click="reset"><v-icon>mdi-sync</v-icon></v-btn>
    <div class="subtitle-1 mb-2 font-weight-medium">
      Years:

      <v-menu
        v-model="start.show"
        :close-on-content-click="false"
        :nudge-right="40"
        transition="scale-transition"
        offset-y
        min-width="200px">
        <template v-slot:activator="{ on }">
          <span class="filter-value" v-on="on">{{ filter[0] }}</span>
        </template>
        <v-card class="pa-1">
          <v-card-text>
            <div class="subtitle-2">Start Year</div>
            <v-text-field
              v-model="start.value"
              single-line
              hide-details
              type="number"
              @keydown.enter="setStart">
            </v-text-field>
          </v-card-text>
          <v-card-actions class="pr-4">
            <v-spacer></v-spacer>
            <v-btn color="primary" outlined @click="setStart">Done</v-btn>
          </v-card-actions>
        </v-card>
      </v-menu>

      to

      <v-menu
        v-model="end.show"
        :close-on-content-click="false"
        :nudge-right="40"
        transition="scale-transition"
        offset-y
        min-width="200px">
        <template v-slot:activator="{ on }">
          <span class="filter-value" v-on="on">{{ filter[1] - 1 }}</span>
        </template>
        <v-card class="pa-1">
          <v-card-text>
            <div class="subtitle-2">End Year</div>
            <v-text-field
              v-model="end.value"
              single-line
              hide-details
              type="number"
              @keydown.enter="setEnd">
            </v-text-field>
          </v-card-text>
          <v-card-actions class="pr-4">
            <v-spacer></v-spacer>
            <v-btn color="primary" outlined @click="setEnd">Done</v-btn>
          </v-card-actions>
        </v-card>
      </v-menu>
    </div>
  </div>
</template>

<script>
import * as d3 from 'd3'
import dc from 'dc'

import ChartMixin from '@/mixins/ChartMixin'
import { xf } from '@/lib/crossfilter'
import { detectionTypes } from '@/lib/constants'

export default {
  name: 'YearFilter',
  mixins: [ChartMixin],
  data () {
    return {
      chart: null,
      extent: [2004, 2020],
      filter: [2004, 2020],
      start: {
        value: '2004',
        show: false
      },
      end: {
        value: '2020',
        show: false
      }
    }
  },
  watch: {
  },
  mounted () {
    const dim = xf.dimension(d => d.date.getFullYear())
    const group = dim.group().reduce(
      (p, v) => {
        p[v.presence] = (p[v.presence] || 0) + 1
        return p
      },
      (p, v) => {
        p[v.presence] = (p[v.presence] || 0) - 1
        return p
      },
      () => {
        return {
          y: 0,
          n: 0,
          m: 0
        }
      }
    )
    this.extent = d3.extent(xf.all().map(d => d.date.getFullYear()))
    this.filter = [this.extent[0], this.extent[1] + 1]

    this.chart = dc.barChart(this.$el.appendChild(document.createElement('div')))
      .width(450)
      .height(160)
      .margins({ top: 10, right: 20, bottom: 40, left: 60 })
      .dimension(dim)
      .group(group, 'y', (d) => d.value.y)
      .elasticY(true)
      .x(d3.scaleLinear().domain(this.filter.slice()))
      .xAxisLabel('Year')
      .yAxisLabel(this.yAxisLabel)
      .round(dc.round.round)
      .colors(d3.scaleOrdinal().range(detectionTypes.map(d => d.color)))
      .on('filtered', (chart, filter) => {
        this.filter = filter ? [filter[0], filter[1]] : [this.extent[0], this.extent[1] + 1]
        this.start.value = this.filter[0].toString()
        this.end.value = (this.filter[1] - 1).toString()
      })
      // .on('postRender', (chart) => {
      //   const n = chart.xUnitCount()
      //   const width = chart.effectiveWidth()
      //   // chart.selectAll('.axis.x .tick line')
      //   //   .attr('transform', `translate(${Math.floor(width / n / 2)} 0)`)
      //   chart.selectAll('.axis.x .tick text')
      //     .attr('transform', `translate(${Math.floor(width / n / 2)} 0)`)
      // })

    this.chart.stack(group, 'm', d => d.value.m)
    this.chart.stack(group, 'n', d => d.value.n)
    this.chart.xAxis().ticks(this.extent[1] - this.extent[0]).tickFormat(v => {
      return (v % (this.extent[1] - this.extent[0] > 4 ? 2 : 1) > 0) || v >= (this.extent[1] + 1) ? '' : d3.format('d')(v)
    })
    this.chart.yAxis().ticks(4)
    // this.chart.yAxis().ticks(4).tickFormat(d3.format('.0s'))
    this.chart.render()
  },
  methods: {
    setStart () {
      if (+this.start.value < this.extent[0]) {
        this.start.value = this.extent[0].toString()
      } else if (+this.start.value > (this.filter[1] - 1)) {
        this.start.value = (this.filter[1] - 1).toString()
      }

      this.filter[0] = +this.start.value
      this.start.show = false
      this.update()
    },
    setEnd () {
      if (+this.end.value > this.extent[1]) {
        this.end.value = this.extent[1].toString()
      } else if (+this.end.value < this.filter[0]) {
        this.end.value = this.filter[0].toString()
      }

      this.filter[1] = +this.end.value + 1
      this.end.show = false
      this.update()
    },
    update () {
      const [low, high] = this.filter
      this.chart.filterAll()
      if (low > this.extent[0] || high < (this.extent[1] + 1)) {
        this.chart.filter(dc.filters.RangedFilter(low, high))
      }
      dc.redrawAll()
    }
  }
}
</script>

<style>
</style>
