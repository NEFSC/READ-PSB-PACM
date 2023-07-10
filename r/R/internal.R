targets_internal <- list(
  tar_target(internal, {
    deployments <- bind_rows(
      towed$deployments,
      moored$deployments,
      glider$deployments
    )
    detections <- bind_rows(
      towed$detections,
      moored$detections,
      glider$detections
    )
    list(
      deployments = deployments,
      detections = detections
    )
  })
)