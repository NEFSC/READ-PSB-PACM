<template>
  <v-dialog v-model="open" max-width="900" scrollable>
    <v-card>
      <v-card-title class="d-flex align-center">
        <h2 class="text-h5">Citations</h2>
        <v-spacer></v-spacer>
        <v-btn icon="mdi-close" variant="flat" size="small" aria-label="close citations" @click="close"></v-btn>
      </v-card-title>
      <v-card-text class="text-body-1 text-grey-darken-4">
        <p class="mb-4">
          If you use data from the Passive Acoustic Cetacean Map (PACM) in a publication, presentation, or other work, please include the PACM citation below and the list of data contributor citations.
        </p>
        <p class="mb-4">
          The data contributor list is generated automatically based on which datasets currently visible on the map. Changing any of the dropdown selections or filters may change this list. Please verify that you have the correct selections and filters applied to the map before copying the citations.
        </p>
        <p class="mb-4">
          Please note that this list may include preferred citations, which can be provided by data contributors. If a dataset does not have a preferred citation, PACM generates a generic citation for the entire organization using the source database for the visible data. Please include both the preferred and generic citations to ensure proper attribution of all data contributors.
        </p>
        <p>
          If you have questions about how to cite data from PACM, please contact <a href="mailto:passive.acoustics@noaa.gov">passive.acoustics@noaa.gov</a>.
        </p>
        <h3 class="text-h6 mt-6 mb-2">PACM Citation</h3>
        <p class="font-weight-bold text-grey-darken-2 text-body-2 mb-4 ml-4">
          {{ pacmCitation }}
        </p>

        <h3 class="text-h6 mt-6 mb-2">Data Contributor Citations</h3>
        <p v-if="contributorCitations.length === 0" class="text-medium-emphasis">
          No data contributors are visible in the current map view.
        </p>
        <p class="font-weight-bold text-grey-darken-2 text-body-2 ml-4 mb-4" v-for="citation in contributorCitations" :key="citation.key">
          {{ citation.text }}
        </p>
      </v-card-text>
      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn color="primary" variant="text" @click="close">Close</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script>
import { mapGetters } from 'vuex'

import { createContributorCitation, parseCitationCodes } from '@/lib/citations'
import { xf } from '@/lib/crossfilter'

export default {
  name: 'CitationsDialog',
  props: {
    modelValue: {
      type: Boolean,
      default: false
    }
  },
  emits: ['update:modelValue'],
  computed: {
    ...mapGetters(['organizations', 'citations', 'deployments']),
    open: {
      get () {
        return this.modelValue
      },
      set (value) {
        this.$emit('update:modelValue', value)
      }
    },
    accessedDate () {
      return new Date().toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      })
    },
    pacmCitation () {
      return `Passive Acoustic Cetacean Map (PACM). 2026. Woods Hole (MA): NOAA Northeast Fisheries Science Center v${process.env.PACKAGE_VERSION || 'Unknown'}. Accessed on ${this.accessedDate}. https://passiveacoustics.fisheries.noaa.gov/pacm/`
    },
    organizationByCode () {
      return new Map((this.organizations || []).map(organization => [organization.code, organization]))
    },
    citationByCode () {
      return new Map((this.citations || []).map(citation => [citation.code, citation]))
    },
    deploymentById () {
      return new Map((this.deployments || []).map(deployment => [deployment.id, deployment]))
    },
    contributorCitations () {
      const preferredCitations = this.getVisibleCitationCodes().map(citationCode => {
        const citation = this.citationByCode.get(citationCode)
        return {
          key: `citation:${citationCode}`,
          text: citation?.reference || citationCode
        }
      })

      const organizationCitations = this.getVisibleOrganizationSources().map(({ organizationCode, sources }) => {
        const organization = this.organizationByCode.get(organizationCode) || { code: organizationCode }
        return {
          key: `organization:${organizationCode}`,
          organizationCode,
          text: createContributorCitation(organization, this.accessedDate, sources)
        }
      })

      return [
        ...preferredCitations,
        ...organizationCitations
      ].sort((a, b) => a.text.localeCompare(b.text))
    }
  },
  methods: {
    normalizeOrganizationCode (code) {
      return code || 'UNKNOWN'
    },
    normalizeSource (source) {
      const normalizedSource = String(source || 'PARS').toUpperCase()
      return ['MAKARA', 'PARS'].includes(normalizedSource) ? normalizedSource : 'PARS'
    },
    getVisibleCitationCodes () {
      const codes = new Set()
      const deploymentIds = new Set(xf.allFiltered().map(detection => detection.id))

      deploymentIds.forEach(id => {
        parseCitationCodes(this.deploymentById.get(id)?.citations)
          .forEach(code => codes.add(code))
      })

      return Array.from(codes).sort()
    },
    getVisibleOrganizationSources () {
      const organizationSources = new Map()
      const deploymentIds = new Set(xf.allFiltered().map(detection => detection.id))

      deploymentIds.forEach(id => {
        const deployment = this.deploymentById.get(id)
        if (!deployment) return

        const source = this.normalizeSource(deployment.source)
        const organizationCodes = [
          deployment.deployment_organization_code,
          deployment.analysis_organization_code
        ].map(this.normalizeOrganizationCode)

        organizationCodes.forEach(organizationCode => {
          if (!organizationSources.has(organizationCode)) {
            organizationSources.set(organizationCode, new Set())
          }
          organizationSources.get(organizationCode).add(source)
        })
      })

      return Array.from(organizationSources.entries())
        .map(([organizationCode, sources]) => ({
          organizationCode,
          sources: Array.from(sources).sort()
        }))
        .sort((a, b) => a.organizationCode.localeCompare(b.organizationCode))
    },
    close () {
      this.open = false
    }
  }
}
</script>
