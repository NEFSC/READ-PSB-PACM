<template>
  <v-select
    outlined
    :items="options"
    :value="theme"
    label="Select a species/group"
    item-text="label"
    item-value="id"
    hide-details
    @input="setTheme"
  ></v-select>
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
    ...mapGetters(['theme'])
  },
  methods: {
    ...mapActions(['setTheme'])
  }
}
</script>

<style>

</style>
