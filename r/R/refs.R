targets_refs <- list(
  tar_target(ref_call_type, {
    c(
      "Upcall",
      "Moan",
      "Gunshot",
      "20Hz Pulse",
      "Song",
      "Social",
      "Song & Social",
      "A/B/AB song",
      "Arch",
      "Frequency modulated upsweep",
      "Narrow band high frequency click",
      "Pulse train"
    )
  }),
  tar_target(ref_qc_processing, {
    c(
      "Real-time",
      "Archival"
    )
  }),
  tar_target(ref_species, {
    read_excel(templates_detections_file, sheet = "Species_Codes") %>% 
      clean_names()
  }),
  tar_target(ref_species_group, {
    tribble(
      ~species_group, ~species,
      "narw", "EUGL",
      "blue", "BAMU",
      "humpback", "MENO",
      "fin", "BAPH",
      "sei", "BABO",
      
      "beaked", "MEDE",
      "beaked", "ZICA",
      "beaked", "MEEU",
      "beaked", "MMME",
      "beaked", "MEBI",
      "beaked", "MEMI",
      "beaked", "MESP",
      "beaked", "HYAM",
      
      "kogia", "KOSP",
      "sperm", "PHMA",
      "harbor", "PHPH"
    )
  }),
  tar_target(refs, {
    list(
      call_type = ref_call_type,
      qc_processing = ref_qc_processing,
      species = ref_species,
      species_group = ref_species_group,
      acoustic_presences = c("D", "P", "N", "M")
    )
  })
)