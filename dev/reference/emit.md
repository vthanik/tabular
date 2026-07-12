# Render a `tabular_spec` to a file

Resolve `spec` through the engine pipeline, dispatch to the backend
registered for the chosen format, and (optionally) write a QC data file
and a CDISC ARS audit manifest alongside the rendered artefact. `emit()`
is the package's terminal verb — it returns `file` invisibly so the call
can sit at the bottom of a pipe without losing the path.

## Usage

``` r
emit(
  .spec,
  file,
  format = NULL,
  data_file = NULL,
  manifest = FALSE,
  create_dir = FALSE
)
```

## Arguments

- .spec:

  *The `tabular_spec` to render.* `<tabular_spec>: required`. The full
  verb chain
  ([`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md)
  -\>
  [`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md)
  -\>
  [`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md)
  -\>
  [`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md)
  -\>
  [`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
  -\>
  [`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md)
  -\>
  [`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md))
  feeds into `emit()`'s first argument by pipe.

- file:

  *Destination path for the rendered artefact.*
  `<character(1)>: required`. Extension drives the backend (see the
  dispatch table in the Details section). The parent directory must
  already exist; `emit()` does not auto-create directories.

  **Tip:** Use `tempfile(fileext = ".md")` inside vignettes and examples
  so the example runs in `R CMD check` without polluting the package
  directory.

- format:

  *Explicit backend override.* `<character(1) | NULL>: default NULL`.
  When set, wins over the file extension. Useful for writing `.txt`
  files that should contain RTF, for round-trip testing, or when the
  user has a custom backend registered under a non-standard name.

- data_file:

  *QC artefact writer.*
  `<character(1) | function(file) -> character(1) | NULL>:`
  `default NULL`. When set, writes the resolved wide data frame
  alongside the render. A character path writes there directly; a lambda
  receives the render path and returns the data file path (typical for
  sponsor-flexible naming).

  **Restriction:** Returned-path extension must be `.csv`, `.tsv` /
  `.txt`, or `.rds`. **Tip:** The data frame the lambda governs is
  pre-backend — the same CSV is emitted regardless of whether `file` is
  RTF, PDF, or DOCX.

      # Three canonical sponsor patterns for the lambda.
      data_file = \(f) paste0(tools::file_path_sans_ext(f), "_qc.csv")
      data_file = \(f) file.path(
        "validation",
        paste0("val_", basename(tools::file_path_sans_ext(f)), ".csv")
      )
      data_file = \(f) file.path(
        "rd",
        paste0("rd_", basename(tools::file_path_sans_ext(f)), ".rds")
      )

- manifest:

  *Emit the CDISC ARS audit manifest sidecar.*
  `<logical(1)>: default FALSE`. `TRUE` writes `<file>.audit.yml` with
  verbatim CDISC ARS LDM v1.0 Output keys; see the **`manifest = TRUE`**
  invariant in the Details section for what the file contains and the
  determinism contract it satisfies.

- create_dir:

  *Create the destination directory if it is missing.*
  `<logical(1)>: default FALSE`. When `TRUE`, the parent directory of
  `file` (and any missing ancestors) is created recursively before
  rendering, instead of aborting. The default `FALSE` keeps the safe
  behaviour of erroring on a missing parent.

## Value

*The `file` path, invisibly.* Use this when chaining `emit()` into a
downstream consumer that needs the resolved path (e.g. printing the link
in a Quarto chunk, copying the sidecar manifest into an archive,
attaching the render to a submission folder builder).

## Details

**Validation before I/O.** Every argument is validated and the backend
is resolved BEFORE the engine runs. An unsupported extension, a
malformed `data_file` path, or a missing backend raises
`tabular_error_input` without writing any file. A spec that resolves
cleanly but whose backend errors mid-write may leave a partial file
behind; this is the only failure mode that touches disk.

**Backend dispatch.** The effective backend is resolved from the file
extension via the table below; the `format` argument always wins when
both are supplied. Each backend lives in its own `R/backend_<fmt>.R`
file and self-registers at package load time.

|                    |         |                            |
|--------------------|---------|----------------------------|
| extension(s)       | format  | backend                    |
| `.md`, `.markdown` | `md`    | GFM pipe table             |
| `.html`, `.htm`    | `html`  | self-contained Bootstrap 5 |
| `.tex`, `.latex`   | `latex` | tabularray                 |
| `.pdf`             | `pdf`   | tinytex compile of LaTeX   |
| `.rtf`             | `rtf`   | RTF 1.9.1, native          |
| `.docx`            | `docx`  | OOXML native, no JVM       |

Unknown extensions, missing extensions, and formats with no registered
backend all raise `tabular_error_input`. The error message lists the
currently registered formats so the failure is actionable.

**`data_file` is sponsor-neutral.** Pass an explicit path
(`"out/qc.csv"`) for a fixed location, or a lambda
(`function(file) -> path`) for sponsor-flexible naming. The lambda
receives the resolved render path so it can derive the QC file from it
(suffix, sibling folder, separate sponsor-styled name). Recognised
extensions on the returned path are `.csv`, `.tsv` (alias: `.txt`), and
`.rds`; anything else raises `tabular_error_input`. The written data
frame is the post-
[`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md)
/ post-`engine_decimal()` wide grid — exactly the cell text the backend
wrote.

**`manifest = TRUE` writes a sidecar.** The audit manifest is written to
`<file>.audit.yml` next to the render (e.g. `out.md` -\>
`out.audit.yml`). Keys are CDISC ARS LDM v1.0 Output verbatim: `id`,
`name`, `programmingCode` (best-effort git + R + platform

- timestamp), `fileSpecifications` (sha256 of every emitted artefact
  including `data_file`), `displays/displaySections` (Title / Header /
  Body / Footnote), `referencedAnalyses` (empty in v0.1; reserved for
  the mintverse handoff), `x-tabular` (rendering geometry, pagination,
  style trace, input provenance). Determinism contract: two consecutive
  `emit()` calls are byte- identical except for the `rendered_at`
  parameter timestamp; the YAML round-trips through
  [`yaml::read_yaml()`](https://yaml.r-lib.org/reference/read_yaml.html) +
  [`yaml::write_yaml()`](https://yaml.r-lib.org/reference/write_yaml.html).

**Pure dispatcher.** `emit()` does not do any rendering itself; it
composes
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md)
with a backend writer. To inspect the resolved grid without writing a
file (during development, or to build a custom downstream consumer),
call
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md)
directly.

## See also

**No-I/O sibling:**
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md)
returns the resolved grid without writing a file — use during
development to inspect what `emit()` would hand a backend.

**Build verbs the pipeline feeds from:**
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md),
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md),
[`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md).

**Inline formatting helpers:**
[`md()`](https://vthanik.github.io/tabular/dev/reference/md.md),
[`html()`](https://vthanik.github.io/tabular/dev/reference/html.md)
(titles, footnotes, labels, cell text).

## Examples

``` r
# ---- Example 1: Render demographics to Markdown ----
#
# Smallest possible emit: spec in, .md out. The backend is chosen
# from the file extension; the engine pipeline runs internally,
# then the registered md backend writes a GFM pipe table you can
# preview in any Markdown renderer. tempfile() keeps the example
# clean for `R CMD check`.
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

demo <- tabular(
  cdisc_saf_demo,
  titles = c(
    "Table 14.1.1",
    "Demographics and Baseline Characteristics",
    "Safety Population"
  ),
  footnotes = "Source: ADSL."
) |>
  cols(
    variable   = col_spec(label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo  = col_spec(label = "Placebo\nN={n['placebo']}",  align = "decimal"),
    drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}",  align = "decimal"),
    drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}", align = "decimal"),
    Total    = col_spec(label = "Total\nN={n['Total']}",    align = "decimal")
  ) |>
  group_rows(by = "variable") |>
  sort_rows(by = c("variable", "stat_label"))

demo_md <- tempfile(fileext = ".md")
emit(demo, demo_md)

# ---- Example 2: Render + QC data + CDISC audit manifest ----
#
# The clinical double-programming pattern: render the table,
# write a QC CSV alongside it for an independent programmer to
# verify cell-for-cell, and emit the CDISC ARS audit manifest
# for submission packaging. The lambda derives the QC path from
# the render path so the sponsor's naming convention lives in one
# place.

ae_spec <- tabular(
  cdisc_saf_aesocpt,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by SOC and Preferred Term",
    "Safety Population"
  ),
  footnotes = "Subjects counted once per SOC and once per PT."
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    soc_n    = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = "Placebo\nN={n['placebo']}",  align = "decimal"),
    drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}",  align = "decimal"),
    drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}", align = "decimal"),
    Total    = col_spec(label = "Total\nN={n['Total']}",    align = "decimal")
  ) |>
  sort_rows(by = c("soc_n", "n_total"), descending = c(TRUE, TRUE))

ae_md <- tempfile(fileext = ".md")
emit(
  ae_spec,
  ae_md,
  data_file = \(f) paste0(tools::file_path_sans_ext(f), "_qc.csv"),
  manifest  = TRUE
)

# ---- Example 3: Same spec, four backends — one-loop fan-out ----
#
# `emit()` dispatches by file extension, so the same spec can
# render to every backend in one loop. Useful for visual diffs
# across formats during development and for shipping a build
# artefact set (RTF for submission, HTML for review, PDF for the
# CSR appendix).
eff_spec <- tabular(cdisc_eff_resp, titles = "Best Overall Response") |>
  cols(
    stat_label  = col_spec(label = "Response"),
    row_type    = col_spec(visible = FALSE),
    groupid     = col_spec(visible = FALSE),
    group_label = col_spec(visible = FALSE),
    placebo     = col_spec(label = "Placebo",  align = "decimal"),
    drug_50     = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100    = col_spec(label = "Drug 100", align = "decimal")
  )

out_dir <- tempfile()
dir.create(out_dir)
for (ext in c(".html", ".rtf", ".tex", ".docx", ".md")) {
  emit(eff_spec, file.path(out_dir, paste0("eff", ext)))
}
list.files(out_dir)
#> [1] "eff.docx" "eff.html" "eff.md"   "eff.rtf"  "eff.tex" 

# ---- Example 4: QC artefact via data_file alongside the render ----
#
# `emit(data_file = ...)` writes the resolved post-engine wide
# data frame alongside the rendered table. The sponsor's QC
# programmer picks up the side-car .csv (or .rds) and validates
# cell values without parsing the rendered RTF.
rtf_out  <- tempfile(fileext = ".rtf")
data_out <- tempfile(fileext = ".csv")
emit(eff_spec, rtf_out, data_file = data_out)
file.exists(rtf_out)
#> [1] TRUE
file.exists(data_out)
#> [1] TRUE

# ---- Example 5: Render into a not-yet-existing output folder ----
#
# `create_dir = TRUE` builds the destination directory tree on the
# fly, so a submission-folder layout can be written in one pass
# without a separate `dir.create()` step.
nested <- file.path(tempfile(), "tables", "safety", "eff.md")
emit(eff_spec, nested, create_dir = TRUE)
file.exists(nested)
#> [1] TRUE
```
