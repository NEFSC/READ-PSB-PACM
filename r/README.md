# PACM data pipeline (`r/`)

This directory holds the [`targets`](https://books.ropensci.org/targets/) data
pipeline that builds the datasets shown in the PACM web application. It ingests
passive-acoustic deployment and detection data, normalizes it into one canonical
schema, and writes the per-species theme files (`data/pacm/<theme>/*.json`) the
app consumes.

For the web application itself, see the [repository README](../README.md).

## Data sources

Since the PARS migration, the pipeline has **two** sources, each normalized into
the internal `pacm_names` schema before being merged in `pacm_data`:

| Source | Input | Loader |
|---|---|---|
| **Makara** | live Postgres database | [`R/makara.R`](R/makara.R) |
| **PARS** | submitted CSVs under `data-raw/pars/<id>/` | [`R/pars.R`](R/pars.R), [`R/pars-load.R`](R/pars-load.R) |

All non-Makara data — new submissions, the historical `PACM_20240820`
submissions, the `MAKARA_1.2` submissions, and the towed-array dataset — now
flows through the single **PARS** path. The old per-submission legacy loader and
the bespoke towed reader were removed once output parity was proven (see
[`tasks/legacy-parity-report.md`](../tasks/legacy-parity-report.md) and
[`tasks/towed-parity-report.md`](../tasks/towed-parity-report.md)).

## Layout

```
r/
├── _targets.R              # pipeline definition (target list)
├── packages.R              # attached packages
├── R/
│   ├── makara.R            # Makara DB source
│   ├── pars*.R             # PARS source: load, parse, validate, reference codes
│   ├── functions.R         # shared helpers (derive_sites/derive_tracks, legacy conversion)
│   ├── pacm.R              # merge sources -> pacm_data -> theme files
│   ├── compare.R           # baseline snapshot + parity comparison harness
│   ├── gis.R / ref.R       # GIS layers and reference tables
├── data-raw/
│   ├── pars/               # PARS submissions + manifest + reference-code snapshot/supplement
│   └── legacy/_rejected/   # excluded historical submissions (not loaded)
├── data/pacm/              # generated theme files (published output)
└── tests/testthat/         # unit + characterization tests
```

## Building

```r
# in R, from r/
targets::tar_make()          # full build; writes data/pacm/<theme>/*.json
targets::tar_outdated()      # what would rebuild
```

```sh
scripts/copy-data.sh         # publish data/pacm/* to ../public/data/ and enum JSONs to ../src/lib/
```

Makara connection details are read from `.env` (`MAKARA_*`). The PARS path needs
**no database** — its reference vocabulary is a vendored snapshot
(`data-raw/pars/reference_codes_makara.json`) plus a supplement CSV.

## Adding a submission

See the **[PARS submission intake runbook](../tasks/pars-intake-runbook.md)**.
In brief: drop the three PARS CSVs in `data-raw/pars/<id>/raw/`, add a row to
`data-raw/pars/submissions.csv`, run `make_pars("<id>")`, confirm
`tar_read(pars_errors)` is empty, then `tar_make()` and `scripts/copy-data.sh`.
A conforming submission needs no code; corrections go in a per-submission
`clean.R` (`raw/` → `clean.R` → `clean/`, never editing `raw/`).

## Tests

```r
# in R, from r/
testthat::test_dir("tests/testthat")
```
