<template>
  <div class="legend">
    <div class="mb-2">
      <div class="subtitle-1 font-weight-medium">Filtered Dataset</div>
      <div>
        <div class="font-weight-medium">Recorded Days:</div>
        <div class="ml-2">
          {{ counts.detections.filtered.toLocaleString() }} of {{ counts.detections.total.toLocaleString() }}
          ({{ counts.detections.total > 0 ? (counts.detections.filtered / counts.detections.total * 100).toFixed(0) : '0' }}%)
        </div>
      </div>
      <div>
        <div class="font-weight-medium">Deployments:</div>
        <div class="ml-2">
          {{ counts.deployments.filtered.toLocaleString() }} of {{ counts.deployments.total.toLocaleString() }}
          ({{ counts.deployments.total > 0 ? (counts.deployments.filtered / counts.deployments.total * 100).toFixed(0) : '0' }}%)
        </div>
      </div>
    </div>

    <v-divider></v-divider>

    <div class="mt-2" v-if="hasStation">
      <div class="subtitle-1 font-weight-medium mb-2">Monitoring Stations</div>

      <!-- DEPLOYMENTS ONLY (# DAYS RECORDED) -->
      <div v-if="theme.deploymentsOnly">
        <svg width="200" height="130" v-if="useSizeScale">
          <text x="55" y="12" class="legend-text"># Days Recorded</text>
          <g v-for="(v, i) in [1000, 500, 100, 50, 1]" :key="'size-0-' + v" transform="translate(27,20)">
            <circle :cy="i * 20 + 20" :r="sizeScale(v)" stroke="white" stroke-opacity="0.5" :fill="detectionTypes[3].color" />
            <text x="27" :y="i * 20 + 20" class="legend-text">{{v.toLocaleString()}}</text>
          </g>
        </svg>
        <svg width="200" height="25" v-else>
          <g transform="translate(27,0)">
            <circle cy="7" r="7" stroke="white" stroke-opacity="0.5" :fill="detectionTypes[3].color" />
            <text x="20" y="8" class="legend-text">Station</text>
          </g>
        </svg>
      </div>

      <!-- NORMALIZED DETECTION DAYS -->
      <svg width="200" height="245" v-else-if="normalizeEffort">
        <text x="55" y="12" class="legend-text">% Days Detected</text>
        <g v-for="(v, i) in [1, 0.75, 0.5, 0.25, 0.01]" :key="'size-' + v" transform="translate(27,20)">
          <circle :cy="i * 20 + 20" :r="sizeScaleUnit(v)" stroke="white" stroke-opacity="0.5" :fill="detectionTypes[0].color" />
          <text x="27" :y="i * 20 + 20" class="legend-text">{{(v * 100).toLocaleString()}}%</text>
        </g>
        <g v-for="(v, i) in [0.25, 0.1, 0.01]" :key="'size-1-' + v" transform="translate(27,125)">
          <circle :cy="i * 20 + 20" :r="sizeScaleUnit(v)" stroke="white" stroke-opacity="0.5" :fill="detectionTypes[1].color" />
          <text x="27" :y="i * 20 + 20" class="legend-text">{{(v * 100).toLocaleString()}}% ({{detectionTypes[1].label}})</text>
        </g>
        <g transform="translate(27,210)">
          <circle :cy="0" :r="sizeScale(0)" stroke="white" stroke-opacity="0.5" :fill="detectionTypes[2].color" />
          <text x="27" :y="0" class="legend-text">0% ({{detectionTypes[2].label}})</text>
        </g>
        <g transform="translate(27,235)">
          <circle :cy="0" :r="sizeScale(0)" stroke="white" stroke-opacity="0.5" :fill="detectionTypes[3].color" />
          <text x="27" :y="0" class="legend-text">{{detectionTypes[3].label}}</text>
        </g>
      </svg>

      <!-- DETECTION DAYS -->
      <svg width="200" height="245" v-else>
        <text x="55" y="12" class="legend-text"># Days Detected</text>
        <g v-for="(v, i) in [1000, 500, 100, 50, 1]" :key="'size-0-' + v" transform="translate(27,20)">
          <circle :cy="i * 20 + 20" :r="sizeScale(v)" stroke="white" stroke-opacity="0.5" :fill="detectionTypes[0].color" />
          <text x="27" :y="i * 20 + 20" class="legend-text">{{v.toLocaleString()}}</text>
        </g>
        <g v-for="(v, i) in [50, 25, 1]" :key="'size-1-' + v" transform="translate(27,125)">
          <circle :cy="i * 20 + 20" :r="sizeScale(v)" stroke="white" stroke-opacity="0.5" :fill="detectionTypes[1].color" />
          <text x="27" :y="i * 20 + 20" class="legend-text">{{v.toLocaleString()}} ({{detectionTypes[1].label}})</text>
        </g>
        <g transform="translate(27,210)">
          <circle :cy="0" :r="sizeScale(0)" stroke="white" stroke-opacity="0.5" :fill="detectionTypes[2].color" />
          <text x="27" :y="0" class="legend-text">0 ({{detectionTypes[2].label}})</text>
        </g>
        <g transform="translate(27,235)">
          <circle :cy="0" :r="sizeScale(0)" stroke="white" stroke-opacity="0.5" :fill="detectionTypes[3].color" />
          <text x="27" :y="0" class="legend-text">{{detectionTypes[3].label}}</text>
        </g>
      </svg>

      <!-- OPTIONS -->
      <div v-if="!theme.deploymentsOnly">
        <v-checkbox class="ml-4 my-0 d-inline-block" hide-details dense label="" v-model="normalizeEffort"></v-checkbox>
        <span class="body-2 pl-1 grey--text text--darken-3">Normalize by effort</span>
      </div>
      <div v-if="theme.deploymentsOnly">
        <v-divider class="mb-2"></v-divider>
        <v-checkbox class="ml-4 my-0 d-inline-block" hide-details dense label="" v-model="useSizeScale" style="height:30px;vertical-align:middle"></v-checkbox>
        <span class="body-2 pl-1 grey--text text--darken-3" style="display:inline;vertical-align:middle;height:20px">Size Scale</span>
      </div>
    </div>

    <div class="mt-2" v-if="hasGlider">
      <div class="subtitle-1 font-weight-medium mb-2">Gliders</div>
      <svg width="200" height="85">
        <g transform="translate(27,10)">
          <rect y="-6" x="-6" width="12" height="12" stroke="white" stroke-opacity="0.5" :fill="detectionTypes[0].color" />
          <text x="27" :y="0" class="legend-text">{{detectionTypes[0].label}} (Daily)</text>
        </g>
        <g transform="translate(27,30)">
          <rect y="-6" x="-6" width="12" height="12" stroke="white" stroke-opacity="0.5" :fill="detectionTypes[1].color" />
          <text x="27" :y="0" class="legend-text">{{detectionTypes[1].label}} (Daily)</text>
        </g>
        <g transform="translate(27,55)">
          <line x1="-6" x2="6" y1="-6" y2="6" stroke="hsla(0, 0%, 30%, 0.5)" stroke-width="1px" />
          <text x="27" :y="0" class="legend-text">Track</text>
        </g>
        <g transform="translate(27,75)">
          <line x1="-6" x2="6" y1="-6" y2="6" stroke="hsla(0, 0%, 30%, 0.5)" stroke-width="1px" stroke-dasharray="3 2" />
          <text x="27" :y="0" class="legend-text">Track (Not Analyzed)</text>
        </g>
      </svg>
    </div>

    <div class="mt-2" v-if="hasTowed">
      <div class="subtitle-1 font-weight-medium mb-2">Towed Array</div>
      <svg width="200" height="65">
        <g transform="translate(27,10)">
          <rect y="-6" x="-6" width="12" height="12" stroke="white" stroke-opacity="0.5" :fill="detectionTypes[0].color" />
          <text x="27" :y="0" class="legend-text">Detection</text>
        </g>
        <g transform="translate(27,35)">
          <line x1="-6" x2="6" y1="-6" y2="6" stroke="hsla(0, 0%, 30%, 0.5)" stroke-width="1px" />
          <text x="27" :y="0" class="legend-text">Track</text>
        </g>
        <g transform="translate(27,55)">
          <line x1="-6" x2="6" y1="-6" y2="6" stroke="hsla(0, 0%, 30%, 0.5)" stroke-width="1px" stroke-dasharray="3 2" />
          <text x="27" :y="0" class="legend-text">Track (Not Analyzed)</text>
        </g>
      </svg>
    </div>
  </div>
</template>

<script>
import { colorScale, sizeScale, sizeScaleUnit } from '@/lib/scales'
import { detectionTypes } from '@/lib/constants'
import { mapGetters } from 'vuex'

export default {
  name: 'Legend',
  props: ['counts'],
  data () {
    return {
      detectionTypes
    }
  },
  computed: {
    ...mapGetters(['deployments', 'theme']),
    hasStation () {
      return this.deployments && this.deployments.some(d => d.properties.deployment_type === 'fixed')
    },
    hasGlider () {
      return this.deployments && this.deployments.some(d => d.properties.platform_type === 'slocum' || d.properties.platform_type === 'wave')
    },
    hasTowed () {
      return this.deployments && this.deployments.some(d => d.properties.platform_type === 'towed')
    },
    normalizeEffort: {
      get () {
        return this.$store.state.normalizeEffort
      },
      set (value) {
        this.$store.dispatch('setNormalizeEffort', value)
      }
    },
    useSizeScale: {
      get () {
        return this.$store.state.useSizeScale
      },
      set (value) {
        this.$store.dispatch('setUseSizeScale', value)
      }
    }
  },
  methods: {
    colorScale,
    sizeScale,
    sizeScaleUnit
  }
}
</script>

<style>
.legend {
  width: 200px;
  background: #eee;
  padding: 10px;
  border-radius: 4px;
}
.legend-text {
  dominant-baseline: middle;
  text-anchor: start;
  font-size: 14px;
  font-weight: 400;
  fill: #555;
}
</style>
