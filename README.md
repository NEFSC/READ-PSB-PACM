NEFSC North American Right Whale Map (Prototype)
================================================

Jeffrey D Walker, PhD <jeff@walkerenvres.com>  
[Walker Environmental Research LLC](https://walkerenvres.com)

## About

This repo contains the source code for the North American Right Whale mapping application. The goal is replicate an existing application that was built using Shiny for R: [https://leviathan.ocean.dal.ca/rw_pam_map/]() (password: `narw123`).

## Data Processing

Data files are processed using various R scripts in the `r/` directory.

## Development

Run rollup in watch mode and serve with livereload:

```
yarn dev
```

## Production

Builds the application to `public/` folder.

```
yarn build
```

## Deployment

Deploy the files in `public/` to web server.

```
yarn deploy
```
