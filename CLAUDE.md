# CLAUDE.md — tabular

TFL rendering for regulatory submissions (RTF / PDF / HTML / LaTeX).
Replaces arframe.

Global directives load from `~/.claude/CLAUDE.md`. This file holds
project-specific shared conventions.

## Project state

Fresh repo. Scaffolding TBD.

## Conventions

- snake_case, package prefix on exports.
- Base R + targeted deps; no tidyverse in `Imports`.
- Test-first for new exports. roxygen2 examples must run.
- `air` formats after edits.

See `build.md` for the dev loop. See `debugging.md` for troubleshooting.
