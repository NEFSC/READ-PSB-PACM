import { scaleOrdinal, scaleSqrt } from 'd3'
import { detectionTypes } from '@/lib/constants'

export const colorScale = scaleOrdinal()
  .domain(detectionTypes.map(d => d.id))
  .range(detectionTypes.map(d => d.color))

export const sizeScale = scaleSqrt()
  .domain([0, 1000])
  .range([5, 20])

export const sizeScaleUnit = scaleSqrt()
  .domain([0, 1])
  .range([5, 20])
