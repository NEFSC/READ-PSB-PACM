<template>
  <v-select
    outlined
    :items="options"
    :value="theme"
    label="Select a Species/Group"
    item-text="label"
    item-value="id"
    hide-details
    return-object
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
