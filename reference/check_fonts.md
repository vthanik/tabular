# Check font availability across backends

Walks the resolved font fallback chain for each backend and reports
which entries the local machine can find. Useful for answering "is the
preview I'm seeing the same fonts the downstream reviewer will see?".

## Usage

``` r
check_fonts(spec)
```

## Arguments

- spec:

  *A `tabular_spec` or `preset_spec`.*
  `<tabular_spec | preset_spec>: required`. The spec whose effective
  preset determines which font chain to walk.

## Value

*Invisibly returns the resolved per-backend chains as a named list of
character vectors.* Side effect: prints a cli tree showing the
availability marker for every entry.

## Details

The diagnostic does NOT change what
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) writes
to the file. Tabular's backends emit font *names* (CSS strings, LaTeX
`\setmainfont` commands, RTF font-table entries); the consuming
application (browser, LaTeX engine, Word, Adobe Reader) on the opening
machine resolves those names against its own installed fonts.
`check_fonts()` is purely informational — it tells you which entries of
the cross-platform fallback chain you can see on this machine, so you
can predict drift.

**Status markers:**

- `v` — font is installed on this machine (via `systemfonts`).

- `o` — font is a CSS / LaTeX generic; always resolvable by the
  consuming application.

- `x` — font is not installed on this machine; the consuming app on a
  different machine may or may not have it.

Requires the `systemfonts` package (in `Suggests`); call
`install.packages("systemfonts")` first if it isn't installed.

## See also

**Builds the spec:**
[`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md),
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md).

**Resolves the spec:**
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md),
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md).

## Examples

``` r
# ---- Example 1: Inspect default font resolution ----
#
# Build a spec with the default font_family ("mono") and ask
# which entries in the cross-platform chain are findable
# locally. Useful before sharing a render with downstream
# reviewers who may be on a different OS.
spec <- tabular(
  cdisc_saf_demo,
  titles = "Demographics"
)
if (requireNamespace("systemfonts", quietly = TRUE)) {
  check_fonts(spec)
}
#> 
#> ── Font resolution for `font_family = mono` 
#> backend: html
#> v Liberation Mono
#> x Courier New (not on this machine)
#> x Courier (not on this machine)
#> o monospace (generic, always available)
#> backend: latex
#> v Liberation Mono
#> x Courier New (not on this machine)
#> x Courier (not on this machine)
#> x TeX Gyre Cursor (not on this machine)
#> x Latin Modern Mono (not on this machine)
#> backend: rtf
#> v Liberation Mono
#> x Courier New (not on this machine)
#> x Courier (not on this machine)

# ---- Example 2: Diagnose a Courier New request ----
#
# A request for "Courier New" (a specific named font) renders
# on macOS / Windows but may fall back to a serif on Linux.
# `check_fonts()` flags this so the user knows to switch to
# the "mono" generic for portable output.
spec_mono <- tabular(
  cdisc_saf_demo,
  titles = "Mono request"
) |>
  preset(font_family = "Courier New")
if (requireNamespace("systemfonts", quietly = TRUE)) {
  check_fonts(spec_mono)
}
#> 
#> ── Font resolution for `font_family = Courier New` 
#> backend: html
#> v Liberation Mono
#> x Courier New (not on this machine)
#> x Courier (not on this machine)
#> o monospace (generic, always available)
#> backend: latex
#> v Liberation Mono
#> x Courier New (not on this machine)
#> x Courier (not on this machine)
#> x TeX Gyre Cursor (not on this machine)
#> x Latin Modern Mono (not on this machine)
#> backend: rtf
#> v Liberation Mono
#> x Courier New (not on this machine)
#> x Courier (not on this machine)

# ---- Example 3: Explicit cross-platform stack ----
#
# A length>1 input is treated as an explicit fallback chain and
# emitted verbatim — no alias lookup, no fabrication. Use this
# when the first choice is a sponsor / brand face that needs an
# honest fallback for reviewers who don't have it installed.
spec_brand <- tabular(cdisc_saf_demo) |>
  preset(font_family = c("Inter", "Liberation Sans", "Arial", "sans"))
if (requireNamespace("systemfonts", quietly = TRUE)) {
  check_fonts(spec_brand)
}
#> 
#> ── Font resolution for `font_family = Inter          , Liberation Sans, Arial          , and sans           ` 
#> backend: html
#> x Inter (not on this machine)
#> v Liberation Sans
#> x Arial (not on this machine)
#> o sans (generic, always available)
#> backend: latex
#> x Inter (not on this machine)
#> v Liberation Sans
#> x Arial (not on this machine)
#> o sans (generic, always available)
#> backend: rtf
#> x Inter (not on this machine)
#> v Liberation Sans
#> x Arial (not on this machine)
#> o sans (generic, always available)

# ---- Example 4: Compare serif vs sans fallback chains ----
#
# Side-by-side check of the two generic families. Useful when
# deciding the house-style default: the serif chain leads with
# Liberation Serif (Linux-server-first); the sans chain leads
# with Liberation Sans. Both close with the backend's native
# fallback layer (CSS generic on HTML, Latin Modern on LaTeX).
if (requireNamespace("systemfonts", quietly = TRUE)) {
  tabular(cdisc_saf_demo) |>
    preset(font_family = "serif") |>
    check_fonts()

  tabular(cdisc_saf_demo) |>
    preset(font_family = "sans") |>
    check_fonts()
}
#> 
#> ── Font resolution for `font_family = serif` 
#> backend: html
#> v Liberation Serif
#> x Times New Roman (not on this machine)
#> x Times (not on this machine)
#> o serif (generic, always available)
#> backend: latex
#> v Liberation Serif
#> x Times New Roman (not on this machine)
#> x Times (not on this machine)
#> x TeX Gyre Termes (not on this machine)
#> x Latin Modern Roman (not on this machine)
#> backend: rtf
#> v Liberation Serif
#> x Times New Roman (not on this machine)
#> x Times (not on this machine)
#> 
#> ── Font resolution for `font_family = sans` 
#> backend: html
#> v Liberation Sans
#> x Arial (not on this machine)
#> x Helvetica (not on this machine)
#> o sans-serif (generic, always available)
#> backend: latex
#> v Liberation Sans
#> x Arial (not on this machine)
#> x Helvetica (not on this machine)
#> x TeX Gyre Heros (not on this machine)
#> x Latin Modern Sans (not on this machine)
#> backend: rtf
#> v Liberation Sans
#> x Arial (not on this machine)
#> x Helvetica (not on this machine)
```
