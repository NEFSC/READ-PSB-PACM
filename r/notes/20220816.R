source("_targets.R")


# nefsc deployments -------------------------------------------------------

x_old <- read_rds("data/deployment-themes/nefsc.rds")
x_old$deployments
x_old$detections

x_new <- readxl::read_excel("~/Dropbox/Work/nefsc/transfers/20220816 - nefsc deployments/2022-07_Current_Recorders_forRWSC.xlsx") |> 
  clean_names()

names(x_old$deployments)
x_old$deployments |> 
  arrange(desc(monitoring_end_datetime))
