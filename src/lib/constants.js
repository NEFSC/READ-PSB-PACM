export const speciesTypes = [
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
    label: 'Beaked Whales'
  },
  {
    id: 'kogia',
    label: 'Kogia Whales'
  }
]
export const speciesTypesMap = new Map(speciesTypes.map(d => [d.id, d]))

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
  }
]

export const detectionTypesMap = new Map(detectionTypes.map(d => [d.id, d]))
