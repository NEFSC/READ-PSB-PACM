<template>
  <v-card>
    <v-toolbar color="grey darken-2" dense dark>
      <div class="subtitle-1 font-weight-bold">
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
          <v-btn icon small @click="close" v-on="on">
            <v-icon small>mdi-close</v-icon>
          </v-btn>
        </template>
        <span>Close</span>
      </v-tooltip>
    </v-toolbar>
    <v-card-text
      :style="{ 'max-height': Math.round($vuetify.breakpoint.height * 0.6) + 'px', 'overflow-y': 'auto' }"
    >
      <v-row>
        <v-col xs="12" md="12" lg="12" xl="4">
          <v-simple-table dense>
            <tbody>
              <tr>
                <td class="px-2 text-right" style="width:140px">Project:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.properties.project }}</td>
              </tr>
              <tr v-if="deploymentType === 'station' || deploymentType === 'glider'">
                <td class="px-2 text-right" style="width:140px">Site:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.properties.site_id ? selectedDeployment.properties.site_id : 'N/A' }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right" style="width:140px">Platform Type:</td>
                <td class="px-2 font-weight-bold">{{ platformTypesMap.get(selectedDeployment.properties.platform_type).label }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Recorder Type:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.properties.instrument_type ? selectedDeployment.properties.instrument_type : 'N/A' }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Sampling Rate:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.properties.sampling_rate_hz ? (selectedDeployment.properties.sampling_rate_hz / 1000).toLocaleString() + ' kHz' : 'N/A' }}</td>
              </tr>
              <tr v-if="!theme.deploymentsOnly">
                <td class="px-2 text-right">Detection Method:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.properties.detection_method ? selectedDeployment.properties.detection_method : 'N/A' }}</td>
              </tr>
              <tr v-if="!theme.deploymentsOnly">
                <td class="px-2 text-right">QAQC:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.properties.qc_data ? selectedDeployment.properties.qc_data : 'N/A'}}</td>
              </tr>
              <tr v-if="deploymentType === 'station'">
                <td class="px-2 text-right">Recorder Depth:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.properties.recorder_depth_meters ? `${(+selectedDeployment.properties.recorder_depth_meters).toFixed(0)} m` : 'N/A' }}</td>
              </tr>
              <tr v-if="deploymentType === 'station'">
                <td class="px-2 text-right">Water Depth: </td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.properties.water_depth_meters ? `${(+selectedDeployment.properties.water_depth_meters).toFixed(0)} m` : 'N/A' }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Deployed:</td>
                <td class="px-2 font-weight-bold">{{ monitoringPeriod.start || 'N/A' }} to {{ monitoringPeriod.end || 'present' }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Duration:</td>
                <td class="px-2 font-weight-bold">{{ isFinite(monitoringPeriod.duration) ? monitoringPeriod.duration.toLocaleString() + ' days' : 'N/A' }}</td>
              </tr>
              <tr>
                <td class="px-2 text-right">Point of Contact:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.properties.data_poc_name }} ({{ selectedDeployment.properties.data_poc_email }}), {{ selectedDeployment.properties.data_poc_affiliation }} </td>
              </tr>
              <tr v-if="!theme.deploymentsOnly">
                <td class="px-2 text-right">Protocol:</td>
                <td class="px-2 font-weight-bold">{{ selectedDeployment.properties.protocol_reference }}</td>
              </tr>
            </tbody>
          </v-simple-table>
        </v-col>

        <v-col xs="12" md="12" lg="12" xl="8" v-if="!theme.deploymentsOnly">
          <div class="heading font-weight-bold">Daily Detections</div>
          <div class="subtitle-2 grey--text">Includes all detection data independent of filters</div>
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
import { detectionTypes, detectionTypesMap, platformTypes } from '@/lib/constants'
import { monitoringPeriodLabels } from '@/lib/tip'

const platformTypesMap = new Map(platformTypes.map(d => [d.id, d]))

export default {
  name: 'DeploymentDetail',
  data () {
    return {
      platformTypesMap,
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
    selectedDeployment () {
      return this.selectedDeployments.length > 0
        ? this.selectedDeployments[this.index]
        : null
    },
    deploymentType () {
      if (this.selectedDeployment.properties.platform_type === 'mooring' || this.selectedDeployment.properties.platform_type === 'buoy') {
        return 'station'
      } else if (this.selectedDeployment.properties.platform_type === 'slocum' || this.selectedDeployment.properties.platform_type === 'wave') {
        return 'glider'
      } else if (this.selectedDeployment.properties.platform_type === 'towed') {
        return 'towed'
      }
      return 'unknown'
    },
    monitoringPeriod () {
      return monitoringPeriodLabels(this.selectedDeployment.properties)
    }
  },
  watch: {
    selectedDeployments () {
      this.index = 0
    },
    selectedDeployment () {
      this.updateChart()
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
      const detections = xf.all().filter(d => d.id === this.selectedDeployment.id)
      const ids = detectionTypes.map(d => d.id)
      const values = detections.map((d) => {
        if (!d.presence) {
          return null
        }
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
      this.chart.xAxis.min = moment
        .utc(this.selectedDeployment.properties.analysis_start_date)
        .startOf('date').toDate().valueOf()
      this.chart.xAxis.max = moment
        .utc(this.selectedDeployment.properties.analysis_end_date)
        .startOf('date').toDate().valueOf()
      this.chart.series = [{
        name: 'Detection',
        data: values
      }]
    }
  }
}
</script>

<style>
</style>
