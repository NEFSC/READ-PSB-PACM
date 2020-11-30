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

export function monitoringPeriodLabels (props) {
  const start = moment.utc(props.monitoring_start_datetime).startOf('date')
  const end = moment.utc(props.monitoring_end_datetime).startOf('date')
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

  const detectionTypesIds = [...detectionTypes.map(d => d.id), 'total']

  const rows = detectionTypesIds.map(id => {
    return [
      id === 'total' ? 'Total' : detectionTypesMap.get(id).label,
      `${pad(6, allDetectionsSummary[id] ? allDetectionsSummary[id].toLocaleString() : 0, '&nbsp;')} ${pad(8, filteredDetections[id] ? filteredDetections[id].toLocaleString() : 0, '&nbsp;')}`
    ]
  })

  return htmlTable(rows)
}
const trackHtml = (d, deployment) => {
  const props = deployment.properties
  const monitoring = monitoringPeriodLabels(props)

  const trackHtml = htmlTable([
    [ 'Project', `${props.project}` ],
    [ 'Site', `${props.site_id ? props.site_id : 'N/A'}` ],
    [ 'Platform Type', `${platformTypesMap.get(props.platform_type).label}` ],
    [ 'Recorder Type', `${props.instrument_type ? props.instrument_type : 'N/A'}` ],
    [ 'Detection Method', `${props.detection_method ? props.detection_method : 'N/A'}` ],
    [ 'QAQC', `${props.qc_data ? props.qc_data : 'N/A'}` ],
    [ 'Deployed', `${monitoring.start} to ${monitoring.end}` ],
    [ 'Duration', `${monitoring.duration} days` ]
  ])

  const detectionHtml = detectionTableHtml(deployment)

  return `
    ${deployment.properties.platform_type === 'towed' ? 'Towed Array' : 'Glider'} Deployment<br><br>

    ${trackHtml}<br><br>

    <hr><br>

    Deployment Summary (# Recorded Days)<br><br>
    ${pad(20, 'All', '&nbsp;')} ${pad(8, 'Filtered', '&nbsp;')}<br>
    ${detectionHtml}
  `
}

const towedPointHtml = (d, deployment) => {
  const detectionHtml = htmlTable([
    [ 'Detection Start', `${moment.utc(d.analysis_period_start_datetime).format('ll LTS')}` ],
    [ 'Detection End', `${d.analysis_period_end_datetime ? moment.utc(d.analysis_period_end_datetime).format('ll LTS') : 'N/A'}` ],
    [ 'Duration', `${isFinite(d.analysis_period_effort_seconds) ? d.analysis_period_effort_seconds.toFixed(1) + ' sec' : 'N/A'}` ],
    [ 'Position', `${d.latitude.toFixed(4)}, ${d.longitude.toFixed(4)}` ],
    [ 'Detection', `${detectionTypesMap.get(d.presence).label}` ]
    // [ 'Call Type/Species', `${d.properties.call_type ? d.properties.call_type : 'N/A'}` ]
  ])
  return `
    ${trackHtml(d, deployment)}<br><br>

    <hr><br>

    Highlighted Detection<br><br>
    ${detectionHtml}
  `
}

const gliderPointHtml = (d, deployment) => {
  const detectionHtml = htmlTable([
    [ 'Date', `${moment.utc(d.date).format('ll')}` ],
    [ 'Position', `${d.latitude.toFixed(4)}, ${d.longitude.toFixed(4)}` ],
    [ 'Detection', `${detectionTypesMap.get(d.presence).label}` ]
    // [ 'Species', `${speciesTypesMap.get(deployment.species).label}` ]
  ])
  return `
    ${trackHtml(d, deployment)}<br><br>
    <hr><br>
    Highlighted Daily Detection<br><br>
    ${detectionHtml}
  `
}

const stationHtml = (d, deployment) => {
  const props = deployment.properties
  const monitoring = monitoringPeriodLabels(props)

  const metaHtml = htmlTable([
    [ 'Project', `${props.project}` ],
    [ 'Site', `${props.site_id ? props.site_id : 'N/A'}` ],
    [ 'Platform Type', `${platformTypesMap.get(props.platform_type).label}` ],
    [ 'Recorder Type', `${props.instrument_type}` ],
    [ 'Detection Method', `${props.detection_method}` ],
    [ 'QAQC', `${props.qc_data ? props.qc_data : 'N/A'}` ],
    [ 'Recorder Depth', props.recorder_depth_meters ? `${(+props.recorder_depth_meters).toFixed(0)} m` : 'N/A' ],
    [ 'Water Depth', props.water_depth_meters ? `${(+props.water_depth_meters).toFixed(0)} m` : 'N/A' ],
    [ 'Deployed', `${monitoring.start} to ${monitoring.end}` ],
    [ 'Duration', `${monitoring.duration} days` ]
  ])
  const detectionHtml = detectionTableHtml(deployment)

  return `
    Monitoring Station Deployment<br><br>

    ${metaHtml}<br><br>

    <hr><br>

    Deployment Summary (# Recorded Days)<br><br>
    ${pad(20, 'All', '&nbsp;')} ${pad(8, 'Filtered', '&nbsp;')}<br>
    ${detectionHtml}
  `
}

const deploymentHtml = (d, deployment) => {
  const props = deployment.properties
  const monitoring = monitoringPeriodLabels(props)

  const metaHtml = htmlTable([
    [ 'Project', `${props.project}` ],
    [ 'Site', `${props.site_id ? props.site_id : 'N/A'}` ],
    [ 'Platform Type', `${platformTypesMap.get(props.platform_type).label}` ],
    [ 'Recorder Type', `${props.instrument_type}` ],
    [ 'Recorder Depth', props.recorder_depth_meters ? `${(+props.recorder_depth_meters).toFixed(0)} m` : 'N/A' ],
    [ 'Water Depth', props.water_depth_meters ? `${(+props.water_depth_meters).toFixed(0)} m` : 'N/A' ],
    [ 'Deployed', `${monitoring.start} to ${monitoring.end}` ],
    [ 'Duration', `${monitoring.duration} days` ]
  ])

  return `
    Monitoring Station Deployment<br><br>

    ${metaHtml}
  `
}

export function tipHtml (d, deployment, nNearby, type) {
  if (type === 'track') {
    return trackHtml(d, deployment)
  }

  let html
  if (type === 'deployment') {
    html = deploymentHtml(d, deployment)
  } else if (type === 'point') {
    if (deployment.properties.platform_type === 'towed') {
      html = towedPointHtml(d, deployment)
    } else {
      html = gliderPointHtml(d, deployment)
    }
  } else {
    html = stationHtml(d, deployment)
  }

  if (nNearby > 0) {
    html += `<br><br><hr><br>Warning: There are ${nNearby} station(s) near this location.<br>Zoom in to view other stations.`
  }

  return html
}
