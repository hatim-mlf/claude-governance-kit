import { useMemo, useState } from 'react'
import { ChevronDown, ChevronRight, Copy, FileSearch, FileText, Files, Search, X } from 'lucide-react'
import { reports, type ReportFormat, type ReportKind } from '@/data/reports'
import { reportCatalogStats } from '@/data/reportCatalogStats'
import { Input } from '@/components/ui/input'

// The first four are the kinds the report-writing skills produce, kept together
// and in the order the routing table lists them. Ledger 2026-W34-16 added the
// middle two: before it there was no audit kind at all and error reports were
// filed under Bugs, so two of the four skills had no heading of their own here.
const kindFilters: Array<{ value: 'all' | ReportKind; label: string }> = [
  { value: 'all', label: 'All' },
  { value: 'bug report', label: 'Bugs' },
  { value: 'error report', label: 'Errors' },
  { value: 'audit report', label: 'Audits' },
  { value: 'session report', label: 'Sessions' },
  { value: 'verification', label: 'Verification' },
  { value: 'diagnostics', label: 'Diagnostics' },
  { value: 'project report', label: 'Project' },
]

const kindStyles: Record<ReportKind, string> = {
  'bug report': 'border-red-500/30 bg-red-500/10 text-red-500',
  'error report': 'border-[#FF9F0A]/30 bg-[#FF9F0A]/10 text-[#FF9F0A]',
  'audit report': 'border-[#5E5CE6]/30 bg-[#5E5CE6]/10 text-[#7D7AFF]',
  'session report': 'border-[#BF5AF2]/30 bg-[#BF5AF2]/10 text-[#BF5AF2]',
  verification: 'border-[#30D158]/30 bg-[#30D158]/10 text-green-500',
  diagnostics: 'border-[#FFD60A]/30 bg-[#FFD60A]/10 text-[#FFD60A]',
  'project report': 'border-[#0A84FF]/30 bg-[#0A84FF]/10 text-[#64D2FF]',
}

// Sort options. `newest` is the default and is deliberately first: a report catalog is
// read to find what happened recently, and before this the list came out in whatever
// order the generator emitted, which is neither newest-first nor stable to a reader.
const sortOptions = [
  { value: 'newest', label: 'Newest first' },
  { value: 'oldest', label: 'Oldest first' },
  { value: 'largest', label: 'Largest first' },
  { value: 'title', label: 'Title A–Z' },
] as const

type ReportSort = (typeof sortOptions)[number]['value']

function formatBytes(bytes: number) {
  if (bytes < 1024) return `${bytes} B`
  return `${(bytes / 1024).toFixed(bytes >= 10240 ? 0 : 1)} KB`
}

export function ReportsView() {
  const [search, setSearch] = useState('')
  const [kind, setKind] = useState<'all' | ReportKind>('all')
  const [format, setFormat] = useState<'all' | ReportFormat>('all')
  const [sort, setSort] = useState<ReportSort>('newest')
  const [expandedReports, setExpandedReports] = useState<Set<string>>(() => new Set())

  const filteredReports = useMemo(() => {
    const query = search.trim().toLowerCase()
    return reports.filter((report) => {
      const matchesSearch = !query || [report.title, report.filename, ...report.sourcePaths]
        .some((value) => value.toLowerCase().includes(query))
      const matchesKind = kind === 'all' || report.kind === kind
      const matchesFormat = format === 'all' || report.format === format
      return matchesSearch && matchesKind && matchesFormat
    })
  }, [search, kind, format])

  const visibleReports = useMemo(() => {
    const sorted = [...filteredReports]
    switch (sort) {
      case 'oldest':
        return sorted.sort((a, b) => a.modifiedDate.localeCompare(b.modifiedDate))
      case 'largest':
        return sorted.sort((a, b) => b.byteSize - a.byteSize)
      case 'title':
        return sorted.sort((a, b) => a.title.localeCompare(b.title))
      default:
        // Dates are ISO-prefixed strings, so a lexicographic compare is a date compare.
        // Ties fall back to title so the order is stable rather than input-dependent.
        return sorted.sort(
          (a, b) => b.modifiedDate.localeCompare(a.modifiedDate) || a.title.localeCompare(b.title),
        )
    }
  }, [filteredReports, sort])

  const duplicateCopies = reportCatalogStats.physicalSourceCount - reportCatalogStats.uniqueReportCount
  const hasActiveFilters = Boolean(search || kind !== 'all' || format !== 'all' || sort !== 'newest')

  const clearFilters = () => {
    setSearch('')
    setKind('all')
    setFormat('all')
    setSort('newest')
  }

  const toggleReport = (reportId: string) => {
    setExpandedReports((current) => {
      const next = new Set(current)
      if (next.has(reportId)) next.delete(reportId)
      else next.add(reportId)
      return next
    })
  }

  return (
    <section aria-labelledby="reports-heading" className="space-y-6">
      <div>
        <div className="flex items-center gap-2 text-[#FF6B35]">
          <FileText className="h-4 w-4" aria-hidden="true" />
          <span className="text-xs font-medium">Project evidence library</span>
        </div>
        <h2 id="reports-heading" className="mt-1 text-2xl font-bold text-white">Reports</h2>
        <p className="mt-1 max-w-3xl text-sm text-[#EBEBF599]">
          Search every indexed Markdown and diagnostics report without losing duplicate source locations.
        </p>
      </div>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
        <div className="rounded-lg border border-[#FF6B35]/30 bg-[#141414] p-4">
          <p className="text-sm text-[#FF6B35]">Indexed reports</p>
          <p className="mt-1 text-2xl font-bold text-white">{reportCatalogStats.uniqueReportCount}</p>
        </div>
        <div className="rounded-lg border border-[#2C2C2E] bg-[#141414] p-4">
          <p className="text-sm text-[#EBEBF599]">Physical sources</p>
          <p className="mt-1 text-2xl font-bold text-white">{reportCatalogStats.physicalSourceCount}</p>
        </div>
        <div className="rounded-lg border border-[#0A84FF]/30 bg-[#141414] p-4">
          <p className="text-sm text-[#64D2FF]">Duplicate copies</p>
          <p className="mt-1 text-2xl font-bold text-[#64D2FF]">{duplicateCopies}</p>
        </div>
      </div>

      <div className="rounded-lg border border-[#2C2C2E] bg-[#141414] p-4">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
          <label className="relative min-w-0 flex-1 lg:max-w-md">
            <span className="sr-only">Search reports</span>
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[#EBEBF54D]" aria-hidden="true" />
            <Input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search reports…"
              className="h-10 border-[#2C2C2E] bg-[#1C1C1E] pl-9"
            />
          </label>

          <div className="flex gap-1 overflow-x-auto rounded-lg bg-[#1C1C1E] p-1 scrollbar-thin" aria-label="Filter reports by kind">
            {kindFilters.map((option) => (
              <button
                key={option.value}
                type="button"
                aria-pressed={kind === option.value}
                onClick={() => setKind(option.value)}
                className={`min-h-9 shrink-0 rounded-md px-3 text-sm outline-none transition-colors focus-visible:ring-2 focus-visible:ring-[#FF6B35] ${
                  kind === option.value ? 'bg-[#FF6B35] text-white' : 'text-[#EBEBF599] hover:bg-[#242426] hover:text-white'
                }`}
              >
                {option.label}
              </button>
            ))}
          </div>

          <label>
            <span className="sr-only">Filter reports by format</span>
            <select
              value={format}
              onChange={(event) => setFormat(event.target.value as 'all' | ReportFormat)}
              className="h-10 rounded-md border border-[#2C2C2E] bg-[#1C1C1E] px-3 text-sm text-[#EBEBF599] outline-none focus-visible:ring-2 focus-visible:ring-[#FF6B35]"
            >
              <option value="all">All formats</option>
              <option value="md">Markdown</option>
              <option value="txt">Text</option>
            </select>
          </label>

          <label>
            <span className="sr-only">Sort reports</span>
            <select
              value={sort}
              onChange={(event) => setSort(event.target.value as ReportSort)}
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
            <strong className="font-semibold text-white">{visibleReports.length}</strong> of {reports.length} reports
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
        {visibleReports.map((report) => {
          const isExpanded = expandedReports.has(report.id)
          const sourceId = `report-sources-${report.id}`

          return (
            <article key={report.id} className="overflow-hidden rounded-lg border border-[#2C2C2E] bg-[#141414] transition-colors hover:border-[#FF6B35]/50">
              <button
                type="button"
                aria-expanded={isExpanded}
                aria-controls={sourceId}
                onClick={() => toggleReport(report.id)}
                className="flex w-full items-start gap-3 p-4 text-left outline-none transition-colors hover:bg-[#1C1C1E]/50 focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[#FF6B35]"
              >
                {isExpanded
                  ? <ChevronDown className="mt-0.5 h-4 w-4 shrink-0 text-[#FF6B35]" aria-hidden="true" />
                  : <ChevronRight className="mt-0.5 h-4 w-4 shrink-0 text-[#FF6B35]" aria-hidden="true" />}

                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className={`rounded border px-2 py-1 text-[11px] font-medium ${kindStyles[report.kind]}`}>{report.kind}</span>
                    <span className="rounded bg-[#1C1C1E] px-2 py-1 font-mono text-[11px] uppercase text-[#EBEBF599]">{report.format}</span>
                    {report.sourcePaths.length > 1 && (
                      <span className="flex items-center gap-1 text-xs text-[#FF6B35]">
                        <Copy className="h-3.5 w-3.5" aria-hidden="true" />
                        {report.sourcePaths.length} copies
                      </span>
                    )}
                  </div>
                  <h3 className="mt-2 break-words text-sm font-medium leading-6 text-white">{report.title}</h3>
                  <p className="mt-1 break-all font-mono text-xs text-[#EBEBF54D]">{report.filename}</p>
                </div>

                <dl className="hidden shrink-0 gap-6 text-xs sm:flex">
                  <div>
                    <dt className="text-[#EBEBF54D]">Modified</dt>
                    <dd className="mt-1 text-[#EBEBF599]">{report.modifiedDate}</dd>
                  </div>
                  <div className="w-14">
                    <dt className="text-[#EBEBF54D]">Size</dt>
                    <dd className="mt-1 font-mono text-[#EBEBF599]">{formatBytes(report.byteSize)}</dd>
                  </div>
                </dl>
              </button>

              {isExpanded && (
                <div id={sourceId} className="border-t border-[#2C2C2E] bg-[#1C1C1E]/40 p-4">
                  <div className="flex items-center gap-2 text-xs font-medium text-[#EBEBF599]">
                    <Files className="h-3.5 w-3.5 text-[#FF6B35]" aria-hidden="true" />
                    {report.sourcePaths.length === 1 ? 'Source path' : 'Source paths'}
                  </div>
                  <ul className="mt-2 space-y-1.5">
                    {report.sourcePaths.map((sourcePath) => (
                      <li key={sourcePath} className="break-all rounded bg-[#0A0A0A] px-3 py-2 font-mono text-xs leading-5 text-[#EBEBF599]">
                        {sourcePath}
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </article>
          )
        })}
      </div>

      {visibleReports.length === 0 && (
        <div className="py-12 text-center text-[#EBEBF599]">
          <FileSearch className="mx-auto mb-3 h-10 w-10 opacity-60" aria-hidden="true" />
          <p className="text-base text-white">No reports found</p>
          <p className="mt-1 text-sm">Try a broader search or clear the active filters.</p>
        </div>
      )}
    </section>
  )
}
