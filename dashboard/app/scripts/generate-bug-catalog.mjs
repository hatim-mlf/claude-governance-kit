// Bug catalog generator — parses the two living defect registers into dashboard data.
//
// TWO SOURCES, DELIBERATELY
//   CLAUDE.md says a defect is filed in one of two places: a numbered row in the bug
//   tracker when it is app or dashboard behaviour, a lettered row in the project
//   register (STRUCTURAL_PROBLEMS.md) when it is tooling, layout or process. A
//   dashboard that reads only the first shows half the defects.

import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { repositoryRoot, trackerPath } from './project-paths.mjs'

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url))
const appDirectory = path.resolve(scriptDirectory, '..')

// The register is optional: a young project may not have one yet. An absent
// register yields empty rows, not an error — unlike a missing tracker, which
// project-paths.mjs already made loudly fatal.
const registerPath = path.join(repositoryRoot, 'STRUCTURAL_PROBLEMS.md')
const outputPath = path.join(appDirectory, 'src', 'data', 'bugCatalog.ts')

// ── Status vocabulary ─────────────────────────────────────────────────────────
// The unverified/verified split is the whole point of the tracker's status
// vocabulary — a fix recorded as done before anyone confirmed it is the most
// expensive pattern a tracker can have — so it is preserved here rather than
// collapsed into a single "fixed".
function classifyStatus(raw) {
  const text = raw.toLowerCase().replace(/\*/g, '')
  if (text.includes('product gap')) return 'product_gap'
  if (text.includes('fixed')) {
    if (text.includes('unverified')) return 'fixed_unverified'
    if (text.includes('verified') || text.includes('reconfirmed')) return 'fixed_verified'
    return 'fixed_unverified' // "Fixed" with no qualifier has not cleared the verified bar
  }
  if (text.includes('open')) return 'open'
  return 'unknown'
}

function classifySeverity(raw) {
  if (!raw) return null
  const text = raw.toLowerCase()
  if (text.includes('blocker') || text.includes('critical')) return 'critical'
  if (text.includes('high')) return 'high'
  if (text.includes('medium')) return 'medium'
  if (text.includes('low')) return 'low'
  return null
}

function stripMarkdown(value) {
  return value
    .replace(/`([^`]*)`/g, '$1')
    .replace(/\*\*/g, '')
    .replace(/~~/g, '')
    .replace(/\s+/g, ' ')
    .trim()
}

function readField(body, names) {
  for (const name of names) {
    const match = body.match(new RegExp(`^\\*\\*${name}[^:]*:\\*\\*\\s*([\\s\\S]*?)(?=\\n\\*\\*|\\n##|$)`, 'm'))
    if (match) return stripMarkdown(match[1])
  }
  return null
}

// ── Recurrence analysis ───────────────────────────────────────────────────────
// Heuristic, and labelled as such on the dashboard. The point is not to be authoritative;
// it is to make a defect class visible *before* the same shape is filed a sixth time.
// Each rule names the lesson, because a count without a lesson changes nobody's behaviour.
const PATTERNS = [
  {
    id: 'silent-failure',
    label: 'Failure that cannot be seen',
    match: /discard|silently|ignored|no log|never parses|reports success|swallow|invisible|unnoticed/i,
    lesson:
      'A call whose status is discarded cannot fail visibly, so the defect behind it is found only by accident. Bind the response and log the status.',
  },
  {
    id: 'account-scoping',
    label: 'Per-account state that outlives the account',
    match: /account switch|account-scop|accountscop|unscoped|not cleared|per-account|sign-out|namespaced/i,
    lesson:
      'State that belongs to an account must be cleared or re-scoped when the account changes. Nothing compiler-visible flags state that survives a sign-out.',
  },
  {
    id: 'derived-state',
    label: 'Derived cache never rebuilt',
    match: /derived|recompute|cache|stale|rebuild|until a relaunch|relaunch/i,
    lesson:
      'Writing the source data is not the same as refreshing what is computed from it. Every path that replaces the source must rebuild the caches derived from it, or the UI shows the previous contents until a relaunch.',
  },
  {
    id: 'fixed-unverified',
    label: 'Fixed on paper, never confirmed',
    match: null, // status-derived, not text-derived
    statusMatch: 'fixed_unverified',
    lesson:
      'A fix with a commit but no verification is not done; it is a claim. Only named evidence moves it to verified.',
  },
  {
    id: 'sync-cursor',
    label: 'Delta-sync cursor and stranded rows',
    match: /cursor|delta|stranded|never pushed|upsert|409|last-write-wins/i,
    lesson:
      'A cursor must never advance past what a fetch actually saw, and a purge must invalidate its cursor in the same operation.',
  },
  {
    id: 'duplicate-copies',
    label: 'Indistinguishable copies of the same thing',
    match: /stale copy|archived|backup|duplicate|two copies|indistinguishable|wrong one/i,
    lesson:
      'When two copies of a project, build or catalog are reachable, the wrong one gets selected silently. Resolve by provenance, never by glob order or alphabetical accident.',
  },
]

function analysePatterns(items) {
  return PATTERNS.map((pattern) => {
    const matched = items.filter((item) => {
      if (pattern.statusMatch) return item.status === pattern.statusMatch
      const haystack = `${item.title} ${item.symptom ?? ''} ${item.rootCause ?? ''} ${item.statusText}`
      return pattern.match.test(haystack)
    })
    return {
      id: pattern.id,
      label: pattern.label,
      lesson: pattern.lesson,
      count: matched.length,
      openCount: matched.filter((item) => item.status === 'open').length,
      ids: matched.map((item) => item.id),
    }
  })
    .filter((pattern) => pattern.count > 0)
    .sort((a, b) => b.count - a.count)
}

// ── Parse BUG_TRACKER.md ──────────────────────────────────────────────────────
function parseTracker() {
  const source = readFileSync(trackerPath, 'utf8')
  const sections = source.split(/^## (?=Bug \d+)/m).slice(1)
  return sections.map((section) => {
    const [heading, ...rest] = section.split('\n')
    const body = rest.join('\n')
    const headingMatch = heading.match(/^Bug (\d+)\s*[—–-]\s*(.*)$/)
    const number = headingMatch ? Number(headingMatch[1]) : 0
    const statusText = readField(body, ['Status']) ?? ''
    return {
      id: `Bug ${number}`,
      number,
      source: 'tracker',
      title: headingMatch ? stripMarkdown(headingMatch[2]) : stripMarkdown(heading),
      status: classifyStatus(statusText),
      statusText,
      severity: classifySeverity(readField(body, ['Severity'])),
      severityText: readField(body, ['Severity']),
      ledger: (readField(body, ['Ledger']) ?? '').split('·')[0].trim() || null,
      surface: readField(body, ['Surface']),
      symptom: readField(body, ['Symptom', 'Reported behaviour']),
      rootCause: readField(body, ['Root cause']),
      nextStep: readField(body, ['Next step']),
      verificationBar: readField(body, ['Verification bar']),
      wordCount: body.split(/\s+/).length,
    }
  })
}

// ── Parse STRUCTURAL_PROBLEMS.md ──────────────────────────────────────────────
// Rows are table lines: | **U-12** | what | why/resolution |
//
// The register also carries a "## Lessons" table whose rows look identical to a defect
// row. They are not defects — the section says so in its own second line: "These are not
// defects to fix. They are findings worth not re-learning." Mixing them into the defect
// count would inflate it and, worse, mark a lesson as an open problem. They are parsed
// separately below and surfaced as lessons, which is what they are.
function splitOffLessonsSection(source) {
  const heading = source.indexOf('## Lessons')
  if (heading === -1) return { defects: source, lessons: '' }
  const next = source.indexOf('\n## ', heading + 1)
  return {
    defects: source.slice(0, heading) + (next === -1 ? '' : source.slice(next)),
    lessons: next === -1 ? source.slice(heading) : source.slice(heading, next),
  }
}

function parseLessons(section) {
  const lessons = []
  for (const line of section.split('\n')) {
    const cells = line.split('|').slice(1, -1)
    if (cells.length < 2) continue
    const id = (cells[0].match(/\*\*(L-\d+)\*\*/) ?? [])[1]
    if (!id) continue
    lessons.push({
      id,
      lesson: stripMarkdown(cells[1] ?? ''),
      origin: stripMarkdown(cells[2] ?? ''),
      action: stripMarkdown(cells[3] ?? ''),
    })
  }
  return lessons.sort((a, b) => a.id.localeCompare(b.id, undefined, { numeric: true }))
}

function parseRegister() {
  if (!existsSync(registerPath)) return []
  const { defects: source } = splitOffLessonsSection(readFileSync(registerPath, 'utf8'))
  const seen = new Map()
  for (const line of source.split('\n')) {
    const match = line.match(/^\|\s*\*\*([A-Z]+\d*-?\d*)\*\*\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*$/)
    if (!match) continue
    const [, id, what, why] = match
    const resolved = /✅/.test(why) || /^~~/.test(what)
    const candidate = {
      id,
      source: 'register',
      title: stripMarkdown(what),
      status: resolved ? 'fixed_verified' : 'open',
      statusText: resolved ? 'Resolved' : 'Open',
      severity: null,
      severityText: null,
      ledger: (why.match(/`(20\d\d-W\d\d-\d\d)`/) ?? [])[1] ?? null,
      surface: 'tooling / process',
      symptom: stripMarkdown(what),
      rootCause: stripMarkdown(why),
      nextStep: null,
      verificationBar: null,
      wordCount: why.split(/\s+/).length,
    }
    // The register repeats some rows in summary tables; keep the richest occurrence.
    const existing = seen.get(id)
    if (!existing || candidate.wordCount > existing.wordCount) seen.set(id, candidate)
  }
  return [...seen.values()].sort((a, b) => a.id.localeCompare(b.id, undefined, { numeric: true }))
}

// ── Emit ──────────────────────────────────────────────────────────────────────
const trackerBugs = parseTracker().sort((a, b) => b.number - a.number)
const registerRows = parseRegister()
const lessons = existsSync(registerPath)
  ? parseLessons(splitOffLessonsSection(readFileSync(registerPath, 'utf8')).lessons)
  : []
const all = [...trackerBugs, ...registerRows]

const countBy = (items, key) =>
  items.reduce((acc, item) => ({ ...acc, [item[key]]: (acc[item[key]] ?? 0) + 1 }), {})

const stats = {
  trackerTotal: trackerBugs.length,
  registerTotal: registerRows.length,
  total: all.length,
  byStatus: countBy(all, 'status'),
  trackerByStatus: countBy(trackerBugs, 'status'),
  lessonTotal: lessons.length,
  openTotal: all.filter((item) => item.status === 'open').length,
  fixedUnverifiedTotal: all.filter((item) => item.status === 'fixed_unverified').length,
}

const banner = `// GENERATED by scripts/generate-bug-catalog.mjs — do not edit by hand.
// Sources: the bug tracker (governance.config.json "tracker"), STRUCTURAL_PROBLEMS.md
// Regenerate with: npm run bugs:generate   (or npm run sync)
`

writeFileSync(
  outputPath,
  `${banner}
import type { TrackerItem, BugPattern, BugCatalogStats, ProjectLesson } from '@/lib/trackerBugs'

export const trackerBugs: TrackerItem[] = ${JSON.stringify(trackerBugs, null, 2)}

export const registerRows: TrackerItem[] = ${JSON.stringify(registerRows, null, 2)}

export const bugPatterns: BugPattern[] = ${JSON.stringify(analysePatterns(all), null, 2)}

/** Hand-written in STRUCTURAL_PROBLEMS.md's "Lessons" table — authoritative, not derived. */
export const projectLessons: ProjectLesson[] = ${JSON.stringify(lessons, null, 2)}

export const bugCatalogStats: BugCatalogStats = ${JSON.stringify(stats, null, 2)}
`,
)

console.log(
  `Bug catalog: ${trackerBugs.length} tracker bugs + ${registerRows.length} register rows, ` +
    `${stats.openTotal} open, ${stats.fixedUnverifiedTotal} fixed-unverified, ` +
    `${lessons.length} recorded lessons`,
)
console.log(`Generated ${path.relative(appDirectory, outputPath)}`)
