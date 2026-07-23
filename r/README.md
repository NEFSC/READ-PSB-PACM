# PACM data pipeline (`r/`)

This directory holds the [`targets`](https://books.ropensci.org/targets/) data
pipeline that builds the datasets shown in the PACM web application. It ingests
passive-acoustic deployment and detection data, normalizes it into one canonical
schema, and writes the per-species theme files (`data/pacm/<theme>/*.json`) the
app consumes.

For the web application itself, see the [repository README](../README.md).

## Data sources

The pipeline has **two** sources, each normalized into the internal `pacm_names`
schema before being merged in `pacm_data`:

| Source | Input | Loader |
|---|---|---|
| **Makara** | live Postgres database | [`R/makara.R`](R/makara.R) |
| **PARS** | submitted CSVs under `data-raw/pars/<id>/` | [`R/pars.R`](R/pars.R), [`R/pars-load.R`](R/pars-load.R) |

All non-Makara data — new submissions, the historical `PACM_20240820`
submissions, the `MAKARA_1.2` submissions, and the towed-array dataset — flows
through the single **PARS** path. The old per-submission legacy loader and the
bespoke towed reader were removed once output parity with the pre-migration
build was proven.

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
│   └── pars/_rejected/     # excluded historical submissions (not loaded)
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

## Tests

```r
# in R, from r/
testthat::test_dir("tests/testthat")
```

---

## Adding a submission

Every non-Makara data source flows through one path: a per-submission directory
under `data-raw/pars/`, validated against the PARS schema, loaded by
`load_pars()`, and published into the per-species theme files the web app reads.
All paths below are relative to `r/`.

### A conforming submission (TL;DR)

A submission that already conforms to the PARS schema (no corrections needed)
takes four steps and **no code**:

```r
# 1. put the files in place (shell)
#    data-raw/pars/<submission_id>/raw/{metadata,detectiondata[,gpsdata]}.csv
# 2. add one row to data-raw/pars/submissions.csv:
#    <submission_id>,PARS_1.0,,
# 3. load it and confirm it validates clean (in R, from r/)
make_pars("<submission_id>")
tar_read(pars_errors)            # must be 0 rows
# 4. rebuild + publish
tar_make()                       # regenerates data/pacm/<theme>/*.json
# then, in shell:  scripts/copy-data.sh
```

If validation reports errors that are genuine data problems in the submission,
add a `clean.R` (see *Correct with a `clean.R`*, below) — that is the only
additional step.

### What a submission is

A PARS submission is **three fixed-name CSVs** (the third optional):

| File | Grain | Required |
|---|---|---|
| `metadata.csv` | one row per deployment | yes |
| `detectiondata.csv` | one row per detection / daily effort record | yes |
| `gpsdata.csv` | one row per position | **only** for mobile platforms |

Field-by-field definitions live in the PARS submission guide
(<https://passiveacoustics.fisheries.noaa.gov/pars/guide>); the column contracts
the loader parses are in [`R/pars-parse.R`](R/pars-parse.R).

Mobile vs. stationary is decided by `deployment_platform_type_code`:
`DRIFTING_BUOY`, `ELECTRIC_GLIDER`, `TOWED_ARRAY`, `WAVE_GLIDER` are mobile and
**must** carry `gpsdata.csv`; everything else is stationary and must **not**
(`PARS_MOBILE_PLATFORM_TYPES` in [`R/pars-load.R`](R/pars-load.R), guarded
against drift by the `pars_platform_type_drift` target).

### The `raw/` → `clean.R` → `clean/` convention

```
data-raw/pars/<submission_id>/
├── raw/                 # the files exactly as submitted — NEVER edited
│   ├── metadata.csv
│   ├── detectiondata.csv
│   └── gpsdata.csv      # mobile only
├── clean.R              # OPTIONAL — corrections only; absent when none needed
└── clean/               # what the loader reads; produced by clean.R
    ├── metadata.csv
    ├── detectiondata.csv
    └── gpsdata.csv
```

Two rules make this safe and reproducible:

- **`raw/` is immutable.** Every correction is expressed as code in `clean.R`,
  so the delta from what was submitted is always visible and reviewable. Never
  hand-edit a file under `raw/`.
- **The loader reads `clean/` when it exists, otherwise `raw/`.** A conforming
  submission has no `clean.R` and no `clean/`, and `load_pars()` reads `raw/`
  directly. A submission that *has* a `clean.R` but whose `clean/` was never
  generated is a **mistake, not a conforming submission** — the loader stops and
  tells you to run `clean_pars()`, rather than silently ingesting the raw values
  the `clean.R` exists to fix (see `load_pars` in [`R/pars-load.R`](R/pars-load.R)).

#### What belongs in a `clean.R`

- **Data corrections only** — unit fixes, typos, malformed values, encoding
  repair. Example: USYRA submitted `recording_sample_rate_khz` in Hz (`48000`)
  instead of kHz; its `clean.R` divides by 1000
  ([`data-raw/pars/USYRA_20260713/clean.R`](data-raw/pars/USYRA_20260713/clean.R)).
- **Legacy-format conversion** — for the historical `PACM_20240820` and
  `MAKARA_1.2` submissions, `clean.R` reads the old-format `raw/` files and calls
  the shared converter `convert_legacy_submission()`
  ([`R/functions.R`](R/functions.R)), which writes PARS-format files to `clean/`.
  See any converted submission, e.g.
  [`data-raw/pars/DFOCA_20211124/clean.R`](data-raw/pars/DFOCA_20211124/clean.R).
  New submissions arrive in PARS format and never need this.

#### What must NOT go in a `clean.R`

- **Schema reshaping of PARS input.** PARS submissions already arrive in the
  target schema. A `clean.R` that renames or restructures PARS columns means
  something is wrong upstream — raise it with the submitter, don't paper over it.
- **Anything that isn't reproducible from `raw/`.** No hand-authored data, no
  one-off external files. Re-running a `clean.R` on unchanged `raw/` must produce
  identical `clean/`.

#### Every correcting `clean.R` carries a re-run guard

A correction must **fail loudly if the underlying data changes**, so a corrected
resubmission is never silently converted twice. USYRA's guard:

```r
# submitter reported recording_sample_rate_khz in Hz (48000) rather than kHz (48)
# guard fires if a corrected submission arrives, to avoid converting twice
stopifnot(all(as.numeric(metadata$recording_sample_rate_khz) >= 1000))
```

If the submitter later re-sends the file already in kHz, the `stopifnot` trips
instead of dividing 48 down to 0.048.

#### Always report the correction back to the submitter

A `clean.R` fixes the data here, but the submitter's next package should be
correct at the source. File the correction with them so the gap closes upstream.

### Step-by-step intake

#### 1. Receive and place the files

Copy the submitted files verbatim into `data-raw/pars/<submission_id>/raw/`.
Pick a `submission_id` matching the existing convention — `<ORG>_<YYYYMMDD>`
(e.g. `USYRA_20260713`), optionally with a suffix
(`JASCO_20260114_EW1-June-October`). These files are gitignored
(`data-raw/**/*.csv`), so this is a working-tree change only.

#### 2. Add a manifest row

Append one line to
[`data-raw/pars/submissions.csv`](data-raw/pars/submissions.csv):

```
submission_id,format,skip,comment
```

| Column | Value |
|---|---|
| `submission_id` | the directory name from step 1 |
| `format` | `PARS_1.0` for a native PARS submission; `PARS_LEGACY` only for a submission converted from the old formats (never for new data) |
| `skip` | **blank** to load it; any non-blank value skips it (`load_pars` warns and returns `NULL`) — use to park an incomplete submission without deleting it |
| `comment` | free text (optional) |

`format` selects the validation profile via `pars_profile_for_format()`:
`PARS_1.0` is **strict**; `PARS_LEGACY` relaxes only a short, explicit list of
*presence* and *cardinality* requirements (`PARS_LEGACY_OPTIONAL` /
`pars_list_valued()` in [`R/pars-validate.R`](R/pars-validate.R)). It never
relaxes type, range, vocabulary, or referential checks — those catch real
defects (the USYRA sample-rate error was a range check). **Use `PARS_LEGACY`
only for the historical conversions; new submissions are always validated
strictly.**

The manifest is version-controlled (`.gitignore` negation
`!data-raw/*/submissions.csv`) — it *is* the pipeline definition, so commit it
with the intake.

#### 3. Validate

```r
make_pars("<submission_id>")   # loads just this submission, then rebuilds `pars`
tar_read(pars_errors)          # tibble of row-level errors; 0 rows == clean
```

`pars_errors` combines three things: per-file schema/vocabulary/range errors,
placeholder errors (a literal `NA`/`NULL`/`-` where PARS wants a blank), and the
**global** referential check (`pars_referential`). Referential integrity is
global by design: a submission may analyse a deployment another submission
provided — e.g. JASCO analysing DFO's recorders — so a `deployment_code` in
`detectiondata.csv` need only exist in *some* submission's metadata, not this
one's.

Read each error's `name`, `row`, and `actual` to locate the problem. If the
errors are genuine data problems, add a `clean.R` (next); if a value is
legitimate but has no official code yet, add a supplement code (below).

#### 4. Correct with a `clean.R` (only if needed)

Write `data-raw/pars/<submission_id>/clean.R` following the convention above:
read `raw/`, apply the minimal correction, add a re-run guard, write `clean/`.
Then:

```r
clean_pars("<submission_id>")  # runs the clean.R, producing clean/
make_pars("<submission_id>")   # reload
tar_read(pars_errors)          # confirm 0
```

#### 5. Add a supplement code (only if a value has no official code)

Validation checks every coded field against `pars_codes` — the union of a
**vendored Makara snapshot** (`reference_codes_makara.json`) and a
**hand-maintained supplement**
([`data-raw/pars/reference_codes_supplement.csv`](data-raw/pars/reference_codes_supplement.csv)).
Because the vocabulary is vendored, validation needs **no database connection**.

When a submission carries a legitimate value with no official PARS code yet
(a detector name, an instrument model), add a supplement row rather than forcing
the value into `OTHER`:

```
table,code,label,rationale,date_added
detectors,MATLAB,MATLAB-based automated detector,legacy detector with no official code; ...,2026-07-22
```

Every column is required; a blank `rationale` is rejected
(`validate_supplement()` in [`R/pars-ref.R`](R/pars-ref.R)). Supplement codes
stay **visible** rather than becoming shadow vocabulary:

- `tar_read(pars_codes_report)` lists every supplement code in use and flags any
  that upstream Makara has since adopted (`retirable == TRUE`).
- `tar_read(pars_codes_drift)` (needs a DB connection) reports what changed in
  Makara since the snapshot. Review it, then regenerate deliberately with
  `refresh_reference_code_snapshot()` — the snapshot is never overwritten as a
  side effect of a build.

Retire a supplement code once it is adopted upstream.

#### 6. Rebuild and publish

```r
tar_make()            # rebuilds pacm_data and the theme files under data/pacm/
```

`tar_make()` regenerates
`data/pacm/<theme>/{sites,deployments,detections,tracks}.json` via the
`pacm_themes_files` target. To push them to the app:

```sh
scripts/copy-data.sh  # copies data/pacm/* -> ../public/data/, and the two enum JSONs -> ../src/lib/
```

Then verify in the running app. New PARS reference values (species, platform
types, and any new supplement codes) may also need syncing into the web-app enums
— see `../src/lib/constants.js` and the `../scripts/check-codes.mjs` assertion.

### The `tar_cue(mode = "never")` pattern

The per-submission load targets (`pars_sub_<id>`, built by `tar_map` over the
manifest in [`R/pars.R`](R/pars.R)) are declared with `cue = tar_cue(mode =
"never")`. Once a submission is loaded, `targets` will **not** reload it on later
builds — not even when the loader code or its inputs change.

Why: submissions are immutable inputs, and re-parsing every submission (hundreds
of thousands of detection rows) on every unrelated pipeline change would be slow
and pointless. The trade-off is that reloading is **explicit**:

```r
make_pars("<submission_id>")   # invalidate just this submission's target, then tar_make(pars)
make_pars()                    # invalidate ALL pars_sub_* and reload everything
```

`make_pars()` ([`R/pars.R`](R/pars.R)) is the intended entry point — it calls
`tar_invalidate()` on the relevant `pars_sub_*` targets and then `tar_make(pars)`.
Use it whenever you add a submission, edit a `clean.R`, or change loader/parser
code and want the change to take effect. A brand-new manifest row builds on the
first `tar_make` without an explicit invalidate (the target didn't exist yet).

The same `mode = "never"` pattern is why routine `tar_make()` runs stay fast and
why editing `pars-load.R` does not silently re-parse every historical submission.

### Command reference

| Goal | Command (run in R, from `r/`) |
|---|---|
| Run one submission's `clean.R` | `clean_pars("<id>")` |
| Run all `clean.R` scripts | `clean_pars_all(pars_manifest$submission_id)` |
| Reload one submission | `make_pars("<id>")` |
| Reload all submissions | `make_pars()` |
| Inspect validation errors | `tar_read(pars_errors)` |
| Inspect supplement codes in use | `tar_read(pars_codes_report)` |
| Inspect reference-code drift (needs DB) | `tar_read(pars_codes_drift)` |
| Regenerate the vendored snapshot (needs DB) | `refresh_reference_code_snapshot()` |
| Full rebuild + write theme files | `tar_make()` |
| Publish to the app (shell) | `scripts/copy-data.sh` |

### Current submissions

`data-raw/pars/` holds all active submissions: the live USYRA production
submission (`PARS_1.0`) plus the converted historical `PACM_20240820`,
`MAKARA_1.2`, and towed-array (`TOWED_LEGACY`) submissions (`PARS_LEGACY`). Each
directory preserves its original `raw/` files — converted submissions were
**moved**, never rewritten in place. `data-raw/pars/_rejected/` holds any rejected
submissions.
