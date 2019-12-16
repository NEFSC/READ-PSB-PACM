# Notes and Questions

Dataset Questions:

- Some rows are missing monitoring_end_datetime (n = 12), analysis_period_start_date_time/analysis_period_end_date_time (3,769), latitude/longitude (77). These rows are removed from the dataset.
- Also, some rows were missing a site_id (2,540). But these were kept because they did have lat/lon coordinates, so site_id was set to N/A.
- Dataset only includes platform_type="mooring", but shiny app also lists buoy, slocum as options?
- platform_id is always N/A?
- How should the dataset be aggregated to a set of unique spatial points on the map? I expected that each unique [project, site_id] would have a fixed lat/long, and thus represent a point on the map. But one site (project=NEFSC_SBNMS_200601, site_id=6) has multiple unique lat/lon coordinates, so maybe the lat/lon for a given site can change between deployments? I ended up defining a "deployment ID" column, which is based on the unique combination of [project, site_id, latitude, longitude, monitoring_start_datetime]. Each point on the new map thus corresponds to a unique deployment ID.
- Most analysis periods are 1 day long, but one project/site (project=NEFSC_MA-RI_201606_CH1, site_id=N1) has analysis periods that were 6 days long (and also overlapping, e.g. 7/15-7/21, 7/16-7/22, 7/17-7/23). How to handle this situation? Web application currently assumes each record is the number of detections over a one day.

Bigger Picture Thoughts:

- How to visually distinguish between detections, non-detections, and no data (when a station was not active for the specified period)?
- Is there anything interesting about the water depth/recorder depth variables?
- Is there a better way to show the data spatially? The current map suffers from clustering of the monitoring sites, which causes sites to overlap. What is the interpretation if there are two sites near one another with very different results? Could the points be spatially aggregated somehow (e.g. hex grid, pre-defined regions)? This gets at larger question: do we only want to explore the raw data? Or would some kind of statistical summary be more informative?
- Are there specific patterns we know about?
- Need to think more about the "season" filter. Currently using cross-filter historgram based on months, but this does not allow selection of winter seasons that cross from the end of one year to the beginning of the next (e.g. Nov - Feb). The shiny app does allow this by using separate sliders for start/end dates.

