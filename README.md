Passive Acoustic Cetacean Map
=============================

## Overview

This repo contains the source code for the Passive Acoustic Cetacean Map (PACM) web application. The PACM application is an interactive data visualization tool for exploring historical observations of whales and other cetaceans based on passive acoustic montoring (PAM) data.

Production URL: https://apps-nefsc.fisheries.noaa.gov/pacm/

## Project Summary

**Who is involved in this project?** This application was developed by Jeffrey D Walker, PhD ([Walker Environmental Research LLC](https://walkerenvres.com)) for Sofie Van Parijs, Genevieve Davis, and Annamaria DeAngelis of the [NEFSC Passive Acoustic Research group](https://www.fisheries.noaa.gov/new-england-mid-atlantic/endangered-species-conservation/passive-acoustic-research-atlantic-ocean).

**When was this project created?** Development of this application began in 2019. The first public release was in Spring 2021. The project is ongoing for the foreseeable future.

**What is this project?** The goal of this application is to provide a user-friendly and map-based data visualization interface for exploring historical detections of whales and other cetaceans based on passive acoustic monitoring data. The dataset includes PAM data collected by the [NEFSC Passive Acoustic Research group](https://www.fisheries.noaa.gov/new-england-mid-atlantic/endangered-species-conservation/passive-acoustic-research-atlantic-ocean) as well as numerous other collaborators.

**Why is this project useful?** Existing PAM datasets are not easily accessible for resource managers, decision makers, other researchers or the general public. PACM was developed in large part to make these datasets more widely available for supporting management, research, and public interest.

**How do I use this code?**: This repo contains the source code for both the web application itself, as well as the data processing scripts used to generate the datasets shown on the application. To use this code, follow the instructions provided below in this README file.

**Where do I get help?**: For help running or understanding the code in this repo, contact Jeff Walker (jeffrey.walker@noaa.gov). For questions about contributing data or other general questions about the project, contact Sofie Van Parijs (sofie.vanparijs@noaa.gov).

**Who maintains this code?**: Ongoing maintenance of this code will be performed by Jeffrey D Walker, PhD ([Walker Environmental Research LLC](https://walkerenvres.com)) with approval from NEFSC.

## Data Processing

The `r/` directory contains an RStudio project that includse a series of R scripts for processing the raw data and generating the final datasets that are loaded by the web application.

To get started, open the `r/r.Rproj` file in [RStudio Desktop](https://rstudio.com/products/rstudio/).

The R packages required for these scripts are managed using the [`renv`](https://rstudio.github.io/renv/articles/renv.html) dependency management package. When opening this project in RStudio for the first time, run the following command to install the required R packages.

```r
renv::restore()
```

Due to their size, the raw data files are not included in this repo. To tell R where to find these files, edit the `data_dir` option in the `r/config.yml` file.

To process the datasets and genrate the final datasets for the web application, open the `r/src/main.R` script, and run the series of `source()` commands (in order) to run each script.

If successful, these scripts should load, clean, and merge the various raw data files, and save the final datasets for the web applciation in the `public/data` folder.

## Web Application Development

### Dependencies

The web application requires a recent version of [Node.js](https://nodejs.org/en/) to be installed on your computer.

Once Node is installed, you need to install the project dependencies using this command:

```
npm install
```

### Development

To work on this application, run the following command to start a local development server:

```
npm run serve
```

Then navigate to http://127.0.0.1:8080 in your browser to view the application.

### Build

To deploy this application to a production web server, first verify that the public path to this application is correctly set using the `publicPath` option in the `vue.config.js` file. For example, if the production application will be hosted using the URL `https://noaa.gov/apps/pacm`, then `publicPath` must be set to `/apps/pacm`. The `publicPath` option is currently set to an empty string (`''`), which means that relative paths will be used in `index.html` for fetching the stylesheets and javascript files. Relative paths are being used so that the code can be deployed to both the development and production environments, which have different base URLs (`/pacm_dev` vs `/pacm`).

Build the application by running:

```
npm run build
```

After the application is built, the output files will be available in the `dist/` folder.

### Deployment

To deploy the application, copy the files in the `dist/` folder to the remote web server.

## Containerization

This application can be run in a Docker container. The `docker-compose.yml` file can be used to build a Docker Compose stack that includes the web application and a web server (`nginx`).

```sh
# build stack
docker-compose -p pacm build

# run stack
docker-compose -p pacm up -d

# check status
docker-compose -p pacm ps

# stop stack
docker-compose -p pacm down

# remove stack
docker-compose -p pacm down --volumes

# view logs
docker-compose -p pacm logs -f
```



## Disclaimer

This repository is a scientific product and is not official communication of the National Oceanic and Atmospheric Administration, or the United States Department of Commerce. All NOAA GitHub project code is provided on an ‘as is’ basis and the user assumes responsibility for its use. Any claims against the Department of Commerce or Department of Commerce bureaus stemming from the use of this GitHub project will be governed by all applicable Federal law. Any reference to specific commercial products, processes, or services by service mark, trademark, manufacturer, or otherwise, does not constitute or imply their endorsement, recommendation or favoring by the Department of Commerce. The Department of Commerce seal and logo, or the seal and logo of a DOC bureau, shall not be used in any manner to imply endorsement of any commercial product or activity by DOC or the United States Government.

## License

See [`LICENSE`](LICENSE).