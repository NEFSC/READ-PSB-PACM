import axios from 'axios'
import * as d3 from 'd3'

function fetchDeployments (id) {
  return axios.get(`data/${id}/deployments.json`)
    .then(response => response.data.features)
}

function fetchDetections (id) {
  return axios.get(`data/${id}/detections.csv`)
    .then(response => response.data)
    .then(csv => d3.csvParse(csv, (d, i) => {
      d.date = new Date(d.date)
      d.locations = JSON.parse(d.locations)
      return d
    }))
}

export function fetchData (id) {
  return Promise.all([
    fetchDeployments(id),
    fetchDetections(id)
  ])
}
