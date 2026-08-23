// Shared path resolution for every dashboard generator — claude-governance-kit.
//
// WHY THIS FILE EXISTS
//
// Configured roots have vacated silently in the past: a generator that skips a
// missing root with `if (!existsSync(dir)) return []` produces a confidently wrong
// catalog instead of an error. Two rules follow, and this file implements both.
//
// FIRST: existence is not enough. A vacated root can be recreated as an empty
// shell by a tool while still being wrong — an existence check passes on that. So
// every root here is validated by a SENTINEL: a specific file that must be present
// inside it for the root to be the thing it claims to be. `requireRoot` throws —
// loudly, naming the root, the sentinel and the likely cause — rather than
// returning empty.
//
// SECOND: no environment variables. A variable that is read in three files and
// defined in none is not configuration; it is a surface that can retarget
// everything while appearing configurable. There is exactly one root — the git
// repository — found by walking up to `.git`, and one config file inside it:
// `governance.config.json`. Per-project layout lives there, nowhere else.

import { existsSync, mkdirSync, readFileSync, realpathSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url))

// Every generator writes into src/data. A fresh install has no such directory
// (generated data is never committed), so create it once here rather than in
// five places.
mkdirSync(path.resolve(scriptDirectory, '..', 'src', 'data'), { recursive: true })

function findRepositoryRoot(startDirectory) {
  let directory = realpathSync(startDirectory)
  for (;;) {
    if (existsSync(path.join(directory, '.git'))) return directory
    const parent = path.dirname(directory)
    if (parent === directory) return null
    directory = parent
  }
}

/**
 * Fail loudly when a configured root is missing or is not what it claims to be.
 *
 * @param {string} label     human name, used in the error
 * @param {string} rootPath  absolute path to validate
 * @param {string} sentinel  path, relative to rootPath, that must exist
 * @param {string} because   what this root is for, shown when it fails
 * @returns {string} rootPath, unchanged, when valid
 */
export function requireRoot(label, rootPath, sentinel, because) {
  const sentinelPath = path.join(rootPath, sentinel)
  if (existsSync(sentinelPath)) return rootPath

  const reason = existsSync(rootPath)
    ? `the directory exists but does not contain ${sentinel}`
    : 'the directory does not exist'

  throw new Error(
    [
      '',
      `Configured root is not valid: ${label}`,
      `  path:     ${rootPath}`,
      `  expected: ${sentinel}`,
      `  problem:  ${reason}`,
      `  used for: ${because}`,
      '',
      '  This is deliberately fatal. A generator that skips a missing root',
      '  produces a confidently wrong catalog instead of an error. If the',
      '  layout moved, fix the path in governance.config.json.',
      '',
    ].join('\n'),
  )
}

const foundRoot = findRepositoryRoot(scriptDirectory)
if (!foundRoot) {
  throw new Error(
    [
      '',
      'Could not locate the git repository root.',
      `  searched upward from: ${scriptDirectory}`,
      '  looked for a .git directory and reached the filesystem root first.',
      '',
      '  The generators resolve every input from the repository root. If this',
      '  checkout has no .git, run them from one that does.',
      '',
    ].join('\n'),
  )
}

// ---------------------------------------------------------------- the config
// The one piece of per-project input. Everything else is derived from it.

const configPath = path.join(foundRoot, 'governance.config.json')
if (!existsSync(configPath)) {
  throw new Error(
    [
      '',
      'governance.config.json not found at the repository root.',
      `  looked for: ${configPath}`,
      '',
      '  This file is how the dashboard learns your project layout. Copy the',
      '  template from the claude-governance-kit and fill in the placeholders.',
      '',
    ].join('\n'),
  )
}

/** @type {{ projectName: string, projectShortName: string, tracker: string,
 *          roots: Record<string, { path: string, sentinel: string }>,
 *          dashboard: { dir: string, syncLog: string, hookLog: string } }} */
export const config = JSON.parse(readFileSync(configPath, 'utf8'))

if (!config.projectName || config.projectName.includes('YOUR PROJECT NAME')) {
  throw new Error(
    [
      '',
      'governance.config.json still has placeholder values.',
      `  file: ${configPath}`,
      '  Set projectName, projectShortName, and the roots for your project.',
      '',
    ].join('\n'),
  )
}

function configuredRoot(key, because) {
  const entry = config.roots?.[key]
  if (!entry) {
    throw new Error(`governance.config.json has no roots.${key} entry (needed for ${because})`)
  }
  return requireRoot(key, path.join(foundRoot, entry.path), entry.sentinel, because)
}

/** The git repository root. Every other path is derived from it. */
export const repositoryRoot = configuredRoot('repository', 'the project catalog, and as the base for every other root')

/** The reports tree: bugs, errors, audits, sessions, verification. */
export const reportsRoot = configuredRoot('reports', 'the report catalog and the bug tracker')

/** The ledger — one Markdown file per ISO week, each holding many task entries. */
export const ledgerRoot = configuredRoot('ledger', 'the ledger catalog and the dashboard sync')

/** The project's own source tree. Used by the project-file inventory. */
export const sourceRoot = configuredRoot('source', 'the project-file inventory')

/** The live bug tracker, from config. */
export const trackerPath = path.join(foundRoot, config.tracker)
if (!existsSync(trackerPath)) {
  throw new Error(
    [
      '',
      'Configured bug tracker is not valid:',
      `  path:     ${trackerPath}`,
      `  problem:  ${existsSync(path.dirname(trackerPath)) ? 'the directory exists but the tracker file is not in it' : 'the directory does not exist'}`,
      '  used for: the bug catalog',
      '',
      '  Fix the "tracker" path in governance.config.json.',
      '',
    ].join('\n'),
  )
}

/** Where the sync records what it has published. */
export const syncLogPath = path.join(foundRoot, config.dashboard?.syncLog ?? path.join('ledger', 'SYNC_LOG.tsv'))
