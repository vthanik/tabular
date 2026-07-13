# Per-column display specification

Build a single column's display attributes — label, format, visibility,
width, alignment, NA text, indent. The result feeds
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md),
which stamps the input column name onto the spec from its named-argument
position and attaches it to the parent `tabular_spec`. Row structure
(section headers, repeat suppression, blank spacers) is not a column
attribute — declare it once with
[`group_rows()`](https://vthanik.github.io/tabular/dev/reference/group_rows.md).

## Usage

``` r
col_spec(
  label = NA_character_,
  format = NULL,
  visible = NA,
  width = "auto",
  align = NULL,
  valign = NULL,
  na_text = NA_character_,
  indent = NA
)
```

## Arguments

- label:

  *Display label for the column header.*
  `<character(1)>: default NA_character_`. Embed `\n` for multi-line
  headers (arm name on row 1, BigN denominator on row 2 is the clinical
  convention). `NA_character_` means use the input column name verbatim.

  **Restriction:** Empty string and whitespace-only labels are accepted
  here, unlike
  [`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md)
  band labels which are strict.

  Supports glue-style `{expr}` interpolation: braces are evaluated as R
  code in the calling environment at build time, so a BigN value folds
  inline, `label = "Placebo (N={n['placebo']})"`. Double a brace (`{{`
  or `}}`) for a literal one. An
  [`md()`](https://vthanik.github.io/tabular/dev/reference/md.md) /
  [`html()`](https://vthanik.github.io/tabular/dev/reference/html.md)
  label is passed through without interpolation.

  **Per-column token.** `{.name}` (alias `{.col}`) inside a `{expr}` is
  *deferred* and resolved to the matched column's name when the spec is
  stamped by
  [`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md) /
  [`cols_apply()`](https://vthanik.github.io/tabular/dev/reference/cols_apply.md),
  so one spec can carry a variable-N arm header. See
  [`cols_apply()`](https://vthanik.github.io/tabular/dev/reference/cols_apply.md)
  for the loop-free idiom.

      # Two-line header with arm name and BigN from cdisc_saf_n.
      n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
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

  *Whether the column renders.* `<logical(1)>: default NA`. `FALSE`
  hides the column from output but keeps it in `spec@data` so
  [`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md)
  and
  [`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
  predicates can still reference it. `NA` (default) is the merge "unset"
  sentinel — it resolves to visible at render and, crucially, is
  mergeable: a later
  [`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md)
  call with `visible = TRUE` can **re-show** a column an earlier call
  hid.

  **Interaction:** Hidden columns are the standard pattern for sort-key
  helpers (`row_type`, `n_total`) and for the numeric counts behind
  formatted-text percentage cells.

  **Auto-hide.** The depth column named by a character `indent` and
  every column named by
  [`subgroup(by = ...)`](https://vthanik.github.io/tabular/dev/reference/subgroup.md)
  or referenced via a `{col}` placeholder in the subgroup banner
  template are flipped to `visible = FALSE` automatically at engine time
  — restating it here is redundant.

  **Break-only grouping key.** To drop a blank line wherever a hidden
  marker column changes (e.g. continuous stats vs. categorical groups
  inside one characteristic), set `visible = FALSE` here AND name the
  column in
  [`group_rows()`](https://vthanik.github.io/tabular/dev/reference/group_rows.md)`(by = )`.
  A hidden grouping key is break-only: it renders nothing and
  contributes only its group transitions (the blank spacer and the
  decimal-section reset).

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

  **Merge sentinel.** For the field-merge across repeated
  [`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md) /
  [`cols_apply()`](https://vthanik.github.io/tabular/dev/reference/cols_apply.md)
  calls, `"auto"` is treated as the default: a later call carrying
  `width = "auto"` leaves a previously pinned width intact, and only an
  explicit non-`"auto"` width overrides.

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
  decimal mark falls on a single column-wide anchor. Pad counts follow
  the active preset's `decimal_metrics` knob (see
  [`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)):
  the default `"afm"` measures real glyph widths so the anchor holds in
  proportional fonts as well as monospace.

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

- indent:

  *Cosmetic indent depth on this column.*
  `<numeric(1) | character(1) | NA>: default NA`. Two modes by type:

  - **A non-negative whole number** — every body row of this column is
    indented that many levels (each level is `preset@indent_size`
    space-widths). `indent = 1` is the common "nudge this stub in one
    level" case; `indent = 0` is a real value that flattens children
    under a `"section"` header.

  - **A column name (character)** — per-row depth: the engine reads
    `spec@data[[indent]]`, coerces each row to a non-negative integer,
    and prefixes that row's text + AST with
    `strrep(" ", preset@indent_size * depth)`. The referenced depth
    column is auto-hidden — no need to set `visible = FALSE` on it.

  `NA` (default) means no indent. Backends with native padding-left
  (HTML / LaTeX / RTF / DOCX / PDF) emit the depth as cell padding so
  wrapped continuation lines align with the indented baseline; Markdown
  carries the literal space-prefix. Synthesised group-header rows are
  never indented — they are the parent at depth 0.

  **Interaction:** an explicit `indent` on the host column of a
  [`group_rows()`](https://vthanik.github.io/tabular/dev/reference/group_rows.md)`(display = "section")`
  section **suppresses** that section's automatic one-level child indent
  (you take control of the depth) — so a stub under a section needs no
  `indent` at all, and adding `indent = 1` there yields a single, not
  double, indent.

  Per-row SOC / PT pattern (the bundled `cdisc_saf_aesocpt` ships the
  canonical depth column, so no upstream construction is needed):

      cols(
        label    = col_spec(label = "Category", indent = "indent_level"),
        soc      = col_spec(visible = FALSE),
        row_type = col_spec(visible = FALSE)
      )

  Depth-column values `c(0L, 1L, 2L, …)` produce `0`, `1`, `2`, …
  levels. Negative values clamp to 0 (warn); fractional numerics floor
  (warn); NA → 0 (silent). Works in flat listings too — a character
  `indent` does not require any
  [`group_rows()`](https://vthanik.github.io/tabular/dev/reference/group_rows.md)
  keys.

## Value

*A `col_spec` S7 object.* Pass it to
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md)
keyed by the input column name; the constructor itself does not stamp a
name.

## Details

**Constructor-only.** `col_spec()` does not know which input column it
belongs to until
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md)
stamps the name. Build reusable specs as ordinary R objects (e.g.
`arm_col <- col_spec(align = "decimal")`) and apply them to multiple
inputs without restating the name.

**Merge semantics across repeated
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md)
calls.** When
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md) is
called twice for the same column, the engine merges field-by-field: any
field set to a non-default value on the new spec overrides; a field left
at its "unset" sentinel (`NA` / `NULL` / `"auto"`) leaves the existing
value intact. Because every mergeable field has a genuine unset
sentinel, a later call can also *restore* a default — e.g.
`visible = TRUE` re-shows a column an earlier call hid. Build a column's
spec in stages without re-stating earlier attributes.

**Validation timing.** Argument shapes are validated eagerly — a
malformed `sprintf` template is probed at construction
(`sprintf(format, 0)`) and fails fast at write time, not at render time.

## See also

**Companion verb:**
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md)
attaches `col_spec` entries to a `tabular_spec` keyed by input column
name.

**Row structure:**
[`group_rows()`](https://vthanik.github.io/tabular/dev/reference/group_rows.md)
declares the grouping keys and section rendering at table level.

**Sibling build verbs:**
[`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md),
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md),
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md).

**Inline label formatting:**
[`md()`](https://vthanik.github.io/tabular/dev/reference/md.md),
[`html()`](https://vthanik.github.io/tabular/dev/reference/html.md).

## Examples

``` r
# ---- Example 1: Demographics with every col_spec field exercised ----
#
# Demographics table where every `col_spec` field is in play:
# the row-label columns are pinned to a fixed width and aligned
# left, the four arm columns embed BigN inline in the header,
# decimal-align numeric content, and render `NA` cells as "-".
n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)

tabular(
  cdisc_saf_demo,
  titles = c(
    "Table 14.1.1",
    "Demographics and Baseline Characteristics",
    "Safety Population"
  ),
  footnotes = "Percentages based on N per treatment group."
) |>
  cols(
    variable   = col_spec(
      label = "Parameter",
      width = 2.0, align = "left"
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
  group_rows(by = "variable") |>
  sort_rows(by = c("variable", "stat_label"))

#tabular-ba6debc427 { font-family: "Courier New", Courier, "Nimbus Mono PS", "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-ba6debc427 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-ba6debc427 p { line-height: inherit; }
#tabular-ba6debc427 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-ba6debc427 .tabular-caption { margin: 0; padding: 0; }
#tabular-ba6debc427 .tabular-pad { margin: 0; line-height: 1; }
#tabular-ba6debc427 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-ba6debc427 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-ba6debc427 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-ba6debc427 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-ba6debc427 .tabular-table th, #tabular-ba6debc427 .tabular-table td { padding: .18rem .6rem; }
#tabular-ba6debc427 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-ba6debc427 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-ba6debc427 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-ba6debc427 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-ba6debc427 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-ba6debc427 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-ba6debc427 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-ba6debc427 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-ba6debc427 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-ba6debc427 .tabular-table tbody tr td { border-top: none; }
#tabular-ba6debc427 .tabular-band { text-align: center; }
#tabular-ba6debc427 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-ba6debc427 .tabular-subgroup-label { font-weight: 600; }
#tabular-ba6debc427 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-ba6debc427 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-ba6debc427 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-ba6debc427 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-ba6debc427 .text-left { text-align: left; }
#tabular-ba6debc427 .text-center { text-align: center; }
#tabular-ba6debc427 .text-right { text-align: right; }
#tabular-ba6debc427 .tabular-table thead th.text-left { text-align: left; }
#tabular-ba6debc427 .tabular-table thead th.text-center { text-align: center; }
#tabular-ba6debc427 .tabular-table thead th.text-right { text-align: right; }
#tabular-ba6debc427 .tabular-table td.text-left { text-align: left; }
#tabular-ba6debc427 .tabular-table td.text-center { text-align: center; }
#tabular-ba6debc427 .tabular-table td.text-right { text-align: right; }
#tabular-ba6debc427 .valign-top { vertical-align: top; }
#tabular-ba6debc427 .valign-middle { vertical-align: middle; }
#tabular-ba6debc427 .valign-bottom { vertical-align: bottom; }
#tabular-ba6debc427 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-ba6debc427 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-ba6debc427 .tabular-page-break-row { display: none; }
#tabular-ba6debc427 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-ba6debc427 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-ba6debc427 .tabular-page-header, #tabular-ba6debc427 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-ba6debc427 .tabular-page-header { margin-bottom: 1rem; }
#tabular-ba6debc427 .tabular-page-footer { margin-top: 1rem; }
#tabular-ba6debc427 .tabular-page-header-left, #tabular-ba6debc427 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-ba6debc427 .tabular-page-header-center, #tabular-ba6debc427 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-ba6debc427 .tabular-page-header-right, #tabular-ba6debc427 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-ba6debc427 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-ba6debc427 .tabular-table tr { page-break-inside: avoid; } #tabular-ba6debc427 .tabular-page-header, #tabular-ba6debc427 .tabular-page-footer { display: none; } #tabular-ba6debc427 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-ba6debc427 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-ba6debc427 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.1.1
Demographics and Baseline Characteristics
Safety Population
 



Statistic
```
