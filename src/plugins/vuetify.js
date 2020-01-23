import Vue from 'vue'
import Vuetify from 'vuetify/lib'

import WhaleIcon from '@/components/WhaleIcon'

Vue.use(Vuetify)

export default new Vuetify({
  icons: {
    iconfont: 'mdi',
    values: {
      whale: {
        component: WhaleIcon
      }
    }
  }
})
