# Package index

## Entry verbs

Wrap a pre-summarised wide data frame into a `tabular_spec`.

- [`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
  : Start a tabular display
- [`pivot_across()`](https://vthanik.github.io/tabular/reference/pivot_across.md)
  : Convert a cards ARD to a wide display data.frame

## Spec building

Configure per-column display, header bands, sort order, and subgrouping.
Each verb attaches one slot onto the spec and returns the updated spec
for chaining.

- [`cols()`](https://vthanik.github.io/tabular/reference/cols.md) :
  Attach per-column specifications
- [`cols_apply()`](https://vthanik.github.io/tabular/reference/cols_apply.md)
  : Apply one column spec to many columns
- [`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
  : Per-column display specification
- [`headers()`](https://vthanik.github.io/tabular/reference/headers.md)
  : Attach multi-level column headers
- [`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md)
  : Sort the display rows
- [`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)
  : Partition the report by a variable

## Styling

A single
[`style()`](https://vthanik.github.io/tabular/reference/style.md) verb,
paired with one of the `cells_*()` location helpers, drives every visual
rule — body cells, headers, footnotes, page chrome, table edges. Build a
reusable house style with
[`style_template()`](https://vthanik.github.io/tabular/reference/style_template.md)
and attach it to
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md) so
every downstream table inherits the look.

- [`style()`](https://vthanik.github.io/tabular/reference/style.md) :

  Attach a style layer to a `tabular_spec` or `style_template`

- [`cells_body()`](https://vthanik.github.io/tabular/reference/cells.md)
  [`cells_headers()`](https://vthanik.github.io/tabular/reference/cells.md)
  [`cells_group_headers()`](https://vthanik.github.io/tabular/reference/cells.md)
  [`cells_title()`](https://vthanik.github.io/tabular/reference/cells.md)
  [`cells_subgroup_labels()`](https://vthanik.github.io/tabular/reference/cells.md)
  [`cells_footnotes()`](https://vthanik.github.io/tabular/reference/cells.md)
  [`cells_pagehead()`](https://vthanik.github.io/tabular/reference/cells.md)
  [`cells_pagefoot()`](https://vthanik.github.io/tabular/reference/cells.md)
  [`cells_table()`](https://vthanik.github.io/tabular/reference/cells.md)
  [`is_tabular_location()`](https://vthanik.github.io/tabular/reference/cells.md)
  :

  Cell-location constructors for
  [`style()`](https://vthanik.github.io/tabular/reference/style.md)

- [`style_template()`](https://vthanik.github.io/tabular/reference/style_template.md)
  [`is_style_template()`](https://vthanik.github.io/tabular/reference/style_template.md)
  : Reusable style template (for house-style presets)

- [`brdr()`](https://vthanik.github.io/tabular/reference/brdr.md)
  [`is_brdr()`](https://vthanik.github.io/tabular/reference/brdr.md) :
  Border-line specification

## Presets and theming

Page geometry and cosmetic defaults.
[`preset()`](https://vthanik.github.io/tabular/reference/preset.md)
overrides per spec in the pipe;
[`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md)
sets a session default;
[`preset_minimal()`](https://vthanik.github.io/tabular/reference/preset_minimal.md)
applies a stripped-down look.

- [`preset()`](https://vthanik.github.io/tabular/reference/preset.md) :
  Override the render preset on a spec
- [`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md)
  : Set or clear the session default preset
- [`get_preset()`](https://vthanik.github.io/tabular/reference/get_preset.md)
  : Get the active session-default preset
- [`preset_minimal()`](https://vthanik.github.io/tabular/reference/preset_minimal.md)
  : Minimal theme: one header rule, normal weight throughout

## Inline markup

Mark label and cell text as Markdown or HTML.

- [`md()`](https://vthanik.github.io/tabular/reference/md.md) : Mark a
  string as Markdown for inline formatting
- [`html()`](https://vthanik.github.io/tabular/reference/html.md) : Mark
  a string as HTML for inline formatting

## Footnotes

Attach an auto-numbered footnote to any `cells_*()` location. The engine
assigns the marker once, in reading order, deduped by id, and
byte-identical across every backend and page.

- [`footnote()`](https://vthanik.github.io/tabular/reference/footnote.md)
  : Attach an auto-numbered footnote to a table location

## Pagination

Configure page splits, group-run protection, and horizontal panel layout
for wide tables. Row budget per page is computed by the engine from the
active preset and the spec’s chrome.

- [`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md)
  : Configure pagination

## Rendering and inspection

Terminal verbs.
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) writes a
file;
[`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)
resolves the spec without I/O;
[`check_fonts()`](https://vthanik.github.io/tabular/reference/check_fonts.md)
and
[`check_latex()`](https://vthanik.github.io/tabular/reference/check_latex.md)
audit font and LaTeX-package availability; the print and `as.tags()`
methods drive the live HTML preview.

- [`emit()`](https://vthanik.github.io/tabular/reference/emit.md) :

  Render a `tabular_spec` to a file

- [`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)
  :

  Resolve a `tabular_spec` into a `tabular_grid`

- [`check_fonts()`](https://vthanik.github.io/tabular/reference/check_fonts.md)
  : Check font availability across backends

- [`check_latex()`](https://vthanik.github.io/tabular/reference/check_latex.md)
  : Check LaTeX-package availability for PDF output

- [`print.tabular_spec`](https://vthanik.github.io/tabular/reference/print.tabular_spec.md)
  :

  Print a `tabular_spec`

- [`as.tags(`*`<tabular_spec>`*`)`](https://vthanik.github.io/tabular/reference/as.tags.tabular_spec.md)
  :

  Convert a `tabular_spec` to an `htmltools` `tagList`

## Predicates

Class predicates for tabular’s S7 objects.

- [`tabular-package`](https://vthanik.github.io/tabular/reference/tabular-package.md)
  : tabular: Render Tables and Listings for Clinical Submissions
- [`tabular_classes`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  [`.col_spec_class`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  [`header_node`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  [`sort_spec`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  [`subgroup_spec`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  [`style_node`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  [`style_layer`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  [`style_spec`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  [`.repeat_content_values`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  [`preset_spec`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  [`tabular_spec`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  [`inline_ast`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  [`tabular_grid`](https://vthanik.github.io/tabular/reference/tabular_classes.md)
  : tabular S7 classes
- [`is_tabular_spec()`](https://vthanik.github.io/tabular/reference/tabular_predicates.md)
  [`is_tabular_grid()`](https://vthanik.github.io/tabular/reference/tabular_predicates.md)
  [`is_col_spec()`](https://vthanik.github.io/tabular/reference/tabular_predicates.md)
  [`is_header_node()`](https://vthanik.github.io/tabular/reference/tabular_predicates.md)
  [`is_sort_spec()`](https://vthanik.github.io/tabular/reference/tabular_predicates.md)
  [`is_style_node()`](https://vthanik.github.io/tabular/reference/tabular_predicates.md)
  [`is_style_layer()`](https://vthanik.github.io/tabular/reference/tabular_predicates.md)
  [`is_style_spec()`](https://vthanik.github.io/tabular/reference/tabular_predicates.md)
  [`is_pagination_spec()`](https://vthanik.github.io/tabular/reference/tabular_predicates.md)
  [`is_preset_spec()`](https://vthanik.github.io/tabular/reference/tabular_predicates.md)
  [`is_subgroup_spec()`](https://vthanik.github.io/tabular/reference/tabular_predicates.md)
  [`is_inline_ast()`](https://vthanik.github.io/tabular/reference/tabular_predicates.md)
  : Test for tabular S7 class instances

## Demo datasets

Pre-summarised wide-format tables and their upstream `cards`-format
counterparts. Power every `@examples` block, every vignette, and every
smoke test.

- [`eff_estimates`](https://vthanik.github.io/tabular/reference/eff_estimates.md)
  : Treatment-effect estimates by model
- [`eff_n`](https://vthanik.github.io/tabular/reference/eff_n.md) :
  Efficacy-population BigN per arm
- [`eff_resp`](https://vthanik.github.io/tabular/reference/eff_resp.md)
  : Best Overall Response and Response Rates
- [`saf_aeoverall`](https://vthanik.github.io/tabular/reference/saf_aeoverall.md)
  : Overall adverse-event summary, Safety Population
- [`saf_aesocpt`](https://vthanik.github.io/tabular/reference/saf_aesocpt.md)
  : Adverse events by System Organ Class and Preferred Term
- [`saf_aesocpt_card`](https://vthanik.github.io/tabular/reference/saf_aesocpt_card.md)
  : Cards hierarchical ARD for AEs by SOC and PT
- [`saf_demo`](https://vthanik.github.io/tabular/reference/saf_demo.md)
  : Demographics summary, Safety Population
- [`saf_demo_card`](https://vthanik.github.io/tabular/reference/saf_demo_card.md)
  : Cards ARD for demographics (flat ARD companion)
- [`saf_n`](https://vthanik.github.io/tabular/reference/saf_n.md) :
  Safety-population BigN per arm
- [`saf_subgroup`](https://vthanik.github.io/tabular/reference/saf_subgroup.md)
  : Vital-signs subgroup summary by Sex and Age Group
- [`saf_vital`](https://vthanik.github.io/tabular/reference/saf_vital.md)
  : Vital-signs summary
