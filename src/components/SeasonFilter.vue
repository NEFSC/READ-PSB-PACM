<template>
  <div class="season-filter">
    <v-btn icon x-small class="mt-1 float-right" color="grey" @click="reset"><v-icon>mdi-sync</v-icon></v-btn>
    <div class="subtitle-1 mb-2 font-weight-medium">
      Season:

      <v-menu
        v-model="start.show"
        :close-on-content-click="false"
        :nudge-right="40"
        transition="scale-transition"
        offset-y
        min-width="290px">
        <template v-slot:activator="{ on }">
          <span class="filter-value" v-on="on">{{ start.jday | dayLabel }}</span>
        </template>
        <v-date-picker
          v-model="start.date"
          @input="start.show = false">
          <template>
            <div class="text-center" style="width:100%">
              Select a start month and day<br>(year does not matter)
            </div>
          </template>
        </v-date-picker>
      </v-menu>

      to

      <v-menu
        v-model="end.show"
        :close-on-content-click="false"
        :nudge-right="40"
        transition="scale-transition"
        offset-y
        min-width="290px">
        <template v-slot:activator="{ on }">
          <span class="filter-value" v-on="on">{{ end.jday | dayLabel }}</span>
        </template>
        <v-date-picker
          v-model="end.date"
          @input="end.show = false">
          <template>
            <div class="text-center" style="width:100%">
              Select a end month and day<br>(year does not matter)
            </div>
          </template>
        </v-date-picker>
      </v-menu>
    </div>
    <!-- <div>
      <pre>{{ start.date }} ({{ start.jday }}) - {{ end.date }} ({{ end.jday }})</pre>
    </div> -->
    <SeasonChart :y-axis-label="yAxisLabel"></SeasonChart>
    <svg class="season-filter-container"></svg>
  </div>
</template>

<script>
// ref: https://bl.ocks.org/mbostock/6452972

import * as d3 from 'd3'
import dc from 'dc'
import moment from 'moment'
import debounce from 'debounce'

import SeasonChart from '@/components/SeasonChart'
import evt from '@/lib/events'
import { xf } from '@/lib/crossfilter'

export default {
  name: 'SeasonFilter',
  props: ['yAxisLabel'],
  components: {
    SeasonChart
  },
  data () {
    return {
      start: {
        show: false,
        jday: 1,
        date: `${new Date().getFullYear()}-01-01`
      },
      end: {
        show: false,
        jday: 365,
        date: `${new Date().getFullYear()}-12-31`
      },
      x: d3.scaleLinear()
        .domain([1, 365])
        .clamp(true)
    }
  },
  watch: {
    'start.date' (val) {
      const m = moment(val)
      if (val.endsWith('02-29')) {
        m.add(1, 'day')
        this.start.date = m.format('YYYY-MM-DD')
      }
      if (m.isLeapYear()) {
        m.subtract(1, 'year')
      }
      this.start.jday = m.dayOfYear()
      this.render()
    },
    'start.jday' (val) {
      let m = moment('2000-12-31').add(val, 'days')
      this.start.date = moment([this.start.date.substr(0, 4), m.month(), m.date()]).format('YYYY-MM-DD')
    },
    'end.date' (val) {
      const m = moment(val)
      if (val.endsWith('02-29')) {
        m.add(1, 'day')
        this.end.date = m.format('YYYY-MM-DD')
      }
      if (m.isLeapYear()) {
        m.subtract(1, 'year')
      }
      this.end.jday = m.dayOfYear()
      this.render()
    },
    'end.jday' (val) {
      let m = moment('2000-12-31').add(val, 'days')
      this.end.date = moment([this.end.date.substr(0, 4), m.month(), m.date()]).format('YYYY-MM-DD')
    }
  },
  filters: {
    dayLabel (value) {
      return moment('2000-12-31').add(value, 'days').format('MMM D')
    }
  },
  mounted () {
    this.dim = xf.dimension(d => d.doy)

    const margins = {
      left: 72,
      right: 20,
      top: 20,
      bottom: 20
    }

    // const width = this.$el.clientWidth - margins.left - margins.right
    const width = 358
    const height = 60

    this.x.range([0, width])

    this.svg = d3.select(this.$el).select('svg.season-filter-container')
      .attr('width', width + margins.left + margins.right)
      .attr('height', height)

    const axisScale = d3.scaleTime()
      .domain([new Date(2001, 0, 1), new Date(2001, 11, 31)])
      .range([0, width])
    const axis = d3.axisBottom(axisScale)
      .ticks(d3.timeMonth)
      .tickFormat(d3.timeFormat('%b'))

    const container = this.svg.append('g')
      .attr('transform', `translate(${margins.left}, 30)`)
    container.append('g')
      .attr('class', 'axis')
      .attr('transform', `translate(0, 2)`)
      .call(axis)

    const slider = container.append('g')
      .attr('class', 'slider')

    slider.append('line')
      .attr('class', 'track')
      .attr('x1', this.x.range()[0])
      .attr('x2', this.x.range()[1])

    slider.append('line')
      .attr('class', 'track-inset')
      .attr('x1', this.x.range()[0])
      .attr('x2', this.x.range()[1])

    slider.append('line')
      .attr('class', 'track-highlight one')
      .attr('x1', this.x(this.start.jday))
      .attr('x2', this.x(this.end.jday))
    slider.append('line')
      .attr('class', 'track-highlight two')
      .attr('x1', this.x(this.start.jday))
      .attr('x2', this.x(this.end.jday))
      .attr('display', 'none')

    slider.append('line')
      .attr('class', 'track-overlay')
      .attr('x1', this.x.range()[0])
      .attr('x2', this.x.range()[1])
      .call(d3.drag()
        .on('start drag', () => {
          if (this.start.jday === this.x.domain()[0] && this.end.jday === this.x.domain()[1]) return
          const dx = d3.event.dx
          const dxScale = this.x(2) - this.x(1)

          this.start.jday = Math.round(this.start.jday + dx / dxScale)
          if (this.start.jday < this.x.domain()[0]) {
            this.start.jday = this.x.domain()[1] - (this.x.domain()[0] - this.start.jday) + 1
          }
          if (this.start.jday > this.x.domain()[1]) {
            this.start.jday = this.x.domain()[0] + (this.start.jday - this.x.domain()[1]) - 1
          }

          this.end.jday = Math.round(this.end.jday + dx / dxScale)
          if (this.end.jday < this.x.domain()[0]) {
            this.end.jday = this.x.domain()[1] - (this.x.domain()[0] - this.end.jday) + 1
          }
          if (this.end.jday > this.x.domain()[1]) {
            this.end.jday = this.x.domain()[0] + (this.end.jday - this.x.domain()[1]) - 1
          }

          this.render()
        })
      )

    const handleStart = slider
      .append('g')
      .attr('class', 'handle start')
    handleStart
      .append('circle')
      .attr('cx', this.x(this.start.jday))
      .attr('r', 9)
      .call(d3.drag()
        .on('start drag', () => {
          this.start.jday = Math.round(this.x.invert(d3.event.x))
          this.render()
        })
      )
    handleStart
      .append('text')
      .text('start')
      .attr('x', this.x(this.start.jday))
      .attr('y', -15)

    const handleEnd = slider
      .append('g')
      .attr('class', 'handle end')
    handleEnd
      .append('circle')
      .attr('cx', this.x(this.end.jday))
      .attr('r', 9)
      .call(d3.drag()
        .on('start drag', () => {
          this.end.jday = Math.round(this.x.invert(d3.event.x))
          this.render()
        })
      )

    handleEnd
      .append('text')
      .text('end')
      .attr('x', this.x(this.end.jday))
      .attr('y', -15)

    evt.$on('reset:filters', this.reset)
  },
  beforeDestroy () {
    this.dim && this.dim.dispose()
    evt.$off('reset:filters', this.reset)
  },
  methods: {
    reset () {
      this.start.jday = this.x.domain()[0]
      this.end.jday = this.x.domain()[1]
      this.render()
    },
    render () {
      const handleStart = this.svg.select('.handle.start')
      handleStart.select('circle').attr('cx', this.x(this.start.jday))
      handleStart.select('text').attr('x', this.x(this.start.jday))

      const handleEnd = this.svg.select('.handle.end')
      handleEnd.select('circle').attr('cx', this.x(this.end.jday))
      handleEnd.select('text').attr('x', this.x(this.end.jday))

      const highlightTrack1 = this.svg.select('.track-highlight.one')
      const highlightTrack2 = this.svg.select('.track-highlight.two')
      if (this.start.jday <= this.end.jday) {
        highlightTrack1
          .attr('x1', this.x(this.start.jday))
          .attr('x2', this.x(this.end.jday))
        highlightTrack2
          .attr('display', 'none')
      } else {
        highlightTrack1
          .attr('x1', this.x(0))
          .attr('x2', this.x(this.end.jday))
        highlightTrack2
          .attr('x1', this.x(this.start.jday))
          .attr('x2', this.x(365))
          .attr('display', null)
      }
      this.setFilter()
      // this.$emit('update', [this.start.jday, this.end.jday])
    },
    setFilter: debounce(function () {
      // console.log('SeasonFilter: setFilter')
      // this.season.start = start
      // this.season.end = end === 365 ? 366 : end
      const start = this.start.jday
      const end = this.end.jday
      // const end = this.end.jday === 365 ? 366 : this.end.jday
      if (start <= end) {
        this.dim.filterRange([start, end + 0.01])
      } else {
        this.dim.filterFunction(d => d >= start || d <= end)
      }
      // evt.$emit('render:map', 'setSeason')
      dc.redrawAll()
    }, 1, true)
  }
}
</script>

<style>
.season-filter .ticks {
  font: 10px sans-serif;
}

.season-filter .track,
.season-filter .track-inset,
.season-filter .track-overlay {
  stroke-linecap: round;
}

.season-filter .track {
  stroke: #000;
  stroke-opacity: 0.3;
  stroke-width: 10px;
}

.season-filter .track-inset {
  stroke: #455A64;
  stroke-width: 8px;
}

.season-filter .track-overlay {
  pointer-events: stroke;
  stroke-width: 20px;
  stroke: transparent;
  cursor: move;
}

.season-filter .track-highlight {
  stroke: #CFD8DC;
  stroke-width: 4px;
  stroke-linecap: round;
}

.season-filter .handle circle {
  fill: #FFF;
  stroke: #FFF;
  stroke-opacity: 0.5;
  stroke-width: 1.25px;
}

.season-filter .handle text {
  text-anchor: middle;
  font-variant: small-caps;
  font-size: 12pt;
  fill: #FFF;
  font-weight: 500;
}

.season-filter svg.season-filter-container .axis .tick text {
  font-weight: 400;
  font-size: 10pt;
  fill: hsl(0, 0%, 90%);
}
</style>
