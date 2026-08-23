// Generates src/data/ledgerCatalog.ts from ledger/*.md.
//
// WHY THIS IS A SEPARATE GENERATOR, not a new root on the report catalog.
//
// WORKFLOW.md already recorded the reason, and it still holds: the report catalog is
// FILE-level. It hashes a file, stores metadata, and emits one entry per file. Point it
// at ledger/ and you get one entry per ISO WEEK — three entries for a project with
// thirty tasks — because a week file is one file containing many entries.
//
// The ledger's unit is the entry, not the file. So this parses entries out of the
// Markdown and emits one catalog row per task, which is the thing anyone would actually
// want to see on a dashboard.
//
// Roots are resolved and sentinel-validated in project-paths.mjs — see the note there on
// why they are found rather than configured.

import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { repositoryRoot, ledgerRoot } from './project-paths.mjs'

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url))
const appDirectory = path.resolve(scriptDirectory, '..')
const outputPath = path.join(appDirectory, 'src', 'data', 'ledgerCatalog.ts')

// A week file is named 2026-W34.md. README.md and anything else is not a week file.
const WEEK_FILE = /^\d{4}-W\d{2}\.md$/
// Entry headings are `## 2026-W34-05 — Title`.
const ENTRY_HEADING = /^##\s+(\d{4}-W\d{2}-\d{2})\s+—\s+(.+?)\s*$/
// Field lines are `**Name:** value`.
const FIELD = /^\*\*(.+?):\*\*\s*(.*)$/

/**
 * Pull repository-relative paths out of a "Files actually touched" block.
 *
 * The contract is in ledger/README.md: backtick real paths, leave prose unbackticked.
 * Anything backticked that does not resolve to a real file is dropped, which is what
 * makes prose like `4 × SKILL.md` or "the backup above" harmless without asking anyone
 * to write the block differently than they already do.
 *
 * `Not touched:` is skipped outright — it is negative space, and counting it would
 * invert its meaning.
 */
/**
 * Pull repository-relative paths out of an "Expected files" block.
 *
 * Deliberately *not* existence-filtered, unlike extractPaths. An expected file is
 * frequently one that does not exist yet — the block routinely reads "`…/foo.swift`
 * (new)" — so requiring the file on disk would drop precisely the entries the field
 * exists to record. Prose is excluded by shape instead: a token counts only if it looks
 * like a path, meaning it contains a slash or ends in a short extension. That keeps
 * inline code such as `isLoading` or `AccountScopedDomain` out without asking anyone to
 * write the block differently than they already do.
 */
function extractExpectedPaths(blockLines) {
  const found = new Set()
  for (const line of blockLines) {
    for (const match of line.matchAll(/`([^`]+)`/g)) {
      const candidate = match[1].trim()
      if (!candidate || candidate.includes(' × ')) continue
      // Globs are excluded: `src/components/**` is a statement of intent about a region,
      // not a file, and listing it as "expected but not touched" is noise rather than
      // signal. Directories are kept — `docs/FIX_LOG/` going untouched is exactly the
      // kind of dropped intent this field is meant to surface.
      if (candidate.includes('*')) continue
      const looksLikePath = candidate.includes('/') || /\.\w{1,5}$/.test(candidate)
      if (looksLikePath) found.add(candidate)
    }
  }
  return [...found]
}

function extractPaths(blockLines) {
  const found = new Set()
  let active = false

  for (const line of blockLines) {
    const prefix = line.match(/^(Created|Modified|Deleted|Moved|Not touched):/)
    if (prefix) active = prefix[1] !== 'Not touched'
    if (!active) continue

    for (const match of line.matchAll(/`([^`]+)`/g)) {
      const candidate = match[1].trim()
      if (!candidate || candidate.includes(' × ')) continue
      const absolute = path.join(repositoryRoot, candidate)
      if (existsSync(absolute) && statSync(absolute).isFile()) found.add(candidate)
    }
  }

  return [...found].sort((left, right) => left.localeCompare(right, 'en'))
}

/** `yes — reason` / `no` / absent. Absent means no; see ledger/README.md. */
function parseAttention(raw) {
  if (!raw) return { needsAttention: false, attentionReason: '' }
  const normalised = raw.trim()
  if (!/^yes\b/i.test(normalised)) return { needsAttention: false, attentionReason: '' }
  const reason = normalised.replace(/^yes\b/i, '').replace(/^\s*[—-]\s*/, '').trim()
  return { needsAttention: true, attentionReason: reason }
}

function parseWeekFile(absolutePath, weekId) {
  const lines = readFileSync(absolutePath, 'utf8').split('\n')
  const entries = []
  let current = null
  let pathsBlock = null
  // Ledger prose wraps at ~90 characters, so a field's value routinely continues on the
  // next line. Reading only the first line silently truncates it — which showed up as an
  // attention reason cut off mid-sentence. These fields accumulate until a blank line or
  // the next `**Bold:**`.
  let wrapped = null

  // A "Files actually touched" block runs until the next `**Bold:**` field or the end of
  // the entry, whichever comes first. Both terminators must harvest it — closing on the
  // field boundary while only harvesting at the end of the entry silently loses the paths
  // for every entry that has a `**Verified by:**` after the block, which is most of them.
  const closePathsBlock = () => {
    if (current && pathsBlock) {
      if (pathsBlock.key === 'expectedPaths') {
        current.expectedPaths = extractExpectedPaths(pathsBlock.lines)
      } else {
        current.paths = extractPaths(pathsBlock.lines)
      }
    }
    pathsBlock = null
  }

  const WRAPPED_FIELDS = { Summary: 'summary', 'Needs attention': 'attention' }

  const closeWrapped = () => {
    if (!current || !wrapped) return
    const text = wrapped.lines.join(' ').replace(/\s+/g, ' ').trim()
    // Dispatch on the key explicitly. This used to fall through to `summary` for
    // anything that was not `attention`, which meant adding a third wrapped field
    // silently overwrote every entry's summary with it.
    if (wrapped.key === 'attention') Object.assign(current, parseAttention(text))
    else if (wrapped.key === 'verifiedBy') current.verifiedBy = text.replace(/`/g, '')
    else if (wrapped.key === 'summary') current.summary = text.replace(/`/g, '')
    wrapped = null
  }

  const finish = () => {
    if (!current) return
    closeWrapped()
    closePathsBlock()
    entries.push(current)
    current = null
  }

  for (const line of lines) {
    const heading = line.match(ENTRY_HEADING)
    if (heading) {
      finish()
      current = {
        id: heading[1],
        week: weekId,
        title: heading[2],
        status: 'open',
        model: '',
        sessionPrompt: '',
        reservedAt: '',
        closedAt: '',
        summary: '',
        report: '',
        needsAttention: false,
        attentionReason: '',
        verifiedBy: '',
        verification: 'absent',
        timestampIssue: '',
        paths: [],
        expectedPaths: [],
      }
      continue
    }
    if (!current) continue

    // `### Closed — 2026-08-17 08:05 +01`
    const closed = line.match(/^###\s+Closed\s+—\s+(.+?)\s*$/)
    if (closed) {
      current.status = 'closed'
      current.closedAt = closed[1]
      continue
    }

    if (pathsBlock) {
      if (FIELD.test(line)) closePathsBlock()
      else { pathsBlock.lines.push(line); continue }
    }

    if (wrapped) {
      if (line.trim() === '' || FIELD.test(line) || line.startsWith('#')) closeWrapped()
      else { wrapped.lines.push(line.trim()); continue }
    }

    const field = line.match(FIELD)
    if (!field) continue
    const [, name, value] = field
    const clean = value.replace(/`/g, '').trim()

    switch (name) {
      case 'Reserved':        current.reservedAt = clean; break
      case 'Model':           current.model = clean; break
      case 'Session prompt':  current.sessionPrompt = clean; break
      case 'Summary':         wrapped = { key: 'summary', lines: [value.trim()] }; break
      case 'Report':          current.report = clean; break
      case 'Status':
        // The `**Status:**` line carries ✅/🟡; the `### Closed` heading is
        // authoritative, so only upgrade to closed, never back to open.
        if (/closed/i.test(clean)) current.status = 'closed'
        break
      case 'Needs attention': wrapped = { key: 'attention', lines: [value.trim()] }; break
      case 'Verified by':     wrapped = { key: 'verifiedBy', lines: [value.trim()] }; break
      case 'Files actually touched': pathsBlock = { key: 'paths', lines: [] }; break
      // Written at reserve time, so it is the only file information an open entry has.
      // Without it the ledger view reports "0 files touched" for every entry in flight —
      // not stale, structurally impossible to populate.
      case 'Expected files': pathsBlock = { key: 'expectedPaths', lines: [] }; break
      default: break
    }
  }

  finish()
  return audit(entries)
}

/**
 * Mirrors `scripts/check-ledger-entries.sh`. The hook warns at commit time about the
 * entry you are writing; this makes the same facts visible for every entry that already
 * landed. Keep the two rule sets in step — if you change one, change the other, and say
 * so in both. They are separate because a pre-commit hook cannot render a dashboard and
 * a generator cannot refuse a commit.
 *
 * Register row U-15: these stamps are prose, nothing rejected a wrong one, and six were
 * fabricated across three sessions before anything compared them.
 */
// What counts as naming evidence. Deliberately wide: a file this repository actually
// produces, a test, a capture, a command that was run, or an exit code. It started
// Swift-only, which scored every dashboard and tooling session as unevidenced.
// Mirrored in scripts/check-ledger-entries.sh — change both together.
const EVIDENCE =
  /test|capture|scenario|exit \d|xcodebuild|npm run|node |\.(md|swift|ts|tsx|mjs|sh|json|html|png|mov|tsv|pbxproj)|diff|`/i
const BUILD_ONLY = /build|compile/i

function audit(entries) {
  // Lexical comparison on "YYYY-MM-DD HH:MM" is correct while two stamps share a UTC
  // offset, and the offsets here are prose too. Mixed offsets are reported, never
  // compared — same reasoning as the shell check.
  const at = (raw) => (raw.match(/\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}/) || [''])[0]
  const off = (raw) => (raw.match(/[-+]\d{2}:?\d{2}\s*$/) || [''])[0].replace(/[\s:]/g, '')
  const now = new Date()
  const pad = (n) => String(n).padStart(2, '0')
  const nowStamp = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ` +
                   `${pad(now.getHours())}:${pad(now.getMinutes())}`

  let prevClosed = ''
  let prevOff = ''
  let prevId = ''

  for (const entry of entries) {
    // A good closing block often does BOTH: it names what was verified and then says
    // plainly what was not. Testing for "not verified" first scored those as `declared`,
    // the same as an entry that verified nothing — penalising exactly the honesty this
    // whole bar exists to encourage. So split the caveat off and judge the positive
    // claim on its own; the caveat only decides the outcome when nothing is left.
    const body = entry.verifiedBy || ''
    const split = body.search(/not verified/i)
    const claimed = split === -1 ? body : body.slice(0, split)
    const caveated = split !== -1

    if (entry.status !== 'closed') entry.verification = 'open'
    else if (!body) entry.verification = 'absent'
    else if (EVIDENCE.test(claimed)) entry.verification = 'evidenced'
    else if (caveated) entry.verification = 'declared'
    else if (BUILD_ONLY.test(claimed)) entry.verification = 'weak'
    else entry.verification = 'evidenced'

    const r = at(entry.reservedAt), c = at(entry.closedAt)
    const ro = off(entry.reservedAt), co = off(entry.closedAt)
    const issues = []
    if (r && c && ro === co && c < r) issues.push(`closed ${c} precedes its own reserved ${r}`)
    if (c && c > nowStamp) issues.push(`closed ${c} is in the future`)
    if (r && prevClosed && ro === prevOff && r < prevClosed)
      issues.push(`reserved ${r} precedes ${prevId} closing at ${prevClosed}`)
    if (r && c && ro && co && ro !== co) issues.push(`mixed UTC offsets (${ro} vs ${co}) — not compared`)
    entry.timestampIssue = issues.join('; ')

    if (c) { prevClosed = c; prevOff = co; prevId = entry.id }
  }
  return entries
}

if (!existsSync(ledgerRoot)) {
  throw new Error(`Ledger root does not exist: ${ledgerRoot}`)
}

const weekFiles = readdirSync(ledgerRoot)
  .filter((name) => WEEK_FILE.test(name))
  .sort((left, right) => left.localeCompare(right, 'en'))

const entries = weekFiles
  .flatMap((name) => parseWeekFile(path.join(ledgerRoot, name), name.replace(/\.md$/, '')))
  // Newest first — the dashboard reads top-down.
  .sort((left, right) => right.id.localeCompare(left.id, 'en'))

const openEntries = entries.filter((entry) => entry.status === 'open')
const attentionEntries = entries.filter((entry) => entry.needsAttention)

const generatedSource = `// Generated by scripts/generate-ledger-catalog.mjs. Do not edit manually.
export type LedgerStatus = 'open' | 'closed'

export interface LedgerEntry {
  id: string
  week: string
  title: string
  status: LedgerStatus
  model: string
  sessionPrompt: string
  reservedAt: string
  closedAt: string
  summary: string
  report: string
  needsAttention: boolean
  attentionReason: string
  paths: string[]
  /** From the Expected files field, recorded when the entry was reserved. */
  expectedPaths: string[]
  /** The Verified by field, verbatim. Empty when the entry never stated one. */
  verifiedBy: string
  /**
   * How well the closing block supports its own claim. Derived, never self-reported.
   * 'evidenced'  names a test, capture, file or command
   * 'declared'   says plainly it was not verified, which is honest and not a defect
   * 'weak'       cites only a build or a compile, which is not a verification
   * 'absent'     closed without saying anything
   * 'open'       still in flight, nothing to judge yet
   */
  verification: 'evidenced' | 'declared' | 'weak' | 'absent' | 'open'
  /** Non-empty when this entry's stamps contradict themselves or its neighbours. U-15. */
  timestampIssue: string
}

export const ledgerEntries: LedgerEntry[] = ${JSON.stringify(entries, null, 2)}

export const ledgerStats = ${JSON.stringify({
  totalEntries: entries.length,
  openEntries: openEntries.length,
  closedEntries: entries.length - openEntries.length,
  needsAttention: attentionEntries.length,
  weeks: weekFiles.length,
  // U-15 and the verification bar. Derived from the entries themselves, never
  // self-reported, and mirrored by scripts/check-ledger-entries.sh at commit time.
  evidenced: entries.filter((e) => e.verification === 'evidenced').length,
  declaredUnverified: entries.filter((e) => e.verification === 'declared').length,
  weakVerification: entries.filter((e) => e.verification === 'weak').length,
  noVerification: entries.filter((e) => e.verification === 'absent').length,
  timestampIssues: entries.filter((e) => e.timestampIssue).length,
}, null, 2)} as const
`

writeFileSync(outputPath, generatedSource)
console.log(
  `Ledger catalog: ${entries.length} entries across ${weekFiles.length} week file(s) — `
  + `${openEntries.length} open, ${attentionEntries.length} needing attention`,
)
console.log(`Generated ${path.relative(appDirectory, outputPath)}`)
