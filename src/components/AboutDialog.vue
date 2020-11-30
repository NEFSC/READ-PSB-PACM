<template>
  <v-card>
    <div>
      <v-img src="../assets/img/noaa-logo.gif" height="54px" width="54px" style="float:right" class="ma-2"></v-img>
      <v-list-item>
        <v-list-item-content>
          <v-list-item-title class="headline">Welcome to the Passive Acoustic Cetacean Map</v-list-item-title>
          <v-list-item-subtitle>by the <a href="https://www.nefsc.noaa.gov/psb/acoustics/index.html">NOAA Northeast Fisheries Science Center</a></v-list-item-subtitle>
        </v-list-item-content>
      </v-list-item>
      <v-img
        src="../assets/img/whale.jpg"
        height="200px">
      </v-img>
    </div>
    <v-card-text class="mt-8 body-1 grey--text text--darken-4">
      <p class="font-weight-medium">
        The Passive Acoustic Cetacean Map (PACM) shows when and where specific cetacean species were acoustically detected in the Atlantic Ocean based on Passive Acoustic Monitoring (PAM).
      </p>
      <v-card-actions class="justify-space-around my-8">
        <v-btn color="success" class="px-4 mx-0" x-large @click="$emit('close', { tour: true })">
          <v-icon left>mdi-cursor-default-click</v-icon>
          Take A Tour
        </v-btn>
        <v-btn color="success" class="px-4 mx-0" x-large @click="$emit('close', { tutorial: true })">
          <v-icon left>mdi-video</v-icon>
          Watch Tutorial
        </v-btn>
        <v-btn color="success" class="px-4 mx-0" x-large @click="$emit('close')">
          <v-icon left>mdi-play-circle</v-icon>
          Get Started
        </v-btn>
      </v-card-actions>
      <p>
        This application provides interactive data visualization tools for exploring PAM-based cetacean acoustic detection data. This application works best in Google Chrome. Click the Help button for a tour of how to use the site.
      </p>
      <p>
        Species that are currently represented are the North Atlantic right whale, fin whale, humpback whale, sei whale, blue whale, beaked whales and Kogia species (dwarf/pygmy sperm whales). Acoustic detections of specific call types are reported here and information on which call type was detected can be found in the metadata.
      </p>
      <p>
        Acoustic detections were made either from bottom mounted recorders, surface buoy recorders, autonomous gliders or towed arrays. Bottom mounted and surface buoys are moored and represent acoustic detections from a fixed location. Gliders and towed arrays are mobile and detections are represented along track lines. The data have the capacity to be normalized by the number of recording days for all stationary recorders.
      </p>
      <p>
        The dataset was compiled by the NOAA NEFSC Passive Acoustic Research Program using detections collected from many collaborators. Information on data ownership can be found in the metadata. This map is an expansion of one created for us by Hansen Johnson.
      </p>
      <p>
        Further information can be found at <a href="https://www.fisheries.noaa.gov/new-england-mid-atlantic/endangered-species-conservation/passive-acoustic-research-atlantic-ocean" target="_blank">https://www.fisheries.noaa.gov/new-england-mid-atlantic/endangered-species-conservation/passive-acoustic-research-atlantic-ocean</a>
      </p>
      <p>Application designed and built by <a href="https://walkerenvres.com" target="_blank">Walker Environmental Research LLC</a>.</p>
    </v-card-text>
    <v-card-actions>
      <v-spacer></v-spacer>
      <v-btn color="primary" text @click.native="$emit('close')">Close</v-btn>
    </v-card-actions>
  </v-card>
</template>

<script>
export default {
  name: 'AboutDialog'
}
</script>

<style>

</style>
