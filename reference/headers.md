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
  clear the tree.

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
    sprintf("Safety Population (N=%d)", n["Total"])
  ),
  footnotes = "Subjects are counted once per SOC and once per PT."
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
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
#> <style>
#> .tabular-doc { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> .tabular-content { width: 100%; }
#> .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> .tabular-pad { margin: 0; }
#> .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> .tabular-table th, .tabular-table td { padding: .35rem .6rem; }
#> .tabular-table td { text-align: left; vertical-align: top; }
#> .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> .tabular-table tbody tr td { border-top: none; }
#> .tabular-band { text-align: center; }
#> .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> .tabular-subgroup-label { font-weight: 600; }
#> .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> .text-left { text-align: left; }
#> .text-center { text-align: center; }
#> .text-right { text-align: right; }
#> .tabular-table thead th.text-left { text-align: left; }
#> .tabular-table thead th.text-center { text-align: center; }
#> .tabular-table thead th.text-right { text-align: right; }
#> .valign-top { vertical-align: top; }
#> .valign-middle { vertical-align: middle; }
#> .valign-bottom { vertical-align: bottom; }
#> .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> .tabular-empty { font-style: italic; color: #6c757d; }
#> .tabular-page-break-row { display: none; }
#> :root { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> .tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> .tabular-page-header { margin-bottom: 1rem; }
#> .tabular-page-footer { margin-top: 1rem; }
#> .tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }
#> .tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }
#> .tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular_WRZorR1u5C" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.1</h1>
#> <h1 class="tabular-title">Adverse Events by System Organ Class and Preferred Term</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th colspan="2"></th><th colspan="4" class="tabular-band">Treatment Group</th></tr>
#> <tr><th>SOC / PT</th><th>soc_n</th><th>Placebo<br/>N=86</th><th>Drug 50<br/>N=96</th><th>Drug 100<br/>N=72</th><th>Total<br/>N=254</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>TOTAL SUBJECTS WITH AN EVENT</td><td>199</td><td>52 (60.5)</td><td>81 (84.4)</td><td>66 (91.7)</td><td>199 (78.3)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>90</td><td>19 (22.1)</td><td>36 (37.5)</td><td>35 (48.6)</td><td>90 (35.4)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>81</td><td>15 (17.4)</td><td>36 (37.5)</td><td>30 (41.7)</td><td>81 (31.9)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>42</td><td>13 (15.1)</td><td>12 (12.5)</td><td>17 (23.6)</td><td>42 (16.5)</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>41</td><td>6 (7.0)</td><td>18 (18.8)</td><td>17 (23.6)</td><td>41 (16.1)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>33</td><td>7 (8.1)</td><td>12 (12.5)</td><td>14 (19.4)</td><td>33 (13.0)</td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>29</td><td>12 (14.0)</td><td>6 (6.2)</td><td>11 (15.3)</td><td>29 (11.4)</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>22</td><td>5 (5.8)</td><td>8 (8.3)</td><td>9 (12.5)</td><td>22 (8.7)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>19</td><td>7 (8.1)</td><td>9 (9.4)</td><td>3 (4.2)</td><td>19 (7.5)</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>14</td><td>3 (3.5)</td><td>6 (6.2)</td><td>5 (6.9)</td><td>14 (5.5)</td></tr>
#> <tr><td>INVESTIGATIONS</td><td>12</td><td>5 (5.8)</td><td>4 (4.2)</td><td>3 (4.2)</td><td>12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PRURITUS</td><td>90</td><td>8 (9.3)</td><td>21 (21.9)</td><td>25 (34.7)</td><td>54 (21.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE PRURITUS</td><td>81</td><td>6 (7.0)</td><td>23 (24.0)</td><td>21 (29.2)</td><td>50 (19.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ERYTHEMA</td><td>90</td><td>8 (9.3)</td><td>14 (14.6)</td><td>14 (19.4)</td><td>36 (14.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE ERYTHEMA</td><td>81</td><td>3 (3.5)</td><td>13 (13.5)</td><td>14 (19.4)</td><td>30 (11.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">RASH</td><td>90</td><td>5 (5.8)</td><td>13 (13.5)</td><td>8 (11.1)</td><td>26 (10.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE DERMATITIS</td><td>81</td><td>5 (5.8)</td><td>9 (9.4)</td><td>7 (9.7)</td><td>21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE IRRITATION</td><td>81</td><td>3 (3.5)</td><td>9 (9.4)</td><td>9 (12.5)</td><td>21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIZZINESS</td><td>41</td><td>2 (2.3)</td><td>9 (9.4)</td><td>10 (13.9)</td><td>21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIARRHOEA</td><td>42</td><td>9 (10.5)</td><td>5 (5.2)</td><td>3 (4.2)</td><td>17 (6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SINUS BRADYCARDIA</td><td>33</td><td>2 (2.3)</td><td>7 (7.3)</td><td>8 (11.1)</td><td>17 (6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HYPERHIDROSIS</td><td>90</td><td>2 (2.3)</td><td>4 (4.2)</td><td>8 (11.1)</td><td>14 (5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SKIN IRRITATION</td><td>90</td><td>3 (3.5)</td><td>6 (6.2)</td><td>5 (6.9)</td><td>14 (5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VOMITING</td><td>42</td><td>3 (3.5)</td><td>4 (4.2)</td><td>6 (8.3)</td><td>13 (5.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NAUSEA</td><td>42</td><td>3 (3.5)</td><td>3 (3.1)</td><td>6 (8.3)</td><td>12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASOPHARYNGITIS</td><td>29</td><td>2 (2.3)</td><td>4 (4.2)</td><td>6 (8.3)</td><td>12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE VESICLES</td><td>81</td><td>1 (1.2)</td><td>5 (5.2)</td><td>5 (6.9)</td><td>11 (4.3)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HEADACHE</td><td>41</td><td>3 (3.5)</td><td>3 (3.1)</td><td>5 (6.9)</td><td>11 (4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">COUGH</td><td>22</td><td>1 (1.2)</td><td>5 (5.2)</td><td>5 (6.9)</td><td>11 (4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MYOCARDIAL INFARCTION</td><td>33</td><td>4 (4.7)</td><td>2 (2.1)</td><td>4 (5.6)</td><td>10 (3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">UPPER RESPIRATORY TRACT INFECTION</td><td>29</td><td>6 (7.0)</td><td>1 (1.0)</td><td>3 (4.2)</td><td>10 (3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SYNCOPE</td><td>41</td><td>0 (0.0)</td><td>5 (5.2)</td><td>2 (2.8)</td><td>7 (2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASAL CONGESTION</td><td>22</td><td>3 (3.5)</td><td>1 (1.0)</td><td>3 (4.2)</td><td>7 (2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SOMNOLENCE</td><td>41</td><td>2 (2.3)</td><td>3 (3.1)</td><td>1 (1.4)</td><td>6 (2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CONFUSIONAL STATE</td><td>19</td><td>2 (2.3)</td><td>3 (3.1)</td><td>1 (1.4)</td><td>6 (2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ABDOMINAL PAIN</td><td>42</td><td>1 (1.2)</td><td>3 (3.1)</td><td>1 (1.4)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ATRIAL FIBRILLATION</td><td>33</td><td>1 (1.2)</td><td>2 (2.1)</td><td>2 (2.8)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">AGITATION</td><td>19</td><td>2 (2.3)</td><td>3 (3.1)</td><td>0 (0.0)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BACK PAIN</td><td>14</td><td>1 (1.2)</td><td>1 (1.0)</td><td>3 (4.2)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM ST SEGMENT DEPRESSION</td><td>12</td><td>4 (4.7)</td><td>1 (1.0)</td><td>0 (0.0)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SALIVARY HYPERSECRETION</td><td>42</td><td>0 (0.0)</td><td>0 (0.0)</td><td>4 (5.6)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INSOMNIA</td><td>19</td><td>2 (2.3)</td><td>0 (0.0)</td><td>2 (2.8)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRALGIA</td><td>14</td><td>1 (1.2)</td><td>2 (2.1)</td><td>1 (1.4)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE INVERSION</td><td>12</td><td>2 (2.3)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">TRANSIENT ISCHAEMIC ATTACK</td><td>41</td><td>0 (0.0)</td><td>2 (2.1)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SUPRAVENTRICULAR EXTRASYSTOLES</td><td>33</td><td>1 (1.2)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VENTRICULAR EXTRASYSTOLES</td><td>33</td><td>0 (0.0)</td><td>2 (2.1)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INFLUENZA</td><td>29</td><td>1 (1.2)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">URINARY TRACT INFECTION</td><td>29</td><td>2 (2.3)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DYSPNOEA</td><td>22</td><td>1 (1.2)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">EPISTAXIS</td><td>22</td><td>0 (0.0)</td><td>1 (1.0)</td><td>2 (2.8)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ANXIETY</td><td>19</td><td>0 (0.0)</td><td>3 (3.1)</td><td>0 (0.0)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SHOULDER PAIN</td><td>14</td><td>1 (1.2)</td><td>2 (2.1)</td><td>0 (0.0)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CYSTITIS</td><td>29</td><td>1 (1.2)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PHARYNGOLARYNGEAL PAIN</td><td>22</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DELUSION</td><td>19</td><td>1 (1.2)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MUSCLE SPASMS</td><td>14</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLOOD GLUCOSE INCREASED</td><td>12</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td>12</td><td>1 (1.2)</td><td>1 (1.0)</td><td>0 (0.0)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRITIS</td><td>14</td><td>0 (0.0)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>1 (0.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">BIOPSY</td><td style="border-bottom: 0.5pt solid #212529;">12</td><td style="border-bottom: 0.5pt solid #212529;">0 (0.0)</td><td style="border-bottom: 0.5pt solid #212529;">0 (0.0)</td><td style="border-bottom: 0.5pt solid #212529;">1 (1.4)</td><td style="border-bottom: 0.5pt solid #212529;">1 (0.4)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Subjects are counted once per SOC and once per PT.</p>
#> </div></div>

# ---- Example 2: Two-level nested band — Control vs Active arms ----
#
# Efficacy BOR table where the active arms are grouped under an
# "Active" sub-band and the placebo arm under a "Control"
# sub-band, both under a single "Treatment Group" parent.
# Demonstrates the named-list value form for arbitrary-depth
# nesting.
bor_levels <- c(
  "CR", "PR", "SD", "NON-CR/NON-PD", "PD", "NE", "MISSING",
  "Objective Response Rate (CR + PR)",
  "Disease Control Rate (CR + PR + SD)"
)
eff <- eff_resp
eff$stat_label <- factor(eff$stat_label, levels = bor_levels)
ne <- stats::setNames(eff_n$n, eff_n$arm_short)

tabular(
  eff,
  titles = c(
    "Table 14.2.1",
    "Best Overall Response and Response Rates",
    sprintf("Efficacy Evaluable Population (N=%d)", ne["Total"])
  ),
  footnotes = "Response per RECIST 1.1, investigator assessment."
) |>
  cols(
    stat_label = col_spec(usage = "group", label = "Response"),
    row_type   = col_spec(visible = FALSE),
    placebo    = col_spec(label = sprintf("Placebo\nN=%d",  ne["placebo"])),
    drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  ne["drug_50"])),
    drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", ne["drug_100"]))
  ) |>
  headers(
    "Treatment Group" = list(
      "Control" = "placebo",
      "Active"  = c("drug_50", "drug_100")
    )
  ) |>
  sort_rows(by = "stat_label")
#> <style>
#> .tabular-doc { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> .tabular-content { width: 100%; }
#> .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> .tabular-pad { margin: 0; }
#> .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> .tabular-table th, .tabular-table td { padding: .35rem .6rem; }
#> .tabular-table td { text-align: left; vertical-align: top; }
#> .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> .tabular-table tbody tr td { border-top: none; }
#> .tabular-band { text-align: center; }
#> .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> .tabular-subgroup-label { font-weight: 600; }
#> .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> .text-left { text-align: left; }
#> .text-center { text-align: center; }
#> .text-right { text-align: right; }
#> .tabular-table thead th.text-left { text-align: left; }
#> .tabular-table thead th.text-center { text-align: center; }
#> .tabular-table thead th.text-right { text-align: right; }
#> .valign-top { vertical-align: top; }
#> .valign-middle { vertical-align: middle; }
#> .valign-bottom { vertical-align: bottom; }
#> .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> .tabular-empty { font-style: italic; color: #6c757d; }
#> .tabular-page-break-row { display: none; }
#> :root { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> .tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> .tabular-page-header { margin-bottom: 1rem; }
#> .tabular-page-footer { margin-top: 1rem; }
#> .tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }
#> .tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }
#> .tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular_jcJSLnb4eY" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.2.1</h1>
#> <h1 class="tabular-title">Best Overall Response and Response Rates</h1>
#> <h1 class="tabular-title">Efficacy Evaluable Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th colspan="3" class="tabular-band">Treatment Group</th><th colspan="2"></th></tr>
#> <tr><th colspan="1" class="tabular-band">Control</th><th colspan="2" class="tabular-band">Active</th><th colspan="2"></th></tr>
#> <tr><th>Placebo<br/>N=86</th><th>Drug 50<br/>N=84</th><th>Drug 100<br/>N=84</th><th>groupid</th><th>group_label</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>1 (1.2)</td><td>1 (1.2)</td><td>1 (1.2)</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>1 (1.2)</td><td>0</td><td>0</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>1 (1.2)</td><td>0</td><td>0</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>0</td><td>0</td><td>1 (1.2)</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>0</td><td>0</td><td>1 (1.2)</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>0</td><td>1 (1.2)</td><td>0</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>83 (96.5)</td><td>82 (97.6)</td><td>81 (96.4)</td><td>1</td><td>Best Overall Response</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>2 (2.3)</td><td>1 (1.2)</td><td>1 (1.2)</td><td>2</td><td>Objective Response Rate</td></tr>
#> <tr><td>(0.3, 8.1)</td><td>(0.0, 6.5)</td><td>(0.0, 6.5)</td><td>2</td><td>Objective Response Rate</td></tr>
#> <tr><td>3 (3.5)</td><td>1 (1.2)</td><td>1 (1.2)</td><td>3</td><td>Clinical Benefit Rate</td></tr>
#> <tr><td>(0.7, 9.9)</td><td>(0.0, 6.5)</td><td>(0.0, 6.5)</td><td>3</td><td>Clinical Benefit Rate</td></tr>
#> <tr><td>3 (3.5)</td><td>1 (1.2)</td><td>2 (2.4)</td><td>4</td><td>Disease Control Rate</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">(0.7, 9.9)</td><td style="border-bottom: 0.5pt solid #212529;">(0.0, 6.5)</td><td style="border-bottom: 0.5pt solid #212529;">(0.3, 8.3)</td><td style="border-bottom: 0.5pt solid #212529;">4</td><td style="border-bottom: 0.5pt solid #212529;">Disease Control Rate</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Response per RECIST 1.1, investigator assessment.</p>
#> </div></div>

# ---- Example 3: Multiple peer bands side by side ----
#
# Vital-signs summary where the parameter columns (param,
# paramcd, visit, stat_label) sit on the left under a "Variable"
# band, and the arm columns sit on the right under "Treatment
# Group". Demonstrates multiple top-level bands in one call --
# bands render side by side in the order declared.
vit <- saf_vital
tabular(vit, titles = c("Table 14.4.1", "Vital Signs Summary")) |>
  cols(
    param      = col_spec(usage = "group", label = "Parameter"),
    paramcd    = col_spec(visible = FALSE),
    visit      = col_spec(usage = "group", label = "Visit"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = "Placebo",  align = "decimal"),
    drug_50    = col_spec(label = "Drug 50",  align = "decimal"),
    drug_100   = col_spec(label = "Drug 100", align = "decimal")
  ) |>
  headers(
    "Variable"        = c("param", "paramcd", "visit", "stat_label"),
    "Treatment Group" = c("placebo", "drug_50", "drug_100")
  )
#> <style>
#> .tabular-doc { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> .tabular-content { width: 100%; }
#> .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> .tabular-pad { margin: 0; }
#> .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> .tabular-table th, .tabular-table td { padding: .35rem .6rem; }
#> .tabular-table td { text-align: left; vertical-align: top; }
#> .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> .tabular-table tbody tr td { border-top: none; }
#> .tabular-band { text-align: center; }
#> .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> .tabular-subgroup-label { font-weight: 600; }
#> .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> .text-left { text-align: left; }
#> .text-center { text-align: center; }
#> .text-right { text-align: right; }
#> .tabular-table thead th.text-left { text-align: left; }
#> .tabular-table thead th.text-center { text-align: center; }
#> .tabular-table thead th.text-right { text-align: right; }
#> .valign-top { vertical-align: top; }
#> .valign-middle { vertical-align: middle; }
#> .valign-bottom { vertical-align: bottom; }
#> .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> .tabular-empty { font-style: italic; color: #6c757d; }
#> .tabular-page-break-row { display: none; }
#> :root { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> .tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> .tabular-page-header { margin-bottom: 1rem; }
#> .tabular-page-footer { margin-top: 1rem; }
#> .tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }
#> .tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }
#> .tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular_rKPRds3Z4q" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.4.1</h1>
#> <h1 class="tabular-title">Vital Signs Summary</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th colspan="1" class="tabular-band">Variable</th><th colspan="3" class="tabular-band">Treatment Group</th></tr>
#> <tr><th>Statistic</th><th class="text-center">Placebo</th><th class="text-center">Drug 50</th><th class="text-center">Drug 100</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>n</td><td class="text-right">340         </td><td class="text-right">384         </td><td class="text-right">288         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 77.1 (10.7)</td><td class="text-right"> 76.6 (9.8) </td><td class="text-right"> 78.2 (10.3)</td></tr>
#> <tr><td>Median</td><td class="text-right"> 77.7       </td><td class="text-right"> 76.7       </td><td class="text-right"> 78.8       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 40  , 110  </td><td class="text-right"> 48  , 108  </td><td class="text-right"> 51  , 108  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">292         </td><td class="text-right">240         </td><td class="text-right">224         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 75.2 (9.1) </td><td class="text-right"> 75.4 (10.6)</td><td class="text-right"> 77.4 (9.1) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 76.0       </td><td class="text-right"> 74.0       </td><td class="text-right"> 78.3       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 101  </td><td class="text-right"> 52  , 100  </td><td class="text-right"> 54  , 98   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">272         </td><td class="text-right">168         </td><td class="text-right">148         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 75.1 (10.9)</td><td class="text-right"> 75.2 (10.0)</td><td class="text-right"> 76.0 (9.0) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 76.0       </td><td class="text-right"> 75.7       </td><td class="text-right"> 77.3       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 98   </td><td class="text-right"> 55  , 98   </td><td class="text-right"> 50  , 92   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">222         </td><td class="text-right">177         </td><td class="text-right">168         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 74.4 (10.7)</td><td class="text-right"> 76.0 (11.2)</td><td class="text-right"> 76.0 (9.9) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 73.5       </td><td class="text-right"> 76.0       </td><td class="text-right"> 78.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 49  , 104  </td><td class="text-right"> 50  , 100  </td><td class="text-right"> 56  , 98   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">340         </td><td class="text-right">384         </td><td class="text-right">288         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 73.5 (11.6)</td><td class="text-right"> 72.1 (10.8)</td><td class="text-right"> 72.4 (9.7) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 72.3       </td><td class="text-right"> 70.0       </td><td class="text-right"> 71.7       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 51  , 134  </td><td class="text-right"> 50  , 104  </td><td class="text-right"> 52  , 100  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">292         </td><td class="text-right">240         </td><td class="text-right">224         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 71.8 (9.0) </td><td class="text-right"> 72.6 (11.1)</td><td class="text-right"> 74.0 (8.9) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 72.0       </td><td class="text-right"> 72.0       </td><td class="text-right"> 73.2       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 52  , 102  </td><td class="text-right"> 49  , 104  </td><td class="text-right"> 50  , 104  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">272         </td><td class="text-right">168         </td><td class="text-right">148         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 70.6 (8.8) </td><td class="text-right"> 68.8 (9.4) </td><td class="text-right"> 73.2 (9.5) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 70.2       </td><td class="text-right"> 68.0       </td><td class="text-right"> 72.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 50  , 90   </td><td class="text-right"> 48  , 104  </td><td class="text-right"> 51  , 96   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">222         </td><td class="text-right">177         </td><td class="text-right">168         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 75.2 (11.5)</td><td class="text-right"> 74.1 (9.4) </td><td class="text-right"> 73.6 (9.6) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 74.0       </td><td class="text-right"> 75.0       </td><td class="text-right"> 73.0       </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="4"></td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 51  , 106  </td><td class="text-right"> 50  , 94   </td><td class="text-right"> 50  , 98   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">340         </td><td class="text-right">384         </td><td class="text-right">288         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">136.8 (17.6)</td><td class="text-right">137.9 (18.5)</td><td class="text-right">137.8 (17.2)</td></tr>
#> <tr><td>Median</td><td class="text-right">136.3       </td><td class="text-right">138.0       </td><td class="text-right">138.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 80  , 184  </td><td class="text-right">100  , 194  </td><td class="text-right">100  , 192  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">292         </td><td class="text-right">240         </td><td class="text-right">224         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">136.3 (17.0)</td><td class="text-right">134.9 (17.8)</td><td class="text-right">135.1 (15.5)</td></tr>
#> <tr><td>Median</td><td class="text-right">136.5       </td><td class="text-right">132.3       </td><td class="text-right">134.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 90  , 189  </td><td class="text-right"> 92  , 200  </td><td class="text-right"> 91  , 198  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">272         </td><td class="text-right">168         </td><td class="text-right">148         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">134.6 (18.3)</td><td class="text-right">132.5 (14.3)</td><td class="text-right">133.7 (16.0)</td></tr>
#> <tr><td>Median</td><td class="text-right">134.0       </td><td class="text-right">130.0       </td><td class="text-right">132.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 76  , 190  </td><td class="text-right">100  , 168  </td><td class="text-right"> 99  , 186  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">222         </td><td class="text-right">177         </td><td class="text-right">168         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right">132.7 (15.4)</td><td class="text-right">133.0 (17.1)</td><td class="text-right">132.3 (15.6)</td></tr>
#> <tr><td>Median</td><td class="text-right">131.0       </td><td class="text-right">130.0       </td><td class="text-right">131.0       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 78  , 172  </td><td class="text-right"> 92  , 178  </td><td class="text-right">100  , 177  </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">172         </td><td class="text-right">190         </td><td class="text-right">144         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.5 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.7       </td><td class="text-right"> 36.6       </td><td class="text-right"> 36.6       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 35  , 37   </td><td class="text-right"> 35  , 37   </td><td class="text-right"> 36  , 37   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">146         </td><td class="text-right">118         </td><td class="text-right">112         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.6       </td><td class="text-right"> 36.7       </td><td class="text-right"> 36.7       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right">136         </td><td class="text-right"> 82         </td><td class="text-right"> 74         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.7 (0.3) </td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.7       </td><td class="text-right"> 36.6       </td><td class="text-right"> 36.7       </td></tr>
#> <tr><td>Min, Max</td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td><td class="text-right"> 36  , 37   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr><td>n</td><td class="text-right"> 74         </td><td class="text-right"> 59         </td><td class="text-right"> 56         </td></tr>
#> <tr><td>Mean (SD)</td><td class="text-right"> 36.7 (0.4) </td><td class="text-right"> 36.6 (0.4) </td><td class="text-right"> 36.6 (0.4) </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="4"></td></tr>
#> <tr><td>Median</td><td class="text-right"> 36.8       </td><td class="text-right"> 36.7       </td><td class="text-right"> 36.7       </td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Min, Max</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 35  , 37   </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 35  , 38   </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 36  , 37   </td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# ---- Example 4: Three-tier band over efficacy arms + Total ----
#
# Demographics-style three-tier nesting: top band labels the
# whole arm strip, middle band splits Active vs Placebo, leaf
# bands carry the per-arm column labels. Each child within a
# `list(...)` may itself be a `list(...)` — bands nest to
# arbitrary depth using nested list literals.
n <- stats::setNames(saf_n$n, saf_n$arm_short)
tabular(saf_demo, titles = "Demographics, hierarchical headers") |>
  cols(
    variable   = col_spec(usage = "group", label = "Characteristic"),
    stat_label = col_spec(label = "Statistic"),
    placebo    = col_spec(label = sprintf("N=%d", n["placebo"])),
    drug_50    = col_spec(label = sprintf("N=%d", n["drug_50"])),
    drug_100   = col_spec(label = sprintf("N=%d", n["drug_100"])),
    Total      = col_spec(label = sprintf("N=%d", n["Total"]))
  ) |>
  headers(
    "Treatment Group" = list(
      "Control" = "placebo",
      "Active"  = list(
        "Drug 50"  = "drug_50",
        "Drug 100" = "drug_100"
      ),
      "Pooled"  = "Total"
    )
  )
#> <style>
#> .tabular-doc { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> .tabular-content { width: 100%; }
#> .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> .tabular-pad { margin: 0; }
#> .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> .tabular-table th, .tabular-table td { padding: .35rem .6rem; }
#> .tabular-table td { text-align: left; vertical-align: top; }
#> .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> .tabular-table tbody tr td { border-top: none; }
#> .tabular-band { text-align: center; }
#> .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> .tabular-subgroup-label { font-weight: 600; }
#> .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> .text-left { text-align: left; }
#> .text-center { text-align: center; }
#> .text-right { text-align: right; }
#> .tabular-table thead th.text-left { text-align: left; }
#> .tabular-table thead th.text-center { text-align: center; }
#> .tabular-table thead th.text-right { text-align: right; }
#> .valign-top { vertical-align: top; }
#> .valign-middle { vertical-align: middle; }
#> .valign-bottom { vertical-align: bottom; }
#> .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> .tabular-empty { font-style: italic; color: #6c757d; }
#> .tabular-page-break-row { display: none; }
#> :root { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> .tabular-page-header, .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> .tabular-page-header { margin-bottom: 1rem; }
#> .tabular-page-footer { margin-top: 1rem; }
#> .tabular-page-header-left, .tabular-page-footer-left { flex: 1; text-align: left; }
#> .tabular-page-header-center, .tabular-page-footer-center { flex: 1; text-align: center; }
#> .tabular-page-header-right, .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { .tabular-table-wrap { overflow-x: visible; margin: 0; } .tabular-table tr { page-break-inside: avoid; } .tabular-page-header, .tabular-page-footer { display: none; } .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular_wECZ3jx2iy" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Demographics, hierarchical headers</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th colspan="1"></th><th colspan="4" class="tabular-band">Treatment Group</th></tr>
#> <tr><th colspan="1"></th><th colspan="1" class="tabular-band">Control</th><th colspan="2" class="tabular-band">Active</th><th colspan="1" class="tabular-band">Pooled</th></tr>
#> <tr><th colspan="2"></th><th colspan="1" class="tabular-band">Drug 100</th><th colspan="1" class="tabular-band">Drug 50</th><th colspan="1"></th></tr>
#> <tr><th>Statistic</th><th>N=86</th><th>N=72</th><th>N=96</th><th>N=254</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Age (years)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td>86</td><td>72</td><td>96</td><td>254</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td>75.2 (8.59)</td><td>73.8 (7.94)</td><td>76.0 (8.11)</td><td>75.1 (8.25)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td>76.0</td><td>75.5</td><td>78.0</td><td>77.0</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td>69.2, 81.8</td><td>70.5, 79.0</td><td>71.0, 82.0</td><td>70.0, 81.0</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td>52, 89</td><td>56, 88</td><td>51, 88</td><td>51, 89</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Age Group, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">18-64</td><td>14 (16.3)</td><td>11 (15.3)</td><td>8 (8.3)</td><td>33 (13.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">&gt;64</td><td>72 (83.7)</td><td>61 (84.7)</td><td>88 (91.7)</td><td>221 (87.0)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Sex, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">F</td><td>53 (61.6)</td><td>35 (48.6)</td><td>55 (57.3)</td><td>143 (56.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">M</td><td>33 (38.4)</td><td>37 (51.4)</td><td>41 (42.7)</td><td>111 (43.7)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Race, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">WHITE</td><td>78 (90.7)</td><td>62 (86.1)</td><td>90 (93.8)</td><td>230 (90.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLACK OR AFRICAN AMERICAN</td><td>8 (9.3)</td><td>9 (12.5)</td><td>6 (6.2)</td><td>23 (9.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ASIAN</td><td>0 (0.0)</td><td>0 (0.0)</td><td>0 (0.0)</td><td>0 (0.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">AMERICAN INDIAN OR ALASKA NATIVE</td><td>0 (0.0)</td><td>1 (1.4)</td><td>0 (0.0)</td><td>1 (0.4)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Ethnicity, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HISPANIC OR LATINO</td><td>3 (3.5)</td><td>3 (4.2)</td><td>6 (6.2)</td><td>12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NOT HISPANIC OR LATINO</td><td>83 (96.5)</td><td>69 (95.8)</td><td>90 (93.8)</td><td>242 (95.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NOT REPORTED</td><td>0 (0.0)</td><td>0 (0.0)</td><td>0 (0.0)</td><td>0 (0.0)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Weight (kg)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td>86</td><td>72</td><td>95</td><td>253</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td>62.8 (12.77)</td><td>69.5 (14.35)</td><td>68.0 (14.50)</td><td>66.6 (14.13)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td>60.6</td><td>69.0</td><td>66.7</td><td>66.7</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td>53.6, 74.2</td><td>56.9, 80.3</td><td>56.0, 78.2</td><td>55.3, 77.1</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td>34, 86</td><td>44, 108</td><td>42, 106</td><td>34, 108</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Height (cm)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td>86</td><td>72</td><td>96</td><td>254</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td>162.6 (11.52)</td><td>165.9 (10.28)</td><td>163.7 (10.30)</td><td>163.9 (10.76)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td>162.6</td><td>165.1</td><td>162.6</td><td>162.8</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td>154.0, 171.1</td><td>157.5, 172.8</td><td>157.5, 170.2</td><td>156.2, 171.4</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td>137, 185</td><td>146, 190</td><td>136, 196</td><td>136, 196</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>BMI (kg/m^2)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">n</td><td>86</td><td>72</td><td>95</td><td>253</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td>23.6 (3.67)</td><td>25.2 (3.97)</td><td>25.2 (4.40)</td><td>24.7 (4.09)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Median</td><td>23.4</td><td>24.8</td><td>24.8</td><td>24.2</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td>21.2, 25.6</td><td>22.7, 27.6</td><td>22.3, 28.2</td><td>21.9, 27.3</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="5"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td>15, 33</td><td>14, 35</td><td>15, 40</td><td>14, 40</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>BMI Category, n (%)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Underweight (&lt;18.5)</td><td>3 (3.5)</td><td>1 (1.4)</td><td>4 (4.2)</td><td>8 (3.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Normal (18.5-24.9)</td><td>57 (66.3)</td><td>39 (54.2)</td><td>46 (47.9)</td><td>142 (55.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">Overweight (25-29.9)</td><td>20 (23.3)</td><td>23 (31.9)</td><td>32 (33.3)</td><td>75 (29.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">Obese (&gt;=30)</td><td style="border-bottom: 0.5pt solid #212529;">6 (7.0)</td><td style="border-bottom: 0.5pt solid #212529;">9 (12.5)</td><td style="border-bottom: 0.5pt solid #212529;">13 (13.5)</td><td style="border-bottom: 0.5pt solid #212529;">28 (11.0)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
