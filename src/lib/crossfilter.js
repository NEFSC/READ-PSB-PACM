import crossfilter from 'crossfilter2'
import { debounce } from 'debounce'
import evt from '@/lib/events'

export const xf = crossfilter()
xf.onChange(debounce(function (eventType) {
  if (eventType === 'filtered') {
    evt.$emit('xf:filtered')
  }
}, 1))
window.xf = xf

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
    total: 0
  })
)

export let deploymentMap = new Map()
export function setData (data) {
  xf.remove(() => true)
  data.forEach((d, i) => {
    d.$index = i
  })
  xf.add(data)
  deploymentMap.clear()
  deploymentGroup.all().forEach(d => {
    deploymentMap.set(d.key, d.value)
  })
}

export function isFiltered (d) {
  return xf.isElementFiltered(d.$index)
}
