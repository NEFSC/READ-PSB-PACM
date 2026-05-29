<template>
  <span>
    Passive Acoustic Cetacean Map (PACM). 2026. Woods Hole (MA): NOAA Northeast Fisheries Science Center v{{ version }}. Accessed on {{ accessedDate }}. https://passiveacoustics.fisheries.noaa.gov/pacm/
  </span>
</template>

<script>
export default {
  name: 'Citation',
  computed: {
    version () {
      return process.env.PACKAGE_VERSION || 'Unknown'
    },
    accessedDate () {
      return new Date().toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      })
    }
  }
}
</script>
