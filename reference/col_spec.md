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
  na_text = NA_character_,
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

  Supports glue-style `{expr}` interpolation: braces are evaluated as R
  code in the calling environment at build time, so a BigN value folds
  inline, `label = "Placebo (N={n['placebo']})"`. Double a brace (`{{`
  or `}}`) for a literal one. An
  [`md()`](https://vthanik.github.io/tabular/reference/md.md) /
  [`html()`](https://vthanik.github.io/tabular/reference/html.md) label
  is passed through without interpolation.

      # Two-line header with arm name and BigN from saf_n.
      n <- stats::setNames(saf_n$n, saf_n$arm_short)
      col_spec(
        label = "Placebo\nN={n['placebo']}",
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

  *Text substituted for `NA` cells.* `<character(1) | NA>: default NA`.
  Substituted BEFORE the `format` step, so `format` does not need to
  anticipate `NA`. `NA` (default) inherits the preset's table-wide
  `na_text`; any string overrides it for this column, including `""` to
  force blank cells even when the preset uses a non-empty token.

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
    "Safety Population"
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
      label = "Placebo\nN={n['placebo']}",
      align = "decimal", na_text = "-"
    ),
    drug_50  = col_spec(
      label = "Drug 50\nN={n['drug_50']}",
      align = "decimal", na_text = "-"
    ),
    drug_100 = col_spec(
      label = "Drug 100\nN={n['drug_100']}",
      align = "decimal", na_text = "-"
    ),
    Total    = col_spec(
      label = "Total\nN={n['Total']}",
      align = "decimal", na_text = "-"
    )
  ) |>
  sort_rows(by = c("variable", "stat_label"))

#tabular-2fc874e2f0 { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-2fc874e2f0 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-2fc874e2f0 p { line-height: inherit; }
#tabular-2fc874e2f0 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-2fc874e2f0 .tabular-caption { margin: 0; padding: 0; }
#tabular-2fc874e2f0 .tabular-pad { margin: 0; line-height: 1; }
#tabular-2fc874e2f0 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-2fc874e2f0 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-2fc874e2f0 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-2fc874e2f0 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-2fc874e2f0 .tabular-table th, #tabular-2fc874e2f0 .tabular-table td { padding: .18rem .6rem; }
#tabular-2fc874e2f0 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-2fc874e2f0 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-2fc874e2f0 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-2fc874e2f0 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-2fc874e2f0 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#tabular-2fc874e2f0 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-2fc874e2f0 .tabular-table tbody tr td { border-top: none; }
#tabular-2fc874e2f0 .tabular-band { text-align: center; }
#tabular-2fc874e2f0 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#tabular-2fc874e2f0 .tabular-subgroup-label { font-weight: 600; }
#tabular-2fc874e2f0 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-2fc874e2f0 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#tabular-2fc874e2f0 .text-left { text-align: left; }
#tabular-2fc874e2f0 .text-center { text-align: center; }
#tabular-2fc874e2f0 .text-right { text-align: right; }
#tabular-2fc874e2f0 .tabular-table thead th.text-left { text-align: left; }
#tabular-2fc874e2f0 .tabular-table thead th.text-center { text-align: center; }
#tabular-2fc874e2f0 .tabular-table thead th.text-right { text-align: right; }
#tabular-2fc874e2f0 .valign-top { vertical-align: top; }
#tabular-2fc874e2f0 .valign-middle { vertical-align: middle; }
#tabular-2fc874e2f0 .valign-bottom { vertical-align: bottom; }
#tabular-2fc874e2f0 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-2fc874e2f0 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-2fc874e2f0 .tabular-page-break-row { display: none; }
#tabular-2fc874e2f0 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-2fc874e2f0 .tabular-page-header, #tabular-2fc874e2f0 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-2fc874e2f0 .tabular-page-header { margin-bottom: 1rem; }
#tabular-2fc874e2f0 .tabular-page-footer { margin-top: 1rem; }
#tabular-2fc874e2f0 .tabular-page-header-left, #tabular-2fc874e2f0 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-2fc874e2f0 .tabular-page-header-center, #tabular-2fc874e2f0 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-2fc874e2f0 .tabular-page-header-right, #tabular-2fc874e2f0 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-2fc874e2f0 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-2fc874e2f0 .tabular-table tr { page-break-inside: avoid; } #tabular-2fc874e2f0 .tabular-page-header, #tabular-2fc874e2f0 .tabular-page-footer { display: none; } #tabular-2fc874e2f0 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-2fc874e2f0 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-2fc874e2f0 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.1.1
Demographics and Baseline Characteristics
Safety Population
 



Statistic
```
