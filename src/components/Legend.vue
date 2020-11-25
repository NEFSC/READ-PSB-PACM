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

    <!-- <v-divider></v-divider>

    <div class="my-2">
      <div class="subtitle-1 font-weight-medium">Detection Type</div>
      <div v-for="type in detectionTypes" :key="type.id" class="pl-5">
        <v-icon small :color="colorScale(type.id)">mdi-circle</v-icon>
        <span
          class="pl-5"
          style="vertical-align:middle">
          {{ type.label }}
        </span>
      </div>
    </div> -->

    <v-divider></v-divider>

    <div class="mt-2" v-if="hasStation">
      <div class="subtitle-1 font-weight-medium mb-2">Monitoring Stations</div>
      <svg width="180" height="245" v-if="normalizeEffort">
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
          <text x="27" :y="0" class="legend-text">0% ({{detectionTypes[3].label}})</text>
        </g>
      </svg>
      <svg width="180" height="245" v-else>
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
          <text x="27" :y="0" class="legend-text">0 ({{detectionTypes[3].label}})</text>
        </g>
      </svg>
      <div>
        <v-checkbox class="ml-4 my-0 d-inline-block" hide-details dense label="" :value="normalizeEffort" @change="setNormalizeEffort"></v-checkbox>
        <span class="body-2 pl-1 grey--text text--darken-3">Normalize by effort</span>
      </div>
    </div>
    <div class="mt-2" v-if="hasGlider">
      <div class="subtitle-1 font-weight-medium mb-2">Gliders</div>
      <svg width="180" height="70">
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
          <text x="27" :y="0" class="legend-text">Glider Track</text>
        </g>
      </svg>
    </div>
    <div class="mt-2" v-if="hasTowed">
      <div class="subtitle-1 font-weight-medium mb-2">Towed Array</div>
      <svg width="180" height="50">
        <g transform="translate(30,10)">
          <rect y="-6" x="-6" width="12" height="12" stroke="white" stroke-opacity="0.5" :fill="detectionTypes[0].color" />
          <text x="30" :y="0" class="legend-text">Detection</text>
        </g>
        <g transform="translate(30,35)">
          <line x1="-6" x2="6" y1="-6" y2="6" stroke="hsla(0, 0%, 30%, 0.5)" stroke-width="1px" />
          <text x="30" :y="0" class="legend-text">Ship Track</text>
        </g>
      </svg>
    </div>
    <!-- <v-divider v-if="hasStation"></v-divider> -->
    <!-- <div class="mt-2" v-if="hasStation">
      <div class="subtitle-1 font-weight-medium mb-2">Settings</div>

    </div> -->
  </div>
</template>

<script>
import { colorScale, sizeScale, sizeScaleUnit } from '@/lib/scales'
import { detectionTypes } from '@/lib/constants'
import { mapActions, mapGetters } from 'vuex'

export default {
  name: 'Legend',
  props: ['counts'],
  data () {
    return {
      detectionTypes
    }
  },
  computed: {
    ...mapGetters(['normalizeEffort', 'deployments']),
    hasStation () {
      return this.deployments && this.deployments.some(d => d.properties.deployment_type === 'station')
    },
    hasGlider () {
      return this.deployments && this.deployments.some(d => d.properties.platform_type === 'slocum' || d.properties.platform_type === 'wave')
    },
    hasTowed () {
      return this.deployments && this.deployments.some(d => d.properties.platform_type === 'towed')
    }
  },
  methods: {
    ...mapActions(['setNormalizeEffort']),
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
