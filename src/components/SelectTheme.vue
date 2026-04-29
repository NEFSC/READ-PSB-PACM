<template>
  <v-select
    variant="outlined"
    :items="options"
    :model-value="activeTheme"
    label="Select a Species/Group"
    item-title="label"
    item-value="id"
    hide-details
    return-object
    @update:model-value="setTheme"
    class="mt-2"
  >
    <template #item="{ props }">
      <v-list-subheader v-if="props.header">
        {{ props.header }}
      </v-list-subheader>
      <v-divider v-else-if="props.divider" class="mt-2" />
      <v-list-item v-else v-bind="props"></v-list-item>
    </template>
  </v-select>
</template>

<script>
import { mapGetters, mapActions } from 'vuex'
import { themes } from '@/lib/constants'
export default {
  name: 'SelectTheme',
  data () {
    return {
      options: themes
    }
  },
  computed: {
    ...mapGetters({
      activeTheme: 'activeTheme'
    })
  },
  methods: {
    ...mapActions(['setTheme'])
  }
}
</script>
