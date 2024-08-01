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
        .filter(d => d.properties.deployment_type === 'stationary')
      const points = this.deployments
        .filter(d => d.properties.deployment_type === 'mobile')
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
  beforeDestroy () {
    this.dim && this.dim.dispose()

    this.reset()
    this.map.removeLayer(this.layer)
    this.map.off('draw:created', this.onDraw)
    this.map.off('draw:edited', this.onEdit)
    this.map.off('draw:deleted', this.onDelete)
    this.map.removeControl(this.control)
  },
  methods: {
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
            x1: swPoint.x,
            y1: nePoint.y,
            x2: nePoint.x,
            y2: swPoint.y
          }
        })
        const selectedDeployments = new Set()
        projectedLayers.forEach((bbox) => {
          this.points.forEach(p => {
            if (bbox.x1 <= p.$x &&
                p.$x <= bbox.x2 &&
                bbox.y1 <= p.$y &&
                p.$y <= bbox.y2) {
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
