# soil-dsm-skills

Portable **Claude Code skills for Digital Soil Mapping**, forged from a knowledge wiki built out of the soil-science literature. Install them into any project and carry them across machines.

Distributed as a **Claude Code plugin** (`dsm-soil`) via this repo, which doubles as a **plugin marketplace**.

## The skills (9)

| Skill | What it does |
|---|---|
| `soil-fertility-mapping` | Multi-property fertility maps → Soil Fertility Index with two-axis uncertainty |
| `spatial-prediction-uncertainty` | Per-pixel intervals + area-of-applicability (AOA/LPD/DI) via CAST; Monte-Carlo to class |
| `soil-sampling-design` | Choose a sampling design by objective (cLHS-family, DL, Reference Area, heterogeneity-adaptive, cost, space-time) |
| `ml-for-soil-prediction` | Choose/tune/validate ML for soil (no universal winner; feature engineering; interpretability) |
| `digital-soil-mapping-workflow` | End-to-end DSM project workflow (scorpan → sampling → model → mapped uncertainty) |
| `soil-map-validation` | CV strategy, accuracy metrics, honest uncertainty, aggregation |
| `rothc-temporal-modelling` | Set up / calibrate / validate RothC over time |
| `hybrid-process-ml-soc` | Fuse RothC + ML for space-time SOC (POML) |
| `soc-stock-mrv` | SOC-stock MRV & carbon crediting |

## Install (recommended: plugin + marketplace)

On any machine with Claude Code, add this repo as a marketplace, then install the plugin:

```
/plugin marketplace add YOUR_GH_USER/soil-dsm-skills
/plugin install dsm-soil
```

(Replace `YOUR_GH_USER` with your GitHub username. For a private repo, make sure your Claude Code is authenticated to GitHub.) Update later with a `git push` here, then reinstall/upgrade from the `/plugin` menu. Uninstall cleanly from the same menu.

## Install (fallback: no plugin system)

Copies the skills into your personal `~/.claude/skills/` folder (global on this machine):

- Windows (PowerShell): `powershell -ExecutionPolicy Bypass -File install.ps1`
- Git Bash / macOS / Linux: `bash install.sh`

## How the skills are built (self-contained)

The **source of truth is the Obsidian wiki** (`Soil_skill/skills-forge/<name>/SKILL.md`), where each skill is richly cross-linked with `[[wiki links]]` to concept/method/source pages. Those links don't resolve outside the vault, so `build.ps1`:

1. reads each vault `SKILL.md`,
2. **flattens** every `[[target|alias]]` → `alias` and `[[a/b/c]]` → `c`, leaving clean readable text,
3. writes a **self-contained** `SKILL.md` into `plugins/dsm-soil/skills/<name>/`.

Re-run after editing skills in the vault:

```
powershell -ExecutionPolicy Bypass -File build.ps1
git add -A && git commit -m "rebuild skills" && git push
```

So: **edit in the vault → `build.ps1` → commit → push.** The vault keeps the full linked knowledge base; this repo ships the portable, standalone skills.

## Layout

```
soil-dsm-skills/
├── .claude-plugin/marketplace.json     # marketplace manifest (lists the plugin)
├── plugins/dsm-soil/
│   ├── .claude-plugin/plugin.json      # plugin manifest
│   └── skills/<name>/SKILL.md          # the 9 self-contained skills (built)
├── build.ps1                           # compile skills from the vault
├── install.ps1 / install.sh            # manual install fallback
└── README.md
```
