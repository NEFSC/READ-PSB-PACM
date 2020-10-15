import { event, nest } from 'd3'
import moment from 'moment'
import pad from 'pad'

import { xf, deploymentMap } from '@/lib/crossfilter'
import { platformTypesMap, detectionTypes, detectionTypesMap } from '@/lib/constants'

export function tipOffset (el) {
  const padding = 20

  const screenWidth = document.body.offsetWidth
  const screenHeight = document.body.offsetHeight

  const nodeWidth = el.node().clientWidth
  const nodeHeight = el.node().clientHeight

  const distanceToBottom = screenHeight - event.y
  const offsetY = distanceToBottom < nodeHeight + padding
    ? -(nodeHeight + padding)
    : padding

  const distanceToRight = screenWidth - event.x
  const offsetX = distanceToRight < nodeWidth + padding
    ? -(nodeWidth + padding)
    : padding
  return {
    x: offsetX,
    y: offsetY
  }
}

export function monitoringPeriodLabels (deployment) {
  const start = moment.utc(deployment.monitoring_start_datetime).startOf('date')
  const end = moment.utc(deployment.monitoring_end_datetime).startOf('date')
  const duration = moment.duration(end.diff(start)).asDays() + 1
  return {
    start: start.format('ll'),
    end: end.format('ll'),
    duration
  }
}

const htmlTable = (rows, padding) => {
  let p = padding
  if (!padding) {
    p = Math.max(...rows.map(d => d[0].length))
  }
  return rows.map(row => `${pad(p, row[0], '&nbsp;')}: ${row[1]}`).join('<br>')
}

const detectionTableHtml = (deployment) => {
  const filteredDetections = deploymentMap.get(deployment.id)
  const allDetections = xf.all().filter(d => d.id === deployment.id)

  const allDetectionsSummary = nest()
    .key(d => d.presence)
    .rollup(v => v.length)
    .object(allDetections)
  allDetectionsSummary.total = allDetections.length

  const detectionTypesIds = detectionTypes.map(d => d.id)
  return htmlTable([detectionTypesIds[0]].map(id => [
    id === 'total' ? 'Total' : detectionTypesMap.get(id).label,
    `${pad(6, allDetectionsSummary[id].toLocaleString().toLocaleString(), '&nbsp;')} ${pad(8, filteredDetections[id].toLocaleString(), '&nbsp;')}`
  ]))
}

const towedTrackHtml = (d, deployment) => {
  const monitoring = monitoringPeriodLabels(deployment)

  const trackHtml = htmlTable([
    [ 'Project', `${deployment.project}` ],
    [ 'Platform Type', `${platformTypesMap.get(deployment.platform_type).label}` ],
    [ 'Detection Method', `${deployment.detection_method}` ],
    [ 'Deployed', `${monitoring.start} to ${monitoring.end}` ],
    [ 'Duration', `${monitoring.duration} days` ]
  ])

  const detectionHtml = detectionTableHtml(deployment)

  return `
    Towed Array Deployment<br><br>

    ${trackHtml}<br><br>

    <hr><br>

    Deployment Summary (# Detections)<br><br>
    ${pad(16, 'All', '&nbsp;')} ${pad(8, 'Filtered', '&nbsp;')}<br>
    ${detectionHtml}
  `
}
const towedPointHtml = (d, deployment) => {
  const trackHtml = towedTrackHtml(d, deployment)
  const positionHtml = deployment.species === 'beaked' ? detectionBeakedHtml(d) : detectionKogiaHtml(d)
  return `
    ${trackHtml}<br><br>

    <hr><br>

    Highlighted Detection<br><br>
    ${positionHtml}
  `
}
const detectionKogiaHtml = (d) => {
  return htmlTable([
    [ 'Analysis Start', `${moment.utc(d.analysis_period_start).format('ll LTS')}` ],
    [ 'Analysis End', `${moment.utc(d.analysis_period_end).format('ll LTS')}` ],
    [ 'Duration', `${(+d.analysis_period_effort_seconds).toFixed(1)} sec` ],
    [ 'Position', `${d.latitude.toFixed(4)}, ${d.longitude.toFixed(4)}` ]
  ])
}
const detectionBeakedHtml = (d) => {
  return htmlTable([
    [ 'Analysis Start', `${moment.utc(d.analysis_period_start).format('ll LTS')}` ],
    [ 'Analysis End', `${moment.utc(d.analysis_period_end).format('ll LTS')}` ],
    [ 'Duration', `${(+d.analysis_period_effort_seconds).toFixed(1)} sec` ],
    [ 'Position', `${d.latitude.toFixed(4)}, ${d.longitude.toFixed(4)}` ],
    [ 'Species', `${d.call_type}` ]
  ])
}

const gliderTrackHtml = (d, deployment) => {
  const monitoring = monitoringPeriodLabels(deployment)

  const trackHtml = htmlTable([
    [ 'Project', `${deployment.project}` ],
    [ 'Site', `${deployment.site_id ? deployment.site_id : 'N/A'}` ],
    [ 'Platform Type', `${platformTypesMap.get(deployment.platform_type).label}` ],
    [ 'Recorder Type', `${deployment.instrument_type}` ],
    [ 'Detection Method', `${deployment.detection_method}` ],
    [ 'Deployed', `${monitoring.start} to ${monitoring.end}` ],
    [ 'Duration', `${monitoring.duration} days` ]
  ])
  const detectionHtml = detectionTableHtml(deployment)

  return `
    Glider Deployment<br><br>

    ${trackHtml}<br><br>

    <hr><br>

    Deployment Summary (# Daily Detections)<br><br>
    ${pad(16, 'All', '&nbsp;')} ${pad(8, 'Filtered', '&nbsp;')}<br>
    ${detectionHtml}
  `
}
const gliderPointHtml = (d, deployment) => {
  const trackHtml = gliderTrackHtml(d, deployment)
  const positionHtml = htmlTable([
    [ 'Date', `${moment.utc(d.date).format('ll')}` ],
    [ 'Position', `${d.latitude.toFixed(4)}, ${d.longitude.toFixed(4)}` ]
    // [ 'Species', `${speciesTypesMap.get(deployment.species).label}` ]
  ])
  return `
    ${trackHtml}<br><br>
    <hr><br>
    Highlighted Daily Detection<br><br>
    ${positionHtml}
  `
}

const stationPointHtml = (d, deployment) => {
  const monitoring = monitoringPeriodLabels(deployment)
  const detectionTypesIds = detectionTypes.map(d => d.id)
  const filteredDetections = deploymentMap.get(deployment.id)
  const allDetections = xf.all().filter(d => d.id === deployment.id)

  const allDetectionsSummary = nest()
    .key(d => d.presence)
    .rollup(v => v.length)
    .object(allDetections)
  detectionTypesIds.forEach(id => {
    allDetectionsSummary[id] = allDetectionsSummary[id] || 0
  })
  allDetectionsSummary.total = allDetections.length

  const metaHtml = htmlTable([
    [ 'Project', `${deployment.project}` ],
    [ 'Site', `${deployment.site_id ? deployment.site_id : 'N/A'}` ],
    [ 'Platform Type', `${platformTypesMap.get(deployment.platform_type).label}` ],
    [ 'Recorder Type', `${deployment.instrument_type}` ],
    [ 'Detection Method', `${deployment.detection_method}` ],
    [ 'Recorder Depth', deployment.recorder_depth_meters ? `${deployment.recorder_depth_meters} m` : 'N/A' ],
    [ 'Water Depth', deployment.water_depth_meters ? `${deployment.water_depth_meters} m` : 'N/A' ],
    [ 'Deployed', `${monitoring.start} to ${monitoring.end}` ],
    [ 'Duration', `${monitoring.duration} days` ]
  ])
  const detectionsHtml = htmlTable([...detectionTypesIds, 'total'].map(id => [
    id === 'total' ? 'Total' : detectionTypesMap.get(id).label,
    `${pad(6, allDetectionsSummary[id].toLocaleString(), '&nbsp;')} ${pad(8, filteredDetections[id].toLocaleString(), '&nbsp;')}`
  ]))

  return `
    Monitoring Station Deployment<br><br>

    ${metaHtml}<br><br>

    <hr><br>

    Deployment Summary (# Daily Detections)<br><br>
    ${pad(20, 'All', '&nbsp;')} ${pad(8, 'Filtered', '&nbsp;')}<br>
    ${detectionsHtml}
  `
}

export function tipHtml (d, deployment, type) {
  // d: feature (data bound to element)
  // deployment: associated with feature
  // type: point, track
  if (deployment.platform_type === 'towed') {
    if (type === 'track') {
      return towedTrackHtml(d, deployment)
    } else if (type === 'point') {
      return towedPointHtml(d, deployment)
    }
  } else if (deployment.platform_type === 'slocum' || deployment.platform_type === 'wave') {
    if (type === 'track') {
      return gliderTrackHtml(d, deployment)
    } else if (type === 'point') {
      return gliderPointHtml(d, deployment)
    }
  }
  return stationPointHtml(d, deployment)
}
