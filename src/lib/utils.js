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
      platform_type: d.platform_type,
      date: new Date(d.date),
      species: d.species,
      detection: d.detection
    })))
}

function fetchGliders () {
  return axios.get('data/gliders.json')
    .then(response => response.data)
    .then(data => {
      data.forEach(d => {
        d.deployment = d.project
      })
      return data
    })
}

// function fetchGliderDeployments () {
//   return axios.get('data/glider-deployments.csv')
//     .then(response => response.data)
//     .then(csv => d3.csvParse(csv, (d, i) => {
//       d.deployment = `${d.project}:${d.site_id}`
//       return d
//     }))
// }

// function fetchGliderDetections () {
//   return axios.get('data/glider-detections.csv')
//     .then(response => response.data)
//     .then(csv => d3.csvParse(csv, (d, i) => ({
//       deployment: `${d.project}:${d.site_id}`,
//       date: new Date(d.date),
//       latitude: +d.latitude,
//       longitude: +d.longitude,
//       species: d.species,
//       detection: d.detection
//     })))
// }

export function fetchData () {
  return Promise.all([
    fetchDeployments(),
    fetchDetections(),
    fetchGliders()
    // fetchGliderDeployments(),
    // fetchGliderDetections()
  ])
}
