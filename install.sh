#!/usr/bin/env bash
# install.sh — manual install WITHOUT the plugin system (Git Bash / macOS / Linux).
# Copies the skills into ~/.claude/skills, making them available in every project.
# Prefer the plugin+marketplace flow (see README) for versioning/uninstall.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
dst="${HOME}/.claude/skills"
mkdir -p "$dst"
cp -R "${here}/plugins/dsm-soil/skills/." "$dst/"
echo "Installed DSM skills to $dst"
