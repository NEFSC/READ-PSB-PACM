import moment from 'moment'
import * as d3 from 'd3'

function dataUrl (id, filename) {
  const path = filename ? `${id}/${filename}` : id
  return `${import.meta.env.BASE_URL}data/${path}`
}

async function getJson (url) {
  const response = await fetch(url)

  if (!response.ok) {
    throw new Error(`Request failed: ${response.status} ${response.statusText}`)
  }

  return response.json()
}

async function getText (url) {
  const response = await fetch(url)

  if (!response.ok) {
    throw new Error(`Request failed: ${response.status} ${response.statusText}`)
  }

  return response.text()
}

function fetchSites (id) {
  console.log('fetchSites', id)
  return getJson(dataUrl(id, 'sites.json'))
}

function fetchTracks (id) {
  console.log('fetchTracks', id)
  return getJson(dataUrl(id, 'tracks.json'))
    .then(data => data.features)
}

function fetchDeployments (id) {
  console.log('fetchDeployments', id)
  return getJson(dataUrl(id, 'deployments.json'))
}

function fetchOrganizations () {
  console.log('fetchOrganizations')
  return getJson(dataUrl('organizations.json'))
}

export function fetchSpecies () {
  console.log('fetchSpecies')
  return getJson(dataUrl('species.json'))
}

export function fetchPlatformTypes () {
  console.log('fetchPlatformTypes')
  return getJson(dataUrl('platform_types.json'))
}

function fetchCitations () {
  console.log('fetchCitations')
  return getJson(dataUrl('citations.json'))
}

function fetchDetections (id) {
  console.log('fetchDetections', id)
  return getText(dataUrl(id, 'detections.csv'))
    .then(csv => d3.csvParse(csv, (d, i) => {
      const m = moment(d.date)

      d.year = m.year()

      // 1 to 365 (leap days moved to 2/28)
      d.doy = m.isLeapYear() && m.dayOfYear() >= 60
        ? m.dayOfYear() - 1
        : m.dayOfYear()
      // 1 to 365 (grouped by 5 days periods)
      d.doySeason = Math.floor((d.doy - 1) / 5) * 5 + 1
      d.datekey = d.year * 1000 + d.doy

      d.locations = d.locations ? JSON.parse(d.locations) : null
      return d
    }))
}

export function fetchData ({ id }) {
  return Promise.all([
    fetchSites(id),
    fetchTracks(id),
    fetchDeployments(id),
    fetchDetections(id),
    fetchOrganizations(),
    fetchCitations()
  ])
}
