<template>
  <l-map
    ref="map"
    style="width:100%;height:100%"
    :center="[49, -60]"
    :zoom="4"
    :options="{ zoomControl: false }"
    @moveend="draw"
    @zoomend="draw">
    <l-control-scale position="bottomleft"></l-control-scale>
    <l-tile-layer
      url="//server.arcgisonline.com/ArcGIS/rest/services/Ocean_Basemap/MapServer/tile/{z}/{y}/{x}"
      attribution="Tiles &copy; Esri &mdash; Sources: GEBCO, NOAA, CHS, OSU, UNH, CSUMB, National Geographic, DeLorme, NAVTEQ, and Esri'">
    </l-tile-layer>
    <l-control position="bottomright">
      <Legend :counts="counts"></Legend>
    </l-control>
  </l-map>
</template>

<script>
import { LMap, LTileLayer, LControlScale, LControl } from 'vue2-leaflet'
import * as d3 from 'd3'
import d3Tip from 'd3-tip'
import L from 'leaflet'
import moment from 'moment'
import pad from 'pad'

import Legend from '@/components/Legend'
import ZoomMin from '@/lib/leaflet/L.Control.ZoomMin'
import '@/lib/leaflet/L.Control.ZoomMin.css'
import evt from '@/lib/events'
import { xf, deploymentMap, isFiltered } from '@/lib/crossfilter'
import { detectionTypesMap, platformTypesMap } from '@/lib/constants'
import { colorScale, sizeScale } from '@/lib/scales'

export default {
  name: 'Map',
  props: ['points', 'tracks', 'counts'],
  components: {
    Legend,
    LMap,
    LTileLayer,
    LControlScale,
    LControl
  },
  mounted () {
    console.log('map: mounted')
    const map = this.$refs.map.mapObject

    map.addControl(new ZoomMin({ minBounds: map.getBounds() }))

    // createColorLegend(map)
    // createSizeLegend(map)

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
      .attr('class', 'd3-tip map')
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

        let isGlider = d.platform_type === 'slocum' || d.platform_type === 'towed_array'
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
            ${pad(12, 'Project', '&nbsp;')}: ${deployment.project}<br>
            ${pad(12, 'Unit Type', '&nbsp;')}: ${deployment.instrument_type}<br>
            ${pad(12, 'Platform', '&nbsp;')}: ${platformTypesMap.get(deployment.platform_type).label}<br>
            ${pad(12, 'Deployed', '&nbsp;')}: ${startDate.format('ll')} to ${endDate.format('ll')}<br>
            ${pad(12, 'Duration', '&nbsp;')}: ${duration.asDays() + 1} days<br>
            <br>
            <u>Total Detection Days</u><br>
            ${pad(12, detectionTypesMap.get('yes').label, '&nbsp;')}: ${value ? value.yes.toLocaleString() : 0}<br>
            ${pad(12, detectionTypesMap.get('maybe').label, '&nbsp;')}: ${value ? value.maybe.toLocaleString() : 0}<br>
            ${pad(12, detectionTypesMap.get('no').label, '&nbsp;')}: ${value ? value.no.toLocaleString() : 0}
          `
          if (!isGliderTrack) {
            const analysisDate = moment.utc(d.date)
            html += `
              <br>
              <br>
              <u>Selected Date</u><br>
              ${pad(12, 'Date', '&nbsp;')}: ${analysisDate.format('ll')}<br>
              ${pad(12, 'Position', '&nbsp;')}: ${d.latitude.toFixed(4)}, ${d.longitude.toFixed(4)}<br>
              ${pad(12, 'Result', '&nbsp;')}: ${detectionTypesMap.get(d.detection).label}
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
          ${pad(12, 'Project', '&nbsp;')}: ${deployment.project}<br>
          ${pad(12, 'Site', '&nbsp;')}: ${deployment.site_id}<br>
          ${pad(12, 'Unit', '&nbsp;')}: ${deployment.instrument_type}<br>
          ${pad(12, 'Platform', '&nbsp;')}: ${platformTypesMap.get(deployment.platform_type).label}<br>
          ${pad(12, 'Position', '&nbsp;')}: ${deployment.latitude.toFixed(4)}, ${deployment.longitude.toFixed(4)}<br>
          ${pad(12, 'Deployed', '&nbsp;')}: ${startDate.format('ll')} to ${endDate.format('ll')}<br>
          ${pad(12, 'Duration', '&nbsp;')}: ${duration.asDays() + 1} days<br>
          <br>
          <u>Total Detection Days</u><br>
          ${pad(12, detectionTypesMap.get('yes').label, '&nbsp;')}: ${value.yes.toLocaleString()}<br>
          ${pad(12, detectionTypesMap.get('maybe').label, '&nbsp;')}: ${value.maybe.toLocaleString()}<br>
          ${pad(12, detectionTypesMap.get('no').label, '&nbsp;')}: ${value.no.toLocaleString()}
        `
      })
    this.container.call(this.tip)

    if (this.points) {
      this.draw()
    }
    evt.$on('render:map', this.render)
  },
  beforeDestroy () {
    evt.$off('render:map', this.render)
    d3.selectAll('.d3-tip.map').remove()
  },
  watch: {
    points () {
      console.log('map: watch points')
      this.draw()
    }
  },
  methods: {
    draw () {
      if (!this.container) return

      console.log('map: draw()')

      const map = this.$refs.map.mapObject

      this.container
        .select('g.static.points')
        .selectAll('circle')
        .data(this.points.filter(d => d.platform_type !== 'slocum' && d.platform_type !== 'towed_array'), d => d.deployment)
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
        .data(xf.all().filter(d => (d.platform_type === 'slocum' || d.platform_type === 'towed_array')), d => d.deployment)
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
      if (!this.container) return
      console.log('map: render()')

      this.container
        .selectAll('g.static.points circle.point')
        // only show site if there is at least one observed day
        .style('display', d => (deploymentMap.get(d.deployment) && deploymentMap.get(d.deployment).total === 0 ? 'none' : 'inline'))
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
            ? sizeScale(value.yes)
            : value.maybe > 0
              ? sizeScale(value.maybe)
              : sizeScale(0)
        })

      this.container
        .selectAll('g.glider.tracks path.track')
        .style('display', d => {
          return deploymentMap.get(d.deployment) && deploymentMap.get(d.deployment).total === 0 ? 'none' : 'inline'
        })
      this.container
        .selectAll('g.glider.tracks path.track-overlay')
        .style('display', d => (deploymentMap.get(d.deployment) && deploymentMap.get(d.deployment).total === 0 ? 'none' : 'inline'))

      this.container
        .selectAll('g.glider.points circle.point')
        .style('display', d => (isFiltered(d) && d.detection === 'yes' ? 'inline' : 'none'))
        .style('fill', d => colorScale(d.detection))
        .attr('r', sizeScale.range()[0] + 1)
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

</style>
