#!/usr/bin/env bash
# Copy the input files in; fixture skills are stored as SKILL.fixture.md so that no agent
# loads them as real skills, and get their real name back here.
set -eu
cp -R "$(dirname "$0")/files/." .
find . -name SKILL.fixture.md | while read -r f; do mv "$f" "$(dirname "$f")/SKILL.md"; done
