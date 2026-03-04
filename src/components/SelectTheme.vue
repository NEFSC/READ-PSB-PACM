<template>
  <v-select
    variant="outlined"
    :items="options"
    :model-value="theme"
    label="Select a Species/Group"
    item-title="label"
    item-value="id"
    hide-details
    return-object
    @update:model-value="setTheme"
  ></v-select>
</template>

<script>
import { mapState, mapActions } from 'pinia'
import { useStore } from '@/store'
import { themes } from '@/lib/constants'
export default {
  name: 'SelectTheme',
  data () {
    return {
      options: themes
    }
  },
  computed: {
    ...mapState(useStore, ['theme'])
  },
  methods: {
    ...mapActions(useStore, ['setTheme'])
  }
}
</script>

<style>

</style>
