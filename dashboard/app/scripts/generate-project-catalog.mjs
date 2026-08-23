import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { repositoryRoot } from './project-paths.mjs'

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url))
const appDirectory = path.resolve(scriptDirectory, '..')

// Roots are found and sentinel-validated in project-paths.mjs, from
// governance.config.json — which is what makes a wrong root fail loudly instead
// of producing an empty catalog.
const outputPath = path.join(appDirectory, 'src', 'data', 'projectCatalog.ts')

const excludedDirectoryNames = new Set([
  '.git',
  'build',
  'DerivedData',
  'xcuserdata',
  'node_modules',
  'dist',
])
const categories = [
  'App',
  'Managers',
  'Models',
  'Views',
  'Utilities',
  'Tests',
  'Debug',
  'Database',
  'Documentation',
  'Assets',
  'Configuration',
  'Other',
]
const categoryOrder = new Map(categories.map((category, index) => [category, index]))
const binaryExtensions = new Set([
  'aiff', 'avi', 'bin', 'bmp', 'caf', 'db', 'dylib', 'gif', 'heic', 'icns', 'ico',
  'jpeg', 'jpg', 'm4a', 'mov', 'mp3', 'mp4', 'pdf', 'png', 'sqlite', 'ttf', 'wav',
  'webp', 'woff', 'woff2', 'zip',
])
const imageExtensions = new Set(['bmp', 'gif', 'heic', 'icns', 'ico', 'jpeg', 'jpg', 'png', 'webp'])
const documentationExtensions = new Set(['md', 'markdown', 'txt', 'rtf'])
const configurationExtensions = new Set([
  'entitlements', 'json', 'pbxproj', 'plist', 'resolved', 'toml', 'xcconfig',
  'xcworkspacedata', 'xml', 'yaml', 'yml',
])

function compareText(left, right) {
  return left < right ? -1 : left > right ? 1 : 0
}

function toPosix(filePath) {
  return filePath.split(path.sep).join('/')
}

function displayRoot(absoluteRoot) {
  const relativeRoot = toPosix(path.relative(repositoryRoot, absoluteRoot))
  if (relativeRoot && relativeRoot !== '..' && !relativeRoot.startsWith('../')) return relativeRoot
  return path.basename(absoluteRoot)
}

function assertDirectory(directory, label) {
  if (!existsSync(directory) || !statSync(directory).isDirectory()) {
    throw new Error(`${label} is missing or is not a directory: ${directory}`)
  }
}

assertDirectory(repositoryRoot, 'repository root')

function collectFiles(directory) {
  const files = []
  const entries = readdirSync(directory, { withFileTypes: true })
    .sort((left, right) => compareText(left.name, right.name))

  for (const entry of entries) {
    if (entry.name === '.DS_Store') continue
    if (entry.isDirectory() && excludedDirectoryNames.has(entry.name)) continue

    const absolutePath = path.join(directory, entry.name)
    if (entry.isDirectory()) {
      files.push(...collectFiles(absolutePath))
    } else if (entry.isFile()) {
      files.push(absolutePath)
    }
  }

  return files
}

function isSensitivePath(displayPath) {
  const filename = path.basename(displayPath)
  return /secret|credential|\.env/i.test(filename)
}

function getExtension(filename) {
  if (filename === '.gitignore') return 'gitignore'
  if (/^\.env(?:\.|$)/i.test(filename)) return 'env'
  const extension = path.extname(filename).slice(1).toLowerCase()
  return extension || 'none'
}

function getKind(displayPath, filename, extension) {
  const normalizedPath = displayPath.toLowerCase()
  if (filename === 'project.pbxproj' || filename === 'project.pbxproj.tmp') return 'Xcode project'
  if (filename === 'Package.resolved') return 'Swift package resolution'
  if (extension === 'swift') return 'Swift'
  if (extension === 'sql') return 'SQL'
  if (documentationExtensions.has(extension)) return extension === 'md' ? 'Markdown' : 'Text'
  if (normalizedPath.includes('.xcassets/')) return 'Asset catalog metadata'
  if (imageExtensions.has(extension)) return 'Image'
  if (extension === 'xcconfig') return 'Xcode configuration'
  if (extension === 'xcworkspacedata') return 'Xcode workspace metadata'
  if (extension === 'gitignore') return 'Git configuration'
  if (configurationExtensions.has(extension)) return 'Configuration'
  if (extension === 'none') return 'Extensionless'
  return extension.toUpperCase()
}

function getCategory(displayPath, sourceRoot, extension) {
  const parts = toPosix(displayPath).split('/')
  const lowerParts = parts.map((part) => part.toLowerCase())
  const filename = parts.at(-1)?.toLowerCase() || ''

  if (lowerParts.some((part) => part.includes('test')) || /tests?\.(swift|m|mm)$/.test(filename)) return 'Tests'
  if (lowerParts.includes('debug') || lowerParts.some((part) => part.includes('diagnostic'))) return 'Debug'
  if (lowerParts.includes('supabase') || extension === 'sql') return 'Database'
  if (
    lowerParts.some((part) => part.endsWith('.xcassets'))
    || lowerParts.some((part) => /icon|logo|previewcontent/.test(part))
    || imageExtensions.has(extension)
  ) return 'Assets'
  if (documentationExtensions.has(extension) || lowerParts.some((part) => /prompt|session|report|roadmap|docs?/.test(part))) {
    return 'Documentation'
  }
  if (
    configurationExtensions.has(extension)
    || extension === 'gitignore'
    || extension === 'env'
    || filename === 'package.resolved'
  ) return 'Configuration'
  if (lowerParts.includes('managers')) return 'Managers'
  if (lowerParts.includes('models')) return 'Models'
  if (lowerParts.includes('views')) return 'Views'
  if (lowerParts.includes('utilities')) return 'Utilities'
  if (/^(app|main|appdelegate|scenedelegate)\.(swift|ts|tsx|js|mjs|py|go|rs)$/.test(filename)) return 'App'
  return 'Other'
}

function countLines(content) {
  const newlineCount = content.match(/\n/g)?.length || 0
  const bareCarriageReturns = content.match(/\r(?!\n)/g)?.length || 0
  return newlineCount + bareCarriageReturns
}

function safelyReadText(absolutePath) {
  const buffer = readFileSync(absolutePath)
  if (buffer.includes(0)) return null

  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(buffer)
  } catch {
    return null
  }
}

function parseSwift(content) {
  const imports = new Set()
  const importPattern = /^\s*(?:(?:@testable|@_exported|@_implementationOnly|@preconcurrency)\s+)?import(?:\s+(?:class|struct|enum|protocol|typealias|func|var|let))?\s+([A-Za-z_][\w.]*)/gm
  for (const match of content.matchAll(importPattern)) imports.add(match[1])

  const declarations = []
  const declarationPattern = /^\s*(?:@\w+(?:\([^\n]*?\))?\s+)*(?:(?:public|package|internal|fileprivate|private(?:\(set\))?|open|final|indirect|nonisolated|isolated|distributed|dynamic|static|required|convenience|override|mutating|nonmutating|lazy|weak|unowned)\s+)*(class|struct|enum|actor|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)/gm
  for (const match of content.matchAll(declarationPattern)) {
    declarations.push({ kind: match[1], name: match[2] })
  }

  return {
    imports: [...imports].sort(compareText),
    declarations,
    declarationCount: declarations.length,
    todoFixmeCount: content.match(/\b(?:TODO|FIXME)\b/gi)?.length || 0,
    fatalSignalCount: content.match(/\b(?:fatalError|preconditionFailure)\s*\(/g)?.length || 0,
  }
}

function isGeneratedPath(displayPath, sourceRoot) {
  const filename = path.basename(displayPath)
  return filename === 'Package.resolved'
    || /(?:^|[._-])(?:generated|autogenerated)(?:[._-]|$)/i.test(displayPath)
}

function createEntry(absolutePath, root, sourceRoot) {
  const displayPath = toPosix(path.relative(root, absolutePath))
  const filename = path.basename(absolutePath)
  const extension = getExtension(filename)
  const stats = statSync(absolutePath)
  const sensitiveMetadataOnly = isSensitivePath(displayPath)
  const extensionSaysBinary = binaryExtensions.has(extension)
  let lineCount = null
  let swift = null
  let isBinary = extensionSaysBinary

  if (!sensitiveMetadataOnly && !extensionSaysBinary) {
    const content = safelyReadText(absolutePath)
    isBinary = content === null
    if (content !== null) {
      lineCount = countLines(content)
      if (extension === 'swift') swift = parseSwift(content)
    }
  }

  return {
    id: `${sourceRoot}:${displayPath}`,
    displayPath,
    sourceRoot,
    category: getCategory(displayPath, sourceRoot, extension),
    filename,
    extension,
    kind: getKind(displayPath, filename, extension),
    byteSize: stats.size,
    modifiedDate: stats.mtime.toISOString(),
    lineCount,
    swift,
    flags: {
      test: /(^|\/)[^/]*tests?(\/|\.|$)/i.test(displayPath),
      legacy: /(^|[/_. -])(?:legacy|old)(?:[/_. -]|$)/i.test(displayPath),
      binary: isBinary,
      generated: isGeneratedPath(displayPath, sourceRoot),
      sensitiveMetadataOnly,
    },
  }
}

function getGitWorkingTreeCounts() {
  let output
  try {
    output = execFileSync(
      'git',
      ['-C', repositoryRoot, 'status', '--porcelain=v1', '-z'],
      {
        encoding: 'utf8',
        env: { ...process.env, GIT_OPTIONAL_LOCKS: '0' },
        stdio: ['ignore', 'pipe', 'pipe'],
      },
    )
  } catch (error) {
    throw new Error(`Unable to read Git status: ${error.message}`)
  }

  const counts = { modified: 0, deleted: 0, untracked: 0 }
  const records = output.split('\0')
  for (let index = 0; index < records.length; index += 1) {
    const record = records[index]
    if (!record) continue
    const status = record.slice(0, 2)
    if (status === '??') {
      counts.untracked += 1
      continue
    }

    const [indexStatus, worktreeStatus] = status
    if (indexStatus === 'D' || worktreeStatus === 'D') counts.deleted += 1
    else if (indexStatus === 'M' || worktreeStatus === 'M') counts.modified += 1
    if (indexStatus === 'R' || indexStatus === 'C') index += 1
  }
  return counts
}

const repositoryFiles = collectFiles(repositoryRoot)
const files = repositoryFiles
  .map((file) => createEntry(file, repositoryRoot, 'repository'))
  .sort((left, right) => {
  const categoryDifference = categoryOrder.get(left.category) - categoryOrder.get(right.category)
  return categoryDifference || compareText(left.displayPath, right.displayPath) || compareText(left.sourceRoot, right.sourceRoot)
})

const categoryCounts = Object.fromEntries(categories.map((category) => [category, 0]))
const kindCounts = {}
const extensionCounts = {}
const importCounts = {}
const declarationsByKind = { class: 0, struct: 0, enum: 0, actor: 0, protocol: 0 }
let swiftFileCount = 0
let physicalSwiftFileCount = 0
let swiftLineCount = 0
let swiftImportCount = 0
let swiftDeclarationCount = 0
let todoFixmeCount = 0
let fatalSignalCount = 0

for (const file of files) {
  categoryCounts[file.category] += 1
  kindCounts[file.kind] = (kindCounts[file.kind] || 0) + 1
  extensionCounts[file.extension] = (extensionCounts[file.extension] || 0) + 1
  if (!file.swift) continue

  physicalSwiftFileCount += 1
  // Keep explicitly old copies searchable and included in line totals without presenting them as active source files.
  if (!file.flags.legacy) swiftFileCount += 1
  swiftLineCount += file.lineCount || 0
  swiftImportCount += file.swift.imports.length
  swiftDeclarationCount += file.swift.declarationCount
  todoFixmeCount += file.swift.todoFixmeCount
  fatalSignalCount += file.swift.fatalSignalCount
  for (const importedModule of file.swift.imports) {
    importCounts[importedModule] = (importCounts[importedModule] || 0) + 1
  }
  for (const declaration of file.swift.declarations) declarationsByKind[declaration.kind] += 1
}

const ids = new Set(files.map((file) => file.id))
const displayPaths = new Set(files.map((file) => file.displayPath))
if (ids.size !== files.length) {
  throw new Error(`Project catalog contains ${files.length - ids.size} duplicate path-based IDs`)
}
if (displayPaths.size !== files.length) {
  throw new Error(`Project catalog contains ${files.length - displayPaths.size} duplicate display paths`)
}

const sortRecord = (record) => Object.fromEntries(
  Object.entries(record).sort(([left], [right]) => compareText(left, right)),
)
const latestModifiedDate = files.reduce(
  (latest, file) => file.modifiedDate > latest ? file.modifiedDate : latest,
  '',
)
const snapshot = {
  displayRoots: {
    repository: displayRoot(repositoryRoot),
  },
  latestModifiedDate,
  fileCount: files.length,
  sourceRootCounts: {
    repository: repositoryFiles.length,
  },
  categoryCounts,
  kindCounts: sortRecord(kindCounts),
  extensionCounts: sortRecord(extensionCounts),
  swift: {
    fileCount: swiftFileCount,
    physicalFileCount: physicalSwiftFileCount,
    legacyFileCount: physicalSwiftFileCount - swiftFileCount,
    lineCount: swiftLineCount,
    importCount: swiftImportCount,
    uniqueImportCount: Object.keys(importCounts).length,
    imports: sortRecord(importCounts),
    declarationCount: swiftDeclarationCount,
    declarationsByKind,
    todoFixmeCount,
    fatalSignalCount,
  },
  gitWorkingTree: getGitWorkingTreeCounts(),
}

const generatedSource = `// Generated by scripts/generate-project-catalog.mjs. Do not edit manually.
export type ProjectSourceRoot = 'repository'
export type ProjectCategory = ${categories.map((category) => `'${category}'`).join(' | ')}
export type SwiftDeclarationKind = 'class' | 'struct' | 'enum' | 'actor' | 'protocol'

export interface SwiftDeclaration {
  kind: SwiftDeclarationKind
  name: string
}

export interface ProjectFileEntry {
  id: string
  displayPath: string
  sourceRoot: ProjectSourceRoot
  category: ProjectCategory
  filename: string
  extension: string
  kind: string
  byteSize: number
  modifiedDate: string
  lineCount: number | null
  swift: null | {
    imports: string[]
    declarations: SwiftDeclaration[]
    declarationCount: number
    todoFixmeCount: number
    fatalSignalCount: number
  }
  flags: {
    test: boolean
    legacy: boolean
    binary: boolean
    generated: boolean
    sensitiveMetadataOnly: boolean
  }
}

export const projectCatalogSnapshot = ${JSON.stringify(snapshot, null, 2)} as const

export const projectCatalog: ProjectFileEntry[] = ${JSON.stringify(files, null, 2)}
`

writeFileSync(outputPath, generatedSource)
console.log(
  `Project catalog: ${files.length} files, ${swiftFileCount} active Swift (${physicalSwiftFileCount} physical) / ${swiftLineCount.toLocaleString('en-US')} lines / ${swiftDeclarationCount} declarations`,
)
console.log(`Generated ${path.relative(appDirectory, outputPath)}`)
