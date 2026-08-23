// Types for the generated bug catalog (src/data/bugCatalog.ts).
//
// The status vocabulary draws the line that matters: between a fix that has a
// commit and a fix that has evidence proving it. Collapsing those two into one
// "fixed" is the most expensive pattern a bug tracker can have.

export type TrackerStatus =
  | 'open'
  | 'fixed_unverified'
  | 'fixed_verified'
  | 'product_gap'
  | 'unknown'

export type TrackerSeverity = 'critical' | 'high' | 'medium' | 'low'

export type TrackerSource = 'tracker' | 'register'

export interface TrackerItem {
  /** "Bug 58" for tracker rows, "U-14" for register rows. */
  id: string
  /** Sort key for tracker rows; 0 for register rows, which sort by id. */
  number?: number
  source: TrackerSource
  title: string
  status: TrackerStatus
  /** The raw status line, kept because its qualifiers carry meaning the enum drops. */
  statusText: string
  severity: TrackerSeverity | null
  severityText: string | null
  ledger: string | null
  surface: string | null
  symptom: string | null
  rootCause: string | null
  nextStep: string | null
  verificationBar: string | null
  wordCount: number
}

export interface BugPattern {
  id: string
  label: string
  /** What to do differently. A count without a lesson changes nobody's behaviour. */
  lesson: string
  count: number
  openCount: number
  ids: string[]
}

export interface ProjectLesson {
  id: string
  lesson: string
  origin: string
  action: string
}

export interface BugCatalogStats {
  trackerTotal: number
  registerTotal: number
  total: number
  byStatus: Partial<Record<TrackerStatus, number>>
  trackerByStatus: Partial<Record<TrackerStatus, number>>
  lessonTotal: number
  openTotal: number
  fixedUnverifiedTotal: number
}

export const TRACKER_STATUS_CONFIG: Record<
  TrackerStatus,
  { label: string; emoji: string; color: string; description: string }
> = {
  open: {
    label: 'Open',
    emoji: '🔴',
    color: '#FF453A',
    description: 'Cause identified with file+line evidence, no fix written.',
  },
  fixed_unverified: {
    label: 'Fixed, unverified',
    emoji: '🟡',
    color: '#FFD60A',
    description: 'Code changed and builds. Nobody has confirmed the behaviour on device.',
  },
  fixed_verified: {
    label: 'Fixed, verified',
    emoji: '✅',
    color: '#30D158',
    description: 'A capture exists showing the failure before and the same scenario passing after.',
  },
  product_gap: {
    label: 'Product gap',
    emoji: '🔵',
    color: '#64D2FF',
    description: 'Behaves as written; what is missing is a decision, not a fix.',
  },
  unknown: {
    label: 'Unclassified',
    emoji: '⚪',
    color: '#8E8E93',
    description: 'Status line did not match the tracker vocabulary.',
  },
}

export const TRACKER_SEVERITY_CONFIG: Record<TrackerSeverity, { label: string; color: string }> = {
  critical: { label: 'Critical', color: '#FF453A' },
  high: { label: 'High', color: '#FF6B35' },
  medium: { label: 'Medium', color: '#FFD60A' },
  low: { label: 'Low', color: '#30D158' },
}

export type TrackerSort = 'newest' | 'oldest' | 'severity' | 'status' | 'id'

export interface TrackerFilter {
  search?: string
  status?: TrackerStatus[]
  severity?: TrackerSeverity[]
  source?: TrackerSource[]
  sort?: TrackerSort
}

const SEVERITY_RANK: Record<TrackerSeverity, number> = {
  critical: 0,
  high: 1,
  medium: 2,
  low: 3,
}

const STATUS_RANK: Record<TrackerStatus, number> = {
  open: 0,
  fixed_unverified: 1,
  product_gap: 2,
  fixed_verified: 3,
  unknown: 4,
}

/** Highest id first — for tracker rows that is newest filed, which is the useful default. */
function byNewest(a: TrackerItem, b: TrackerItem) {
  if (a.source !== b.source) return a.source === 'tracker' ? -1 : 1
  if (a.source === 'tracker') return (b.number ?? 0) - (a.number ?? 0)
  return b.id.localeCompare(a.id, undefined, { numeric: true })
}

export function filterTrackerItems(items: TrackerItem[], filter: TrackerFilter): TrackerItem[] {
  const search = filter.search?.trim().toLowerCase()
  const result = items.filter((item) => {
    if (filter.status?.length && !filter.status.includes(item.status)) return false
    if (filter.severity?.length && !(item.severity && filter.severity.includes(item.severity))) return false
    if (filter.source?.length && !filter.source.includes(item.source)) return false
    if (search) {
      const haystack = [item.id, item.title, item.symptom, item.rootCause, item.statusText, item.ledger]
        .filter(Boolean)
        .join(' ')
        .toLowerCase()
      if (!haystack.includes(search)) return false
    }
    return true
  })

  switch (filter.sort ?? 'newest') {
    case 'oldest':
      return result.sort((a, b) => byNewest(b, a))
    case 'severity':
      return result.sort(
        (a, b) =>
          (a.severity ? SEVERITY_RANK[a.severity] : 99) - (b.severity ? SEVERITY_RANK[b.severity] : 99) ||
          byNewest(a, b),
      )
    case 'status':
      return result.sort((a, b) => STATUS_RANK[a.status] - STATUS_RANK[b.status] || byNewest(a, b))
    case 'id':
      return result.sort((a, b) => a.id.localeCompare(b.id, undefined, { numeric: true }))
    default:
      return result.sort(byNewest)
  }
}
