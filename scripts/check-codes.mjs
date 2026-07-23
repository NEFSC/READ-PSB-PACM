#!/usr/bin/env node
// Assert that every code in the published PACM data resolves to a label in the
// app's reference constants, and that the theme menu matches the exported theme
// directories. Run after regenerating the data / before publishing:
//
//   node scripts/check-codes.mjs [dataDir]
//
// dataDir defaults to r/data/pacm (the pipeline output). Exits non-zero on any
// unresolved code or theme/dir mismatch so it can gate a build.

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const dataDir = process.argv[2] || path.join(root, 'r/data/pacm')

const readJson = (p) => JSON.parse(fs.readFileSync(p, 'utf8'))

// label maps the app imports
const speciesMap = new Map(readJson(path.join(root, 'src/lib/species.json')).map((d) => [d.code, d.name]))
const platformMap = new Map(readJson(path.join(root, 'src/lib/platform_types.json')).map((d) => [d.code, d.name]))

// theme ids + presence enum, parsed from constants.js so the check tracks the app source
const constants = fs.readFileSync(path.join(root, 'src/lib/constants.js'), 'utf8')
const themeBlock = constants.slice(constants.indexOf('export const themes'), constants.indexOf('export const species'))
const themeIds = [...themeBlock.matchAll(/id:\s*'([^']+)'/g)].map((m) => m[1])
const presenceBlock = constants.slice(constants.indexOf('export const detectionTypes'))
const presenceCodes = new Set([...presenceBlock.matchAll(/id:\s*'([^']+)'/g)].map((m) => m[1]))

const errors = []
const add = (msg) => errors.push(msg)

// theme menu <-> exported directories
const dirs = fs.readdirSync(dataDir, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name)
for (const id of themeIds) {
  if (!dirs.includes(id)) add(`theme '${id}' is in the menu but has no exported directory`)
}
for (const dir of dirs) {
  if (!themeIds.includes(dir)) add(`directory '${dir}' is exported but has no menu entry`)
}

// codes in the data must resolve to a label
const badSpecies = new Set()
const badPlatform = new Set()
const badPresence = new Set()
for (const dir of dirs) {
  const detFile = path.join(dataDir, dir, 'detections.csv')
  if (fs.existsSync(detFile)) {
    const lines = fs.readFileSync(detFile, 'utf8').split('\n')
    const header = lines[0].split(',')
    const iSpecies = header.indexOf('species')
    const iPresence = header.indexOf('presence')
    for (let k = 1; k < lines.length; k++) {
      if (!lines[k]) continue
      const cells = lines[k].split(',')
      const species = cells[iSpecies]
      const presence = cells[iPresence]
      if (species && !speciesMap.has(species)) badSpecies.add(species)
      if (presence && !presenceCodes.has(presence)) badPresence.add(presence)
    }
  }

  const depFile = path.join(dataDir, dir, 'deployments.json')
  if (fs.existsSync(depFile)) {
    const raw = readJson(depFile)
    const features = Array.isArray(raw) ? raw : raw.features
    for (const f of features) {
      const props = f.properties || f
      if (props.platform_type && !platformMap.has(props.platform_type)) badPlatform.add(props.platform_type)
    }
  }
}

if (badSpecies.size) add(`species codes with no label: ${[...badSpecies].join(', ')}`)
if (badPlatform.size) add(`platform_type codes with no label: ${[...badPlatform].join(', ')}`)
if (badPresence.size) add(`presence codes not in the detectionTypes enum: ${[...badPresence].join(', ')}`)

if (errors.length) {
  console.error(`FAIL: ${errors.length} problem(s) in ${dataDir}`)
  errors.forEach((e) => console.error('  - ' + e))
  process.exit(1)
}

console.log(`OK: ${themeIds.length} themes, all species/platform_type/presence codes in ${path.relative(root, dataDir)} resolve to a label`)
