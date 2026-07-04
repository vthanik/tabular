# Print a `tabular_spec`

Renders a `tabular_spec` interactively. The default behaviour mirrors
`gt::gt()`: convert the spec to an `htmltools` tag list and let
htmltools dispatch — RStudio + Positron viewer panes, Quarto / Rmd
notebook inline, Databricks `displayHTML`, and plain-console
[`cat()`](https://rdrr.io/r/base/cat.html) are all handled without any
IDE- specific branching.

## Arguments

- x:

  *The `tabular_spec` to render.* `<tabular_spec>: required`. The same
  object you'd hand to
  [`emit()`](https://vthanik.github.io/tabular/reference/emit.md).

- ...:

  *Forwarded to `htmltools::print` / `as.tags()`.* Use this to pass
  `id`, `style`, `class` overrides to the wrapping `<div>`.

- view:

  *Open the viewer?* `<logical(1)>: default `interactive()“. Same role
  as `gt::gt`'s \`view\` argument: passes through to htmltools as
  \`browse = view\`. Set \`view = FALSE\` to suppress the viewer for one
  call (e.g. to capture the HTML string without launching a window).

- output:

  *Force a specific preview format.*
  `<character(1) | NULL>: default `NULL` (auto)`. See the **`output`
  argument** section below for the full list. The session default can be
  set via `options(tabular_print_output = "cli")` for users who prefer
  the structural summary over the HTML preview.

## Value

*Invisibly returns `x`.* Side effect: opens the viewer, inlines under a
chunk, or [`cat()`](https://rdrr.io/r/base/cat.html)s output.

## Details

**Dispatch.** [`print()`](https://rdrr.io/r/base/print.html) delegates
to
[`as.tags.tabular_spec()`](https://vthanik.github.io/tabular/reference/as.tags.tabular_spec.md)
which returns an
[`htmltools::tagList`](https://rstudio.github.io/htmltools/reference/tagList.html).
That tag list is handed to `htmltools`'s own print method with
`browse = view`: htmltools opens the IDE viewer when one is registered,
inlines under a Quarto / Rmd chunk when running inside one, or
[`cat()`](https://rdrr.io/r/base/cat.html)s the HTML when neither
applies. No `is_rstudio()` / `is_positron()` / `is_notebook()`
heuristics — htmltools already knows.

**`view` argument.** Defaults to
[`interactive()`](https://rdrr.io/r/base/interactive.html), the same
universal off-switch `gt::gt()` uses. Non-interactive contexts
(`Rscript`, `R CMD check`, CI, devtools::test) bypass the viewer
automatically. Pass `view = FALSE` explicitly at an interactive prompt
to suppress the viewer for a single call.

**`output` argument.** Forces a specific preview format instead of the
default HTML-via-htmltools path. One of:

- `"html"` — same as the default, but explicit.

- `"md"` / `"markdown"` — [`cat()`](https://rdrr.io/r/base/cat.html) the
  markdown source to the console (round-trips through `backend_md`).

- `"latex"` — [`cat()`](https://rdrr.io/r/base/cat.html) the markdown
  source as a temporary placeholder (real LaTeX preview lands with
  `backend_latex`).

- `"rtf"` / `"docx"` / `"pdf"` — render an HTML preview and emit a cli
  note pointing at
  [`emit()`](https://vthanik.github.io/tabular/reference/emit.md) for
  the real artefact. The viewer pane cannot render RTF / OOXML, and we
  deliberately do *not* compile through tinytex on every autoprint.

- `"cli"` — print the structural cli-tree summary (props, headers, sort,
  pagination, preset). Useful for debugging spec composition without
  paying the HTML render cost.

**Robustness.** The HTML render is wrapped in `tryCatch`; if rendering
fails for any reason the printer falls back to the cli-tree summary and
a [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html)
describing the failure, so a broken spec never crashes the REPL.

**Tempdir.** Preview HTML files live under
`getOption("tabular_preview_dir", default = tempdir())`. Override the
option to keep them in a stable location (handy on Linux distros where
browsers don't have read access to `/tmp/`).

## See also

**Tag conversion:**
[`as.tags.tabular_spec()`](https://vthanik.github.io/tabular/reference/as.tags.tabular_spec.md)
— the htmltools tag list that
[`print()`](https://rdrr.io/r/base/print.html) delegates to. Call it
directly to embed the table in a custom
[`htmltools::tagList`](https://rstudio.github.io/htmltools/reference/tagList.html)
or Shiny UI.

**Terminal verb:**
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) writes
the resolved artefact to disk;
[`print()`](https://rdrr.io/r/base/print.html) is for in-session preview
only.

**Pipeline shape:**
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)
resolves the engine pipeline to a `tabular_grid` without I/O.

## Examples

``` r
# ---- Example 1: Build + autoprint (HTML preview) ----
#
# Build a spec and let autoprint render it. Inside RStudio /
# Positron the HTML lands in the viewer pane; inside a
# Quarto / Rmd chunk it inlines under the chunk; at a plain
# console the HTML source is `cat()`-ed.
tabular(
  cdisc_saf_demo,
  titles = c("Table 14.1.1", "Demographics"),
  footnotes = "Safety Population."
)

#tabular-e65ff1c855 { font-family: "Courier New", Courier, "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-e65ff1c855 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-e65ff1c855 p { line-height: inherit; }
#tabular-e65ff1c855 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-e65ff1c855 .tabular-caption { margin: 0; padding: 0; }
#tabular-e65ff1c855 .tabular-pad { margin: 0; line-height: 1; }
#tabular-e65ff1c855 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-e65ff1c855 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-e65ff1c855 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-e65ff1c855 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-e65ff1c855 .tabular-table th, #tabular-e65ff1c855 .tabular-table td { padding: .18rem .6rem; }
#tabular-e65ff1c855 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-e65ff1c855 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-e65ff1c855 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-e65ff1c855 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-e65ff1c855 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-e65ff1c855 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-e65ff1c855 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-e65ff1c855 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-e65ff1c855 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-e65ff1c855 .tabular-table tbody tr td { border-top: none; }
#tabular-e65ff1c855 .tabular-band { text-align: center; }
#tabular-e65ff1c855 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-e65ff1c855 .tabular-subgroup-label { font-weight: 600; }
#tabular-e65ff1c855 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-e65ff1c855 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-e65ff1c855 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-e65ff1c855 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-e65ff1c855 .text-left { text-align: left; }
#tabular-e65ff1c855 .text-center { text-align: center; }
#tabular-e65ff1c855 .text-right { text-align: right; }
#tabular-e65ff1c855 .tabular-table thead th.text-left { text-align: left; }
#tabular-e65ff1c855 .tabular-table thead th.text-center { text-align: center; }
#tabular-e65ff1c855 .tabular-table thead th.text-right { text-align: right; }
#tabular-e65ff1c855 .tabular-table td.text-left { text-align: left; }
#tabular-e65ff1c855 .tabular-table td.text-center { text-align: center; }
#tabular-e65ff1c855 .tabular-table td.text-right { text-align: right; }
#tabular-e65ff1c855 .valign-top { vertical-align: top; }
#tabular-e65ff1c855 .valign-middle { vertical-align: middle; }
#tabular-e65ff1c855 .valign-bottom { vertical-align: bottom; }
#tabular-e65ff1c855 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-e65ff1c855 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-e65ff1c855 .tabular-page-break-row { display: none; }
#tabular-e65ff1c855 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-e65ff1c855 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-e65ff1c855 .tabular-page-header, #tabular-e65ff1c855 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-e65ff1c855 .tabular-page-header { margin-bottom: 1rem; }
#tabular-e65ff1c855 .tabular-page-footer { margin-top: 1rem; }
#tabular-e65ff1c855 .tabular-page-header-left, #tabular-e65ff1c855 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-e65ff1c855 .tabular-page-header-center, #tabular-e65ff1c855 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-e65ff1c855 .tabular-page-header-right, #tabular-e65ff1c855 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-e65ff1c855 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-e65ff1c855 .tabular-table tr { page-break-inside: avoid; } #tabular-e65ff1c855 .tabular-page-header, #tabular-e65ff1c855 .tabular-page-footer { display: none; } #tabular-e65ff1c855 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-e65ff1c855 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-e65ff1c855 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.1.1
Demographics
 



variable
```
