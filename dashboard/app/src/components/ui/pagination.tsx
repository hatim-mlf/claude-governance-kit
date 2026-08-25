import { useEffect, useMemo, useState } from 'react'
import { ChevronLeft, ChevronRight } from 'lucide-react'

/**
 * Page a long list. Added when the long views outgrew a single scroll.
 *
 * `usePagination` owns the page number so a view does not have to. It resets to page 1
 * whenever the item count changes — without that, filtering a 91-item list down to 3
 * while sitting on page 5 shows an empty view that looks like "no results".
 */
export function usePagination<T>(items: readonly T[], perPage: number) {
  const [page, setPage] = useState(1)
  const pageCount = Math.max(1, Math.ceil(items.length / perPage))

  useEffect(() => {
    setPage(1)
  }, [items.length, perPage])

  const current = Math.min(page, pageCount)
  const slice = useMemo(
    () => items.slice((current - 1) * perPage, current * perPage),
    [items, current, perPage],
  )

  return { page: current, pageCount, slice, setPage, total: items.length }
}

type PaginationProps = {
  page: number
  pageCount: number
  total: number
  onChange: (page: number) => void
  /** What is being counted — "entries", "defects". Shown as "12–24 of 91 entries". */
  noun?: string
  perPage: number
}

export function Pagination({ page, pageCount, total, onChange, noun = 'items', perPage }: PaginationProps) {
  if (pageCount <= 1) return null

  const first = (page - 1) * perPage + 1
  const last = Math.min(page * perPage, total)

  // Window the numbers so 40 pages does not produce 40 buttons.
  const numbers: Array<number | 'gap'> = []
  for (let candidate = 1; candidate <= pageCount; candidate += 1) {
    const nearEdge = candidate <= 1 || candidate >= pageCount
    const nearPage = Math.abs(candidate - page) <= 1
    if (nearEdge || nearPage) numbers.push(candidate)
    else if (numbers[numbers.length - 1] !== 'gap') numbers.push('gap')
  }

  return (
    <nav
      className="flex flex-wrap items-center justify-between gap-3 border-t border-white/10 pt-4"
      aria-label={`${noun} pagination`}
    >
      <p className="text-xs text-white/50">
        {first}–{last} of {total} {noun}
      </p>
      <div className="flex items-center gap-1">
        <button
          type="button"
          onClick={() => onChange(page - 1)}
          disabled={page === 1}
          aria-label="Previous page"
          className="flex h-8 w-8 items-center justify-center rounded-md border border-white/10 text-white/70 transition hover:border-white/25 hover:text-white disabled:cursor-not-allowed disabled:opacity-30"
        >
          <ChevronLeft className="h-4 w-4" />
        </button>
        {numbers.map((entry, index) =>
          entry === 'gap' ? (
            <span key={`gap-${index}`} className="px-1 text-xs text-white/30">
              …
            </span>
          ) : (
            <button
              key={entry}
              type="button"
              onClick={() => onChange(entry)}
              aria-current={entry === page ? 'page' : undefined}
              className={
                entry === page
                  ? 'h-8 min-w-8 rounded-md bg-white/15 px-2 text-xs font-semibold text-white'
                  : 'h-8 min-w-8 rounded-md border border-white/10 px-2 text-xs text-white/60 transition hover:border-white/25 hover:text-white'
              }
            >
              {entry}
            </button>
          ),
        )}
        <button
          type="button"
          onClick={() => onChange(page + 1)}
          disabled={page === pageCount}
          aria-label="Next page"
          className="flex h-8 w-8 items-center justify-center rounded-md border border-white/10 text-white/70 transition hover:border-white/25 hover:text-white disabled:cursor-not-allowed disabled:opacity-30"
        >
          <ChevronRight className="h-4 w-4" />
        </button>
      </div>
    </nav>
  )
}
