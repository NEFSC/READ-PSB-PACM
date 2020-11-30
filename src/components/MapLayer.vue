<script>
import { mapGetters, mapActions } from 'vuex'
import L from 'leaflet'
import * as d3 from 'd3'
import * as d3Hexbin from 'd3-hexbin'
import d3Tip from 'd3-tip'

import evt from '@/lib/events'
// import { detectionTypes } from '@/lib/constants'
import { xf, deploymentMap } from '@/lib/crossfilter'
import { colorScale, sizeScale, sizeScaleUnit } from '@/lib/scales'
import { tipOffset, tipHtml } from '@/lib/tip'

export default {
  name: 'MapLayer',
  computed: {
    ...mapGetters(['theme', 'deployments', 'selectedDeployment', 'normalizeEffort']),
    map () {
      return this.$parent.map
    },
    svg () {
      return this.$parent.svg
    },
    container () {
      return this.$parent.container
    },
    stations () {
      if (!this.deployments) return []
      return this.deployments
        .filter(d => d.properties.deployment_type === 'station')
    },
    points () {
      if (!this.deployments) return []
      return this.deployments
        .filter(d => d.properties.deployment_type === 'track')
        .map(d => d.trackDetections)
        .flat()
    }
  },
  watch: {
    theme () {
      this.draw()
    },
    selectedDeployment () {
      this.updateSelected()
    },
    normalizeEffort () {
      this.render()
    }
  },
  mounted () {
    this.container.append('g').classed('tracks', true)
    this.container.append('g').classed('points', true)
    this.container.append('g').classed('stations', true)
    this.container.append('g').classed('hexbins', true)

    this.tip = d3Tip()
      .attr('class', 'd3-tip map')
    this.container.call(this.tip)

    this.draw()

    evt.$on('map:zoom', this.draw)
    evt.$on('xf:filtered', this.render)
  },
  beforeDestroy () {
    this.container.selectAll('g').remove()
    d3.selectAll('.d3-tip.map').remove()

    evt.$off('map:zoom', this.draw)
    evt.$off('xf:filtered', this.render)
  },
  methods: {
    ...mapActions(['selectDeploymentById']),
    isSelected (d) {
      return this.selectedDeployment && d.id === this.selectedDeployment.id
    },
    updateSelected () {
      this.container.select('g.stations')
        .selectAll('circle.station')
        .classed('selected', this.isSelected)
      this.container.select('g.points')
        .selectAll('path.point')
        .classed('selected', this.isSelected)
      this.container.select('g.tracks')
        .selectAll('path.track-overlay')
        .classed('selected', this.isSelected)
    },
    draw () {
      if (this.loading) return
      // this.drawHexbin()
      this.drawTracks()
      this.drawStations()
      this.drawPoints()
      this.render()
      this.updateSelected()
    },
    drawHexbin () {
      const width = this.svg.attr('width')
      const height = this.svg.attr('height')

      const hexbin = d3Hexbin.hexbin()
        .extent([[0, 0], [width, height]])
        .radius(10)
        .x((d) => {
          let point
          if (d.geometry) {
            point = this.map.latLngToLayerPoint(new L.LatLng(d.geometry.coordinates[1], d.geometry.coordinates[0]))
          } else {
            point = this.map.latLngToLayerPoint(new L.LatLng(d.latitude, d.longitude))
          }
          return point.x
        })
        .y((d) => {
          let point
          if (d.geometry) {
            point = this.map.latLngToLayerPoint(new L.LatLng(d.geometry.coordinates[1], d.geometry.coordinates[0]))
          } else {
            point = this.map.latLngToLayerPoint(new L.LatLng(d.latitude, d.longitude))
          }
          return point.y
        })
      const bins = hexbin([...this.stations, ...this.points])
      const g = this.container.select('g.hexbins')
      g.selectAll('path')
        .data(bins)
        .join('path')
        .attr('class', 'hexbin')
        .attr('transform', d => `translate(${d.x},${d.y})`)
        .attr('d', d => hexbin.hexagon())
        .attr('fill-opacity', 0)
        .attr('stroke', 'red')
        .on('click', (d) => console.log(d, this.getHexbinValue(d)))
    },
    drawStations () {
      if (!this.deployments) return

      const g = this.container.select('g.stations')

      const data = this.stations
        .sort((a, b) => d3.ascending(deploymentMap.get(a.id).y, deploymentMap.get(b.id).y))

      data.forEach((d) => {
        const latLon = new L.LatLng(d.geometry.coordinates[1], d.geometry.coordinates[0])
        const point = this.map.latLngToLayerPoint(latLon)
        d.$x = point.x
        d.$y = point.y
      })

      g.selectAll('circle.station')
        .data(data, d => d.id)
        .join('circle')
        .attr('class', 'station')
        .attr('r', 5)
        .attr('cx', d => d.$x)
        .attr('cy', d => d.$y)
        // .each(function drawCircle (d) {
        //   const point = map.latLngToLayerPoint(new L.LatLng(d.geometry.coordinates[1], d.geometry.coordinates[0]))
        //   d3.select(this)
        //     .attr('cx', point.x)
        //     .attr('cy', point.y)
        // })
        .on('click', d => this.selectDeploymentById(d.id))
        .on('mouseenter', d => this.showTip(d, this.theme.deploymentsOnly ? 'deployment' : 'station'))
        .on('mouseout', this.hideTip)
    },
    drawPoints () {
      const g = this.container.select('g.points')

      const projection = (d) => {
        const point = this.map.latLngToLayerPoint(new L.LatLng(d.latitude, d.longitude))
        return [point.x, point.y]
      }

      const data = this.points
        .sort((a, b) => d3.ascending(deploymentMap.get(a.id).y, deploymentMap.get(b.id).y))

      data.forEach((d) => {
        const latLon = new L.LatLng(d.latitude, d.longitude)
        const point = this.map.latLngToLayerPoint(latLon)
        d.$x = point.x
        d.$y = point.y
      })

      g.selectAll('path.point')
        .data(data)
        .join('path')
        .attr('class', 'point')
        .attr('d', d3.symbol().type(d3.symbolSquare))
        .attr('transform', d => `translate(${projection(d)})`)
        // .on('click', d => console.log(d))
        .on('click', d => this.selectDeploymentById(d.id))
        .on('mouseenter', d => this.showTip(d, 'point'))
        .on('mouseout', this.hideTip)
    },
    drawTracks () {
      if (!this.deployments) return

      const map = this.map
      function projectPoint (x, y) {
        const point = map.latLngToLayerPoint(new L.LatLng(y, x))
        this.stream.point(point.x, point.y)
      }
      const projection = d3.geoTransform({ point: projectPoint })

      const g = this.container.select('g.tracks')

      const line = d3.geoPath()
        .projection(projection)

      const data = this.deployments.filter(d => d.properties.deployment_type === 'track')

      g.selectAll('path.track')
        .data(data, d => d.id)
        .join('path')
        .attr('class', 'track')
        .attr('d', line)

      g.selectAll('path.track-overlay')
        .data(data, d => d.id)
        .join('path')
        .attr('class', 'track-overlay')
        .attr('d', line)
        // .on('click', d => console.log(d))
        .on('click', d => this.selectDeploymentById(d.id))
        .on('mouseenter', d => this.showTip(d, 'track'))
        .on('mouseout', this.hideTip)
    },
    renderHexbins () {
      // const value = deploymentMap.get(d.id)
      //     if (this.normalizeEffort) {
      //       return value.y
      const color = d3.scaleSequential(d3.interpolateTurbo)
      if (!this.normalizeEffort) {
        color.domain([0, 500])
      }
      this.container
        .selectAll('g.hexbins path.hexbin')
        .style('fill', (bin, i) => {
          const value = this.getHexbinValue(bin)
          return color(this.normalizeEffort ? value.y / value.total : value.y)
        })
    },
    getHexbinValue (bin) {
      const values = bin.map(d => deploymentMap.get(d.id))
      return values.reduce((p, v) => {
        p.y = v.y + (p.y || 0)
        p.m = v.m + (p.m || 0)
        p.n = v.n + (p.n || 0)
        p.na = v.na + (p.na || 0)
        p.total = v.total + (p.total || 0)
        return p
      }, {})
    },
    render () {
      if (!this.container) return

      // this.renderHexbins()

      this.container
        .selectAll('g.stations circle.station')
        // only show site if there is at least one observed day
        .style('display', d => (deploymentMap.get(d.id) && deploymentMap.get(d.id).total === 0 ? 'none' : 'inline'))
        .style('fill', (d) => {
          const value = deploymentMap.get(d.id)

          return value.y > 0
            ? colorScale('y')
            : value.m > 0
              ? colorScale('m')
              : value.n > 0
                ? colorScale('n')
                : colorScale('na')
        })
        .attr('r', (d) => {
          const value = deploymentMap.get(d.id)

          if (this.theme.deploymentsOnly) {
            return sizeScale(value.total)
          } else if (this.normalizeEffort) {
            return value.y > 0
              ? sizeScaleUnit(value.total > 0 ? value.y / value.total : 0)
              : value.m > 0
                ? sizeScaleUnit(value.total > 0 ? value.m / value.total : 0)
                : sizeScaleUnit(0)
          } else {
            return value.y > 0
              ? sizeScale(value.y)
              : value.m > 0
                ? sizeScale(value.m)
                : sizeScale(0)
          }
        })

      this.container
        .selectAll('g.tracks path.track')
        .style('display', d => (!deploymentMap.has(d.id) || deploymentMap.get(d.id).total === 0 ? 'none' : 'inline'))
      this.container
        .selectAll('g.tracks path.track-overlay')
        .style('display', d => (!deploymentMap.has(d.id) || deploymentMap.get(d.id).total === 0 ? 'none' : 'inline'))

      this.container
        .selectAll('g.points path.point')
        .style('display', d => (xf.isElementFiltered(d.$index) ? 'inline' : 'none'))
        .style('fill', d => colorScale(d.presence))
    },
    countNearby (d) {
      const distanceFrom = (x, y) => Math.sqrt(Math.pow(d.$x - x, 2) + Math.pow(d.$y - y, 2))
      const maxDistance = 10
      const stations = this.svg.select('g.stations').selectAll('circle.station')
        .filter((d, i) => distanceFrom(d.$x, d.$y) < maxDistance)
        .nodes()
      const points = this.svg.select('g.points').selectAll('path.point')
        .filter((d, i) => distanceFrom(d.$x, d.$y) < maxDistance)
        .nodes()
      return stations.length + points.length
    },
    showTip (d, type) {
      const el = d3.select('.d3-tip.map')

      let deployment = this.$store.getters.deploymentById(d.id)
      const nNearby = this.countNearby(d) - 1
      el.html(tipHtml(d, deployment, nNearby, type))

      const offset = tipOffset(el)

      el.style('left', (d3.event.x + offset.x) + 'px')
        .style('top', (d3.event.y + offset.y) + 'px')
        .style('opacity', 1)
    },
    hideTip (d) {
      d3.select('.d3-tip.map')
        .style('opacity', 0)
    }
  },
  render: function (h) {
    return null
  }
}
</script>

<style>
.svg-rect {
  stroke: red;
  stroke-width: 1px;
}
.vue2leaflet-map svg path.track {
  stroke-linecap: round;
  stroke-linejoin: round;
  fill: none;
  stroke: hsla(0, 0%, 30%, 0.5);
  stroke-width: 1px;
}
.vue2leaflet-map svg path.track-overlay.selected {
  stroke: hsla(0, 90%, 39%, 0.5);
}
.vue2leaflet-map svg path.track:hover {
  stroke-width: 3px;
}
.vue2leaflet-map svg path.track-overlay {
  stroke-linecap: round;
  stroke-linejoin: round;
  cursor: pointer;
  pointer-events: auto;
  fill: none;
  stroke: transparent;
  stroke-width: 5px;
}
.vue2leaflet-map svg path.track-overlay:hover {
  stroke: hsla(0, 0%, 30%, 1);
}
/* .vue2leaflet-map svg circle.point {
  cursor: pointer;
  fill-opacity: 0.75;
  stroke-opacity: 0.5;
  stroke-width: 1.5px;
  stroke: rgb(255, 255, 255);
}
.vue2leaflet-map svg circle.point.selected {
  stroke: rgb(255, 0, 0);
  stroke-opacity: 1;
  stroke-width: 2px;
}
.vue2leaflet-map svg circle.point:hover {
  fill-opacity: 1;
  stroke-opacity: 1;
  stroke-width: 3px;
} */

.vue2leaflet-map svg circle.station {
  cursor: pointer;
  pointer-events: auto;
  fill-opacity: 0.75;
  stroke-opacity: 0.5;
  stroke-width: 1.5px;
  stroke: rgb(255, 255, 255);
}
.vue2leaflet-map svg circle.station.selected {
  stroke: rgb(255, 0, 0);
  stroke-opacity: 1;
  stroke-width: 2px;
}
.vue2leaflet-map svg circle.station:hover {
  fill-opacity: 1;
  stroke-opacity: 1;
  stroke-width: 3px;
}

.vue2leaflet-map svg path.point {
  cursor: pointer;
  pointer-events: auto;
  fill-opacity: 0.75;
  stroke-opacity: 0.5;
  stroke-width: 1.5px;
  stroke: rgb(255, 255, 255);
}
.vue2leaflet-map svg path.point.selected {
  stroke: rgb(255, 0, 0);
  stroke-opacity: 1;
  stroke-width: 2px;
}
.vue2leaflet-map svg path.point:hover {
  fill-opacity: 1;
  stroke-opacity: 1;
  stroke-width: 3px;
}

.vue2leaflet-map svg path.hexbin {
  cursor: pointer;
  pointer-events: auto;
  fill-opacity: 1;
  stroke-opacity: 0.5;
  stroke-width: 1.5px;
  stroke: black;
  fill: white;
}
.vue2leaflet-map svg path.hexbin:hover {
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
  font-size: 14px;
  z-index: 1000;
}
</style>
