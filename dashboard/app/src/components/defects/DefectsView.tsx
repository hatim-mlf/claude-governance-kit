import { useMemo, useState } from 'react'
import { AlertTriangle, BookOpen, Bug, ChevronDown, ChevronRight, Repeat2, Search, ShieldAlert, X } from 'lucide-react'
import { trackerBugs, registerRows, bugPatterns, projectLessons, bugCatalogStats } from '@/data/bugCatalog'
import {
  filterTrackerItems,
  TRACKER_SEVERITY_CONFIG,
  TRACKER_STATUS_CONFIG,
  type TrackerFilter,
  type TrackerSort,
  type TrackerSource,
  type TrackerStatus,
} from '@/lib/trackerBugs'
import { Input } from '@/components/ui/input'

const statusFilters: Array<{ value: 'all' | TrackerStatus; label: string }> = [
  { value: 'all', label: 'All' },
  { value: 'open', label: 'Open' },
  { value: 'fixed_unverified', label: 'Unverified' },
  { value: 'fixed_verified', label: 'Verified' },
  { value: 'product_gap', label: 'Product gap' },
]

const sortOptions: Array<{ value: TrackerSort; label: string }> = [
  { value: 'newest', label: 'Newest first' },
  { value: 'oldest', label: 'Oldest first' },
  { value: 'severity', label: 'Severity' },
  { value: 'status', label: 'Status' },
  { value: 'id', label: 'ID' },
]

const allItems = [...trackerBugs, ...registerRows]

export function DefectsView() {
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<'all' | TrackerStatus>('all')
  const [source, setSource] = useState<'all' | TrackerSource>('all')
  const [sort, setSort] = useState<TrackerSort>('newest')
  const [expanded, setExpanded] = useState<Set<string>>(() => new Set())
  const [showAnalysis, setShowAnalysis] = useState(true)

  const filter: TrackerFilter = useMemo(
    () => ({
      search,
      sort,
      status: status === 'all' ? undefined : [status],
      source: source === 'all' ? undefined : [source],
    }),
    [search, status, source, sort],
  )

  const visible = useMemo(() => filterTrackerItems(allItems, filter), [filter])
  const hasActiveFilters = Boolean(search || status !== 'all' || source !== 'all' || sort !== 'newest')

  const clearFilters = () => {
    setSearch('')
    setStatus('all')
    setSource('all')
    setSort('newest')
  }

  const toggle = (id: string) =>
    setExpanded((current) => {
      const next = new Set(current)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })

  return (
    <section aria-labelledby="defects-heading" className="space-y-6">
      <div>
        <div className="flex items-center gap-2 text-[#FF6B35]">
          <Bug className="h-4 w-4" aria-hidden="true" />
          <span className="text-xs font-medium">Live defect registers</span>
        </div>
        <h2 id="defects-heading" className="mt-1 text-2xl font-bold text-white">Defects</h2>
        <p className="mt-1 max-w-3xl text-sm text-[#EBEBF599]">
          Generated from <code className="text-[#EBEBF5CC]">BUG_TRACKER.md</code> and{' '}
          <code className="text-[#EBEBF5CC]">STRUCTURAL_PROBLEMS.md</code> — the two places a defect is
          filed. Both are read on every sync, so a row filed here appears here.
        </p>
      </div>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className="rounded-lg border border-[#2C2C2E] bg-[#141414] p-4">
          <p className="text-sm text-[#EBEBF599]">Tracker bugs</p>
          <p className="mt-1 text-2xl font-bold text-white">{bugCatalogStats.trackerTotal}</p>
        </div>
        <div className="rounded-lg border border-[#2C2C2E] bg-[#141414] p-4">
          <p className="text-sm text-[#EBEBF599]">Register rows</p>
          <p className="mt-1 text-2xl font-bold text-white">{bugCatalogStats.registerTotal}</p>
        </div>
        <div className="rounded-lg border border-red-500/30 bg-[#141414] p-4">
          <p className="text-sm text-red-500">Open</p>
          <p className="mt-1 text-2xl font-bold text-red-500">{bugCatalogStats.openTotal}</p>
        </div>
        <div className="rounded-lg border border-[#FFD60A]/30 bg-[#141414] p-4">
          <p className="text-sm text-[#FFD60A]">Fixed, unverified</p>
          <p className="mt-1 text-2xl font-bold text-[#FFD60A]">{bugCatalogStats.fixedUnverifiedTotal}</p>
        </div>
      </div>

      {/* Analysis — the "so we stop repeating them" half. */}
      <div className="rounded-lg border border-[#5E5CE6]/30 bg-[#141414]">
        <button
          type="button"
          onClick={() => setShowAnalysis((current) => !current)}
          aria-expanded={showAnalysis}
          className="flex w-full items-center gap-2 p-4 text-left outline-none focus-visible:ring-2 focus-visible:ring-[#FF6B35]"
        >
          {showAnalysis ? <ChevronDown className="h-4 w-4 text-[#7D7AFF]" /> : <ChevronRight className="h-4 w-4 text-[#7D7AFF]" />}
          <Repeat2 className="h-4 w-4 text-[#7D7AFF]" aria-hidden="true" />
          <span className="text-base font-semibold text-white">Recurring patterns</span>
          <span className="text-sm text-[#7D7AFF]">{bugPatterns.length}</span>
        </button>

        {showAnalysis && (
          <div className="space-y-3 px-4 pb-4">
            <p className="text-xs text-[#EBEBF599]">
              <strong className="text-[#FFD60A]">Heuristic, not authoritative.</strong> Each pattern is a
              keyword rule over every defect's title, symptom and root cause, so a row can match more than
              one and some matches will be loose. It exists to make a defect class visible before the same
              shape is filed again — treat the lesson as the point, not the count.
            </p>
            {bugPatterns.map((pattern) => (
              <div key={pattern.id} className="rounded-lg border border-[#2C2C2E] bg-[#1C1C1E] p-3">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="text-sm font-medium text-white">{pattern.label}</span>
                  <span className="rounded bg-[#5E5CE6]/15 px-2 py-0.5 text-xs font-semibold text-[#7D7AFF]">
                    {pattern.count} defects
                  </span>
                  {pattern.openCount > 0 && (
                    <span className="rounded bg-red-500/10 px-2 py-0.5 text-xs font-semibold text-red-500">
                      {pattern.openCount} still open
                    </span>
                  )}
                </div>
                <p className="mt-2 text-sm leading-6 text-[#EBEBF599]">{pattern.lesson}</p>
                <p className="mt-2 break-words font-mono text-[11px] text-[#8E8E93]">{pattern.ids.join(' · ')}</p>
              </div>
            ))}

            <div className="rounded-lg border border-[#30D158]/30 bg-[#1C1C1E] p-3">
              <div className="flex items-center gap-2">
                <BookOpen className="h-4 w-4 text-green-500" aria-hidden="true" />
                <span className="text-sm font-medium text-white">Recorded lessons</span>
                <span className="text-xs text-green-500">{projectLessons.length}</span>
              </div>
              <p className="mt-1 text-xs text-[#EBEBF599]">
                Hand-written in the register's own Lessons table — authoritative, unlike the patterns above.
                Not defects to fix; findings worth not re-learning.
              </p>
              <ul className="mt-3 space-y-3">
                {projectLessons.map((lesson) => (
                  <li key={lesson.id}>
                    <p className="text-sm leading-6 text-[#EBEBF5CC]">
                      <span className="mr-2 font-mono text-xs text-green-500">{lesson.id}</span>
                      {lesson.lesson}
                    </p>
                    {lesson.action && <p className="mt-1 text-xs text-[#8E8E93]">→ {lesson.action}</p>}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        )}
      </div>

      {/* Filters */}
      <div className="rounded-lg border border-[#2C2C2E] bg-[#141414] p-4">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
          <label className="relative min-w-0 flex-1 lg:max-w-md">
            <span className="sr-only">Search defects</span>
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[#EBEBF54D]" aria-hidden="true" />
            <Input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search id, title, symptom, root cause…"
              className="h-10 border-[#2C2C2E] bg-[#1C1C1E] pl-9"
            />
          </label>

          <div className="flex gap-1 overflow-x-auto rounded-lg bg-[#1C1C1E] p-1 scrollbar-thin" aria-label="Filter by status">
            {statusFilters.map((option) => (
              <button
                key={option.value}
                type="button"
                aria-pressed={status === option.value}
                onClick={() => setStatus(option.value)}
                className={`min-h-9 shrink-0 rounded-md px-3 text-sm outline-none transition-colors focus-visible:ring-2 focus-visible:ring-[#FF6B35] ${
                  status === option.value ? 'bg-[#FF6B35] text-white' : 'text-[#EBEBF599] hover:bg-[#242426] hover:text-white'
                }`}
              >
                {option.label}
              </button>
            ))}
          </div>

          <label>
            <span className="sr-only">Filter by register</span>
            <select
              value={source}
              onChange={(event) => setSource(event.target.value as 'all' | TrackerSource)}
              className="h-10 rounded-md border border-[#2C2C2E] bg-[#1C1C1E] px-3 text-sm text-[#EBEBF599] outline-none focus-visible:ring-2 focus-visible:ring-[#FF6B35]"
            >
              <option value="all">Both registers</option>
              <option value="tracker">Bug tracker</option>
              <option value="register">Structural register</option>
            </select>
          </label>

          <label>
            <span className="sr-only">Sort defects</span>
            <select
              value={sort}
              onChange={(event) => setSort(event.target.value as TrackerSort)}
              className="h-10 rounded-md border border-[#2C2C2E] bg-[#1C1C1E] px-3 text-sm text-[#EBEBF599] outline-none focus-visible:ring-2 focus-visible:ring-[#FF6B35]"
            >
              {sortOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </label>
        </div>

        <div className="mt-3 flex min-h-7 items-center justify-between gap-3">
          <p aria-live="polite" className="text-sm text-[#EBEBF599]">
            <strong className="font-semibold text-white">{visible.length}</strong> of {allItems.length} defects
          </p>
          {hasActiveFilters && (
            <button
              type="button"
              onClick={clearFilters}
              className="flex min-h-10 items-center gap-1.5 rounded-md px-3 text-xs text-[#EBEBF599] outline-none hover:bg-[#242426] hover:text-white focus-visible:ring-2 focus-visible:ring-[#FF6B35]"
            >
              <X className="h-3.5 w-3.5" aria-hidden="true" />
              Clear filters
            </button>
          )}
        </div>
      </div>

      <div className="space-y-3">
        {visible.map((item) => {
          const statusMeta = TRACKER_STATUS_CONFIG[item.status]
          const isExpanded = expanded.has(item.id)
          const detailId = `defect-detail-${item.id}`
          return (
            <article key={item.id} className="overflow-hidden rounded-lg border border-[#2C2C2E] bg-[#141414] transition-colors hover:border-[#FF6B35]/50">
              <div className="p-4">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="rounded bg-[#1C1C1E] px-2 py-1 font-mono text-[11px] text-[#EBEBF599]">{item.id}</span>
                  <span
                    className="rounded border px-2 py-1 text-[11px] font-medium"
                    style={{ borderColor: `${statusMeta.color}4D`, backgroundColor: `${statusMeta.color}1A`, color: statusMeta.color }}
                    title={statusMeta.description}
                  >
                    {statusMeta.emoji} {statusMeta.label}
                  </span>
                  {item.severity && (
                    <span
                      className="rounded border px-2 py-1 text-[11px] font-medium"
                      style={{
                        borderColor: `${TRACKER_SEVERITY_CONFIG[item.severity].color}4D`,
                        color: TRACKER_SEVERITY_CONFIG[item.severity].color,
                      }}
                    >
                      {TRACKER_SEVERITY_CONFIG[item.severity].label}
                    </span>
                  )}
                  {item.source === 'register' && (
                    <span className="flex items-center gap-1 rounded bg-[#5E5CE6]/15 px-2 py-1 text-[11px] text-[#7D7AFF]">
                      <ShieldAlert className="h-3 w-3" aria-hidden="true" /> Structural
                    </span>
                  )}
                  {item.ledger && (
                    <span className="rounded bg-[#1C1C1E] px-2 py-1 font-mono text-[11px] text-[#8E8E93]">{item.ledger}</span>
                  )}
                </div>

                <h3 className="mt-2 break-words text-sm font-medium leading-6 text-white">{item.title}</h3>

                {item.symptom && item.symptom !== item.title && (
                  <p className="mt-2 line-clamp-2 text-sm leading-6 text-[#EBEBF599]">{item.symptom}</p>
                )}

                <button
                  type="button"
                  onClick={() => toggle(item.id)}
                  aria-expanded={isExpanded}
                  aria-controls={detailId}
                  className="mt-3 flex min-h-9 items-center gap-1.5 rounded-md text-xs text-[#EBEBF599] outline-none hover:text-white focus-visible:ring-2 focus-visible:ring-[#FF6B35]"
                >
                  {isExpanded ? <ChevronDown className="h-3.5 w-3.5" /> : <ChevronRight className="h-3.5 w-3.5" />}
                  {isExpanded ? 'Hide detail' : 'Show detail'}
                </button>

                {isExpanded && (
                  <dl id={detailId} className="mt-3 space-y-3 border-t border-[#2C2C2E] pt-3 text-sm">
                    <div>
                      <dt className="text-xs uppercase tracking-wide text-[#8E8E93]">Status line</dt>
                      <dd className="mt-1 leading-6 text-[#EBEBF5CC]">{item.statusText || '—'}</dd>
                    </div>
                    {item.rootCause && (
                      <div>
                        <dt className="text-xs uppercase tracking-wide text-[#8E8E93]">Root cause</dt>
                        <dd className="mt-1 leading-6 text-[#EBEBF599]">{item.rootCause}</dd>
                      </div>
                    )}
                    {item.nextStep && (
                      <div>
                        <dt className="text-xs uppercase tracking-wide text-[#8E8E93]">Next step</dt>
                        <dd className="mt-1 leading-6 text-[#EBEBF599]">{item.nextStep}</dd>
                      </div>
                    )}
                    {item.verificationBar && (
                      <div>
                        <dt className="flex items-center gap-1.5 text-xs uppercase tracking-wide text-[#FFD60A]">
                          <AlertTriangle className="h-3 w-3" aria-hidden="true" /> Verification bar
                        </dt>
                        <dd className="mt-1 leading-6 text-[#EBEBF599]">{item.verificationBar}</dd>
                      </div>
                    )}
                    {item.surface && (
                      <div>
                        <dt className="text-xs uppercase tracking-wide text-[#8E8E93]">Surface</dt>
                        <dd className="mt-1 text-[#EBEBF599]">{item.surface}</dd>
                      </div>
                    )}
                  </dl>
                )}
              </div>
            </article>
          )
        })}
      </div>

      {visible.length === 0 && (
        <div className="rounded-lg border border-[#2C2C2E] bg-[#141414] p-10 text-center text-[#EBEBF599]">
          <p className="text-base font-medium text-white">No defects match these filters</p>
          <p className="mt-1 text-sm">Try a broader search or clear the active filters.</p>
        </div>
      )}
    </section>
  )
}
