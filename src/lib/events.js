import Vue from 'vue'

const evt = new Vue()

if (process.env.NODE_ENV === 'development') {
  const events = [
    'render:map',
    'render:filter'
  ]
  events.forEach(e => evt.$on(e, (msg) => console.log(`${e} ${msg}`)))
}

export default evt
