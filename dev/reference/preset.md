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

  *The spec to attach the preset to.*
  `<tabular_spec | figure_spec>: required`. Dot-prefixed so R's partial
  argument matching cannot accidentally bind a knob name in `...` to the
  spec slot.

  **Note:** a
  [`figure()`](https://vthanik.github.io/tabular/dev/reference/figure.md)
  spec accepts the page-geometry knobs (`paper_size`, `orientation`,
  `margins`, `font_size`, `font_family`, `pagehead`, `pagefoot`, ...)
  plus the cosmetic surface knobs (`alignment` / `fonts` / `colors` /
  `padding`) that target its chrome surfaces, the titles and footnotes,
  e.g. `fonts = list(titles = c(size = 14))`. A cosmetic knob that
  targets a table-only surface (`body` / `header` / `subgroup`), a
  `rules` knob (the rules sit on the header band a figure lacks), and
  the `.template` / `.style` style templates are rejected, since a
  figure has no such surfaces.

- ...:

  *Named preset knobs.* Any subset of the preset knobs the `preset_spec`
  class carries. Knob values are validated against the class's enum /
  length / type rules; bad values raise `tabular_error_input`. Unknown
  knob names raise `tabular_error_input` with the recognised set listed.

  Recognised knobs:

  - **`font_size`** — body point size. `<numeric(1)>`.

  - **`font_family`** — body font family. `<character | character(1)>`.
    Default `"mono"`. Four accepted shapes:

    1.  **Generic family** — `"mono"` (default), `"serif"`, `"sans"`
        (CSS aliases `"monospace"` / `"sans-serif"` also recognised).
        The resolver expands to a per-backend chain that leads with the
        Microsoft Office face (Courier New / Times New Roman / Arial) —
        installed on every Windows and macOS machine, where documents
        are reviewed — then the PostScript legacy name, then the
        metric-compatible **Liberation** face LAST as the Linux-server
        fallback (Posit Workbench / Domino / Citrix / RStudio Server),
        then TeX Gyre for LaTeX compile / the CSS generic for HTML.
        Liberation Mono / Serif / Sans are metric-compatible with
        Courier New / TNR / Arial, so layout, line breaks, and decimal
        alignment hold across every render context regardless of which
        end of the chain resolves. The mono default matches the dominant
        submission-TFL convention where deterministic glyph widths drive
        `n (%)` cell alignment.

    2.  **Named alias** — `"Times"`, `"Times New Roman"`, `"Arial"`,
        `"Helvetica"`, `"Courier"`, `"Courier New"`. These
        PostScript-era names alias to the appropriate generic family
        (Times -\> serif, Arial / Helvetica -\> sans, Courier -\> mono)
        and emit the same expanded chain. Honours the user's intent ("I
        want Times-like rendering") on every OS instead of hard-erroring
        on a Linux server with no TNR installed.

    3.  **Arbitrary named font** — `"Inter"`, `"JetBrains Mono"`,
        `"IBM Plex Mono"`, `"Source Code Pro"`, sponsor-specific face,
        etc. Emitted verbatim with no fallback fabricated. The consuming
        app (browser, xelatex, Word, LibreOffice) resolves the name
        against its own font matcher: RTF and DOCX substitute when the
        name is missing; **xelatex hard-errors at compile time** if the
        face is not installed; HTML browsers fall through to the
        browser's default font (not necessarily class-matched). For a
        portable result, prefer a generic family (shape 1) or an
        explicit stack (shape 4).

    4.  **Explicit stack** — `c("Inter", "Helvetica", "sans")`. User
        owns the chain. Returned verbatim — alias lookup is
        **bypassed**, so `c("Times", "Times")` honours the exact name
        with no chain expansion (escape hatch for users who genuinely
        want exact-name semantics).

    **Note:** tabular bundles no fonts. Because the default chain leads
    with the Office face, Word's font dropdown shows a face the reader
    actually has installed on Windows / macOS (e.g. Courier New for
    `"mono"`), not a phantom name; the metric-compatible Liberation face
    only appears as the fallback for a headless Linux box.

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
    [`inline_ast`](https://vthanik.github.io/tabular/dev/reference/tabular_classes.md).
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
    [`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md)
    /
    [`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md));
    `{page}` and `{npages}` resolve per page (filled in by Word /
    xelatex / the browser's print engine at view time). The program
    tokens walk a 5-mode detection chain — RStudio API,
    [`source()`](https://rdrr.io/r/base/source.html) frame, Rscript / R
    CMD BATCH commandArgs (covers Domino + Linux batch + CI), knitr
    current_input, fallback `"<interactive>"`.

  - **`rules`** — the single border vocabulary (replaces the old
    `borders` knob). String sugar `"booktabs"` (default, the clinical
    baseline), `"grid"`, `"frame"`, `"none"`; a single
    [`brdr()`](https://vthanik.github.io/tabular/dev/reference/brdr.md)
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
    `c(above = , below = )` (footnote: `above` only). Default is the one
    blank line above and below the title block. Two adjoining
    region-sides that target the same physical gap resolve to the MAX
    (never the sum), so a gap is never accidentally doubled.

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
    `"afm"` (default) measures glyphs with the bundled Core font
    metrics, so decimal columns align width-exact in proportional fonts
    (to within one padding space of rounding; exact in Courier).
    `"chars"` pads by character count — exact in monospaced faces only.
    Markdown output always pads by character count, the correct geometry
    for a text medium.

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

    - **`"window"`** — Auto-sized columns are scaled proportionally to
      their natural width to fill the residual page width. Pinned and
      percent columns keep their pins. Word's "Auto-fit Window".

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

  - **`empty_text`** — house-style *wording* for the empty-state message
    shown when a spec resolves to zero data rows. `<character(1)>`. The
    resolution is spec arg -\> preset knob -\> built-in default: a
    per-table `tabular(empty_text = ...)` wins, else this preset knob
    (set once via
    [`set_preset()`](https://vthanik.github.io/tabular/dev/reference/set_preset.md)
    for a whole house style), else the built-in
    `"No data available to report"`. Glue
    [`{}`](https://rdrr.io/r/base/Paren.html) and
    [`md()`](https://vthanik.github.io/tabular/dev/reference/md.md) /
    [`html()`](https://vthanik.github.io/tabular/dev/reference/html.md)
    inline formatting are honoured, exactly like a title line.

  - **`whitespace`** — how significant ASCII spaces in labels and cells
    render. `<character(1)>`. One of:

    - **`"preserve"`** *(default)* — leading, trailing, and interior
      runs of 2+ spaces become the backend non-breaking token (`&nbsp;`
      / `~` / `\~`; DOCX preserves via `xml:space`), so a hand-built
      indent like `col_spec(label = " Placebo")` renders verbatim across
      every backend. A single interior space stays breakable, so cells
      still wrap.

    - **`"collapse"`** — leave the backend's native run-folding in place
      (HTML / md / LaTeX collapse runs to one space).

    **Note:** never affects `col_spec(align = "decimal")` padding, which
    uses U+00A0 and is preserved unconditionally.

  - **`chrome_onscreen`** — whether the on-screen running header /
    footer bands render in HTML output. `<character(1)>`. One of:

    - **`"auto"`** *(default)* — the `pagehead` / `pagefoot` content
      renders as on-screen `<header>` / `<footer>` bands.

    - **`"off"`** — suppress the on-screen bands; the print-time `@page`
      chrome still renders, so print-to-PDF output is unchanged. Useful
      when the HTML is consumed only via print.

    HTML-only; the paged backends (RTF / PDF / DOCX) always emit
    per-page chrome regardless of this knob.

  - **`footnote_markers`** — the glyph scheme for
    [`footnote()`](https://vthanik.github.io/tabular/dev/reference/footnote.md)
    markers, which the engine allocates once in reading order.
    `<character(1)>`. One of:

    - **`"letters"`** *(default)* — `a`, `b`, …, `z`, `aa`, `ab`, …
      (bijective base-26).

    - **`"numbers"`** — `1`, `2`, `3`, …

    - **`"symbols"`** — Lamport's sequence `*`, `†`, `‡`, `§`, `¶`, `‖`,
      then doubled (`**`, `††`, …) once it spills past the sixth.

    **Interaction:** a note's *anchor* is fixed by
    [`footnote()`](https://vthanik.github.io/tabular/dev/reference/footnote.md);
    its *scheme* (this knob) and *label* (`footnote_label`) are resolved
    from the active preset at render, so flipping either re-letters
    every marker at once.

  - **`footnote_label`** — block-line template for a
    [`footnote()`](https://vthanik.github.io/tabular/dev/reference/footnote.md)
    marker. `<character(1)>`. Default `"{m}"`; the `{m}` token is
    replaced by the allocated marker, so `"[{m}]"` prints `[a]` ahead of
    the note text on the footnote line.

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
  [`style_template()`](https://vthanik.github.io/tabular/dev/reference/style_template.md)
  to layer onto the cascade.* `<style_template | NULL>: default NULL`.
  When supplied, every layer the template has accumulated via
  [`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
  is replayed in order at engine time, after the per-spec
  [`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
  layers on `.spec`. Use this to attach a sponsor's reusable house style
  to a chain without restating every per-region rule.

- .reset:

  *Discard the spec's existing preset before applying `...`.*
  `<logical(1)>: default FALSE`. When `TRUE`, the spec's prior
  `preset_spec` (if any) is dropped and `...` knobs are merged onto
  fresh
  [`preset_spec()`](https://vthanik.github.io/tabular/dev/reference/tabular_classes.md)
  defaults. With no knobs, the per-spec preset is cleared back to NULL
  (the spec falls through to
  [`set_preset()`](https://vthanik.github.io/tabular/dev/reference/set_preset.md)
  or
  [`preset_spec()`](https://vthanik.github.io/tabular/dev/reference/tabular_classes.md)
  defaults).

## Value

*The updated `tabular_spec`.* Continue chaining with
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md),
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md),
then render via
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md) (or
resolve without I/O via
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md)).

## Details

**Per-spec, chained.** `preset()` is the per-spec override — a verb that
returns a modified spec, composable on the pipe alongside
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md) /
[`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md)
/
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md).
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
[`preset_spec()`](https://vthanik.github.io/tabular/dev/reference/tabular_classes.md)
defaults. `preset(.spec, .reset = TRUE)` with no knobs clears the
per-spec override entirely (the spec then falls through to
[`set_preset()`](https://vthanik.github.io/tabular/dev/reference/set_preset.md)
or
[`preset_spec()`](https://vthanik.github.io/tabular/dev/reference/tabular_classes.md)
defaults at render time).

**Direct
[`preset_spec()`](https://vthanik.github.io/tabular/dev/reference/tabular_classes.md)
calls bypass lowering.** The five named-list knobs are no longer slots
on the `preset_spec` S7 class — they exist only as `preset()` /
[`set_preset()`](https://vthanik.github.io/tabular/dev/reference/set_preset.md)
arguments that lower into `@style`. `preset_spec(rules = list(...))`
(and analogous direct calls) raise "unused argument". Wrap such calls in
`tabular(...) |> preset(...)` so the lowering helper fires and the
layers land on `@style`.

**Cascade with
[`set_preset()`](https://vthanik.github.io/tabular/dev/reference/set_preset.md).**
The engine resolves the active preset in this order: (1) the spec's
per-call preset (this verb), (2) the session default attached via
[`set_preset()`](https://vthanik.github.io/tabular/dev/reference/set_preset.md),
(3)
[`preset_spec()`](https://vthanik.github.io/tabular/dev/reference/tabular_classes.md)
factory defaults. The first non-NULL layer wins; layers are not
field-merged across the cascade.

## See also

**Session-scope partners:**
[`set_preset()`](https://vthanik.github.io/tabular/dev/reference/set_preset.md),
[`get_preset()`](https://vthanik.github.io/tabular/dev/reference/get_preset.md).

**Render-geometry consumer:**
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md)
derives the per-page row budget from the active preset's paper,
orientation, margins, and font size.

**Sibling build verbs:**
[`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md) /
[`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md),
[`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md),
[`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md),
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md).

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
  "ORR (CR + PR)", "CBR (CR + PR + SD)",
  "DCR (CR + PR + SD + NON-CR/NON-PD)", "95% CI (Clopper-Pearson)"
)
eff <- cdisc_eff_resp
eff$stat_label <- factor(eff$stat_label, levels = bor_levels)
ne <- stats::setNames(cdisc_eff_n$n, cdisc_eff_n$arm_short)

tabular(
  eff,
  titles = c(
    "Table 14.2.1",
    "Best Overall Response and Response Rates",
    "Efficacy Evaluable Population"
  ),
  footnotes = "Response per RECIST 1.1, investigator assessment."
) |>
  cols(
    stat_label  = col_spec(label = "Response"),
    row_type    = col_spec(visible = FALSE),
    groupid     = col_spec(visible = FALSE),
    group_label = col_spec(visible = FALSE),
    placebo    = col_spec(label = "Placebo\nN={ne['placebo']}"),
    drug_50    = col_spec(label = "Drug 50\nN={ne['drug_50']}"),
    drug_100   = col_spec(label = "Drug 100\nN={ne['drug_100']}")
  ) |>
  sort_rows(by = c("groupid", "stat_label")) |>
  preset(
    orientation = "landscape",
    paper_size  = "a4",
    font_size   = 8
  ) |>
  paginate()

#tabular-6baf110ab1 { font-family: "Courier New", Courier, "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 8pt; line-height: 1.3; }
#tabular-6baf110ab1 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-6baf110ab1 p { line-height: inherit; }
#tabular-6baf110ab1 .tabular-title { font-size: 8pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-6baf110ab1 .tabular-caption { margin: 0; padding: 0; }
#tabular-6baf110ab1 .tabular-pad { margin: 0; line-height: 1; }
#tabular-6baf110ab1 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-6baf110ab1 .tabular-table { border-collapse: collapse; font-size: 8pt; margin: 0 auto; }
#tabular-6baf110ab1 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-6baf110ab1 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-6baf110ab1 .tabular-table th, #tabular-6baf110ab1 .tabular-table td { padding: .18rem .6rem; }
#tabular-6baf110ab1 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-6baf110ab1 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-6baf110ab1 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-6baf110ab1 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-6baf110ab1 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-6baf110ab1 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-6baf110ab1 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-6baf110ab1 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-6baf110ab1 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-6baf110ab1 .tabular-table tbody tr td { border-top: none; }
#tabular-6baf110ab1 .tabular-band { text-align: center; }
#tabular-6baf110ab1 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-6baf110ab1 .tabular-subgroup-label { font-weight: 600; }
#tabular-6baf110ab1 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-6baf110ab1 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-6baf110ab1 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-6baf110ab1 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-6baf110ab1 .text-left { text-align: left; }
#tabular-6baf110ab1 .text-center { text-align: center; }
#tabular-6baf110ab1 .text-right { text-align: right; }
#tabular-6baf110ab1 .tabular-table thead th.text-left { text-align: left; }
#tabular-6baf110ab1 .tabular-table thead th.text-center { text-align: center; }
#tabular-6baf110ab1 .tabular-table thead th.text-right { text-align: right; }
#tabular-6baf110ab1 .tabular-table td.text-left { text-align: left; }
#tabular-6baf110ab1 .tabular-table td.text-center { text-align: center; }
#tabular-6baf110ab1 .tabular-table td.text-right { text-align: right; }
#tabular-6baf110ab1 .valign-top { vertical-align: top; }
#tabular-6baf110ab1 .valign-middle { vertical-align: middle; }
#tabular-6baf110ab1 .valign-bottom { vertical-align: bottom; }
#tabular-6baf110ab1 .tabular-footnote { font-size: 8pt; color: #495057; margin: .25rem 0; }
#tabular-6baf110ab1 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-6baf110ab1 .tabular-page-break-row { display: none; }
#tabular-6baf110ab1 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-6baf110ab1 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-6baf110ab1 .tabular-page-header, #tabular-6baf110ab1 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 7pt; color: var(--tabular-chrome-color); }
#tabular-6baf110ab1 .tabular-page-header { margin-bottom: 1rem; }
#tabular-6baf110ab1 .tabular-page-footer { margin-top: 1rem; }
#tabular-6baf110ab1 .tabular-page-header-left, #tabular-6baf110ab1 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-6baf110ab1 .tabular-page-header-center, #tabular-6baf110ab1 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-6baf110ab1 .tabular-page-header-right, #tabular-6baf110ab1 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-6baf110ab1 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-6baf110ab1 .tabular-table tr { page-break-inside: avoid; } #tabular-6baf110ab1 .tabular-page-header, #tabular-6baf110ab1 .tabular-page-footer { display: none; } #tabular-6baf110ab1 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-6baf110ab1 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-6baf110ab1 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.2.1
Best Overall Response and Response Rates
Efficacy Evaluable Population
 



Response
```
