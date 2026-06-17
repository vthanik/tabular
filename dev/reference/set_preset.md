# Set or clear the session default preset

Stash a `preset_spec` in the package-internal session environment. Every
subsequent
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md)
chain that does not attach its own
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)
inherits these knobs at render time. Mirrors ggplot2's
[[`ggplot2::theme_set()`](https://ggplot2.tidyverse.org/reference/get_theme.html)](https://ggplot2.tidyverse.org/reference/get_theme.html):
one call up front, many tables downstream.

## Usage

``` r
set_preset(new = NULL, ..., .template = NULL, .style = NULL, .reset = FALSE)
```

## Arguments

- new:

  *A `preset_spec` to install wholesale.*
  `<preset_spec | NULL>: default NULL`. When non-`NULL`, replaces the
  session preset in one call without touching knobs. The primary use is
  the save/restore round-trip
  (`old <- set_preset(...); set_preset(old)`) — `new` accepts any
  `preset_spec` previously returned by `set_preset()` or
  [`get_preset()`](https://vthanik.github.io/tabular/dev/reference/get_preset.md).

  Mutually exclusive with `...`, `.template`, `.style`, `.reset`:
  passing any of those alongside a non-`NULL` `new` raises
  `tabular_error_input`.

- ...:

  *Named preset knobs.* Same shape as
  [`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md);
  see that verb for the full list of 13 recognised knobs. Unknown names
  raise `tabular_error_input`. Mutually exclusive with a non-`NULL`
  `new`.

- .template:

  *A `preset_spec` to bulk-apply before `...`.*
  `<preset_spec | NULL>: default NULL`. Same semantics as
  [`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)'s
  `.template`: every knob set away from its factory default feeds in as
  the base layer; user-supplied `...` knobs then merge on top with
  shallow-merge per list-valued knob.

- .style:

  *A
  [`style_template()`](https://vthanik.github.io/tabular/dev/reference/style_template.md)
  to layer into the session default.*
  `<style_template | NULL>: default NULL`. Same semantics as
  [`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)'s
  `.style`: the template's accumulated layers feed in as session-default
  style, layered before any per-spec
  [`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
  calls.

- .reset:

  *Discard the existing session preset before applying `...`.*
  `<logical(1)>: default FALSE`. With no knobs, clears the session
  default back to NULL.

## Value

*The previous session `preset_spec` (invisible).* Returns `NULL` when no
session preset was attached prior to the call. Capture it to round-trip
a temporary override: `old <- set_preset(...); set_preset(old)`. Mirrors
[[`ggplot2::theme_set()`](https://ggplot2.tidyverse.org/reference/get_theme.html)](https://ggplot2.tidyverse.org/reference/get_theme.html)
and [`base::options()`](https://rdrr.io/r/base/options.html) — the
canonical tidyverse save/restore primitive.

## Details

**Persistence.** The session preset lives in a package-internal
environment populated when `tabular` is loaded and emptied when the
namespace unloads. There is no on-disk persistence; set the default at
the top of each analysis script (or in a project-level `.Rprofile`) when
a sticky house style is needed.

**Merge, not replace.** A second `set_preset()` call merges its knobs
onto the existing session preset; unspecified knobs keep their prior
value. Pass `.reset = TRUE` to discard the existing session preset and
start from
[`preset_spec()`](https://vthanik.github.io/tabular/dev/reference/tabular_classes.md)
defaults. `set_preset(.reset = TRUE)` with no knobs clears the session
default back to NULL.

**Save and restore.** Every call returns the *previous* session preset
invisibly, the same primitive ggplot2's
[[`ggplot2::theme_set()`](https://ggplot2.tidyverse.org/reference/get_theme.html)](https://ggplot2.tidyverse.org/reference/get_theme.html)
ships. Capture it once, render, and restore by passing the saved value
back as the positional `new` argument:

    old <- set_preset(font_size = 10, paper_size = "a4")
    # ... one renegade render at 10pt A4 ...
    set_preset(old)        # restore

When the prior was `NULL` (no session preset ever attached), the restore
is `set_preset(.reset = TRUE)` instead — `set_preset(NULL)` is the same
shape as `set_preset()` and falls through to factory defaults rather
than clearing the session.

**Cascade with
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md).**
A per-spec
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)
always wins over the session default. The session default fills in only
when the spec carries no preset of its own.

## See also

**Per-spec partner:**
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)
— overrides the session default on one chain.

**Inspect:**
[`get_preset()`](https://vthanik.github.io/tabular/dev/reference/get_preset.md).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Sticky session default for an analysis script ----
#
# The submission's safety tables all use portrait letter, 9pt
# Times New Roman with 1-inch margins. Set once at the top of the
# analysis script and every `tabular()` chain inherits it — no
# per-table `preset()` call needed unless one table deviates.
set_preset(
  font_size   = 9,
  font_family = "Times New Roman",
  orientation = "portrait",
  paper_size  = "letter",
  margins     = 1
)

# Subsequent tabular() chains pick up the session preset at render.
demo_n <- stats::setNames(cdisc_saf_n$n, cdisc_saf_n$arm_short)
tabular(
  cdisc_saf_ae,
  titles = c(
    "Table 14.3.1",
    "Overall Summary of Adverse Events",
    "Safety Population"
  ),
  footnotes = "Subjects counted once per category."
) |>
  cols(
    stat_label = col_spec(label = "Category"),
    placebo    = col_spec(label = "Placebo\nN={demo_n['placebo']}"),
    drug_50    = col_spec(label = "Drug 50\nN={demo_n['drug_50']}"),
    drug_100   = col_spec(label = "Drug 100\nN={demo_n['drug_100']}"),
    Total      = col_spec(label = "Total\nN={demo_n['Total']}")
  )

#tabular-f5008f6aa4 { font-family: "Liberation Serif", "Times New Roman", Times, serif; color: #212529; margin: 1.5rem; font-size: 9pt; line-height: 1.3; }
#tabular-f5008f6aa4 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-f5008f6aa4 p { line-height: inherit; }
#tabular-f5008f6aa4 .tabular-title { font-size: 9pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#tabular-f5008f6aa4 .tabular-caption { margin: 0; padding: 0; }
#tabular-f5008f6aa4 .tabular-pad { margin: 0; line-height: 1; }
#tabular-f5008f6aa4 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#tabular-f5008f6aa4 .tabular-table { border-collapse: collapse; font-size: 9pt; margin: 0 auto; }
#tabular-f5008f6aa4 .tabular-table { --bs-table-bg: transparent; --bs-table-accent-bg: transparent; --bs-table-border-color: transparent; width: auto; }
#tabular-f5008f6aa4 .tabular-table > :not(caption) > * > * { border-bottom-width: 0; box-shadow: none; }
#tabular-f5008f6aa4 .tabular-table th, #tabular-f5008f6aa4 .tabular-table td { padding: .18rem .6rem; }
#tabular-f5008f6aa4 .tabular-table td { text-align: left; vertical-align: top; }
#tabular-f5008f6aa4 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#tabular-f5008f6aa4 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#tabular-f5008f6aa4 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#tabular-f5008f6aa4 .tabular-table thead .tabular-band { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-f5008f6aa4 .tabular-table thead .tabular-band.tabular-band-flush-left { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0.5em), transparent calc(100% - 0.5em)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-f5008f6aa4 .tabular-table thead .tabular-band.tabular-band-flush-right { background-image: linear-gradient(to right, transparent 0.5em, #adb5bd 0.5em, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-f5008f6aa4 .tabular-table thead .tabular-band.tabular-band-flush-both { background-image: linear-gradient(to right, transparent 0px, #adb5bd 0px, #adb5bd calc(100% - 0px), transparent calc(100% - 0px)); background-repeat: no-repeat; background-position: left bottom; background-size: 100% 0.5pt; }
#tabular-f5008f6aa4 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#tabular-f5008f6aa4 .tabular-table tbody tr td { border-top: none; }
#tabular-f5008f6aa4 .tabular-band { text-align: center; }
#tabular-f5008f6aa4 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .15rem .6rem; }
#tabular-f5008f6aa4 .tabular-subgroup-label { font-weight: 600; }
#tabular-f5008f6aa4 .tabular-subgroup-bign td { text-align: center; border-bottom: 1px solid #adb5bd; }
#tabular-f5008f6aa4 .tabular-subgroup-closed td { border-bottom: 1px solid #adb5bd; }
#tabular-f5008f6aa4 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#tabular-f5008f6aa4 .tabular-blank-row td { padding: 0; border: none; height: 1em; line-height: 1em; }
#tabular-f5008f6aa4 .text-left { text-align: left; }
#tabular-f5008f6aa4 .text-center { text-align: center; }
#tabular-f5008f6aa4 .text-right { text-align: right; }
#tabular-f5008f6aa4 .tabular-table thead th.text-left { text-align: left; }
#tabular-f5008f6aa4 .tabular-table thead th.text-center { text-align: center; }
#tabular-f5008f6aa4 .tabular-table thead th.text-right { text-align: right; }
#tabular-f5008f6aa4 .tabular-table td.text-left { text-align: left; }
#tabular-f5008f6aa4 .tabular-table td.text-center { text-align: center; }
#tabular-f5008f6aa4 .tabular-table td.text-right { text-align: right; }
#tabular-f5008f6aa4 .valign-top { vertical-align: top; }
#tabular-f5008f6aa4 .valign-middle { vertical-align: middle; }
#tabular-f5008f6aa4 .valign-bottom { vertical-align: bottom; }
#tabular-f5008f6aa4 .tabular-footnote { font-size: 9pt; color: #495057; margin: .25rem 0; }
#tabular-f5008f6aa4 .tabular-empty { font-style: italic; color: #6c757d; }
#tabular-f5008f6aa4 .tabular-page-break-row { display: none; }
#tabular-f5008f6aa4 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#tabular-f5008f6aa4 .tabular-chrome-wrap { width: fit-content; max-width: 100%; margin: 0 auto; }
#tabular-f5008f6aa4 .tabular-page-header, #tabular-f5008f6aa4 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; width: 100%; padding: .5rem 0; font-size: 8pt; color: var(--tabular-chrome-color); }
#tabular-f5008f6aa4 .tabular-page-header { margin-bottom: 1rem; }
#tabular-f5008f6aa4 .tabular-page-footer { margin-top: 1rem; }
#tabular-f5008f6aa4 .tabular-page-header-left, #tabular-f5008f6aa4 .tabular-page-footer-left { flex: 1; text-align: left; }
#tabular-f5008f6aa4 .tabular-page-header-center, #tabular-f5008f6aa4 .tabular-page-footer-center { flex: 1; text-align: center; }
#tabular-f5008f6aa4 .tabular-page-header-right, #tabular-f5008f6aa4 .tabular-page-footer-right { flex: 1; text-align: right; }
@media print { #tabular-f5008f6aa4 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-f5008f6aa4 .tabular-table tr { page-break-inside: avoid; } #tabular-f5008f6aa4 .tabular-page-header, #tabular-f5008f6aa4 .tabular-page-footer { display: none; } #tabular-f5008f6aa4 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-f5008f6aa4 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-f5008f6aa4 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }

 
Table 14.3.1
Overall Summary of Adverse Events
Safety Population
 



Category
```
