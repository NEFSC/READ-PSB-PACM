import Vue from 'vue'

const evt = new Vue()

// if (process.env.NODE_ENV === 'development') {
//   const events = [
//     'render:map',
//     'render:filter',
//     'reset:filters',
//     'map:zoom',
//     'map:move',
//     'xf:filtered'
//   ]
//   events.forEach(e => evt.$on(e, (msg) => console.log(`evt(${e}) ${msg}`)))
// }

export default evt
