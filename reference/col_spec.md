# Per-column display specification

Build a single column's display attributes — usage, label, format,
visibility, width, alignment, NA text. The result feeds
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md), which
stamps the input column name onto the spec from its named- argument
position and attaches it to the parent `tabular_spec`.

## Usage

``` r
col_spec(
  usage = NULL,
  label = NA_character_,
  format = NULL,
  visible = TRUE,
  width = "auto",
  group_display = "header_row",
  group_skip = NA,
  align = NULL,
  valign = NULL,
  na_text = "",
  indent_by = NA_character_
)
```

## Arguments

- usage:

  *Engine role.* `<character(1) | NULL>: default NULL`. One of:

  - **`"display"`** (default in
    [`cols()`](https://vthanik.github.io/tabular/reference/cols.md)) —
    pass-through.

  - **`"group"`** — row-label with repeat-suppression and
    continuation-page repeat keys. Use for `variable`, `soc`,
    `stat_label`.

  - **`"indent"`** — prefix every body cell of this column with one
    indent level (`preset@indent_size` space-widths). Composes
    additively with `indent_by` (a column with both gets `depth_by + 1`
    indent levels per row). Backends with native padding-left semantics
    (HTML / LaTeX / RTF / DOCX / PDF) emit this as cell padding so
    wrapped continuation lines align with the indented baseline;
    Markdown carries the literal space-prefix. Synthesised group-header
    rows (under `group_display = "header_row"`) are NEVER indented —
    they're the parent at depth 0.

  - **`"id"`** — a row-identifier column. Renders like `"display"` (one
    value per row, never collapses) but joins the *stub*: it repeats on
    every horizontal panel (`paginate(panels = N)`) and shows once on
    the left when a continuous backend (HTML / Markdown) collapses the
    panels into one table. The PROC REPORT `ID` role, orthogonal to
    grouping. Use for a per-row statistic label (`"n"`, `"Mean"`,
    `"SD"`) that must stay legible on every panel of a wide demographics
    or efficacy table.

  - **`NULL`** — inferred as `"display"` in
    [`cols()`](https://vthanik.github.io/tabular/reference/cols.md).

      # Two row-label columns and four arm columns.
      cols(
        variable   = col_spec(usage = "group"),
        stat_label = col_spec(usage = "group"),
        placebo    = col_spec(),
        drug_50    = col_spec()
      )

      # Section-band table: the `group_label` column drives section
      # headers; `stat_label` body rows auto-indent under each header
      # without an explicit depth column.
      cols(
        group_label = col_spec(usage = "group",  group_display = "header_row"),
        stat_label  = col_spec(usage = "indent", label = "Response"),
        placebo     = col_spec(align = "decimal")
      )

      # End-to-end ARD → wide → tabular pipeline. The cards ARD
      # `saf_demo_card` is the long upstream input; `pivot_across()`
      # widens to one column per arm and stamps an internal marker
      # so [`sort_rows()`] can reject sort keys on those arm columns.
      # `cols()` then attaches per-column display rules.
      wide <- pivot_across(
        saf_demo_card,
        statistic = list(
          continuous  = c(N = "{N}", "Mean (SD)" = "{mean} ({sd})"),
          categorical = "{n} ({p}%)"
        )
      )
      tabular(wide, titles = "Demographics") |>
        cols(
          variable                 = col_spec(
            usage = "group", label = "Characteristic"
          ),
          stat_label               = col_spec(
            usage = "group", label = "Statistic"
          ),
          Placebo                  = col_spec(align = "decimal"),
          `Xanomeline High Dose`   = col_spec(
            label = "High Dose", align = "decimal"
          ),
          `Xanomeline Low Dose`    = col_spec(
            label = "Low Dose", align = "decimal"
          ),
          Total                    = col_spec(align = "decimal")
        )

- label:

  *Display label for the column header.*
  `<character(1)>: default NA_character_`. Embed `\n` for multi-line
  headers (arm name on row 1, BigN denominator on row 2 is the clinical
  convention). `NA_character_` means use the input column name verbatim.

  **Restriction:** Empty string and whitespace-only labels are accepted
  here, unlike
  [`headers()`](https://vthanik.github.io/tabular/reference/headers.md)
  band labels which are strict.

      # Two-line header with arm name and BigN from saf_n.
      n <- stats::setNames(saf_n$n, saf_n$arm_short)
      col_spec(
        label = sprintf("Placebo\nN=%d", n["placebo"]),
        align = "decimal"
      )

- format:

  *Post-cell formatter.*
  `<character(1) | function | NULL>: default NULL`. A `sprintf` template
  applied per cell, OR a unary `function(x) -> character` of the same
  length, OR `NULL` for backend default.

  **Restriction:** Character templates are probed with
  `sprintf(format, 0)` at construction; malformed templates fail fast.
  **Tip:** Use a function for non-`sprintf` formatting (locale- aware
  numbers, thousand separators, conditional symbols).

      # sprintf template vs. function form.
      col_spec(format = "%.1f")
      col_spec(format = function(x) formatC(x, format = "f", digits = 1, big.mark = ","))

- visible:

  *Whether the column renders.* `<logical(1)>: default TRUE`. `FALSE`
  hides the column from output but keeps it in `spec@data` so
  [`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md)
  and [`style()`](https://vthanik.github.io/tabular/reference/style.md)
  predicates can still reference it.

  **Interaction:** Hidden columns are the standard pattern for sort-key
  helpers (`row_type`, `n_total`) and for the numeric counts behind
  formatted-text percentage cells.

  **Auto-hide.** The depth column named by `indent_by` and every column
  named by
  [`subgroup(by = ...)`](https://vthanik.github.io/tabular/reference/subgroup.md)
  or referenced via a `{col}` placeholder in the subgroup banner
  template are flipped to `visible = FALSE` automatically at engine time
  — restating it here is redundant.

  **Break-only group column.** A hidden `usage = "group"` column emits
  no header rows and no in-column text; it contributes only its
  `group_skip` transitions, so `group_display` is ignored while hidden.
  This is the canonical "spacer" that drops a blank line wherever a
  marker value changes (e.g. continuous stats vs. categorical groups
  inside one characteristic):
  `col_spec(usage = "group", group_skip = TRUE, visible = FALSE)`.

- width:

  *Column width — auto-sized, pinned, or proportional.*
  `<character(1) | numeric(1)>: default "auto"`.

  - **`"auto"`** *(default)* — engine measures the widest cell (header +
    body) using bundled Adobe AFM Core 13 glyph metrics and distributes
    against the available content width. The **header** is sized to its
    widest *word*, so a multi-word header (e.g. `"n, median"`) wraps at
    spaces; a non-breaking space (` `) keeps a run whole. The **body**
    is sized to its widest *line* and never wraps, so numeric values
    stay intact. Pin a numeric width to wrap the body too.

  - **`<number>`** — pinned in inches. Backends wrap content inside the
    pinned width (tabularray `Q[wd=...]`, HTML `style="width:..."`, RTF
    / DOCX after twips conversion).

  - **`"2.5in"` / `"60mm"` / `"4cm"` / `"30pt"` / `"5pc"`** — pinned
    dimension with an explicit TeX unit. Same behaviour as a bare
    numeric.

  - **`"30%"`** — proportional width, percent of available content
    width. Resolved at engine time against the printable area.

  **Tip:** Mix freely. Pinned and percent widths take priority; `"auto"`
  columns distribute whatever space remains. If pinned widths together
  exceed the available content width, the engine warns and leaves
  `"auto"` columns at their natural fit (layout may overflow).

  **Restriction:** Must be positive. Percent values must fall in
  `[0, 100]`. Font-relative units (`em`, `ex`, `rem`) are rejected (no
  font-size context at parse time).

  **Cross-format semantics (gt convention).** The width value is the
  user's source-of-truth. HTML emits it verbatim into
  `<col style="width:...">` (CSS accepts every unit: `%`, `in`, `px`,
  `pt`, `cm`, `mm`). Paper backends (LaTeX / RTF / PDF / DOCX) convert
  to their native unit via the AFM / distribute-widths pipeline. HTML is
  unconditionally responsive: when `width = "auto"` (default), the
  browser auto-sizes the column and cells wrap when the viewport
  narrows.

  **Note:** `NA` and `NULL` are rejected. In pre-v0.1.0 tabular `NA`
  deferred to backend auto-fit; that path was inconsistent across
  backends and is replaced by the `"auto"` default, which produces
  identical widths across RTF / LaTeX / HTML.

- group_display:

  *How `usage = "group"` values render in the body.*
  `<character(1)>: default "header_row"`. Active only when
  `usage = "group"`; ignored otherwise.

  - **`"header_row"`** *(default)* — each unique value emits as a
    section header row above its block of data rows. The source column
    is hidden from the visible body. Matches the canonical submission
    Appendix I shape used by clinical TFL house templates (Disposition,
    Demographics, Statistical Report sections).

  - **`"column"`** — column stays visible; repeated values are
    suppressed (only the first row of each value shows the label). PROC
    REPORT's default for grouping variables.

  - **`"column_repeat"`** — column stays visible; every row repeats the
    value (no suppression). The shape `R`'s `print.data.frame` produces.

  **Composition under multiple group columns.** When more than one
  `usage = "group"` column is declared, the FIRST one encountered in
  [`cols()`](https://vthanik.github.io/tabular/reference/cols.md) order
  is the outer group; subsequent group columns nest inside it. Each
  column's `group_display` choice is independent — a common clinical
  pattern is the outer `variable` as `"header_row"` plus the inner
  `stat_label` as `"column"` (visible row labels under each section
  header).

      # Demographics layout: variable as section header, stat_label
      # as visible suppressed column.
      cols(
        variable   = col_spec(usage = "group", group_display = "header_row"),
        stat_label = col_spec(usage = "group", group_display = "column"),
        placebo    = col_spec(label = "Placebo", align = "decimal")
      )

- group_skip:

  *Insert a blank row between consecutive groups.*
  `<logical(1)>: default NA`. Active only when `usage = "group"`;
  ignored otherwise. Three values:

  - **`TRUE`** — engine injects one blank row immediately before each
    value transition on this column (PROC REPORT's
    `BREAK AFTER var / SKIP` semantics, lifted to per-column control).
    Never trails the final group.

  - **`FALSE`** — never insert a blank row for this column.

  - **`NA`** *(default)* — follow `group_display`: `TRUE` when
    `group_display = "header_row"`, `FALSE` when `"column"` or
    `"column_repeat"`. Picks the canonical Appendix-I shape without an
    extra knob to set.

  **Interaction:** When two or more columns have an effective
  `group_skip = TRUE` and their value transitions coincide on the same
  row, the engine emits ONE blank row at that boundary, not one per
  column. Transition row indices are unioned across all contributing
  group columns.

      # Default: header_row mode auto-injects blanks between sections.
      col_spec(usage = "group", group_display = "header_row")

      # Override: keep the column visible (suppressed-value mode) but
      # still insert blank-row separators between value changes.
      col_spec(usage = "group", group_display = "column", group_skip = TRUE)

      # Override: section headers without the blank-row separator
      # (denser layout, used when vertical space is tight).
      col_spec(usage = "group", group_display = "header_row", group_skip = FALSE)

      # Break-only "spacer": pairs with visible = FALSE to drop a blank
      # line wherever a hidden marker changes, without rendering the
      # column or any header row. group_display is ignored when hidden.
      col_spec(usage = "group", group_skip = TRUE, visible = FALSE)

- align:

  *Horizontal alignment within the column.*
  `<character(1) | NULL>: default NULL`. One of:

  - **`"left"`** — character columns; row labels.

  - **`"center"`** — column-header band; rarely on data cells.

  - **`"right"`** — numeric content without decimals.

  - **`"decimal"`** — numeric or mixed-format cells aligned on the
    decimal mark. Use for `"5 (3.2%)"` next to `"54 (32.1%)"`.

  - **`NULL`** (default) — falls through to
    `preset(alignment = list(body_halign = ...))` and then to the baked
    default `"left"`.

  **Tip:** `"decimal"` pads numerics with non-breaking spaces so the
  decimal mark falls on a single column-wide anchor. The active preset's
  `decimal_metrics` knob is reserved for future em-aware padding
  refinement (see
  [`preset()`](https://vthanik.github.io/tabular/reference/preset.md));
  the current engine pads by character count.

  **Default behaviour.** When `align` is unset (`NULL` / `NA`), every
  column emits with body left-aligned and header centred, regardless of
  the column's R data type. tabular's canonical input is pre-summarised
  wide data frames where numeric content is already formatted as
  character strings (e.g. `"52 (60.5)"`), so
  [`is.numeric()`](https://rdrr.io/r/base/numeric.html)-based
  auto-detection would mis-classify those columns as text and align them
  left — the opposite of intent. Use explicit `align = "decimal"` for
  NBSP-padded numeric columns (centred header over the padded centroid)
  or `align = "right"` for plain right-aligned numeric columns. The
  default cascade is body →
  `preset(alignment = list( body_halign = ...))` → CSS
  `text-align: left`; header →
  `preset(alignment = list(header_halign = ...))` → CSS
  `text-align: center`.

- valign:

  *Vertical alignment within the cell.*
  `<character(1) | NULL>: default NULL`. One of `"top"`, `"middle"`,
  `"bottom"`. `NULL` falls through to
  `preset(alignment = list(body_valign = ...))` (baked default `"top"`).
  Per-cell overrides via `style(valign = ...)` still win over the column
  setting.

  **Tip:** Set `"middle"` on the row-label column of a banded- row table
  so the label stays centred against the multi-line stat-block in the
  adjacent cell.

- na_text:

  *Text substituted for `NA` cells.* `<character(1)>: default ""`.
  Substituted BEFORE the `format` step, so `format` does not need to
  anticipate `NA`.

  **Tip:** Use a sentinel (`"-"`, `"NR"`, `"."`) when blank cells would
  be ambiguous, e.g. when "not applicable" and "not reported" both
  render blank.

- indent_by:

  *Name of a column in `spec@data` whose per-row integer / logical
  values drive indent depth on this column.*
  `<character(1)>: default NA_character_`. When set, the engine reads
  `spec@data[[indent_by]]` and prefixes this column's text

  - AST in each row with `strrep(" ", preset@indent_size * depth)`. The
    referenced depth column is auto-hidden — no need to set
    `visible = FALSE` on it.

  Typical SOC / PT pattern (the bundled `saf_aesocpt` ships with the
  canonical depth column already attached, so no upstream construction
  is needed):

      cols(
        label    = col_spec(label = "Category", indent_by = "indent_level"),
        soc      = col_spec(visible = FALSE),
        row_type = col_spec(visible = FALSE)
      )

  Multi-depth nesting works the same way — values `c(0L, 1L, 2L, …)`
  produce `0`, `1`, `2`, … indent levels of `preset@indent_size`
  space-widths each. Negative values clamp to 0 (warn); fractional
  numerics floor (warn); NA → 0 (silent).

  Composes orthogonally with `group_display = "header_row"`: synthetic
  group headers (depth 0) stay flush as parents; data rows under them
  carry their column's declared depth. Works in flat listings too —
  `indent_by` does not require any `usage = "group"` columns.

## Value

*A `col_spec` S7 object.* Pass it to
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) keyed by
the input column name; the constructor itself does not stamp a name.

## Details

**Constructor-only.** `col_spec()` does not know which input column it
belongs to until
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) stamps
the name. Build reusable specs as ordinary R objects (e.g.
`arm_col <- col_spec(align = "decimal")`) and apply them to multiple
inputs without restating the name.

**Merge semantics across repeated
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) calls.**
When [`cols()`](https://vthanik.github.io/tabular/reference/cols.md) is
called twice for the same column, the engine merges field-by-field: a
non-default value on the new spec overrides; a default-valued field (NA
/ NULL / "" / `TRUE`) leaves the existing field intact. Build a column's
spec in stages without re-stating earlier attributes.

**Validation timing.** Argument shapes are validated eagerly — a
malformed `sprintf` template is probed at construction
(`sprintf(format, 0)`) and fails fast at write time, not at render time.

## See also

**Companion verb:**
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) attaches
`col_spec` entries to a `tabular_spec` keyed by input column name.

**Sibling build verbs:**
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
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
# ---- Example 1: Demographics with every col_spec field exercised ----
#
# Demographics table where every `col_spec` field is in play:
# the row-label columns are pinned to a fixed width and aligned
# left, the four arm columns embed BigN inline in the header,
# decimal-align numeric content, and render `NA` cells as "-".
n <- stats::setNames(saf_n$n, saf_n$arm_short)

tabular(
  saf_demo,
  titles = c(
    "Table 14.1.1",
    "Demographics and Baseline Characteristics",
    sprintf("Safety Population (N=%d)", n["Total"])
  ),
  footnotes = "Percentages based on N per treatment group."
) |>
  cols(
    variable   = col_spec(
      usage = "group", label = "Parameter",
      width = 2.0,     align = "left"
    ),
    stat_label = col_spec(label = "Statistic", align = "left"),
    placebo  = col_spec(
      label = sprintf("Placebo\nN=%d", n["placebo"]),
      align = "decimal", na_text = "-"
    ),
    drug_50  = col_spec(
      label = sprintf("Drug 50\nN=%d", n["drug_50"]),
      align = "decimal", na_text = "-"
    ),
    drug_100 = col_spec(
      label = sprintf("Drug 100\nN=%d", n["drug_100"]),
      align = "decimal", na_text = "-"
    ),
    Total    = col_spec(
      label = sprintf("Total\nN=%d", n["Total"]),
      align = "decimal", na_text = "-"
    )
  ) |>
  sort_rows(by = c("variable", "stat_label"))
#> <style>
#> #tabular-3386ac1cd6 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-3386ac1cd6 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-3386ac1cd6 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-3386ac1cd6 .tabular-pad { margin: 0; }
#> #tabular-3386ac1cd6 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-3386ac1cd6 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-3386ac1cd6 .tabular-table th, #tabular-3386ac1cd6 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-3386ac1cd6 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-3386ac1cd6 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-3386ac1cd6 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-3386ac1cd6 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-3386ac1cd6 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-3386ac1cd6 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-3386ac1cd6 .tabular-table tbody tr td { border-top: none; }
#> #tabular-3386ac1cd6 .tabular-band { text-align: center; }
#> #tabular-3386ac1cd6 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-3386ac1cd6 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-3386ac1cd6 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-3386ac1cd6 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-3386ac1cd6 .text-left { text-align: left; }
#> #tabular-3386ac1cd6 .text-center { text-align: center; }
#> #tabular-3386ac1cd6 .text-right { text-align: right; }
#> #tabular-3386ac1cd6 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-3386ac1cd6 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-3386ac1cd6 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-3386ac1cd6 .valign-top { vertical-align: top; }
#> #tabular-3386ac1cd6 .valign-middle { vertical-align: middle; }
#> #tabular-3386ac1cd6 .valign-bottom { vertical-align: bottom; }
#> #tabular-3386ac1cd6 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-3386ac1cd6 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-3386ac1cd6 .tabular-page-break-row { display: none; }
#> #tabular-3386ac1cd6 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-3386ac1cd6 .tabular-page-header, #tabular-3386ac1cd6 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-3386ac1cd6 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-3386ac1cd6 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-3386ac1cd6 .tabular-page-header-left, #tabular-3386ac1cd6 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-3386ac1cd6 .tabular-page-header-center, #tabular-3386ac1cd6 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-3386ac1cd6 .tabular-page-header-right, #tabular-3386ac1cd6 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-3386ac1cd6 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-3386ac1cd6 .tabular-table tr { page-break-inside: avoid; } #tabular-3386ac1cd6 .tabular-page-header, #tabular-3386ac1cd6 .tabular-page-footer { display: none; } #tabular-3386ac1cd6 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-3386ac1cd6 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-3386ac1cd6 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-3386ac1cd6" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.1.1</h1>
#> <h1 class="tabular-title">Demographics and Baseline Characteristics</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
#> <thead>
#> <tr><th class="text-left">Statistic</th><th class="text-center">Placebo<br/>N=86</th><th class="text-center">Drug 100<br/>N=72</th><th class="text-center">Drug 50<br/>N=96</th><th class="text-center">Total<br/>N=254</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Age (years)</strong></td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right"> 75.2 (8.59) </td><td class="text-right"> 73.8 (7.94) </td><td class="text-right"> 76.0 (8.11) </td><td class="text-right"> 75.1 (8.25) </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right"> 76.0        </td><td class="text-right"> 75.5        </td><td class="text-right"> 78.0        </td><td class="text-right"> 77.0        </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right"> 52  , 89    </td><td class="text-right"> 56  , 88    </td><td class="text-right"> 51  , 88    </td><td class="text-right"> 51  , 89    </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right"> 69.2, 81.8  </td><td class="text-right"> 70.5, 79.0  </td><td class="text-right"> 71.0, 82.0  </td><td class="text-right"> 70.0, 81.0  </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">n</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 96          </td><td class="text-right">254          </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Age Group, n (%)</strong></td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">18-64</td><td class="text-right"> 14 (16.3)   </td><td class="text-right"> 11 (15.3)   </td><td class="text-right">  8 ( 8.3)   </td><td class="text-right"> 33 (13.0)   </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">&gt;64</td><td class="text-right"> 72 (83.7)   </td><td class="text-right"> 61 (84.7)   </td><td class="text-right"> 88 (91.7)   </td><td class="text-right">221 (87.0)   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>BMI (kg/m^2)</strong></td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right"> 23.6 (3.67) </td><td class="text-right"> 25.2 (3.97) </td><td class="text-right"> 25.2 (4.40) </td><td class="text-right"> 24.7 (4.09) </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right"> 23.4        </td><td class="text-right"> 24.8        </td><td class="text-right"> 24.8        </td><td class="text-right"> 24.2        </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right"> 15  , 33    </td><td class="text-right"> 14  , 35    </td><td class="text-right"> 15  , 40    </td><td class="text-right"> 14  , 40    </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right"> 21.2, 25.6  </td><td class="text-right"> 22.7, 27.6  </td><td class="text-right"> 22.3, 28.2  </td><td class="text-right"> 21.9, 27.3  </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">n</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 95          </td><td class="text-right">253          </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>BMI Category, n (%)</strong></td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Normal (18.5-24.9)</td><td class="text-right"> 57 (66.3)   </td><td class="text-right"> 39 (54.2)   </td><td class="text-right"> 46 (47.9)   </td><td class="text-right">142 (55.9)   </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Obese (&gt;=30)</td><td class="text-right">  6 ( 7.0)   </td><td class="text-right">  9 (12.5)   </td><td class="text-right"> 13 (13.5)   </td><td class="text-right"> 28 (11.0)   </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Overweight (25-29.9)</td><td class="text-right"> 20 (23.3)   </td><td class="text-right"> 23 (31.9)   </td><td class="text-right"> 32 (33.3)   </td><td class="text-right"> 75 (29.5)   </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Underweight (&lt;18.5)</td><td class="text-right">  3 ( 3.5)   </td><td class="text-right">  1 ( 1.4)   </td><td class="text-right">  4 ( 4.2)   </td><td class="text-right">  8 ( 3.1)   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Ethnicity, n (%)</strong></td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">HISPANIC OR LATINO</td><td class="text-right">  3 ( 3.5)   </td><td class="text-right">  3 ( 4.2)   </td><td class="text-right">  6 ( 6.2)   </td><td class="text-right"> 12 ( 4.7)   </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">NOT HISPANIC OR LATINO</td><td class="text-right"> 83 (96.5)   </td><td class="text-right"> 69 (95.8)   </td><td class="text-right"> 90 (93.8)   </td><td class="text-right">242 (95.3)   </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">NOT REPORTED</td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Height (cm)</strong></td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right">162.6 (11.52)</td><td class="text-right">165.9 (10.28)</td><td class="text-right">163.7 (10.30)</td><td class="text-right">163.9 (10.76)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right">162.6        </td><td class="text-right">165.1        </td><td class="text-right">162.6        </td><td class="text-right">162.8        </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right">137  , 185   </td><td class="text-right">146  , 190   </td><td class="text-right">136  , 196   </td><td class="text-right">136  , 196   </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right">154.0, 171.1 </td><td class="text-right">157.5, 172.8 </td><td class="text-right">157.5, 170.2 </td><td class="text-right">156.2, 171.4 </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">n</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 96          </td><td class="text-right">254          </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Race, n (%)</strong></td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">AMERICAN INDIAN OR ALASKA NATIVE</td><td class="text-right">  0          </td><td class="text-right">  1 ( 1.4)   </td><td class="text-right">  0          </td><td class="text-right">  1 ( 0.4)   </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">ASIAN</td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">BLACK OR AFRICAN AMERICAN</td><td class="text-right">  8 ( 9.3)   </td><td class="text-right">  9 (12.5)   </td><td class="text-right">  6 ( 6.2)   </td><td class="text-right"> 23 ( 9.1)   </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">WHITE</td><td class="text-right"> 78 (90.7)   </td><td class="text-right"> 62 (86.1)   </td><td class="text-right"> 90 (93.8)   </td><td class="text-right">230 (90.6)   </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="5"></td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Sex, n (%)</strong></td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">F</td><td class="text-right"> 53 (61.6)   </td><td class="text-right"> 35 (48.6)   </td><td class="text-right"> 55 (57.3)   </td><td class="text-right">143 (56.3)   </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">M</td><td class="text-right"> 33 (38.4)   </td><td class="text-right"> 37 (51.4)   </td><td class="text-right"> 41 (42.7)   </td><td class="text-right">111 (43.7)   </td></tr>
#> <tr class="tabular-blank-row"><td colspan="5">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="5"><strong>Weight (kg)</strong></td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Mean (SD)</td><td class="text-right"> 62.8 (12.77)</td><td class="text-right"> 69.5 (14.35)</td><td class="text-right"> 68.0 (14.50)</td><td class="text-right"> 66.6 (14.13)</td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Median</td><td class="text-right"> 60.6        </td><td class="text-right"> 69.0        </td><td class="text-right"> 66.7        </td><td class="text-right"> 66.7        </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Min, Max</td><td class="text-right"> 34  , 86    </td><td class="text-right"> 44  , 108   </td><td class="text-right"> 42  , 106   </td><td class="text-right"> 34  , 108   </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em);">Q1, Q3</td><td class="text-right"> 53.6, 74.2  </td><td class="text-right"> 56.9,  80.3 </td><td class="text-right"> 56.0,  78.2 </td><td class="text-right"> 55.3,  77.1 </td></tr>
#> <tr><td class="text-left" style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">n</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 86          </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 72          </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 95          </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">253          </td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Percentages based on N per treatment group.</p>
#> </div></div>

# ---- Example 2: AE table with indented label + hidden helpers ----
#
# AE-by-SOC/PT table where `label` carries SOC and PT text under
# one column, indented by `indent_level`. Hidden helpers
# (`row_type`, `n_total`) drive the sort while staying off the
# rendered page. Demonstrates `indent_by` plus `visible = FALSE`
# for sort-only columns, fixed width on the wide label column, and
# decimal alignment on all four arm columns.
ae <- saf_aesocpt
ae$row_type <- factor(ae$row_type, levels = c("overall", "soc", "pt"))
ae$n_total <- as.integer(sub(" .*", "", ae$Total))

tabular(
  ae,
  titles = c(
    "Table 14.3.1",
    "Adverse Events by SOC and Preferred Term",
    sprintf("Safety Population (N=%d)", n["Total"])
  )
) |>
  cols(
    label    = col_spec(label = "SOC / Preferred Term",
                        indent_by = "indent_level", width = 2.5),
    soc      = col_spec(visible = FALSE),
    row_type = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"]),  align = "decimal"),
    drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"]),  align = "decimal"),
    drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"]), align = "decimal"),
    Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]),    align = "decimal")
  ) |>
  sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE))
#> <style>
#> #tabular-1f7f9732f2 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-1f7f9732f2 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-1f7f9732f2 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-1f7f9732f2 .tabular-pad { margin: 0; }
#> #tabular-1f7f9732f2 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-1f7f9732f2 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-1f7f9732f2 .tabular-table th, #tabular-1f7f9732f2 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-1f7f9732f2 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-1f7f9732f2 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-1f7f9732f2 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-1f7f9732f2 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-1f7f9732f2 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-1f7f9732f2 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-1f7f9732f2 .tabular-table tbody tr td { border-top: none; }
#> #tabular-1f7f9732f2 .tabular-band { text-align: center; }
#> #tabular-1f7f9732f2 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-1f7f9732f2 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-1f7f9732f2 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-1f7f9732f2 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-1f7f9732f2 .text-left { text-align: left; }
#> #tabular-1f7f9732f2 .text-center { text-align: center; }
#> #tabular-1f7f9732f2 .text-right { text-align: right; }
#> #tabular-1f7f9732f2 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-1f7f9732f2 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-1f7f9732f2 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-1f7f9732f2 .valign-top { vertical-align: top; }
#> #tabular-1f7f9732f2 .valign-middle { vertical-align: middle; }
#> #tabular-1f7f9732f2 .valign-bottom { vertical-align: bottom; }
#> #tabular-1f7f9732f2 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-1f7f9732f2 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-1f7f9732f2 .tabular-page-break-row { display: none; }
#> #tabular-1f7f9732f2 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-1f7f9732f2 .tabular-page-header, #tabular-1f7f9732f2 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-1f7f9732f2 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-1f7f9732f2 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-1f7f9732f2 .tabular-page-header-left, #tabular-1f7f9732f2 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-1f7f9732f2 .tabular-page-header-center, #tabular-1f7f9732f2 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-1f7f9732f2 .tabular-page-header-right, #tabular-1f7f9732f2 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-1f7f9732f2 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-1f7f9732f2 .tabular-table tr { page-break-inside: avoid; } #tabular-1f7f9732f2 .tabular-page-header, #tabular-1f7f9732f2 .tabular-page-footer { display: none; } #tabular-1f7f9732f2 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-1f7f9732f2 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-1f7f9732f2 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-1f7f9732f2" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.1</h1>
#> <h1 class="tabular-title">Adverse Events by SOC and Preferred Term</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
#> <colgroup>
#> <col style="width:2.500000in"/>
#> <col/>
#> <col/>
#> <col/>
#> <col/>
#> <col/>
#> </colgroup>
#> <thead>
#> <tr><th>SOC / Preferred Term</th><th>soc_n</th><th class="text-center">Placebo<br/>N=86</th><th class="text-center">Drug 50<br/>N=96</th><th class="text-center">Drug 100<br/>N=72</th><th class="text-center">Total<br/>N=254</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>TOTAL SUBJECTS WITH AN EVENT</td><td>199</td><td class="text-right">52 (60.5)</td><td class="text-right">81 (84.4)</td><td class="text-right">66 (91.7)</td><td class="text-right">199 (78.3)</td></tr>
#> <tr><td>SKIN AND SUBCUTANEOUS TISSUE DISORDERS</td><td>90</td><td class="text-right">19 (22.1)</td><td class="text-right">36 (37.5)</td><td class="text-right">35 (48.6)</td><td class="text-right"> 90 (35.4)</td></tr>
#> <tr><td>GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS</td><td>81</td><td class="text-right">15 (17.4)</td><td class="text-right">36 (37.5)</td><td class="text-right">30 (41.7)</td><td class="text-right"> 81 (31.9)</td></tr>
#> <tr><td>GASTROINTESTINAL DISORDERS</td><td>42</td><td class="text-right">13 (15.1)</td><td class="text-right">12 (12.5)</td><td class="text-right">17 (23.6)</td><td class="text-right"> 42 (16.5)</td></tr>
#> <tr><td>NERVOUS SYSTEM DISORDERS</td><td>41</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right">18 (18.8)</td><td class="text-right">17 (23.6)</td><td class="text-right"> 41 (16.1)</td></tr>
#> <tr><td>CARDIAC DISORDERS</td><td>33</td><td class="text-right"> 7 ( 8.1)</td><td class="text-right">12 (12.5)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 33 (13.0)</td></tr>
#> <tr><td>INFECTIONS AND INFESTATIONS</td><td>29</td><td class="text-right">12 (14.0)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right">11 (15.3)</td><td class="text-right"> 29 (11.4)</td></tr>
#> <tr><td>RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS</td><td>22</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 8 ( 8.3)</td><td class="text-right"> 9 (12.5)</td><td class="text-right"> 22 ( 8.7)</td></tr>
#> <tr><td>PSYCHIATRIC DISORDERS</td><td>19</td><td class="text-right"> 7 ( 8.1)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 19 ( 7.5)</td></tr>
#> <tr><td>MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS</td><td>14</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td>INVESTIGATIONS</td><td>12</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PRURITUS</td><td>90</td><td class="text-right"> 8 ( 9.3)</td><td class="text-right">21 (21.9)</td><td class="text-right">25 (34.7)</td><td class="text-right"> 54 (21.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE PRURITUS</td><td>81</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right">23 (24.0)</td><td class="text-right">21 (29.2)</td><td class="text-right"> 50 (19.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ERYTHEMA</td><td>90</td><td class="text-right"> 8 ( 9.3)</td><td class="text-right">14 (14.6)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 36 (14.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE ERYTHEMA</td><td>81</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right">13 (13.5)</td><td class="text-right">14 (19.4)</td><td class="text-right"> 30 (11.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">RASH</td><td>90</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right">13 (13.5)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 26 (10.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE DERMATITIS</td><td>81</td><td class="text-right"> 5 ( 5.8)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 7 ( 9.7)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE IRRITATION</td><td>81</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right"> 9 (12.5)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIZZINESS</td><td>41</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 9 ( 9.4)</td><td class="text-right">10 (13.9)</td><td class="text-right"> 21 ( 8.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DIARRHOEA</td><td>42</td><td class="text-right"> 9 (10.5)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 17 ( 6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SINUS BRADYCARDIA</td><td>33</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 7 ( 7.3)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 17 ( 6.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HYPERHIDROSIS</td><td>90</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 8 (11.1)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SKIN IRRITATION</td><td>90</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 6 ( 6.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 14 ( 5.5)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VOMITING</td><td>42</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 13 ( 5.1)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NAUSEA</td><td>42</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASOPHARYNGITIS</td><td>29</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 4 ( 4.2)</td><td class="text-right"> 6 ( 8.3)</td><td class="text-right"> 12 ( 4.7)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">APPLICATION SITE VESICLES</td><td>81</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">HEADACHE</td><td>41</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">COUGH</td><td>22</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 5 ( 6.9)</td><td class="text-right"> 11 ( 4.3)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MYOCARDIAL INFARCTION</td><td>33</td><td class="text-right"> 4 ( 4.7)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 4 ( 5.6)</td><td class="text-right"> 10 ( 3.9)</td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">UPPER RESPIRATORY TRACT INFECTION</td><td>29</td><td class="text-right"> 6 ( 7.0)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right"> 10 ( 3.9)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SYNCOPE</td><td>41</td><td class="text-right"> 0       </td><td class="text-right"> 5 ( 5.2)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  7 ( 2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">NASAL CONGESTION</td><td>22</td><td class="text-right"> 3 ( 3.5)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">  7 ( 2.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SOMNOLENCE</td><td>41</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  6 ( 2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CONFUSIONAL STATE</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  6 ( 2.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ABDOMINAL PAIN</td><td>42</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ATRIAL FIBRILLATION</td><td>33</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">AGITATION</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 0       </td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BACK PAIN</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 3 ( 4.2)</td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM ST SEGMENT DEPRESSION</td><td>12</td><td class="text-right"> 4 ( 4.7)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 0       </td><td class="text-right">  5 ( 2.0)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SALIVARY HYPERSECRETION</td><td>42</td><td class="text-right"> 0       </td><td class="text-right"> 0       </td><td class="text-right"> 4 ( 5.6)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INSOMNIA</td><td>19</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRALGIA</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE INVERSION</td><td>12</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  4 ( 1.6)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">TRANSIENT ISCHAEMIC ATTACK</td><td>41</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SUPRAVENTRICULAR EXTRASYSTOLES</td><td>33</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">VENTRICULAR EXTRASYSTOLES</td><td>33</td><td class="text-right"> 0       </td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">INFLUENZA</td><td>29</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">URINARY TRACT INFECTION</td><td>29</td><td class="text-right"> 2 ( 2.3)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DYSPNOEA</td><td>22</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">EPISTAXIS</td><td>22</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 2 ( 2.8)</td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ANXIETY</td><td>19</td><td class="text-right"> 0       </td><td class="text-right"> 3 ( 3.1)</td><td class="text-right"> 0       </td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">SHOULDER PAIN</td><td>14</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 2 ( 2.1)</td><td class="text-right"> 0       </td><td class="text-right">  3 ( 1.2)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">CYSTITIS</td><td>29</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">PHARYNGOLARYNGEAL PAIN</td><td>22</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">DELUSION</td><td>19</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">MUSCLE SPASMS</td><td>14</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">BLOOD GLUCOSE INCREASED</td><td>12</td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ELECTROCARDIOGRAM T WAVE AMPLITUDE DECREASED</td><td>12</td><td class="text-right"> 1 ( 1.2)</td><td class="text-right"> 1 ( 1.0)</td><td class="text-right"> 0       </td><td class="text-right">  2 ( 0.8)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em);">ARTHRITIS</td><td>14</td><td class="text-right"> 0       </td><td class="text-right"> 0       </td><td class="text-right"> 1 ( 1.4)</td><td class="text-right">  1 ( 0.4)</td></tr>
#> <tr><td style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">BIOPSY</td><td style="border-bottom: 0.5pt solid #212529;">12</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 0       </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 0       </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 1 ( 1.4)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">  1 ( 0.4)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# ---- Example 3: Format string + na_text for clean numeric display ----
#
# `eff_estimates` ships four competing efficacy models with
# pre-computed numeric estimates, 95% CI bounds (NA on the MMRM
# row), and a nominal p-value. `format =` pins the printed
# precision; `na_text` renders the missing CI bounds as a dash
# rather than a literal "NA". `valign = "top"` keeps the multi-
# line cell text aligned to the top.
tabular(eff_estimates, titles = "Treatment-effect estimates by model") |>
  cols(
    model    = col_spec(usage = "group",  label = "Model",   valign = "top"),
    estimate = col_spec(label = "Estimate", align = "decimal", format = "%.2f"),
    lower_ci = col_spec(
      label   = "Lower\n95% CI",
      align   = "decimal",
      format  = "%.2f",
      na_text = "--"
    ),
    upper_ci = col_spec(
      label   = "Upper\n95% CI",
      align   = "decimal",
      format  = "%.2f",
      na_text = "--"
    ),
    p_value  = col_spec(
      label   = "p-value",
      align   = "decimal",
      format  = "%.4f"
    )
  )
#> <style>
#> #tabular-8f586b16e5 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-8f586b16e5 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-8f586b16e5 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-8f586b16e5 .tabular-pad { margin: 0; }
#> #tabular-8f586b16e5 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-8f586b16e5 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-8f586b16e5 .tabular-table th, #tabular-8f586b16e5 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-8f586b16e5 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-8f586b16e5 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-8f586b16e5 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-8f586b16e5 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-8f586b16e5 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-8f586b16e5 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-8f586b16e5 .tabular-table tbody tr td { border-top: none; }
#> #tabular-8f586b16e5 .tabular-band { text-align: center; }
#> #tabular-8f586b16e5 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-8f586b16e5 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-8f586b16e5 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-8f586b16e5 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-8f586b16e5 .text-left { text-align: left; }
#> #tabular-8f586b16e5 .text-center { text-align: center; }
#> #tabular-8f586b16e5 .text-right { text-align: right; }
#> #tabular-8f586b16e5 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-8f586b16e5 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-8f586b16e5 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-8f586b16e5 .valign-top { vertical-align: top; }
#> #tabular-8f586b16e5 .valign-middle { vertical-align: middle; }
#> #tabular-8f586b16e5 .valign-bottom { vertical-align: bottom; }
#> #tabular-8f586b16e5 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-8f586b16e5 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-8f586b16e5 .tabular-page-break-row { display: none; }
#> #tabular-8f586b16e5 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-8f586b16e5 .tabular-page-header, #tabular-8f586b16e5 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-8f586b16e5 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-8f586b16e5 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-8f586b16e5 .tabular-page-header-left, #tabular-8f586b16e5 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-8f586b16e5 .tabular-page-header-center, #tabular-8f586b16e5 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-8f586b16e5 .tabular-page-header-right, #tabular-8f586b16e5 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-8f586b16e5 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-8f586b16e5 .tabular-table tr { page-break-inside: avoid; } #tabular-8f586b16e5 .tabular-page-header, #tabular-8f586b16e5 .tabular-page-footer { display: none; } #tabular-8f586b16e5 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-8f586b16e5 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-8f586b16e5 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-8f586b16e5" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Treatment-effect estimates by model</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
#> <thead>
#> <tr><th class="text-center">Estimate</th><th class="text-center">Lower<br/>95% CI</th><th class="text-center">Upper<br/>95% CI</th><th class="text-center">p-value</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="4"><strong>ANCOVA</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">-2.31</td><td class="text-right">-3.42</td><td class="text-right">-1.20</td><td class="text-right">0.0042</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>MMRM</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);">-2.45</td><td class="text-right">--   </td><td class="text-right">--   </td><td class="text-right">0.0061</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Cox PH</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em);"> 0.81</td><td class="text-right"> 0.68</td><td class="text-right"> 0.97</td><td class="text-right">0.0087</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Bootstrap (1000 reps)</strong></td></tr>
#> <tr><td class="text-right" style="padding-left: calc(.6rem + 1.2em); border-bottom: 0.5pt solid #212529;">-2.29</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">-3.50</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">-1.10</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">0.0050</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# ---- Example 4: Per-column width + halign override for vitals ----
#
# `width` accepts a numeric (inches), a CSS-style string ("1.5in",
# "20%"), or `"auto"`. Centering the visit column under a wider
# group-column setup demonstrates the alignment cascade —
# col_spec@align beats the engine default but yields to a more
# specific style() rule downstream.
n <- stats::setNames(saf_n$n, saf_n$arm_short)
tabular(
  saf_vital,
  titles = "Vital Signs at Baseline and End of Treatment"
) |>
  cols(
    paramcd    = col_spec(visible = FALSE),
    param      = col_spec(usage = "group", label = "Parameter",
                          width = "1.6in"),
    visit      = col_spec(usage = "group", label = "Visit",
                          width = "1.2in", align = "center"),
    stat_label = col_spec(label = "Statistic", width = "1.0in"),
    placebo    = col_spec(
      label = sprintf("Placebo\nN=%d", n["placebo"]),
      align = "decimal", width = "0.9in"
    ),
    drug_50    = col_spec(
      label = sprintf("Drug 50\nN=%d", n["drug_50"]),
      align = "decimal", width = "0.9in"
    ),
    drug_100   = col_spec(
      label = sprintf("Drug 100\nN=%d", n["drug_100"]),
      align = "decimal", width = "0.9in"
    )
  )
#> <style>
#> #tabular-5f4566be52 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-5f4566be52 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-5f4566be52 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-5f4566be52 .tabular-pad { margin: 0; }
#> #tabular-5f4566be52 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-5f4566be52 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-5f4566be52 .tabular-table th, #tabular-5f4566be52 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-5f4566be52 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-5f4566be52 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-5f4566be52 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-5f4566be52 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-5f4566be52 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-5f4566be52 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-5f4566be52 .tabular-table tbody tr td { border-top: none; }
#> #tabular-5f4566be52 .tabular-band { text-align: center; }
#> #tabular-5f4566be52 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-5f4566be52 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-5f4566be52 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-5f4566be52 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-5f4566be52 .text-left { text-align: left; }
#> #tabular-5f4566be52 .text-center { text-align: center; }
#> #tabular-5f4566be52 .text-right { text-align: right; }
#> #tabular-5f4566be52 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-5f4566be52 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-5f4566be52 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-5f4566be52 .valign-top { vertical-align: top; }
#> #tabular-5f4566be52 .valign-middle { vertical-align: middle; }
#> #tabular-5f4566be52 .valign-bottom { vertical-align: bottom; }
#> #tabular-5f4566be52 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-5f4566be52 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-5f4566be52 .tabular-page-break-row { display: none; }
#> #tabular-5f4566be52 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-5f4566be52 .tabular-page-header, #tabular-5f4566be52 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-5f4566be52 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-5f4566be52 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-5f4566be52 .tabular-page-header-left, #tabular-5f4566be52 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-5f4566be52 .tabular-page-header-center, #tabular-5f4566be52 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-5f4566be52 .tabular-page-header-right, #tabular-5f4566be52 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-5f4566be52 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-5f4566be52 .tabular-table tr { page-break-inside: avoid; } #tabular-5f4566be52 .tabular-page-header, #tabular-5f4566be52 .tabular-page-footer { display: none; } #tabular-5f4566be52 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-5f4566be52 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-5f4566be52 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-5f4566be52" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Vital Signs at Baseline and End of Treatment</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
#> <colgroup>
#> <col style="width:1.0in"/>
#> <col style="width:0.9in"/>
#> <col style="width:0.9in"/>
#> <col style="width:0.9in"/>
#> </colgroup>
#> <thead>
#> <tr><th>Statistic</th><th class="text-center">Placebo<br/>N=86</th><th class="text-center">Drug 50<br/>N=96</th><th class="text-center">Drug 100<br/>N=72</th></tr>
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
#> <tr><td>Min, Max</td><td class="text-right"> 51  , 106  </td><td class="text-right"> 50  , 94   </td><td class="text-right"> 50  , 98   </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="4"></td></tr>
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
#> <tr><td>Median</td><td class="text-right"> 36.8       </td><td class="text-right"> 36.7       </td><td class="text-right"> 36.7       </td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Min, Max</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 35  , 37   </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 35  , 38   </td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 36  , 37   </td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# ---- Example 5: Non-collapsing `id` stub for a panelled table ----
#
# `usage = "id"` marks `stat_label` ("n", "Mean", "SD", ...) as a
# row identifier: like `display` it shows on every row, but it also
# joins the stub, so it repeats on each horizontal panel created by
# `paginate(panels = 2)`. On HTML / Markdown (no page width) the
# panels collapse into one scrollable table with a "Panel 1 / Panel
# 2" header note; on RTF / Word each panel is its own page with the
# `variable` + `stat_label` stub repeated.
n <- stats::setNames(saf_n$n, saf_n$arm_short)
tabular(
  saf_demo,
  titles = c("Table 14.1.1", "Demographics", "Safety Population")
) |>
  cols(
    variable   = col_spec(usage = "group", group_display = "column",
                          label = "Parameter"),
    stat_label = col_spec(usage = "id", label = "Statistic"),
    placebo    = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"]),  align = "decimal"),
    drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"]),  align = "decimal"),
    drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"]), align = "decimal"),
    Total      = col_spec(label = sprintf("Total\nN=%d",    n["Total"]),    align = "decimal")
  ) |>
  paginate(panels = 2)
#> <style>
#> #tabular-72b7062cd5 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-72b7062cd5 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-72b7062cd5 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-72b7062cd5 .tabular-pad { margin: 0; }
#> #tabular-72b7062cd5 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-72b7062cd5 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-72b7062cd5 .tabular-table th, #tabular-72b7062cd5 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-72b7062cd5 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-72b7062cd5 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-72b7062cd5 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-72b7062cd5 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-72b7062cd5 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-72b7062cd5 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-72b7062cd5 .tabular-table tbody tr td { border-top: none; }
#> #tabular-72b7062cd5 .tabular-band { text-align: center; }
#> #tabular-72b7062cd5 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-72b7062cd5 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-72b7062cd5 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-72b7062cd5 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-72b7062cd5 .text-left { text-align: left; }
#> #tabular-72b7062cd5 .text-center { text-align: center; }
#> #tabular-72b7062cd5 .text-right { text-align: right; }
#> #tabular-72b7062cd5 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-72b7062cd5 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-72b7062cd5 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-72b7062cd5 .valign-top { vertical-align: top; }
#> #tabular-72b7062cd5 .valign-middle { vertical-align: middle; }
#> #tabular-72b7062cd5 .valign-bottom { vertical-align: bottom; }
#> #tabular-72b7062cd5 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-72b7062cd5 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-72b7062cd5 .tabular-page-break-row { display: none; }
#> #tabular-72b7062cd5 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-72b7062cd5 .tabular-page-header, #tabular-72b7062cd5 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-72b7062cd5 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-72b7062cd5 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-72b7062cd5 .tabular-page-header-left, #tabular-72b7062cd5 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-72b7062cd5 .tabular-page-header-center, #tabular-72b7062cd5 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-72b7062cd5 .tabular-page-header-right, #tabular-72b7062cd5 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-72b7062cd5 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-72b7062cd5 .tabular-table tr { page-break-inside: avoid; } #tabular-72b7062cd5 .tabular-page-header, #tabular-72b7062cd5 .tabular-page-footer { display: none; } #tabular-72b7062cd5 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-72b7062cd5 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-72b7062cd5 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-72b7062cd5" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.1.1</h1>
#> <h1 class="tabular-title">Demographics</h1>
#> <h1 class="tabular-title">Safety Population</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
#> <thead>
#> <tr><th colspan="2"></th><th colspan="2" class="tabular-band tabular-panel-note">Panel 1</th><th colspan="2" class="tabular-band tabular-panel-note">Panel 2</th></tr>
#> <tr><th>Parameter</th><th>Statistic</th><th class="text-center">Placebo<br/>N=86</th><th class="text-center">Drug 100<br/>N=72</th><th class="text-center">Drug 50<br/>N=96</th><th class="text-center">Total<br/>N=254</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>Age (years)</td><td>n</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 96          </td><td class="text-right">254          </td></tr>
#> <tr><td></td><td>Mean (SD)</td><td class="text-right"> 75.2 ( 8.59)</td><td class="text-right"> 73.8 ( 7.94)</td><td class="text-right"> 76.0 ( 8.11)</td><td class="text-right"> 75.1 ( 8.25)</td></tr>
#> <tr><td></td><td>Median</td><td class="text-right"> 76.0        </td><td class="text-right"> 75.5        </td><td class="text-right"> 78.0        </td><td class="text-right"> 77.0        </td></tr>
#> <tr><td></td><td>Q1, Q3</td><td class="text-right"> 69.2, 81.8  </td><td class="text-right"> 70.5, 79.0  </td><td class="text-right"> 71.0, 82.0  </td><td class="text-right"> 70.0, 81.0  </td></tr>
#> <tr><td></td><td>Min, Max</td><td class="text-right"> 52  , 89    </td><td class="text-right"> 56  , 88    </td><td class="text-right"> 51  , 88    </td><td class="text-right"> 51  , 89    </td></tr>
#> <tr><td>Age Group, n (%)</td><td>18-64</td><td class="text-right"> 14   (16.3 )</td><td class="text-right"> 11   (15.3 )</td><td class="text-right">  8   ( 8.3 )</td><td class="text-right"> 33   (13.0 )</td></tr>
#> <tr><td></td><td>&gt;64</td><td class="text-right"> 72   (83.7 )</td><td class="text-right"> 61   (84.7 )</td><td class="text-right"> 88   (91.7 )</td><td class="text-right">221   (87.0 )</td></tr>
#> <tr><td>Sex, n (%)</td><td>F</td><td class="text-right"> 53   (61.6 )</td><td class="text-right"> 35   (48.6 )</td><td class="text-right"> 55   (57.3 )</td><td class="text-right">143   (56.3 )</td></tr>
#> <tr><td></td><td>M</td><td class="text-right"> 33   (38.4 )</td><td class="text-right"> 37   (51.4 )</td><td class="text-right"> 41   (42.7 )</td><td class="text-right">111   (43.7 )</td></tr>
#> <tr><td>Race, n (%)</td><td>WHITE</td><td class="text-right"> 78   (90.7 )</td><td class="text-right"> 62   (86.1 )</td><td class="text-right"> 90   (93.8 )</td><td class="text-right">230   (90.6 )</td></tr>
#> <tr><td></td><td>BLACK OR AFRICAN AMERICAN</td><td class="text-right">  8   ( 9.3 )</td><td class="text-right">  9   (12.5 )</td><td class="text-right">  6   ( 6.2 )</td><td class="text-right"> 23   ( 9.1 )</td></tr>
#> <tr><td></td><td>ASIAN</td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td></tr>
#> <tr><td></td><td>AMERICAN INDIAN OR ALASKA NATIVE</td><td class="text-right">  0          </td><td class="text-right">  1   ( 1.4 )</td><td class="text-right">  0          </td><td class="text-right">  1   ( 0.4 )</td></tr>
#> <tr><td>Ethnicity, n (%)</td><td>HISPANIC OR LATINO</td><td class="text-right">  3   ( 3.5 )</td><td class="text-right">  3   ( 4.2 )</td><td class="text-right">  6   ( 6.2 )</td><td class="text-right"> 12   ( 4.7 )</td></tr>
#> <tr><td></td><td>NOT HISPANIC OR LATINO</td><td class="text-right"> 83   (96.5 )</td><td class="text-right"> 69   (95.8 )</td><td class="text-right"> 90   (93.8 )</td><td class="text-right">242   (95.3 )</td></tr>
#> <tr><td></td><td>NOT REPORTED</td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td><td class="text-right">  0          </td></tr>
#> <tr><td>Weight (kg)</td><td>n</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 95          </td><td class="text-right">253          </td></tr>
#> <tr><td></td><td>Mean (SD)</td><td class="text-right"> 62.8 (12.77)</td><td class="text-right"> 69.5 (14.35)</td><td class="text-right"> 68.0 (14.50)</td><td class="text-right"> 66.6 (14.13)</td></tr>
#> <tr><td></td><td>Median</td><td class="text-right"> 60.6        </td><td class="text-right"> 69.0        </td><td class="text-right"> 66.7        </td><td class="text-right"> 66.7        </td></tr>
#> <tr><td></td><td>Q1, Q3</td><td class="text-right"> 53.6, 74.2  </td><td class="text-right"> 56.9, 80.3  </td><td class="text-right"> 56.0, 78.2  </td><td class="text-right"> 55.3, 77.1  </td></tr>
#> <tr><td></td><td>Min, Max</td><td class="text-right"> 34  , 86    </td><td class="text-right"> 44  , 108   </td><td class="text-right"> 42  , 106   </td><td class="text-right"> 34  , 108   </td></tr>
#> <tr><td>Height (cm)</td><td>n</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 96          </td><td class="text-right">254          </td></tr>
#> <tr><td></td><td>Mean (SD)</td><td class="text-right">162.6 (11.52)</td><td class="text-right">165.9 (10.28)</td><td class="text-right">163.7 (10.30)</td><td class="text-right">163.9 (10.76)</td></tr>
#> <tr><td></td><td>Median</td><td class="text-right">162.6        </td><td class="text-right">165.1        </td><td class="text-right">162.6        </td><td class="text-right">162.8        </td></tr>
#> <tr><td></td><td>Q1, Q3</td><td class="text-right">154.0, 171.1 </td><td class="text-right">157.5, 172.8 </td><td class="text-right">157.5, 170.2 </td><td class="text-right">156.2, 171.4 </td></tr>
#> <tr><td></td><td>Min, Max</td><td class="text-right">137  , 185   </td><td class="text-right">146  , 190   </td><td class="text-right">136  , 196   </td><td class="text-right">136  , 196   </td></tr>
#> <tr><td>BMI (kg/m^2)</td><td>n</td><td class="text-right"> 86          </td><td class="text-right"> 72          </td><td class="text-right"> 95          </td><td class="text-right">253          </td></tr>
#> <tr><td></td><td>Mean (SD)</td><td class="text-right"> 23.6 ( 3.67)</td><td class="text-right"> 25.2 ( 3.97)</td><td class="text-right"> 25.2 ( 4.40)</td><td class="text-right"> 24.7 ( 4.09)</td></tr>
#> <tr><td></td><td>Median</td><td class="text-right"> 23.4        </td><td class="text-right"> 24.8        </td><td class="text-right"> 24.8        </td><td class="text-right"> 24.2        </td></tr>
#> <tr><td></td><td>Q1, Q3</td><td class="text-right"> 21.2, 25.6  </td><td class="text-right"> 22.7, 27.6  </td><td class="text-right"> 22.3, 28.2  </td><td class="text-right"> 21.9, 27.3  </td></tr>
#> <tr class="tabular-page-break-row" aria-hidden="true"><td colspan="6"></td></tr>
#> <tr><td></td><td>Min, Max</td><td class="text-right"> 15  , 33    </td><td class="text-right"> 14  , 35    </td><td class="text-right"> 15  , 40    </td><td class="text-right"> 14  , 40    </td></tr>
#> <tr><td>BMI Category, n (%)</td><td>Underweight (&lt;18.5)</td><td class="text-right">  3   ( 3.5 )</td><td class="text-right">  1   ( 1.4 )</td><td class="text-right">  4   ( 4.2 )</td><td class="text-right">  8   ( 3.1 )</td></tr>
#> <tr><td></td><td>Normal (18.5-24.9)</td><td class="text-right"> 57   (66.3 )</td><td class="text-right"> 39   (54.2 )</td><td class="text-right"> 46   (47.9 )</td><td class="text-right">142   (55.9 )</td></tr>
#> <tr><td></td><td>Overweight (25-29.9)</td><td class="text-right"> 20   (23.3 )</td><td class="text-right"> 23   (31.9 )</td><td class="text-right"> 32   (33.3 )</td><td class="text-right"> 75   (29.5 )</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;"></td><td style="border-bottom: 0.5pt solid #212529;">Obese (&gt;=30)</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">  6   ( 7.0 )</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;">  9   (12.5 )</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 13   (13.5 )</td><td class="text-right" style="border-bottom: 0.5pt solid #212529;"> 28   (11.0 )</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>
```
