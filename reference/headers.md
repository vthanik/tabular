# Attach multi-level column headers

Build the column-header band(s) above the rendered table. Each named
argument is one band; the value is either a character vector of column
names (leaf band) or a named list of further bands (inner band). Nesting
depth is arbitrary — the engine renders one band row per depth level,
with each cell spanning the columns of its leaves.

## Usage

``` r
headers(.spec, ...)
```

## Arguments

- .spec:

  *The `tabular_spec` to attach the header tree to.*
  `<tabular_spec>: required`. Dot-prefixed so R's partial argument
  matching cannot accidentally bind a short user-supplied band label in
  `...` to the spec slot.

- ...:

  *Named header bands.* Each name is the band label (must be non-blank);
  each value is either:

  - a **character vector** of data-column names — leaf band, or

  - a **named list** whose entries follow the same recursive pattern —
    inner band.

  Inside a nested-list value, an unnamed character-vector entry declares
  a passthrough leaf (see the Passthrough section below).

  **Restriction:** Every column referenced must exist in `.spec@data`. A
  column may appear under at most one leaf. Names must be unique within
  one `headers()` call. **Tip:** Pass `headers()` with no arguments to
  clear the tree. **Interaction:** Band labels support glue-style
  `{expr}` interpolation, evaluated as R code in the calling environment
  at build time (double a brace for a literal one). The non-blank and
  uniqueness checks apply to the raw author-typed name, before
  interpolation.

## Value

*The updated `tabular_spec`.* Continue chaining with
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md).

## Details

**Replace, not stack.** A second `headers()` call REPLACES the prior
tree — header structure is a single spec, not a stackable list. Call
with no arguments to clear the tree.

**Strict label rule.** Every declared band label must carry visible text
— empty strings, NA, and whitespace-only labels are rejected at every
nesting level. This is stricter than
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md),
which DOES accept empty labels (a row-label column with no header text
is a legitimate clinical case). A silently-blank band would be a layout
artefact.

**Uncovered columns render naked.** Columns not referenced under any
band render with their `col_spec.label` only — no extra band row above
them. This is the canonical pattern for row-label columns (`variable`,
`soc`, `stat_label`).

**Multi-line band labels.** Embed `\n` in a band label for a two-line
band cell (arm name on row 1, BigN on row 2).

**Spanner underline trim (backend limitation).** Each spanner's
underline is trimmed at both ends, booktabs `\cmidrule(lr)` style, so
adjacent spanners are separated by a visible gap rather than merging
into one continuous line. PDF / LaTeX (tabularray `leftpos`/`rightpos`)
and HTML (an inset rule) render the trim natively. RTF and DOCX cannot
inset a cell border horizontally, so there the spanner underline spans
the full band width (adjacent spanner rules abut). This is a known,
documented limitation of the OOXML / RTF cell-border model, not a bug.

## Passthrough leaves inside a nested band

Inside a nested-list value, a child entry may be **unnamed** — the entry
is then a character vector of column names that sit directly under the
parent with no intermediate band at this depth. Use this when one column
under a band has no sub-grouping while its siblings do. The strict-label
rule still applies to every declared band; an unnamed passthrough is NOT
a band with a missing label — it is "no band declared at this depth for
this column."

## See also

**Companion verb:**
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
sets per-column labels — the leaf-row header text that sits below the
band rows this verb builds.

**Sibling build verbs:**
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

**Inline label formatting:**
[`md()`](https://vthanik.github.io/tabular/reference/md.md),
[`html()`](https://vthanik.github.io/tabular/reference/html.md).

## Examples

``` r
# ---- Example 1: Single "Treatment Group" band over four arms ----
#
# AE-by-SOC/PT table with one flat band labelled "Treatment Group"
# spanning the four arm columns and the Total column. The
# row-label column (`soc`) sits to the left of the band with no
# header covering it — the canonical clinical layout.
ae <- cdisc_saf_aesocpt
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

tabular(
  ae,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by System Organ Class and Preferred Term",
    "Safety Population"
  ),
  footnotes = "Subjects are counted once per SOC and once per PT."
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    soc_n    = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = "Placebo\nN={n['placebo']}"),
    drug_50  = col_spec(label = "Drug 50\nN={n['drug_50']}"),
    drug_100 = col_spec(label = "Drug 100\nN={n['drug_100']}"),
    Total    = col_spec(label = "Total\nN={n['Total']}")
  ) |>
  headers(
    "Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")
  ) |>
  sort_rows(by = c("soc_n", "n_total"), descending = c(TRUE, TRUE))

#tabular-fcbe777680 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-fcbe777680 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-fcbe777680 p { line-height: inherit; }
#tabular-fcbe777680 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-fcbe777680 .tabular-caption { margin: 0; padding: 0; }
#tabular-fcbe777680 .tabular-pad { margin: 0; line-height: 1; }
#tabular-fcbe777680 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-fcbe777680 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-fcbe777680 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-fcbe777680 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-fcbe777680 .tabular-table th, #tabular-fcbe777680 .tabular-table td { padding: .18rem .6rem; }
#tabular-fcbe777680 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-fcbe777680 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-fcbe777680 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-fcbe777680 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-fcbe777680 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-fcbe777680 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-fcbe777680 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-fcbe777680 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-fcbe777680 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-fcbe777680 .tabular-table tbody tr td { border-top: none; }
#tabular-fcbe777680 .tabular-band { text-align: center; }
#tabular-fcbe777680 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-fcbe777680 .tabular-subgroup-label { font-weight: 600; }
#tabular-fcbe777680 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-fcbe777680 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-fcbe777680 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-fcbe777680 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-fcbe777680 .text-left { text-align: left; }
#tabular-fcbe777680 .text-center { text-align: center; }
#tabular-fcbe777680 .text-right { text-align: right; }
#tabular-fcbe777680 .tabular-table thead th.text-left { text-align: left; }
#tabular-fcbe777680 .tabular-table thead th.text-center { text-align: center; }
#tabular-fcbe777680 .tabular-table thead th.text-right { text-align: right; }
#tabular-fcbe777680 .valign-top { vertical-align: top; }
#tabular-fcbe777680 .valign-middle { vertical-align: middle; }
#tabular-fcbe777680 .valign-bottom { vertical-align: bottom; }
#tabular-fcbe777680 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-fcbe777680 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-fcbe777680 .tabular-page-break-row { display: none; }
#tabular-fcbe777680 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-fcbe777680 .tabular-page-header, #tabular-fcbe777680 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-fcbe777680 .tabular-page-header { margin-bottom: 1rem; }
#tabular-fcbe777680 .tabular-page-footer { margin-top: 1rem; }
#tabular-fcbe777680 .tabular-page-header-left, #tabular-fcbe777680 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-fcbe777680 .tabular-page-header-center, #tabular-fcbe777680 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-fcbe777680 .tabular-page-header-right, #tabular-fcbe777680 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-fcbe777680 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-fcbe777680 .tabular-table tr { page-break-inside: avoid; } #tabular-fcbe777680 .tabular-page-header, #tabular-fcbe777680 .tabular-page-footer { display: none; } #tabular-fcbe777680 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-fcbe777680 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-fcbe777680 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.1
Adverse Events by System Organ Class and Preferred Term
Safety Population
 



```
