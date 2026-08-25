/**
 * Sub-tabs within a view. Added when the long views outgrew a single scroll.
 */
export type SubTab<T extends string> = {
  id: T
  label: string
  count?: number
}

type SubTabsProps<T extends string> = {
  tabs: ReadonlyArray<SubTab<T>>
  active: T
  onChange: (id: T) => void
  ariaLabel: string
}

export function SubTabs<T extends string>({ tabs, active, onChange, ariaLabel }: SubTabsProps<T>) {
  return (
    <div role="tablist" aria-label={ariaLabel} className="flex flex-wrap items-center gap-1">
      {tabs.map((tab) => {
        const selected = tab.id === active
        return (
          <button
            key={tab.id}
            type="button"
            role="tab"
            aria-selected={selected}
            onClick={() => onChange(tab.id)}
            className={
              selected
                ? 'flex items-center gap-2 rounded-md bg-white/15 px-3 py-1.5 text-xs font-semibold text-white'
                : 'flex items-center gap-2 rounded-md border border-white/10 px-3 py-1.5 text-xs text-white/60 transition hover:border-white/25 hover:text-white'
            }
          >
            {tab.label}
            {tab.count !== undefined && (
              <span className={selected ? 'text-white/70' : 'text-white/35'}>{tab.count}</span>
            )}
          </button>
        )
      })}
    </div>
  )
}
