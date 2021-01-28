import axios from 'axios'
import moment from 'moment'
import * as d3 from 'd3'

function fetchDeployments (id) {
  return axios.get(`data/${id}/deployments.json`)
    .then(response => response.data.features)
}

function fetchDetections (id) {
  return axios.get(`data/${id}/detections.csv`)
    .then(response => response.data)
    .then(csv => d3.csvParse(csv, (d, i) => {
      const m = moment(d.date)

      d.year = m.year()

      // 1 to 365 (leap days moved to 2/28)
      d.doy = m.isLeapYear() && m.dayOfYear() >= 60
        ? m.dayOfYear() - 1
        : m.dayOfYear()
      // 1 to 365 (grouped by 5 days periods)
      d.doySeason = Math.floor((d.doy - 1) / 5) * 5 + 1

      d.locations = JSON.parse(d.locations)
      return d
    }))
}

export function fetchData ({ id }) {
  return Promise.all([
    fetchDeployments(id),
    fetchDetections(id)
  ])
}
