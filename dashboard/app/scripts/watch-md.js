import { watch } from 'chokidar'
import { execFile } from 'node:child_process'
import { realpathSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { promisify } from 'node:util'

import { repositoryRoot, reportsRoot, sourceRoot } from './project-paths.mjs'

const execFileAsync = promisify(execFile)
const scriptDirectory = path.dirname(fileURLToPath(import.meta.url))
const appDirectory = realpathSync(path.resolve(scriptDirectory, '..'))

// Roots are found from the repository and sentinel-validated in project-paths.mjs.
// The watcher benefits most from the loud failure — it runs unattended, so a
// silently retargeted root here would produce wrong output for as long as it
// stayed up.
const reportRoots = [reportsRoot]
const projectRoots = [sourceRoot]
const watchedFolders = [...new Set([...reportRoots, ...projectRoots])]

const ignoredDirectoryNames = new Set([
  '.git',
  'build',
  'DerivedData',
  'xcuserdata',
  'node_modules',
  'dist',
])
const npmCommand = process.platform === 'win32' ? 'npm.cmd' : 'npm'

function isReportFile(filePath) {
  const extension = path.extname(filePath).toLowerCase()
  return extension === '.md' || extension === '.txt'
}

function isIgnored(filePath) {
  if (path.basename(filePath) === '.DS_Store') return true
  return filePath.split(path.sep).some((part) => ignoredDirectoryNames.has(part))
}

function isWithin(root, filePath) {
  const relativePath = path.relative(root, filePath)
  return relativePath === '' || (!relativePath.startsWith('..') && !path.isAbsolute(relativePath))
}

function isRelevantFile(filePath) {
  if (isIgnored(filePath)) return false
  if (projectRoots.some((root) => isWithin(root, filePath))) return true
  return reportRoots.some((root) => isWithin(root, filePath)) && isReportFile(filePath)
}

console.log('Watching report Markdown/TXT and complete project inventory roots:')
reportRoots.forEach((folder) => console.log(`  reports: ${folder}`))
projectRoots.forEach((folder) => console.log(`  project: ${folder}`))

let isRunning = false
let rerunRequested = false
let debounceTimer = null

async function runExtraction() {
  if (isRunning) {
    rerunRequested = true
    return
  }

  isRunning = true
  do {
    rerunRequested = false
    console.log(`\n${new Date().toLocaleTimeString()} — running complete extraction...`)

    try {
      const { stdout, stderr } = await execFileAsync(npmCommand, ['run', 'generate'], { cwd: appDirectory })
      if (stdout.trim()) console.log(stdout.trim())
      if (stderr.trim()) console.error(stderr.trim())
      console.log('Extraction complete. Refresh the dashboard.\n')
    } catch (error) {
      console.error('Extraction failed:', error.message)
    }
  } while (rerunRequested)

  isRunning = false
}

function scheduleExtraction(eventName, filePath) {
  if (!isRelevantFile(filePath)) return

  console.log(`${eventName}: ${path.relative(repositoryRoot, filePath)}`)
  clearTimeout(debounceTimer)
  debounceTimer = setTimeout(runExtraction, 500)
}

const watcher = watch(watchedFolders, {
  persistent: true,
  ignoreInitial: true,
  ignored: (filePath) => isIgnored(filePath),
  awaitWriteFinish: { stabilityThreshold: 300, pollInterval: 100 },
})

watcher.on('add', (filePath) => scheduleExtraction('Added', filePath))
watcher.on('change', (filePath) => scheduleExtraction('Changed', filePath))
watcher.on('unlink', (filePath) => scheduleExtraction('Removed', filePath))
watcher.on('unlinkDir', (filePath) => scheduleExtraction('Removed directory', filePath))
