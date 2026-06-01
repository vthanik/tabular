# Set or clear the session default preset

Stash a `preset_spec` in the package-internal session environment. Every
subsequent
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
chain that does not attach its own
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md)
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
  [`get_preset()`](https://vthanik.github.io/tabular/reference/get_preset.md).

  Mutually exclusive with `...`, `.template`, `.style`, `.reset`:
  passing any of those alongside a non-`NULL` `new` raises
  `tabular_error_input`.

- ...:

  *Named preset knobs.* Same shape as
  [`preset()`](https://vthanik.github.io/tabular/reference/preset.md);
  see that verb for the full list of 13 recognised knobs. Unknown names
  raise `tabular_error_input`. Mutually exclusive with a non-`NULL`
  `new`.

- .template:

  *A `preset_spec` to bulk-apply before `...`.*
  `<preset_spec | NULL>: default NULL`. Same semantics as
  [`preset()`](https://vthanik.github.io/tabular/reference/preset.md)'s
  `.template`: every knob set away from its factory default feeds in as
  the base layer; user-supplied `...` knobs then merge on top with
  shallow-merge per list-valued knob.

- .style:

  *A
  [`style_template()`](https://vthanik.github.io/tabular/reference/style_template.md)
  to layer into the session default.*
  `<style_template | NULL>: default NULL`. Same semantics as
  [`preset()`](https://vthanik.github.io/tabular/reference/preset.md)'s
  `.style`: the template's accumulated layers feed in as session-default
  style, layered before any per-spec
  [`style()`](https://vthanik.github.io/tabular/reference/style.md)
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
[`preset_spec()`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
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
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md).** A
per-spec
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md)
always wins over the session default. The session default fills in only
when the spec carries no preset of its own.

## See also

**Per-spec partner:**
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md) —
overrides the session default on one chain.

**Inspect:**
[`get_preset()`](https://vthanik.github.io/tabular/reference/get_preset.md).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

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
demo_n <- stats::setNames(saf_n$n, saf_n$arm_short)
tabular(
  saf_aeoverall,
  titles = c(
    "Table 14.3.1",
    "Overall Summary of Adverse Events",
    sprintf("Safety Population (N=%d)", demo_n["Total"])
  ),
  footnotes = "Subjects counted once per category."
) |>
  cols(
    stat_label = col_spec(usage = "group", label = "Category"),
    placebo    = col_spec(label = sprintf("Placebo\nN=%d",  demo_n["placebo"])),
    drug_50    = col_spec(label = sprintf("Drug 50\nN=%d",  demo_n["drug_50"])),
    drug_100   = col_spec(label = sprintf("Drug 100\nN=%d", demo_n["drug_100"])),
    Total      = col_spec(label = sprintf("Total\nN=%d",    demo_n["Total"]))
  )
#> <style>
#> #tabular-a799212863 { font-family: "Liberation Serif", "Times New Roman", Times, serif; color: #212529; margin: 1.5rem; }
#> #tabular-a799212863 .tabular-content { width: fit-content; max-width: 100%; margin: 0 auto; }
#> #tabular-a799212863 .tabular-title { font-size: 9pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-a799212863 .tabular-pad { margin: 0; }
#> #tabular-a799212863 .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-a799212863 .tabular-table { border-collapse: collapse; font-size: 9pt; margin: 0 auto; }
#> #tabular-a799212863 .tabular-table th, #tabular-a799212863 .tabular-table td { padding: .35rem .6rem; }
#> #tabular-a799212863 .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-a799212863 .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-a799212863 .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-a799212863 .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-a799212863 .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-a799212863 .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-a799212863 .tabular-table tbody tr td { border-top: none; }
#> #tabular-a799212863 .tabular-band { text-align: center; }
#> #tabular-a799212863 .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-a799212863 .tabular-subgroup-label { font-weight: 600; }
#> #tabular-a799212863 .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-a799212863 .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-a799212863 .text-left { text-align: left; }
#> #tabular-a799212863 .text-center { text-align: center; }
#> #tabular-a799212863 .text-right { text-align: right; }
#> #tabular-a799212863 .tabular-table thead th.text-left { text-align: left; }
#> #tabular-a799212863 .tabular-table thead th.text-center { text-align: center; }
#> #tabular-a799212863 .tabular-table thead th.text-right { text-align: right; }
#> #tabular-a799212863 .valign-top { vertical-align: top; }
#> #tabular-a799212863 .valign-middle { vertical-align: middle; }
#> #tabular-a799212863 .valign-bottom { vertical-align: bottom; }
#> #tabular-a799212863 .tabular-footnote { font-size: 9pt; color: #495057; margin: .25rem 0; }
#> #tabular-a799212863 .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-a799212863 .tabular-page-break-row { display: none; }
#> #tabular-a799212863 { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-a799212863 .tabular-page-header, #tabular-a799212863 .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 8pt; color: var(--tabular-chrome-color); }
#> #tabular-a799212863 .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-a799212863 .tabular-page-footer { margin-top: 1rem; }
#> #tabular-a799212863 .tabular-page-header-left, #tabular-a799212863 .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-a799212863 .tabular-page-header-center, #tabular-a799212863 .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-a799212863 .tabular-page-header-right, #tabular-a799212863 .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-a799212863 .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-a799212863 .tabular-table tr { page-break-inside: avoid; } #tabular-a799212863 .tabular-page-header, #tabular-a799212863 .tabular-page-footer { display: none; } #tabular-a799212863 .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-a799212863 .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-a799212863 .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-a799212863" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <p class="tabular-pad">&nbsp;</p>
#> <h1 class="tabular-title">Table 14.3.1</h1>
#> <h1 class="tabular-title">Overall Summary of Adverse Events</h1>
#> <h1 class="tabular-title">Safety Population (N=254)</h1>
#> <p class="tabular-pad">&nbsp;</p>
#> <div class="tabular-table-wrap">
#> <table class="tabular-table">
#> <thead>
#> <tr><th>Total<br/>N=254</th><th>Placebo<br/>N=86</th><th>Drug 100<br/>N=72</th><th>Drug 50<br/>N=96</th></tr>
#> </thead>
#> <tbody>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any TEAE</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 0.5em);">217 (85.4)</td><td>65 (75.6)</td><td>68 (94.4)</td><td>84 (87.5)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any Serious AE (SAE)</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 0.5em);">3 (1.2)</td><td>0 (0.0)</td><td>1 (1.4)</td><td>2 (2.1)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any AE Related to Study Drug</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 0.5em);">184 (72.4)</td><td>43 (50.0)</td><td>64 (88.9)</td><td>77 (80.2)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any AE Leading to Death</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 0.5em);">3 (1.2)</td><td>2 (2.3)</td><td>0 (0.0)</td><td>1 (1.0)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>Any AE Recovered / Resolved</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 0.5em);">157 (61.8)</td><td>47 (54.7)</td><td>49 (68.1)</td><td>61 (63.5)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>  Maximum severity: Mild</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 0.5em);">77 (30.3)</td><td>36 (41.9)</td><td>20 (27.8)</td><td>21 (21.9)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>  Maximum severity: Moderate</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 0.5em);">111 (43.7)</td><td>24 (27.9)</td><td>40 (55.6)</td><td>47 (49.0)</td></tr>
#> <tr class="tabular-blank-row"><td colspan="4">&nbsp;</td></tr>
#> <tr class="tabular-group-header"><td colspan="4"><strong>  Maximum severity: Severe</strong></td></tr>
#> <tr><td style="padding-left: calc(.6rem + 0.5em); border-bottom: 0.5pt solid #212529;">29 (11.4)</td><td style="border-bottom: 0.5pt solid #212529;">5 (5.8)</td><td style="border-bottom: 0.5pt solid #212529;">8 (11.1)</td><td style="border-bottom: 0.5pt solid #212529;">16 (16.7)</td></tr>
#> </tbody>
#> </table>
#> </div>
#> <p class="tabular-footnote">Subjects counted once per category.</p>
#> </div></div>

# ---- Example 2: Reset the session default mid-script ----
#
# The first half of the script produces safety tables at 9pt; the
# second half produces efficacy tables at 10pt on landscape A4. A
# single `set_preset(.reset = TRUE, ...)` resets the cascade before
# the second batch starts.
set_preset(font_size = 9, paper_size = "letter")
get_preset()@font_size  # 9
#> [1] 9

set_preset(
  .reset      = TRUE,
  font_size   = 10,
  orientation = "landscape",
  paper_size  = "a4"
)
get_preset()@orientation  # "landscape"
#> [1] "landscape"

# Reset the session default so subsequent examples / R sessions
# are not affected.
set_preset(.reset = TRUE)

# ---- Example 3: Save and restore around a renegade table ----
#
# Most of the submission renders portrait letter at 9pt. One
# renegade efficacy table needs landscape A4 at 10pt. Capture
# the prior session preset, render the renegade, then restore.
set_preset(font_size = 9, paper_size = "letter")

old <- set_preset(
  font_size   = 10,
  paper_size  = "a4",
  orientation = "landscape"
)
# ... one renegade render ...
if (is.null(old)) {
  set_preset(.reset = TRUE)   # was no prior — clear
} else {
  set_preset(old)              # round-trip via the positional `new` arg
}
get_preset()@paper_size  # "letter" — restored
#> [1] "letter"

# ---- Example 4: Snapshot current preset, mutate, restore ----
#
# Capture whatever the session preset is right now (may be NULL),
# let a downstream helper mutate it, then put it back when done.
set_preset(font_size = 9, paper_size = "letter")
snapshot <- get_preset()

# Simulate downstream code mutating session state.
set_preset(font_size = 11, orientation = "landscape")

# Restore. The wholesale-install path of `set_preset(new)`
# accepts any `preset_spec` returned by `get_preset()` /
# `set_preset()`.
if (is.null(snapshot)) {
  set_preset(.reset = TRUE)
} else {
  set_preset(snapshot)
}
get_preset()@font_size    # 9 — restored
#> [1] 9

# Reset for subsequent examples / R sessions.
set_preset(.reset = TRUE)
```
