export function parseCitationCodes (codes) {
  return (codes || '')
    .split(',')
    .map(code => code.trim())
    .filter(code => code && code !== 'NA')
}

export function createContributorCitation (organization, accessedDate, sources = ['PARS']) {
  const organizationName = organization?.name || organization?.code || 'Unknown organization'

  return `${organizationName}. 2026. Passive acoustic monitoring data retrieved from the NOAA Fisheries Passive Acoustic Reporting System (PARS) at https://passiveacoustics.fisheries.noaa.gov/pars/. Accessed on ${accessedDate} via the Passive Acoustic Cetacean Map (PACM) at https://passiveacoustics.fisheries.noaa.gov/pacm/.`
}
