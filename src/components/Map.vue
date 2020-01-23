<template>
  <l-map
    ref="map"
    style="width:100%;height:100%"
    :center="[35, -60]"
    :zoom="5"
    @moveend="drawPoints"
    @zoomend="drawPoints">
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
import { deploymentMap } from '@/lib/crossfilter'
import { detectionTypes, detectionTypesMap, platformTypesMap } from '@/lib/constants'

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

    const minRadius = 5
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
  props: ['points'],
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

    this.tip = d3Tip()
      .attr('class', 'd3-tip')
      .direction('e')
      .direction(function (d) {
        const viewBox = svg.attr('viewBox').split(' ').map(d => +d)
        const mapWidth = map.getSize().x
        const svgWidth = viewBox[2]
        const offsetX = viewBox[0]
        const pointX = +d3.select(this).attr('cx')
        const mapX = Math.round((mapWidth - svgWidth) / 2 - offsetX + pointX)
        return (mapWidth - mapX) < (0.5 * mapWidth) ? 'w' : 'e'
      })
      .html(d => {
        const value = deploymentMap.get(d.deployment)
        const startDate = moment.utc(d.monitoring_start_datetime).startOf('date')
        const endDate = moment.utc(d.monitoring_end_datetime).startOf('date')
        const duration = moment.duration(endDate.diff(startDate))
        return `
          &nbsp;&nbsp;Project: ${d.project}<br>
          &nbsp;&nbsp;Site ID: ${d.site_id}<br>
          Unit Type: ${d.instrument_type}<br>
          &nbsp;Platform: ${platformTypesMap.get(d.platform_type).label}<br>
          &nbsp;Position: ${d.latitude.toFixed(4)}, ${d.longitude.toFixed(4)}<br>
          &nbsp;Deployed: ${startDate.format('ll')} to ${endDate.format('ll')}<br>
          &nbsp;Duration: ${duration.asDays() + 1} days<br>
          <br>
          <u>Detection Days</u><br>
          &nbsp;${detectionTypesMap.get('yes').label}: ${value.yes.toLocaleString()}<br>
          &nbsp;${detectionTypesMap.get('maybe').label}: ${value.maybe.toLocaleString()}<br>
          &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;${detectionTypesMap.get('no').label}: ${value.no.toLocaleString()}
        `
      })
    this.container.call(this.tip)

    this.drawPoints()
    evt.$on('render:map', this.render)
  },
  beforeDestroy () {
    evt.$off('render:map', this.render)
  },
  watch: {
    points () {
      this.drawPoints()
    }
  },
  methods: {
    drawPoints () {
      if (!this.container) return
      const map = this.$refs.map.mapObject

      this.container
        .selectAll('circle')
        .data(this.points, d => `${d.project}:${d.site_id}`)
        .join(
          enter => enter.append('circle'),
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
        .style('fill', 'red')
      this.render()
    },
    render () {
      // console.log('Map:render')
      if (!this.container) return
      const map = this.$refs.map.mapObject
      const zoom = map.getZoom()
      this.container
        .selectAll('circle')
        .style('display', (d) => {
          // only show site if there is at least one observed day
          return deploymentMap.get(d.deployment).total === 0 ? 'none' : 'inline'
        })
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
            ? Math.sqrt(value.yes) + zoom
            : value.maybe > 0
              ? Math.sqrt(value.maybe) + zoom
              : zoom
        })
        // .style('stroke', (d) => {
        //   return deploymentMap.get(d.deployment).yes > 1
        //     ? 'red'
        //     : deploymentMap.get(d.deployment).maybe > 1
        //       ? 'green'
        //       : 'blue'
        // })
    }
  }
}
</script>

<style>
circle {
  cursor: pointer;
  fill-opacity: 0.75;
  stroke-opacity: 0.5;
  stroke-width: 1.5px;
  stroke: rgb(255, 255, 255);
}
circle:hover {
  fill-opacity: 1;
  stroke-opacity: 1;
  stroke-width: 3px;
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
