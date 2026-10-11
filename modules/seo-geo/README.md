# Module: seo-geo

An SEO and GEO consultant method as a skill, for projects with a public website. Not part of the
core kit, because many projects have no site to rank.

| Path | What |
|---|---|
| `seo-geo/` | The generic method: research, intent and journey, topical map and linking, content, audits (technical, local, international, conversion), GEO and authority, measurement. Includes standard-library Python scripts: link graph with PageRank, cannibalization, Google autocomplete, App Store reviews. |
| `PROJECT-WRAPPER.template.md` | A thin project skill that holds that project's sources of truth, decisions, rules and paths, and runs the generic method under them. |

## Install

1. Copy `seo-geo/` to `~/.claude/skills/seo-geo/`, so every project can reach it, or to
   `<project>/.claude/skills/seo-geo/` for one project only.
2. Copy the template to `<project>/.claude/skills/<project>-seo/SKILL.md`, fill in the
   placeholders, and record it in `.claude/skills/UPSTREAM.md` under *Written here*.

Origin: written in the GLOOD project, ledger `2026-W41-74`, 2026-10-11. **This module is the source
of truth**, because it is the versioned copy. Installed copies (such as `~/.claude/skills/seo-geo/`) are
refreshed from it. Run `python3 -I seo-geo/scripts/test_scripts.py` after changing a script.
