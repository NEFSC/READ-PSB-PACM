<template>
  <v-card>
    <div>
      <v-img src="@/assets/img/noaa-logo.gif" height="54px" width="54px" style="float:right" class="ma-2"></v-img>
      <v-list-item>
        <v-list-item-content>
          <v-list-item-title class="headline"><span v-if="!$vuetify.breakpoint.mobile">Welcome to the </span>Passive Acoustic Cetacean Map</v-list-item-title>
          <v-list-item-subtitle>by the <a href="https://www.nefsc.noaa.gov/psb/acoustics/index.html">NOAA Northeast Fisheries Science Center</a></v-list-item-subtitle>
        </v-list-item-content>
      </v-list-item>
      <v-img
        src="@/assets/img/whale.jpg"
        height="200px">
      </v-img>
    </div>
    <v-card-text class="mt-8 body-2 grey--text text--darken-4">
      <p class="font-weight-medium pb-0 body-1">
        The Passive Acoustic Cetacean Map (PACM) shows when and where specific whale, dolphin, and other cetacean species were acoustically detected in the North Atlantic Ocean based on Passive Acoustic Monitoring (PAM).
      </p>
      <v-container class="mb-6">
        <v-row justify="space-around">
          <v-col cols="12" md="4" class="text-center" v-if="!$vuetify.breakpoint.mobile">
            <v-btn color="success" class="px-8 mx-0" x-large @click="$emit('close', { tour: true })">
              <v-icon left>mdi-cursor-default-click</v-icon>
              Take A Tour
            </v-btn>
          </v-col>
          <v-col cols="12" md="4" class="text-center">
            <v-btn color="success" class="px-8 mx-0" x-large @click="$emit('close', { guide: true })">
              <v-icon left>mdi-book-open-variant</v-icon>
              User Guide
            </v-btn>
          </v-col>
          <v-col cols="12" md="4" class="text-center">
            <v-btn color="success" class="px-8 mx-0" x-large @click="$emit('close')">
              <v-icon left>mdi-play-circle</v-icon>
              Get Started
            </v-btn>
          </v-col>
        </v-row>
      </v-container>
      <p>
        PACM was designed for exploring the spatial and temporal patterns of PAM-based acoustic detection data of cetacean species. A series of interactive data visualization tools can be used to view detections over different seasons, years, and areas. Click the Tour button for a walk-through of how to use this site or see the User Guide for a video tutorial.
      </p>
      <p>
        Species that are currently represented include the North Atlantic right whale, fin whale, humpback whale, sei whale, blue whale, sperm whale, beaked whale species, and Kogia species (dwarf/pygmy sperm whales). The specific call types used for each species along with other metadata related to the recording and detection analysis can be found by hovering over or clicking on each platform.
      </p>
      <p>
        Acoustic detections were recorded using stationary (bottom-mounted moorings, surface buoys) and mobile (autonomous gliders and towed arrays) platforms. Stationary platforms are represented using circles with varying sizes that represent the number of days with definite or possible acoustic detections at a fixed location. Mobile platforms are represented using track lines with squares indicating the specific locations where each detection was observed (for gliders, only the first detection of each day is shown). See the User Guide for more information about the map symbology and descriptions of different types of PAM platforms.
      </p>
      <p>
        These acoustic detections only represent times when animals are calling; they do not capture time periods when animals are present but silent.
      </p>
      <p>
        The dataset was compiled by the NOAA NEFSC Passive Acoustic Research Program using detection data collected by many collaborators. Information on data ownership can be found in the metadata of each station or platform.
      </p>
      <p>
        When using or referencing this data, please cite as:
      </p>
      <p class="font-weight-bold ml-4 grey--text text--darken-2">
        Passive Acoustic Cetacean Map. 2021. Woods Hole (MA): NOAA Northeast Fisheries Science Center [accessed date]. https://walkerenvres.com/projects/nefsc/pam/
      </p>
      <!-- TODO: UPDATE URL -->
      <p>
        For questions about contributing data to this project or any other inquiries, please contact <a href="mailto:nmfs.pacmdata@noaa.gov">nmfs.pacmdata@noaa.gov</a>.
      </p>
      <p>
        Further information about Passive Acoustic Monitoring can be found at the <a href="https://www.fisheries.noaa.gov/new-england-mid-atlantic/endangered-species-conservation/passive-acoustic-research-atlantic-ocean" target="_blank">NOAA NEFSC Passive Acoustic Research Website</a>
      </p>
      <p>
        PACM was designed and built by <a href="https://walkerenvres.com" target="_blank">Walker Environmental Research LLC</a> based on a map-based interface for PAM acoustic detection data developed by Hansen Johnson (Dalhousie University).
      </p>
    </v-card-text>
    <v-card-actions>
      <v-spacer></v-spacer>
      <v-btn color="primary" text @click.native="$emit('close')">Close</v-btn>
    </v-card-actions>
  </v-card>
</template>

<script>
export default {
  name: 'About'
}
</script>