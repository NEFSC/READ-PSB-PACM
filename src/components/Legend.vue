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
    </div>

    <v-divider></v-divider>

    <div class="mt-2">
      <div class="subtitle-1 font-weight-medium"># Detection Days</div>
      <svg width="130" height="85">
        <g v-for="(v, i) in sizeValues" :key="'size-' + v" transform="translate(30,0)">
          <circle :cy="i * 20 + 20" :r="sizeScale(v)" stroke="white" stroke-opacity="0.5" :fill="colorScale('yes')" />
          <text x="30" :y="i * 20 + 20" class="legend-text">{{v.toLocaleString()}}</text>
        </g>
      </svg>
    </div>
  </div>
</template>

<script>
import { colorScale, sizeScale } from '@/lib/scales'
import { detectionTypes } from '@/lib/constants'

export default {
  name: 'Legend',
  props: ['counts'],
  data () {
    return {
      detectionTypes,
      sizeValues: [0, 100, 500, 1000].reverse()
    }
  },
  methods: {
    colorScale,
    sizeScale
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
