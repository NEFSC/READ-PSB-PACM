export const themes = [
  {
    id: 'narw',
    label: 'North Atlantic Right Whale'
  },
  {
    id: 'blue',
    label: 'Blue Whale'
  },
  {
    id: 'humpback',
    label: 'Humpback Whale'
  },
  {
    id: 'fin',
    label: 'Fin Whale'
  },
  {
    id: 'sei',
    label: 'Sei Whale'
  },
  {
    id: 'beaked',
    label: 'Beaked Whales',
    showSpeciesFilter: true
  },
  {
    id: 'kogia',
    label: 'Kogia Whales'
  },
  {
    id: 'sperm',
    label: 'Sperm Whales'
  },
  {
    id: 'nefsc-deployments',
    label: 'Deployments (NEFSC Only)',
    deploymentsOnly: true
  }
]
// export const speciesTypesMap = new Map(speciesTypes.map(d => [d.id, d]))

export const platformTypes = [
  {
    id: 'mooring',
    label: 'Bottom Mooring'
  },
  {
    id: 'buoy',
    label: 'Surface Buoy'
  },
  {
    id: 'slocum',
    label: 'Glider (Slocum)'
  },
  {
    id: 'wave',
    label: 'Glider (Wave)'
  },
  {
    id: 'towed',
    label: 'Towed Array'
  }
]
export const platformTypesMap = new Map(platformTypes.map(d => [d.id, d]))

export const detectionTypes = [
  {
    id: 'y',
    label: 'Detected',
    color: '#CC3833'
  },
  {
    id: 'm',
    label: 'Possibly',
    color: '#78B334'
  },
  {
    id: 'n',
    label: 'Not Detected',
    color: '#0277BD'
  },
  {
    id: 'na',
    label: 'Not Analyzed',
    color: '#666666'
  }
]

export const detectionTypesMap = new Map(detectionTypes.map(d => [d.id, d]))

export const tour = [
  {
    target: '[data-v-step="0"]',
    content: `
    <h1 class="title">Welcome!</h1>
    This map shows the locations where whales were detected using passive acoustic monitoring.<br><br>
    Each circle represents a fixed location station (buoy or mooring). The color and size reflect the number of detection days at that station.<br><br>
    Detections using gliders or towed arrays are shown using square symbols.<br><br>
    For gliders, detections are aggregated by day. Each square shows the average location of all detections that occured during a single day.<br><br>
    For towed arrays, detections are <b>not</b> aggregated by day. Each square shows the location of a single detection.<br><br>
    <i>Hover over a point to view metadata about that project, or click on it to view a timeseries of detections.</i>
    `,
    params: {
      highlight: false,
      placement: 'bottom'
    }
  },
  {
    target: '[data-v-step="1"]',
    content: `<i>Switch to a different species or group.</i>`,
    params: {
      highlight: true,
      placement: 'top'
    }
  },
  {
    target: '[data-v-step="2"]',
    content: '<i>Choose which platform types to include.</i>',
    params: {
      highlight: true,
      placement: 'top'
    }
  },
  {
    target: '[data-v-step="3"]',
    content: `
      Chart shows the total number of detection days among all deployments and over all years during each week of the year.<br><br>
      <i>Click and drag on the bottom slider to filter for a specific seasonal period. Or click the start/end dates in the title to manually adjust.</i>
    `,
    params: {
      highlight: true,
      placement: 'bottom'
    }
  },
  {
    target: '[data-v-step="4"]',
    content: `
      Chart shows the number of detection days per year among all stations.<br><br>
      <i>Click and drag on the chart to filter for a specific range of years. Or click the start/end years in the title to manually adjust.</i>
    `,
    params: {
      highlight: true,
      placement: 'bottom'
    }
  },
  {
    target: '[data-v-step="5"]',
    content: `
      Chart shows the total number of days for each detection type among all stations.<br><br>
      <i>Click on one or more bars to filter the dataset for specific detection type(s).</i>
    `,
    params: {
      highlight: true,
      placement: 'bottom'
    }
  },
  {
    target: '[data-v-step="6"]',
    content: 'Click here to start the tour again',
    params: {
      highlight: true,
      placement: 'bottom'
    }
  }
]
