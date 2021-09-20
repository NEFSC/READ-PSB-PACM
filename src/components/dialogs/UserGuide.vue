<template>
  <v-card>
    <v-card-title primary-title>
      User Guide
      <v-spacer></v-spacer>
      <v-tooltip open-delay="500" bottom>
        <template v-slot:activator="{ on }">
          <v-btn icon small @click.native="$emit('close')" v-on="on"><v-icon>mdi-close</v-icon></v-btn>
        </template>
        <span>Close</span>
      </v-tooltip>
    </v-card-title>

    <v-card-text class="mt-8">
      <v-tabs vertical>
        <v-tab class="justify-start">
          <v-icon left>
            mdi-video
          </v-icon>
          Video
        </v-tab>

        <v-tab class="justify-start">
          <v-icon left>
            mdi-map
          </v-icon>
          Map Key
        </v-tab>

        <v-tab class="justify-start">
          <v-icon left>
            mdi-microphone
          </v-icon>
          Platform Types
        </v-tab>

        <v-tab class="justify-start">
          <v-icon left>
            mdi-help-circle
          </v-icon>
          FAQ
        </v-tab>

        <v-tab class="justify-start">
          <v-icon left>
            mdi-pencil
          </v-icon>
          Citation
        </v-tab>

        <!-- VIDEO -->
        <v-tab-item>
          <v-card flat>
            <v-card-text class="body-1 black--text text-center">
              <p>
                To learn more about how to use PACM, please watch the following videos.<br>
                <span class="body-2 font-italic">(scroll down for Part 2 - Interactive Filtering)</span>
              </p>
              <iframe src='//players.brightcove.net/659677166001/4b3c8a9e-7bf7-43dd-b693-2614cc1ed6b7_default/index.html?videoId=6263997740001' allowfullscreen frameborder=0 width="800" height="450"></iframe>
              <iframe src='//players.brightcove.net/659677166001/4b3c8a9e-7bf7-43dd-b693-2614cc1ed6b7_default/index.html?videoId=6263997873001' allowfullscreen frameborder=0 width="800" height="450" class="mt-4"></iframe>
            </v-card-text>
          </v-card>
        </v-tab-item>

        <!-- MAP KEY -->
        <v-tab-item>
          <v-card flat>
            <v-card-text class="body-1 black--text">
              <div class="text-h5">Stationary Platforms (Bottom-Mounted Moorings and Surface Buoys)</div>
              <v-container fluid grid-list-xs>
                <v-row align="start">
                  <v-col cols="2">
                    <v-img
                      class="mt-2"
                      src="@/assets/img/guide/key/circle-red.png"
                      alt="Definite detection icon for stationary platforms (red circle)"
                      max-height="100px"
                      contain
                    ></v-img>
                  </v-col>
                  <v-col cols="10">
                    <div class="text-h6">Definite Acoustic Detection</div>
                    <p>A red circle indicates at least one day with a definite acoustic detection at a fixed location platform. The size is proportional to the number of days with at least one definite acoustic detection over the selected time period. Note that the size does not reflect the number of days with possible acoustic detections at this location, it only reflects definite acoustic detections.</p>
                  </v-col>
                </v-row>
                <v-row align="start">
                  <v-col cols="2">
                    <v-img
                      class="mt-2"
                      src="@/assets/img/guide/key/circle-green.png"
                      alt="Possible detection icon for stationary platforms (green circle)"
                      max-height="100px"
                      contain
                    ></v-img>
                  </v-col>
                  <v-col cols="10">
                    <div class="text-h6">Possible Acoustic Detection</div>
                    <p>A green circle indicates at least one day with a possible acoustic detection, but no definite acoustic detections. The size is proportional to the number of days with at least one possible acoustic detection.</p>
                  </v-col>
                </v-row>
                <v-row align="start">
                  <v-col cols="2">
                    <v-img
                      class="mt-2"
                      src="@/assets/img/guide/key/circle-blue.png"
                      alt="No detection icon for stationary platforms (blue circle)"
                      max-height="100px"
                      contain
                    ></v-img>
                  </v-col>
                  <v-col cols="10">
                    <div class="text-h6">No Acoustic Detection</div>
                    <p>A blue circle indicates that the species was not detected at this location.</p>
                  </v-col>
                </v-row>
                <v-row align="start">
                  <v-col cols="2">
                    <v-img
                      class="mt-2"
                      src="@/assets/img/guide/key/circle-gray.png"
                      alt="Not analyzed icon for stationary platforms (gray circle)"
                      max-height="100px"
                      contain
                    ></v-img>
                  </v-col>
                  <v-col cols="10">
                    <div class="text-h6">Not Analyzed</div>
                    <p>A gray circle indicates that none of the days within the selected time period have been analyzed yet at this platform.</p>
                  </v-col>
                </v-row>
                <v-row align="start">
                  <v-col cols="2">
                    <v-img
                      class="mt-2"
                      src="@/assets/img/guide/key/checkbox.png"
                      alt="Checkbox icon"
                      max-height="100px"
                      contain
                    ></v-img>
                  </v-col>
                  <v-col cols="10">
                    <div class="text-h6">Settings</div>
                    <p>
                      <span class="font-weight-bold">Normalize By Effort</span>: When checked, the size of each circle will represent the percent of all recorded days with at least one definite (or possible) detection. This is calculated by dividing the number of detection days by the total number of recorded days at each station.
                    </p>
                  </v-col>
                </v-row>
              </v-container>

              <v-divider class="my-8"></v-divider>

              <div class="text-h5">Mobile Platforms (Gliders and Towed Arrays)</div>
              <v-container fluid>
                <v-row align="start">
                  <v-col cols="2">
                    <v-img
                      class="mt-2"
                      src="@/assets/img/guide/key/square-red.png"
                      alt="Definite detection icon for mobile platforms (red square)"
                      max-height="100px"
                      contain
                    ></v-img>
                  </v-col>
                  <v-col cols="10">
                    <div class="text-h6">Definite Acoustic Detection</div>
                    <p>
                      A red square indicates the location of a definite acoustic detection using a mobile platform (glider or towed array).
                    </p>
                    <p>
                      For <em>gliders</em>, only the first definite acoustic detection of each day is shown on the map. Due to the large number of potential acoustic detections on any given day by a single glider, only one acoustic detection is shown to prevent overcrowding of red squares on the map.
                    </p>
                    <p>
                      For <em>towed arrays</em>, multiple squares will be shown if there were more than one definite acoustic detections on any given day.
                    </p>
                  </v-col>
                </v-row>
                <v-row align="start">
                  <v-col cols="2">
                    <v-img
                      class="mt-2"
                      src="@/assets/img/guide/key/square-green.png"
                      alt="Possible detection icon for mobile platforms (green square)"
                      max-height="100px"
                      contain
                    ></v-img>
                  </v-col>
                  <v-col cols="10">
                    <div class="text-h6">Possible Acoustic Detection</div>
                    <p>
                      A green square indicates a possible acoustic detection using a mobile platform. At the moment, possible acoustic detections are only shown for gliders, and not towed arrays.
                    </p>
                  </v-col>
                </v-row>
                <v-row align="start">
                  <v-col cols="2">
                    <v-img
                      class="mt-2"
                      src="@/assets/img/guide/key/line-solid.png"
                      alt="Glider/Ship track symbol for mobile platforms (solid gray line)"
                      max-height="100px"
                      contain
                    ></v-img>
                  </v-col>
                  <v-col cols="10">
                    <div class="text-h6">Glider/Ship Track</div>
                    <p>
                      A solid line indicates the tracked position of a mobile platform (glider or towed array) for which the acoustic data has been analyzed. For towed arrays, the ship track is only shown on days when the array was deployed and acoustic data were recorded (i.e., the track excludes movements when the ship returns to port).
                    </p>
                  </v-col>
                </v-row>
                <v-row align="start">
                  <v-col cols="2">
                    <v-img
                      class="mt-2"
                      src="@/assets/img/guide/key/line-dashed.png"
                      alt="Unanalyzed glider/ship track for mobile platforms (dashed gray line)"
                      max-height="100px"
                      contain
                    ></v-img>
                  </v-col>
                  <v-col cols="10">
                    <div class="text-h6">Unanalyzed Glider/Ship Track</div>
                    <p>
                      A dashed line denotes gliders or towed array cruises for which the acoustic data have not yet been analyzed.
                    </p>
                  </v-col>
                </v-row>
              </v-container>

              <v-divider class="my-8"></v-divider>

              <div class="text-h5">Metadata</div>
              <v-container fluid class="pb-0">
                <v-row align="start">
                  <v-col cols="6">
                    <v-img
                      class="mt-1"
                      src="@/assets/img/guide/key/tooltip.png"
                      alt="Metadata tooltip box"
                      max-height="400px"
                      contain
                    ></v-img>
                  </v-col>
                  <v-col cols="6">
                    <p>
                      Hovering your mouse over a point or line on the map will provide a summary of the corresponding passive acoustic deployment. This summary includes the primary metadata for that deployment followed by a summary table listing the number of days in each detection category.
                    </p>
                    <p>
                      The summary table includes all days with recorded data, as well as only those days within the time period selected using the seasonal and annual filters.
                    </p>
                    <p>
                      At the bottom of the tooltip, a notification will alert you if there are multiple stations at this location. In this case, only one of these stations will be shown in the tooltip. To see the other stations, zoom in on the map until the station points no longer overlap.
                    </p>
                  </v-col>
                </v-row>
              </v-container>
            </v-card-text>
          </v-card>
        </v-tab-item>

        <!-- PLATFORMS -->
        <v-tab-item>
          <v-card flat>
            <v-card-text class="body-1 black--text">
              <div class="text-h5">Stationary Platforms</div>
              <v-container fluid>
                <v-row>
                  <v-col cols="3" class="text-center">
                    <v-img
                      src="@/assets/img/guide/platforms/SOUNDTRAP.png"
                      alt="Bottom-mounted mooring diagram"
                      max-height="300px"
                      contain
                    ></v-img>
                  </v-col>
                  <v-col cols="9">
                    <div class="text-h6">Bottom-Mounted Mooring</div>
                    <p>A bottom-mounted mooring is a stationary passive acoustic recorder anchored to the sea floor in a particular location. It records passive acoustic data and is recovered after a set amount of time which can be up to several months or years. These bottom-mounted recorders are useful for collecting data on the long term temporal (over time) occurrence of vocally active species in a given area. There are many types of bottom-mounted recorders, each one built to handle the different combinations of recording period, water depth, and species.</p>
                  </v-col>
                </v-row>
                <v-row>
                  <v-col cols="3" class="text-center">
                    <v-img
                      src="@/assets/img/guide/platforms/MOORED-BUOY.png"
                      alt="Surface buoy diagram"
                      max-height="300px"
                      contain
                    ></v-img>
                  </v-col>
                  <v-col cols="9">
                    <div class="text-h6">Surface Buoy</div>
                    <p>A surface buoy can either be a stationary mooring or a drifting unit. The stationary mooring is anchored to the seafloor and has a surface float where electronics are housed that allow data transmission. Both types can send back near real-time passive acoustic data using either an iridium satellite link or a VHF antenna.</p>
                  </v-col>
                </v-row>
              </v-container>

              <v-divider class="my-8"></v-divider>

              <div class="text-h5">Mobile Platforms</div>
              <v-container fluid>
                <v-row align="center">
                  <v-col cols="3" class="text-center">
                    <v-img
                      src="@/assets/img/guide/platforms/SLOCUM-GLIDER.png"
                      alt="Slocum glider diagram"
                      max-height="300px"
                      contain
                    ></v-img>
                  </v-col>
                  <v-col cols="9">
                    <div class="text-h6">Glider (Slocum)</div>
                    <p>A glider, or autonomous underwater vehicle (AUV), can be programmed to travel along a given trajectory. Gliders can be outfitted with many different instruments, including passive acoustic recording packages. They are able to transmit data back in near real time using an iridium satellite or cellular link as well as storing the data onboard until it is retrieved. There are several different types of gliders, the main ones being battery- or wave-powered. Battery-powered gliders (also known as Slocum gliders) tend to travel up and down the water column in a vertical zig-zag, utilizing buoyancy and an onboard motor to maintain course. Wave powered gliders are a different type of glider that use the energy produced by the motion of waves to create their propulsion. Currently, only detection data collected by Slocum gliders are included in this application; wave gliders will be added in the future as a separate category.</p>
                  </v-col>
                </v-row>
                <v-row align="center">
                  <v-col cols="3" class="text-center">
                    <v-img
                      src="@/assets/img/guide/platforms/SHIP-TOWED-ARRAY.png"
                      alt="Towed array diagram"
                      max-height="300px"
                      contain
                    ></v-img>
                  </v-col>
                  <v-col cols="9">
                    <div class="text-h6">Towed Array</div>
                    <p>A towed array usually consists of a long electronic cable with a series of hydrophones and other sensors encompassed within it. Typically, they are towed horizontally behind a vessel and collect passive acoustic data in real time, but they can also be suspended vertically from a stationary mooring or vessel. The most simple array is a linear one in which all hydrophones are arranged in one plane (usually x) and therefore localization occurs in 2D, but there are also volumetric arrays, which have the hydrophones arranged in the x,y, and z planes for 3D localization.</p>
                  </v-col>
                </v-row>
              </v-container>
            </v-card-text>
          </v-card>
        </v-tab-item>

        <!-- FAQ -->
        <v-tab-item>
          <v-card flat>
            <v-card-text class="body-1 black--text">
                <v-expansion-panels>
                  <v-expansion-panel>
                    <v-expansion-panel-header class="text-subtitle-1 font-weight-bold">
                      What is passive acoustic monitoring?
                    </v-expansion-panel-header>
                    <v-expansion-panel-content class="text-body-2">
                      Passive Acoustic Monitoring (PAM) is a non-invasive method that allows us to continuously monitor the ocean by recording sounds produced by marine animals and the surrounding environment. We use underwater microphones, called hydrophones, to record sound, which we use to understand which species are calling, or what other activities (i.e. anthropogenic activity, weather events) occur. We use a variety of computer programs that have been developed for different types of sounds; these help us identify when specific sounds (which can be attributed to species) occur in our data. For more information on the types of information PAM provides, and the projects we work on, see the <a href="https://www.fisheries.noaa.gov/new-england-mid-atlantic/endangered-species-conservation/passive-acoustic-research-atlantic-ocean" target="_blank">NOAA NEFSC Passive Acoustic Research Program Website</a>.
                    </v-expansion-panel-content>
                  </v-expansion-panel>

                  <v-expansion-panel>
                    <v-expansion-panel-header class="text-subtitle-1 font-weight-bold">
                      What is a deployment?
                    </v-expansion-panel-header>
                    <v-expansion-panel-content class="text-body-2">
                      In general, a single deployment contains the acoustic recordings collected by a single platform over a continuous period of time. For stationary platforms (bottom-mounted moorings, surface buoys), a deployment is the continuous period when a hydrophone was left at a fixed position over time and then subsequently recovered. For many stationary platforms, multiple deployments are collected within a close spatial proximity, sometimes at different depths. For gliders, a deployment represents the continuous period when a single glider travelled through the ocean collecting audio data. For towed arrays, a deployment corresponds to a single cruise of the research vessel. Towed array deployments may have multi-day gaps due to periods when the vessel returned to port or bad weather.
                    </v-expansion-panel-content>
                  </v-expansion-panel>

                  <v-expansion-panel>
                    <v-expansion-panel-header class="text-subtitle-1 font-weight-bold">
                      What is the difference between "Detected" and "Possibly Detected"?
                    </v-expansion-panel-header>
                    <v-expansion-panel-content class="text-body-2">
                      Detected indicates the species was acoustically detected, and verified, by the analysis' protocols. This means that the minimum number of species-specific call types were detected within a given time period (i.e. 24 hours). Sometimes, similar calls can be produced by multiple species, or the recordings have other sounds co-occurring (i.e. boat, or singing humpback whale), which can make it difficult to confirm the presence of the target species. Periods like these, when we cannot confirm with certainty that a species is present, are marked as "Possibly Detected."  The minimum requirements to mark a period as "Detected" differ between species, the detector used, and the analysis methods. More information on these methods can be found in the protocol references for each deployment, for each species (click on the stationary platform or track to bring up the details for the deployment). Periods marked as "Detected" represent the minimum presence of species for times when animals are calling; they do not capture time periods when animals are present but silent.
                    </v-expansion-panel-content>
                  </v-expansion-panel>

                  <v-expansion-panel>
                    <v-expansion-panel-header class="text-subtitle-1 font-weight-bold">
                      What is a call type?
                    </v-expansion-panel-header>
                    <v-expansion-panel-content class="text-body-2">
                      Most species produce more than one type of call which can be attributed to that species (for example, North Atlantic right whales produce upcalls, gunshots, and additional call types; many odontoceti species produce both whistles and echolocation clicks). These call types can be similar to one another, or vary greatly, often resulting with detectors built specifically for one call type. Sometimes, only one call type is analyzed for a species; other times, multiple call types are analyzed for a species. The metadata table shows you which call types have been analyzed and are marked as "Detected" for that species and specific recorder. Species use call types for different behaviours (i.e. blue whale arch/D calls are a feeding call, while AB calls denote song). The presence of different call types may show different seasonal presence depending on what call type was analyzed.
                    </v-expansion-panel-content>
                  </v-expansion-panel>

                  <v-expansion-panel>
                    <v-expansion-panel-header class="text-subtitle-1 font-weight-bold">
                      Where did this dataset come from?
                    </v-expansion-panel-header>
                    <v-expansion-panel-content class="text-body-2">
                      The full detections dataset was compiled by the NOAA NEFSC Passive Acoustic Research Program using acoustic data collected by many collaborators. Information on data ownership can be found in the details of each deployment (click on a stationary platform or track to bring up the details for a deployment).
                    </v-expansion-panel-content>
                  </v-expansion-panel>

                  <v-expansion-panel>
                    <v-expansion-panel-header class="text-subtitle-1 font-weight-bold">
                      Can I get a copy of this dataset?
                    </v-expansion-panel-header>
                    <v-expansion-panel-content class="text-body-2">
                      The entire dataset is not publicly available. If you are interested in the data for a single deployment, you may reach out to the point of contact (POC), which is listed in the deployment details (click on a stationary platform or track to bring up the details for a deployment).
                    </v-expansion-panel-content>
                  </v-expansion-panel>

                  <v-expansion-panel>
                    <v-expansion-panel-header class="text-subtitle-1 font-weight-bold">
                      Can I contribute my own passive acoustic detection data?
                    </v-expansion-panel-header>
                    <v-expansion-panel-content class="text-body-2">
                      If you have passive acoustic data that you would like to contribute to this project, please contact <a href="mailto:nmfs.pacmdata@noaa.gov">nmfs.pacmdata@noaa.gov</a>.
                    </v-expansion-panel-content>
                  </v-expansion-panel>

                  <v-expansion-panel>
                    <v-expansion-panel-header class="text-subtitle-1 font-weight-bold">
                      How should I cite this website?
                    </v-expansion-panel-header>
                    <v-expansion-panel-content class="text-body-2">
                      <p>
                        When using or referencing this data, please cite as:
                      </p>
                      <p class="font-weight-bold grey--text text--darken-2">
                        <Citation></Citation>
                      </p>
                    </v-expansion-panel-content>
                  </v-expansion-panel>
                </v-expansion-panels>
                <p class="mt-4 text-center">
                  For any other questions or inquiries, please contact <a href="mailto:nmfs.pacmdata@noaa.gov">nmfs.pacmdata@noaa.gov</a>
                </p>
            </v-card-text>
          </v-card>
        </v-tab-item>

        <!-- CITATION -->
        <v-tab-item>
          <v-card flat>
            <v-card-text class="body-1 black--text">
              <p>
                When using or referencing this dataset or website, please cite as:
              </p>
              <p class="font-weight-bold grey--text text--darken-2">
                <Citation></Citation>
              </p>
              <!-- TODO: UPDATE URL -->
            </v-card-text>
          </v-card>
        </v-tab-item>
      </v-tabs>
    </v-card-text>
    <v-card-actions>
      <v-spacer></v-spacer>
      <v-btn color="primary" text @click.native="$emit('close')">Close</v-btn>
    </v-card-actions>
  </v-card>
</template>

<script>
import Citation from '@/components/Citation'
export default {
  name: 'Guide',
  components: {
    Citation
  }
}
</script>
