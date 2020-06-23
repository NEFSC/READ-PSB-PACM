<template>
  <div class="season-filter">
    <v-btn icon x-small class="mt-1 float-right" color="grey" @click="reset"><v-icon>mdi-sync</v-icon></v-btn>
    <div class="subtitle-1 mb-2 font-weight-medium">
      Season: <span class="filter-value">{{ start | dayLabel }}</span> to <span class="filter-value">{{ end | dayLabel }}</span></div>
    <SeasonChart></SeasonChart>
    <svg class="season-filter-container"></svg>
  </div>
</template>

<script>
// ref: https://bl.ocks.org/mbostock/6452972

import * as d3 from 'd3'
import moment from 'moment'

import SeasonChart from '@/components/SeasonChart'
import evt from '@/lib/events'

export default {
  name: 'SeasonFilter',
  components: {
    SeasonChart
  },
  data () {
    return {
      start: 1,
      end: 365,
      x: d3.scaleLinear()
        .domain([1, 365])
        .clamp(true)
    }
  },
  filters: {
    dayLabel (value) {
      return moment('2000-12-31').add(value, 'days').format('MMM D')
    }
  },
  mounted () {
    const margins = {
      left: 72,
      right: 10,
      top: 20,
      bottom: 20
    }

    const width = this.$el.clientWidth - margins.left - margins.right
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
      .attr('x1', this.x(this.start))
      .attr('x2', this.x(this.end))
    slider.append('line')
      .attr('class', 'track-highlight two')
      .attr('x1', this.x(this.start))
      .attr('x2', this.x(this.end))
      .attr('display', 'none')

    slider.append('line')
      .attr('class', 'track-overlay')
      .attr('x1', this.x.range()[0])
      .attr('x2', this.x.range()[1])
      .call(d3.drag()
        .on('start drag', () => {
          if (this.start === this.x.domain()[0] && this.end === this.x.domain()[1]) return
          const dx = d3.event.dx
          const dxScale = this.x(2) - this.x(1)

          this.start = Math.round(this.start + dx / dxScale)
          if (this.start < this.x.domain()[0]) {
            this.start = this.x.domain()[1] - (this.x.domain()[0] - this.start) + 1
          }
          if (this.start > this.x.domain()[1]) {
            this.start = this.x.domain()[0] + (this.start - this.x.domain()[1]) - 1
          }

          this.end = Math.round(this.end + dx / dxScale)
          if (this.end < this.x.domain()[0]) {
            this.end = this.x.domain()[1] - (this.x.domain()[0] - this.end) + 1
          }
          if (this.end > this.x.domain()[1]) {
            this.end = this.x.domain()[0] + (this.end - this.x.domain()[1]) - 1
          }

          this.render()
        })
      )

    const handleStart = slider
      .append('g')
      .attr('class', 'handle start')
    handleStart
      .append('circle')
      .attr('cx', this.x(this.start))
      .attr('r', 9)
      .call(d3.drag()
        .on('start drag', () => {
          this.start = Math.round(this.x.invert(d3.event.x))
          this.render()
        })
      )
    handleStart
      .append('text')
      .text('start')
      .attr('x', this.x(this.start))
      .attr('y', -15)

    const handleEnd = slider
      .append('g')
      .attr('class', 'handle end')
    handleEnd
      .append('circle')
      .attr('cx', this.x(this.end))
      .attr('r', 9)
      .call(d3.drag()
        .on('start drag', () => {
          this.end = Math.round(this.x.invert(d3.event.x))
          this.render()
        })
      )

    handleEnd
      .append('text')
      .text('end')
      .attr('x', this.x(this.end))
      .attr('y', -15)

    evt.$on('reset:filters', this.reset)
  },
  beforeDestroy () {
    evt.$off('reset:filters', this.reset)
  },
  methods: {
    reset () {
      this.start = this.x.domain()[0]
      this.end = this.x.domain()[1]
      this.render()
    },
    render () {
      const handleStart = this.svg.select('.handle.start')
      handleStart.select('circle').attr('cx', this.x(this.start))
      handleStart.select('text').attr('x', this.x(this.start))

      const handleEnd = this.svg.select('.handle.end')
      handleEnd.select('circle').attr('cx', this.x(this.end))
      handleEnd.select('text').attr('x', this.x(this.end))

      const highlightTrack1 = this.svg.select('.track-highlight.one')
      const highlightTrack2 = this.svg.select('.track-highlight.two')
      if (this.start <= this.end) {
        highlightTrack1
          .attr('x1', this.x(this.start))
          .attr('x2', this.x(this.end))
        highlightTrack2
          .attr('display', 'none')
      } else {
        highlightTrack1
          .attr('x1', this.x(0))
          .attr('x2', this.x(this.end))
        highlightTrack2
          .attr('x1', this.x(this.start))
          .attr('x2', this.x(365))
          .attr('display', null)
      }
      this.$emit('update', [this.start, this.end])
    }
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
