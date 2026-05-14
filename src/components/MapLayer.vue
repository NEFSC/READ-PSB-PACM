<script>
import { mapGetters, mapActions } from 'vuex'
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
    ...mapGetters(['activeTheme', 'isLoading', 'sites', 'tracks', 'deployments', 'selectedDeployments', 'normalizeEffort', 'useSizeScale']),
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
    }
  },
  watch: {
    activeTheme () {
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
    this.container.append('g').classed('stationary', true)

    this.tip = d3Tip()
      .attr('class', 'd3-tip map')
      .attr('role', 'complementary')
    this.container.call(this.tip)

    this.setBounds()
    this.draw()

    evt.$on('map:zoom', this.draw)
    evt.$on('xf:dataAdded', this.draw)
    evt.$on('xf:dataRemoved', this.draw)
    evt.$on('xf:filtered', this.render)
    console.log('[MapLayer.mounted] event listeners registered')
  },
  beforeUnmount () {
    this.container.selectAll('g').remove()
    d3.selectAll('.d3-tip.map').remove()

    evt.$off('map:zoom', this.draw)
    evt.$off('xf:dataAdded', this.draw)
    evt.$off('xf:dataRemoved', this.draw)
    evt.$off('xf:filtered', this.render)
  },
  methods: {
    ...mapActions(['selectDeployments']),
    datum (d) {
      return d?.datum || d
    },
    getWorldWidth () {
      const bounds = this.map?.getPixelWorldBounds?.(this.map.getZoom())
      return bounds ? bounds.getSize().x : 0
    },
    getWrapOffsets () {
      const worldWidth = this.getWorldWidth()
      if (!worldWidth) return [0]

      const mapWidth = this.map.getSize().x
      const copyCount = Math.ceil(mapWidth / worldWidth) + 1
      return d3.range(-copyCount, copyCount + 1)
    },
    withWrapCopies (data, keyFn) {
      return this.getWrapOffsets().flatMap(wrapOffset => {
        return data.map(d => ({
          datum: d,
          wrapOffset,
          key: `${keyFn(d)}:${wrapOffset}`
        }))
      })
    },
    wrappedPoint (d, latitudeKey, longitudeKey) {
      const datum = this.datum(d)
      const latitude = +datum[latitudeKey]
      const longitude = +datum[longitudeKey]
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return [0, 0]

      const point = this.map.latLngToLayerPoint(new L.LatLng(latitude, longitude))
      const x = point.x + (d.wrapOffset || 0) * this.getWorldWidth()
      return [x, point.y]
    },
    isSelected (d) {
      const datum = this.datum(d)
      return this.selectedDeployments.length > 0 && this.selectedDeployments.map(d => d.id).includes(datum.id)
    },
    isSiteSelected (d) {
      const datum = this.datum(d)
      if (this.selectedDeployments.length === 0) return false
      return this.selectedDeployments.some(dep => dep.site_id === datum.site_id)
    },
    updateSelected () {
      this.container.select('g.stationary')
        .selectAll('circle.site')
        .classed('selected', d => this.isSiteSelected(d))
      this.container.select('g.stationary')
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
        isLoading: this.isLoading,
        deployments: this.deployments,
        tracks: this.tracks
      })
      if (this.isLoading) return
      if (!this.deployments) return
      const deployments = this.deployments
        .filter(d => d.deployment_type === 'STATIONARY')
        .map(d => ({
          type: 'Feature',
          geometry: {
            type: 'Point',
            coordinates: [d.longitude, d.latitude]
          }
        }))
      const bounds = d3.geoBounds({
        type: 'FeatureCollection',
        features: [deployments, this.tracks].flat()
      })
      console.log('[MapLayer.setBounds] bounds:', bounds)
      evt.$emit('map:setBounds', bounds)
    },
    draw () {
      console.log('[MapLayer.draw] called', {
        isLoading: this.isLoading,
        deployments: this.deployments?.length,
        sites: this.sites?.length,
        container: !!this.container,
        map: !!this.map
      })
      if (this.isLoading) return
      this.drawTracks()
      this.drawSites()
      this.drawStationaryDeployments()
      this.drawTrackDetections()
      this.render()
      this.updateSelected()
    },
    drawSites () {
      if (!this.deployments) return

      const g = this.container.select('g.stationary')

      const data = this.stationarySites
        .filter(d => siteMap.has(d.site_id))
        .sort((a, b) => d3.ascending(siteMap.get(a.site_id)?.y ?? 0, siteMap.get(b.site_id)?.y ?? 0))

      g.selectAll('circle.site')
        .data(this.withWrapCopies(data, d => d.site_id), d => d.key)
        .join('circle')
        .attr('class', 'site')
        .attr('r', 5)
        .attr('cx', d => {
          const point = this.wrappedPoint(d, 'site_latitude', 'site_longitude')
          d.$x = point[0]
          return point[0]
        })
        .attr('cy', d => {
          const point = this.wrappedPoint(d, 'site_latitude', 'site_longitude')
          d.$y = point[1]
          return point[1]
        })
        .on('click', (event, d) => this.onClick(event, d, 'site'))
        .on('mouseenter', (event, d) => this.showTip(event, d, 'site'))
        .on('mouseout', (event, d) => this.hideTip())
    },
    drawStationaryDeployments () {
      if (!this.deployments) return

      const g = this.container.select('g.stationary')

      const data = this.stationaryDeployments
        .filter(d => deploymentMap.has(d.id))
        .sort((a, b) => d3.ascending(deploymentMap.get(a.id)?.y ?? 0, deploymentMap.get(b.id)?.y ?? 0))

      g.selectAll('circle.deployment')
        .data(this.withWrapCopies(data, d => d.id), d => d.key)
        .join('circle')
        .attr('class', 'deployment')
        .attr('r', 5)
        .attr('cx', d => {
          const point = this.wrappedPoint(d, 'latitude', 'longitude')
          d.$x = point[0]
          return point[0]
        })
        .attr('cy', d => {
          const point = this.wrappedPoint(d, 'latitude', 'longitude')
          d.$y = point[1]
          return point[1]
        })
        .on('click', (event, d) => this.onClick(event, d, 'deployment'))
        .on('mouseenter', (event, d) => this.showTip(event, d, 'deployment'))
        .on('mouseout', (event, d) => this.hideTip())
    },
    getTrackDetections () {
      if (!this.activeTheme || this.activeTheme.deploymentsOnly) return []
      return this.deployments
        .filter(d => d.deployment_type === 'MOBILE')
        .map(d => d.trackDetections)
        .flat()
    },
    drawTrackDetections () {
      const data = this.getTrackDetections()

      console.log('[MapLayer.drawTrackDetections] called', {
        points: data?.length,
        samplePoint: data?.[0]
      })
      const g = this.container.select('g.points')
      console.log('[MapLayer.drawTrackDetections] g.points element:', g.node())

      const projection = (d) => {
        return this.wrappedPoint(d, 'latitude', 'longitude')
      }

      // .sort((a, b) => d3.ascending(deploymentMap.get(a.id).y, deploymentMap.get(b.id).y))
      console.log('[MapLayer.drawTrackDetections] sorted data:', data.length)

      const paths = g.selectAll('path.point')
        .data(this.withWrapCopies(data, d => `${d.id}:${d.$index}:${d.latitude}:${d.longitude}`), d => d.key)
        .join('path')
        .attr('class', 'point')
        .attr('d', d3.symbol().type(d3.symbolSquare))
        .attr('transform', d => {
          const point = projection(d)
          d.$x = point[0]
          d.$y = point[1]
          return `translate(${point})`
        })
        .on('click', (event, d) => this.onClick(event, d, 'point'))
        .on('mouseenter', (event, d) => {
          console.log('[MapLayer.drawTrackDetections] mouseenter', {
            d
          })
          this.showTip(event, d, 'point')
        })
        .on('mouseout', (event, d) => this.hideTip())
      console.log('[MapLayer.drawTrackDetections] points created:', paths.size())
    },
    drawTracks () {
      console.log('[MapLayer.drawTracks] called', {
        tracks: this.tracks?.length
      })
      if (!this.tracks) return

      const map = this.map
      const worldWidth = this.getWorldWidth()
      function projectPoint (x, y) {
        const point = map.latLngToLayerPoint(new L.LatLng(y, x))
        this.stream.point(point.x + this.wrapOffset * worldWidth, point.y)
      }

      const g = this.container.select('g.tracks')
      console.log('[MapLayer.drawTracks] g.tracks element:', g.node())

      const line = (d) => {
        const projection = d3.geoTransform({
          point: projectPoint,
          wrapOffset: d.wrapOffset
        })
        return d3.geoPath()
          .projection(projection)(d.datum)
      }

      const data = this.withWrapCopies(this.tracks, d => d.id)
      console.log('[MapLayer.drawTracks] mobile deployments:', data.length, 'sample:', data[0]?.datum?.id)

      const tracks = g.selectAll('path.track')
        .data(data, d => d.key)
        .join('path')
        .attr('class', 'track')
        .attr('d', line)
      console.log('[MapLayer.drawTracks] tracks created:', tracks.size())

      const overlays = g.selectAll('path.track-overlay')
        .data(data, d => d.key)
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
          const mapValue = mapLookup(this.datum(d))
          return (mapValue && mapValue.total === 0) ? 'none' : 'inline'
        })
        .style('opacity', d => this.activeTheme.deploymentsOnly ? 0.9 : null)
        .style('fill', (d) => {
          const value = mapLookup(this.datum(d))

          if (this.activeTheme.deploymentsOnly) return 'orange'

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
          const value = mapLookup(this.datum(d))
          const total = value?.total ?? 0

          if (this.activeTheme.deploymentsOnly) {
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
      console.log('[MapLayer.render] called')
      this.renderCircles(
        this.container.selectAll('g.stationary circle.site'),
        d => siteMap.get(d.site_id)
      )

      this.renderCircles(
        this.container.selectAll('g.stationary circle.deployment'),
        d => deploymentMap.get(d.id)
      )

      this.container.selectAll('g.stationary circle')
        .filter(function (d) {
          const datum = d.datum || d
          const value = datum.site_id ? siteMap.get(datum.site_id) : deploymentMap.get(datum.id)
          return value && value.y > 0
        })
        .raise()

      this.container.selectAll('g.tracks path.track')
        .style('display', d => {
          const total = deploymentMap.get(this.datum(d).id)?.total ?? 0
          return total === 0 ? 'none' : 'inline'
        })

      this.container
        .selectAll('g.tracks path.track-overlay')
        .style('display', d => {
          const datum = this.datum(d)
          return !deploymentMap.has(datum.id) || deploymentMap.get(datum.id).total === 0 ? 'none' : 'inline'
        })

      this.container.selectAll('g.points path.point')
        .style('display', d => {
          return xf.isElementFiltered(this.datum(d).$index) ? 'inline' : 'none'
        })
        .style('fill', d => colorScale(this.datum(d).presence))
    },
    onClick (event, d, type) {
      if (event._simulated) return // safari bug
      const datum = this.datum(d)

      if (type === 'track') {
        return this.selectDeployments([datum.id])
      } else if (type === 'point') {
        return this.selectDeployments([datum.id])
      } else if (type === 'deployment') {
        return this.selectDeployments([datum.id])
      } else if (type === 'site') {
        const ids = this.deployments
          .filter(dep => dep.deployment_type === 'STATIONARY' && dep.site_id === datum.site_id)
          .map(dep => dep.id)
        return this.selectDeployments(ids)
      }
    },
    findNearbyDeployments (d) {
      const distanceFrom = (x, y) => Math.sqrt(Math.pow(d.$x - x, 2) + Math.pow(d.$y - y, 2))
      const maxDistance = 10
      const sites = this.container.select('g.stationary').selectAll('circle.site')
        .filter((d) => {
          const datum = this.datum(d)
          return distanceFrom(d.$x, d.$y) < maxDistance && siteMap.has(datum.site_id) && siteMap.get(datum.site_id).total > 0
        })
        .data()
      const standaloneDeployments = this.container.select('g.stationary').selectAll('circle.deployment')
        .filter((d) => {
          const datum = this.datum(d)
          return distanceFrom(d.$x, d.$y) < maxDistance && deploymentMap.has(datum.id) && deploymentMap.get(datum.id).total > 0
        })
        .data()
      const points = this.container.select('g.points').selectAll('path.point')
        .filter((d) => {
          const datum = this.datum(d)
          return distanceFrom(d.$x, d.$y) < maxDistance && xf.isElementFiltered(datum.$index)
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
      const datum = this.datum(d)

      let deployment = null
      let siteDeployments = null

      if (type === 'site') {
        siteDeployments = this.deployments.filter(
          dep => dep.deployment_type === 'STATIONARY' && dep.site_id === datum.site_id
        )
      } else if (type === 'deployment' || type === 'track' || type === 'point') {
        deployment = this.$store.getters.deploymentById(datum.id)
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

      el.html(tipHtml(datum, deployment, nNearby, type, siteDeployments, this.activeTheme.deploymentsOnly))

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
  render: function (h) {
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

</style>
