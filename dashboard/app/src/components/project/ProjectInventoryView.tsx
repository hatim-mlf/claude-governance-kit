import { useEffect, useMemo, useState } from 'react'
import {
  AlertTriangle,
  Braces,
  ChevronDown,
  ChevronRight,
  FileCode2,
  Files,
  Folder,
  FolderGit2,
  FolderOpen,
  GitBranch,
  Search,
  ShieldCheck,
  X,
} from 'lucide-react'
import {
  projectCatalog,
  projectCatalogSnapshot,
  type ProjectFileEntry,
} from '@/data/projectCatalog'
import { Input } from '@/components/ui/input'

type FlagFilter = 'all' | 'test' | 'legacy' | 'sensitive' | 'todo' | 'fatal' | 'generated'

const numberFormatter = new Intl.NumberFormat('en-US')
const dateFormatter = new Intl.DateTimeFormat('en', {
  year: 'numeric',
  month: 'short',
  day: 'numeric',
})

function formatBytes(bytes: number) {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(bytes < 10 * 1024 ? 1 : 0)} KB`
  return `${(bytes / 1024 ** 2).toFixed(1)} MB`
}

function formatDate(value: string) {
  return dateFormatter.format(new Date(value))
}

function rootLabel(root: ProjectFileEntry['sourceRoot']) {
  return root === 'repository' ? 'Repository' : root
}

function getDirectory(displayPath: string) {
  const slashIndex = displayPath.lastIndexOf('/')
  return slashIndex === -1 ? '.' : displayPath.slice(0, slashIndex)
}

function getFolderId(sourceRoot: ProjectFileEntry['sourceRoot'], path: string) {
  return `${sourceRoot}:${path}`
}

interface InventoryFolder {
  id: string
  path: string
  sourceRoot: ProjectFileEntry['sourceRoot']
  files: ProjectFileEntry[]
}

function groupFilesByFolder(files: ProjectFileEntry[]) {
  const folders = new Map<string, InventoryFolder>()

  for (const file of files) {
    const path = getDirectory(file.displayPath)
    const id = getFolderId(file.sourceRoot, path)
    const folder = folders.get(id)
    if (folder) folder.files.push(file)
    else folders.set(id, { id, path, sourceRoot: file.sourceRoot, files: [file] })
  }

  return [...folders.values()]
    .map((folder) => ({
      ...folder,
      files: folder.files.sort((left, right) => left.filename.localeCompare(right.filename)),
    }))
    .sort((left, right) => (
      left.sourceRoot.localeCompare(right.sourceRoot) || left.path.localeCompare(right.path)
    ))
}

function matchesFlag(file: ProjectFileEntry, flag: FlagFilter) {
  switch (flag) {
    case 'test': return file.flags.test
    case 'legacy': return file.flags.legacy
    case 'sensitive': return file.flags.sensitiveMetadataOnly
    case 'todo': return Boolean(file.swift?.todoFixmeCount)
    case 'fatal': return Boolean(file.swift?.fatalSignalCount)
    case 'generated': return file.flags.generated
    default: return true
  }
}

function FileFlags({ file }: { file: ProjectFileEntry }) {
  const flags = [
    file.flags.test && { label: 'Test', className: 'bg-[#0A84FF]/15 text-[#64D2FF]' },
    file.flags.legacy && { label: 'Legacy', className: 'bg-[#FF9F0A]/15 text-[#FFD60A]' },
    file.flags.generated && { label: 'Generated', className: 'bg-[#BF5AF2]/15 text-[#D9A7FF]' },
    file.flags.binary && { label: 'Binary', className: 'bg-[#8E8E93]/15 text-[#C7C7CC]' },
    file.flags.sensitiveMetadataOnly && { label: 'Metadata only', className: 'bg-[#30D158]/15 text-[#5DE879]' },
  ].filter(Boolean) as Array<{ label: string; className: string }>

  if (flags.length === 0) return null
  return (
    <span className="mt-1.5 flex flex-wrap gap-1.5">
      {flags.map((flag) => (
        <span key={flag.label} className={`rounded px-1.5 py-0.5 text-[10px] font-medium ${flag.className}`}>
          {flag.label}
        </span>
      ))}
    </span>
  )
}

function FileDetail({ file }: { file: ProjectFileEntry }) {
  if (file.flags.sensitiveMetadataOnly) {
    return (
      <div className="flex max-w-2xl items-start gap-3 rounded-lg bg-[#30D158]/10 p-3 text-sm text-[#A8F0B8]">
        <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
        <p>
          Sensitive filename detected. Only path, category, file kind, byte size, and modification date were catalogued;
          its contents were never read, hashed, parsed, printed, or embedded.
        </p>
      </div>
    )
  }

  if (!file.swift) {
    return (
      <dl className="grid gap-x-8 gap-y-2 text-xs sm:grid-cols-3">
        <div>
          <dt className="text-[#8E8E93]">Inventory ID</dt>
          <dd className="mt-1 break-all font-mono text-[#EBEBF5CC]">{file.id}</dd>
        </div>
        <div>
          <dt className="text-[#8E8E93]">Physical size</dt>
          <dd className="mt-1 text-[#EBEBF5CC]">{formatBytes(file.byteSize)}</dd>
        </div>
        <div>
          <dt className="text-[#8E8E93]">Readable lines</dt>
          <dd className="mt-1 text-[#EBEBF5CC]">{file.lineCount === null ? 'Not safely readable' : numberFormatter.format(file.lineCount)}</dd>
        </div>
      </dl>
    )
  }

  return (
    <div className="grid gap-5 lg:grid-cols-[minmax(0,0.65fr)_minmax(0,1.1fr)_minmax(9rem,0.45fr)]">
      <div>
        <h4 className="text-xs font-semibold text-[#EBEBF599]">Imports · {file.swift.imports.length}</h4>
        {file.swift.imports.length ? (
          <div className="mt-2 flex flex-wrap gap-1.5">
            {file.swift.imports.map((item) => (
              <code key={item} className="rounded bg-[#0A84FF]/10 px-2 py-1 text-xs text-[#64D2FF]">{item}</code>
            ))}
          </div>
        ) : <p className="mt-2 text-xs text-[#8E8E93]">No imports detected.</p>}
      </div>
      <div>
        <h4 className="text-xs font-semibold text-[#EBEBF599]">Declarations · {file.swift.declarationCount}</h4>
        {file.swift.declarations.length ? (
          <ul className="mt-2 grid gap-1.5 sm:grid-cols-2 xl:grid-cols-3">
            {file.swift.declarations.map((declaration, index) => (
              <li key={`${declaration.kind}-${declaration.name}-${index}`} className="flex min-w-0 items-baseline gap-2 text-xs">
                <span className="w-14 shrink-0 text-[#BF5AF2]">{declaration.kind}</span>
                <code className="truncate text-[#EBEBF5CC]" title={declaration.name}>{declaration.name}</code>
              </li>
            ))}
          </ul>
        ) : <p className="mt-2 text-xs text-[#8E8E93]">No type declarations detected.</p>}
      </div>
      <div>
        <h4 className="text-xs font-semibold text-[#EBEBF599]">Source signals</h4>
        <dl className="mt-2 space-y-2 text-xs">
          <div className="flex items-center justify-between gap-4">
            <dt className="text-[#8E8E93]">TODO / FIXME</dt>
            <dd className={file.swift.todoFixmeCount ? 'font-semibold text-[#FFD60A]' : 'text-[#EBEBF5CC]'}>{file.swift.todoFixmeCount}</dd>
          </div>
          <div className="flex items-center justify-between gap-4">
            <dt className="text-[#8E8E93]">Fatal / precondition</dt>
            <dd className={file.swift.fatalSignalCount ? 'font-semibold text-[#FF6961]' : 'text-[#EBEBF5CC]'}>{file.swift.fatalSignalCount}</dd>
          </div>
        </dl>
      </div>
    </div>
  )
}

interface InventoryFileRowProps {
  file: ProjectFileEntry
  expanded: boolean
  onToggle: () => void
}

function InventoryFileRow({ file, expanded, onToggle }: InventoryFileRowProps) {
  const detailId = `project-file-${file.id.replace(/[^a-zA-Z0-9_-]/g, '-')}`
  const signalCount = (file.swift?.todoFixmeCount || 0) + (file.swift?.fatalSignalCount || 0)

  return (
    <article>
      <button
        type="button"
        aria-expanded={expanded}
        aria-controls={detailId}
        onClick={onToggle}
        className="grid min-h-11 w-full gap-3 px-4 py-3 text-left outline-none transition-colors hover:bg-[#1C1C1E]/70 focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[#FF6B35] md:grid-cols-[1.5rem_minmax(12rem,2fr)_minmax(8rem,1fr)_minmax(7rem,.75fr)_minmax(8rem,.8fr)] md:items-start"
      >
        <span className="hidden pt-0.5 text-[#FF6B35] md:block">
          {expanded ? <ChevronDown className="h-4 w-4" aria-hidden="true" /> : <ChevronRight className="h-4 w-4" aria-hidden="true" />}
        </span>

        <span className="min-w-0">
          <span className="flex min-w-0 items-center gap-2">
            <span className="text-[#FF6B35] md:hidden">
              {expanded ? <ChevronDown className="h-4 w-4" aria-hidden="true" /> : <ChevronRight className="h-4 w-4" aria-hidden="true" />}
            </span>
            <FileCode2 className="h-4 w-4 shrink-0 text-[#8E8E93]" aria-hidden="true" />
            <code className="truncate font-semibold text-[#FF8A5B]" title={file.filename}>{file.filename}</code>
            {file.flags.sensitiveMetadataOnly && <ShieldCheck className="h-4 w-4 shrink-0 text-[#5DE879]" aria-label="Sensitive metadata only" />}
          </span>
          <FileFlags file={file} />
        </span>

        <span className="grid grid-cols-2 gap-2 text-xs md:block">
          <span className="block text-[#EBEBF5CC]">{file.category}</span>
          <span className="block text-[#8E8E93] md:mt-1">{rootLabel(file.sourceRoot)}</span>
        </span>

        <span className="grid grid-cols-2 gap-2 text-xs md:block">
          <span className="block text-[#EBEBF5CC]">{file.kind}</span>
          <code className="block text-[#8E8E93] md:mt-1">{file.extension === 'none' ? 'no extension' : `.${file.extension}`}</code>
        </span>

        <span className="grid grid-cols-2 gap-2 text-xs md:block md:text-right">
          <span className="block text-[#EBEBF5CC]">{file.lineCount === null ? '—' : `${numberFormatter.format(file.lineCount)} lines`}</span>
          <span className="block text-[#8E8E93] md:mt-1">{formatBytes(file.byteSize)} · {formatDate(file.modifiedDate)}</span>
          {file.flags.sensitiveMetadataOnly ? (
            <span className="col-span-2 mt-1 block text-[#5DE879]">Metadata only · not inspected</span>
          ) : signalCount > 0 ? (
            <span className="col-span-2 mt-1 flex items-center gap-1 text-[#FFD60A] md:justify-end">
              <AlertTriangle className="h-3.5 w-3.5" aria-hidden="true" />
              {file.swift?.todoFixmeCount || 0} TODO · {file.swift?.fatalSignalCount || 0} fatal
            </span>
          ) : null}
        </span>
      </button>

      <div id={detailId} hidden={!expanded} className="border-t border-[#2C2C2E] bg-[#101011] px-4 py-4 md:pl-14">
        <FileDetail file={file} />
      </div>
    </article>
  )
}

// Files are grouped by folder, so sorting applies within each folder rather than across
// the tree. "Newest first" is the default here as elsewhere; "Largest first" is the one
// that earns its place operationally — FILE_SIZE_REVIEW.md is driven by exactly that
// question, and answering it previously meant reading the whole list.
const projectSortOptions = [
  { value: 'newest', label: 'Newest first' },
  { value: 'oldest', label: 'Oldest first' },
  { value: 'largest', label: 'Largest first' },
  { value: 'lines', label: 'Most lines' },
  { value: 'path', label: 'Path A–Z' },
] as const

type ProjectSort = (typeof projectSortOptions)[number]['value']

export function ProjectInventoryView() {
  const [search, setSearch] = useState('')
  const [category, setCategory] = useState('all')
  const [kind, setKind] = useState('all')
  const [sourceRoot, setSourceRoot] = useState('all')
  const [flag, setFlag] = useState<FlagFilter>('all')
  const [sort, setSort] = useState<ProjectSort>('newest')
  const [expandedIds, setExpandedIds] = useState<Set<string>>(() => new Set())
  const [expandedFolderIds, setExpandedFolderIds] = useState<Set<string>>(() => (
    new Set(groupFilesByFolder(projectCatalog).map((folder) => folder.id))
  ))

  const kindOptions = useMemo(() => {
    const options = new Map<string, { kind: string; extension: string; count: number }>()
    for (const file of projectCatalog) {
      const value = `${file.kind}\u0000${file.extension}`
      const option = options.get(value)
      if (option) option.count += 1
      else options.set(value, { kind: file.kind, extension: file.extension, count: 1 })
    }
    return [...options.entries()].sort(([, left], [, right]) => (
      left.kind.localeCompare(right.kind) || left.extension.localeCompare(right.extension)
    ))
  }, [])

  const filteredFiles = useMemo(() => {
    const normalizedSearch = search.trim().toLocaleLowerCase()
    return projectCatalog.filter((file) => {
      const [selectedKind, selectedExtension] = kind === 'all' ? ['', ''] : kind.split('\u0000')
      const searchable = [
        file.displayPath,
        file.filename,
        ...(file.swift?.imports || []),
        ...(file.swift?.declarations.map((declaration) => declaration.name) || []),
      ].join(' ').toLocaleLowerCase()

      return (!normalizedSearch || searchable.includes(normalizedSearch))
        && (category === 'all' || file.category === category)
        && (kind === 'all' || (file.kind === selectedKind && file.extension === selectedExtension))
        && (sourceRoot === 'all' || file.sourceRoot === sourceRoot)
        && matchesFlag(file, flag)
    })
  }, [category, flag, kind, search, sourceRoot])

  const sortedFiles = useMemo(() => {
    const sorted = [...filteredFiles]
    switch (sort) {
      case 'oldest':
        return sorted.sort((a, b) => a.modifiedDate.localeCompare(b.modifiedDate))
      case 'largest':
        return sorted.sort((a, b) => b.byteSize - a.byteSize)
      case 'lines':
        // lineCount is null for anything not safely readable as text; those sort last
        // rather than being treated as zero-line files.
        return sorted.sort((a, b) => (b.lineCount ?? -1) - (a.lineCount ?? -1))
      case 'path':
        return sorted.sort((a, b) => a.displayPath.localeCompare(b.displayPath))
      default:
        return sorted.sort(
          (a, b) => b.modifiedDate.localeCompare(a.modifiedDate) || a.displayPath.localeCompare(b.displayPath),
        )
    }
  }, [filteredFiles, sort])

  const folderGroups = useMemo(() => groupFilesByFolder(sortedFiles), [sortedFiles])

  useEffect(() => {
    if (!search.trim()) return
    setExpandedFolderIds((current) => {
      const next = new Set(current)
      folderGroups.forEach((folder) => next.add(folder.id))
      return next
    })
  }, [folderGroups, search])

  const hasActiveFilters = Boolean(search || category !== 'all' || kind !== 'all' || sourceRoot !== 'all' || flag !== 'all')

  function clearFilters() {
    setSearch('')
    setCategory('all')
    setKind('all')
    setSourceRoot('all')
    setFlag('all')
    setSort('newest')
  }

  function toggleExpanded(id: string) {
    setExpandedIds((current) => {
      const next = new Set(current)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  function toggleFolder(folderId: string) {
    setExpandedFolderIds((current) => {
      const next = new Set(current)
      if (next.has(folderId)) next.delete(folderId)
      else next.add(folderId)
      return next
    })
  }

  function setAllVisibleFolders(expanded: boolean) {
    setExpandedFolderIds((current) => {
      const next = new Set(current)
      folderGroups.forEach((folder) => {
        if (expanded) next.add(folder.id)
        else next.delete(folder.id)
      })
      return next
    })
  }

  const snapshot = projectCatalogSnapshot

  return (
    <section aria-labelledby="project-inventory-title" className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <div className="flex items-center gap-2 text-[#FF8A5B]">
            <FolderGit2 className="h-4 w-4" aria-hidden="true" />
            <span className="text-xs font-semibold">Physical project map</span>
          </div>
          <h2 id="project-inventory-title" className="mt-1 text-2xl font-bold tracking-[-0.02em] text-white sm:text-3xl">
            Project inventory
          </h2>
          <p className="mt-1 max-w-3xl text-sm text-[#EBEBF599]">
            Every included file on disk, organized by folder and searchable by path, Swift import, or type declaration.
          </p>
        </div>
        <p className="text-xs text-[#8E8E93]">Latest source modification · {formatDate(snapshot.latestModifiedDate)}</p>
      </div>

      <div className="grid overflow-hidden rounded-xl border border-[#2C2C2E] bg-[#141414] sm:grid-cols-2 xl:grid-cols-4">
        <div className="border-b border-[#2C2C2E] p-4 sm:border-r xl:border-b-0">
          <div className="flex items-center gap-2 text-[#EBEBF599]"><Files className="h-4 w-4" aria-hidden="true" /><span className="text-xs">Physical files</span></div>
          <p className="mt-2 text-2xl font-bold text-white">{numberFormatter.format(snapshot.fileCount)}</p>
          <p className="mt-1 text-xs text-[#8E8E93]">{snapshot.sourceRootCounts.repository} files in the repository</p>
        </div>
        <div className="border-b border-[#2C2C2E] p-4 xl:border-b-0 xl:border-r">
          <div className="flex items-center gap-2 text-[#EBEBF599]"><FileCode2 className="h-4 w-4" aria-hidden="true" /><span className="text-xs">Active Swift source</span></div>
          <p className="mt-2 text-2xl font-bold text-white">{numberFormatter.format(snapshot.swift.fileCount)}</p>
          <p className="mt-1 text-xs text-[#8E8E93]">{numberFormatter.format(snapshot.swift.lineCount)} physical lines · {snapshot.swift.legacyFileCount} legacy file retained</p>
        </div>
        <div className="border-b border-[#2C2C2E] p-4 sm:border-r sm:border-b-0">
          <div className="flex items-center gap-2 text-[#EBEBF599]"><Braces className="h-4 w-4" aria-hidden="true" /><span className="text-xs">Swift declarations</span></div>
          <p className="mt-2 text-2xl font-bold text-white">{numberFormatter.format(snapshot.swift.declarationCount)}</p>
          <p className="mt-1 text-xs text-[#8E8E93]">{snapshot.swift.uniqueImportCount} unique imports · {snapshot.swift.todoFixmeCount} TODO/FIXME</p>
        </div>
        <div className="p-4">
          <div className="flex items-center gap-2 text-[#EBEBF599]"><GitBranch className="h-4 w-4" aria-hidden="true" /><span className="text-xs">Working tree snapshot</span></div>
          <div className="mt-2 flex flex-wrap items-baseline gap-x-3 gap-y-1 text-sm">
            <span><strong className="text-[#FF9F0A]">{snapshot.gitWorkingTree.modified}</strong> <span className="text-[#8E8E93]">modified</span></span>
            <span><strong className="text-[#FF6961]">{snapshot.gitWorkingTree.deleted}</strong> <span className="text-[#8E8E93]">deleted</span></span>
            <span><strong className="text-[#64D2FF]">{snapshot.gitWorkingTree.untracked}</strong> <span className="text-[#8E8E93]">new</span></span>
          </div>
        </div>
      </div>

      <div className="flex items-start gap-3 rounded-xl bg-[#0A84FF]/10 px-4 py-3 text-sm text-[#B9E1FF]">
        <GitBranch className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
        <p>
          Inventory of the Git root{' '}
          <code className="text-[#64D2FF]">{snapshot.displayRoots.repository}</code>, resolved and sentinel-validated from governance.config.json.
        </p>
      </div>

      <div className="rounded-xl border border-[#2C2C2E] bg-[#141414] p-3 sm:p-4">
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-[minmax(15rem,1.5fr)_repeat(4,minmax(9rem,1fr))]">
          <label className="relative block sm:col-span-2 xl:col-span-1">
            <span className="sr-only">Search project inventory</span>
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[#8E8E93]" aria-hidden="true" />
            <Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Folder, filename, import, declaration…" className="h-11 border-[#3A3A3C] bg-[#1C1C1E] pl-9 text-sm placeholder:text-[#8E8E93] focus-visible:ring-[#FF6B35]" />
          </label>
          <label>
            <span className="sr-only">Filter by category</span>
            <select value={category} onChange={(event) => setCategory(event.target.value)} className="h-11 w-full rounded-md border border-[#3A3A3C] bg-[#1C1C1E] px-3 text-sm text-[#EBEBF5CC] outline-none focus-visible:ring-2 focus-visible:ring-[#FF6B35]">
              <option value="all">All categories</option>
              {Object.entries(snapshot.categoryCounts).map(([value, count]) => <option key={value} value={value}>{value} · {count}</option>)}
            </select>
          </label>
          <label>
            <span className="sr-only">Filter by file kind and extension</span>
            <select value={kind} onChange={(event) => setKind(event.target.value)} className="h-11 w-full rounded-md border border-[#3A3A3C] bg-[#1C1C1E] px-3 text-sm text-[#EBEBF5CC] outline-none focus-visible:ring-2 focus-visible:ring-[#FF6B35]">
              <option value="all">All file kinds</option>
              {kindOptions.map(([value, option]) => <option key={value} value={value}>{option.kind} · {option.extension === 'none' ? 'no ext.' : `.${option.extension}`} · {option.count}</option>)}
            </select>
          </label>
          <label>
            <span className="sr-only">Filter by source root</span>
            <select value={sourceRoot} onChange={(event) => setSourceRoot(event.target.value)} className="h-11 w-full rounded-md border border-[#3A3A3C] bg-[#1C1C1E] px-3 text-sm text-[#EBEBF5CC] outline-none focus-visible:ring-2 focus-visible:ring-[#FF6B35]">
              <option value="all">All source roots</option>
              <option value="repository">Repository · {snapshot.sourceRootCounts.repository}</option>
            </select>
          </label>
          <label>
            <span className="sr-only">Filter by inventory flag</span>
            <select value={flag} onChange={(event) => setFlag(event.target.value as FlagFilter)} className="h-11 w-full rounded-md border border-[#3A3A3C] bg-[#1C1C1E] px-3 text-sm text-[#EBEBF5CC] outline-none focus-visible:ring-2 focus-visible:ring-[#FF6B35]">
              <option value="all">All flags</option>
              <option value="test">Tests</option>
              <option value="legacy">Legacy / old</option>
              <option value="sensitive">Sensitive · metadata only</option>
              <option value="todo">Has TODO / FIXME</option>
              <option value="fatal">Has fatal signal</option>
              <option value="generated">Generated metadata</option>
            </select>
          </label>
          <label>
            <span className="sr-only">Sort files within each folder</span>
            <select value={sort} onChange={(event) => setSort(event.target.value as ProjectSort)} className="h-11 w-full rounded-md border border-[#3A3A3C] bg-[#1C1C1E] px-3 text-sm text-[#EBEBF5CC] outline-none focus-visible:ring-2 focus-visible:ring-[#FF6B35]">
              {projectSortOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </label>
        </div>
        <div className="mt-3 flex min-h-11 flex-wrap items-center justify-between gap-3">
          <p aria-live="polite" className="text-sm text-[#EBEBF599]">
            <strong className="font-semibold text-white">{sortedFiles.length}</strong> of {snapshot.fileCount} files in{' '}
            <strong className="font-semibold text-white">{folderGroups.length}</strong> folders
          </p>
          <div className="flex flex-wrap items-center justify-end gap-1">
            <button type="button" onClick={() => setAllVisibleFolders(true)} className="min-h-10 rounded-md px-3 text-xs text-[#EBEBF599] outline-none hover:bg-[#242426] hover:text-white focus-visible:ring-2 focus-visible:ring-[#FF6B35]">
              Expand folders
            </button>
            <button type="button" onClick={() => setAllVisibleFolders(false)} className="min-h-10 rounded-md px-3 text-xs text-[#EBEBF599] outline-none hover:bg-[#242426] hover:text-white focus-visible:ring-2 focus-visible:ring-[#FF6B35]">
              Collapse folders
            </button>
            {hasActiveFilters && (
              <button type="button" onClick={clearFilters} className="flex min-h-10 items-center gap-1.5 rounded-md px-3 text-xs text-[#EBEBF599] outline-none hover:bg-[#242426] hover:text-white focus-visible:ring-2 focus-visible:ring-[#FF6B35]">
                <X className="h-3.5 w-3.5" aria-hidden="true" /> Clear filters
              </button>
            )}
          </div>
        </div>
      </div>

      {folderGroups.length > 0 ? (
        <div className="space-y-3" aria-label="Project files grouped by folder">
          {folderGroups.map((folder) => {
            const folderExpanded = expandedFolderIds.has(folder.id)
            const folderContentId = `project-folder-${folder.id.replace(/[^a-zA-Z0-9_-]/g, '-')}`
            const folderLabel = folder.path === '.' ? `${rootLabel(folder.sourceRoot)} root` : folder.path

            return (
              <section key={folder.id} className="overflow-hidden rounded-xl border border-[#2C2C2E] bg-[#141414]">
                <button
                  type="button"
                  aria-expanded={folderExpanded}
                  aria-controls={folderContentId}
                  onClick={() => toggleFolder(folder.id)}
                  className="flex min-h-14 w-full items-center gap-3 px-4 py-3 text-left outline-none transition-colors hover:bg-[#1C1C1E] focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[#FF6B35]"
                >
                  {folderExpanded ? <ChevronDown className="h-4 w-4 shrink-0 text-[#EBEBF599]" aria-hidden="true" /> : <ChevronRight className="h-4 w-4 shrink-0 text-[#EBEBF599]" aria-hidden="true" />}
                  {folderExpanded ? <FolderOpen className="h-5 w-5 shrink-0 text-[#FF6B35]" aria-hidden="true" /> : <Folder className="h-5 w-5 shrink-0 text-[#FF6B35]" aria-hidden="true" />}
                  <span className="min-w-0 flex-1">
                    <code className="block truncate text-sm font-semibold text-white" title={folderLabel}>{folderLabel}</code>
                    <span className="mt-0.5 block text-xs text-[#8E8E93]">{rootLabel(folder.sourceRoot)}</span>
                  </span>
                  <span className="shrink-0 text-xs text-[#EBEBF599]">{folder.files.length} {folder.files.length === 1 ? 'file' : 'files'}</span>
                </button>

                <div id={folderContentId} hidden={!folderExpanded} className="divide-y divide-[#2C2C2E] border-t border-[#2C2C2E]">
                  {folder.files.map((file) => (
                    <InventoryFileRow
                      key={file.id}
                      file={file}
                      expanded={expandedIds.has(file.id)}
                      onToggle={() => toggleExpanded(file.id)}
                    />
                  ))}
                </div>
              </section>
            )
          })}
        </div>
      ) : (
        <div className="rounded-xl border border-[#2C2C2E] bg-[#141414] px-4 py-14 text-center">
          <Search className="mx-auto h-8 w-8 text-[#EBEBF54D]" aria-hidden="true" />
          <p className="mt-3 font-medium text-white">No inventory folders match</p>
          <p className="mt-1 text-sm text-[#EBEBF599]">Adjust the search or clear the active filters.</p>
        </div>
      )}
    </section>
  )
}
