import { nest } from 'd3-collection'
import moment from 'moment'
import pad from 'pad'

import { xf, deploymentMap, siteMap } from '@/lib/crossfilter'
import { detectionTypes, detectionTypesMap } from '@/lib/constants'

const orNa = (value) => value || 'N/A'

export function tipOffset (event, el) {
  const padding = 20

  const screenWidth = document.body.offsetWidth
  const screenHeight = document.body.offsetHeight

  const nodeWidth = el.node().clientWidth
  const nodeHeight = el.node().clientHeight

  const offsetY = event.y + nodeHeight + padding > screenHeight
    ? -1 * (event.y + nodeHeight + padding - screenHeight)
    : padding

  const offsetX = nodeWidth + padding + event.x > screenWidth
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
    start: start.isValid() ? start.format('ll') : undefined,
    end: end.isValid() ? end.format('ll') : undefined,
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

  const detectionTypesIds = [...detectionTypes.filter(d => d.id !== 'd').map(d => d.id), 'total']

  const rows = detectionTypesIds.map(id => {
    return [
      id === 'total' ? 'Total' : detectionTypesMap.get(id).label,
      `${pad(6, allDetectionsSummary[id] ? allDetectionsSummary[id].toLocaleString() : 0, '&nbsp;')} ${pad(8, filteredDetections[id] ? filteredDetections[id].toLocaleString() : 0, '&nbsp;')}`
    ]
  })

  return htmlTable(rows)
}

const detectionTableFromValues = (filteredValues, allValues) => {
  const detectionTypesIds = [...detectionTypes.filter(d => d.id !== 'd').map(d => d.id), 'total']

  const rows = detectionTypesIds.map(id => {
    return [
      id === 'total' ? 'Total' : detectionTypesMap.get(id).label,
      `${pad(6, allValues[id] ? allValues[id].toLocaleString() : 0, '&nbsp;')} ${pad(8, filteredValues[id] ? filteredValues[id].toLocaleString() : 0, '&nbsp;')}`
    ]
  })

  return htmlTable(rows)
}

const uniqueStrings = (deployments, key) => {
  const values = [...new Set(deployments.map(d => d[key]).filter(Boolean))]
  return values.length > 0 ? values.join(', ') : 'N/A'
}

const numericRange = (deployments, key, suffix) => {
  const values = deployments.map(d => +d[key]).filter(v => isFinite(v))
  if (values.length === 0) return 'N/A'
  const min = Math.min(...values)
  const max = Math.max(...values)
  if (min === max) return `${min.toFixed(0)} ${suffix}`
  return `${min.toFixed(0)} to ${max.toFixed(0)} ${suffix}`
}

const siteHtml = (d, siteDeployments) => {
  const filteredValues = siteMap.get(d.site_id) || { y: 0, n: 0, m: 0, na: 0, d: 0, total: 0 }

  const allDetections = xf.all().filter(det => det.site_id === d.site_id)
  const allValues = { y: 0, n: 0, m: 0, na: 0, d: 0, total: 0 }
  allDetections.forEach(det => {
    allValues[det.presence] = (allValues[det.presence] || 0) + 1
    allValues.total += 1
  })

  const deps = siteDeployments || []

  const monitoringStarts = deps.map(dep => moment.utc(dep.monitoring_start_datetime)).filter(m => m.isValid())
  const monitoringEnds = deps.map(dep => moment.utc(dep.monitoring_end_datetime)).filter(m => m.isValid())
  const earliest = monitoringStarts.length > 0 ? moment.min(monitoringStarts).format('ll') : 'N/A'
  const latest = monitoringEnds.length > 0 ? moment.max(monitoringEnds).format('ll') : 'N/A'

  const metaHtml = htmlTable([
    ['Organization', `${orNa(d.organization_code)}`],
    ['Site', `${orNa(d.site)}`],
    // ['Coordinates', `${d.site_latitude.toFixed(4)}, ${d.site_longitude.toFixed(4)}`],
    ['Project', uniqueStrings(deps, 'project')],
    ['Platform Type', uniqueStrings(deps, 'platform_type')],
    ['Recorder Type', uniqueStrings(deps, 'instrument_type')],
    ['Sampling Rate (Hz)', uniqueStrings(deps, 'sampling_rate_hz')],
    ['Detection Method', uniqueStrings(deps, 'detection_method')],
    // ['Call Types', uniqueStrings(deps, 'call_type')],
    ['Analysis QAQC', uniqueStrings(deps, 'qc_data')],
    ['Recorder Depth', numericRange(deps, 'recorder_depth_meters', 'm')],
    ['Water Depth', numericRange(deps, 'water_depth_meters', 'm')],
    ['Monitoring Period', `${earliest} to ${latest}`],
    ['# Deployments', `${deps.length}`]
  ])

  const detectionHtml = detectionTableFromValues(filteredValues, allValues)

  return `
    Stationary Platform<br><br>

    ${metaHtml}<br><br>

    <hr><br>

    Detection Summary (# Recorded Days)<br><br>
    ${pad(21, 'All', '&nbsp;')} ${pad(8, 'Filtered', '&nbsp;')}<br>
    ${detectionHtml}
  `
}

const deploymentHtml = (d, deployment) => {
  const props = deployment
  const monitoring = monitoringPeriodLabels(props)

  const metaHtml = htmlTable([
    ['Organization', `${orNa(d.organization_code)}`],
    ['Deployment', `${orNa(d.deployment_code)}`],
    // ['Site', `${orNa(props.site)}`],
    // ['Coordinates', `${d.latitude.toFixed(4)}, ${d.longitude.toFixed(4)}`],
    ['Project', `${props.project}`],
    ['Platform Type', `${orNa(props.platform_type)}`],
    ['Recorder Type', `${orNa(props.instrument_type)}`],
    ['Sampling Rate (Hz)', `${props.sampling_rate_hz ? (props.sampling_rate_hz / 1000).toLocaleString() + ' kHz' : 'N/A'}`],
    ['Detection Method', `${orNa(props.detection_method)}`],
    // ['Call Type', `${orNa(props.call_type)}`],
    ['Analysis QAQC', `${orNa(props.qc_data)}`],
    ['Recorder Depth', props.recorder_depth_meters ? `${(+props.recorder_depth_meters).toFixed(0)} m` : 'N/A'],
    ['Water Depth', props.water_depth_meters ? `${(+props.water_depth_meters).toFixed(0)} m` : 'N/A'],
    ['Monitoring Period', `${orNa(monitoring.start)} to ${orNa(monitoring.end)}`],
    // ['Duration', `${monitoring.duration ? monitoring.duration + ' days' : 'N/A'} `]
    ['# Deployments', 1]
  ])
  const detectionHtml = detectionTableHtml(deployment)

  return `
    Stationary Platform<br><br>

    ${metaHtml}<br><br>

    <hr><br>

    Detection Summary (# Recorded Days)<br><br>
    ${pad(20, 'All', '&nbsp;')} ${pad(8, 'Filtered', '&nbsp;')}<br>
    ${detectionHtml}
  `
}

const trackHtml = (d, deployment) => {
  const props = deployment
  const monitoring = monitoringPeriodLabels(props)

  const trackHtml = htmlTable([
    ['Project', `${props.project}`],
    ['Site', `${orNa(props.site)}`],
    ['Platform Type', `${orNa(props.platform_type)}`],
    ['Recorder Type', `${orNa(props.instrument_type)}`],
    // ['Sampling Rate', `${props.sampling_rate_hz ? (props.sampling_rate_hz / 1000).toLocaleString() + ' kHz' : 'N/A'}`],
    ['Sampling Rates (Hz)', `${orNa(props.sampling_rate_hz)}`],
    ['Detection Method', `${orNa(props.detection_method)}`],
    // ['Call Type', `${orNa(props.call_type)}`],
    ['Analysis QAQC', `${orNa(props.qc_data)}`],
    ['Deployed', `${orNa(monitoring.start)} to ${orNa(monitoring.end)}`],
    ['Duration', `${monitoring.duration ? monitoring.duration + ' days' : 'N/A'} `]
  ])

  const detectionHtml = detectionTableHtml(deployment)

  return `
    Mobile Platform<br><br>

    ${trackHtml}<br><br>

    <hr><br>

    Detection Summary (# Recorded Days)<br><br>
    ${pad(20, 'All', '&nbsp;')} ${pad(8, 'Filtered', '&nbsp;')}<br>
    ${detectionHtml}
  `
}

const towedPointHtml = (d, deployment) => {
  const detectionHtml = htmlTable([
    ['Detection Start', `${moment.utc(d.analysis_period_start_datetime).format('ll LTS')}`],
    ['Detection End', `${d.analysis_period_end_datetime ? moment.utc(d.analysis_period_end_datetime).format('ll LTS') : 'N/A'}`],
    ['Duration', `${isFinite(d.analysis_period_effort_seconds) ? d.analysis_period_effort_seconds.toFixed(1) + ' sec' : 'N/A'}`],
    ['Position', `${d.latitude.toFixed(4)}, ${d.longitude.toFixed(4)}`],
    ['Detection', `${detectionTypesMap.get(d.presence).label}`]
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
    ['Date', `${moment.utc(d.date).format('ll')}`],
    ['Position', `${d.latitude.toFixed(4)}, ${d.longitude.toFixed(4)}`],
    ['Detection', `${detectionTypesMap.get(d.presence).label}`]
    // [ 'Species', `${speciesTypesMap.get(deployment.species).label}` ]
  ])
  return `
    ${trackHtml(d, deployment)}<br><br>
    <hr><br>
    Highlighted Daily Detection<br><br>
    ${detectionHtml}<br><br>
    Note: Only the first detection on each date is shown on the map.
    There may be other detections on this date at nearby locations.
  `
}

export function tipHtml (d, deployment, nNearby, type, siteDeployments) {
  if (type === 'site') {
    let html = siteHtml(d, siteDeployments)
    if (nNearby > 1) {
      html += `<br><br><hr><br>Warning: There are ${nNearby} other sites near this location.<br>Zoom in to better distinguish them.`
    } else if (nNearby === 1) {
      html += `<br><br><hr><br>Warning: There is ${nNearby} other site near this location.<br>Zoom in to better distinguish the two.`
    }
    return html
  }

  if (type === 'track') {
    return trackHtml(d, deployment)
  }

  let html
  if (type === 'deployment') {
    html = deploymentHtml(d, deployment)
  } else if (type === 'point') {
    if (deployment.platform_type === 'towed') {
      html = towedPointHtml(d, deployment)
    } else {
      html = gliderPointHtml(d, deployment)
    }
  } else {
    html = deploymentHtml(d, deployment)
  }

  if (nNearby > 1) {
    html += `<br><br><hr><br>Warning: There are ${nNearby} other deployments near this location.<br>Zoom in to better distinguish them, or click to select these deployments and view their metadata and daily detection history.`
  } else if (nNearby === 1) {
    html += `<br><br><hr><br>Warning: There is ${nNearby} other deployment near this location.<br>Zoom in to better distinguish the two, or click to select both deployments and view their metadata and daily detection history.`
  }

  return html
}
