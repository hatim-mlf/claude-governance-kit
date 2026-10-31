// Dashboard sync — the entry point the SessionEnd hook runs.
//
// WHAT IT DOES
//   Regenerates the dashboard's catalogs when any watched source has changed, and
//   appends newly-published ledger entries to a sync log. If nothing has changed it
//   exits without running a generator at all.
//
// WHY THE TRIGGER IS NOT THE LEDGER ALONE
//   It used to be: the run exited early unless a ledger entry had changed status. That
//   made the ledger the only thing that could refresh anything, so a new report, a new
//   bug row or a release change regenerated nothing and the dashboard sat on its last
//   ledger-triggered state. Two independent conditions now trigger a run — a changed
//   source fingerprint, or an unpublished ledger entry — and either one is enough.
//
// WHY THERE IS A SEPARATE SYNC LOG
//   The ledger's own discipline is that a closed entry is not edited again. Recording
//   "synced" inside the entry would break that on every run. So sync state lives beside
//   the ledger in its own append-only file, keyed by entry ID — the ledger stays the
//   record of what happened, and the log stays the record of what has been published.
//
// Publication is keyed by the latest event's status and exact entry hash. Older
// events cannot prove current content. Reservation identity cannot change once
// fingerprinted; a new task requires a fresh ID.
//
// WHY THERE IS NO CRON TRIGGER
//   Decided against, not deferred. A scheduled process runs independently of any session,
//   which makes it a second writer to the same working tree — the untracked-concurrent-
//   state problem this whole system exists to prevent. The sync only ever runs as part of
//   a session that is already ending.

import { execFileSync } from 'node:child_process'
import { appendFileSync, existsSync, readFileSync, writeFileSync, mkdirSync, rmSync, renameSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { latestSyncEvents, catalogEntries } from '../../../scripts/lib/ledger_entry.mjs'
import { syncLogPath } from './project-paths.mjs'
import {
  computeSourceFingerprint,
  readStoredFingerprint,
  writeStoredFingerprint,
} from './source-fingerprint.mjs'

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url))
const appDirectory = path.resolve(scriptDirectory, '..')
const statePath = path.join(appDirectory, '.sync-state.json')

const GENERATORS = [
  'generate-ledger-catalog.mjs',
  'generate-config.mjs',
  'generate-bug-catalog.mjs',
  'generate-report-catalog.mjs',
  'generate-project-catalog.mjs',
  'generate-skills-catalog.mjs',
]

const SYNC_LOG_HEADER = [
  '# Dashboard sync log — append-only, written by scripts/sync-dashboard.mjs.',
  '# One line per changed ledger entry fingerprint published to the dashboard.',
  '# Never edited or reordered; the ledger itself is never edited to record sync state.',
  '# entry_id\tstatus\tsynced_at\tcontent_sha256\treservation_sha256',
].join('\n') + '\n'

function readSyncLog() {
  return latestSyncEvents(existsSync(syncLogPath) ? readFileSync(syncLogPath, 'utf8') : '')
}

function runGenerator(name, args = []) {
  return execFileSync(process.execPath, [path.join(scriptDirectory, name), ...args], {
    cwd: appDirectory,
    encoding: 'utf8',
  })
}

// One writer owns the catalog/log transaction. A killed owner leaves a lock and
// requires operator inspection; never silently steal it from a live session.
const lockPath = path.join(appDirectory, '.ledger-sync-lock')
const deadline = Date.now() + 10000
for (;;) {
  try { mkdirSync(lockPath); break }
  catch (error) {
    if (error.code !== 'EEXIST') throw error
    if (Date.now() >= deadline) throw new Error(`Ledger sync locked: ${lockPath}; inspect the owner before removing the lock.`)
    await new Promise(resolve => setTimeout(resolve, 100))
  }
}
async function sync() {
  // ── 1. Work out what is new ────────────────────────────────────────────────────
  // The ledger catalog generator is the single parser for ledger Markdown. Run it into a
  // temporary read so sync decisions and dashboard data can never disagree about what the
  // ledger says.
  const candidatePath = path.join(lockPath, 'ledgerCatalog.ts')
  runGenerator('generate-ledger-catalog.mjs', ['--output', candidatePath])

  const catalogPath = path.join(appDirectory, 'src', 'data', 'ledgerCatalog.ts')
  const catalogSource = readFileSync(candidatePath, 'utf8')
  const entries = catalogEntries(catalogSource)
  const alreadySynced = readSyncLog()
  const seen = new Set()
  const pending = entries.filter(entry => {
    if (seen.has(entry.id)) throw new Error(`Duplicate ledger heading: ${entry.id}`)
    seen.add(entry.id)
    const previous = alreadySynced.get(entry.id)
    if (previous?.reservationHash && previous.reservationHash !== entry.reservationHash && previous.contentHash !== entry.contentHash) {
      throw new Error(`Reservation identity changed for ${entry.id}; allocate a fresh ID.`)
    }
    // An unchanged exact raw entry can safely upgrade the identity hash algorithm;
    // changed source content cannot use that upgrade to reassign a reservation.
    return previous?.status !== entry.status || previous?.contentHash !== entry.contentHash || previous?.reservationHash !== entry.reservationHash
  })

  // Either condition is sufficient. A changed source with no new ledger entry is the
  // ordinary case for a report or a bug row; a new ledger entry with an unchanged
  // fingerprint cannot happen in practice but is handled rather than assumed away.
  const fingerprint = computeSourceFingerprint()
  const stored = readStoredFingerprint(statePath)
  const sourcesChanged = stored?.digest !== fingerprint.digest

  if (pending.length === 0 && !sourcesChanged) {
    console.log(
      `Dashboard sync: nothing new — no generator run. (${fingerprint.fileCount} source files unchanged)`,
    )
    renameSync(candidatePath, catalogPath)
    return
  }

  // ── 2. Publish ─────────────────────────────────────────────────────────────────
  if (sourcesChanged) {
    const reason = stored === null ? 'no previous fingerprint' : 'source files changed'
    console.log(`Dashboard sync: regenerating — ${reason} (${fingerprint.fileCount} files watched)`)
  }
  if (pending.length > 0) {
    console.log(`Dashboard sync: ${pending.length} ledger entr${pending.length === 1 ? 'y' : 'ies'} to publish`)
    for (const entry of pending) {
      const flag = entry.needsAttention ? '  ⚠ needs attention' : ''
      console.log(`  ${entry.id} [${entry.status}] ${entry.paths.length} path(s)${flag}`)
    }
  }

  for (const name of GENERATORS.slice(1)) {
    process.stdout.write(runGenerator(name))
  }

  renameSync(candidatePath, catalogPath)

  // ── 3. Record, append-only ─────────────────────────────────────────────────────
  // The fingerprint is written *after* the generators have run, so a generator that throws
  // leaves the stored digest stale and the next run retries rather than skipping.
  writeStoredFingerprint(statePath, computeSourceFingerprint())

  if (pending.length > 0) {
    if (!existsSync(syncLogPath)) writeFileSync(syncLogPath, SYNC_LOG_HEADER)
    const stamp = new Date().toISOString()
    appendFileSync(
      syncLogPath,
      pending.map((entry) => `${entry.id}\t${entry.status}\t${stamp}\t${entry.contentHash}\t${entry.reservationHash}`).join('\n') + '\n',
    )
  }

  const attention = pending.filter((entry) => entry.needsAttention)
  if (pending.length > 0) {
    console.log(`Dashboard sync: recorded ${pending.length} in ${path.relative(appDirectory, syncLogPath)}`)
  }
  if (attention.length > 0) {
    console.log(`Dashboard sync: ${attention.length} entr${attention.length === 1 ? 'y' : 'ies'} flagged for attention:`)
    for (const entry of attention) console.log(`  ⚠ ${entry.id} — ${entry.attentionReason}`)
  }

}
try {
  writeFileSync(path.join(lockPath, 'owner.json'), JSON.stringify({ pid: process.pid, startedAt: new Date().toISOString() }) + '\n')
  await sync()
} finally {
  rmSync(lockPath, { recursive: true })
}
