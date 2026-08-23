// Generates src/data/skillsCatalog.ts from .claude/skills/*/SKILL.md.
//
// WHY A GENERATOR AND NOT A HAND-KEPT LIST
//   A skills list maintained by hand is exactly the document that keeps turning up stale.
//   In the originating project a hand-kept file-size review row was 1,759 lines out of
//   date before anyone checked it. The skills are already on disk in a fixed shape;
//   anything that has to be remembered separately will eventually disagree with them.
//
// WHAT IT READS
//   Each skill's YAML frontmatter (name, description) and the provenance table in
//   .claude/skills/UPSTREAM.md, which records where each one came from. A skill present
//   on disk but absent from UPSTREAM.md is reported as `unrecorded` rather than skipped —
//   the gap is the finding, and hiding it would defeat the point.
//
// Roots are resolved and sentinel-validated in project-paths.mjs — see the note there on
// why they are found from `.git` and read from governance.config.json rather than taken
// from the environment.

import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs'
import path from 'node:path'

import { fileURLToPath } from 'node:url'

import { repositoryRoot } from './project-paths.mjs'

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url))
const appDirectory = path.resolve(scriptDirectory, '..')

const skillsRoot = path.join(repositoryRoot, '.claude', 'skills')
const upstreamPath = path.join(skillsRoot, 'UPSTREAM.md')
// Resolved from this script's own location, not from the configured dashboard directory:
// the generator runs from inside the app, so where it lives is a fact, while the config
// value is a claim that could disagree after the dashboard is moved.
const outputPath = path.join(appDirectory, 'src', 'data', 'skillsCatalog.ts')

/** `name:` and `description:` out of the YAML frontmatter, which may wrap over lines. */
function parseFrontmatter(markdown) {
  const match = markdown.match(/^---\n([\s\S]*?)\n---/)
  if (!match) return { name: '', description: '' }
  const block = match[1]
  const field = (key) => {
    // A value can continue onto following lines as long as they are indented, which is
    // how every description in this repo is written — they are long by design, since the
    // description is what decides whether a skill fires at all.
    const re = new RegExp(`^${key}:\\s*([\\s\\S]*?)(?=\\n\\S|$)`, 'm')
    const m = block.match(re)
    return m ? m[1].split('\n').map((l) => l.trim()).join(' ').trim() : ''
  }
  return { name: field('name'), description: field('description') }
}

/**
 * Provenance, read from UPSTREAM.md's two tables rather than from a second hand-kept list.
 * Returns a map of directory name to origin.
 */
function parseProvenance() {
  if (!existsSync(upstreamPath)) return {}
  const text = readFileSync(upstreamPath, 'utf8')
  const provenance = {}
  // Rows look like: | `grilling/` | `skills/productivity/grilling/` | `SKILL.md` |
  // Which section a row sits in decides its origin, so the offsets are found once.
  const forksAt = text.indexOf('## Forks')
  const ownAt = text.indexOf('## Written here')
  for (const match of text.matchAll(/^\|\s*`([a-z0-9-]+)\/`\s*\|/gm)) {
    const dir = match[1]
    const at = match.index ?? 0
    if (ownAt !== -1 && at > ownAt) provenance[dir] = 'written-here'
    else if (forksAt !== -1 && at > forksAt) provenance[dir] = 'fork'
    else provenance[dir] = 'vendored'
  }
  return provenance
}

if (!existsSync(skillsRoot)) {
  // Loud, and not fatal. Unlike the ledger or the tracker, a project may legitimately
  // have no .claude/skills — but it must never look like a project with zero skills.
  console.error(`Skills catalog: SKIPPED — no ${path.relative(repositoryRoot, skillsRoot)} directory.`)
  process.exit(0)
}

const provenance = parseProvenance()

const skills = readdirSync(skillsRoot)
  .filter((entry) => statSync(path.join(skillsRoot, entry)).isDirectory())
  .filter((entry) => existsSync(path.join(skillsRoot, entry, 'SKILL.md')))
  .sort((left, right) => left.localeCompare(right, 'en'))
  .map((dir) => {
    const skillPath = path.join(skillsRoot, dir, 'SKILL.md')
    const markdown = readFileSync(skillPath, 'utf8')
    const { name, description } = parseFrontmatter(markdown)
    const supporting = readdirSync(path.join(skillsRoot, dir))
      .filter((f) => f !== 'SKILL.md')
    return {
      directory: dir,
      name: name || dir,
      description,
      lines: markdown.split('\n').length,
      supportingFiles: supporting,
      // 'unrecorded' is a finding, not a default. A skill on disk that UPSTREAM.md does
      // not mention has no recorded source, which the rule in
      // .claude/rules/skills-stay-indexed.md exists to prevent.
      origin: provenance[dir] ?? 'unrecorded',
      // A skill the model can never reach on its own. Reachable only when typed.
      userInvokedOnly: /disable-model-invocation:\s*true/.test(markdown),
    }
  })

const unrecorded = skills.filter((s) => s.origin === 'unrecorded')

const source = `// Generated by scripts/generate-skills-catalog.mjs. Do not edit manually.

/** Where a skill came from. \`unrecorded\` means UPSTREAM.md does not mention it. */
export type SkillOrigin = 'vendored' | 'fork' | 'written-here' | 'unrecorded'

export interface SkillEntry {
  directory: string
  name: string
  description: string
  lines: number
  supportingFiles: string[]
  origin: SkillOrigin
  /** True when the skill declares disable-model-invocation, so only a person can reach it. */
  userInvokedOnly: boolean
}

export const skills: SkillEntry[] = ${JSON.stringify(skills, null, 2)} as unknown as SkillEntry[]

export const skillsStats = ${JSON.stringify({
  total: skills.length,
  userInvokedOnly: skills.filter((s) => s.userInvokedOnly).length,
  vendored: skills.filter((s) => s.origin === 'vendored').length,
  forks: skills.filter((s) => s.origin === 'fork').length,
  writtenHere: skills.filter((s) => s.origin === 'written-here').length,
  unrecorded: unrecorded.length,
}, null, 2)} as const
`

writeFileSync(outputPath, source)
console.log(
  `Skills catalog: ${skills.length} skill(s)`
  + ` — ${skills.filter((s) => s.userInvokedOnly).length} user-invoked only`
  + (unrecorded.length
    ? `, ⚠️ ${unrecorded.length} with no provenance in UPSTREAM.md: ${unrecorded.map((s) => s.directory).join(', ')}`
    : ', all with recorded provenance'),
)
