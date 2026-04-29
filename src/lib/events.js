const handlers = new Map()

const evt = {
  $on (name, handler) {
    if (!handlers.has(name)) handlers.set(name, new Set())
    handlers.get(name).add(handler)
  },
  $off (name, handler) {
    if (!handler) {
      handlers.delete(name)
      return
    }
    handlers.get(name)?.delete(handler)
  },
  $emit (name, ...args) {
    handlers.get(name)?.forEach(handler => handler(...args))
  }
}

export default evt
