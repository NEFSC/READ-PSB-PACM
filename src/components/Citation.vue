<template>
  <span>
    Passive Acoustic Cetacean Map. {{ year }}. Woods Hole (MA): NOAA Northeast Fisheries Science Center v{{ version }} [accessed date]. https://passiveacoustics.fisheries.noaa.gov/pacm/
  </span>
</template>

<script>
export default {
  name: 'Citation',
  data () {
    return {
      year: (new Date()).getYear() + 1900,
      version: process.env.PACKAGE_VERSION || 'Unknown'
    }
  }
}
</script>
