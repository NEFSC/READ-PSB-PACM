<template>
  <v-card role="main" aria-label="about page">
    <v-card-title class="d-flex flex-wrap align-center pl-0">
      <div class="px-2">
        <a href="https://passiveacoustics.fisheries.noaa.gov">
          <v-img
            src="@/assets/img/noaa-logo.gif"
            height="54px"
            width="54px"
            alt="NOAA Logo">
          </v-img>
        </a>
      </div>
      <div>
        <h1 class="text-h5"><span v-if="!$vuetify.display.mobile">Welcome to the </span>Passive Acoustic Cetacean Map</h1>
        <div class="text-caption">by the <a href="https://www.fisheries.noaa.gov/new-england-mid-atlantic/endangered-species-conservation/passive-acoustic-research-northeast">NOAA Fisheries | Northeast Fisheries Science Center</a></div>
      </div>
      <v-spacer></v-spacer>
      <v-tooltip open-delay="500" location="bottom">
        <template v-slot:activator="{ props }">
          <v-btn icon="mdi-close" variant="text" size="small" @click="$emit('close')" v-bind="props" aria-label="close"></v-btn>
        </template>
        <span>Close</span>
      </v-tooltip>
    </v-card-title>
    <v-img
      src="@/assets/img/whale.jpg"
      height="200px"
      alt="Whale Photo"
      cover>
    </v-img>
    <v-card-text class="text-body-2 text-grey-darken-4">
      <p class="font-weight-medium text-body-1">
        The Passive Acoustic Cetacean Map (PACM) is an interactive data visualization tool for exploring when and where specific whale, dolphin, and other cetacean species were detected using Passive Acoustic Monitoring (PAM) technologies.
      </p>
      <v-container class="my-4">
        <v-row justify="space-around">
          <v-col cols="12" md="4" class="text-center">
            <v-btn
              color="secondary"
              class="px-8"
              size="x-large"
              aria-label="take a tour"
              :disabled="$vuetify.display.mobile"
              @click="$emit('close', { tour: true })"
            >
              <v-icon start>mdi-cursor-default-click</v-icon>
              Take A Tour
            </v-btn>
            <div class="text-caption" v-if="$vuetify.display.mobile">Tour not available on mobile devices, see User Guide.</div>
          </v-col>
          <v-col cols="12" md="4" class="text-center">
            <v-btn color="secondary" class="px-8" size="x-large" @click="$emit('close', { guide: true })" aria-label="user guide">
              <v-icon start>mdi-book-open-variant</v-icon>
              User Guide
            </v-btn>
          </v-col>
          <v-col cols="12" md="4" class="text-center">
            <v-btn color="secondary" class="px-8" size="x-large" @click="$emit('close')" aria-label="get started">
              <v-icon start>mdi-play-circle</v-icon>
              Get Started
            </v-btn>
          </v-col>
        </v-row>
      </v-container>

      <p>
        More information about Passive Acoustic Monitoring and how it works can be found at the <a class="text-decoration-underline" href="https://www.fisheries.noaa.gov/new-england-mid-atlantic/endangered-species-conservation/passive-acoustic-research-northeast" target="_blank">NOAA NEFSC Passive Acoustic Research website</a>
      </p>

      <h2 class="text-h6">Data Attributions and Citations</h2>
      <p>
        PACM displays PAM datasets contributed from a wide range of government agencies, research institutions, industry partners, and other organizations. PAM data collected by NOAA Fisheries, across its various branches and science centers, are obtained from an internal passive acoustics database (Makara) accessible only within NOAA. All datasets contributed by agencies and organizations outside NOAA are obtained from the <a class="text-decoration-underline" href="https://passiveacoustics.fisheries.noaa.gov/pars/">Passive Acoustic Reporting System (PARS)</a>.
      </p>
      <p>
        PACM dynamically lists all data contributors based on which datasets are currently visible on the map. Click the "Generate Citations" button for more information and to get a list of citations for all currently visible datasets, which can be copied and pasted into reports, publications, presentations, or other documents.
      </p>
      <p>
        When using or referencing PACM, please use the following citation and be sure to also include the list of data contributor citations created by the "Generate Citations" button:
      </p>
      <p class="font-weight-bold ml-4 text-grey-darken-2">
        <Citation></Citation>
      </p>

      <h2 class="text-h6 mb-2">Contributing Data to PACM</h2>
      <p>
        Data can be submitted for display on PACM by any organization who uses standard scientific protocols to collect and analyze PAM data through the <a class="text-decoration-underline" href="https://passiveacoustics.fisheries.noaa.gov/pars/">Passive Acoustic Reporting System</a>. NOAA scientists and staff can also contribute data to PACM using the internal (NOAA-only) Makara passive acoustics database.
      </p>


      <h2 class="text-h6 mb-2">Accessing Data in PACM</h2>
      <p>
        Although PACM does not support direct data downloads, a copy of any data shown on PACM can be requested through the <a href="https://www.narwc.org/accessing-narwc-data.html">North Atlantic Right Whale Consortion (NARWC) Data Access Request Form</a>. Data requests must include a clear description of the specific data being requested (e.g., species, location, time period) and along with a brief proposal explaining the intended use of the data. Data requests are reviewed by the NARWC Board members and may be subject to additional data sharing agreements or requirements depending on the specific datasets being requested and the intended use of the data.
      </p>

      <h2 class="text-h6 mb-2">Contact Us</h2>
      <p>
        For any questions or comments about PACM, please contact <a class="text-decoration-underline" href="mailto:passive.acoustics@noaa.gov">passive.acoustics@noaa.gov</a>.
      </p>

      <h2 class="text-h6 mb-2">About the Project</h2>
      <p>
        PACM was created by the NOAA NEFSC Passive Acoustic Branch to facilitate collaborative research and management of marine species using PAM detection data. PACM was designed and built by Walker Environmental Research based on a map-based interface for PAM acoustic detection data developed by Hansen Johnson (Dalhousie University).
      </p>

      <h2 class="text-h6 mb-2">Latest Updates</h2>

      <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
        v1.3.3 | June 3, 2026
      </div>
      <div class="mt-2">Features:</div>
      <ul class="ml-4">
        <li>Added dynamic attribution list of data contributors to map and Generate Citations button.</li>
        <li>Updated about text in this welcome dialog and clarified submission, data request, and citation processes.</li>
      </ul>
      <div class="mt-2">
        Bug Fixes:
      </div>
      <ul class="ml-4">
        <li>Data processing pipeline had previously excluded some datasets from Makara erroneously, those datasets have been added back.</li>
        <li>Fixed minor bug fix in legend to correctly display the total recorded day tallies when switching species.</li>
      </ul>

      <div class="text-subtitle-1 font-weight-bold text-medium-emphasis mt-4">
        v1.3.2 | May 14, 2026
      </div>
      <p>Improved global map display so platform data repeats across wrapped world views when zoomed out.</p>

      <v-btn
        color="primary"
        variant="text"
        class="px-0 mb-4"
        :aria-expanded="showAllUpdates.toString()"
        aria-controls="about-update-history"
        @click="showAllUpdates = !showAllUpdates"
      >
        <v-icon start>{{ showAllUpdates ? 'mdi-chevron-up' : 'mdi-chevron-down' }}</v-icon>
        {{ showAllUpdates ? 'Show Less' : 'Show More' }}
      </v-btn>

      <div v-show="showAllUpdates" id="about-update-history">
        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.3.1 | May 11, 2026
        </div>
        <p>Added PIFSC detection datasets, and updated list of available species.</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.3.0 | Apr 29, 2026
        </div>
        <p>Upgraded application frameworks and libraries to latest versions.</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.2.1 | Apr 7, 2026
        </div>
        <p>Added Dynamic Management Platform filter to Advanced Filters. Added Bryde's Whale, Bottlenose Dolphin, Harbor Porpoise, and Killer Whale to species list. Added new NWFSC datasets and updated real-time detection data from NEFSC.</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.2.0 | Mar 16, 2026
        </div>
        <p>Major dataset updates from PARS submissions and Makara database. Deployments at the same site are now aggregated into a single site-level result. Seasonal filter now trims partial seasons when Start DOY > End DOY. Multi-species datasets (e.g., Beaked Whales) now aggregate detections across species by date to avoid double counting.</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.1.11 | Apr 1, 2025
        </div>
        <p>Minor updates to About and User Guide pages.</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.1.10 | Aug 21, 2024
        </div>
        <p>Added Gray Whale, Minke Whale, Pacific White-sided Dolphin. Re-labelled "Cuvier's Beaked Whale" to "Goose-beaked Whale." Added Unid. Mesoplodon (Beaked Whale Species) from SWFSC-SAEL_20240814.</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.1.9 | Aug 19, 2024
        </div>
        <p>Fixed user-defined spatial filter when switching species. Added SWFSC-SAEL_20240814 dataset.</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.1.8 | Mar 22, 2024
        </div>
        <p>Updated SEFSC datasets for Gulf of Mexico (corrected lat/lon coordinates for 2020-2021 datasets).</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.1.7 | Mar 13, 2024
        </div>
        <p>Added and updated SEFSC datasets from Gulf of Mexico for Beaked Whales, Kogia, Sperm Whales, and Dolphins.</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.1.6 | Sep 29, 2023
        </div>
        <p>Added FPOD datasets for Harbor Porpoise and Dolphins (Unidentified), and new Beaked Whale and Dolphin datasets from SEFSC.</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.1.5 | Jul 20, 2023
        </div>
        <p>Added new DFO, JASCO, SEFSC datasets. Minor updates to About page and User Guide.</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.1.4 | Mar 22, 2023
        </div>
        <p>Updated contact email address to <a class="text-decoration-underline" href="mailto:passive.acoustics@noaa.gov">passive.acoustics@noaa.gov</a>. Fixed ESRI Ocean basemap.</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.1.3 | Nov 17, 2022
        </div>
        <p>Added nautical charts basemap, updated baleen whale datasets and active deployments.</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.1.2 | Apr 1, 2022
        </div>
        <p>Added wind energy areas layer to map overlays, latest updates to about. Updated NYSDEC baleen whale data.</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.1.1 | Mar 16, 2022
        </div>
        <p>Fixed bug when selecting deployments by bounding box.</p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.1.0 | Mar 7, 2022
        </div>
        <p>
          Added advanced filters, map overlays with Lobster Management Areas layer, harbor porpoise to species list. Added/updated data from DFO, NYSDEC, NEFSC, Cornell Univ.
        </p>

        <div class="text-subtitle-1 font-weight-bold text-medium-emphasis">
          v1.0.0 | May 27, 2021
        </div>
        <p class="mb-0">Initial release.</p>
      </div>
    </v-card-text>
    <v-divider></v-divider>
    <v-card-actions>
      <v-spacer></v-spacer>
      <v-btn color="primary" variant="text" @click="$emit('close')" aria-label="close">Close</v-btn>
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
      version: process.env.PACKAGE_VERSION,
      showAllUpdates: false
    }
  }
}
</script>

<style scoped>
p {
  margin-bottom: 1em;
}
</style>
