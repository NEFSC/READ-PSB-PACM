<template>
  <div>
    <v-toolbar color="grey darken-2" dense dark>
      <div class="subtitle-1 font-weight-bold">Project: {{ deployment.project }}</div>
      <v-spacer></v-spacer>
      <v-btn icon small @click="$emit('close')">
        <v-icon small>mdi-close</v-icon>
      </v-btn>
    </v-toolbar>
    <v-row class="px-4">
      <v-col lg="3">
        <span v-if="!isGlider">Site: <span class="font-weight-bold">{{ deployment.site_id ? deployment.site_id : 'N/A' }}</span><br></span>
        Platform: <span class="font-weight-bold">{{ platformTypesMap.get(deployment.platform_type).label }}</span><br>
        Unit: <span class="font-weight-bold">{{ deployment.instrument_type }}</span><br>
        <span v-if="!isGlider">Position: <span class="font-weight-bold">{{ deployment.latitude.toFixed(4) }}, {{ deployment.longitude.toFixed(4) }}</span><br></span>
        Deployed: <span class="font-weight-bold">{{ startDate.format('ll') }} to {{ endDate.format('ll') }}</span><br>
        Duration: <span class="font-weight-bold">{{ (duration.asDays() + 1).toLocaleString() }} days</span>
      </v-col>
      <v-col lg="9">
        <highcharts class="chart" :options="chart"></highcharts>
      </v-col>
    </v-row>
  </div>
</template>

<script>
import moment from 'moment'

import { detectionTypes, detectionTypesMap, platformTypesMap } from '@/lib/constants'

export default {
  name: 'DeploymentDetail',
  props: ['selected'],
  data () {
    return {
      platformTypesMap,
      detectionTypesMap,
      chart: {
        chart: {
          type: 'scatter',
          zoomType: 'x',
          height: 200,
          marginRight: 50,
          marginLeft: 70
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
            hour: '%A, %b %e, %Y',
            minute: '%A, %b %e, %Y'
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
          max: detectionTypes.length - 1,
          labels: {
            step: 1
          }
        },
        series: [{
          name: 'Detection',
          data: [
            {
              x: 1402272000000,
              y: 1
            }
          ]
        }]
      }
    }
  },
  computed: {
    deployment () {
      return this.selected.deployment
    },
    detections () {
      return this.selected.detections
    },
    startDate () {
      return moment.utc(this.deployment.monitoring_start_datetime).startOf('date')
    },
    endDate () {
      return moment.utc(this.deployment.monitoring_end_datetime).startOf('date')
    },
    duration () {
      return moment.duration(this.endDate.diff(this.startDate))
    },
    isGlider () {
      return this.deployment.platform_type === 'slocum' || this.deployment.platform_type === 'towed_array'
    }
  },
  watch: {
    detections () {
      this.updateChart()
    }
  },
  mounted () {
    this.updateChart()
  },
  methods: {
    updateChart () {
      const ids = detectionTypes.map(d => d.id)
      const values = this.detections.map((d) => {
        if (!d.detection) {
          return null
        }
        const status = detectionTypes.find(s => s.id === d.detection)
        return {
          x: d.date.valueOf(),
          y: ids.indexOf(d.detection),
          label: status.label,
          marker: {
            fillColor: status.color
          }
        }
      })
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
