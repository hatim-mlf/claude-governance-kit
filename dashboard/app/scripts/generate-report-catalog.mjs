import { createHash } from 'node:crypto'
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { repositoryRoot, reportsRoot } from './project-paths.mjs'

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url))
const appDirectory = path.resolve(scriptDirectory, '..')

// Roots are resolved and sentinel-validated in project-paths.mjs;
// see the header there for why this is found rather than configured.
const reportRoots = [reportsRoot]

const outputPath = path.join(appDirectory, 'src', 'data', 'reports.ts')
const statsOutputPath = path.join(appDirectory, 'src', 'data', 'reportCatalogStats.ts')
const ignoredDirectories = new Set(['node_modules', 'dist'])
const includedExtensions = new Set(['.md', '.txt'])

function isHidden(name) {
  return name.startsWith('.')
}

function collectReportFiles(directory) {
  if (!existsSync(directory)) return []

  const files = []
  const entries = readdirSync(directory, { withFileTypes: true })
    .sort((left, right) => left.name.localeCompare(right.name, 'en'))

  for (const entry of entries) {
    if (isHidden(entry.name)) continue
    if (entry.isDirectory() && ignoredDirectories.has(entry.name)) continue

    const absolutePath = path.join(directory, entry.name)
    if (entry.isDirectory()) {
      files.push(...collectReportFiles(absolutePath))
      continue
    }

    if (entry.isFile() && includedExtensions.has(path.extname(entry.name).toLowerCase())) {
      files.push(absolutePath)
    }
  }

  return files
}

function getTitle(content, filename) {
  const text = content.toString('utf8')
  const heading = text.match(/^#\s+(.+?)\s*$/m)?.[1]?.trim()
  if (heading) return heading

  return path.basename(filename, path.extname(filename)).replace(/[_-]+/g, ' ').trim()
}

// WHY FOLDER BEATS TITLE — ledger 2026-W34-16.
//
// Each of the four report-writing skills writes into exactly one folder:
// bug-report → reports/bugs/, error-report → reports/errors/,
// audit-report → reports/audits/, session-report → reports/sessions/.
// The folder is not a hint about the kind. It *is* the kind, chosen by the
// skill that wrote the file, so no heuristic over the title can be more
// reliable than reading it.
//
// Before this change there was no folder step and no `audit report` kind at
// all. Two of the four were wrong as a result: an audit fell through every
// branch to `project report`, and an error report matched `/bug|error|issue/`
// on the word "errors" in its own path and was labelled a **bug report**.
//
// It went unnoticed for the reason worth remembering: reports/audits/ and
// reports/errors/ were both empty, so the classifier had never once been run
// against two of the four inputs it exists to sort. An empty folder is not a
// passing test — 2026-W34-15 found this by reading the function, not by
// watching it fail.
// Only the four skill-written folders are listed. reports/verification/ and
// reports/logs/ are deliberately absent: nothing writes to them by contract —
// they hold raw device exports and capture transcripts dropped in by tooling —
// so their names are a strong hint, not an authority, and the heuristics below
// already sort them the way this project has always read them. Adding them here
// was tried and reverted: it reclassified 16 scenario transcripts from
// `verification` to `diagnostics`, which is churn this change has no business
// causing.
const folderKinds = [
  ['reports/bugs/', 'bug report'],
  ['reports/errors/', 'error report'],
  ['reports/audits/', 'audit report'],
  ['reports/sessions/', 'session report'],
]

function classifyReport(title, filename, sourcePaths) {
  // A byte-identical file can sit in more than one tree. Take the first
  // authoritative folder any of its copies is in; a live report outranks an
  // archived duplicate of itself.
  for (const sourcePath of sourcePaths) {
    for (const [prefix, kind] of folderKinds) {
      if (sourcePath.startsWith(prefix)) return kind
    }
  }

  // Everything else is legacy: reports/archive/, reports/bugs reports/, and
  // loose files at the tree root. These predate the skills and have no folder
  // to read, so they keep the original title heuristics unchanged.
  const searchable = `${title} ${filename} ${sourcePaths.join(' ')}`.toLowerCase()

  if (/verification|verify|reconciliation|scenario|testflight/.test(searchable)) return 'verification'
  if (/diagnostic|build[ _-]?log|error[ _-]?log|\/logs\//.test(searchable)) return 'diagnostics'
  if (/audit/.test(searchable)) return 'audit report'
  if (/session|handoff/.test(searchable)) return 'session report'
  if (/bug|error|issue/.test(searchable)) return 'bug report'
  return 'project report'
}

const physicalReports = reportRoots
  .flatMap(collectReportFiles)
  .sort((left, right) => left.localeCompare(right, 'en'))
  .map((absolutePath) => {
    const content = readFileSync(absolutePath)
    const stats = statSync(absolutePath)
    const extension = path.extname(absolutePath).toLowerCase()

    return {
      absolutePath,
      hash: createHash('sha256').update(content).digest('hex'),
      title: getTitle(content, path.basename(absolutePath)),
      filename: path.basename(absolutePath),
      format: extension === '.md' ? 'md' : 'txt',
      modifiedDate: stats.mtime.toISOString().slice(0, 10),
      byteSize: stats.size,
      sourcePath: path.relative(repositoryRoot, absolutePath).split(path.sep).join('/'),
    }
  })

const reportsByHash = new Map()

for (const report of physicalReports) {
  const existing = reportsByHash.get(report.hash)
  if (existing) {
    existing.sourcePaths.push(report.sourcePath)
    if (report.modifiedDate > existing.modifiedDate) existing.modifiedDate = report.modifiedDate
    continue
  }

  reportsByHash.set(report.hash, {
    id: `report-${report.hash.slice(0, 16)}`,
    hash: report.hash,
    title: report.title,
    filename: report.filename,
    kind: 'project report',
    format: report.format,
    modifiedDate: report.modifiedDate,
    byteSize: report.byteSize,
    sourcePaths: [report.sourcePath],
  })
}

const reports = [...reportsByHash.values()]
  .map((report) => ({
    ...report,
    sourcePaths: report.sourcePaths.sort((left, right) => left.localeCompare(right, 'en')),
    kind: classifyReport(report.title, report.filename, report.sourcePaths),
  }))
  .sort((left, right) => {
    const titleOrder = left.title.localeCompare(right.title, 'en', { sensitivity: 'base' })
    return titleOrder || left.id.localeCompare(right.id, 'en')
  })

const generatedSource = `// Generated by scripts/generate-report-catalog.mjs. Do not edit manually.
export type ReportKind =
  | 'bug report'
  | 'error report'
  | 'audit report'
  | 'session report'
  | 'verification'
  | 'diagnostics'
  | 'project report'
export type ReportFormat = 'md' | 'txt'

export interface ReportCatalogEntry {
  id: string
  hash: string
  title: string
  filename: string
  kind: ReportKind
  format: ReportFormat
  modifiedDate: string
  byteSize: number
  sourcePaths: string[]
}

export const reports: ReportCatalogEntry[] = ${JSON.stringify(reports, null, 2)}
`

const generatedStatsSource = `// Generated by scripts/generate-report-catalog.mjs. Do not edit manually.
export const reportCatalogStats = ${JSON.stringify({
  physicalSourceCount: physicalReports.length,
  uniqueReportCount: reports.length,
}, null, 2)} as const
`

writeFileSync(outputPath, generatedSource)
writeFileSync(statsOutputPath, generatedStatsSource)
console.log(`Report catalog: ${physicalReports.length} physical sources, ${reports.length} unique reports`)
console.log(`Generated ${path.relative(appDirectory, outputPath)}`)
console.log(`Generated ${path.relative(appDirectory, statsOutputPath)}`)
