import HighchartsVue from 'highcharts-vue'
import Highcharts from 'highcharts'
import more from 'highcharts/highcharts-more'

more(Highcharts)

Highcharts.setOptions({
  lang: {
    thousandsSep: ','
  }
})

export default HighchartsVue
