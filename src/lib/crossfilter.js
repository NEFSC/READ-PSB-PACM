import crossfilter from 'crossfilter2'
import { debounce } from 'debounce'
import evt from '@/lib/events'

export const xf = crossfilter()
window.xf = xf

xf.onChange(debounce(function (eventType) {
  console.log('[xf.onChange] called', {
    eventType
  })
  evt.$emit(`xf:${eventType}`)
}, 1))

export const deploymentDim = xf.dimension(d => d.id)
export const deploymentGroup = deploymentDim.group().reduce(
  (p, v) => {
    p[v.presence] += 1
    p.total += 1
    return p
  },
  (p, v) => {
    p[v.presence] -= 1
    p.total -= 1
    return p
  },
  () => ({
    y: 0,
    n: 0,
    m: 0,
    na: 0,
    d: 0,
    total: 0
  })
)
export const siteDim = xf.dimension(d => d.site_id)
export const siteGroup = siteDim.group().reduce(
  (p, v) => {
    p[v.presence] += 1
    p.total += 1
    return p
  },
  (p, v) => {
    p[v.presence] -= 1
    p.total -= 1
    return p
  },
  () => ({
    y: 0,
    n: 0,
    m: 0,
    na: 0,
    d: 0,
    total: 0
  })
)

export const deploymentMap = new Map()
window.deploymentMap = deploymentMap
export const siteMap = new Map()
window.siteMap = siteMap

export function setData (data) {
  console.log('[setData] called', {
    data: data?.length,
    first: data?.[0]
  })
  xf.remove(() => true)
  xf.add(data)
  deploymentMap.clear()
  deploymentGroup.all().forEach(d => {
    deploymentMap.set(d.key, d.value)
  })
  siteMap.clear()
  siteGroup.all().forEach(d => {
    if (d.key !== '__none__') {
      siteMap.set(d.key, d.value)
    }
  })
}

export function isFiltered (d) {
  return xf.isElementFiltered(d.$index)
}

// --- Multi-species pre-aggregation ---

let rawDetections = []
let isMultiSpecies = false

function effectivePresence (counts) {
  if (counts.y > 0) return 'y'
  if (counts.m > 0) return 'm'
  if (counts.n > 0) return 'n'
  if (counts.na > 0) return 'na'
  if (counts.d > 0) return 'd'
  return null
}

export function aggregateByDate (detections) {
  const groups = new Map()
  console.log('[aggregateByDate] called', {
    detections: detections?.length,
    first: detections?.[0]
  })
  detections.forEach(d => {
    const key = d.id + '|' + d.date
    if (!groups.has(key)) {
      groups.set(key, { record: d, counts: { y: 0, m: 0, n: 0, na: 0, d: 0 }, locations: [] })
    }
    const g = groups.get(key)
    g.counts[d.presence] = (g.counts[d.presence] || 0) + 1
    if (d.locations) {
      g.locations.push(...d.locations.map(l => ({ ...l, species: d.species })))
    }
  })
  console.log('[aggregateByDate] groups', groups.entries())
  return Array.from(groups.values()).map((g, i) => ({
    ...g.record,
    presence: effectivePresence(g.counts),
    locations: g.locations || null,
    species: undefined,
    $index: i
  }))
}

export function setRawDetections (detections, multiSpecies) {
  rawDetections = detections
  isMultiSpecies = multiSpecies
}

export function getRawDetections () { return rawDetections }
export function getIsMultiSpecies () { return isMultiSpecies }
