# CLAUDE.md — tabular

This file provides guidance to Claude Code when working with code in this
repository. Global directives load from `~/.claude/CLAUDE.md`; deeper
project detail (industry references, smoke tests, the full roxygen
standard) lives in the gitignored `CLAUDE.local.md`.

## Project overview

`tabular` is an R package for rendering clinical submission **tables,
listings, and figures** (TFL) to RTF, LaTeX, Typst, HTML, PDF, DOCX, and
Markdown from one immutable verb pipeline. It is **display-only**: the
input is a pre-summarised wide data frame (one row in = one display row);
the package never aggregates or computes statistics. The user interface is
built around a few core verbs: `tabular()`, `cols()`, `group_rows()`,
`headers()`, `sort_rows()`, `subgroup()`, `paginate()`, `style()`,
`preset()`, `footnote()`, `figure()`, and `emit()`.

## Architecture

### Core rendering flow (three phases)

```
3  Emit       backend_<fmt>(grid, file) -> file    per backend (rtf/latex/typst/html/docx/md/pdf)
2  Resolve    engine_finalize(spec) -> grid        decimal align / BigN / tokens / pagination
1  Build      tabular_spec (S7)                    tabular() |> cols() |> headers() |> ...
0  Input      pre-summarised wide data.frame       one row per display row
```

- Each verb validates its arguments at call time (friendly
  `tabular_error_input` via the `check_*` helpers in `R/sanity.R`),
  updates one property, and returns a **new immutable spec** via
  `S7::set_props()`. Nothing renders until `emit()`.
- `emit()` dispatches on the file extension (`.rtf` `.tex` `.typ` `.html`
  `.docx` `.md` `.pdf`) or an explicit `format =`. A `.pdf` target has
  **two engines**: LaTeX (default when a usable TeX is found) and Typst
  (fallback; the standalone `typst` binary or Quarto's bundled copy).
- `as_grid(spec)` resolves the grid without writing a file — the
  pre-backend IR (`tabular_grid`: `@pages` + `@metadata`).
- Backends are isolated: each receives the fully-resolved grid and only
  renders. They register themselves via `.register_backend()` at load.

### File organization

- `R/aaa_class.R` — S7 class definitions (loads first alphabetically).
- `R/<verb>.R` — one file per verb (`cols.R`, `paginate.R`, ...).
- `R/engine_*.R` — resolve-phase passes (decimal, footnotes, pagination,
  group display).
- `R/backend_<fmt>.R` — one file per output format; `backend_pdf.R`
  (LaTeX engine) and `backend_typst_pdf.R` (Typst engine) compile the
  corresponding source backends.
- `R/fonts.R`, `R/font_metrics.R` — AFM font metrics; column widths and
  decimal alignment are measured, not guessed.
- `tests/testthat/test-<source>.R` mirrors each `R/` file exactly.
- `pkgdown/assets/skills/tabular/SKILL.md` — the AI/Agents skill served
  on the pkgdown site (indexed into `llms.txt` by CI).

### Output format details

- **RTF** (`.rtf`): RTF 1.9.1, Word paginates natively; per-row keep via
  `\keepn`; submission deliverable.
- **LaTeX** (`.tex`): `tabularray` `longtblr`; bundled `.sty` staged when
  the local TeX lacks it.
- **Typst** (`.typ`): native `#table` with repeating header/footer;
  keep-with-next enforced through unbreakable rowspans in a hidden 0pt
  column; compiles standalone via `typst compile`.
- **PDF** (`.pdf`): compiled from the LaTeX or Typst source (engine
  probe: LaTeX first, Typst fallback; `format = "latex"` / `"typst"`
  overrides). Diagnostics: `check_latex()`, `check_typst()`.
- **HTML** (`.html`): self-contained Bootstrap document, continuous (no
  pagination); also the live preview medium (knitr / pkgdown).
- **DOCX** (`.docx`): native OOXML zip, no pandoc/Office; Word paginates
  natively with `keepNext`.
- **Markdown** (`.md`): GitHub-flavored pipe table, continuous.

## R package development

### Key commands

```
# Run code interactively
Rscript -e "devtools::load_all(); <code>"

# Run all tests
Rscript -e "devtools::test()"

# Run tests for files starting with {name}
Rscript -e "devtools::test(filter = '^{name}')"

# Run tests for R/{name}.R
Rscript -e "devtools::test_active_file('R/{name}.R')"

# Re-document (regenerates man/*.Rd and NAMESPACE)
Rscript -e "devtools::document()"

# Check that every topic is in the reference index
Rscript -e "pkgdown::check_pkgdown()"

# R CMD check
Rscript -e "devtools::check()"

# Format code (non-negotiable, runs as a PostToolUse hook)
air format R/ tests/
```

### The inner loop (after every change)

Run all four, in order, before any commit. Target: 0 failures / 0
warnings / 0 errors / 0 notes.

```
Rscript -e "devtools::document()"
Rscript -e "devtools::test()"
Rscript -e "devtools::check(args = '--no-manual')"
air format R/ tests/
```

The sponsor-name guard (`.local/scripts/check-sponsor-names.sh`) runs at
`git push` time only, not in this loop.

### Coding

- snake_case throughout; exported verbs are bare (`tabular()`, `cols()`,
  `emit()`), internals are dot-prefixed (`.resolve_col_widths`).
- Base R plus targeted dependencies. No tidyverse in `Imports`.
- Use the base pipe (`|>`), never magrittr (`%>%`).
- The package targets R >= 4.3, so `\() ...` anonymous functions and the
  `_` placeholder pipe are fine.
- S7 is the OOP system. Properties are read with `@` and updated with
  `S7::set_props()`; each verb returns a new, immutable spec.
- Errors go through `cli::cli_abort(msg, class = "tabular_error_<kind>",
  call)` — never bare `stop()` / `rlang::abort()`. Kinds: `input`,
  `runtime`, `backend`, `spec`.
- `vapply()` not `sapply()`; `seq_along()` / `seq_len()` not `1:n`;
  `anyNA()` for NA checks. No `library()` in `R/` — qualify with `::`.

### Testing

- Tests for `R/{name}.R` live in `tests/testthat/test-{name}.R`; mirror
  the source file name. testthat edition 3.
- All new code ships with a test. **Bug fixes are test-first**: write the
  failing regression test (red on the prior code), then fix it (green),
  referencing the issue in the test name.
- Reach internals with `tabular:::.fn` so tests survive `R CMD check`.
- Backend output is pinned with `expect_snapshot_file()` byte snapshots;
  error messages with `expect_snapshot(error = TRUE)` plus an
  `expect_error(..., class = "tabular_error_<kind>")`.
- Use bundled demo data (`saf_demo`, `saf_aesocpt`, `saf_vital`,
  `eff_resp`, ...); do not invent toy data per test.

### Documentation

- Every exported verb has roxygen with `@return` and runnable
  `@examples` (no `\dontrun{}` / `\donttest{}`); examples are complete
  clinical pipelines that run under `R CMD check`. The full doc standard
  is in `CLAUDE.local.md`.
- Internal helpers use plain `#` comments, not roxygen.
- Re-document after any roxygen change, and add new topics to
  `_pkgdown.yml`; verify with `pkgdown::check_pkgdown()`.
- Vignettes and README are `.qmd` (Quarto). README.md is generated from
  README.qmd via `devtools::build_readme()` — edit the `.qmd`.

### `NEWS.md`

- Every user-facing change gets a bullet under the top development
  heading. Skip bullets for internal refactors and small doc fixes.
- A bullet is one issue, past tense, ending in a period, with the issue
  reference in parentheses where one exists; no line wrapping.
- Put the function name early in the bullet; order bullets
  alphabetically by function name, with non-function bullets first.

### GitHub

- When reading an issue with `gh`, always pass `--comments`.
- Branch for every new task; never commit new work directly to `main`.
- No AI attribution in commits or PRs.
- **Never merge a PR into `main` while any check fails — including
  `codecov/patch` (≥ 95% patch coverage), even though it is not a
  required check.** Find the uncovered diff lines (codecov report or
  `covr::zero_coverage()`) and add tests that execute them before
  merging. OS- or device-conditional branches are covered by mocking
  the boundary (`testthat::local_mocked_bindings` with `.package =`
  for foreign namespaces — own-namespace mocks do not engage under
  covr), not waived.

### Doc-sync surfaces (merge gate into `main`)

Two documentation surfaces must track the package with **every
user-facing change**, in the same branch as the change:

- **`CITATION.cff`** — `version:` and `title:` mirror DESCRIPTION;
  refresh the abstract when the backend/feature surface changes.
- **AI/Agents skill** (`pkgdown/assets/skills/tabular/SKILL.md`) — new
  or renamed exports, backends, file extensions, and conventions land
  here too (it is served on the pkgdown site and indexed into
  `llms.txt` / `llms-full.txt` by the pkgdown workflow).

Also re-check the human surfaces the change touches: README.qmd (then
`devtools::build_readme()`), `vignettes/tabular.qmd`, and
`vignettes/articles/output.qmd` (backends, engine requirements).

The mechanical part is enforced: `Rscript tools/check-doc-sync.R` must
pass before merging to `main` (CI runs it on every PR via
`.github/workflows/doc-sync.yaml` — CITATION.cff version/title parity
with DESCRIPTION, and every NAMESPACE export mentioned in the skill).

### Writing

- Sentence case for headings; US English.
- Em-dashes, en-dashes, and curly quotes are canonical in prose,
  comments, and roxygen. The one hard exception: keep `cli_abort()` /
  `cli_warn()` / `cli_inform()` message strings ASCII (a comma or a
  split `c()` entry instead of an em-dash).

### Proofreading

If asked to proofread a file, act as an expert editor. Work paragraph by
paragraph, starting with a TODO list of one item per top-level heading.
Fix spelling, grammar, and minor problems without asking; label unclear
or ambiguous sentences with a `FIXME` comment. Report only what changed.

## More detail

See `build.md` for the dev loop, `debugging.md` for troubleshooting, and
`CLAUDE.local.md` for the pipeline architecture, the `emit()` dispatch
table, the full roxygen standard, smoke-test protocol, and industry
references.
