import axios from 'axios'
import * as d3 from 'd3'

function fetchDeployments (id) {
  return axios.get(`data/${id}/deployments.csv`)
    .then(response => response.data)
    .then(csv => d3.csvParse(csv, (d, i) => {
      d.deployment = d.site_id ? `${d.project}:${d.site_id}` : d.project
      d.latitude = parseFloat(d.latitude)
      d.longitude = parseFloat(d.longitude)
      return d
    }))
}

function fetchDetections (id) {
  return axios.get(`data/${id}/detections.csv`)
    .then(response => response.data)
    .then(csv => d3.csvParse(csv, (d, i) => ({
      deployment: d.site_id ? `${d.project}:${d.site_id}` : d.project,
      platform_type: d.platform_type,
      date: new Date(d.date),
      latitude: parseFloat(d.latitude),
      longitude: parseFloat(d.longitude),
      species: d.species,
      detection: d.detection
    })))
}

function fetchTracks (id) {
  return axios.get(`data/${id}/tracks.json`)
    .then(response => response.data)
    .then(data => {
      data.forEach(d => {
        d.deployment = d.site_id ? `${d.project}:${d.site_id}` : d.project
      })
      return data
    })
}

export function fetchData (id) {
  return Promise.all([
    fetchDeployments(id),
    fetchDetections(id),
    fetchTracks(id)
  ])
}
