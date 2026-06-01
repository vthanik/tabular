# Mark a string as Markdown for inline formatting

Wrap a length-1 character vector so
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md)
pretext / posttext, and similar string slots interpret it as CommonMark
Markdown at render time. Supports the GitHub-flavoured plus Pandoc-style
superscript (`^sup^`) and subscript (`~sub~`) extensions; raw HTML
inside Markdown passes through to the constrained tag set documented
under [`html()`](https://vthanik.github.io/tabular/reference/html.md).

## Usage

``` r
md(text)
```

## Arguments

- text:

  *The Markdown string.* `<character(1)>: required`. Length-1 character
  vector. `NA` is rejected; the empty string `""` renders as no content.

## Value

*A length-1 character vector classed `c("from_markdown", "character")`.*
Pass it directly into any string-bearing slot
([`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
titles / footnotes,
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
label, [`style()`](https://vthanik.github.io/tabular/reference/style.md)
pretext / posttext); the resolve engine calls `parse_inline()`
internally and backends walk the resulting `inline_ast`.

## Details

**Convention adopted from gt.** Marking strings with `md()` and
[`html()`](https://vthanik.github.io/tabular/reference/html.md) mirrors
the well-tested gt convention. Plain (unwrapped) strings render as plain
text — a stray `**` will NOT silently bold the surrounding span. Wrap
explicitly to opt in.

**Recognised Markdown.** `**bold**`, `*italic*`, `` `code` ``,
`[link text](url)`, hard line break (two trailing spaces + `\n` or
`\\` + `\n`), Pandoc `^sup^` and `~sub~`. Single embedded `\n` (a "soft
break" in CommonMark) renders as a space in HTML; tabular preserves it
as a line break for clinical-table use where multi-line cells / titles
are routine.

**HTML pass-through.** Raw HTML in Markdown (e.g.
`md("Drug A <span style='color:red'>warning</span>")`) is parsed as HTML
using the same tag whitelist as
[`html()`](https://vthanik.github.io/tabular/reference/html.md). Tags
outside the whitelist drop their wrapper and keep their text content.

**Composition with plain strings.** `md()` and
[`html()`](https://vthanik.github.io/tabular/reference/html.md) wrap the
input with an internal control-character prefix that survives
[`c()`](https://rdrr.io/r/base/c.html) concatenation, so you can freely
mix plain and marked strings in a single character vector:
`c("Table 14.3.1", md("**Drug A**"), "third")`. Backends strip the
marker before rendering; users never see it.

## See also

**Sibling helper:**
[`html()`](https://vthanik.github.io/tabular/reference/html.md) — same
wrapper pattern for raw HTML when Markdown cannot express the
formatting.

**String slots that consume the wrapper:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
(`titles`, `footnotes`),
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
(`label`),
[`style()`](https://vthanik.github.io/tabular/reference/style.md)
(`pretext`, `posttext`).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Bold title with Pandoc-style footnote marker ----
#
# AE-by-SOC/PT table. The third title line bolds "Safety
# Population (N=86)" via `md("**...**")`; the first footnote
# carries a Pandoc-style superscript marker `^a^` that the
# backends render as a true superscript.
n <- stats::setNames(saf_n$n, saf_n$arm_short)

tabular(
  saf_aesocpt,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by System Organ Class and Preferred Term",
    md(sprintf("**Safety Population (N=%d)**", n["Total"]))
  ),
  footnotes = c(
    md("^a^ Subjects counted once per SOC and once per PT.")
  )
) |>
  cols(
    label    = col_spec(label = "SOC / PT", indent_by = "indent_level"),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    Total    = col_spec(label = sprintf("Total\nN=%d", n["Total"]))
  )
#> <style>
#> #tabular-9bf9452eda { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-9bf9452eda .tabular-content { width: 100%; }
#> #tabular-9bf9452eda .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-9bf9452eda .tabular-pad { margin: 0; }
#> #tabular-9bf9452eda .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-9bf9452eda .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-9bf9452eda .tabular-table th, #tabular-9bf9452eda .tabular-table td { padding: .35rem .6rem; }
#> #tabular-9bf9452eda .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-9bf9452eda .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-9bf9452eda .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-9bf9452eda .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-9bf9452eda .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-9bf9452eda .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-9bf9452eda .tabular-table tbody tr td { border-top: none; }
#> #tabular-9bf9452eda .tabular-band { text-align: center; }
#> #tabular-9bf9452eda .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-9bf9452eda .tabular-subgroup-label { font-weight: 600; }
#> #tabular-9bf9452eda .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-9bf9452eda .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-9bf9452eda .text-left { text-align: left; }
#> #tabular-9bf9452eda .text-center { text-align: center; }
#> #tabular-9bf9452eda .text-right { text-align: right; }
#> #tabular-9bf9452eda .tabular-table thead th.text-left { text-align: left; }
#> #tabular-9bf9452eda .tabular-table thead th.text-center { text-align: center; }
#> #tabular-9bf9452eda .tabular-table thead th.text-right { text-align: right; }
#> #tabular-9bf9452eda .valign-top { vertical-align: top; }
#> #tabular-9bf9452eda .valign-middle { vertical-align: middle; }
#> #tabular-9bf9452eda .valign-bottom { vertical-align: bottom; }
#> #tabular-9bf9452eda .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-9bf9452eda .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-9bf9452eda .tabular-page-break-row { display: none; }
#> #tabular-9bf9452eda { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-9bf9452eda .tabular-page-header, #tabular-9bf9452eda .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-9bf9452eda .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-9bf9452eda .tabular-page-footer { margin-top: 1rem; }
#> #tabular-9bf9452eda .tabular-page-header-left, #tabular-9bf9452eda .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-9bf9452eda .tabular-page-header-center, #tabular-9bf9452eda .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-9bf9452eda .tabular-page-header-right, #tabular-9bf9452eda .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-9bf9452eda .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-9bf9452eda .tabular-table tr { page-break-inside: avoid; } #tabular-9bf9452eda .tabular-page-header, #tabular-9bf9452eda .tabular-page-footer { display: none; } #tabular-9bf9452eda .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-9bf9452eda .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-9bf9452eda .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-9bf9452eda" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.1</h1>
#> <h1 class="tabular-title">Adverse Events by System Organ Class and Preferred Term</h1>
#> <h1 class="tabular-title"><strong>Safety Population (N=254)</strong></h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>SOC / PT</th><th>n_total</th><th>soc_n</th><th>placebo</th><th>drug_50</th><th>drug_100</th><th>Total<br/>N=254</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>TOTAL SUBJECTS WITH AN EVENT</td><td>199</td><td>199</td><td>52 (60.5)</td><td>81 (84.4)</td><td>66 (91.7)</td><td>199 (78.3)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>90</td><td>90</td><td>19 (22.1)</td><td>36 (37.5)</td><td>35 (48.6)</td><td>90 (35.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PRURITUS</td><td>54</td><td>90</td><td>8 (9.3)</td><td>21 (21.9)</td><td>25 (34.7)</td><td>54 (21.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ERYTHEMA</td><td>36</td><td>90</td><td>8 (9.3)</td><td>14 (14.6)</td><td>14 (19.4)</td><td>36 (14.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">RASH</td><td>26</td><td>90</td><td>5 (5.8)</td><td>13 (13.5)</td><td>8 (11.1)</td><td>26 (10.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HYPERHIDROSIS</td><td>14</td><td>90</td><td>2 (2.3)</td><td>4 (4.2)</td><td>8 (11.1)</td><td>14 (5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SKIN IRRITATION</td><td>14</td><td>90</td><td>3 (3.5)</td><td>6 (6.2)</td><td>5 (6.9)</td><td>14 (5.5)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>81</td><td>81</td><td>15 (17.4)</td><td>36 (37.5)</td><td>30 (41.7)</td><td>81 (31.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE PRURITUS</td><td>50</td><td>81</td><td>6 (7.0)</td><td>23 (24.0)</td><td>21 (29.2)</td><td>50 (19.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE ERYTHEMA</td><td>30</td><td>81</td><td>3 (3.5)</td><td>13 (13.5)</td><td>14 (19.4)</td><td>30 (11.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE DERMATITIS</td><td>21</td><td>81</td><td>5 (5.8)</td><td>9 (9.4)</td><td>7 (9.7)</td><td>21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE IRRITATION</td><td>21</td><td>81</td><td>3 (3.5)</td><td>9 (9.4)</td><td>9 (12.5)</td><td>21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE VESICLES</td><td>11</td><td>81</td><td>1 (1.2)</td><td>5 (5.2)</td><td>5 (6.9)</td><td>11 (4.3)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>42</td><td>42</td><td>13 (15.1)</td><td>12 (12.5)</td><td>17 (23.6)</td><td>42 (16.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIARRHOEA</td><td>17</td><td>42</td><td>9 (10.5)</td><td>5 (5.2)</td><td>3 (4.2)</td><td>17 (6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VOMITING</td><td>13</td><td>42</td><td>3 (3.5)</td><td>4 (4.2)</td><td>6 (8.3)</td><td>13 (5.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NAUSEA</td><td>12</td><td>42</td><td>3 (3.5)</td><td>3 (3.1)</td><td>6 (8.3)</td><td>12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ABDOMINAL PAIN</td><td>5</td><td>42</td><td>1 (1.2)</td><td>3 (3.1)</td><td>1 (1.4)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SALIVARY HYPERSECRETION</td><td>4</td><td>42</td><td>0 (0.0)</td><td>0 (0.0)</td><td>4 (5.6)</td><td>4 (1.6)</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>41</td><td>41</td><td>6 (7.0)</td><td>18 (18.8)</td><td>17 (23.6)</td><td>41 (16.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIZZINESS</td><td>21</td><td>41</td><td>2 (2.3)</td><td>9 (9.4)</td><td>10 (13.9)</td><td>21 (8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HEADACHE</td><td>11</td><td>41</td><td>3 (3.5)</td><td>3 (3.1)</td><td>5 (6.9)</td><td>11 (4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SYNCOPE</td><td>7</td><td>41</td><td>0 (0.0)</td><td>5 (5.2)</td><td>2 (2.8)</td><td>7 (2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SOMNOLENCE</td><td>6</td><td>41</td><td>2 (2.3)</td><td>3 (3.1)</td><td>1 (1.4)</td><td>6 (2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">TRANSIENT ISCHAEMIC ATTACK</td><td>3</td><td>41</td><td>0 (0.0)</td><td>2 (2.1)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>33</td><td>33</td><td>7 (8.1)</td><td>12 (12.5)</td><td>14 (19.4)</td><td>33 (13.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SINUS BRADYCARDIA</td><td>17</td><td>33</td><td>2 (2.3)</td><td>7 (7.3)</td><td>8 (11.1)</td><td>17 (6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MYOCARDIAL INFARCTION</td><td>10</td><td>33</td><td>4 (4.7)</td><td>2 (2.1)</td><td>4 (5.6)</td><td>10 (3.9)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="7"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ATRIAL FIBRILLATION</td><td>5</td><td>33</td><td>1 (1.2)</td><td>2 (2.1)</td><td>2 (2.8)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SUPRAVENTRICULAR EXTRASYSTOLES</td><td>3</td><td>33</td><td>1 (1.2)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VENTRICULAR EXTRASYSTOLES</td><td>3</td><td>33</td><td>0 (0.0)</td><td>2 (2.1)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>29</td><td>29</td><td>12 (14.0)</td><td>6 (6.2)</td><td>11 (15.3)</td><td>29 (11.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASOPHARYNGITIS</td><td>12</td><td>29</td><td>2 (2.3)</td><td>4 (4.2)</td><td>6 (8.3)</td><td>12 (4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">UPPER RESPIRATORY TRACT INFECTION</td><td>10</td><td>29</td><td>6 (7.0)</td><td>1 (1.0)</td><td>3 (4.2)</td><td>10 (3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INFLUENZA</td><td>3</td><td>29</td><td>1 (1.2)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">URINARY TRACT INFECTION</td><td>3</td><td>29</td><td>2 (2.3)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CYSTITIS</td><td>2</td><td>29</td><td>1 (1.2)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>22</td><td>22</td><td>5 (5.8)</td><td>8 (8.3)</td><td>9 (12.5)</td><td>22 (8.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">COUGH</td><td>11</td><td>22</td><td>1 (1.2)</td><td>5 (5.2)</td><td>5 (6.9)</td><td>11 (4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASAL CONGESTION</td><td>7</td><td>22</td><td>3 (3.5)</td><td>1 (1.0)</td><td>3 (4.2)</td><td>7 (2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DYSPNOEA</td><td>3</td><td>22</td><td>1 (1.2)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">EPISTAXIS</td><td>3</td><td>22</td><td>0 (0.0)</td><td>1 (1.0)</td><td>2 (2.8)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PHARYNGOLARYNGEAL PAIN</td><td>2</td><td>22</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>19</td><td>19</td><td>7 (8.1)</td><td>9 (9.4)</td><td>3 (4.2)</td><td>19 (7.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CONFUSIONAL STATE</td><td>6</td><td>19</td><td>2 (2.3)</td><td>3 (3.1)</td><td>1 (1.4)</td><td>6 (2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">AGITATION</td><td>5</td><td>19</td><td>2 (2.3)</td><td>3 (3.1)</td><td>0 (0.0)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INSOMNIA</td><td>4</td><td>19</td><td>2 (2.3)</td><td>0 (0.0)</td><td>2 (2.8)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ANXIETY</td><td>3</td><td>19</td><td>0 (0.0)</td><td>3 (3.1)</td><td>0 (0.0)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DELUSION</td><td>2</td><td>19</td><td>1 (1.2)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>14</td><td>14</td><td>3 (3.5)</td><td>6 (6.2)</td><td>5 (6.9)</td><td>14 (5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BACK PAIN</td><td>5</td><td>14</td><td>1 (1.2)</td><td>1 (1.0)</td><td>3 (4.2)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRALGIA</td><td>4</td><td>14</td><td>1 (1.2)</td><td>2 (2.1)</td><td>1 (1.4)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SHOULDER PAIN</td><td>3</td><td>14</td><td>1 (1.2)</td><td>2 (2.1)</td><td>0 (0.0)</td><td>3 (1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MUSCLE SPASMS</td><td>2</td><td>14</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRITIS</td><td>1</td><td>14</td><td>0 (0.0)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>1 (0.4)</td></tr>
#> <tr><td>INVESTIGATIONS</td><td>12</td><td>12</td><td>5 (5.8)</td><td>4 (4.2)</td><td>3 (4.2)</td><td>12 (4.7)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="7"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM ST SEGMENT DEPRESSION</td><td>5</td><td>12</td><td>4 (4.7)</td><td>1 (1.0)</td><td>0 (0.0)</td><td>5 (2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE INVERSION</td><td>4</td><td>12</td><td>2 (2.3)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>4 (1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLOOD GLUCOSE INCREASED</td><td>2</td><td>12</td><td>0 (0.0)</td><td>1 (1.0)</td><td>1 (1.4)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td>2</td><td>12</td><td>1 (1.2)</td><td>1 (1.0)</td><td>0 (0.0)</td><td>2 (0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">BIOPSY</td><td style="border-bottom: 0.5pt solid #212529;">1</td><td style="border-bottom: 0.5pt solid #212529;">12</td><td style="border-bottom: 0.5pt solid #212529;">0 (0.0)</td><td style="border-bottom: 0.5pt solid #212529;">0 (0.0)</td><td style="border-bottom: 0.5pt solid #212529;">1 (1.4)</td><td style="border-bottom: 0.5pt solid #212529;">1 (0.4)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote"><sup>a</sup> Subjects counted once per SOC and once per PT.</p>
#> </div></div>

# ---- Example 2: Markdown link in a footnote ----
#
# Efficacy BOR table that footnotes the response criteria with
# a Markdown link. HTML / PDF / DOCX render as clickable; RTF /
# LaTeX render the link text with the URL inline (backend
# decides).
ne <- stats::setNames(eff_n$n, eff_n$arm_short)

tabular(
  eff_resp,
  titles = c(
    "Table 14.2.1",
    "Best Overall Response",
    sprintf("Efficacy Evaluable Population (N=%d)", ne["Total"])
  ),
  footnotes = c(
    md("Response per [RECIST 1.1](https://recist.eortc.org/), investigator assessment.")
  )
) |>
  cols(
    stat_label = col_spec(usage = "group", label = "Response"),
    row_type   = col_spec(visible = FALSE)
  )
#> <style>
#> #tabular-75f0006a10 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-75f0006a10 .tabular-content { width: 100%; }
#> #tabular-75f0006a10 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-75f0006a10 .tabular-pad { margin: 0; }
#> #tabular-75f0006a10 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-75f0006a10 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-75f0006a10 .tabular-table th, #tabular-75f0006a10 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-75f0006a10 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-75f0006a10 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-75f0006a10 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-75f0006a10 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-75f0006a10 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-75f0006a10 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-75f0006a10 .tabular-table tbody tr td { border-top: none; }
#> #tabular-75f0006a10 .tabular-band { text-align: center; }
#> #tabular-75f0006a10 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-75f0006a10 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-75f0006a10 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-75f0006a10 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-75f0006a10 .text-left { text-align: left; }
#> #tabular-75f0006a10 .text-center { text-align: center; }
#> #tabular-75f0006a10 .text-right { text-align: right; }
#> #tabular-75f0006a10 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-75f0006a10 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-75f0006a10 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-75f0006a10 .valign-top { vertical-align: top; }
#> #tabular-75f0006a10 .valign-middle { vertical-align: middle; }
#> #tabular-75f0006a10 .valign-bottom { vertical-align: bottom; }
#> #tabular-75f0006a10 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-75f0006a10 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-75f0006a10 .tabular-page-break-row { display: none; }
#> #tabular-75f0006a10 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-75f0006a10 .tabular-page-header, #tabular-75f0006a10 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-75f0006a10 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-75f0006a10 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-75f0006a10 .tabular-page-header-left, #tabular-75f0006a10 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-75f0006a10 .tabular-page-header-center, #tabular-75f0006a10 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-75f0006a10 .tabular-page-header-right, #tabular-75f0006a10 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-75f0006a10 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-75f0006a10 .tabular-table tr { page-break-inside: avoid; } #tabular-75f0006a10 .tabular-page-header, #tabular-75f0006a10 .tabular-page-footer { display: none; } #tabular-75f0006a10 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-75f0006a10 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-75f0006a10 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-75f0006a10" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.2.1</h1>
#> <h1 class="tabular-title">Best Overall Response</h1>
#> <h1 class="tabular-title">Efficacy Evaluable Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>placebo</th><th>drug_50</th><th>drug_100</th><th>groupid</th><th>group_label</th></tr>
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
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>(0.3, 8.1)</td><td>(0.0, 6.5)</td><td>(0.0, 6.5)</td><td>2</td><td>Objective Response Rate</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>3 (3.5)</td><td>1 (1.2)</td><td>1 (1.2)</td><td>3</td><td>Clinical Benefit Rate</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>(0.7, 9.9)</td><td>(0.0, 6.5)</td><td>(0.0, 6.5)</td><td>3</td><td>Clinical Benefit Rate</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td>3 (3.5)</td><td>1 (1.2)</td><td>2 (2.4)</td><td>4</td><td>Disease Control Rate</td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">(0.7, 9.9)</td><td style="border-bottom: 0.5pt solid #212529;">(0.0, 6.5)</td><td style="border-bottom: 0.5pt solid #212529;">(0.3, 8.3)</td><td style="border-bottom: 0.5pt solid #212529;">4</td><td style="border-bottom: 0.5pt solid #212529;">Disease Control Rate</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Response per <a href="https://recist.eortc.org/">RECIST 1.1</a>, investigator assessment.</p>
#> </div></div>
```
