# CLAUDE.md — tabular

Native rendering of clinical submission tables, listings, and figures to
RTF, LaTeX, HTML, PDF, and DOCX from one immutable verb pipeline.

Global directives load from `~/.claude/CLAUDE.md`; deeper project detail
(industry references, smoke tests, the full roxygen standard) lives in the
gitignored `CLAUDE.local.md`. This file is the shared, checked-in guide.

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
