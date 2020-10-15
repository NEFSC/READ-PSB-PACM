# Notes and Questions

## 2020-10-12

Towed Array Data

- Metadata missing for projects "NEFSC_GU1303" and "NEFSC_HB1303" (found in tracks and detections)
- Metadata file has project "NEFSC_GU1402", but not found in detections or tracks
- Metadata file
  - missing columns for consistency with mooring/glider datasets (assuming all are `NA`)
    - `PLATFORM_ID`
    - `SITE_ID`
    - `INSTRUMENT_TYPE`
    - `INSTRUMENT_ID`
    - `CHANNEL`
    - `WATER_DEPTH_METERS`
    - `RECORDER_DEPTH_METERS`
  - one row per project
    - monitoring start/end times should cover entire deployment (currently taking min/max of all rows for project)
    - PLATFORM_TYPE currently varies for NEFSC_GU1801 ("Towed Array, linear" and "Towed Array, tetrahedral + linear")
    - QC_DATA currently varies for NEFSC_GU1801
    - QC_DATA should be consistent with moored/glider datasets? those all have QC_DATA=YES, towed array dataset has "post-processed" in most projects
- Beaked detection data
  - GU1803 Legs 1 and 2 are missing `EventEnd` column (plus a number of other columns), setting `EventEnd` equal to `Time (UTC)` for now
  - HB1603, sheet Leg3_HB1_0822-0823_ONEFF has split table (bunch of empty rows), copy and paste error?
  - Missing lat/lon for in 657 rows of GU1803, 1 row of HB1303, and 27 rows of HB1603
  - Aggregating detections is problematic because of species. If two or more species observed on same day, should this be one detection for all, or one for each species? Assuming the latter...

Data Processing Notes

- Tracks
  - GU1803
    - `Echosounder` set to ON from 2018-07-31 17:00 to 2018-08-17 15:00 UTC
    - only include rows where `UserField` > 0
    - latitude/longitude has numerous erroneous or inconsistent values (e.g. latitude = 1356 at 7/22 22:52:55), dropping rows where longitude < -90 or > -30, latitude > 90
  - HB1403
    - sheet 20140725 (GMT) is different from the others
      - missing `Echosounders` column (set to `NA`)
      - ignoring `PCTime` column (using `GPSDate` as timestamp)
      - has `Recording Effort` while others have `MF Rec Effort` and `HF Rec Effort`
- Beaked Whales
  - only include rows where `eventType = (PRBK, POBK, BEAK)`), excluding any rows with `eventType = (BRAN, DOLP)`
  - standardized species names to only have unique values: `"Blainville's", "Cuvier's", "Gervais'", "Gervais'/True's", "MmMe", "Sowerby's", "True's", "Unid. Mesoplodon")`
  - using `UTC` and `EventEnd` for `analysis_period_start` and `analysis_period_end`, assuming everything is in UTC
  - using `TMLatitude1` and `TMLongitude1` for `latitude` and `longitude`
  - ignoring `nClicks`, `min/best/maxNumber`, `TMModelName1`
- Kogia Whales
  - using `UTC` and `EventEnd` for `analysis_period_start` and `analysis_period_end`, assuming everything is in UTC
  - using `TMLatitude1` and `TMLongitude1` for `latitude` and `longitude`
  - ignoring `nClicks`, `min/best/maxNumber`, `TMModelName1`
- Gliders
  - aggregate detections to daily timesteps (first latitude/longitude)
  - no track aggregation
- Towed Arrays
  - aggregate tracks to hourly timesteps (use median lat/lon instead of mean due to issues with GU1803)
  - no aggregation of detections. n is small, and its not clear how to aggregate position (coord in tracks vs detections)

## 2020-01-06

Dataset:

- What to do with small clusters of sites? For example, project=BERCHOK_SAMANA_200901_CH{2,3,4} with site_id={2,3,4} are all very close together.
- Check for longitude > 0 (should be easterly)

Questions:

- How far does each station represent? How far does sound travel?
- What happened in 2010? Any theories aside from general warming of GOM?
- For spatial aggregation by region, what to calculate? # detection days would be influenced by # observation days. Probability of detection? % of total days with detection?
- Davis 2017 focuses on # detection days, but dataset has # detections? Is that # individuals? Or # calls?
- Presence/absence vs abundance

## 2019-12-16

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

