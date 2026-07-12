# Wrap a plot or image in submission chrome

Builds a figure display, the "F" in TFL. `figure()` takes a ggplot, a
recorded base-R plot, a zero-argument drawing function, or a path to a
PNG / JPG file, and surrounds it with the same canonical submission
chrome as a table: up to four centred title lines, footnotes, and the
per-page header / footer drawn from the active
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md).
Pass a list to emit one figure per page in a single file.

## Usage

``` r
figure(
  plot,
  titles = NULL,
  footnotes = NULL,
  width = NULL,
  height = NULL,
  halign = "center",
  valign = "middle",
  dpi = 300,
  meta = NULL
)
```

## Arguments

- plot:

  *The figure to display.* One of: a `ggplot` object; a recorded base
  plot from
  [`grDevices::recordPlot()`](https://rdrr.io/r/grDevices/recordplot.html);
  a zero-argument function that draws to the active device when called;
  a length-1 path to a `.png`, `.jpg`, or `.jpeg` file; or a `list` of
  any of these for a multi-page figure.

  **Tip:** a list may mix kinds freely — a ggplot, a recorded plot, and
  a PNG path can share one multi-page figure.

- titles:

  *Title lines above the figure.* `<character> | NULL`. One element per
  line, up to four; same `{glue}` interpolation and
  [`md()`](https://vthanik.github.io/tabular/dev/reference/md.md) /
  [`html()`](https://vthanik.github.io/tabular/dev/reference/html.md)
  inline formatting as
  [`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md).
  `NULL` draws no titles.

- footnotes:

  *Footnote lines below the figure.* `<character> | NULL`. One element
  per line; same interpolation and inline formatting as `titles`. `NULL`
  draws no footnotes.

- width:

  *Drawn image width in inches.* `<numeric(1)> | NULL`. `NULL` fills the
  full printable width.

- height:

  *Drawn image height in inches.* `<numeric(1)> | NULL`. `NULL` fills
  the body box height (the printable height minus the title and footnote
  chrome). Set a smaller value to leave vertical slack for `valign` to
  place the image within.

- halign:

  *Horizontal placement in the content box.* `<character(1)>`. One of:

  - `"left"`

  - `"center"` (default)

  - `"right"`

- valign:

  *Vertical placement in the content box.* `<character(1)>`. One of:

  - `"top"`

  - `"middle"` (default)

  - `"bottom"`

  **Note:** continuous backends (HTML / Markdown) render the figure
  contained to the viewport with no fixed page height, so `valign` is a
  no-op there; the paged backends honour it exactly.

- dpi:

  *Raster resolution for plot inputs.* `<numeric(1)>`. Resolution in
  dots per inch for PNG rasterisation. Ignored for file inputs (passed
  through unchanged) and for vector PDF targets.

- meta:

  *Per-page token data frame.* `<data.frame> | NULL`. Multi-page only:
  one row per plot, whose columns become `{token}` values in that page's
  `titles` / `footnotes`. Ignored (with a warning) for a single-plot
  figure.

## Value

*A `figure_spec`.* Pass it to
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md) to
write a file, or print it to preview the figure inline.

## Details

**Two-axis placement.** By default the image FILLS the body content box
— the full printable width by the box height (the printable height minus
the title / footnote chrome). Pass an explicit `width` / `height`
smaller than the box and `halign` / `valign` place the image within the
resulting slack, independently — horizontally (`left` / `center` /
`right`) and vertically (`top` / `middle` / `bottom`), both defaulting
to centred. Paged backends (RTF / PDF / DOCX) honour `valign` exactly
against the content-box height; with the box-filling default there is no
vertical slack, so `valign` only bites once you set a shorter `height`.
The continuous backends (HTML / Markdown) render the figure
responsively, contained to the viewport, so `halign` still applies but
`valign` is a no-op there.

**Format-aware rasterisation.** Plot inputs render to vector PDF for
`.pdf` / `.tex` targets and to PNG at `dpi` for every other backend;
file inputs pass through byte-for-byte. No raster work happens until
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md).

**Styling the chrome.** A figure carries the same chrome surfaces as a
table, so
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
and the
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)
cosmetic knobs reach its titles, footnotes, and page header / footer —
e.g. `style(fig, font_size = 14, .at = cells_title())` or
`preset(fig, colors = list(footnotes = c(text = "grey40")))`. A figure
has no body, column headers, or subgroup banner, so styling those
surfaces is an error. Inter-section spacing follows the preset `spacing`
knob (`title`, `footnote`), exactly like a table.

## See also

**Terminal verb:**
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md)
(write the figure to a file).

**Shared chrome:**
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)
/
[`set_preset()`](https://vthanik.github.io/tabular/dev/reference/set_preset.md)
(page geometry, fonts, header / footer),
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
(per-figure title / footnote / page-chrome styling),
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md)
(the table sibling).

**Class predicate:**
[`is_figure_spec()`](https://vthanik.github.io/tabular/dev/reference/tabular_predicates.md).

## Examples

``` r
# ---- Example 1: a single base-R figure with submission chrome ----
#
# A zero-argument drawing function is the simplest portable input: it
# draws to whatever device the backend opens. Here, subjects enrolled
# per treatment arm from the bundled BigN frame, wrapped in the
# canonical title block and a population footnote.
arms <- cdisc_saf_n[cdisc_saf_n$arm_short != "Total", ]

draw_enrollment <- function() {
  barplot(
    arms$n,
    names.arg = arms$arm_short,
    ylab = "Subjects enrolled",
    col = "grey70"
  )
}

fig <- figure(
  draw_enrollment,
  titles = c(
    "Figure 14.1.1",
    "Subjects Enrolled by Treatment Arm",
    "Safety Population"
  ),
  footnotes = "Total enrolled: N = 254."
)
fig

#tabular-cd0522e723 { font-family: "Courier New", Courier, "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-cd0522e723 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-cd0522e723 p { line-height: inherit; }
#tabular-cd0522e723 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-cd0522e723 .tabular-caption { margin: 0; padding: 0; }
#tabular-cd0522e723 .tabular-pad { margin: 0; line-height: 1; }
#tabular-cd0522e723 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-cd0522e723 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-cd0522e723 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-cd0522e723 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-cd0522e723 .tabular-table th, #tabular-cd0522e723 .tabular-table td { padding: .18rem .6rem; }
#tabular-cd0522e723 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-cd0522e723 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-cd0522e723 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-cd0522e723 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-cd0522e723 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-cd0522e723 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-cd0522e723 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-cd0522e723 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-cd0522e723 .tabular-table tbody tr td { border-top: none; }
#tabular-cd0522e723 .tabular-band { text-align: center; }
#tabular-cd0522e723 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-cd0522e723 .tabular-subgroup-label { font-weight: 600; }
#tabular-cd0522e723 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-cd0522e723 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-cd0522e723 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-cd0522e723 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-cd0522e723 .text-left { text-align: left; }
#tabular-cd0522e723 .text-center { text-align: center; }
#tabular-cd0522e723 .text-right { text-align: right; }
#tabular-cd0522e723 .tabular-table thead th.text-left { text-align: left; }
#tabular-cd0522e723 .tabular-table thead th.text-center { text-align: center; }
#tabular-cd0522e723 .tabular-table thead th.text-right { text-align: right; }
#tabular-cd0522e723 .tabular-table td.text-left { text-align: left; }
#tabular-cd0522e723 .tabular-table td.text-center { text-align: center; }
#tabular-cd0522e723 .tabular-table td.text-right { text-align: right; }
#tabular-cd0522e723 .valign-top { vertical-align: top; }
#tabular-cd0522e723 .valign-middle { vertical-align: middle; }
#tabular-cd0522e723 .valign-bottom { vertical-align: bottom; }
#tabular-cd0522e723 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-cd0522e723 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-cd0522e723 .tabular-page-break-row { display: none; }
#tabular-cd0522e723 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-cd0522e723 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-cd0522e723 .tabular-page-header, #tabular-cd0522e723 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-cd0522e723 .tabular-page-header { margin-bottom: 1rem; }
#tabular-cd0522e723 .tabular-page-footer { margin-top: 1rem; }
#tabular-cd0522e723 .tabular-page-header-left, #tabular-cd0522e723 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-cd0522e723 .tabular-page-header-center, #tabular-cd0522e723 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-cd0522e723 .tabular-page-header-right, #tabular-cd0522e723 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-cd0522e723 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-cd0522e723 .tabular-table tr { page-break-inside: avoid; } #tabular-cd0522e723 .tabular-page-header, #tabular-cd0522e723 .tabular-page-footer { display: none; } #tabular-cd0522e723 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-cd0522e723 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-cd0522e723 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Figure 14.1.1
Subjects Enrolled by Treatment Arm
Safety Population
 



Total enrolled: N = 254.


# ---- Example 2: one figure per page from a list ----
#
# A list input emits one figure per page in a single file. Each arm
# gets its own page; the kinds may mix (a ggplot, a recorded plot, or
# a PNG path could share the list). Bottom-anchored here to show the
# two-axis placement.
draw_arm <- function(i) {
  force(i)
  function() {
    barplot(arms$n[i], names.arg = arms$arm_short[i], col = "grey70")
  }
}

per_arm <- figure(
  lapply(seq_len(nrow(arms)), draw_arm),
  titles = c("Figure 14.1.2", "Enrollment by Arm, One Page per Arm"),
  valign = "bottom"
)
per_arm

#tabular-e184540ca8 { font-family: "Courier New", Courier, "Liberation Mono", monospace; color: #212529; margin: 1.5rem; font-size: 10pt; line-height: 1.3; }
#tabular-e184540ca8 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-e184540ca8 p { line-height: inherit; }
#tabular-e184540ca8 .tabular-title { font-size: 10pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-e184540ca8 .tabular-caption { margin: 0; padding: 0; }
#tabular-e184540ca8 .tabular-pad { margin: 0; line-height: 1; }
#tabular-e184540ca8 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-e184540ca8 .tabular-table { border-collapse: collapse; font-size: 10pt; margin: 0 auto; }
#tabular-e184540ca8 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-e184540ca8 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-e184540ca8 .tabular-table th, #tabular-e184540ca8 .tabular-table td { padding: .18rem .6rem; }
#tabular-e184540ca8 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-e184540ca8 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-e184540ca8 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-e184540ca8 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-e184540ca8 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-e184540ca8 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-e184540ca8 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-e184540ca8 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-e184540ca8 .tabular-table tbody tr td { border-top: none; }
#tabular-e184540ca8 .tabular-band { text-align: center; }
#tabular-e184540ca8 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-e184540ca8 .tabular-subgroup-label { font-weight: 600; }
#tabular-e184540ca8 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-e184540ca8 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-e184540ca8 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-e184540ca8 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-e184540ca8 .text-left { text-align: left; }
#tabular-e184540ca8 .text-center { text-align: center; }
#tabular-e184540ca8 .text-right { text-align: right; }
#tabular-e184540ca8 .tabular-table thead th.text-left { text-align: left; }
#tabular-e184540ca8 .tabular-table thead th.text-center { text-align: center; }
#tabular-e184540ca8 .tabular-table thead th.text-right { text-align: right; }
#tabular-e184540ca8 .tabular-table td.text-left { text-align: left; }
#tabular-e184540ca8 .tabular-table td.text-center { text-align: center; }
#tabular-e184540ca8 .tabular-table td.text-right { text-align: right; }
#tabular-e184540ca8 .valign-top { vertical-align: top; }
#tabular-e184540ca8 .valign-middle { vertical-align: middle; }
#tabular-e184540ca8 .valign-bottom { vertical-align: bottom; }
#tabular-e184540ca8 .tabular-footnote { font-size: 10pt; color: #495057; margin: .25rem 0; }
#tabular-e184540ca8 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-e184540ca8 .tabular-page-break-row { display: none; }
#tabular-e184540ca8 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-e184540ca8 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-e184540ca8 .tabular-page-header, #tabular-e184540ca8 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 9pt; color: var(--tabular-chrome-color); }
#tabular-e184540ca8 .tabular-page-header { margin-bottom: 1rem; }
#tabular-e184540ca8 .tabular-page-footer { margin-top: 1rem; }
#tabular-e184540ca8 .tabular-page-header-left, #tabular-e184540ca8 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-e184540ca8 .tabular-page-header-center, #tabular-e184540ca8 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-e184540ca8 .tabular-page-header-right, #tabular-e184540ca8 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-e184540ca8 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-e184540ca8 .tabular-table tr { page-break-inside: avoid; } #tabular-e184540ca8 .tabular-page-header, #tabular-e184540ca8 .tabular-page-footer { display: none; } #tabular-e184540ca8 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-e184540ca8 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-e184540ca8 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Figure 14.1.2
Enrollment by Arm, One Page per Arm
 












```
