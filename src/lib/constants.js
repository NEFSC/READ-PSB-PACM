export const themes = [
  {
    header: 'Baleen Whales (Mysticeti)'
  },
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
    divider: true
  },
  {
    header: 'Toothed Whales (Odontoceti)'
  },
  {
    id: 'beaked',
    label: 'Beaked Whale Species',
    showSpeciesFilter: true
  },
  {
    id: 'kogia',
    label: 'Kogia Species'
  },
  {
    id: 'sperm',
    label: 'Sperm Whale'
  },
  {
    id: 'harbor',
    label: 'Harbor Porpoise'
  },
  {
    divider: true
  },
  {
    header: 'Deployments Only (No Detection Data)'
  },
  {
    id: 'deployments',
    label: 'All Deployments',
    deploymentsOnly: true
  }
]
// export const speciesTypesMap = new Map(speciesTypes.map(d => [d.id, d]))

export const platformTypes = [
  {
    id: 'mooring',
    label: 'Bottom-Mounted Mooring'
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
  },
  {
    id: 'd',
    label: 'Total Days',
    color: 'orange'
  }
]

export const detectionTypesMap = new Map(detectionTypes.map(d => [d.id, d]))
