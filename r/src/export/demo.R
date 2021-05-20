
# demo theme --------------------------------------------------------------
# 
# demo_deployments <- bind_rows(
#   df_deployments %>% 
#     filter(
#       theme == "narw",
#       id %in% c(
#         # "NEFSC_NC_201310_CH2_2",                         # moored | detected
#         # "DUKE_VA_201406_NFC01A_NFC01A",                  # moored | multi-possibly
#         # "MOORS-MURPHY_SCOTIAN_SHELF_200708_PU093_SWGUL", # moored | not detected
#         # "NEFSC_NE_OFFSHORE_201506_WAT_HZ_01_WAT_HZ",     # moored | not analyzed
#         "WHOI_SCOTIAN_SHELF_201509_rb0915_otn200",       # glider | detected/possibly
#         "WHOI_GOM_201812_gom1218_we03",                  # glider | not detected
#         "WHOI_MID-ATLANTIC_202001_hatteras0120_we14"     # glider | not analyzed
#       )
#     )
# ) %>% 
#   mutate(
#     analyzed = if_else(id == "WHOI_MID-ATLANTIC_202001_hatteras0120_we14", FALSE, analyzed)
#   )
# demo_detections <- df_detections %>% 
#   semi_join(
#     demo_deployments,
#     by = c("theme", "id")
#   ) %>% 
#   mutate(
#     presence = case_when(
#       id == "NEFSC_NE_OFFSHORE_201506_WAT_HZ_01_WAT_HZ" ~ "na",
#       id == "WHOI_GOM_201812_gom1218_we03" ~ "nm",
#       id == "WHOI_MID-ATLANTIC_202001_hatteras0120_we14" ~ "na",
#       TRUE ~ presence
#     ),
#     presence = if_else(presence == "nm", "n", presence)
#   ) %>% 
#   mutate(theme = "demo")
# 
# demo_detections_locations <- demo_detections %>% 
#   select(-presence, -date) %>% 
#   unnest(locations) %>% 
#   filter(!id %in% c("WHOI_GOM_201812_gom1218_we03", "WHOI_MID-ATLANTIC_202001_hatteras0120_we14")) %>% 
#   select(id, starts_with("analysis_"), latitude, longitude, presence) %>% 
#   nest(locations = -id)
# 
# demo_detections <- demo_detections %>% 
#   select(-locations) %>% 
#   left_join(demo_detections_locations, by = "id")
# 
# tabyl(demo_detections, id, presence)
# 
# demo_glider_ids <- demo_deployments %>% filter(deployment_type == "mobile") %>% pull(id)
# 
# export_theme("demo", deployments = mutate(demo_deployments, theme = "demo"), detections = demo_detections)

