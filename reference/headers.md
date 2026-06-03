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
  a passthrough leaf (see the Passthrough section above).

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
ae <- saf_aesocpt
ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
ae$n_total <- as.integer(sub(" .*", "", ae$Total))
n <- stats::setNames(saf_n$n, saf_n$arm_short)

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
    label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    soc_n    = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"])),
    drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"])),
    drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"])),
    Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]))
  ) |>
  headers(
    "Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")
  ) |>
  sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE))

#tabular-c869c10298 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-c869c10298 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-c869c10298 p { line-height: inherit; }
#tabular-c869c10298 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-c869c10298 .tabular-caption { margin: 0; padding: 0; }
#tabular-c869c10298 .tabular-pad { margin: 0; line-height: 1; }
#tabular-c869c10298 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-c869c10298 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-c869c10298 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-c869c10298 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-c869c10298 .tabular-table th, #tabular-c869c10298 .tabular-table td { padding: .18rem .6rem; }
#tabular-c869c10298 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-c869c10298 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-c869c10298 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-c869c10298 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-c869c10298 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-c869c10298 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-c869c10298 .tabular-table tbody tr td { border-top: none; }
#tabular-c869c10298 .tabular-band { text-align: center; }
#tabular-c869c10298 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-c869c10298 .tabular-subgroup-label { font-weight: 600; }
#tabular-c869c10298 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-c869c10298 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-c869c10298 .text-left { text-align: left; }
#tabular-c869c10298 .text-center { text-align: center; }
#tabular-c869c10298 .text-right { text-align: right; }
#tabular-c869c10298 .tabular-table thead th.text-left { text-align: left; }
#tabular-c869c10298 .tabular-table thead th.text-center { text-align: center; }
#tabular-c869c10298 .tabular-table thead th.text-right { text-align: right; }
#tabular-c869c10298 .valign-top { vertical-align: top; }
#tabular-c869c10298 .valign-middle { vertical-align: middle; }
#tabular-c869c10298 .valign-bottom { vertical-align: bottom; }
#tabular-c869c10298 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-c869c10298 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-c869c10298 .tabular-page-break-row { display: none; }
#tabular-c869c10298 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-c869c10298 .tabular-page-header, #tabular-c869c10298 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-c869c10298 .tabular-page-header { margin-bottom: 1rem; }
#tabular-c869c10298 .tabular-page-footer { margin-top: 1rem; }
#tabular-c869c10298 .tabular-page-header-left, #tabular-c869c10298 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-c869c10298 .tabular-page-header-center, #tabular-c869c10298 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-c869c10298 .tabular-page-header-right, #tabular-c869c10298 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-c869c10298 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-c869c10298 .tabular-table tr { page-break-inside: avoid; } #tabular-c869c10298 .tabular-page-header, #tabular-c869c10298 .tabular-page-footer { display: none; } #tabular-c869c10298 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-c869c10298 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-c869c10298 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.1
Adverse Events by System Organ Class and Preferred Term
Safety Population
 



```
