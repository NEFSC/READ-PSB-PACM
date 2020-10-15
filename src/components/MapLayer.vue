<script>
import { mapGetters, mapActions } from 'vuex'
import L from 'leaflet'
import * as d3 from 'd3'
import d3Tip from 'd3-tip'

import evt from '@/lib/events'
import { xf, deploymentMap, isFiltered } from '@/lib/crossfilter'
import { colorScale, sizeScale, sizeScaleUnit } from '@/lib/scales'
import { tipOffset, tipHtml } from '@/lib/tip'

export default {
  name: 'MapLayer',
  computed: {
    ...mapGetters(['theme', 'tracks', 'deployments', 'selectedDeployment', 'normalizeEffort']),
    map () {
      return this.$parent.map
    },
    container () {
      return this.$parent.container
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
    this.container.append('g').classed('symbols', true)
    this.container.append('g').classed('points', true)

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
    updateSelected () {
      this.container.select('g.points')
        .selectAll('circle.point')
        .classed('selected', (d) => (this.selectedDeployment && d.id === this.selectedDeployment.id))
      this.container.select('g.symbols')
        .selectAll('path.symbol')
        .classed('selected', (d) => (this.selectedDeployment && d.id === this.selectedDeployment.id))
      this.container.select('g.tracks')
        .selectAll('path.track-overlay')
        .classed('selected', (d) => (this.selectedDeployment && d.id === this.selectedDeployment.id))
    },
    draw () {
      if (this.loading) return
      this.drawTracks()
      this.drawCircles()
      this.drawSymbols()
      this.render()
      this.updateSelected()
    },
    drawCircles () {
      const g = this.container.select('g.points')

      if (!this.deployments) return

      const map = this.map
      g.selectAll('circle.point')
        .data(this.deployments.filter(d => d.dataset === 'moored'))
        .join('circle')
        .attr('class', 'point')
        .attr('r', 5)
        .each(function drawCircle (d) {
          const point = map.latLngToLayerPoint(new L.LatLng(d.latitude, d.longitude))
          d3.select(this)
            .attr('cx', point.x)
            .attr('cy', point.y)
        })
        .on('click', d => this.selectDeploymentById(d.id))
        .on('mouseenter', d => this.showTip(d, 'point'))
        .on('mouseout', this.hideTip)
    },
    drawSymbols () {
      const data = xf.all().filter(d => (d.platform_type !== 'mooring' && d.platform_type !== 'buoy'))
      const g = this.container.select('g.symbols')

      const projection = (d) => {
        const point = this.map.latLngToLayerPoint(new L.LatLng(d.latitude, d.longitude))
        return [point.x, point.y]
      }

      g.selectAll('path.symbol')
        .data(data, d => d.id)
        .join('path')
        .attr('class', 'symbol')
        .attr('d', d3.symbol().type(d3.symbolSquare))
        .attr('transform', d => `translate(${projection(d)})`)
        .on('click', d => this.selectDeploymentById(d.id))
        .on('mouseenter', d => this.showTip(d, 'point'))
        .on('mouseout', this.hideTip)
    },
    drawTracks () {
      if (!this.tracks) return

      const map = this.map
      function projectPoint (x, y) {
        const point = map.latLngToLayerPoint(new L.LatLng(y, x))
        this.stream.point(point.x, point.y)
      }
      const projection = d3.geoTransform({ point: projectPoint })

      const g = this.container.select('g.tracks')

      const line = d3.geoPath()
        .projection(projection)

      g.selectAll('path.track')
        .data(this.tracks.features.filter(d => deploymentMap.has(d.id)))
        .join('path')
        .attr('class', 'track')
        .attr('d', line)

      g.selectAll('path.track-overlay')
        .data(this.tracks.features)
        .join('path')
        .attr('class', 'track-overlay')
        .attr('d', line)
        .on('click', d => this.selectDeploymentById(d.id))
        .on('mouseenter', d => this.showTip(d, 'track'))
        .on('mouseout', this.hideTip)
    },
    render () {
      if (!this.container) return

      this.container
        .selectAll('g.points circle.point')
        // only show site if there is at least one observed day
        .style('display', d => (deploymentMap.get(d.id) && deploymentMap.get(d.id).total === 0 ? 'none' : 'inline'))
        .style('fill', (d) => {
          const value = deploymentMap.get(d.id)

          return value.y > 0
            ? colorScale('y')
            : value.m > 0
              ? colorScale('m')
              : colorScale('n')
        })
        .attr('r', (d) => {
          const value = deploymentMap.get(d.id)
          if (this.normalizeEffort) {
            return value.y > 0
              ? sizeScaleUnit(value.total > 0 ? value.y / value.total : 0)
              : value.m > 0
                ? sizeScaleUnit(value.total > 0 ? value.m / value.total : 0)
                : sizeScaleUnit(0)
          }
          return value.y > 0
            ? sizeScale(value.y)
            : value.m > 0
              ? sizeScale(value.m)
              : sizeScale(0)
        })

      this.container
        .selectAll('g.tracks path.track')
        .style('display', d => !deploymentMap.has(d.id) || deploymentMap.get(d.id).total === 0 ? 'none' : 'inline')
      this.container
        .selectAll('g.tracks path.track-overlay')
        .style('display', d => (!deploymentMap.has(d.id) || deploymentMap.get(d.id).total === 0 ? 'none' : 'inline'))

      this.container
        .selectAll('g.symbols path.symbol')
        .style('display', d => (isFiltered(d) && d.presence === 'y' ? 'inline' : 'none'))
        .style('fill', d => colorScale(d.presence))
        .attr('r', sizeScale.range()[0] + 1)
    },
    showTip (d, type) {
      const el = d3.select('.d3-tip.map')

      let deployment = this.$store.getters.deploymentById(d.id)
      el.html(tipHtml(d, deployment, type))

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
.vue2leaflet-map svg circle.point {
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
}

.vue2leaflet-map svg path.symbol {
  cursor: pointer;
  pointer-events: auto;
  fill-opacity: 0.75;
  stroke-opacity: 0.5;
  stroke-width: 1.5px;
  stroke: rgb(255, 255, 255);
}
.vue2leaflet-map svg path.symbol.selected {
  stroke: rgb(255, 0, 0);
  stroke-opacity: 1;
  stroke-width: 2px;
}
.vue2leaflet-map svg path.symbol:hover {
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
