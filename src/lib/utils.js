import axios from 'axios'
import * as d3 from 'd3'

function fetchDeployments (id) {
  return axios.get(`data/${id}/deployments.csv`)
    .then(response => response.data)
    .then(csv => d3.csvParse(csv, (d, i) => {
      d.latitude = parseFloat(d.latitude)
      d.longitude = parseFloat(d.longitude)
      return d
    }))
}

function fetchDetections (id) {
  return axios.get(`data/${id}/detections.csv`)
    .then(response => response.data)
    .then(csv => d3.csvParse(csv, (d, i) => {
      d.date = new Date(d.date)
      d.latitude = parseFloat(d.latitude)
      d.longitude = parseFloat(d.longitude)
      return d
    }))
}

function fetchTracks (id) {
  return axios.get(`data/${id}/tracks.json`)
    .then(response => response.data)
}

export function fetchData (id) {
  return Promise.all([
    fetchDeployments(id),
    fetchDetections(id),
    fetchTracks(id)
  ])
}
