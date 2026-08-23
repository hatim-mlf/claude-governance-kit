// Source fingerprint — what the dashboard sync uses to decide whether anything changed.
//
// WHY THIS EXISTS
//   The sync used to gate solely on the ledger: if no entry had changed status it exited
//   without running a generator. That made the ledger the only thing that could ever
//   trigger a refresh, so a new report, a new bug row, or a release change regenerated
//   nothing and the dashboard showed the last ledger-triggered state indefinitely. That
//   was the cause of "the reports never get updated automatically".
//
// WHY NOT JUST ALWAYS REGENERATE
//   Tried, and it is wrong here. generate-project-catalog embeds each file's mtime, and
//   the files it inventories include the generated catalogs themselves — so every run
//   changes its own next input and the working tree is dirtied on every session end
//   forever. A gate is required; it just has to watch the right thing.
//
// WHAT IS AND IS NOT WATCHED
//   The repository content the catalogs are derived from. The dashboard's own directory
//   is excluded deliberately — including it would reintroduce exactly the self-feeding
//   loop above, since the generated output lives inside it.

import { createHash } from 'node:crypto'
import { readdirSync, statSync, existsSync, readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'

import { repositoryRoot, config } from './project-paths.mjs'

/**
 * Files the sync itself writes. They live under a watched root but are bookkeeping,
 * not source: including SYNC_LOG.tsv means every run invalidates its own fingerprint
 * and the next run always sees "changed" — the self-feeding loop this gate exists to
 * avoid, one level up. Found by running the sync twice and watching the second run
 * regenerate when it should have been a no-op.
 */
const SKIP_FILES = new Set(['SYNC_LOG.tsv'])

/** Directory names skipped anywhere in the tree. */
const SKIP_DIRECTORIES = new Set([
  '.git',
  'node_modules',
  'dist',
  'build',
  '.build',
  'DerivedData',
  '.swiftpm',
  // The dashboard itself — see the header note. Taken from config so a project
  // that installs it under a different directory name is still excluded.
  (config.dashboard?.dir ?? 'bug-tracker-dashboard/app').split('/')[0],
])

/**
 * Roots whose contents feed a generator, relative to the repository root —
 * read from governance.config.json rather than hardcoded, so the watched set
 * is the project's own layout.
 */
const WATCHED = Object.values(config.roots ?? {})
  .map((root) => root.path)
  .filter((p) => p && p !== '.')

/** Loose files at the repository root that feed a catalog or the review flow. */
const WATCHED_ROOT_FILES = [
  'STRUCTURAL_PROBLEMS.md',
  'FILE_SIZE_REVIEW.md',
  'MODEL_DELEGATION.md',
  'CONTEXT.md',
  'CLAUDE.md',
  'governance.config.json',
]

function walk(absolute, relative, out) {
  let entries
  try {
    entries = readdirSync(absolute, { withFileTypes: true })
  } catch {
    return
  }
  for (const entry of entries) {
    if (entry.name.startsWith('.') && entry.name !== '.claude') continue
    const childAbsolute = path.join(absolute, entry.name)
    const childRelative = relative ? `${relative}/${entry.name}` : entry.name
    if (entry.isDirectory()) {
      if (SKIP_DIRECTORIES.has(entry.name)) continue
      walk(childAbsolute, childRelative, out)
    } else if (entry.isFile()) {
      if (SKIP_FILES.has(entry.name)) continue
      let stats
      try {
        stats = statSync(childAbsolute)
      } catch {
        continue
      }
      out.push(`${childRelative}\t${stats.size}\t${Math.round(stats.mtimeMs)}`)
    }
  }
}

/**
 * A stable digest of every watched source file's path, size and mtime.
 * Content is not read — size plus mtime is enough to notice an edit, and reading
 * ~1,000 files on every session end to gain nothing would be the wrong trade.
 */
export function computeSourceFingerprint() {
  const lines = []
  for (const name of WATCHED) {
    const absolute = path.join(repositoryRoot, name)
    if (existsSync(absolute)) walk(absolute, name, lines)
  }
  for (const name of WATCHED_ROOT_FILES) {
    const absolute = path.join(repositoryRoot, name)
    if (!existsSync(absolute)) continue
    const stats = statSync(absolute)
    lines.push(`${name}\t${stats.size}\t${Math.round(stats.mtimeMs)}`)
  }
  lines.sort()
  return {
    digest: createHash('sha256').update(lines.join('\n')).digest('hex'),
    fileCount: lines.length,
  }
}

export function readStoredFingerprint(statePath) {
  if (!existsSync(statePath)) return null
  try {
    return JSON.parse(readFileSync(statePath, 'utf8'))
  } catch {
    return null // unreadable state means "regenerate", never "skip"
  }
}

export function writeStoredFingerprint(statePath, fingerprint) {
  writeFileSync(
    statePath,
    JSON.stringify({ ...fingerprint, updatedAt: new Date().toISOString() }, null, 2) + '\n',
  )
}
