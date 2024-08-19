<template>
  <v-card role="main" aria-label="about page">
    <div>
      <v-img
        src="@/assets/img/noaa-logo.gif"
        height="54px"
        width="54px"
        style="float:right"
        class="ma-2"
        alt="NOAA Logo">
      </v-img>
      <v-list-item>
        <v-list-item-content>
          <v-list-item-title><h1 class="headline"><span v-if="!$vuetify.breakpoint.mobile">Welcome to the </span>Passive Acoustic Cetacean Map</h1></v-list-item-title>
          <v-list-item-subtitle>by the <a href="https://www.nefsc.noaa.gov/psb/acoustics/index.html">NOAA Northeast Fisheries Science Center</a></v-list-item-subtitle>
        </v-list-item-content>
      </v-list-item>
      <v-img
        src="@/assets/img/whale.jpg"
        height="200px"
        alt="Whale Photo">
      </v-img>
    </div>
    <v-card-text class="mt-8 body-2 grey--text text--darken-4">
      <p class="font-weight-medium pb-0 body-1">
        The Passive Acoustic Cetacean Map (PACM) shows when and where specific whale, dolphin, and other cetacean species were acoustically detected in the North Atlantic Ocean based on Passive Acoustic Monitoring (PAM).
      </p>
      <v-container class="mb-6">
        <v-row justify="space-around">
          <v-col cols="12" md="4" class="text-center" v-if="!$vuetify.breakpoint.mobile">
            <v-btn color="success darken-2" class="px-8 mx-0" x-large @click="$emit('close', { tour: true })" aria-label="take a tour">
              <v-icon left>mdi-cursor-default-click</v-icon>
              Take A Tour
            </v-btn>
          </v-col>
          <v-col cols="12" md="4" class="text-center">
            <v-btn color="success darken-2" class="px-8 mx-0" x-large @click="$emit('close', { guide: true })" aria-label="user guide">
              <v-icon left>mdi-book-open-variant</v-icon>
              User Guide
            </v-btn>
          </v-col>
          <v-col cols="12" md="4" class="text-center">
            <v-btn color="success darken-2" class="px-8 mx-0" x-large @click="$emit('close')" aria-label="get started">
              <v-icon left>mdi-play-circle</v-icon>
              Get Started
            </v-btn>
          </v-col>
        </v-row>
      </v-container>

      <h2 class="text-h5">About PACM</h2>
      <p>
        PACM was designed for exploring the spatial and temporal patterns of PAM-based acoustic detection data of cetacean species. A series of interactive data visualization tools can be used to view detections over different seasons, years, and areas. Click the Tour button for a walk-through of how to use this site or see the User Guide for a video tutorial.
      </p>

      <h2 class="text-h5">Acoustic Recorders and Detections</h2>
      <p>
        Species that are currently represented include the North Atlantic right whale, fin whale, humpback whale, sei whale, blue whale, sperm whale, harbor porpoise, beaked whale species, Kogia species (dwarf/pygmy sperm whales), and dolphins (Risso's and unidentified). The specific call types used for each species along with other metadata related to the recording and detection analysis can be found by hovering over or clicking on each platform.
      </p>
      <p>
        Acoustic detections were recorded using stationary (bottom-mounted moorings, surface buoys) and mobile (autonomous gliders and towed arrays) platforms. Stationary platforms are represented using circles with varying sizes that represent the number of days with definite or possible acoustic detections at a fixed location. Mobile platforms are represented using track lines with squares indicating the specific locations where each detection was observed (for gliders, only the first detection of each day is shown). See the User Guide for more information about the map symbology and descriptions of different types of PAM platforms.
      </p>
      <p>
        These acoustic detections only represent times when animals are calling; they do not capture time periods when animals are present but silent.  Detections are from archival acoustic recorders and do not show recorders currently in the water (this is not a real-time tool). Differences in recorder detection ranges for each species are not accounted for; they can vary based on differences in instrumentation (i.e. recording hardware), environmental conditions (i.e. weather, bottom type, ambient sound levels), and anthropogenic sound levels.
      </p>

      <h2 class="text-h5">Data Permissions and Contributions</h2>
      <p>
        The dataset was compiled by the NOAA NEFSC Passive Acoustic Research Program using detection data collected by many collaborators. Information on data ownership can be found in the metadata of each station or platform.
      </p>
      <p>
        When using or referencing this data, please cite as:
      </p>
      <p class="font-weight-bold ml-4 grey--text text--darken-2">
        <Citation></Citation>
      </p>
      <p>
        Data can be submitted by using the <a class="text-decoration-underline" href="https://www.fisheries.noaa.gov/resource/document/passive-acoustic-reporting-system-templates">Passive Acoustic Reporting System</a> templates. For questions about contributing data to this project or any other inquiries, please contact <a class="text-decoration-underline" href="mailto:nmfs.nec.pacmdata@noaa.gov">nmfs.nec.pacmdata@noaa.gov</a>.
      </p>
      <p>
        Further information about Passive Acoustic Monitoring can be found at the <a class="text-decoration-underline" href="https://www.fisheries.noaa.gov/new-england-mid-atlantic/endangered-species-conservation/passive-acoustic-research-atlantic-ocean" target="_blank">NOAA NEFSC Passive Acoustic Research Website</a>
      </p>
      <p>
        PACM was designed and built by Walker Environmental Research LLC based on a map-based interface for PAM acoustic detection data developed by Hansen Johnson (Dalhousie University).
      </p>

      <h2 class="text-h5 mb-2">Latest Updates</h2>

      <div class="text-subheading font-weight-bold text--secondary">
        v1.1.9 | Aug 1, 2024
      </div>
      <p>Fixed user-defined spatial filter when switching species. Added SWFSC-SAEL_20240814 dataset.</p>

      <div class="text-subheading font-weight-bold text--secondary">
        v1.1.8 | Mar 22, 2024
      </div>
      <p>Updated SEFSC datasets for Gulf of Mexico (corrected lat/lon coordinates for 2020-2021 datasets).</p>

      <div class="text-subheading font-weight-bold text--secondary">
        v1.1.7 | Mar 13, 2024
      </div>
      <p>Added and updated SEFSC datasets from Gulf of Mexico for Beaked Whales, Kogia, Sperm Whales, and Dolphins.</p>

      <div class="text-subheading font-weight-bold text--secondary">
        v1.1.6 | Sep 29, 2023
      </div>
      <p>Added FPOD datasets for Harbor Porpoise and Dolphins (Unidentified), and new Beaked Whale and Dolphin datasets from SEFSC.</p>

      <div class="text-subheading font-weight-bold text--secondary">
        v1.1.5 | Jul 20, 2023
      </div>
      <p>Added new DFO, JASCO, SEFSC datasets. Minor updates to About page and User Guide.</p>

      <div class="text-subheading font-weight-bold text--secondary">
        v1.1.4 | Mar 22, 2023
      </div>
      <p>Updated contact email address to <a class="text-decoration-underline" href="mailto:nmfs.nec.pacmdata@noaa.gov">nmfs.nec.pacmdata@noaa.gov</a>. Fixed ESRI Ocean basemap.</p>

      <div class="text-subheading font-weight-bold text--secondary">
        v1.1.3 | Nov 17, 2022
      </div>
      <p>Added nautical charts basemap, updated baleen whale datasets and active deployments.</p>

      <div class="text-subheading font-weight-bold text--secondary">
        v1.1.2 | Apr 1, 2022
      </div>
      <p>Added wind energy areas layer to map overlays, latest updates to about. Updated NYSDEC baleen whale data.</p>

      <div class="text-subheading font-weight-bold text--secondary">
        v1.1.1 | Mar 16, 2022
      </div>
      <p>Fixed bug when selecting deployments by bounding box.</p>

      <div class="text-subheading font-weight-bold text--secondary">
        v1.1.0 | Mar 7, 2022
      </div>
      <p>
        Added advanced filters, map overlays with Lobster Management Areas layer, harbor porpoise to species list. Added/updated data from DFO, NYSDEC, NEFSC, Cornell Univ.
      </p>

      <div class="text-subheading font-weight-bold text--secondary">
        v1.0.0 | May 27, 2021
      </div>
      <p class="mb-0">Initial release.</p>
    </v-card-text>
    <v-card-actions>
      <v-spacer></v-spacer>
      <v-btn color="primary" text @click.native="$emit('close')" aria-label="close">Close</v-btn>
    </v-card-actions>
  </v-card>
</template>

<script>
import Citation from '@/components/Citation'
export default {
  name: 'About',
  components: {
    Citation
  },
  data () {
    return {
      version: process.env.PACKAGE_VERSION
    }
  }
}
</script>
