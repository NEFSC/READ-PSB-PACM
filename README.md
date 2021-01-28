NEFSC North American Right Whale Map (Prototype)
================================================

Jeffrey D Walker, PhD <jeff@walkerenvres.com>  
[Walker Environmental Research LLC](https://walkerenvres.com)

## About

This repo contains the source code for the North American Right Whale mapping application. The goal is replicate an existing application that was built using Shiny for R: [https://leviathan.ocean.dal.ca/rw_pam_map/]().

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