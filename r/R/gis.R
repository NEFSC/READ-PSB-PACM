targets_gis <- list(
  tar_target(gis_wind_lease_file, "data/gis/wind/Wind_Lease_Boundaries_March_2022.shp", format = "file"),
  tar_target(gis_wind_lease, {
    st_read(gis_wind_lease_file) %>% 
      clean_names() %>% 
      transmute(
        id = lease_numb,
        lease_type,
        lease_company = company,
        lease_date = coalesce(lease_date, "provisional"),
        lease_term = lease_term,
        state,
        type = "lease"
      )
  }),
  tar_target(gis_wind_plan_file, "data/gis/wind/Wind_Planning_Area_Boundaries_March25_2022.shp", format = "file"),
  tar_target(gis_wind_plan, {
    st_read(gis_wind_plan_file) %>% 
      clean_names() %>% 
      filter(str_detect(additional, c("Carolina|New York"))) %>%
      transmute(
        id = coalesce(protractio, "N/A"),
        plan_name = additional,
        plan_category = category1,
        type = "plan"
      )
  }),
  tar_target(gis_wind, bind_rows(gis_wind_lease, gis_wind_plan)),
  tar_target(gis_wind_geojson, {
    filename <- "../public/gis/wind-energy-areas.json"
    if (file.exists(filename)) {
      log_warn("deleting: {filename}")
      unlink(filename)
    }
    gis_wind %>% 
      st_transform(crs = "EPSG:4326") %>% 
      st_write(filename, driver = "GeoJSON", append = FALSE, layer_options = "COORDINATE_PRECISION=6")
    filename
  }, format = "file")
)