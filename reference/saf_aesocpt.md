# Adverse events by System Organ Class and Preferred Term

Pre-summarised AE-by-SOC/PT table. Interleaved row order: overall "any
TEAE" row first, then per-SOC blocks where each SOC row is followed by
its preferred-term detail rows. Top 10 SOCs and top 5 PTs per SOC are
kept; `row_type` marks the role of each row and `indent_level` carries
the canonical depth (0 for overall and SOC, 1 for PT) so the downstream
pipeline drives the SOC -\> PT indent via
`col_spec(indent_by = "indent_level")` without reconstructing it in
every script. The richer SOC × PT slice exercises
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md)
and the engine's horizontal-panel splitter end-to-end on a realistic
submission shell.

## Usage

``` r
saf_aesocpt
```

## Format

A data frame with 61 rows and 10 columns:

- `soc`:

  System Organ Class label. Repeats across the SOC's PT rows; hide via
  `col_spec(visible = FALSE)` once `label` carries the same SOC text on
  SOC rows.

- `label`:

  The row's display label. Equal to `soc` on the overall and SOC-summary
  rows; equal to the preferred-term name on PT detail rows. Promoted to
  the primary display column — pair with `indent_by = "indent_level"` to
  drive the SOC -\> PT indent.

- `row_type`:

  One of `"overall"`, `"soc"`, `"pt"`. Partition marker; hide via
  `col_spec(visible = FALSE)`.

- `indent_level`:

  Integer depth (0 on overall and SOC rows, 1 on PT rows). Consumed by
  `col_spec(indent_by = "indent_level")` on the `label` column; the
  engine auto-hides this column at resolve time.

- `n_total`:

  Integer. The row's own subject count — overall TEAE count on the
  overall row, the SOC's count on each SOC row, the PT's count on each
  PT row. Inner sort key.

- `soc_n`:

  Integer. The parent SOC's count, broadcast to every row in that SOC's
  cluster (SOC row + its PT children) so a descending sort on `soc_n`
  keeps PTs grouped under their parent. On the overall row, equal to the
  overall TEAE count. Outer sort key.

- `placebo`:

  Placebo arm cell text (`"n (pct)"`).

- `drug_50`, `drug_100`:

  Drug arms cell text.

- `Total`:

  Pooled-across-arms cell text.

## Source

Derived in `data-raw/bundle-demo.R` from
[`pharmaverseadam::adae`](https://pharmaverse.github.io/pharmaverseadam/reference/adae.html).
Filtered to the top 10 SOCs by total incidence and the top 5 PTs per
SOC. Body rows are pre-sorted with the cards-style two-level rule
(`arrange(desc(soc_n), soc, desc(n_total))`) so the canonical render
order is already baked in; the render-time
`sort_rows(by = c("soc_n", "n_total"), descending = c(TRUE, TRUE))`
reproduces it via stable sort.

## See also

[saf_aesocpt_card](https://vthanik.github.io/tabular/reference/saf_aesocpt_card.md)
for the hierarchical long ARD;
[saf_n](https://vthanik.github.io/tabular/reference/saf_n.md) for BigN
denominators.

## Examples

``` r
# 95% safety pattern: SOC/PT table where `label` carries SOC text
# on SOC rows and PT text on PT rows, indented by `indent_level`.
# `soc` / `row_type` / `n_total` / `soc_n` ride along as hidden
# partition + sort keys. `sort_rows(soc_n, n_total)` clusters PTs
# under their parent SOC and orders both levels by descending count.
n <- stats::setNames(saf_n$n, saf_n$arm_short)

tabular(
  saf_aesocpt,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by SOC and Preferred Term",
    sprintf("Safety Population (N=%d)", n["Total"])
  )
) |>
  cols(
    label    = col_spec(
      label = "SOC / PT",
      indent_by = "indent_level",
      align = "left"
    ),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    soc_n    = col_spec(visible = FALSE),
    placebo  = col_spec(
      label = sprintf("Placebo\nN=%d", n["placebo"]),
      align = "decimal"
    ),
    drug_50  = col_spec(
      label = sprintf("Drug 50\nN=%d", n["drug_50"]),
      align = "decimal"
    ),
    drug_100 = col_spec(
      label = sprintf("Drug 100\nN=%d", n["drug_100"]),
      align = "decimal"
    ),
    Total    = col_spec(
      label = sprintf("Total\nN=%d", n["Total"]),
      align = "decimal"
    )
  ) |>
  sort_rows(
    by = c("soc_n", "n_total"),
    descending = c(TRUE, TRUE)
  )

#tabular-011894328b { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#tabular-011894328b .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-011894328b .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-011894328b .tabular-pad { margin: 0; }
#tabular-011894328b .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-011894328b .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-011894328b .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-011894328b .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-011894328b .tabular-table th, #tabular-011894328b .tabular-table td { padding: .35rem .6rem; }
#tabular-011894328b .tabular-table td { text-align: left; vertical-align: top; }
#tabular-011894328b .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-011894328b .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-011894328b .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-011894328b .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-011894328b .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-011894328b .tabular-table tbody tr td { border-top: none; }
#tabular-011894328b .tabular-band { text-align: center; }
#tabular-011894328b .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-011894328b .tabular-subgroup-label { font-weight: 600; }
#tabular-011894328b .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-011894328b .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-011894328b .text-left { text-align: left; }
#tabular-011894328b .text-center { text-align: center; }
#tabular-011894328b .text-right { text-align: right; }
#tabular-011894328b .tabular-table thead th.text-left { text-align: left; }
#tabular-011894328b .tabular-table thead th.text-center { text-align: center; }
#tabular-011894328b .tabular-table thead th.text-right { text-align: right; }
#tabular-011894328b .valign-top { vertical-align: top; }
#tabular-011894328b .valign-middle { vertical-align: middle; }
#tabular-011894328b .valign-bottom { vertical-align: bottom; }
#tabular-011894328b .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-011894328b .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-011894328b .tabular-page-break-row { display: none; }
#tabular-011894328b { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-011894328b .tabular-page-header, #tabular-011894328b .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-011894328b .tabular-page-header { margin-bottom: 1rem; }
#tabular-011894328b .tabular-page-footer { margin-top: 1rem; }
#tabular-011894328b .tabular-page-header-left, #tabular-011894328b .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-011894328b .tabular-page-header-center, #tabular-011894328b .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-011894328b .tabular-page-header-right, #tabular-011894328b .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-011894328b .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-011894328b .tabular-table tr { page-break-inside: avoid; } #tabular-011894328b .tabular-page-header, #tabular-011894328b .tabular-page-footer { display: none; } #tabular-011894328b .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-011894328b .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-011894328b .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }


 
Table 14.3.1
Adverse Events by SOC and Preferred Term
Safety Population (N=254)
 



SOC / PT
```
