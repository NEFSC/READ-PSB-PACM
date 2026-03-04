targets_ref <- list(
  tar_target(organizations, {
    makara_db$organizations |> 
      select(
        organization_code = code,
        organization_name = name
      )
  }),
  tar_target(platform_types, {
    makara_db$platform_types |> 
      transmute(
        platform_type = code,
        platform_type_name = name,
        deployment_type = if_else(mobile, "MOBILE", "STATIONARY")
      )
  })
)