import crossfilter from 'crossfilter2'

export const xf = crossfilter()

export const deploymentDim = xf.dimension(d => d.deployment)
export const deploymentGroup = deploymentDim.group().reduce(
  (p, v) => {
    p[v.detection] += 1
    p.total += 1
    return p
  },
  (p, v) => {
    p[v.detection] -= 1
    p.total -= 1
    return p
  },
  () => ({
    yes: 0,
    no: 0,
    maybe: 0,
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
