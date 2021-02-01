<template>
  <v-card>
    <v-card-title primary-title>
      Video Tutorial
    </v-card-title>

    <v-card-text class="mt-8 body-1 grey--text text--darken-4">
      <p class="font-weight-medium">
        Coming soon...
      </p>
    </v-card-text>
    <v-card-actions>
      <v-spacer></v-spacer>
      <v-btn color="primary" text @click.native="$emit('close')">Close</v-btn>
    </v-card-actions>
  </v-card>
</template>

<script>
export default {
  name: 'HelpDialog'
}
</script>

<style>

</style>
