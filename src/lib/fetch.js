import axios from 'axios'
import dayjs from 'dayjs'
import * as d3 from 'd3'

export function fetchReferences () {
  const tables = ['species', 'platform_types']
  return Promise.all(tables.map(table => {
    return axios.get(`data/${table}.csv`)
      .then(response => response.data)
      .then(csv => d3.csvParse(csv, (d, i) => {
        return d
      }))
  })).then(([species, platformTypes]) => {
    return {
      species,
      platformTypes
    }
  })
}

function fetchSites (id) {
  console.log('fetchSites', id)
  return axios.get(`data/${id}/sites.json`)
    .then(response => response.data)
}

function fetchTracks (id) {
  console.log('fetchTracks', id)
  return axios.get(`data/${id}/tracks.json`)
    .then(response => response.data.features)
}

function fetchDeployments (id) {
  console.log('fetchDeployments', id)
  return axios.get(`data/${id}/deployments.json`)
    .then(response => response.data)
}

function fetchDetections (id) {
  console.log('fetchDetections', id)
  return axios.get(`data/${id}/detections.csv`)
    .then(response => response.data)
    .then(csv => d3.csvParse(csv, (d, i) => {
      const m = dayjs(d.date)

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
    fetchDetections(id)
  ])
}
