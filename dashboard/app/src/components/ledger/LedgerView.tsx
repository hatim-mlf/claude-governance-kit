import { useMemo, useState } from 'react'
import { Pagination, usePagination } from '@/components/ui/pagination'
import { SubTabs, type SubTab } from '@/components/ui/sub-tabs'
import {
  AlertTriangle, CheckCircle2, ChevronDown, ChevronRight, CircleDot,
  Cpu, FileSearch, Files, PauseCircle, ScrollText, Search, X,
} from 'lucide-react'
import { ledgerEntries, ledgerStats, type LedgerEntry } from '@/data/ledgerCatalog'
import { Input } from '@/components/ui/input'

// The generated catalog types status as 'open' | 'closed'. The ledger itself has
// a third state, ⏸️ Abandoned — closed deliberately with a reason and no work
// landed — which the generator does not yet emit, so no entry carries it today.
// It is handled here rather than left to fail silently the day it does: this view
// is the only place an abandoned entry would ever be looked for, and a status it
// cannot render would show as a blank badge rather than an error. See BACKLOG.md.
type DisplayStatus = LedgerEntry['status'] | 'abandoned'

const statusMeta: Record<DisplayStatus, { label: string; badge: string; icon: typeof CircleDot }> = {
  open: {
    label: 'Open',
    badge: 'border-[#FFD60A]/40 bg-[#FFD60A]/10 text-[#FFD60A]',
    icon: CircleDot,
  },
  closed: {
    label: 'Closed',
    badge: 'border-[#30D158]/30 bg-[#30D158]/10 text-[#30D158]',
    icon: CheckCircle2,
  },
  abandoned: {
    label: 'Abandoned',
    badge: 'border-[#8E8E93]/30 bg-[#8E8E93]/10 text-[#AEAEB2]',
    icon: PauseCircle,
  },
}

const statusFilters: Array<{ value: 'all' | DisplayStatus; label: string }> = [
  { value: 'all', label: 'All' },
  { value: 'open', label: 'Open' },
  { value: 'closed', label: 'Closed' },
  { value: 'abandoned', label: 'Abandoned' },
]

// The ledger is Markdown, and this view is where it gets read. Summaries and
// attention reasons use **bold** to mark the part that matters and `backticks`
// for paths — rendering them raw puts literal asterisks in front of exactly the
// sentence someone is meant to act on. Only those two inline forms are handled;
// anything more would be a Markdown renderer, which is a dependency this view
// does not need for two constructs.
const INLINE = /(\*\*[^*]+\*\*|`[^`]+`)/g

function renderInline(text: string) {
  return text.split(INLINE).map((part, index) => {
    if (part.startsWith('**') && part.endsWith('**')) {
      return <strong key={index} className="font-semibold text-white">{part.slice(2, -2)}</strong>
    }
    if (part.startsWith('`') && part.endsWith('`')) {
      return <code key={index} className="rounded bg-[#0A0A0A] px-1 py-0.5 font-mono text-[0.9em]">{part.slice(1, -1)}</code>
    }
    return part
  })
}

/** Model strings in the ledger carry their reasoning after an em dash. Keep the tier. */
function modelTier(model: string) {
  const tier = model.split('—')[0].trim()
  return tier || model
}

/**
 * An open entry has no `Files actually touched` block — that is written when the entry
 * closes — so it used to render "0 files touched" permanently. `Expected files` is
 * recorded at reserve time and is the only file information work in flight has, so it is
 * shown instead, labelled as expected rather than done.
 *
 * Once closed, both are known, and ledger/README.md says the gap between them "is the
 * useful part". Expected paths the entry never touched are listed separately rather than
 * dropped — that difference is a signal about how the estimate held, and nothing showed
 * it before.
 */
function FilesSection({ entry }: { entry: LedgerEntry }) {
  const isOpen = entry.status === 'open'
  const expected = entry.expectedPaths ?? []
  const touched = entry.paths
  const shown = isOpen ? expected : touched
  const untouched = isOpen ? [] : expected.filter((candidate) => !touched.includes(candidate))

  const label = isOpen
    ? expected.length === 1
      ? '1 file expected'
      : `${expected.length} files expected`
    : touched.length === 1
      ? '1 file touched'
      : `${touched.length} files touched`

  return (
    <div>
      <div className="flex flex-wrap items-center gap-2 text-xs font-medium text-[#EBEBF599]">
        <Files className="h-3.5 w-3.5 text-[#FF6B35]" aria-hidden="true" />
        {label}
        {isOpen && expected.length > 0 && (
          <span className="rounded bg-[#FFD60A]/10 px-2 py-0.5 text-[11px] text-[#FFD60A]">
            reserved, not yet closed
          </span>
        )}
      </div>

      {shown.length > 0 && (
        <ul className="mt-2 space-y-1.5">
          {shown.map((filePath) => (
            <li key={filePath} className="break-all rounded bg-[#0A0A0A] px-3 py-2 font-mono text-xs leading-5 text-[#EBEBF599]">
              {filePath}
            </li>
          ))}
        </ul>
      )}

      {untouched.length > 0 && (
        <div className="mt-3">
          <p className="text-xs font-medium text-[#8E8E93]">
            Expected but not touched · {untouched.length}
          </p>
          <ul className="mt-2 space-y-1.5">
            {untouched.map((filePath) => (
              <li key={filePath} className="break-all rounded border border-dashed border-[#2C2C2E] px-3 py-2 font-mono text-xs leading-5 text-[#8E8E93]">
                {filePath}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}

function EntryCard({
  entry,
  isExpanded,
  onToggle,
}: {
  entry: LedgerEntry
  isExpanded: boolean
  onToggle: () => void
}) {
  const status = statusMeta[entry.status as DisplayStatus] ?? statusMeta.open
  const StatusIcon = status.icon
  const detailId = `ledger-detail-${entry.id}`

  return (
    <article
      className={`overflow-hidden rounded-lg border bg-[#141414] transition-colors ${
        entry.needsAttention
          ? 'border-[#FF6B35]/50 hover:border-[#FF6B35]'
          : 'border-[#2C2C2E] hover:border-[#FF6B35]/50'
      }`}
    >
      <button
        type="button"
        aria-expanded={isExpanded}
        aria-controls={detailId}
        onClick={onToggle}
        className="flex w-full items-start gap-3 p-4 text-left outline-none transition-colors hover:bg-[#1C1C1E]/50 focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[#FF6B35]"
      >
        {isExpanded
          ? <ChevronDown className="mt-0.5 h-4 w-4 shrink-0 text-[#FF6B35]" aria-hidden="true" />
          : <ChevronRight className="mt-0.5 h-4 w-4 shrink-0 text-[#FF6B35]" aria-hidden="true" />}

        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <span className="rounded bg-[#1C1C1E] px-2 py-1 font-mono text-[11px] text-[#EBEBF599]">{entry.id}</span>
            <span className={`flex items-center gap-1 rounded border px-2 py-1 text-[11px] font-medium ${status.badge}`}>
              <StatusIcon className="h-3 w-3" aria-hidden="true" />
              {status.label}
            </span>
            <VerificationBadge entry={entry} />
            {entry.needsAttention && (
              <span className="flex items-center gap-1 rounded border border-[#FF6B35]/40 bg-[#FF6B35]/15 px-2 py-1 text-[11px] font-semibold text-[#FF6B35]">
                <AlertTriangle className="h-3 w-3" aria-hidden="true" />
                Needs attention
              </span>
            )}
            {entry.model && (
              <span className="flex items-center gap-1 text-[11px] text-[#EBEBF54D]">
                <Cpu className="h-3 w-3" aria-hidden="true" />
                {modelTier(entry.model)}
              </span>
            )}
          </div>

          <h3 className="mt-2 break-words text-sm font-medium leading-6 text-white">{entry.title}</h3>

          {entry.timestampIssue && (
            <p className="mt-2 border-l-2 border-[#FF453A] pl-3 text-sm leading-6 text-[#FF453A]">
              <span className="font-semibold">Timestamps disagree</span> — {entry.timestampIssue}.
              {' '}<span className="text-[#EBEBF599]">Register row U-15: a fabricated stamp reads as evidence.</span>
            </p>
          )}

          {entry.needsAttention && entry.attentionReason && (
            <p className="mt-2 border-l-2 border-[#FF6B35] pl-3 text-sm leading-6 text-[#FF6B35]">
              {renderInline(entry.attentionReason)}
            </p>
          )}

          {entry.summary && (
            <p className={`mt-2 text-sm leading-6 text-[#EBEBF599] ${isExpanded ? '' : 'line-clamp-2'}`}>
              {renderInline(entry.summary)}
            </p>
          )}
        </div>

        <dl className="hidden shrink-0 gap-6 text-xs sm:flex">
          <div className="w-36">
            <dt className="text-[#EBEBF54D]">Reserved</dt>
            <dd className="mt-1 text-[#EBEBF599]">{entry.reservedAt || '—'}</dd>
          </div>
          <div className="w-36">
            <dt className="text-[#EBEBF54D]">Closed</dt>
            <dd className="mt-1 text-[#EBEBF599]">{entry.closedAt || '—'}</dd>
          </div>
        </dl>
      </button>

      {isExpanded && (
        <div id={detailId} className="space-y-4 border-t border-[#2C2C2E] bg-[#1C1C1E]/40 p-4">
          <dl className="grid gap-4 sm:grid-cols-2">
            <div>
              <dt className="text-xs text-[#EBEBF54D]">Model</dt>
              <dd className="mt-1 text-sm leading-6 text-[#EBEBF599]">{entry.model || '—'}</dd>
            </div>
            <div>
              <dt className="text-xs text-[#EBEBF54D]">Session prompt</dt>
              <dd className="mt-1 break-all font-mono text-xs leading-5 text-[#EBEBF599]">{entry.sessionPrompt || '—'}</dd>
            </div>
            <div className="sm:col-span-2">
              <dt className="text-xs text-[#EBEBF54D]">Verified by</dt>
              <dd className="mt-1 text-sm leading-6 text-[#EBEBF599]">
                {entry.verifiedBy ? renderInline(entry.verifiedBy) : '—'}
              </dd>
            </div>
            <div className="sm:col-span-2">
              <dt className="text-xs text-[#EBEBF54D]">Report</dt>
              <dd className="mt-1 break-all font-mono text-xs leading-5 text-[#EBEBF599]">{entry.report || '—'}</dd>
            </div>
          </dl>

          <FilesSection entry={entry} />
        </div>
      )}
    </article>
  )
}

/**
 * How well a closed entry supports its own claim. Derived in the generator from the
 * `Verified by:` field, never self-reported — see generate-ledger-catalog.mjs.
 *
 * `declared` is deliberately NOT a warning colour. An entry that says plainly it was
 * not verified is doing the right thing; the failure this surfaces is the entry that
 * says nothing, or that offers a build as though a build were evidence.
 */
const verificationBadge = {
  evidenced: { label: 'Evidenced', className: 'border-[#30D158]/40 bg-[#30D158]/10 text-[#30D158]' },
  declared:  { label: 'Unverified, stated', className: 'border-[#0A84FF]/40 bg-[#0A84FF]/10 text-[#0A84FF]' },
  weak:      { label: 'Build only', className: 'border-[#FFD60A]/40 bg-[#FFD60A]/10 text-[#FFD60A]' },
  absent:    { label: 'No evidence stated', className: 'border-[#FF453A]/40 bg-[#FF453A]/10 text-[#FF453A]' },
  open:      null,
} as const

function VerificationBadge({ entry }: { entry: LedgerEntry }) {
  const badge = verificationBadge[entry.verification]
  if (!badge) return null
  return (
    <span
      title={entry.verifiedBy || 'The closing block states no Verified by field.'}
      className={`rounded border px-2 py-1 text-[11px] font-semibold ${badge.className}`}
    >
      {badge.label}
    </span>
  )
}

// Sorting applies *within* the existing grouping, never across it. Open-first and
// newest-week-first are a deliberate structure (see the comment on restByWeek); a flat
// re-sort would discard the thing that makes this view readable when resuming work.
const ledgerSortOptions = [
  { value: 'newest', label: 'Newest first' },
  { value: 'oldest', label: 'Oldest first' },
] as const

type LedgerSort = (typeof ledgerSortOptions)[number]['value']
type LedgerSection = 'all' | 'open' | 'attention' | 'week'

/** Enough that a page is worth reading, few enough that it is not a scroll. */
const ENTRIES_PER_PAGE = 15

/** Sits above the list, so keep it short — it must not become the scroll itself. */
const ATTENTION_PER_PAGE = 5

/** Newest week present, for the "This week" tab — ids are week-qualified and sortable. */
const latestWeek = ledgerEntries.reduce((newest, entry) => (entry.week > newest ? entry.week : newest), '')

export function LedgerView() {
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<'all' | DisplayStatus>('all')
  const [attentionOnly, setAttentionOnly] = useState(false)
  const [sort, setSort] = useState<LedgerSort>('newest')
  const [expanded, setExpanded] = useState<Set<string>>(() => new Set())

  const toggle = (id: string) => {
    setExpanded((current) => {
      const next = new Set(current)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const filtered = useMemo(() => {
    const query = search.trim().toLowerCase()
    return ledgerEntries.filter((entry) => {
      const matchesSearch = !query || [entry.id, entry.title, entry.summary, entry.attentionReason, entry.model, ...entry.paths]
        .some((value) => value.toLowerCase().includes(query))
      const matchesStatus = status === 'all' || entry.status === status
      const matchesAttention = !attentionOnly || entry.needsAttention
      return matchesSearch && matchesStatus && matchesAttention
    })
  }, [search, status, attentionOnly])

  // Open entries first — an open entry is either work in flight or work that
  // stopped, and that is what someone resuming needs to find before anything
  // else. Everything else groups by week, newest week first. Older weeks are
  // never dropped: the ledger's value is partly that it accumulates.
  // Entry ids are week-qualified and zero-padded (2026-W34-07), so a plain string
  // compare orders them correctly without parsing.
  const orderEntries = useMemo(
    () =>
      (entries: LedgerEntry[]) =>
        [...entries].sort((a, b) =>
          sort === 'oldest' ? a.id.localeCompare(b.id) : b.id.localeCompare(a.id),
        ),
    [sort],
  )


  const attentionEntries = ledgerEntries.filter((entry) => entry.needsAttention)

  // Sub-tabs, then pages within them. Paging alone still makes you walk every page to
  // reach the open entries, which are the ones someone resuming needs.
  const [section, setSection] = useState<LedgerSection>('all')
  const sectionTabs: ReadonlyArray<SubTab<LedgerSection>> = [
    { id: 'all', label: 'All', count: filtered.length },
    { id: 'open', label: 'In flight', count: filtered.filter((e) => e.status === 'open').length },
    { id: 'attention', label: 'Needs attention', count: filtered.filter((e) => e.needsAttention).length },
    { id: 'week', label: 'This week', count: filtered.filter((e) => e.week === latestWeek).length },
  ]

  const sectionEntries = useMemo(() => {
    const base =
      section === 'open' ? filtered.filter((e) => e.status === 'open')
      : section === 'attention' ? filtered.filter((e) => e.needsAttention)
      : section === 'week' ? filtered.filter((e) => e.week === latestWeek)
      : filtered
    return orderEntries(base)
  }, [section, filtered, orderEntries])

  const paged = usePagination(sectionEntries, ENTRIES_PER_PAGE)

  // The attention block sits ABOVE the list and rendered every flagged entry, so the tab
  // still scrolled however well the list below it paged. One screen can have more than one
  // unpaged region, and fixing the obvious one does not fix the screen.
  const pagedAttention = usePagination(attentionEntries, ATTENTION_PER_PAGE)
  const hasActiveFilters = Boolean(search || status !== 'all' || attentionOnly || sort !== 'newest')

  const clearFilters = () => {
    setSearch('')
    setStatus('all')
    setAttentionOnly(false)
    setSort('newest')
  }

  return (
    <section aria-labelledby="ledger-heading" className="space-y-6">
      <div>
        <div className="flex items-center gap-2 text-[#FF6B35]">
          <ScrollText className="h-4 w-4" aria-hidden="true" />
          <span className="text-xs font-medium">Execution spine</span>
        </div>
        <h2 id="ledger-heading" className="mt-1 text-2xl font-bold text-white">Ledger</h2>
        <p className="mt-1 max-w-3xl text-sm text-[#EBEBF599]">
          Every task, reserved before it started and closed after. What was started, when, by which
          model, and whether it ever finished — the record none of the other logs keep.
        </p>
      </div>

      {/*
        The evidence bar. Everything here is derived from the entries themselves, so it
        cannot be improved by writing a better summary — only by doing the verification.
        Mirrored at commit time by scripts/check-ledger-entries.sh.
      */}
      <div className="rounded-lg border border-[#2C2C2E] bg-[#141414] p-4">
        <div className="flex flex-wrap items-baseline justify-between gap-2">
          <p className="text-sm font-medium text-white">Does the record support its own claims?</p>
          <p className="text-xs text-[#EBEBF54D]">Derived from each closing block, never self-reported</p>
        </div>
        <div className="mt-3 flex h-2 w-full overflow-hidden rounded-full bg-[#0A0A0A]">
          {([
            ['bg-[#30D158]', ledgerStats.evidenced],
            ['bg-[#0A84FF]', ledgerStats.declaredUnverified],
            ['bg-[#FFD60A]', ledgerStats.weakVerification],
            ['bg-[#FF453A]', ledgerStats.noVerification],
          ] as const).map(([colour, count]) => (
            count > 0 ? (
              <div
                key={colour}
                className={colour}
                style={{ width: `${(count / Math.max(ledgerStats.closedEntries, 1)) * 100}%` }}
              />
            ) : null
          ))}
        </div>
        <dl className="mt-3 grid grid-cols-2 gap-x-4 gap-y-2 text-xs sm:grid-cols-5">
          <div><dt className="text-[#30D158]">Evidenced</dt><dd className="mt-0.5 font-mono text-sm text-white">{ledgerStats.evidenced}</dd></div>
          <div><dt className="text-[#0A84FF]">Unverified, stated</dt><dd className="mt-0.5 font-mono text-sm text-white">{ledgerStats.declaredUnverified}</dd></div>
          <div><dt className="text-[#FFD60A]">Build only</dt><dd className="mt-0.5 font-mono text-sm text-white">{ledgerStats.weakVerification}</dd></div>
          <div><dt className="text-[#FF453A]">Nothing stated</dt><dd className="mt-0.5 font-mono text-sm text-white">{ledgerStats.noVerification}</dd></div>
          <div>
            <dt className={ledgerStats.timestampIssues > 0 ? 'text-[#FF453A]' : 'text-[#EBEBF54D]'}>Timestamp conflicts</dt>
            <dd className={`mt-0.5 font-mono text-sm ${ledgerStats.timestampIssues > 0 ? 'text-[#FF453A]' : 'text-white'}`}>{ledgerStats.timestampIssues}</dd>
          </div>
        </dl>
      </div>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className="rounded-lg border border-[#FF6B35]/30 bg-[#141414] p-4">
          <p className="text-sm text-[#FF6B35]">Entries</p>
          <p className="mt-1 text-2xl font-bold text-white">{ledgerStats.totalEntries}</p>
        </div>
        <div className="rounded-lg border border-[#FFD60A]/30 bg-[#141414] p-4">
          <p className="text-sm text-[#FFD60A]">Open</p>
          <p className="mt-1 text-2xl font-bold text-[#FFD60A]">{ledgerStats.openEntries}</p>
        </div>
        <div className="rounded-lg border border-[#2C2C2E] bg-[#141414] p-4">
          <p className="text-sm text-[#EBEBF599]">Closed</p>
          <p className="mt-1 text-2xl font-bold text-white">{ledgerStats.closedEntries}</p>
        </div>
        <div className="rounded-lg border border-[#2C2C2E] bg-[#141414] p-4">
          <p className="text-sm text-[#EBEBF599]">Weeks</p>
          <p className="mt-1 text-2xl font-bold text-white">{ledgerStats.weeks}</p>
        </div>
      </div>

      {/*
        The attention flag is why this view exists. It is set by the session that
        closed the entry, at the one moment that session has the context, and
        before 2026-W34-16 nothing anywhere read it back. It goes above the list
        rather than into a column, because a flag you have to notice is a flag
        that gets missed.
      */}
      {attentionEntries.length > 0 && (
        <div className="rounded-lg border border-[#FF6B35]/50 bg-[#FF6B35]/5 p-4">
          <div className="flex items-center gap-2 text-[#FF6B35]">
            <AlertTriangle className="h-4 w-4" aria-hidden="true" />
            <h3 className="text-sm font-semibold">
              {attentionEntries.length === 1
                ? '1 entry needs attention'
                : `${attentionEntries.length} entries need attention`}
            </h3>
          </div>
          <p className="mt-1 text-xs text-[#EBEBF599]">
            Flagged by the session that closed them. Each one left something a person should look at.
          </p>
          <ul className="mt-3 space-y-2">
            {pagedAttention.slice.map((entry) => (
              <li key={entry.id} className="rounded-md border border-[#FF6B35]/25 bg-[#141414] p-3">
                <div className="flex flex-wrap items-baseline gap-2">
                  <span className="font-mono text-xs text-[#FF6B35]">{entry.id}</span>
                  <span className="min-w-0 text-sm font-medium text-white">{entry.title}</span>
                </div>
                {entry.attentionReason && (
                  <p className="mt-1.5 text-sm leading-6 text-[#EBEBF599]">{renderInline(entry.attentionReason)}</p>
                )}
              </li>
            ))}
          </ul>
          <Pagination
            page={pagedAttention.page}
            pageCount={pagedAttention.pageCount}
            total={pagedAttention.total}
            perPage={ATTENTION_PER_PAGE}
            noun="flagged entries"
            onChange={pagedAttention.setPage}
          />
        </div>
      )}

      <div className="rounded-lg border border-[#2C2C2E] bg-[#141414] p-4">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
          <label className="relative min-w-0 flex-1 lg:max-w-md">
            <span className="sr-only">Search ledger entries</span>
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[#EBEBF54D]" aria-hidden="true" />
            <Input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search entries…"
              className="h-10 border-[#2C2C2E] bg-[#1C1C1E] pl-9"
            />
          </label>

          <div className="flex gap-1 overflow-x-auto rounded-lg bg-[#1C1C1E] p-1 scrollbar-thin" aria-label="Filter entries by status">
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

          <button
            type="button"
            aria-pressed={attentionOnly}
            onClick={() => setAttentionOnly((current) => !current)}
            className={`flex min-h-10 shrink-0 items-center gap-1.5 rounded-md px-3 text-sm outline-none transition-colors focus-visible:ring-2 focus-visible:ring-[#FF6B35] ${
              attentionOnly ? 'bg-[#FF6B35] text-white' : 'bg-[#1C1C1E] text-[#EBEBF599] hover:text-white'
            }`}
          >
            <AlertTriangle className="h-3.5 w-3.5" aria-hidden="true" />
            Needs attention
          </button>

          <label>
            <span className="sr-only">Sort ledger entries within each group</span>
            <select
              value={sort}
              onChange={(event) => setSort(event.target.value as LedgerSort)}
              className="h-10 rounded-md border border-[#2C2C2E] bg-[#1C1C1E] px-3 text-sm text-[#EBEBF599] outline-none focus-visible:ring-2 focus-visible:ring-[#FF6B35]"
            >
              {ledgerSortOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </label>
        </div>

        <div className="mt-3 flex min-h-7 items-center justify-between gap-3">
          <p aria-live="polite" className="text-sm text-[#EBEBF599]">
            <strong className="font-semibold text-white">{filtered.length}</strong> of {ledgerEntries.length} entries
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

      <div className="flex flex-wrap items-center justify-between gap-3">
        <SubTabs tabs={sectionTabs} active={section} onChange={setSection} ariaLabel="Ledger sections" />
      </div>

      <div className="space-y-3">
        {paged.slice.map((entry) => (
          <EntryCard key={entry.id} entry={entry} isExpanded={expanded.has(entry.id)} onToggle={() => toggle(entry.id)} />
        ))}
        <Pagination
          page={paged.page}
          pageCount={paged.pageCount}
          total={paged.total}
          perPage={ENTRIES_PER_PAGE}
          noun="entries"
          onChange={paged.setPage}
        />
      </div>

      {filtered.length === 0 && (
        <div className="py-12 text-center text-[#EBEBF599]">
          <FileSearch className="mx-auto mb-3 h-10 w-10 opacity-60" aria-hidden="true" />
          <p className="text-base text-white">No ledger entries found</p>
          <p className="mt-1 text-sm">Try a broader search or clear the active filters.</p>
        </div>
      )}
    </section>
  )
}
