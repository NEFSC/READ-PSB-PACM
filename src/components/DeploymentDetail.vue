<template>
  <v-dialog
    :model-value="selectedDeployments.length > 0"
    :fullscreen="$vuetify.display.mobile"
    max-width="1600"
    width="calc(100vw - 48px)"
    scrollable
    @update:model-value="onDialogModelUpdate"
  >
  <v-card class="deployment-detail-dialog">
    <v-toolbar color="grey-darken-2" density="compact" theme="dark" class="pl-2">
      <div v-if="isSiteView" class="text-subtitle-1 font-weight-bold">
        Selected Site ({{ selectedDeployments.length }} deployments)
      </div>
      <div v-else class="text-subtitle-1 font-weight-bold">
        Selected Deployments
        ({{ index + 1 }} of {{ selectedDeployments.length }})
        <v-tooltip open-delay="500" location="bottom">
          <template v-slot:activator="{ props }">
            <v-btn
              icon
              size="small"
              :disabled="index === 0"
              @click="index -= 1"
              v-bind="props"
              aria-label="previous"
            >
              <v-icon>mdi-menu-left</v-icon>
            </v-btn>
          </template>
          <span>Previous</span>
        </v-tooltip>
        <v-tooltip open-delay="500" location="bottom">
          <template v-slot:activator="{ props }">
            <v-btn
              icon
              size="small"
              :disabled="index === (selectedDeployments.length - 1)"
              @click="index += 1"
              v-bind="props"
              aria-label="next"
            >
              <v-icon>mdi-menu-right</v-icon>
            </v-btn>
          </template>
          <span>Next</span>
        </v-tooltip>
      </div>
      <v-spacer></v-spacer>
      <v-tooltip open-delay="500" location="bottom">
        <template v-slot:activator="{ props }">
          <v-btn icon size="small" @click="close" v-bind="props" aria-label="close">
            <v-icon size="small">mdi-close</v-icon>
          </v-btn>
        </template>
        <span>Close</span>
      </v-tooltip>
    </v-toolbar>
    <v-card-text
      class="deployment-detail-body"
      :style="{ 'max-height': $vuetify.display.mobile ? 'none' : Math.round($vuetify.display.height * 0.82) + 'px' }"
    >
      <v-row class="deployment-detail-content">
        <v-col cols="12" md="5" xl="4">
          <div class="deployment-detail-metadata">
            <div
              v-for="field in activeMetadataFields"
              :key="field.label"
              class="deployment-detail-metadata__item"
            >
              <span class="deployment-detail-metadata__label">{{ field.label }}:</span>
              <span class="deployment-detail-metadata__value">{{ field.value }}</span>
            </div>
          </div>
        </v-col>

        <v-col
          v-if="!activeTheme.deploymentsOnly || activeCitations.length > 0"
          cols="12"
          md="7"
          xl="8"
          class="text-black"
        >
          <template v-if="!activeTheme.deploymentsOnly">
            <div class="heading font-weight-bold">Daily Detections</div>
            <div v-if="isSiteView" class="text-subtitle-2 text-grey-darken-1">
              Shaded periods indicate unmonitored gaps between deployments.
            </div>
            <highcharts class="chart" :options="chart"></highcharts>
          </template>

          <template v-if="activeCitations.length > 0">
            <v-divider v-if="!activeTheme.deploymentsOnly" class="my-5"></v-divider>
            <section class="deployment-detail-citations">
              <div class="heading font-weight-bold mb-1">Citations</div>
              <ul class="deployment-detail-citations__list">
                <li
                  v-for="citation in activeCitations"
                  :key="citation.key"
                  class="deployment-detail-citations__item text-body-2 text-grey-darken-3"
                >
                  {{ citation.reference }}
                </li>
              </ul>
            </section>
          </template>
        </v-col>
      </v-row>
    </v-card-text>
  </v-card>
  </v-dialog>
</template>

<script>
import { mapActions, mapGetters } from 'vuex'
import moment from 'moment'

import evt from '@/lib/events'
import { xf } from '@/lib/crossfilter'
import { detectionTypes, detectionTypesMap } from '@/lib/constants'
import { monitoringPeriodLabels, dutyCycleLabel } from '@/lib/tip'
import { createContributorCitation, parseCitationCodes } from '@/lib/citations'

export default {
  name: 'DeploymentDetail',
  data () {
    return {
      detectionTypesMap,
      index: 0,
      chart: {
        chart: {
          type: 'scatter',
          zoomType: 'x',
          height: 360,
          marginRight: 50,
          marginLeft: 70
        },
        plotOptions: {
          series: {
            turboThreshold: 100000
          }
        },
        title: {
          text: undefined
        },
        legend: {
          enabled: false
        },
        tooltip: {
          headerFormat: '<span style="font-size: 10px">{point.key}</span><br/>',
          pointFormat: '{series.name}: <b>{point.label}</b>',
          dateTimeLabelFormats: {
            day: '%b %e, %Y',
            hour: '%b %e, %Y',
            minute: '%b %e, %Y'
          }
        },
        xAxis: {
          type: 'datetime',
          dateTimeLabelFormats: {
            week: '%b %d'
          },
          title: {
            text: 'Date'
          }
        },
        yAxis: {
          title: {
            text: undefined
          },
          type: 'category',
          categories: detectionTypes.filter(d => d.id !== 'rd').map(d => d.label),
          reversed: true,
          min: 0,
          max: detectionTypes.length - 2,
          labels: {
            step: 1
          }
        },
        series: []
      }
    }
  },
  computed: {
    ...mapGetters(['selectedDeployments', 'activeTheme', 'citations', 'organizations']),
    isSiteView () {
      if (this.selectedDeployments.length < 1) return false
      const isStationary = this.selectedDeployments.every(d => d.deployment_type === 'STATIONARY')
      const siteId = this.selectedDeployments[0].site_id
      return isStationary && siteId && this.selectedDeployments.every(d => d.site_id === siteId)
    },
    siteMetadata () {
      if (!this.isSiteView) return null
      const deps = this.selectedDeployments
      const unique = (key) => {
        const vals = [...new Set(deps.map(d => d[key]).filter(Boolean))]
        return vals.length > 0 ? vals.join(', ') : 'N/A'
      }
      const uniqueArray = (key) => {
        const vals = [...new Set(deps.map(d => d[key].split(',').map(v => v.trim())).flat())]
        return vals.length > 0 ? vals.join(', ') : 'N/A'
      }
      const range = (key, suffix) => {
        const vals = deps.map(d => +d[key]).filter(v => isFinite(v))
        if (vals.length === 0) return 'N/A'
        const min = Math.min(...vals)
        const max = Math.max(...vals)
        return min === max ? `${min.toFixed(0)} ${suffix}` : `${min.toFixed(0)} to ${max.toFixed(0)} ${suffix}`
      }
      const starts = deps.map(d => moment.utc(d.monitoring_start_datetime)).filter(m => m.isValid())
      const ends = deps.map(d => moment.utc(d.monitoring_end_datetime)).filter(m => m.isValid())
      return {
        organizationCode: unique('deployment_organization_code'),
        analysisOrganizationCode: unique('analysis_organization_code'),
        site: deps[0].site || deps[0].site_id || 'N/A',
        project: unique('project'),
        platformType: unique('platform_type'),
        instrumentType: uniqueArray('instrument_type'),
        samplingRate: unique('sampling_rate_hz'),
        detectionMethod: unique('detection_method'),
        detectorVersion: unique('analysis_detector_version'),
        projectFunding: unique('project_funding'),
        qcData: unique('qc_data'),
        recorderDepth: range('recorder_depth_meters', 'm'),
        waterDepth: range('water_depth_meters', 'm'),
        monitoringStart: starts.length > 0 ? moment.min(starts).format('ll') : 'N/A',
        monitoringEnd: ends.length > 0 ? moment.max(ends).format('ll') : 'N/A',
        nDeployments: deps.length,
        dataPoc: unique('data_poc')
      }
    },
    selectedDeployment () {
      return this.selectedDeployments.length > 0
        ? this.selectedDeployments[this.index]
        : null
    },
    citationByCode () {
      return new Map((this.citations || []).map(citation => [citation.code, citation]))
    },
    organizationByCode () {
      return new Map((this.organizations || []).map(organization => [organization.code, organization]))
    },
    accessedDate () {
      return new Date().toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      })
    },
    siteDeploymentCitations () {
      return this.getDeploymentCitations(this.selectedDeployments)
    },
    selectedDeploymentCitations () {
      return this.getDeploymentCitations(this.selectedDeployment ? [this.selectedDeployment] : [])
    },
    activeCitations () {
      return this.isSiteView ? this.siteDeploymentCitations : this.selectedDeploymentCitations
    },
    siteMetadataFields () {
      const m = this.siteMetadata
      if (!m) return []
      const showAnalysis = !this.activeTheme?.deploymentsOnly
      return [
        { label: 'Monitoring Organization', value: m.organizationCode },
        { label: 'Site', value: m.site },
        { label: 'Project', value: m.project },
        { label: 'Platform Type', value: m.platformType },
        { label: 'Recorder Type', value: m.instrumentType },
        { label: 'Sampling Rate', value: `${m.samplingRate} Hz` },
        showAnalysis && { label: 'Analysis Organization', value: m.analysisOrganizationCode },
        showAnalysis && { label: 'Detection Method', value: m.detectionMethod },
        showAnalysis && m.detectorVersion !== 'N/A' && { label: 'Detector Version', value: m.detectorVersion },
        showAnalysis && { label: 'Analysis QAQC', value: m.qcData },
        m.projectFunding !== 'N/A' && { label: 'Project Funding', value: m.projectFunding },
        { label: 'Recorder Depth', value: m.recorderDepth },
        { label: 'Water Depth', value: m.waterDepth },
        { label: 'Monitoring Period', value: `${m.monitoringStart} to ${m.monitoringEnd}` },
        { label: '# Deployments', value: m.nDeployments },
        { label: 'Point of Contact', value: m.dataPoc }
      ].filter(Boolean)
    },
    deploymentMetadataFields () {
      const d = this.selectedDeployment
      if (!d) return []
      const showAnalysis = !this.activeTheme?.deploymentsOnly
      const isStationary = d.deployment_type === 'STATIONARY'
      const showSite = this.deploymentType === 'station' || this.deploymentType === 'glider'
      const period = this.monitoringPeriod
      const depth = value => value ? `${(+value).toFixed(0)} m` : 'N/A'
      const dutyCycle = dutyCycleLabel(d.recording_duration_secs, d.recording_interval_secs)
      // new PARS fields: shown only when the value is present, so
      // makara records without them stay uncluttered
      const hasDmp = d.dynamic_management_platform === true || d.dynamic_management_platform === false
      return [
        { label: 'Monitoring Organization', value: d.deployment_organization_code },
        { label: 'Deployment', value: d.deployment_code },
        { label: 'Project', value: d.project },
        showSite && { label: 'Site', value: d.site ? d.site : 'N/A' },
        { label: 'Platform Type', value: d.platform_type || 'N/A' },
        { label: 'Recorder Type', value: d.instrument_type || 'N/A' },
        { label: 'Sampling Rate', value: d.sampling_rate_hz + ' Hz' || 'N/A' },
        dutyCycle && { label: 'Duty Cycle', value: dutyCycle },
        showAnalysis && { label: 'Analysis Organization', value: d.analysis_organization_code ? d.analysis_organization_code : 'N/A' },
        showAnalysis && { label: 'Detection Method', value: d.detection_method ? d.detection_method : 'N/A' },
        showAnalysis && d.analysis_detector_version && { label: 'Detector Version', value: d.analysis_detector_version },
        showAnalysis && { label: 'Analysis QAQC', value: d.qc_data ? d.qc_data : 'N/A' },
        isStationary && { label: 'Recorder Depth', value: depth(d.recorder_depth_meters) },
        isStationary && { label: 'Water Depth', value: depth(d.water_depth_meters) },
        { label: 'Deployed', value: `${period.start || 'N/A'} to ${period.end || 'N/A'}` },
        { label: 'Duration', value: isFinite(period.duration) ? period.duration.toLocaleString() + ' days' : 'N/A' },
        hasDmp && { label: 'Dynamic Mgmt Platform', value: d.dynamic_management_platform ? 'Yes' : 'No' },
        d.project_funding && { label: 'Project Funding', value: d.project_funding },
        d.deployment_url && { label: 'Data URL', value: d.deployment_url },
        { label: 'Point of Contact', value: d.data_poc },
        showAnalysis && { label: 'Protocol', value: d.protocol_reference }
      ].filter(Boolean)
    },
    activeMetadataFields () {
      return this.isSiteView ? this.siteMetadataFields : this.deploymentMetadataFields
    },
    deploymentType () {
      // platform_type uses uppercase codes from platform_types.json
      // (BOTTOM_MOUNTED_MOORING, ELECTRIC_GLIDER, TOWED_ARRAY, ...). Classify
      // from the authoritative STATIONARY/MOBILE deployment_type so this stays
      // correct as new platform codes are added; only towed vs glider needs the
      // specific code. This drives showSite (stations and gliders have sites).
      const d = this.selectedDeployment
      if (!d) return 'unknown'
      if (d.deployment_type === 'STATIONARY') {
        return 'station'
      } else if (d.platform_type === 'TOWED_ARRAY') {
        return 'towed'
      } else if (d.deployment_type === 'MOBILE') {
        return 'glider'
      }
      return 'unknown'
    },
    monitoringPeriod () {
      return monitoringPeriodLabels(this.selectedDeployment)
    }
  },
  watch: {
    selectedDeployments () {
      this.index = 0
      if (this.isSiteView) this.updateChart()
    },
    selectedDeployment () {
      if (!this.isSiteView) this.updateChart()
    }
  },
  mounted () {
    this.updateChart()

    evt.$on('xf:dataAdded', this.updateChart)
    evt.$on('xf:dataRemoved', this.updateChart)
    evt.$on('xf:filtered', this.updateChart)
  },
  beforeUnmount () {
    evt.$off('xf:dataAdded', this.updateChart)
    evt.$off('xf:dataRemoved', this.updateChart)
    evt.$off('xf:filtered', this.updateChart)
  },
  methods: {
    ...mapActions(['selectDeployments']),
    close () {
      this.selectDeployments()
    },
    onDialogModelUpdate (value) {
      if (!value) this.close()
    },
    normalizeOrganizationCode (code) {
      return code || 'UNKNOWN'
    },
    normalizeSource (source) {
      const normalizedSource = String(source || 'PARS').toUpperCase()
      return ['MAKARA', 'PARS'].includes(normalizedSource) ? normalizedSource : 'PARS'
    },
    getDeploymentCitations (deployments) {
      const codes = new Set()

      deployments.forEach(deployment => {
        parseCitationCodes(deployment?.citations)
          .forEach(code => codes.add(code))
      })

      const preferredCitations = Array.from(codes)
        .sort()
        .map(code => ({
          key: `citation:${code}`,
          code,
          reference: this.citationByCode.get(code)?.reference || code
        }))

      const organizationCitations = this.getDeploymentOrganizationSources(deployments).map(({ organizationCode, sources }) => {
        const organization = this.organizationByCode.get(organizationCode) || { code: organizationCode }
        return {
          key: `organization:${organizationCode}`,
          code: organizationCode,
          reference: createContributorCitation(organization, this.accessedDate, sources)
        }
      })

      return [
        ...preferredCitations,
        ...organizationCitations
      ].sort((a, b) => a.reference.localeCompare(b.reference))
    },
    getDeploymentOrganizationSources (deployments) {
      const organizationSources = new Map()

      deployments.forEach(deployment => {
        if (!deployment) return

        const source = this.normalizeSource(deployment.source)
        const organizationCodes = [
          deployment.deployment_organization_code,
        ]
        if (deployment.analysis_organization_code) {
          organizationCodes.push(deployment.analysis_organization_code)
        }

        organizationCodes.forEach(organizationCode => {
          if (!organizationSources.has(organizationCode)) {
            organizationSources.set(organizationCode, new Set())
          }
          organizationSources.get(organizationCode).add(source)
        })
      })

      return Array.from(organizationSources.entries())
        .map(([organizationCode, sources]) => ({
          organizationCode,
          sources: Array.from(sources).sort()
        }))
        .sort((a, b) => a.organizationCode.localeCompare(b.organizationCode))
    },
    updateChart () {
      if (this.activeTheme && this.activeTheme.deploymentsOnly) return

      const ids = detectionTypes.map(d => d.id)

      const allIds = this.selectedDeployments.map(d => d.id)
      const detections = xf.all().filter(d => allIds.includes(d.id))
      // if (this.isSiteView) {
      const values = detections.map((d) => {
        if (!d.presence) return null
        const status = detectionTypes.find(s => s.id === d.presence)
        return {
          x: (new Date(d.date)).valueOf(),
          y: ids.indexOf(d.presence),
          label: status.label,
          marker: {
            fillColor: status.color
          }
        }
      })
      this.chart.series = [{
        name: 'Result',
        data: values
      }]

      // const filteredDetections = xf.allFiltered().filter(d => allIds.includes(d.id))
      const filteredDetections = xf.allFiltered().filter(d => allIds.includes(d.id))
      const minDetectionDate = Math.min(...filteredDetections.map(d => new Date(d.date)).filter(d => d !== null))
      const maxDetectionDate = Math.max(...filteredDetections.map(d => new Date(d.date)).filter(d => d !== null))
      this.chart.xAxis.min = minDetectionDate
      this.chart.xAxis.max = maxDetectionDate

      // compute gaps between deployments for shaded plotBands
      const intervals = this.selectedDeployments
        .map(d => ({
          start: moment.utc(d.analysis_start_date),
          end: moment.utc(d.analysis_end_date)
        }))
        .filter(iv => iv.start.isValid() && iv.end.isValid())
        .sort((a, b) => a.start.valueOf() - b.start.valueOf())
      console.log('[DeploymentDetail.updateChart] intervals', intervals)
      const plotBands = []
      for (let i = 1; i < intervals.length; i++) {
        const prevEnd = intervals[i - 1].end
        const nextStart = intervals[i].start
        if (prevEnd.isBefore(nextStart) &&
            nextStart.diff(prevEnd, 'days') > 1 &&
            nextStart.isAfter(minDetectionDate) &&
            prevEnd.isBefore(maxDetectionDate)) {
          console.log('[DeploymentDetail.updateChart] plotBand', {
            from: prevEnd.format('YYYY-MM-DD'),
            to: nextStart.format('YYYY-MM-DD')
          })
          plotBands.push({
            from: prevEnd.add(12, 'hours').valueOf(),
            to: nextStart.subtract(12, 'hours').valueOf(),
            color: 'rgba(0, 0, 0, 0.06)'
          })
        }
      }
      console.log('[DeploymentDetail.updateChart] plotBands', plotBands)
      this.chart.xAxis.plotBands = plotBands
    }
  }
}
</script>

<style scoped>
.deployment-detail-dialog {
  max-height: calc(100vh - 48px);
}

.deployment-detail-body {
  overflow-y: auto;
}

.deployment-detail-content {
  min-height: 420px;
}

.deployment-detail-metadata {
  font-size: 0.875rem;
}

.deployment-detail-metadata__item {
  break-inside: avoid;
  display: flex;
  gap: 0.75rem;
  align-items: baseline;
  padding: 5px 0;
  line-height: 1.4;
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);
}

.deployment-detail-metadata__label {
  flex: 0 0 170px;
  text-align: right;
  color: #555;
  white-space: nowrap;
}

.deployment-detail-metadata__value {
  min-width: 0;
  font-weight: 700;
  overflow-wrap: anywhere;
}

.deployment-detail-citations__list {
  list-style: none;
  margin: 0;
  padding: 0;
}

.deployment-detail-citations__item {
  margin-bottom: 0.9rem;
  padding-left: 1.25rem;
  text-indent: -1.25rem;
  line-height: 1.5;
  overflow-wrap: anywhere;
}
</style>
