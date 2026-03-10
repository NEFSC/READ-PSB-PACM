<template>
  <v-card>
    <v-toolbar color="grey darken-2" dense dark>
      <div v-if="isSiteView" class="subtitle-1 font-weight-bold">
        Selected Site ({{ selectedDeployments.length }} deployments)
      </div>
      <div v-else class="subtitle-1 font-weight-bold">
        Selected Deployments
        ({{ index + 1 }} of {{ selectedDeployments.length }})
        <v-tooltip open-delay="500" bottom>
          <template v-slot:activator="{ on }">
            <v-btn
              icon
              small
              :disabled="index === 0"
              @click="index -= 1"
              v-on="on"
              aria-label="previous"
            >
              <v-icon>mdi-menu-left</v-icon>
            </v-btn>
          </template>
          <span>Previous</span>
        </v-tooltip>
        <v-tooltip open-delay="500" bottom>
          <template v-slot:activator="{ on }">
            <v-btn
              icon
              small
              :disabled="index === (selectedDeployments.length - 1)"
              @click="index += 1"
              v-on="on"
              aria-label="next"
            >
              <v-icon>mdi-menu-right</v-icon>
            </v-btn>
          </template>
          <span>Next</span>
        </v-tooltip>
      </div>
      <v-spacer></v-spacer>
      <v-tooltip open-delay="500" bottom>
        <template v-slot:activator="{ on }">
          <v-btn icon small @click="close" v-on="on" aria-label="close">
            <v-icon small>mdi-close</v-icon>
          </v-btn>
        </template>
        <span>Close</span>
      </v-tooltip>
    </v-toolbar>
    <v-card-text
      :style="{ 'max-height': Math.round($vuetify.breakpoint.height * 0.6) + 'px', 'overflow-y': 'auto' }"
    >
      <v-row v-if="isSiteView">
        <v-col xs="12" md="12" lg="12" xl="4">
          <v-simple-table dense>
            <tbody>
              <tr>
                <td class="px-2 text-right" style="width:140px">Organization:</td>
                <td class="px-2 font-weight-bold">{{ siteMetadata.organizationCode }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right" style="width:140px">Site:</td>
                <td class="px-2 font-weight-bold">{{ siteMetadata.site }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right" style="width:140px">Project:</td>
                <td class="px-2 font-weight-bold">{{ siteMetadata.project }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right" style="width:140px">Platform Type:</td>
                <td class="px-2 font-weight-bold">{{ siteMetadata.platformType }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Recorder Type:</td>
                <td class="px-2 font-weight-bold">{{ siteMetadata.instrumentType }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Sampling Rate:</td>
                <td class="px-2 font-weight-bold">{{ siteMetadata.samplingRate }} Hz</td>
              </tr>
              <tr v-if="!theme.deploymentsOnly">
                <td class="px-2 text-right">Detection Method:</td>
                <td class="px-2 font-weight-bold">{{ siteMetadata.detectionMethod }}</td>
              </tr>
              <tr v-if="!theme.deploymentsOnly">
                <td class="px-2 text-right">Analysis QAQC:</td>
                <td class="px-2 font-weight-bold">{{ siteMetadata.qcData }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Recorder Depth:</td>
                <td class="px-2 font-weight-bold">{{ siteMetadata.recorderDepth }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Water Depth:</td>
                <td class="px-2 font-weight-bold">{{ siteMetadata.waterDepth }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Monitoring Period:</td>
                <td class="px-2 font-weight-bold">{{ siteMetadata.monitoringStart }} to {{ siteMetadata.monitoringEnd }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right"># Deployments:</td>
                <td class="px-2 font-weight-bold">{{ siteMetadata.nDeployments }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Point of Contact:</td>
                <td class="px-2 font-weight-bold">{{ siteMetadata.dataPoc }}</td>
              </tr>
            </tbody>
          </v-simple-table>
        </v-col>

        <v-col xs="12" md="12" lg="12" xl="8" v-if="!theme.deploymentsOnly" class="black--text">
          <div class="heading font-weight-bold">Daily Detections</div>
          <div class="subtitle-2 grey--text text--darken-1">Shaded periods indicate unmonitored gaps between deployments.</div>
          <highcharts class="chart" :options="chart"></highcharts>
        </v-col>
      </v-row>

      <v-row v-else>
        <v-col xs="12" md="12" lg="12" xl="4">
          <v-simple-table dense>
            <tbody>
              <tr>
                <td class="px-2 text-right" style="width:140px">Organization:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.organization_code }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right" style="width:140px">Deployment:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.deployment_code }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right" style="width:140px">Project:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.project }}</td>
              </tr>
              <tr v-if="deploymentType === 'station' || deploymentType === 'glider'">
                <td class="px-2 text-right" style="width:140px">Site:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.site ? selectedDeployment.site : 'N/A' }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right" style="width:140px">Platform Type:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.platform_type || 'N/A' }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Recorder Type:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.instrument_type || 'N/A' }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Sampling Rate:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.sampling_rate_hz + ' Hz' || 'N/A' }}</td>
              </tr>
              <tr v-if="!theme.deploymentsOnly">
                <td class="px-2 text-right">Detection Method:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.detection_method ? selectedDeployment.detection_method : 'N/A' }}</td>
              </tr>
              <tr v-if="!theme.deploymentsOnly">
                <td class="px-2 text-right">Analysis QAQC:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.qc_data ? selectedDeployment.qc_data : 'N/A'}}</td>
              </tr>
              <tr v-if="selectedDeployment.deployment_type === 'STATIONARY'">
                <td class="px-2 text-right">Recorder Depth:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.recorder_depth_meters ? `${(+selectedDeployment.recorder_depth_meters).toFixed(0)} m` : 'N/A' }}</td>
              </tr>
              <tr v-if="selectedDeployment.deployment_type === 'STATIONARY'">
                <td class="px-2 text-right">Water Depth: </td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.water_depth_meters ? `${(+selectedDeployment.water_depth_meters).toFixed(0)} m` : 'N/A' }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Deployed:</td>
                <td class="px-2 font-weight-bold">{{ monitoringPeriod.start || 'N/A' }} to {{ monitoringPeriod.end || 'N/A' }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Duration:</td>
                <td class="px-2 font-weight-bold">{{ isFinite(monitoringPeriod.duration) ? monitoringPeriod.duration.toLocaleString() + ' days' : 'N/A' }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Point of Contact:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.data_poc }} </td>
              </tr>
              <tr v-if="!theme.deploymentsOnly">
                <td class="px-2 text-right">Protocol:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.protocol_reference }}</td>
              </tr>
            </tbody>
          </v-simple-table>
        </v-col>

        <v-col xs="12" md="12" lg="12" xl="8" v-if="!theme.deploymentsOnly" class="black--text">
          <div class="heading font-weight-bold">Daily Detections</div>
          <highcharts class="chart" :options="chart"></highcharts>
        </v-col>
      </v-row>
    </v-card-text>
  </v-card>
</template>

<script>
import { mapActions, mapGetters } from 'vuex'
import moment from 'moment'

import { xf } from '@/lib/crossfilter'
import { detectionTypes, detectionTypesMap } from '@/lib/constants'
import { monitoringPeriodLabels } from '@/lib/tip'

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
          height: 275,
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
    ...mapGetters(['selectedDeployments', 'theme']),
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
        organizationCode: unique('organization_code'),
        site: deps[0].site || deps[0].site_id || 'N/A',
        project: unique('project'),
        platformType: unique('platform_type'),
        instrumentType: unique('instrument_type'),
        samplingRate: unique('sampling_rate_hz'),
        detectionMethod: unique('detection_method'),
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
    deploymentType () {
      if (this.selectedDeployment.platform_type === 'mooring' || this.selectedDeployment.platform_type === 'buoy') {
        return 'station'
      } else if (this.selectedDeployment.platform_type === 'slocum' || this.selectedDeployment.platform_type === 'wave') {
        return 'glider'
      } else if (this.selectedDeployment.platform_type === 'towed') {
        return 'towed'
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
  },
  methods: {
    ...mapActions(['selectDeployments']),
    close () {
      this.selectDeployments()
    },
    updateChart () {
      if (this.theme && this.theme.deploymentsOnly) return

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

<style>
</style>
