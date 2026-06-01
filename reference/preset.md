# Override the render preset on a spec

Attach a `preset_spec` to a `tabular_spec`, carrying page-geometry knobs
(paper, orientation, margins, body font_size + family, h-rule policy,
decimal metric, typography defaults). The engine consults the per-spec
preset first when computing the per-page row budget, decimal-aligned
column widths, and the chrome that the backend renders around the body
grid.

## Usage

``` r
preset(.spec, ..., .template = NULL, .style = NULL, .reset = FALSE)
```

## Arguments

- .spec:

  *The `tabular_spec` to attach the preset to.*
  `<tabular_spec>: required`. Dot-prefixed so R's partial argument
  matching cannot accidentally bind a knob name in `...` to the spec
  slot.

- ...:

  *Named preset knobs.* Any subset of the 13 knobs the `preset_spec`
  class carries. Knob values are validated against the class's enum /
  length / type rules; bad values raise `tabular_error_input`. Unknown
  knob names raise `tabular_error_input` with the recognised set listed.

  Recognised knobs:

  - **`font_size`** — body point size. `<numeric(1)>`.

  - **`font_family`** — body font family. `<character | character(1)>`.
    Default `"mono"`. Three accepted shapes:

    1.  **Generic family** — `"mono"` (default), `"serif"`, `"sans"`
        (CSS aliases `"monospace"` / `"sans-serif"` also recognised).
        The resolver expands to a per-backend chain that leads with the
        Linux-installed **Liberation** face (Posit Workbench / Domino /
        Citrix / RStudio Server), then the Microsoft Office face
        (Courier New / Times New Roman / Arial) for desktop Win / Mac
        consumers, then TeX Gyre for LaTeX compile, then the CSS generic
        for HTML. Liberation Mono / Serif / Sans are metric-compatible
        with Courier New / TNR / Arial, so layout, line breaks, and
        decimal alignment hold across every render context. The mono
        default matches the dominant submission-TFL convention where
        deterministic glyph widths drive `n (%)` cell alignment.

    2.  **Named alias** — `"Times"`, `"Times New Roman"`, `"Arial"`,
        `"Helvetica"`, `"Courier"`, `"Courier New"`. These
        PostScript-era names alias to the appropriate generic family
        (Times -\> serif, Arial / Helvetica -\> sans, Courier -\> mono)
        and emit the same expanded chain. Honours the user's intent ("I
        want Times-like rendering") on every OS instead of hard-erroring
        on a Linux server with no TNR installed.

    3.  **Named font** — `"Inter"`, `"JetBrains Mono"`,
        `"Source Serif Pro"`, sponsor-specific face, etc. Emitted
        verbatim with no fallback fabricated. The consuming app
        (browser, xelatex, Word, LibreOffice) resolves the name against
        its own font matcher. RTF and DOCX fall back to the consuming
        app's substitution table when the name is missing; xelatex
        hard-errors at compile time; HTML browsers fall through to the
        browser's default font (not necessarily class-matched).

    4.  **Explicit stack** — `c("Inter", "Helvetica", "sans")`. User
        owns the chain. Returned verbatim — alias lookup is
        **bypassed**, so `c("Times", "Times")` honours the exact name
        with no chain expansion (escape hatch for users who genuinely
        want exact-name semantics).

    **Note:** Adobe Source Pro is no longer the default lead. Source Pro
    is not pre-installed on production Linux servers, so leading with it
    walks through 2-3 missing names before resolving. Users who
    installed Source Pro can opt in via the explicit-stack form
    (`c("Source Serif Pro", "serif")`).

    **What you see in Word's font dropdown vs. what renders.** When you
    open a tabular-generated `.rtf` in Word on macOS or Windows, the
    font dropdown displays the file's *requested* face —
    `"Liberation Mono"` by default (the Linux-server-installed face).
    The rendered text on screen is whatever Word's `\\*\\falt`
    substitution resolved to — typically Courier New on macOS / Windows.
    This is correct: Liberation Mono and Courier New are
    metric-compatible by design, so the rendered layout (line breaks,
    decimal alignment, page breaks) is identical regardless of which
    face Word actually used to render. The same `\\*\\falt` substitution
    model applies to serif (Liberation Serif -\> Times New Roman) and
    sans (Liberation Sans -\> Arial).

    **How to force Office names as the primary.** If reviewers will be
    confused by seeing `"Liberation Mono"` in the Word font dropdown
    (cosmetic concern; doesn't affect rendering), pass an explicit
    length\>1 stack with the Office name first. The resolver returns the
    vector verbatim — no alias lookup, no chain expansion — so the RTF
    file then names the Office face as primary and your chosen alternate
    as `\\*\\falt`:

        preset(font_family = c("Courier New", "Courier", "Liberation Mono"))

    This is the canonical escape hatch for authors who know their
    consumer audience is Mac / Windows Word users and want the dropdown
    to show the Office face directly.

  - **`orientation`** — page orientation. `<character(1)>`. One of
    `"landscape"` (default), `"portrait"`.

  - **`paper_size`** — paper key. `<character(1)>`. One of `"letter"`
    (default), `"a4"`.

  - **`margins`** — page margins in inches. `<numeric(1) | numeric(4)>`.
    Length 1 = all four sides; length 4 = top, right, bottom, left.

  - **`pagehead`**, **`pagefoot`** — per-page header / footer band
    content. `<list>`. Each band is a named list with slots from `left`
    / `center` / `right`; every other slot name is rejected. Each slot
    accepts `NULL` (omit), a character scalar, a character vector
    (multi-row content), or an
    [`inline_ast`](https://vthanik.github.io/tabular/reference/tabular_classes.md).
    Empty [`list()`](https://rdrr.io/r/base/list.html) (the default) -\>
    no band emitted.

    **Single-row form** (scalar slots):

        pagehead = list(
          left   = "Protocol: ABC-123",
          center = "Draft",
          right  = "Page {page} of {npages}"
        )

    **Multi-row form** (vector slots, index-aligned):

        pagehead = list(
          left  = c("Protocol: ABC-123", "Analysis Set: Safety"),
          right = "Page {page} of {npages}"   # scalar -> body-edge row
        )

    **Growth direction.** Vector index 1 = body edge; index N = far from
    body. `pagehead` rows stack **upward** away from the table (the row
    closest to the table is index 1). `pagefoot` rows stack **downward**
    away from the table (the row closest to the table is index 1).
    Shorter slots pad with `""` at the FAR end (high index), so a scalar
    slot naturally lands on the body-edge row.

    **Token vocabulary** — substituted into slot text:

    |                  |         |                                        |
    |------------------|---------|----------------------------------------|
    | Token            | Phase   | Expansion                              |
    | `{page}`         | backend | current page number (field code)       |
    | `{npages}`       | backend | total page count (field code)          |
    | `{program}`      | engine  | calling script's base name             |
    | `{program_path}` | engine  | calling script's full path             |
    | `{datetime}`     | engine  | `DDMMMYYYY HH:MM:SS` UTC (render time) |

    `{program}`, `{program_path}`, and `{datetime}` resolve once per
    render (at
    [`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)
    / [`emit()`](https://vthanik.github.io/tabular/reference/emit.md));
    `{page}` and `{npages}` resolve per page (filled in by Word /
    xelatex / the browser's print engine at view time). The program
    tokens walk a 5-mode detection chain — RStudio API,
    [`source()`](https://rdrr.io/r/base/source.html) frame, Rscript / R
    CMD BATCH commandArgs (covers Domino + Linux batch + CI), knitr
    current_input, fallback `"<interactive>"`.

  - **`rules`** — the single border vocabulary (replaces the old
    `borders` knob). String sugar `"booktabs"` (default, the clinical
    baseline), `"grid"`, `"frame"`, `"none"`; a single
    [`brdr()`](https://vthanik.github.io/tabular/reference/brdr.md)
    broadcast to every active rule; or a named list keyed by the nine
    rule names (`toprule`, `midrule`, `bottomrule`, `spanrule`,
    `rowrule`, `footnoterule`, `leftrule`, `rightrule`, `colrule`) —
    unlisted rules keep their default, and the bare string `"none"`
    drops one. `rules = list(rowrule = brdr())` reproduces the old
    `hlines = "all"`.

    **`bottomrule` vs `footnoterule`.** These are mutually exclusive:
    exactly one rule sits at the data -\> footnote boundary. The default
    is `bottomrule` (the table's bottom edge); `footnoterule` (a
    table-width rule opening the footnote section) is OFF by default. As
    a distinct footnote-section rule, `footnoterule` is drawn only by
    the paginated backends — **RTF, LaTeX / PDF, and DOCX**. The
    **HTML** backend is continuous (non-paginated) and has no separate
    footnote section, so it folds both into one rule: whichever of
    `bottomrule` / `footnoterule` is active becomes the table's bottom
    edge (`bottomrule` wins when both are set). Setting `footnoterule`
    therefore still draws a closing rule on HTML — rendered as the
    `bottomrule`.

  - **`spacing`** — region-keyed blank-line control. A named list keyed
    by `title` / `body` / `subgroup` / `footnote`, each a named numeric
    `c(above = , below = )` (footnote: `above` only). Default is the
    Appendix-I one blank line above and below the title block. Two
    adjoining region-sides that target the same physical gap resolve to
    the MAX (never the sum), so a gap is never accidentally doubled.

  - **`stripe`** — zebra body-row fills. A single colour (applied to
    even rows) or a named `c(odd = , even = )`; `NULL` (default) is off.

  - **`indent_size`** — row-label indent width, in monospace- space
    units. `<integer(1)>`. Default `2L`. Each indent level adds this
    many space-widths of left padding to the cell. `0L` disables the
    indent prefix entirely. Backends with native padding-left semantics
    (HTML / LaTeX / RTF / DOCX / PDF) emit this as cell padding so
    wrapped continuation lines align with the indented baseline;
    Markdown carries the literal space-prefix. Block alignment for the
    title / footnote / header / subgroup / body surfaces is set via the
    `alignment` named-list knob
    (`alignment = list(title_halign = "left", ...)`), not a scalar knob;
    blank-line spacing is set via `spacing` (above).

  - **`na_text`** — global NA fallback. `<character(1)>`.

  - **`decimal_metrics`** — decimal-padding metric. `<character(1)>`.
    Only `"chars"` (default); the engine pads decimal columns by
    character count.

  - **`decimal_markers`** — missing-value tokens recognised by
    `col_spec(align = "decimal")`. `<character>`. Default
    `c("NR", "NE", "NC", "ND", "BLQ")`. A cell whose trimmed value is
    one of these is treated as a non-numeric *marker*: it is shown and
    right-aligned in the column rather than parsed as a number, and a
    marker appearing inside a compound (e.g. the upper bound of
    `14.3 (11.2, NR)`) is preserved and slot-aligned. Excludes `"-"`,
    `"NA"`, and `"INF"`/`"-INF"` by default: `"-"` collides with range
    separators, `"NA"` is handled by `na_text`, and infinities are real
    values. Set to `character(0)` to disable marker handling.

  - **`width_mode`** — table-level column-sizing policy. Mirrors Word's
    Table Layout menu. `<character(1)>`. One of:

    - **`"content"`** *(default)* — Each column auto-sized to
      `max(body, header)`. The table doesn't fill the page. Word's
      "Auto-fit Contents".

    - **`"window"`** — Auto-sized columns expand to share the residual
      page width equally. Pinned and percent columns keep their pins.
      Word's "Auto-fit Window".

    - **`"fixed"`** — Only explicit per-column widths drive the layout.
      Auto-sized columns collapse to a minimum sliver. Word's "Fixed
      Column Width".

    **Interaction:** Pair with `col_spec(width = ...)` pins to drive the
    layout under `"window"` / `"fixed"`. Under `"content"`, pins still
    take priority over auto columns.

    **HTML backend.** `width_mode` drives paper backends (LaTeX / RTF /
    PDF / DOCX) only. HTML is unconditionally responsive — the table
    always fills its parent and columns wrap when the viewport narrows,
    regardless of `width_mode`. Per-column widths (`col_spec(width)`)
    emit verbatim into the HTML colgroup per the gt convention.

  - **`cell_padding`** — cell padding in points, CSS shorthand of length
    1 / 2 / 4 (`all` \| `vertical horizontal` \|
    `top right bottom left`), parsed by the same length rule as
    `margins`. `<numeric>: default c(0, 5.4)` (vertical 0, horizontal
    5.4pt). The single source of truth for both auto column-width
    measurement (left + right) and every backend's cell margin, so
    measured and rendered widths agree.

    **Interaction:** A body per-side padding override
    (`preset(padding = list(body = ...))` or
    `style(.at = cells_body(), padding = ...)`) takes precedence at both
    measurement and render.

    **Note:** DOCX and LaTeX render left / right exactly; RTF
    (`\\trgaph` is one symmetric gap) renders the average, so the total
    width still matches but the two sides look equal.

      # Landscape A4, 8pt body, slim margins for one wide table.
      preset(
        orientation = "landscape",
        paper_size  = "a4",
        font_size   = 8,
        margins     = c(0.75, 0.5, 0.75, 0.5)
      )

- .template:

  *A `preset_spec` to bulk-apply before `...`.*
  `<preset_spec | NULL>: default NULL`. When supplied, every knob the
  template has set away from its factory default feeds in as the base
  layer; user-supplied `...` knobs then merge on top. List-valued knobs
  (`rules`, `fonts`, `colors`, `padding`, `alignment`) shallow-merge per
  key; scalars replace. Use this to layer a house-style `preset_spec`
  onto a chain without restating its knobs.

- .style:

  *A
  [`style_template()`](https://vthanik.github.io/tabular/reference/style_template.md)
  to layer onto the cascade.* `<style_template | NULL>: default NULL`.
  When supplied, every layer the template has accumulated via
  [`style()`](https://vthanik.github.io/tabular/reference/style.md) is
  replayed in order at engine time, after the per-spec
  [`style()`](https://vthanik.github.io/tabular/reference/style.md)
  layers on `.spec`. Use this to attach a sponsor's reusable house style
  to a chain without restating every per-region rule.

- .reset:

  *Discard the spec's existing preset before applying `...`.*
  `<logical(1)>: default FALSE`. When `TRUE`, the spec's prior
  `preset_spec` (if any) is dropped and `...` knobs are merged onto
  fresh
  [`preset_spec()`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  defaults. With no knobs, the per-spec preset is cleared back to NULL
  (the spec falls through to
  [`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md)
  or
  [`preset_spec()`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  defaults).

## Value

*The updated `tabular_spec`.* Continue chaining with
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md), then
render via
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) (or
resolve without I/O via
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)).

## Details

**Per-spec, chained.** `preset()` is the per-spec override — a verb that
returns a modified spec, composable on the pipe alongside
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) /
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md) /
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md).
Use it when a single table needs a one-off geometry (e.g. landscape A4
for one wide efficacy summary inside a portfolio of portrait letter
tables).

**Merge, not replace.** A second `preset()` call merges its scalar knobs
onto the spec's existing preset; unspecified knobs keep their prior
value. The five named-list knobs (`alignment` / `rules` / `fonts` /
`colors` / `padding`) lower to `style_layer` records on `preset@style`
via `.preset_args_to_layers()` (internal) and append in call order;
layer order is precedence within the engine cascade, so a later
`preset()` call's lowered attribute wins over an earlier one at the
cell. Pass `.reset = TRUE` to discard the existing knobs and start from
[`preset_spec()`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
defaults. `preset(.spec, .reset = TRUE)` with no knobs clears the
per-spec override entirely (the spec then falls through to
[`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md)
or
[`preset_spec()`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
defaults at render time).

**Direct
[`preset_spec()`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
calls bypass lowering.** The five named-list knobs are no longer slots
on the `preset_spec` S7 class — they exist only as `preset()` /
[`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md)
arguments that lower into `@style`. `preset_spec(rules = list(...))`
(and analogous direct calls) raise "unused argument". Wrap such calls in
`tabular(...) |> preset(...)` so the lowering helper fires and the
layers land on `@style`.

**Cascade with
[`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md).**
The engine resolves the active preset in this order: (1) the spec's
per-call preset (this verb), (2) the session default attached via
[`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md),
(3)
[`preset_spec()`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
factory defaults. The first non-NULL layer wins; layers are not
field-merged across the cascade.

## See also

**Session-scope partners:**
[`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md),
[`get_preset()`](https://vthanik.github.io/tabular/reference/get_preset.md).

**Render-geometry consumer:**
[`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md)
derives the per-page row budget from the active preset's paper,
orientation, margins, and font size.

**Sibling build verbs:**
[`cols()`](https://vthanik.github.io/tabular/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md),
[`headers()`](https://vthanik.github.io/tabular/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/reference/style.md).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Landscape A4 for a wide efficacy table ----
#
# BOR table where the four-arm column block fits portrait letter
# with a smaller body font, but the sponsor wants A4 landscape at
# 8pt for visual breathing room. `preset()` attaches the geometry;
# `paginate()` reads it later to size the per-page row budget.
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
  sort_rows(by = "stat_label") |>
  preset(
    orientation = "landscape",
    paper_size  = "a4",
    font_size   = 8
  ) |>
  paginate()
#> <style>
#> #tabular-25fa150fab { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-25fa150fab .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-25fa150fab .tabular-title { font-size: 8pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-25fa150fab .tabular-pad { margin: 0; }
#> #tabular-25fa150fab .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-25fa150fab .tabular-table { border-collapse: collapse; font-size: 8pt; margin: 0 auto; }
#> #tabular-25fa150fab .tabular-table th, #tabular-25fa150fab .tabular-table td { padding: .35rem .6rem; }
#> #tabular-25fa150fab .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-25fa150fab .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-25fa150fab .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-25fa150fab .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-25fa150fab .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-25fa150fab .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-25fa150fab .tabular-table tbody tr td { border-top: none; }
#> #tabular-25fa150fab .tabular-band { text-align: center; }
#> #tabular-25fa150fab .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-25fa150fab .tabular-subgroup-label { font-weight: 600; }
#> #tabular-25fa150fab .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-25fa150fab .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-25fa150fab .text-left { text-align: left; }
#> #tabular-25fa150fab .text-center { text-align: center; }
#> #tabular-25fa150fab .text-right { text-align: right; }
#> #tabular-25fa150fab .tabular-table thead th.text-left { text-align: left; }
#> #tabular-25fa150fab .tabular-table thead th.text-center { text-align: center; }
#> #tabular-25fa150fab .tabular-table thead th.text-right { text-align: right; }
#> #tabular-25fa150fab .valign-top { vertical-align: top; }
#> #tabular-25fa150fab .valign-middle { vertical-align: middle; }
#> #tabular-25fa150fab .valign-bottom { vertical-align: bottom; }
#> #tabular-25fa150fab .tabular-footnote { font-size: 8pt; color: #495057; margin: .25rem 0; }
#> #tabular-25fa150fab .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-25fa150fab .tabular-page-break-row { display: none; }
#> #tabular-25fa150fab { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-25fa150fab .tabular-page-header, #tabular-25fa150fab .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 7pt; color: var(--tabular-chrome-color); }
#> #tabular-25fa150fab .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-25fa150fab .tabular-page-footer { margin-top: 1rem; }
#> #tabular-25fa150fab .tabular-page-header-left, #tabular-25fa150fab .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-25fa150fab .tabular-page-header-center, #tabular-25fa150fab .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-25fa150fab .tabular-page-header-right, #tabular-25fa150fab .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-25fa150fab .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-25fa150fab .tabular-table tr { page-break-inside: avoid; } #tabular-25fa150fab .tabular-page-header, #tabular-25fa150fab .tabular-page-footer { display: none; } #tabular-25fa150fab .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-25fa150fab .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-25fa150fab .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-25fa150fab" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.2.1</h1>
#> <h1 class="tabular-title">Best Overall Response and Response Rates</h1>
#> <h1 class="tabular-title">Efficacy Evaluable Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
#> <thead>
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

# ---- Example 2: Per-spec override with per-page chrome ----
#
# The submission session sets a portrait letter 9pt default (typical
# safety-table geometry). One particular AE table needs landscape
# for a long PT label band; the per-spec `preset()` overrides only
# orientation. The same per-spec call wires the canonical
# per-page header band (protocol on the left, page X of Y on the
# right) and a footer band that auto-resolves the calling
# script's name and the current render timestamp via the
# `{program}` and `{datetime}` tokens.
set_preset(font_size = 9, paper_size = "letter")

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
    soc      = col_spec(usage = "group", visible = FALSE,
                        group_display = "column_repeat"),
    row_type = col_spec(visible = FALSE),
    n_total  = col_spec(visible = FALSE),
    placebo  = col_spec(label = sprintf("Placebo\nN=%d",  n["placebo"])),
    drug_50  = col_spec(label = sprintf("Drug 50\nN=%d",  n["drug_50"])),
    drug_100 = col_spec(label = sprintf("Drug 100\nN=%d", n["drug_100"])),
    Total    = col_spec(label = sprintf("Total\nN=%d",    n["Total"]))
  ) |>
  headers("Treatment Group" = c("placebo", "drug_50", "drug_100", "Total")) |>
  sort_rows(by = c("row_type", "n_total"), descending = c(FALSE, TRUE)) |>
  preset(
    orientation = "landscape",
    pagehead = list(
      left  = "Protocol: ABC-123",
      right = "Page {page} of {npages}"
    ),
    pagefoot = list(
      left  = "{program}",
      right = "{datetime}"
    )
  ) |>
  paginate(keep_together = "soc")
#> <style>
#> #tabular-684a2ff60a { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-684a2ff60a .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-684a2ff60a .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-684a2ff60a .tabular-pad { margin: 0; }
#> #tabular-684a2ff60a .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-684a2ff60a .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#> #tabular-684a2ff60a .tabular-table th, #tabular-684a2ff60a .tabular-table td { padding: .35rem .6rem; }
#> #tabular-684a2ff60a .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-684a2ff60a .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-684a2ff60a .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-684a2ff60a .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-684a2ff60a .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-684a2ff60a .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-684a2ff60a .tabular-table tbody tr td { border-top: none; }
#> #tabular-684a2ff60a .tabular-band { text-align: center; }
#> #tabular-684a2ff60a .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-684a2ff60a .tabular-subgroup-label { font-weight: 600; }
#> #tabular-684a2ff60a .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-684a2ff60a .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-684a2ff60a .text-left { text-align: left; }
#> #tabular-684a2ff60a .text-center { text-align: center; }
#> #tabular-684a2ff60a .text-right { text-align: right; }
#> #tabular-684a2ff60a .tabular-table thead th.text-left { text-align: left; }
#> #tabular-684a2ff60a .tabular-table thead th.text-center { text-align: center; }
#> #tabular-684a2ff60a .tabular-table thead th.text-right { text-align: right; }
#> #tabular-684a2ff60a .valign-top { vertical-align: top; }
#> #tabular-684a2ff60a .valign-middle { vertical-align: middle; }
#> #tabular-684a2ff60a .valign-bottom { vertical-align: bottom; }
#> #tabular-684a2ff60a .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#> #tabular-684a2ff60a .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-684a2ff60a .tabular-page-break-row { display: none; }
#> #tabular-684a2ff60a { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-684a2ff60a .tabular-page-header, #tabular-684a2ff60a .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#> #tabular-684a2ff60a .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-684a2ff60a .tabular-page-footer { margin-top: 1rem; }
#> #tabular-684a2ff60a .tabular-page-header-left, #tabular-684a2ff60a .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-684a2ff60a .tabular-page-header-center, #tabular-684a2ff60a .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-684a2ff60a .tabular-page-header-right, #tabular-684a2ff60a .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-684a2ff60a .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-684a2ff60a .tabular-table tr { page-break-inside: avoid; } #tabular-684a2ff60a .tabular-page-header, #tabular-684a2ff60a .tabular-page-footer { display: none; } #tabular-684a2ff60a .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-684a2ff60a .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-684a2ff60a .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> @page {
#>   white-space: pre-line;
#>   @top-left { content: "Protocol: ABC-123"; }
#>   @top-center { content: ""; }
#>   @top-right { content: "Page " counter(page) " of " counter(pages); }
#>   @bottom-left { content: "<interactive>"; }
#>   @bottom-center { content: ""; }
#>   @bottom-right { content: "01JUN2026 22:30:48"; }
#> }
#> </style>
#> <div id="tabular-684a2ff60a" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><header class="tabular-page-header">
#>   <div class="tabular-page-header-left">Protocol: ABC-123</div>
#>   <div class="tabular-page-header-right">Page 1 of 3</div>
#> </header>
#> <div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.1</h1>
#> <h1 class="tabular-title">Adverse Events by System Organ Class and Preferred Term</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
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
#> </div>
#> <footer class="tabular-page-footer">
#>   <div class="tabular-page-footer-left">&lt;interactive&gt;</div>
#>   <div class="tabular-page-footer-right">01JUN2026 22:30:48</div>
#> </footer></div>

# Reset the session default so subsequent examples / R sessions
# are not affected.
set_preset(.reset = TRUE)
```
