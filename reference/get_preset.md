# Get the active session-default preset

Return the `preset_spec` last attached via
[`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md),
or `NULL` when no session default has been set. The cascade resolver
calls this internally; users call it for diagnostics ("what is my
session inheriting?") or to copy the active default into a per-spec
override via
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md).

## Usage

``` r
get_preset()
```

## Value

*A `preset_spec`*, or `NULL` when no session default is active.

## See also

**Session-scope setter:**
[`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md).

**Per-spec partner:**
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md).

**Entry / terminal verbs:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md),
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md).

## Examples

``` r
# ---- Example 1: Inspect after setting a session default ----
#
# `get_preset()` returns NULL before any session default has been
# attached, then returns the `preset_spec` after `set_preset()`.
get_preset()  # NULL
#> NULL

set_preset(font_size = 8, orientation = "landscape")

active <- get_preset()
is_preset_spec(active)     # TRUE
#> [1] TRUE
active@font_size            # 8
#> [1] 8
active@orientation          # "landscape"
#> [1] "landscape"

# ---- Example 2: Copy the session default into a per-spec override ----
#
# Read the session preset, tweak one knob for a single table, and
# attach as a per-spec override without disturbing the session.
set_preset(font_size = 9, paper_size = "letter")

# Read-tweak-attach without mutating the session default.
base_knobs <- get_preset()
tabular(saf_n) |>
  preset(
    font_size   = base_knobs@font_size,
    paper_size  = base_knobs@paper_size,
    orientation = "landscape"
  )
#> <style>
#> #tabular-3a297da4ba { font-family: "Liberation Mono", "Courier New", Courier, monospace; color: #212529; margin: 1.5rem; }
#> #tabular-3a297da4ba .tabular-content { width: 100%; }
#> #tabular-3a297da4ba .tabular-title { font-size: 9pt; font-weight: 600; text-align: center; margin: .2rem 0; }
#> #tabular-3a297da4ba .tabular-pad { margin: 0; }
#> #tabular-3a297da4ba .tabular-table-wrap { overflow-x: auto; margin: .2rem 0; }
#> #tabular-3a297da4ba .tabular-table { border-collapse: collapse; font-size: 9pt; margin: 0 auto; }
#> #tabular-3a297da4ba .tabular-table th, #tabular-3a297da4ba .tabular-table td { padding: .35rem .6rem; }
#> #tabular-3a297da4ba .tabular-table td { text-align: left; vertical-align: top; }
#> #tabular-3a297da4ba .tabular-table thead th { font-weight: 600; text-align: center; vertical-align: bottom; }
#> #tabular-3a297da4ba .tabular-table thead tr:first-child th { border-top: 0.5pt solid #212529; }
#> #tabular-3a297da4ba .tabular-table thead tr:last-child th { border-bottom: 0.5pt solid #212529; }
#> #tabular-3a297da4ba .tabular-table thead .tabular-band { border-bottom: 0.5pt solid #adb5bd; }
#> #tabular-3a297da4ba .tabular-table tbody tr:last-child td { border-bottom: 0.5pt solid #212529; }
#> #tabular-3a297da4ba .tabular-table tbody tr td { border-top: none; }
#> #tabular-3a297da4ba .tabular-band { text-align: center; }
#> #tabular-3a297da4ba .tabular-subgroup td { text-align: center; vertical-align: middle; padding: .5rem .6rem; border-top: 1px solid #adb5bd; border-bottom: 1px solid #adb5bd; }
#> #tabular-3a297da4ba .tabular-subgroup-label { font-weight: 600; }
#> #tabular-3a297da4ba .tabular-group-header td { font-weight: 600; text-align: left; padding-top: .55rem; }
#> #tabular-3a297da4ba .tabular-blank-row td { padding: .25rem .6rem; border: none; }
#> #tabular-3a297da4ba .text-left { text-align: left; }
#> #tabular-3a297da4ba .text-center { text-align: center; }
#> #tabular-3a297da4ba .text-right { text-align: right; }
#> #tabular-3a297da4ba .tabular-table thead th.text-left { text-align: left; }
#> #tabular-3a297da4ba .tabular-table thead th.text-center { text-align: center; }
#> #tabular-3a297da4ba .tabular-table thead th.text-right { text-align: right; }
#> #tabular-3a297da4ba .valign-top { vertical-align: top; }
#> #tabular-3a297da4ba .valign-middle { vertical-align: middle; }
#> #tabular-3a297da4ba .valign-bottom { vertical-align: bottom; }
#> #tabular-3a297da4ba .tabular-footnote { font-size: 9pt; color: #495057; margin: .25rem 0; }
#> #tabular-3a297da4ba .tabular-empty { font-style: italic; color: #6c757d; }
#> #tabular-3a297da4ba .tabular-page-break-row { display: none; }
#> #tabular-3a297da4ba { --tabular-border-color: #212529; --tabular-border-color-muted: #adb5bd; --tabular-chrome-color: #495057; }
#> #tabular-3a297da4ba .tabular-page-header, #tabular-3a297da4ba .tabular-page-footer { display: flex; justify-content: space-between; align-items: center; padding: .5rem 0; font-size: 8pt; color: var(--tabular-chrome-color); }
#> #tabular-3a297da4ba .tabular-page-header { margin-bottom: 1rem; }
#> #tabular-3a297da4ba .tabular-page-footer { margin-top: 1rem; }
#> #tabular-3a297da4ba .tabular-page-header-left, #tabular-3a297da4ba .tabular-page-footer-left { flex: 1; text-align: left; }
#> #tabular-3a297da4ba .tabular-page-header-center, #tabular-3a297da4ba .tabular-page-footer-center { flex: 1; text-align: center; }
#> #tabular-3a297da4ba .tabular-page-header-right, #tabular-3a297da4ba .tabular-page-footer-right { flex: 1; text-align: right; }
#> @media print { #tabular-3a297da4ba .tabular-table-wrap { overflow-x: visible; margin: 0; } #tabular-3a297da4ba .tabular-table tr { page-break-inside: avoid; } #tabular-3a297da4ba .tabular-page-header, #tabular-3a297da4ba .tabular-page-footer { display: none; } #tabular-3a297da4ba .tabular-page-break-row { display: table-row; page-break-before: always; break-before: page; } #tabular-3a297da4ba .tabular-page-break-row td { border: none; padding: 0; height: 0; line-height: 0; font-size: 0; } #tabular-3a297da4ba .tabular-table + .tabular-table { page-break-before: always; break-before: page; } }
#> </style>
#> <div id="tabular-3a297da4ba" class="tabular-doc" style="overflow-x:auto;max-width:100%;"><div class="tabular-content">
#> <div class="tabular-table-wrap">
#> <table class="tabular-table" style="width:100%">
#> <thead>
#> <tr><th>arm</th><th>arm_short</th><th>n</th></tr>
#> </thead>
#> <tbody>
#> <tr><td>Placebo</td><td>placebo</td><td>86</td></tr>
#> <tr><td>Xanomeline Low Dose</td><td>drug_50</td><td>96</td></tr>
#> <tr><td>Xanomeline High Dose</td><td>drug_100</td><td>72</td></tr>
#> <tr><td style="border-bottom: 0.5pt solid #212529;">Total</td><td style="border-bottom: 0.5pt solid #212529;">Total</td><td style="border-bottom: 0.5pt solid #212529;">254</td></tr>
#> </tbody>
#> </table>
#> </div>
#> </div></div>

# Reset the session default so subsequent examples / R sessions
# are not affected.
set_preset(.reset = TRUE)
```
