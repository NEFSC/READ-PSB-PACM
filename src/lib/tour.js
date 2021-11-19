export default [
  {
    target: '[data-v-step="map"]',
    header: {
      title: 'Welcome'
    },
    content: `
    This map shows where and how often whales and other cetaceans were detected using passive acoustic monitoring (PAM).<br><br>

    Detections are shown using different symbols for each type of monitoring platform:<br>
    <ul>
      <li><b>Stationary Platforms</b>: Bottom-mounted moorings and surface buoys are represented using circles. The size and color of each circle reflect the number days and type of detections observed.</li>
      <li><b>Mobile Platforms</b>: Gliders and towed arrays are represented using lines for their tracks and and square symbols to indicate the specific locations where a detection was observed. For gliders, only the first detection of each day is shown on the map. For towed arrays, all detections are shown and may include more than one on a given day.</li>
    </ul><br>

    <i>Hover over a point to view a brief summary of that deployment. Click on a point or track line to view the complete metadata and a timeseries chart of daily detection results for the corresponding deployment.</i><br><br>

    See the <b>User Guide</b> for more information about the map symbology and platform types, as well as a video tutorial on how to use this website.
    `,
    params: {
      highlight: true,
      placement: 'bottom'
    }
  },
  {
    target: '[data-v-step="theme"]',
    header: {
      title: 'Select Species or Group'
    },
    content: `
    <i>Switch to a different species or group using the dropdown.</i><br><br>
    At the bottom of this menu is an option to show the deployments associated with only the NEFSC. This option does not include any detection results.
    `,
    params: {
      highlight: true,
      placement: 'top'
    }
  },
  {
    target: '[data-v-step="platform"]',
    header: {
      title: 'Filter by Platform Type'
    },
    content: `
      <i>Choose which platform type(s) include in the dataset shown on the map.</i><br><br>
      See the <b>User Guide</b> for detailed descriptions and diagrams of each platform type.
    `,
    params: {
      highlight: true,
      placement: 'top'
    }
  },
  {
    target: '[data-v-step="advanced"]',
    header: {
      title: 'Open Advanced Filters'
    },
    content: `
      <i>Click here to open advanced filtering options.</i><br><br>
      Advanced filters can be used to focus on specific data affiliations, instrument types, and recorder sampling rates.
    `,
    params: {
      highlight: true,
      placement: 'top'
    }
  },
  {
    target: '[data-v-step="season"]',
    header: {
      title: 'Filter by Season'
    },
    content: `
      <i>Click and drag on the bottom slider or click the start/end dates above the chart to focus on a specific portion of the year.</i><br><br>
      The chart shows the total number of days for each detection result over the course of the year based on the selected platform types and years. Days are grouped into 5-day intervals.
    `,
    params: {
      highlight: true,
      placement: 'bottom'
    }
  },
  {
    target: '[data-v-step="year"]',
    header: {
      title: 'Filter by Year'
    },
    content: `
      <i>Click and drag on the bottom slider or click the start/end years above the chart to focus on a specific set of years.</i><br><br>
      The chart shows the total number of days for each type of detection result and during each year based on the selected platform types and seasonal period.
    `,
    params: {
      highlight: true,
      placement: 'bottom'
    }
  },
  {
    target: '[data-v-step="detection"]',
    header: {
      title: 'Filter by Detection Result Type'
    },
    content: `
      <i>Click on the individual bars or use the radio buttons on the right to focus on specific types of detection results.</i><br><br>
      The chart shows the total number of days for each type of detection result over the selected platform types, seasonal period, and years.
    `,
    params: {
      highlight: true,
      placement: 'bottom'
    }
  },
  {
    target: '[data-v-step="legend"]',
    header: {
      title: 'Legend'
    },
    content: `Top section indicates how many of the total recorded days and deployments are currently being shown on the map. These counts will change in response to the selected platform types, seasonal period, years, and detection result types. See the <b>FAQ</b> in the <b>User Guide</b> for more information about how deployments are defined for each platform type.<br><br>
    The bottom section shows the symbology for each platform type. See the <b>Map Key</b> in the <b>User Guide</b> for more information about these symbols.<br><br>
    If Stationary Platforms are shown, check the <b>Normalize by Effort</b> box to re-scale the size of each circle using the <i>percent</i> of days detected (calculated by dividing number of detection days by total number of recorded days recorded during the deployment).
    `,
    params: {
      highlight: true,
      placement: 'right'
    }
  },
  {
    target: '.leaflet-control-zoom.leaflet-bar.leaflet-control',
    header: {
      title: 'Zoom or Reset Map'
    },
    content: `
      <i>Use the +/- buttons to zoom in and out. Click the world button to reset the map to its original extent.</i>
    `,
    params: {
      highlight: true,
      placement: 'right'
    }
  },
  {
    target: '.leaflet-control-layers.leaflet-control',
    header: {
      title: 'Basemaps and Layers'
    },
    content: `
      <i>Toggle basemaps and overlay layers (e.g. management areas).</i>
    `,
    params: {
      highlight: true,
      placement: 'right'
    }
  },
  {
    target: '.leaflet-draw.leaflet-control',
    header: {
      title: 'Select Deployments by Bounding Box'
    },
    content: `
      <i>Click the top button to enable drawing mode, then click and drag on the map to draw a bounding box around a set of deployments.</i><br><br>
      The deployments will then be filtered to only include those within that box.<br><br>
      To add another bounding box, click the top button again and draw a second box.<br><br>
      Click the middle button to <b>edit</b> each box.<br><br>
      Click the bottom button to <b>delete</b> the boxes.
    `,
    params: {
      highlight: true,
      placement: 'right'
    }
  },
  {
    target: '[data-v-step="about-button"]',
    header: {
      title: 'Open the About Window'
    },
    content: '<i>Click here to read more about this project.</i>',
    params: {
      highlight: true,
      placement: 'bottom'
    }
  },
  {
    target: '[data-v-step="user-guide-button"]',
    header: {
      title: 'Open the User Guide'
    },
    content: `<i>Click here to open the <b>User Guide</b> containing:</i><br><br>
    <ul>
      <li><b>Map Key</b> explaining the different symbols and colors</li>
      <li><b>Video Tutorial</b> demonstrating how to use this website</li>
      <li>Descriptions of the various <b>Platform Types</b></li>
      <li><b>Frequently Asked Questions (FAQ)</b></li>
      <li>Suggested <b>Citation</b> for referencing this website</li>
    </ul>`,
    params: {
      highlight: true,
      placement: 'bottom'
    }
  },
  {
    target: '[data-v-step="tour-button"]',
    header: {
      title: 'Start Tour'
    },
    content: '<i>Click here to start the tour again.</i>',
    params: {
      highlight: true,
      placement: 'bottom'
    }
  }
]
