# Reusable style template (for house-style presets)

Build a reusable, composable style template by chaining
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
calls against a `tabular_style_template`. The template carries an
ordered list of
[`style_layer`](https://vthanik.github.io/tabular/dev/reference/tabular_classes.md)
records and can be attached to
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)
/
[`set_preset()`](https://vthanik.github.io/tabular/dev/reference/set_preset.md)
as a `style =` argument — every downstream
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md)
chain then inherits the template's layers via the engine cascade.

## Usage

``` r
style_template()

is_style_template(x)
```

## Arguments

- x:

  *Any R object.* The predicate inspects the class via
  [`inherits()`](https://rdrr.io/r/base/class.html); no other
  introspection is performed.

## Value

*A `tabular_style_template`* — a small S3 list with a `layers` slot.
Pipe through
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md) to
add layers.

## Details

**One verb, two surfaces.** The same
`style(.spec_or_template, ..., .at = ...)` call that attaches a layer to
a per-table spec also accumulates layers onto a template. Symmetric API
— no need to learn a second function for the multi-table use case.

**Submission workflow.** A submission typically renders 100–200 tables
with one visual identity. Build the template once at the top of the
submission script, pass it to `set_preset(style = template)`, and every
subsequent
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md)
produces output that inherits the same column-header rules, group-header
bolding, title spacing, and outer-frame borders without a single
per-table
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
call.

**Cascade order.** Engines apply layers low-to-high priority: backend
defaults → session preset's `@style` → spec preset's `@style` → per-spec
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
layers. Later layers override prior ones per attribute; NA fields leave
the prior layer's value in place.

## See also

**Style verb:**
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md) —
the same verb chains onto a spec or a template.

**Locations:**
[`cells_body`](https://vthanik.github.io/tabular/dev/reference/cells.md)
— locations that name the *where* half of every layer.

## Examples

``` r
# ---- Sponsor "house style" composed once ----
#
# The result becomes the default look for every table rendered
# against this preset. No per-table style() boilerplate.
house <- style_template() |>
  style(background = "#DBE4F0", .at = cells_headers(level = -1)) |>
  style(color = "#1F3B5C", .at = cells_group_headers()) |>
  style(
    border_top    = brdr("thick", "double"),
    border_bottom = brdr("thick", "double"),
    .at = cells_headers()
  ) |>
  style(blank_above = 1, blank_below = 1, .at = cells_title())

length(house$layers)
#> [1] 4

# ---- Verify class ----
is_style_template(house)
#> [1] TRUE
```
