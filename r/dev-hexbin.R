# development: hexbin mapping

library(tidyverse)
library(lubridate)
library(gganimate)

dat <- readRDS("rds/dataset.rds")
deployments <- dat$deployments
detections <- dat$detections


df <- detections %>% 
  select(project, site_id, date, narw) %>% 
  left_join(
    deployments %>% 
      select(project, site_id, latitude, longitude),
    by = c("project", "site_id")
  ) %>% 
  transmute(
    deployment = str_c(project, site_id, sep = ":"),
    date,
    latitude,
    longitude,
    detect = 1 * (narw == "yes")
  ) %>% 
  filter(
    !is.na(detect),
    latitude >= 30,
    latitude <= 47
  )

df %>% 
  filter(
    month(date) >= 11 | month(date) <= 2
  ) %>% 
  summary()

df %>% 
  group_by(deployment, latitude, longitude) %>% 
  summarise(
    n = n(),
    mean = mean(detect),
    sum = sum(detect)
  ) %>% 
  ggplot(aes(longitude, latitude, color = sum)) +
  geom_point(aes(size = n)) +
  scale_color_viridis_c() +
  theme_bw()


# count of stations in each bin
df %>% 
  group_by(deployment, latitude, longitude) %>% 
  summarise(
    n = n(),
    mean = mean(detect),
    sum = sum(detect)
  ) %>% 
  ggplot() +
  geom_hex(aes(longitude, latitude)) +
  scale_fill_viridis_c() +
  theme_bw()

df_hex <- hexbin::hexbin(
  df$longitude, df$latitude,
  xbins = 30, IDs = TRUE
)
hexagons <- data.frame(
  hexbin::hcell2xy(df_hex),
  cell = df_hex@cell,
  count = df_hex@count
)
df$cell <- df_hex@cID

# mean(detect) by cell
df %>% 
  group_by(cell) %>% 
  summarise(
    mean = mean(detect)
  ) %>% 
  right_join(hexagons, by = "cell") %>% 
  ggplot() +
  geom_hex(
    aes(x, y, fill = mean),
    stat = "identity", color = NA
  ) +
  scale_fill_distiller(palette = "RdYlGn", direction = -1)

# mean(detect) by cell, date
df %>% 
  filter(month(date) == 2) %>% 
  group_by(cell, date) %>% 
  summarise(
    detect = max(detect)
  ) %>% 
  summarise(
    n_day = n(),
    mean = mean(detect)
  ) %>% 
  right_join(hexagons, by = "cell") %>% 
  mutate(
    n_day = coalesce(n_day, 0L)
  ) %>% 
  ggplot() +
  geom_hex(
    aes(x, y, fill = mean, alpha = n_day),
    stat = "identity", color = NA
  ) +
  scale_fill_distiller(palette = "RdYlGn", direction = -1, limits = c(0, 1)) +
  theme_bw()

# mean(detect) by cell, date | animate by month
p <- df %>% 
  mutate(month = month(date)) %>% 
  group_by(cell, month, date) %>% 
  summarise(
    detect = max(detect)
  ) %>% 
  summarise(
    n_day = n(),
    mean = mean(detect)
  ) %>% 
  ungroup() %>% 
  right_join(hexagons, by = "cell") %>% 
  mutate(
    n_day = coalesce(n_day, 0L),
    sum = mean * n_day
  ) %>% 
  ggplot() +
  geom_hex(
    aes(x, y, fill = sum, alpha = n_day, group = month),
    stat = "identity", color = NA
  ) +
  scale_fill_distiller(palette = "RdYlGn", direction = -1, limits = c(0, 3)) +
  theme_bw() +
  transition_states(month, transition_length = 2, state_length = 1)
animate(p, renderer = ffmpeg_renderer())


p <- df %>% 
  mutate(month = month(date)) %>% 
  group_by(cell, month) %>% 
  summarise(
    detect = max(detect)
  ) %>% 
  ungroup() %>% 
  right_join(hexagons, by = "cell") %>% 
  ggplot() +
  geom_hex(
    aes(x, y, fill = detect, group = month),
    stat = "identity", color = NA
  ) +
  scale_fill_distiller(palette = "RdYlGn", direction = -1) +
  theme_bw() +
  transition_states(month, transition_length = 2, state_length = 1)
animate(p, renderer = ffmpeg_renderer())


p <- df %>% 
  mutate(year = year(date)) %>% 
  group_by(cell, year) %>% 
  summarise(
    detect = max(detect)
  ) %>% 
  ungroup() %>% 
  right_join(hexagons, by = "cell") %>% 
  ggplot() +
  geom_hex(
    aes(x, y, fill = detect, group = year),
    stat = "identity", color = NA
  ) +
  scale_fill_distiller(palette = "RdYlGn", direction = -1) +
  theme_bw() +
  transition_states(year, transition_length = 2, state_length = 1)
animate(p, renderer = ffmpeg_renderer())
