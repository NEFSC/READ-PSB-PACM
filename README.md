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

Deploy the files in `dist/` to web server.

```
# TODO
yarn deploy
```
