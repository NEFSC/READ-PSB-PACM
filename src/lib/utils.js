import axios from 'axios'
import * as d3 from 'd3'

function fetchDeployments () {
  return axios.get('data/deployments.csv')
    .then(response => response.data)
    .then(csv => d3.csvParse(csv, (d, i) => {
      d.deployment = `${d.project}:${d.site_id}`
      d.latitude = +d.latitude
      d.longitude = +d.longitude
      return d
    }))
}
function fetchDetections () {
  return axios.get('data/detections.csv')
    .then(response => response.data)
    .then(csv => d3.csvParse(csv, (d, i) => ({
      deployment: `${d.project}:${d.site_id}`,
      date: new Date(d.date),
      species: d.species,
      detection: d.detection
    })))
}

export function fetchData () {
  return Promise.all([
    fetchDeployments(),
    fetchDetections()
  ])
}
