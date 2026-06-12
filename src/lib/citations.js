function normalizeSources (sources) {
  const values = Array.isArray(sources) || sources instanceof Set
    ? Array.from(sources)
    : [sources]

  const normalizedSources = values
    .map(source => String(source || 'PARS').toUpperCase())
    .filter(source => source === 'PARS' || source === 'MAKARA')

  return normalizedSources.length > 0
    ? Array.from(new Set(normalizedSources)).sort()
    : ['PARS']
}

export function parseCitationCodes (codes) {
  return (codes || '')
    .split(',')
    .map(code => code.trim())
    .filter(code => code && code !== 'NA')
}

export function createContributorCitation (organization, accessedDate, sources = ['PARS']) {
  const organizationName = organization?.name || organization?.code || 'Unknown organization'
  // const normalizedSources = normalizeSources(sources)
  // const sourcePhrases = []

  // if (normalizedSources.includes('PARS')) {
  //   sourcePhrases.push('Passive Acoustic Reporting System (PARS) at https://passiveacoustics.fisheries.noaa.gov/pars/')
  // }

  // if (normalizedSources.includes('MAKARA')) {
  //   sourcePhrases.push('Makara Passive Acoustics Database')
  // }

  return `${organizationName}. 2026. Passive acoustic monitoring data retrieved from the NOAA Fisheries Passive Acoustic Reporting System (PARS) at https://passiveacoustics.fisheries.noaa.gov/pars/. Accessed on ${accessedDate} via the Passive Acoustic Cetacean Map (PACM) at https://passiveacoustics.fisheries.noaa.gov/pacm/.`
}
