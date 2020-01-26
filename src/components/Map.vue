<template>
  <l-map
    ref="map"
    style="width:100%;height:100%"
    :center="[35, -60]"
    :zoom="5"
    @moveend="draw"
    @zoomend="draw">
    <l-tile-layer
      url="//server.arcgisonline.com/ArcGIS/rest/services/Ocean_Basemap/MapServer/tile/{z}/{y}/{x}"
      attribution="Tiles &copy; Esri &mdash; Sources: GEBCO, NOAA, CHS, OSU, UNH, CSUMB, National Geographic, DeLorme, NAVTEQ, and Esri'">
    </l-tile-layer>
  </l-map>
</template>

<script>
import { LMap, LTileLayer } from 'vue2-leaflet'
import * as d3 from 'd3'
import d3Tip from 'd3-tip'
import L from 'leaflet'
import moment from 'moment'

import evt from '@/lib/events'
import { xf, deploymentMap, isFiltered } from '@/lib/crossfilter'
import { detectionTypes, detectionTypesMap, platformTypesMap } from '@/lib/constants'

const MIN_RADIUS = 5

const colorScale = d3.scaleOrdinal()
  .domain(detectionTypes.map(d => d.id))
  .range(detectionTypes.map(d => d.color))

function createColorLegend (map) {
  const legend = L.control({ position: 'bottomright' })
  legend.onAdd = function (map) {
    const div = L.DomUtil.create('div', 'legend')
    const svg = d3.select(div)
      .append('svg')
      .attr('width', 130)
      .attr('height', 100)

    const radius = 8
    const padding = 15

    svg.append('text')
      .attr('class', 'legend-title')
      .attr('x', 0)
      .attr('y', 20)
      .text('Detection Type')

    svg.selectAll('circle.color')
      .data(['yes', 'maybe', 'no'])
      .join(
        enter => enter.append('circle').attr('class', 'color'),
        update => update,
        exit => exit.remove()
      )
      .attr('cx', 15)
      .attr('cy', (d, i) => i * (radius + padding) + 45)
      .attr('r', radius)
      .style('fill', colorScale)

    svg.selectAll('text.color')
      .data(['yes', 'maybe', 'no'])
      .join(
        enter => enter.append('text').attr('class', 'color'),
        update => update,
        exit => exit.remove()
      )
      .attr('x', 40)
      .attr('y', (d, i) => i * (radius + padding) + 45)
      .attr('dy', '0.3em')
      .text(d => detectionTypesMap.get(d).label)
    return div
  }
  legend.addTo(map)
}

function createSizeLegend (map) {
  const legend = L.control({ position: 'bottomright' })
  legend.onAdd = function (map) {
    const div = L.DomUtil.create('div', 'legend')
    const svg = d3.select(div)
      .append('svg')
      .attr('width', 130)
      .attr('height', 130)

    const minRadius = MIN_RADIUS
    const padding = 15

    const values = [0, 25, 50, 75, 100].reverse()

    svg.append('text')
      .attr('class', 'legend-title')
      .attr('x', 0)
      .attr('y', 20)
      .text('# Detection Days')

    svg.selectAll('circle.count')
      .data(values)
      .join(
        enter => enter.append('circle').attr('class', 'count'),
        update => update,
        exit => exit.remove()
      )
      .attr('cx', minRadius + 10)
      .attr('cy', (d, i) => i * (minRadius + padding) + 45)
      .attr('r', d => Math.sqrt(d) + minRadius)
      .style('fill', colorScale('yes'))

    svg.selectAll('text.count')
      .data(values)
      .join(
        enter => enter.append('text').attr('class', 'count'),
        update => update,
        exit => exit.remove()
      )
      .attr('x', minRadius + 35)
      .attr('y', (d, i) => i * (minRadius + padding) + 45)
      .attr('dy', '0.3em')
      .text(d => d)
    return div
  }
  legend.addTo(map)
}

export default {
  name: 'Map',
  props: ['points', 'tracks'],
  components: {
    LMap,
    LTileLayer
  },
  mounted () {
    const map = this.$refs.map.mapObject

    createColorLegend(map)
    createSizeLegend(map)

    const svgLayer = L.svg()
    map.addLayer(svgLayer)

    const svg = d3.select(svgLayer.getPane()).select('svg')
      .classed('leaflet-zoom-animated', false)
      .classed('leaflet-zoom-hide', true)
      .classed('map', true)
      .attr('pointer-events', null)
    this.container = svg.select('g')

    this.container.append('g').attr('class', 'glider tracks')
    this.container.append('g').attr('class', 'glider points')
    this.container.append('g').attr('class', 'static points')

    this.tip = d3Tip()
      .attr('class', 'd3-tip')
      .direction(function (d) {
        const viewBox = svg.attr('viewBox').split(' ').map(d => +d)
        const mapWidth = map.getSize().x
        const svgWidth = viewBox[2]
        const offsetX = viewBox[0]
        const pointX = d3.mouse(this)[0]

        const mapX = Math.round((mapWidth - svgWidth) / 2 - offsetX + pointX)
        return (mapWidth - mapX) < (0.5 * mapWidth) ? 'w' : 'e'
      })
      .html((d) => {
        let deployment = d
        let isGlider = d.platform_type === 'slocum'
        let isGliderTrack = isGlider && d.hasOwnProperty('data')
        if (isGlider && !isGliderTrack) {
          deployment = this.tracks.filter(track => track.deployment === d.deployment)[0]
        }

        const value = deploymentMap.get(deployment.deployment)
        const startDate = moment.utc(deployment.monitoring_start_datetime).startOf('date')
        const endDate = moment.utc(deployment.monitoring_end_datetime).startOf('date')
        const duration = moment.duration(endDate.diff(startDate))
        if (isGlider) {
          let html = `
            &nbsp;&nbsp;&nbsp;Project: ${deployment.project}<br>
            &nbsp;Unit Type: ${deployment.instrument_type}<br>
            &nbsp;&nbsp;Platform: ${platformTypesMap.get(deployment.platform_type).label}<br>
            &nbsp;&nbsp;Deployed: ${startDate.format('ll')} to ${endDate.format('ll')}<br>
            &nbsp;&nbsp;Duration: ${duration.asDays() + 1} days<br>
            <br>
            <u>Total Detection Days</u><br>
            &nbsp;&nbsp;${detectionTypesMap.get('yes').label}: ${value.yes.toLocaleString()}<br>
            &nbsp;&nbsp;${detectionTypesMap.get('maybe').label}: ${value.maybe.toLocaleString()}<br>
            ${detectionTypesMap.get('no').label}: ${value.no.toLocaleString()}
          `
          if (!isGliderTrack) {
            const analysisDate = moment.utc(d.date)
            html += `
              <br>
              <br>
              <u>Selected Date</u><br>
              &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Date: ${analysisDate.format('ll')}<br>
              &nbsp;&nbsp;Position: ${d.latitude.toFixed(4)}, ${d.longitude.toFixed(4)}<br>
              &nbsp;&nbsp;&nbsp;&nbsp;Result: ${detectionTypesMap.get(d.detection).label}
            `
          } else {
            // reposition tip for glider track from bbox to mouse
            const x = d3.event.x
            const y = d3.event.y
            setTimeout(() => {
              const tip = d3.select('.d3-tip')
              const offsetX = tip.classed('w') ? -1 * tip.node().clientWidth - 10 : 10
              const height = tip.node().clientHeight
              d3.select('.d3-tip')
                .style('top', (y - height / 2) + 'px')
                .style('left', (x + offsetX) + 'px')
            }, 10)
          }
          return html
        }
        return `
          &nbsp;&nbsp;&nbsp;Project: ${deployment.project}<br>
          &nbsp;&nbsp;&nbsp;Site ID: ${deployment.site_id}<br>
          &nbsp;Unit Type: ${deployment.instrument_type}<br>
          &nbsp;&nbsp;Platform: ${platformTypesMap.get(deployment.platform_type).label}<br>
          &nbsp;&nbsp;Position: ${deployment.latitude.toFixed(4)}, ${deployment.longitude.toFixed(4)}<br>
          &nbsp;&nbsp;Deployed: ${startDate.format('ll')} to ${endDate.format('ll')}<br>
          &nbsp;&nbsp;Duration: ${duration.asDays() + 1} days<br>
          <br>
          <u>Total Detection Days</u><br>
          &nbsp;&nbsp;${detectionTypesMap.get('yes').label}: ${value.yes.toLocaleString()}<br>
          &nbsp;&nbsp;${detectionTypesMap.get('maybe').label}: ${value.maybe.toLocaleString()}<br>
          ${detectionTypesMap.get('no').label}: ${value.no.toLocaleString()}
        `
      })
    this.container.call(this.tip)

    this.draw()
    evt.$on('render:map', this.render)
  },
  beforeDestroy () {
    evt.$off('render:map', this.render)
    d3.selectAll('.d3-tip').remove()
  },
  watch: {
    points () {
      this.draw()
    }
  },
  methods: {
    draw () {
      if (!this.container) return
      const map = this.$refs.map.mapObject

      this.container
        .select('g.static.points')
        .selectAll('circle')
        .data(this.points.filter(d => d.platform_type !== 'slocum'), d => d.deployment)
        .join(
          enter => enter.append('circle').attr('class', 'point'),
          update => update,
          exit => exit.remove()
        )
        .attr('cx', (d) => map.latLngToLayerPoint(new L.LatLng(d.latitude, d.longitude)).x)
        .attr('cy', (d) => map.latLngToLayerPoint(new L.LatLng(d.latitude, d.longitude)).y)
        .on('mouseenter', this.tip.show)
        .on('mouseout', this.tip.hide)
        .on('click', d => {
          console.log({
            ...d,
            value: deploymentMap.get(d.deployment)
          })
        })

      const path = d3.line()
        .x(d => map.latLngToLayerPoint(new L.LatLng(d.latitude, d.longitude)).x)
        .y(d => map.latLngToLayerPoint(new L.LatLng(d.latitude, d.longitude)).y)

      this.container
        .select('g.glider.tracks')
        .selectAll('path.track')
        .data(this.tracks, d => d.deployment)
        .join(
          enter => enter.append('path').attr('class', 'track'),
          update => update,
          exit => exit.remove()
        )
        .attr('d', d => path(d.data))

      this.container
        .select('g.glider.tracks')
        .selectAll('path.track-overlay')
        .data(this.tracks, d => d.deployment)
        .join(
          enter => enter.append('path').attr('class', 'track-overlay'),
          update => update,
          exit => exit.remove()
        )
        .attr('d', d => path(d.data))
        .on('mouseenter', this.tip.show)
        .on('mouseout', this.tip.hide)

      this.container
        .select('g.glider.points')
        .selectAll('circle')
        .data(xf.all().filter(d => d.platform_type === 'slocum'), d => d.deployment)
        .join(
          enter => enter.append('circle').attr('class', 'point'),
          update => update,
          exit => exit.remove()
        )
        .attr('cx', (d) => map.latLngToLayerPoint(new L.LatLng(d.latitude, d.longitude)).x)
        .attr('cy', (d) => map.latLngToLayerPoint(new L.LatLng(d.latitude, d.longitude)).y)
        .on('mouseenter', this.tip.show)
        .on('mouseout', this.tip.hide)

      this.render()
    },
    render () {
      // console.log('Map:render')
      if (!this.container) return

      const minRadius = MIN_RADIUS

      this.container
        .selectAll('g.static.points circle.point')
        // only show site if there is at least one observed day
        .style('display', d => (deploymentMap.get(d.deployment).total === 0 ? 'none' : 'inline'))
        .style('fill', (d) => {
          const value = deploymentMap.get(d.deployment)
          return value.yes > 0
            ? colorScale('yes')
            : value.maybe > 0
              ? colorScale('maybe')
              : colorScale('no')
        })
        .attr('r', (d) => {
          const value = deploymentMap.get(d.deployment)
          return value.yes > 0
            ? Math.sqrt(value.yes) + minRadius
            : value.maybe > 0
              ? Math.sqrt(value.maybe) + minRadius
              : minRadius
        })

      this.container
        .selectAll('g.glider.tracks path.track')
        .style('display', d => (deploymentMap.get(d.deployment).total === 0 ? 'none' : 'inline'))
      this.container
        .selectAll('g.glider.tracks path.track-overlay')
        .style('display', d => (deploymentMap.get(d.deployment).total === 0 ? 'none' : 'inline'))

      this.container
        .selectAll('g.glider.points circle.point')
        .style('display', d => (isFiltered(d) && d.detection === 'yes' ? 'inline' : 'none'))
        .style('fill', d => colorScale(d.detection))
        .attr('r', minRadius + 1)
    }
  }
}
</script>

<style>
.vue2leaflet-map svg circle.point {
  cursor: pointer;
  fill-opacity: 0.75;
  stroke-opacity: 0.5;
  stroke-width: 1.5px;
  stroke: rgb(255, 255, 255);
}
.vue2leaflet-map svg circle.point:hover {
  fill-opacity: 1;
  stroke-opacity: 1;
  stroke-width: 3px;
}
.vue2leaflet-map svg path.track {
  stroke-linecap: round;
  fill: none;
  stroke: hsla(0, 0%, 30%, 0.5);
  stroke-width: 1px;
}
.vue2leaflet-map svg path.track-overlay {
  stroke-linecap: round;
  cursor: pointer;
  pointer-events: auto;
  fill: none;
  stroke: transparent;
  stroke-width: 5px;
}
.vue2leaflet-map svg path.track-overlay:hover {
  stroke: hsla(0, 0%, 30%, 1);
}

.d3-tip {
  line-height: 1;
  padding: 10px;
  background: rgba(255, 255, 255, 0.75);
  color: #000;
  border-radius: 4px;
  pointer-events: none;
  font-family: 'Roboto Mono', monospace;
  font-weight: 400;
  font-size: 14px;
  z-index: 1000;
}
.legend {
  background: #EEE;
  padding: 10px;
  border-radius: 4px;
  line-height: 18px;
  color: #555;
}
.legend svg text {
  font-size: 12pt;
  fill: #555;
}
.legend svg text.legend-title {
  font-size: 12pt;
  font-weight: 600;
  fill: #555;
}
.legend svg circle {
  /* fill-opacity: 0.75; */
  stroke-opacity: 0.5;
  stroke-width: 1.5px;
  stroke: rgb(255, 255, 255);
}
</style>
