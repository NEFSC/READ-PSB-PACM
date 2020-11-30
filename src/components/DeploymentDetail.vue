<template>
  <div>
    <v-toolbar color="grey darken-2" dense dark>
      <div class="subtitle-1 font-weight-bold">Selected: {{ selectedDeployment.id }}</div>
      <v-spacer></v-spacer>
      <v-btn icon small @click="close">
        <v-icon small>mdi-close</v-icon>
      </v-btn>
    </v-toolbar>
    <div style="max-height:420px;overflow-y:auto;overflow-x:hidden">
      <v-row class="px-4">
        <v-col xs="12" md="12" lg="12" xl="4">
          <div :style="{ 'max-height': $vuetify.breakpoint.lgAndUp ? '420px' : null, 'overflow-y': 'auto' }">
            <v-simple-table dense>
              <template>
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
                  <tr v-if="!theme.deploymentsOnly">
                    <td class="px-2 text-right">Detection Method:</td>
                    <td class="px-2 font-weight-bold">{{ selectedDeployment.properties.detection_method }}</td>
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
                    <td class="px-2 font-weight-bold">{{ monitoringPeriod.start }} to {{ monitoringPeriod.end }}</td>
                  </tr>
                  <tr>
                    <td class="px-2 text-right">Duration:</td>
                    <td class="px-2 font-weight-bold">{{ monitoringPeriod.duration.toLocaleString() }} days</td>
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
              </template>
            </v-simple-table>
          </div>
        </v-col>

        <v-col xs="12" md="12" lg="12" xl="8" v-if="!theme.deploymentsOnly">
          <div class="heading font-weight-bold">Daily Detections</div>
          <div class="subtitle-2 grey--text">Includes all detection data independent of filters</div>
          <highcharts class="chart" :options="chart"></highcharts>
        </v-col>
      </v-row>
    </div>
  </div>
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
          categories: detectionTypes.map(d => d.label),
          reversed: true,
          min: 0,
          max: detectionTypes.length - 1,
          labels: {
            step: 1
          }
        },
        series: []
      }
    }
  },
  computed: {
    ...mapGetters(['selectedDeployment', 'theme']),
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
    selectedDeployment () {
      this.updateChart()
    }
  },
  mounted () {
    this.updateChart()
  },
  methods: {
    ...mapActions(['selectDeployment']),
    close () {
      this.selectDeployment()
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
          x: d.date.valueOf(),
          y: ids.indexOf(d.presence),
          label: status.label,
          marker: {
            fillColor: status.color
          }
        }
      })
      this.chart.xAxis.min = moment.utc(this.selectedDeployment.properties.monitoring_start_datetime).startOf('date').toDate().valueOf()
      this.chart.xAxis.max = moment.utc(this.selectedDeployment.properties.monitoring_end_datetime).startOf('date').toDate().valueOf()
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
