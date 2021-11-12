<script>
import { mapGetters, mapActions } from 'vuex'
import L from 'leaflet'
import * as d3 from 'd3'
import d3Tip from 'd3-tip'

import evt from '@/lib/events'
// import { detectionTypes } from '@/lib/constants'
import { xf, deploymentMap } from '@/lib/crossfilter'
import { colorScale, sizeScale, sizeScaleUnit } from '@/lib/scales'
import { tipOffset, tipHtml } from '@/lib/tip'

export default {
  name: 'MapLayer',
  computed: {
    ...mapGetters(['theme', 'deployments', 'selectedDeployments', 'normalizeEffort', 'useSizeScale']),
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
        .filter(d => d.properties.deployment_type === 'stationary')
    },
    points () {
      if (!this.deployments) return []
      return this.deployments
        .filter(d => d.properties.deployment_type === 'mobile')
        .map(d => d.trackDetections)
        .flat()
    }
  },
  watch: {
    theme () {
      this.draw()
      this.setBounds()
    },
    selectedDeployments () {
      this.updateSelected()
    },
    normalizeEffort () {
      this.render()
    },
    useSizeScale () {
      this.render()
    }
  },
  mounted () {
    this.container.append('g').classed('tracks', true)
    this.container.append('g').classed('points', true)
    this.container.append('g').classed('stations', true)

    this.tip = d3Tip()
      .attr('class', 'd3-tip map')
      .attr('role', 'complementary')
    this.container.call(this.tip)

    this.setBounds()
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
    ...mapActions(['selectDeployments']),
    isSelected (d) {
      return this.selectedDeployments.length > 0 && this.selectedDeployments.map(d => d.id).includes(d.id)
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
    setBounds () {
      if (this.loading) return
      if (!this.deployments) return
      const bounds = d3.geoBounds({ type: 'FeatureCollection', features: this.deployments })
      evt.$emit('map:setBounds', bounds)
    },
    draw () {
      if (this.loading) return
      this.drawTracks()
      this.drawStations()
      this.drawPoints()
      this.render()
      this.updateSelected()
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
        .on('click', d => this.onClick(d, 'station'))
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
        .on('click', d => this.onClick(d, 'point'))
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

      const data = this.deployments.filter(d => d.properties.deployment_type === 'mobile')

      g.selectAll('path.track')
        .data(data, d => d.id)
        .join('path')
        .attr('class', 'track')
        .attr('d', line)
        .classed('not-analyzed', d => !d.properties.analyzed)

      g.selectAll('path.track-overlay')
        .data(data, d => d.id)
        .join('path')
        .attr('class', 'track-overlay')
        .attr('d', line)
        .on('click', d => this.onClick(d, 'track'))
        .on('mouseenter', d => this.showTip(d, 'track'))
        .on('mouseout', this.hideTip)
    },
    render () {
      if (!this.container) return

      this.container
        .selectAll('g.stations circle.station')
        // only show site if there is at least one observed day
        .style('display', d => (deploymentMap.get(d.id) && deploymentMap.get(d.id).total === 0 ? 'none' : 'inline'))
        .style('opacity', d => this.theme.deploymentsOnly ? 0.9 : null)
        .style('fill', (d) => {
          const value = deploymentMap.get(d.id)

          if (this.theme.deploymentsOnly) return 'orange'

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
            return this.useSizeScale ? sizeScale(value.total) : 7
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
    onClick (d, type) {
      if (d3.event._simulated) return // safari bug

      if (type === 'track') {
        return this.selectDeployments([d.id])
      }
      const nearby = this.findNearbyDeployments(d)

      let ids = []
      if (type === 'station') {
        ids = nearby.stations.map(d => d.id)
      } else if (type === 'point') {
        ids = nearby.points.map(d => d.id)
      }

      return this.selectDeployments(ids)
    },
    findNearbyDeployments (d) {
      const distanceFrom = (x, y) => Math.sqrt(Math.pow(d.$x - x, 2) + Math.pow(d.$y - y, 2))
      const maxDistance = 10
      const stations = this.svg.select('g.stations').selectAll('circle.station')
        .filter((d, i) => {
          return distanceFrom(d.$x, d.$y) < maxDistance && deploymentMap.has(d.id) && deploymentMap.get(d.id).total > 0
        })
        .data()
      const points = this.svg.select('g.points').selectAll('path.point')
        .filter((d, i) => {
          return distanceFrom(d.$x, d.$y) < maxDistance && deploymentMap.has(d.id) && deploymentMap.get(d.id).total > 0
        })
        .data()
      return {
        stations,
        points
      }
    },
    showTip (d, type) {
      const el = d3.select('.d3-tip.map')

      const deployment = this.$store.getters.deploymentById(d.id)
      const nearbyDeployments = this.findNearbyDeployments(d)

      let nNearby = 0
      if (type === 'station') {
        nNearby = nearbyDeployments.stations.length - 1
      } else if (type === 'point') {
        nNearby = nearbyDeployments.points.length - 1
      }

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
.vue2leaflet-map svg path.track {
  stroke-linecap: round;
  stroke-linejoin: round;
  fill: none;
  stroke: hsla(0, 0%, 30%, 0.5);
  stroke-width: 2px;
}
.vue2leaflet-map svg path.track.not-analyzed {
  stroke: hsla(0, 0%, 30%, 0.25);
  stroke-dasharray: 3 3;
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
  max-width: 600px;
}
</style>
