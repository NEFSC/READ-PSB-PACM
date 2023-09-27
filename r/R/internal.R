targets_internal <- list(
  tar_target(internal, {
    deployments <- bind_rows(
      towed$deployments,
      moored$deployments,
      glider$deployments,
      nefsc_20230926$deployments
    )
    detections <- bind_rows(
      towed$detections,
      moored$detections,
      glider$detections,
      nefsc_20230926$detections
    )
    list(
      deployments = deployments,
      detections = detections
    )
  })
)