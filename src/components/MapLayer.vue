<script>
import { mapState, mapActions } from 'pinia'
import { useStore } from '@/store'
import L from 'leaflet'
import * as d3 from 'd3'
import d3Tip from 'd3-tip'

import evt from '@/lib/events'
import { xf, deploymentMap, siteMap } from '@/lib/crossfilter'
import { colorScale, sizeScale, sizeScaleUnit } from '@/lib/scales'
import { tipOffset, tipHtml } from '@/lib/tip'

export default {
  name: 'MapLayer',
  computed: {
    ...mapState(useStore, ['theme', 'sites', 'tracks', 'deployments', 'selectedDeployments', 'normalizeEffort', 'useSizeScale']),
    map () {
      return this.$parent.map
    },
    svg () {
      return this.$parent.svg
    },
    container () {
      return this.$parent.container
    },
    stationaryDeployments () {
      if (!this.deployments) return []
      return this.deployments.filter(d => d.deployment_type === 'STATIONARY' && !d.site_id)
    },
    stationarySites () {
      if (!this.sites) return []
      const stationarySiteIds = new Set(
        this.deployments?.filter(d => d.deployment_type === 'STATIONARY' && d.site_id).map(d => d.site_id) || []
      )
      return this.sites.filter(d => stationarySiteIds.has(d.site_id))
    },
    points () {
      if (!this.deployments) return []
      return this.deployments
        .filter(d => d.deployment_type === 'MOBILE')
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
    console.log('[MapLayer.mounted] called', {
      container: !!this.container,
      map: !!this.map,
      deployments: this.deployments?.length
    })
    this.container.append('g').classed('tracks', true)
    this.container.append('g').classed('points', true)
    this.container.append('g').classed('sites', true)
    this.container.append('g').classed('deployments', true)

    this.tip = d3Tip()
      .attr('class', 'd3-tip map')
      .attr('role', 'complementary')
    this.container.call(this.tip)

    this.setBounds()
    this.draw()

    evt.on('map:zoom', this.draw)
    evt.on('xf:filtered', this.render)
    console.log('[MapLayer.mounted] event listeners registered')
  },
  beforeUnmount () {
    this.container.selectAll('g').remove()
    d3.selectAll('.d3-tip.map').remove()

    evt.off('map:zoom', this.draw)
    evt.off('xf:filtered', this.render)
  },
  methods: {
    ...mapActions(useStore, ['selectDeployments']),
    isSelected (d) {
      return this.selectedDeployments.length > 0 && this.selectedDeployments.map(d => d.id).includes(d.id)
    },
    isSiteSelected (d) {
      if (this.selectedDeployments.length === 0) return false
      return this.selectedDeployments.some(dep => dep.site_id === d.site_id)
    },
    updateSelected () {
      this.container.select('g.sites')
        .selectAll('circle.site')
        .classed('selected', d => this.isSiteSelected(d))
      this.container.select('g.deployments')
        .selectAll('circle.deployment')
        .classed('selected', d => this.isSelected(d))
      this.container.select('g.points')
        .selectAll('path.point')
        .classed('selected', this.isSelected)
      this.container.select('g.tracks')
        .selectAll('path.track-overlay')
        .classed('selected', this.isSelected)
    },
    setBounds () {
      console.log('[MapLayer.setBounds] called', {
        loading: this.loading,
        deployments: this.deployments?.length
      })
      // TODO: compute bounds from sites, deployments and tracks
      // if (this.loading) return
      // if (!this.deployments) return
      // const bounds = d3.geoBounds({ type: 'FeatureCollection', features: this.deployments })
      // console.log('[MapLayer.setBounds] bounds:', bounds)
      // evt.$emit('map:setBounds', bounds)
    },
    draw () {
      console.log('[MapLayer.draw] called', {
        loading: this.loading,
        deployments: this.deployments?.length,
        sites: this.sites?.length,
        points: this.points?.length,
        container: !!this.container,
        map: !!this.map
      })
      if (this.loading) return
      this.drawTracks()
      this.drawSites()
      this.drawStationaryDeployments()
      this.drawTrackDetections()
      this.render()
      this.updateSelected()
    },
    drawSites () {
      if (!this.deployments) return

      const g = this.container.select('g.sites')

      const data = this.stationarySites
        .filter(d => siteMap.has(d.site_id))
        .sort((a, b) => d3.ascending(siteMap.get(a.site_id)?.y ?? 0, siteMap.get(b.site_id)?.y ?? 0))

      data.forEach((d) => {
        const latLon = new L.LatLng(d.site_latitude, d.site_longitude)
        const point = this.map.latLngToLayerPoint(latLon)
        d.$x = point.x
        d.$y = point.y
      })

      g.selectAll('circle.site')
        .data(data, d => d.site_id)
        .join('circle')
        .attr('class', 'site')
        .attr('r', 5)
        .attr('cx', d => d.$x)
        .attr('cy', d => d.$y)
        .on('click', (event, d) => this.onClick(event, d, 'site'))
        .on('mouseenter', (event, d) => this.showTip(event, d, 'site'))
        .on('mouseout', (event, d) => this.hideTip())
    },
    drawStationaryDeployments () {
      if (!this.deployments) return

      const g = this.container.select('g.deployments')

      const data = this.stationaryDeployments
        .filter(d => deploymentMap.has(d.id))
        .sort((a, b) => d3.ascending(deploymentMap.get(a.id)?.y ?? 0, deploymentMap.get(b.id)?.y ?? 0))

      data.forEach((d) => {
        const latLon = new L.LatLng(d.latitude, d.longitude)
        const point = this.map.latLngToLayerPoint(latLon)
        d.$x = point.x
        d.$y = point.y
      })

      g.selectAll('circle.deployment')
        .data(data, d => d.id)
        .join('circle')
        .attr('class', 'deployment')
        .attr('r', 5)
        .attr('cx', d => d.$x)
        .attr('cy', d => d.$y)
        .on('click', (event, d) => this.onClick(event, d, 'deployment'))
        .on('mouseenter', (event, d) => this.showTip(event, d, 'deployment'))
        .on('mouseout', (event, d) => this.hideTip())
    },
    drawTrackDetections () {
      console.log('[MapLayer.drawTrackDetections] called', {
        points: this.points?.length,
        samplePoint: this.points?.[0]
      })
      const g = this.container.select('g.points')
      console.log('[MapLayer.drawTrackDetections] g.points element:', g.node())

      const projection = (d) => {
        if (!d.latitude || !d.longitude) return [0, 0]
        const point = this.map.latLngToLayerPoint(new L.LatLng(d.latitude, d.longitude))
        return [point.x, point.y]
      }

      const data = this.points
      // .sort((a, b) => d3.ascending(deploymentMap.get(a.id).y, deploymentMap.get(b.id).y))
      console.log('[MapLayer.drawTrackDetections] sorted data:', data.length)

      data.forEach((d) => {
        if (!d.latitude || !d.longitude) return
        const latLon = new L.LatLng(d.latitude, d.longitude)
        const point = this.map.latLngToLayerPoint(latLon)
        d.$x = point.x
        d.$y = point.y
      })

      const paths = g.selectAll('path.point')
        .data(data)
        .join('path')
        .attr('class', 'point')
        .attr('d', d3.symbol().type(d3.symbolSquare))
        .attr('transform', d => `translate(${projection(d)})`)
        .on('click', (event, d) => this.onClick(event, d, 'point'))
        .on('mouseenter', (event, d) => this.showTip(event, d, 'point'))
        .on('mouseout', (event, d) => this.hideTip())
      console.log('[MapLayer.drawTrackDetections] paths created:', paths.size())
    },
    drawTracks () {
      console.log('[MapLayer.drawTracks] called', {
        tracks: this.tracks?.length
      })
      if (!this.tracks) return

      const map = this.map
      function projectPoint (x, y) {
        const point = map.latLngToLayerPoint(new L.LatLng(y, x))
        this.stream.point(point.x, point.y)
      }
      const projection = d3.geoTransform({ point: projectPoint })

      const g = this.container.select('g.tracks')
      console.log('[MapLayer.drawTracks] g.tracks element:', g.node())

      const line = d3.geoPath()
        .projection(projection)

      const data = this.tracks
      console.log('[MapLayer.drawTracks] mobile deployments:', data.length, 'sample:', data[0]?.id)

      const tracks = g.selectAll('path.track')
        .data(data, d => d.id)
        .join('path')
        .attr('class', 'track')
        .attr('d', line)
      console.log('[MapLayer.drawTracks] tracks created:', tracks.size())

      const overlays = g.selectAll('path.track-overlay')
        .data(data, d => d.id)
        .join('path')
        .attr('class', 'track-overlay')
        .attr('d', line)
        .on('click', (event, d) => this.onClick(event, d, 'track'))
        .on('mouseenter', (event, d) => this.showTip(event, d, 'track'))
        .on('mouseout', (event, d) => this.hideTip())
      console.log('[MapLayer.drawTracks] overlays created:', overlays.size())
    },
    renderCircles (selection, mapLookup) {
      selection
        .style('display', d => {
          const mapValue = mapLookup(d)
          return (mapValue && mapValue.total === 0) ? 'none' : 'inline'
        })
        .style('opacity', d => this.theme.deploymentsOnly ? 0.9 : null)
        .style('fill', (d) => {
          const value = mapLookup(d)

          if (this.theme.deploymentsOnly) return 'orange'

          if (!value) return 'gray'

          return value.y > 0
            ? colorScale('y')
            : value.m > 0
              ? colorScale('m')
              : value.n > 0
                ? colorScale('n')
                : colorScale('na')
        })
        .attr('r', (d) => {
          const value = mapLookup(d)
          const total = value?.total ?? 0

          if (this.theme.deploymentsOnly) {
            return this.useSizeScale ? sizeScale(total) : 7
          } else if (this.normalizeEffort) {
            if (!value) return 0

            return value.y > 0
              ? sizeScaleUnit(total > 0 ? value.y / total : 0)
              : value.m > 0
                ? sizeScaleUnit(total > 0 ? value.m / total : 0)
                : value.n > 0
                  ? sizeScaleUnit(total > 0 ? value.n / total : 0)
                  : sizeScaleUnit(0)
          } else {
            if (!value) return 0
            return value.y > 0
              ? sizeScale(value.y)
              : value.m > 0
                ? sizeScale(value.m)
                : sizeScale(0)
          }
        })
    },
    render () {
      if (!this.container) return

      this.renderCircles(
        this.container.selectAll('g.sites circle.site'),
        d => siteMap.get(d.site_id)
      )

      this.renderCircles(
        this.container.selectAll('g.deployments circle.deployment'),
        d => deploymentMap.get(d.id)
      )

      this.container.selectAll('g.tracks path.track')
        .style('display', d => {
          const total = deploymentMap.get(d.id)?.total ?? 0
          return total === 0 ? 'none' : 'inline'
        })

      this.container
        .selectAll('g.tracks path.track-overlay')
        .style('display', d => (!deploymentMap.has(d.id) || deploymentMap.get(d.id).total === 0 ? 'none' : 'inline'))

      this.container.selectAll('g.points path.point')
        .style('display', d => (xf.isElementFiltered(d.$index) ? 'inline' : 'none'))
        .style('fill', d => colorScale(d.presence))
    },
    onClick (event, d, type) {
      if (event._simulated) return // safari bug

      if (type === 'track') {
        return this.selectDeployments([d.id])
      } else if (type === 'deployment') {
        return this.selectDeployments([d.id])
      } else if (type === 'site') {
        const ids = this.deployments
          .filter(dep => dep.deployment_type === 'STATIONARY' && dep.site_id === d.site_id)
          .map(dep => dep.id)
        return this.selectDeployments(ids)
      } else if (type === 'point') {
        const nearby = this.findNearbyDeployments(d)
        const ids = nearby.points.map(p => p.id)
        return this.selectDeployments(ids)
      }
    },
    findNearbyDeployments (d) {
      const distanceFrom = (x, y) => Math.sqrt(Math.pow(d.$x - x, 2) + Math.pow(d.$y - y, 2))
      const maxDistance = 10
      const sites = this.container.select('g.sites').selectAll('circle.site')
        .filter((d) => {
          return distanceFrom(d.$x, d.$y) < maxDistance && siteMap.has(d.site_id) && siteMap.get(d.site_id).total > 0
        })
        .data()
      const standaloneDeployments = this.container.select('g.deployments').selectAll('circle.deployment')
        .filter((d) => {
          return distanceFrom(d.$x, d.$y) < maxDistance && deploymentMap.has(d.id) && deploymentMap.get(d.id).total > 0
        })
        .data()
      const points = this.container.select('g.points').selectAll('path.point')
        .filter((d) => {
          return distanceFrom(d.$x, d.$y) < maxDistance && xf.isElementFiltered(d.$index)
        })
        .data()
      return {
        sites,
        standaloneDeployments,
        points
      }
    },
    showTip (event, d, type) {
      const el = d3.select('.d3-tip.map')

      let deployment = null
      let siteDeployments = null

      if (type === 'site') {
        siteDeployments = this.deployments.filter(
          dep => dep.deployment_type === 'STATIONARY' && dep.site_id === d.site_id
        )
      } else if (type === 'deployment' || type === 'track' || type === 'point') {
        deployment = useStore().deploymentById(d.id)
      }

      const nearbyDeployments = this.findNearbyDeployments(d)

      let nNearby = 0
      if (type === 'site') {
        nNearby = nearbyDeployments.sites.length - 1
      } else if (type === 'deployment') {
        nNearby = nearbyDeployments.standaloneDeployments.length - 1
      } else if (type === 'point') {
        nNearby = nearbyDeployments.points.length - 1
      }

      el.html(tipHtml(d, deployment, nNearby, type, siteDeployments))

      const offset = tipOffset(event, el)

      el.style('left', (event.x + offset.x) + 'px')
        .style('top', (event.y + offset.y) + 'px')
        .style('opacity', 1)
    },
    hideTip () {
      d3.select('.d3-tip.map')
        .style('opacity', 0)
    }
  },
  render () {
    return null
  }
}
</script>

<style>
.leaflet-container svg path.track {
  stroke-linecap: round;
  stroke-linejoin: round;
  fill: none;
  stroke: hsla(0, 0%, 30%, 0.8);
  stroke-width: 2px;
}
.leaflet-container svg path.track.not-analyzed {
  stroke: hsla(0, 0%, 30%, 0.25);
  stroke-dasharray: 3 3;
}
.leaflet-container svg path.track-overlay.selected {
  stroke: hsla(0, 90%, 39%, 0.5);
}
.leaflet-container svg path.track:hover {
  stroke-width: 3px;
}
.leaflet-container svg path.track-overlay {
  stroke: hsla(0, 0%, 30%, 0.8);
  stroke-width: 5px;
  stroke-linecap: round;
  stroke-linejoin: round;
  cursor: pointer;
  pointer-events: auto;
  fill: none;
  stroke: transparent;
  stroke-width: 5px;
}
.leaflet-container svg path.track-overlay:hover {
  stroke: hsla(0, 0%, 30%, 1);
}
.leaflet-container svg circle.site {
  cursor: pointer;
  pointer-events: auto;
  fill-opacity: 0.75;
  stroke-opacity: 0.5;
  stroke-width: 1.5px;
  stroke: rgb(255, 255, 255);
}
.leaflet-container svg circle.site.selected {
  stroke: rgb(255, 0, 0);
  stroke-opacity: 1;
  stroke-width: 2px;
}
.leaflet-container svg circle.site:hover {
  fill-opacity: 1;
  stroke-opacity: 1;
  stroke-width: 3px;
}
.leaflet-container svg circle.deployment {
  cursor: pointer;
  pointer-events: auto;
  fill-opacity: 0.75;
  stroke-opacity: 0.5;
  stroke-width: 1.5px;
  stroke: rgb(255, 255, 255);
}
.leaflet-container svg circle.deployment.selected {
  stroke: rgb(255, 0, 0);
  stroke-opacity: 1;
  stroke-width: 2px;
}
.leaflet-container svg circle.deployment:hover {
  fill-opacity: 1;
  stroke-opacity: 1;
  stroke-width: 3px;
}

.leaflet-container svg path.point {
  cursor: pointer;
  pointer-events: auto;
  fill-opacity: 0.75;
  stroke-opacity: 0.5;
  stroke-width: 1.5px;
  stroke: rgb(255, 255, 255);
}
.leaflet-container svg path.point.selected {
  stroke: rgb(255, 0, 0);
  stroke-opacity: 1;
  stroke-width: 2px;
}
.leaflet-container svg path.point:hover {
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
