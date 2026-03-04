targets_towed_tracks <- list(
  tar_target(towed_tracks_dir, file.path(towed_dir, "tracks")),

  tar_target(towed_tracks_gu1303_file, file.path(towed_tracks_dir, "GU1303_gpsData.xlsx"), format = "file"),
  tar_target(towed_tracks_gu1303, {
    read_xlsx(
      towed_tracks_gu1303_file,
      col_types = "guess"
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "SEFSC_GU1303",
        datetime = utc,
        latitude,
        longitude
      )
  }),
  
  tar_target(towed_tracks_gu1402_file, file.path(towed_tracks_dir, "GU1402_GPS_data.xlsx"), format = "file"),
  tar_target(towed_tracks_gu1402, {
    read_xlsx(
      towed_tracks_gu1402_file,
      col_types = "guess"
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_GU1402",
        datetime = utc,
        latitude,
        longitude
      )
  }),
  
  tar_target(towed_tracks_gu1605_file, file.path(towed_tracks_dir, "GU1605_allGPS_Corrected.xlsx"), format = "file"),
  tar_target(towed_tracks_gu1605, {
    read_xlsx(
      towed_tracks_gu1605_file,
      col_types = "guess"
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "SEFSC_GU1605",
        datetime = utc,
        latitude,
        longitude
      )
  }),
  
  tar_target(towed_tracks_gu1803_files, list.files(file.path(towed_tracks_dir, "GU1803_ShipGPS_EffortAppended_FIXED"), full.names = TRUE), format = "file"),
  tar_target(towed_tracks_gu1803, {
    towed_tracks_gu1803_files %>% 
      map_df(function (fname) {
        read_xlsx(
          fname,
          col_types = "guess"
        ) %>% 
          clean_names()
      }) %>% 
      filter(
        user_field >= 0,
        longitude > -90,
        longitude < -30,
        latitude < 90
      ) %>% 
      transmute(
        id = "NEFSC_GU1803",
        datetime = date_time_utc,
        latitude,
        longitude
      )
  }),
  
  tar_target(towed_tracks_hb1103a_file, file.path(towed_tracks_dir, "HB1103_gpsData.xlsx"), format = "file"),
  tar_target(towed_tracks_hb1103a, {
    read_xlsx(
      towed_tracks_hb1103a_file,
      col_types = "guess"
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_HB1103",
        datetime = utc,
        latitude,
        longitude
      )
  }),
  tar_target(towed_tracks_hb1103b_file, file.path(towed_tracks_dir, "HB1103_GPS_data_0729-0730.xlsx"), format = "file"),
  tar_target(towed_tracks_hb1103b, {
    read_xlsx(
      towed_tracks_hb1103b_file,
      col_types = "guess"
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_HB1103",
        datetime = utc,
        latitude,
        longitude
      )
  }),
  tar_target(towed_tracks_hb1103, bind_rows(towed_tracks_hb1103a, towed_tracks_hb1103b)),
  
  tar_target(towed_tracks_hb1303_file, file.path(towed_tracks_dir, "HB1303_PG_GPS_ALL_AIedits.xlsx"), format = "file"),
  tar_target(towed_tracks_hb1303, {
    read_xlsx(
      towed_tracks_hb1303_file,
      col_types = "guess"
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_HB1303",
        datetime = utc,
        latitude,
        longitude
      )
  }),
  
  tar_target(towed_tracks_hb1403_file, file.path(towed_tracks_dir, "HB1403_Completed_GpsData_AIedits.xlsx"), format = "file"),
  tar_target(towed_tracks_hb1403_1, {
    read_xlsx(
      towed_tracks_hb1403_file,
      sheet = 1,
      col_types = "guess",
      range = "A1:Q28830"
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_HB1403",
        datetime = gps_date,
        latitude,
        longitude
      )
  }),
  tar_target(towed_tracks_hb1403_2, {
    read_xlsx(
      towed_tracks_hb1403_file,
      sheet = 2,
      col_types = "guess",
      range = "A1:T86072"
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_HB1403",
        datetime = gps_date,
        latitude,
        longitude
      )
  }),
  tar_target(towed_tracks_hb1403_3, {
    read_xlsx(
      towed_tracks_hb1403_file,
      sheet = 3,
      col_types = "guess",
      range = "A1:T59256"
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_HB1403",
        datetime = gps_date,
        latitude,
        longitude
      )
  }),
  tar_target(towed_tracks_hb1403_4, {
    read_xlsx(
      towed_tracks_hb1403_file,
      sheet = 4,
      col_types = "guess",
      range = "A1:T30509"
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_HB1403",
        datetime = gps_date,
        latitude,
        longitude
      )
  }),
  tar_target(towed_tracks_hb1403_5, {
    read_xlsx(
      towed_tracks_hb1403_file,
      sheet = 5,
      col_types = "guess",
      range = "A1:T14141"
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_HB1403",
        datetime = gps_date,
        latitude,
        longitude
      )
  }),
  tar_target(towed_tracks_hb1403, {
    bind_rows(
      towed_tracks_hb1403_1,
      towed_tracks_hb1403_2,
      towed_tracks_hb1403_3,
      towed_tracks_hb1403_4,
      towed_tracks_hb1403_5
    )
  }),
  
  tar_target(towed_tracks_hb1503_1_file, file.path(towed_tracks_dir, "HB1503_20150615_gpsData.xlsx"), format = "file"),
  tar_target(towed_tracks_hb1503_1, {
    read_xlsx(
      towed_tracks_hb1503_1_file,
      col_types = "guess"
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_HB1503",
        datetime = mdy_hms(utc),
        latitude,
        longitude
      )
  }),
  tar_target(towed_tracks_hb1503_2_file, file.path(towed_tracks_dir, "HB1503_Copy of Leg1_gps_June16-18.xlsx"), format = "file"),
  tar_target(towed_tracks_hb1503_2, {
    read_xlsx(
      towed_tracks_hb1503_2_file,
      col_types = "guess"
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_HB1503",
        datetime = utc,
        latitude,
        longitude
      )
  }),
  tar_target(towed_tracks_hb1503_3_file, file.path(towed_tracks_dir, "HB1503_Leg2_ShipGPS.xlsx"), format = "file"),
  tar_target(towed_tracks_hb1503_3, {
    read_xlsx(
      towed_tracks_hb1503_3_file,
      col_types = "guess"
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_HB1503",
        datetime = utc,
        latitude,
        longitude
      )
  }),
  tar_target(towed_tracks_hb1503, {
    bind_rows(
      towed_tracks_hb1503_1,
      towed_tracks_hb1503_2,
      towed_tracks_hb1503_3
    )
  }),
  
  tar_target(towed_tracks_hb1603_file, file.path(towed_tracks_dir, "HB1603_ship_GPS_EchoAdd_All_legs_combined.xlsx"), format = "file"),
  tar_target(towed_tracks_hb1603, {
    read_xlsx(
      towed_tracks_hb1603_file,
      col_types = c(rep("guess", times = 21), "text")
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_HB1603",
        datetime = utc,
        latitude,
        longitude
      )
  }),
  
  tar_target(towed_tracks_hrs1701_file, file.path(towed_tracks_dir, "HRS1701_Skala_gpsData.csv"), format = "file"),
  tar_target(towed_tracks_hrs1701, {
    read_csv(
      towed_tracks_hrs1701_file,
      col_types = cols(
        Id = col_double(),
        Date_UTC = col_character(),
        UTC = col_character(),
        UTCMilliseconds = col_double(),
        PCLocalTime = col_character(),
        PCTime = col_character(),
        GpsDate = col_character(),
        GPSTime = col_double(),
        Latitude = col_double(),
        Longitude = col_double(),
        Speed = col_double(),
        SpeedType = col_character(),
        Heading = col_double(),
        HeadingType = col_logical(),
        TrueHeading = col_logical(),
        MagneticHeading = col_logical(),
        MagneticVariation = col_double(),
        GPSError = col_double(),
        DataStatus = col_character()
      )
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_HRS1701",
        datetime = mdy_hms(utc),
        latitude,
        longitude
      )
  }),
  
  tar_target(towed_tracks_hrs1910_file, file.path(towed_tracks_dir, "HRS1910_ship_GPS.csv"), format = "file"),
  tar_target(towed_tracks_hrs1910, {
    read_csv(
      towed_tracks_hrs1910_file,
      col_types = cols(
        .default = col_double(),
        UTC = col_datetime(format = ""),
        PCLocalTime = col_datetime(format = ""),
        PCTime = col_datetime(format = ""),
        SequenceBitmap = col_logical(),
        GpsDate = col_datetime(format = ""),
        SpeedType = col_character(),
        HeadingType = col_logical(),
        TrueHeading = col_logical(),
        MagneticHeading = col_logical(),
        DataStatus = col_character(),
        FixType = col_character()
      )
    ) %>% 
      clean_names() %>% 
      transmute(
        id = "NEFSC_HRS1910",
        datetime = utc,
        latitude,
        longitude
      )
  }),
  
  tar_target(towed_tracks_raw, {
    bind_rows(
      towed_tracks_gu1303,
      towed_tracks_gu1402,
      towed_tracks_gu1605,
      towed_tracks_gu1803,
      towed_tracks_hb1103,
      towed_tracks_hb1303,
      towed_tracks_hb1403,
      towed_tracks_hb1503,
      towed_tracks_hb1603,
      towed_tracks_hrs1701,
      towed_tracks_hrs1910
    ) %>% 
      arrange(id, datetime)
  }),
  
  tar_target(towed_tracks, {
    # aggregate to hourly timesteps using first position in hour
    df_hr <- towed_tracks_raw |> 
      mutate(
        datetime_hour = floor_date(datetime, unit = "hour")
      ) |> 
      group_by(id, datetime_hour) |> 
      slice_min(order_by = datetime, n = 1) |> 
      ungroup() |> 
      select(-datetime_hour)
    
    # no legs missing track data
    stopifnot(
      towed_cruise_dates %>% 
        anti_join(
          df_hr %>% 
            mutate(date = as_date(datetime)),
          by = c("id", "date")
        ) %>% 
        nrow() == 0
    )
    
    df_legs <- df_hr %>% 
      mutate(date = as_date(datetime)) %>% 
      left_join(towed_cruise_dates, by = c("id", "date"))
    
    # track data with missing legs (not included in Cruise Dates)
    # represents time when recorders were off (e.g. returning to port)
    df_legs %>% 
      filter(is.na(leg)) %>% 
      distinct(id, date)
    
    # convert lat/lon to sf points and then to sf linestrings by leg
    sf_points <- df_legs %>% 
      filter(!is.na(leg)) %>% # only include days listed on cruise tab
      filter(
        !(id == "NEFSC_HB1603" & datetime == ymd_hm(201608110000)) # one point at midnight on this day, but doesn't match rest of the day
      ) %>%
      st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
    
    sf_tracks <- sf_points %>% 
      arrange(id, leg, datetime) %>%
      group_by(id, leg) %>% 
      summarise(
        start_datetime = min(datetime),
        end_datetime = max(datetime),
        start_latitude = first(latitude),
        start_longitude = first(longitude),
        end_latitude = last(latitude),
        end_longitude = last(longitude),
        do_union = FALSE,
        .groups = "drop_last"
      ) %>% 
      st_cast("LINESTRING") %>% 
      summarise(
        start_datetime = min(start_datetime),
        end_datetime = max(end_datetime),
        start_latitude = first(start_latitude),
        start_longitude = first(start_longitude),
        end_latitude = last(end_latitude),
        end_longitude = last(end_longitude),
        do_union = TRUE,
        .groups = "drop"
      ) %>% 
      st_cast("MULTILINESTRING")
    
    # mapview(sf_points, zcol = "leg")
    # mapview(sf_tracks, zcol = "id")
    
    # export
    sf_tracks |> 
      mutate(
        organization_code = str_sub(id, 1, 5),
        deployment_id = glue("{organization_code}:{id}"),
        track_id = glue("{deployment_id}:TOWED_TRACK"),
        track_code = "TOWED_TRACK",
        .after = "id"
      ) |> 
      select(-id)
  }),
  tar_target(towed_tracks_map, {
    towed_tracks |> 
      mapview::mapview(
        label = "track_id",
        zcol = "deployment_id",
        layer.name = "Towed Tracks"
      )
  })
)