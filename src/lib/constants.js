export const speciesTypes = [
  {
    id: 'narw',
    label: 'North Atlantic Right Whale'
  },
  {
    id: 'sei',
    label: 'Sei Whale'
  },
  {
    id: 'blue',
    label: 'Blue Whale'
  },
  {
    id: 'humpback',
    label: 'Humpback Whale'
  }
]
export const speciesTypesMap = new Map(speciesTypes.map(d => [d.id, d]))

export const platformTypes = [
  {
    id: 'mooring',
    label: 'Bottom Mooring'
  },
  {
    id: 'glider',
    label: 'Glider'
  },
  {
    id: 'buoy',
    label: 'Surface Buoy'
  }
]
export const platformTypesMap = new Map(platformTypes.map(d => [d.id, d]))

export const detectionTypes = [
  {
    id: 'yes',
    label: 'Detected',
    color: '#CC3833'
  },
  {
    id: 'maybe',
    label: 'Possibly',
    color: '#78B334'
  },
  {
    id: 'no',
    label: 'None',
    color: '#0277BD'
  }
]

export const detectionTypesMap = new Map(detectionTypes.map(d => [d.id, d]))
