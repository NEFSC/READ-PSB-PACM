<template>
  <div class="legend">
    <div class="my-4">
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

    <div class="mt-4">
      <div class="subtitle-1 font-weight-medium"># Detection Days</div>
      <svg width="130" height="90">
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
