import 'vuetify/styles'
import '@mdi/font/css/materialdesignicons.css'
import { createVuetify } from 'vuetify'
import { aliases, mdi } from 'vuetify/iconsets/mdi'
import { h } from 'vue'

import WhaleIcon from '@/components/WhaleIcon.vue'

const customIcons = {
  whale: WhaleIcon
}

const custom = {
  component: (props) =>
    h(props.tag, [h(customIcons[props.icon], { class: 'v-icon__svg' })]),
}

export default createVuetify({
  icons: {
    defaultSet: 'mdi',
    aliases,
    sets: {
      mdi,
      custom
    }
  }
})
