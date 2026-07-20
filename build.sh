#!/usr/bin/env bash
# build.sh - Git Bash / macOS / Linux twin of build.ps1.
# Compiles the forged skills from the Obsidian vault into self-contained,
# portable Claude Code skills: flattens [[wiki links]] so each skill stands alone.
# Re-run after editing skills in the vault, then commit + push (or use release.ps1).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

# Vault location (source of truth). Override with DSM_VAULT; otherwise defaults
# to a sibling 'Soil_skill/skills-forge' next to this repo.
vault="${DSM_VAULT:-${here}/../Soil_skill/skills-forge}"
out="${here}/plugins/dsm-soil/skills"
skills=(
  soil-map-validation ml-for-soil-prediction digital-soil-mapping-workflow
  soc-stock-mrv rothc-temporal-modelling hybrid-process-ml-soc
  soil-fertility-mapping spatial-prediction-uncertainty soil-sampling-design
)
note=$'\n\n---\n_Portable build from the DSM knowledge wiki (the source of truth). Obsidian cross-references were flattened for standalone use; regenerate with build.sh._\n'

n=0
for s in "${skills[@]}"; do
  src="${vault}/${s}/SKILL.md"
  if [[ ! -f "$src" ]]; then echo "MISSING: $src" >&2; continue; fi
  mkdir -p "${out}/${s}"
  # [[target|alias]] -> alias ; [[a/b/c]] -> c (last path segment). -0777 = slurp whole
  # file so links that wrap across lines are matched too.
  perl -0777 -pe 's/\[\[[^\]\|]+\|([^\]]+)\]\]/$1/g; s{\[\[([^\]\|]+)\]\]}{ (split m!/!, $1)[-1] }ge' "$src" > "${out}/${s}/SKILL.md"
  printf '%s' "$note" >> "${out}/${s}/SKILL.md"
  echo "compiled: $s"
  n=$((n+1))
done
echo "done - ${n} skill(s) -> ${out}"
