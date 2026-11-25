import { lazy, Suspense, useState, useEffect } from 'react'
import { dashboardConfig } from '@/data/config'
import { bugCatalogStats } from '@/data/bugCatalog'
import { reportCatalogStats } from '@/data/reportCatalogStats'
import { ledgerStats } from '@/data/ledgerCatalog'
import { Bug as BugIcon, FileText, Folder, ScrollText, type LucideIcon } from 'lucide-react'

type ViewMode = 'defects' | 'ledger' | 'reports' | 'project'

const navigationItems: Array<{ view: ViewMode; label: string; shortcut: string; icon: LucideIcon }> = [
  { view: 'defects', label: 'Defects', shortcut: '1', icon: BugIcon },
  { view: 'ledger', label: 'Ledger', shortcut: '2', icon: ScrollText },
  { view: 'reports', label: 'Reports', shortcut: '3', icon: FileText },
  { view: 'project', label: 'Project', shortcut: '4', icon: Folder },
]

const loadDefectsView = () => import('@/components/defects/DefectsView')
const loadLedgerView = () => import('@/components/ledger/LedgerView')
const loadReportsView = () => import('@/components/reports/ReportsView')
const loadProjectView = () => import('@/components/project/ProjectInventoryView')

const DefectsView = lazy(() => loadDefectsView().then((module) => ({ default: module.DefectsView })))
const LedgerView = lazy(() => loadLedgerView().then((module) => ({ default: module.LedgerView })))
const ReportsView = lazy(() => loadReportsView().then((module) => ({ default: module.ReportsView })))
const ProjectInventoryView = lazy(() => loadProjectView().then((module) => ({ default: module.ProjectInventoryView })))

const viewPreloaders: Record<ViewMode, () => Promise<unknown>> = {
  defects: loadDefectsView,
  ledger: loadLedgerView,
  reports: loadReportsView,
  project: loadProjectView,
}

function DashboardLoadingState({ label }: { label: string }) {
  return (
    <div role="status" className="flex min-h-48 items-center justify-center rounded-lg border border-[#2C2C2E] bg-[#141414] text-sm text-[#EBEBF599]">
      <span className="mr-2 h-2 w-2 animate-pulse rounded-full bg-[#FF6B35]" aria-hidden="true" />
      Loading {label}…
    </div>
  )
}

export default function App() {
  const [viewMode, setViewMode] = useState<ViewMode>('defects')

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return
      const item = navigationItems.find((n) => n.shortcut === e.key)
      if (item) setViewMode(item.view)
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [])

  return (
    <div className="min-h-screen bg-[#0A0A0A] text-white">
      <header className="sticky top-0 z-50 border-b border-[#2C2C2E] bg-[#141414]">
        <div className="mx-auto max-w-7xl px-4 py-3">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[#FF6B35]">
              <ScrollText className="h-6 w-6 text-white" aria-hidden="true" />
            </div>
            <div className="min-w-0">
              <h1 className="truncate text-lg font-bold text-white sm:text-xl">{dashboardConfig.projectName} — Governance</h1>
              <p className="truncate text-xs text-[#EBEBF599]">
                {bugCatalogStats.total} tracked defects · {reportCatalogStats.uniqueReportCount} reports · {ledgerStats.totalEntries} ledger entries
              </p>
            </div>
          </div>

          <div className="-mx-4 mt-3 overflow-x-auto px-4 pb-1 scrollbar-thin">
            <div className="flex min-w-max items-center gap-2">
              <nav aria-label="Dashboard views" className="flex rounded-lg bg-[#1C1C1E] p-1">
                {navigationItems.map(({ view, label, shortcut, icon: Icon }) => {
                  const isCurrent = viewMode === view
                  return (
                    <button
                      key={view}
                      type="button"
                      aria-current={isCurrent ? 'page' : undefined}
                      title={`${label} view (${shortcut})`}
                      onClick={() => setViewMode(view)}
                      onMouseEnter={() => { void viewPreloaders[view]() }}
                      onFocus={() => { void viewPreloaders[view]() }}
                      className={`flex min-h-11 items-center gap-2 rounded-md px-3 text-sm outline-none transition-colors focus-visible:ring-2 focus-visible:ring-[#FF6B35] ${
                        isCurrent ? 'bg-[#FF6B35] text-white' : 'text-[#EBEBF599] hover:bg-[#242426] hover:text-white'
                      }`}
                    >
                      <Icon className="h-4 w-4" aria-hidden="true" />
                      <span>{label}</span>
                    </button>
                  )
                })}
              </nav>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-6">
        {viewMode === 'defects' ? (
          <Suspense fallback={<DashboardLoadingState label="defects" />}>
            <DefectsView />
          </Suspense>
        ) : viewMode === 'ledger' ? (
          <Suspense fallback={<DashboardLoadingState label="ledger" />}>
            <LedgerView />
          </Suspense>
        ) : viewMode === 'reports' ? (
          <Suspense fallback={<DashboardLoadingState label="reports" />}>
            <ReportsView />
          </Suspense>
        ) : (
          <Suspense fallback={<DashboardLoadingState label="project inventory" />}>
            <ProjectInventoryView />
          </Suspense>
        )}
      </main>
    </div>
  )
}
