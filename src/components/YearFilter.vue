<template>
  <div class="pacm-year-filter">
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
          <span class="pacm-filter-value" v-on="on">{{ filter[0] }}</span>
        </template>
        <v-card class="pa-1">
          <v-card-text>
            <div class="subtitle-2">Start Year</div>
            <v-text-field
              v-model="start.input"
              single-line
              hide-details
              type="number"
              @keydown.enter="setStart">
            </v-text-field>
          </v-card-text>
          <v-card-actions class="pr-4">
            <v-spacer></v-spacer>
            <v-btn color="primary" outlined @click="setStart" aria-label="done">Done</v-btn>
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
          <span class="pacm-filter-value" v-on="on">{{ filter[1] }}</span>
        </template>
        <v-card class="pa-1">
          <v-card-text>
            <div class="subtitle-2">End Year</div>
            <v-text-field
              v-model="end.input"
              single-line
              hide-details
              type="number"
              @keydown.enter="setEnd">
            </v-text-field>
          </v-card-text>
          <v-card-actions class="pr-4">
            <v-spacer></v-spacer>
            <v-btn color="primary" outlined @click="setEnd" aria-label="done">Done</v-btn>
          </v-card-actions>
        </v-card>
      </v-menu>
    </div>
    <YearChart :y-axis-label="yAxisLabel"></YearChart>
    <svg class="pacm-year-slider"></svg>
  </div>
</template>

<script>
// ref: https://bl.ocks.org/mbostock/6452972

import * as d3 from 'd3'
import * as dc from 'dc'
import debounce from 'debounce'

import YearChart from '@/components/YearChart'
import evt from '@/lib/events'
import { xf } from '@/lib/crossfilter'

export default {
  name: 'YearFilter',
  props: ['yAxisLabel'],
  components: {
    YearChart
  },
  data () {
    return {
      extent: [2004, 2020],
      filter: [2004, 2020],
      start: {
        value: 2004,
        input: '2004',
        show: false
      },
      end: {
        value: 2021,
        input: '2020',
        show: false
      },
      drag: {
        x: 0,
        start: null,
        end: null
      }
    }
  },
  computed: {
    domain () {
      return [this.extent[0], this.extent[1] + 1]
    },
    x () {
      return d3.scaleLinear()
        .domain(this.domain)
        .clamp(true)
    }
  },
  watch: {
    'start.value' (val) {
      if (this.start.value < this.extent[0]) {
        this.start.value = this.extent[0]
      }
      this.start.input = this.start.value.toString()
      this.render()
    },
    'end.value' (val) {
      if (this.end.value > this.domain[1]) {
        this.end.value = this.domain[1]
      }
      this.end.input = (this.end.value - 1).toString()
      this.render()
    }
  },
  mounted () {
    this.dim = xf.dimension(d => d.year)
    this.extent = d3.extent(xf.all().map(d => d.year))
    this.filter = this.extent
    this.start.value = this.filter[0]
    this.end.value = this.filter[1] + 1

    const margins = {
      left: 72,
      right: 20,
      top: 20,
      bottom: 20
    }

    // const width = this.$el.clientWidth - margins.left - margins.right
    const width = 358
    const height = 35

    this.x.range([0, width])

    this.svg = d3.select(this.$el).select('svg.pacm-year-slider')
      .attr('width', width + margins.left + margins.right)
      .attr('height', height)

    const container = this.svg.append('g')
      .attr('transform', `translate(${margins.left}, 10)`)

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
      .attr('class', 'track-highlight')
      .attr('x1', this.x(this.start.value))
      .attr('x2', this.x(this.end.value))

    const dxPerYear = this.x(this.x.domain()[0] + 1) - this.x(this.x.domain()[0])

    slider.append('line')
      .attr('class', 'track-overlay')
      .attr('x1', this.x.range()[0])
      .attr('x2', this.x.range()[1])
      .call(d3.drag()
        .on('start', () => {
          this.drag.x = 0
          this.drag.start = this.start.value
          this.drag.end = this.end.value
        })
        .on('drag', (event) => {
          const dx = event.dx

          if (dx === 0) return

          this.drag.x += event.dx
          const dYear = Math.round(this.drag.x / dxPerYear)

          if (this.drag.x < 0) {
            // shift left
            const newStart = Math.max(this.x.domain()[0], this.drag.start + dYear)
            const shift = newStart - this.drag.start

            this.start.value = newStart
            this.end.value = this.drag.end + shift
          } else {
            // shift right
            const newEnd = Math.min(this.x.domain()[1], this.drag.end + dYear)
            const shift = newEnd - this.drag.end

            this.end.value = newEnd
            this.start.value = this.drag.start + shift
          }
          this.render()
        })
        .on('end', () => {
          this.drag.x = 0
          this.drag.start = null
          this.drag.end = null
        })
      )

    const handleStart = slider
      .append('g')
      .attr('class', 'handle start')
    handleStart
      .append('circle')
      .attr('cx', this.x(this.start.value))
      .attr('r', 9)
      .call(d3.drag()
        .on('start drag', (event) => {
          const newStart = Math.round(this.x.invert(event.x))
          if (newStart < this.end.value) {
            this.start.value = newStart
            this.render()
          }
        })
      )
    handleStart
      .append('text')
      .text('start')
      .attr('x', this.x(this.start.value))
      .attr('y', 22)

    const handleEnd = slider
      .append('g')
      .attr('class', 'handle end')
    handleEnd
      .append('circle')
      .attr('cx', this.x(this.end.value))
      .attr('r', 9)
      .call(d3.drag()
        .on('start drag', (event) => {
          const newEnd = Math.round(this.x.invert(event.x))
          if (newEnd > this.start.value) {
            this.end.value = newEnd
            this.render()
          }
        })
      )

    handleEnd
      .append('text')
      .text('end')
      .attr('x', this.x(this.end.value))
      .attr('y', 22)

    evt.$on('reset:filters', this.reset)
  },
  beforeDestroy () {
    if (this.dim) {
      this.dim.filterAll()
      this.dim.dispose()
    }
    evt.$off('reset:filters', this.reset)
  },
  methods: {
    setStart () {
      this.start.show = false
      this.start.value = +this.start.input

      if (this.start.value < this.extent[0]) {
        this.start.value = this.extent[0]
      }

      if (this.start.value >= this.end.value) {
        this.start.value = this.end.value - 1
      }

      this.start.input = this.start.value.toString()

      this.render()
    },
    setEnd () {
      this.end.show = false
      this.end.value = +this.end.input + 1

      if (this.end.value > (this.extent[1] + 1)) {
        this.end.value = this.extent[1] + 1
      }

      if (this.end.value <= this.start.value) {
        this.end.value = this.start.value + 1
      }

      this.end.input = (this.end.value - 1).toString()

      this.render()
    },
    reset () {
      // console.log('YearFilter:reset()')
      this.start.value = this.x.domain()[0]
      this.end.value = this.x.domain()[1]
      this.render()
    },
    render () {
      // console.log('YearFilter:render()')
      const handleStart = this.svg.select('.handle.start')
      handleStart.select('circle').attr('cx', this.x(this.start.value))
      handleStart.select('text').attr('x', this.x(this.start.value))

      const handleEnd = this.svg.select('.handle.end')
      handleEnd.select('circle').attr('cx', this.x(this.end.value))
      handleEnd.select('text').attr('x', this.x(this.end.value))

      this.svg.select('.track-highlight')
        .attr('x1', this.x(this.start.value))
        .attr('x2', this.x(this.end.value))

      this.setFilter()
      // this.$emit('update', [this.start.jday, this.end.jday])
    },
    setFilter: debounce(function () {
      // console.log('YearFilter:setFilter()')
      const start = this.start.value
      const end = this.end.value - 1

      this.filter = [start, end]
      this.dim.filterRange([start, end + 1])

      dc.redrawAll()
    }, 1, true)
  }
}
</script>

<style>
.pacm-year-filter .ticks {
  font: 10px sans-serif;
}

.pacm-year-filter .track,
.pacm-year-filter .track-inset,
.pacm-year-filter .track-overlay {
  stroke-linecap: round;
}

.pacm-year-filter .track {
  stroke: #000;
  stroke-opacity: 0.3;
  stroke-width: 10px;
}

.pacm-year-filter .track-inset {
  stroke: #455A64;
  stroke-width: 8px;
}

.pacm-year-filter .track-overlay {
  pointer-events: stroke;
  stroke-width: 20px;
  stroke: transparent;
  cursor: move;
}

.pacm-year-filter .track-highlight {
  stroke: #CFD8DC;
  stroke-width: 4px;
  stroke-linecap: round;
}

.pacm-year-filter .handle circle {
  fill: #FFF;
  stroke: #FFF;
  stroke-opacity: 0.5;
  stroke-width: 1.25px;
}

.pacm-year-filter .handle text {
  text-anchor: middle;
  font-variant: small-caps;
  font-size: 12pt;
  fill: #FFF;
  font-weight: 500;
}

.pacm-year-filter svg.pacm-year-slider .axis .tick text {
  font-weight: 400;
  font-size: 10pt;
  fill: hsl(0, 0%, 90%);
}
</style>
