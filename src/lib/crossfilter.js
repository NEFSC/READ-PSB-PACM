import crossfilter from 'crossfilter2'
import { debounce } from 'debounce'
import evt from '@/lib/events'

export const xf = crossfilter()
window.xf = xf
xf.onChange(debounce(function (eventType) {
  if (eventType === 'filtered') {
    evt.$emit('xf:filtered')
  }
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

export const deploymentMap = new Map()

export function setData (data) {
  xf.remove(() => true)
  xf.add(data)
  deploymentMap.clear()
  deploymentGroup.all().forEach(d => {
    deploymentMap.set(d.key, d.value)
  })
}

export function isFiltered (d) {
  return xf.isElementFiltered(d.$index)
}
