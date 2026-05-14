<script>
import { mapGetters } from 'vuex'
import L from 'leaflet'
import * as dc from 'dc'

import { xf } from '@/lib/crossfilter'

export default {
  name: 'MapSelector',
  data () {
    return {
      layer: new L.FeatureGroup(),
      control: null
    }
  },
  computed: {
    ...mapGetters(['deployments']),
    map () {
      return this.$parent.map
    },
    points () {
      if (!this.deployments) return []
      const stations = this.deployments
        .filter(d => d.deployment_type === 'STATIONARY')
      const points = this.deployments
        .filter(d => d.deployment_type === 'MOBILE')
        .map(d => d.trackDetections)
        .flat()

      return [...stations, ...points]
    }
  },
  mounted () {
    this.dim = xf.dimension(d => d.id)

    this.map.addLayer(this.layer)
    this.layer.bringToBack()
    this.control = new L.Control.Draw({
      position: 'topleft',
      draw: {
        polyline: false,
        polygon: false,
        circle: false,
        marker: false,
        circlemarker: false
      },
      edit: {
        featureGroup: this.layer
      }
    })
    this.map.addControl(this.control)

    this.map.on('draw:created', this.onDraw)
    this.map.on('draw:edited', this.onEdit)
    this.map.on('draw:deleted', this.onDelete)
  },
  beforeUnmount () {
    this.dim && this.dim.dispose()

    this.reset()
    this.map.removeLayer(this.layer)
    this.map.off('draw:created', this.onDraw)
    this.map.off('draw:edited', this.onEdit)
    this.map.off('draw:deleted', this.onDelete)
    this.map.removeControl(this.control)
  },
  methods: {
    getWorldWidth () {
      const bounds = this.map?.getPixelWorldBounds?.(this.map.getZoom())
      return bounds ? bounds.getSize().x : 0
    },
    getWrapOffsets () {
      const worldWidth = this.getWorldWidth()
      if (!worldWidth) return [0]

      const mapWidth = this.map.getSize().x
      const copyCount = Math.ceil(mapWidth / worldWidth) + 1
      const offsets = []
      for (let i = -copyCount; i <= copyCount; i++) {
        offsets.push(i)
      }
      return offsets
    },
    projectPointCopies (p) {
      const latitude = +p.latitude
      const longitude = +p.longitude
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return []

      const point = this.map.latLngToLayerPoint(new L.LatLng(latitude, longitude))
      const worldWidth = this.getWorldWidth()
      return this.getWrapOffsets().map(wrapOffset => ({
        x: point.x + wrapOffset * worldWidth,
        y: point.y
      }))
    },
    onDraw (evt) {
      this.layer.addLayer(evt.layer.setStyle({ fillOpacity: 0.05 }))
      this.setFilter()
    },
    onEdit (evt) {
      this.setFilter()
    },
    onDelete () {
      this.setFilter()
    },
    reset () {
      this.layer.getLayers().forEach(layer => {
        this.layer.removeLayer(layer)
      })
      this.setFilter()
    },
    setFilter () {
      if (!this.dim) return

      if (this.layer.getLayers().length === 0) {
        this.dim.filterAll()
      } else {
        const layers = this.layer.getLayers()
        const projectedLayers = layers.map(layer => {
          const bounds = layer.getBounds()
          const nePoint = this.map.latLngToLayerPoint(bounds._northEast)
          const swPoint = this.map.latLngToLayerPoint(bounds._southWest)
          return {
            x1: Math.min(swPoint.x, nePoint.x),
            y1: Math.min(nePoint.y, swPoint.y),
            x2: Math.max(swPoint.x, nePoint.x),
            y2: Math.max(nePoint.y, swPoint.y)
          }
        })
        const selectedDeployments = new Set()
        projectedLayers.forEach((bbox) => {
          this.points.forEach(p => {
            const isSelected = this.projectPointCopies(p).some(point => {
              return bbox.x1 <= point.x &&
                point.x <= bbox.x2 &&
                bbox.y1 <= point.y &&
                point.y <= bbox.y2
            })
            if (isSelected) {
              selectedDeployments.add(p.id)
            }
          })
        })

        this.dim.filter(d => selectedDeployments.has(d))
      }

      dc.redrawAll()
    }
  },
  render: function (h) {
    return null
  }
}
</script>

<style>
.leaflet-disabled {
  opacity: 0.5
}
.leaflet-draw-actions a {
  color: #fff !important;
}
</style>
