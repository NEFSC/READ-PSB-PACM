export const themes = [
  {
    header: 'Detections & Deployments'
  },
  {
    id: 'narw-1',
    label: 'NARW x1'
  },
  {
    id: 'narw-2',
    label: 'NARW x2'
  },
  {
    id: 'narw-4',
    label: 'NARW x4'
  },
  {
    id: 'narw-8',
    label: 'NARW x8'
  },
  {
    divider: true
  },
  {
    header: 'Detections Only'
  },
  {
    id: 'narw-detect-1',
    label: 'NARW x1 (Detect. Only)'
  },
  {
    id: 'narw-detect-2',
    label: 'NARW x2 (Detect. Only)'
  },
  {
    id: 'narw-detect-4',
    label: 'NARW x4 (Detect. Only)'
  },
  {
    id: 'narw-detect-8',
    label: 'NARW x8 (Detect. Only)'
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
