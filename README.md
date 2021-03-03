Passive Acoustic Cetacean Map
=============================

## Overview

This repo contains the source code for the Passive Acoustic Cetacean Map (PACM) web application. The PACM application is an interactive data visualization tool for exploring historical observations of whales and other cetaceans based on passive acoustic montoring data.

## Data Processing

Data files are processed using various R scripts in the `r/` directory.

## Development

Run development server:

```
yarn serve
```

## Production

Builds the application to `dist/` folder.

```
yarn build
```

## Deployment

Deploy the files in `dist/` to web server (automatically builds first).

```
yarn deploy
```

## Data Structure

### Deployment

Unique: `theme,id`

```
theme                     STRING(->themes)*
id                        STRING*
project                   STRING*
site_id                   STRING
latitude                  REAL
longitude                 REAL

monitoring_start_datetime STRING("YYYY-MM-DDTHH:mm:ssZ")
monitoring_end_datetime   STRING("YYYY-MM-DDTHH:mm:ssZ")

platform_type             STRING(->platform_types)*
platform_id               STRING
water_depth_meters        REAL
recorder_depth_meters     REAL

detection_method          STRING
instrument_type           STRING
instrument_id             STRING
sampling_rate_hz          STRING
soundfiles_timezone       STRING
duty_cycle_seconds        STRING
channel                   STRING
qc_data                   STRING
protocol_reference        STRING

data_poc_name             STRING
data_poc_affiliation      STRING
data_poc_email            STRING

submitter_name            STRING
submitter_affiliation     STRING
submitter_email           STRING
submission_date           STRING("YYYY-MM-DD")
```

### Detections

Unique: `theme,deployment_id,species,date`

```
theme         STRING(->themes)
deployment_id STRING(->deployment.id)
species       STRING
date          STRING("YYYY-MM-DD")
presence      STRING({y,m,n})
call_type     STRING
locations     JSON([{analysis_period_start_datetime,analysis_period_end_datetime,latitude,longitude}])
```

### Tracks

Unique: `theme,deployment_id`

```
theme         STRING(->themes)
track_id      INTEGER(UNIQUE)
deployment_id STRING(->deployment.id)
geometry      LINESTRING/MULTILINESTRING
```

stations.fixed <- deployments
stations.mobile <- detections.points

## Disclaimer

This repository is a scientific product and is not official communication of the National Oceanic and Atmospheric Administration, or the United States Department of Commerce. All NOAA GitHub project code is provided on an ‘as is’ basis and the user assumes responsibility for its use. Any claims against the Department of Commerce or Department of Commerce bureaus stemming from the use of this GitHub project will be governed by all applicable Federal law. Any reference to specific commercial products, processes, or services by service mark, trademark, manufacturer, or otherwise, does not constitute or imply their endorsement, recommendation or favoring by the Department of Commerce. The Department of Commerce seal and logo, or the seal and logo of a DOC bureau, shall not be used in any manner to imply endorsement of any commercial product or activity by DOC or the United States Government.

## License

See [`LICENSE` file](LICENSE).