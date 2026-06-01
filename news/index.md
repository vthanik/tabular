# Changelog

## tabular 0.0.0.9000

- Initial development. Public surface (verb signatures, S7 class shapes,
  error contracts) will churn until v0.1.0. This file is rewritten at
  first tagged release; see `git log` for live change history in the
  interim.

### HTML / MD backends — continuous document

- `backend_html` and `backend_md` render the resolved grid as one
  continuous document instead of one section per logical page. The HTML
  backend emits a single `<table>` per horizontal panel with one
  `<thead>` and one `<tbody>`; vertical-page boundaries are carried by
  invisible `<tr class="tabular-page-break-row">` markers that fire as
  `page-break-before: always` only under `@media print`. Browsers
  natively repeat `<thead>` across the resulting printed page breaks.
  The MD backend emits one pipe table per horizontal panel with all body
  rows concatenated.
- `paginate(repeat_headers = ...)` and `paginate(continuation = ...)`
  are now ignored by the HTML and MD backends — they are effective only
  for the page-oriented backends (RTF / PDF / LaTeX / DOCX), where
  per-printed-page headers and continuation markers are part of the
  regulatory output contract.
- Removed DOM / CSS classes from the HTML backend:
  `<section class="tabular-page">`, `<hr class="tabular-page-break"/>`,
  the `<!-- page N of M -->` comment, the
  `<p class="tabular-continuation">` paragraph, and the corresponding
  `.tabular-page` / `.tabular-page-break` / `.tabular-continuation` CSS
  rules. With `paginate(panels = N)` on HTML / MD output, each panel
  renders as its own table; in HTML print a single rule on
  `.tabular-table + .tabular-table` forces each subsequent panel onto a
  new printed page.

### New features

- `col_spec(indent_by = "<column_name>")` declares per-row indent depth
  on the target column. The referenced column carries integer (or
  logical) values; the engine prefixes the target column’s text + AST in
  each row with `paste(rep(preset@indent_chars, depth), collapse = "")`.
  Synthetic header rows from `group_display = "header_row"` are NEVER
  prefixed — they stay flush as the parent at depth 0.

  Typical clinical AE shape:

  ``` r

  ae$indent_level <- as.integer(ae$row_type == "pt")

  tabular(ae) |>
    cols(
      soc          = col_spec(usage = "group", group_display = "header_row"),
      label        = col_spec(label = "Category", indent_by = "indent_level"),
      indent_level = col_spec(visible = FALSE),
      row_type     = col_spec(visible = FALSE)
    )
  # Overall + SOC summary rows stay flush; PT rows indent.
  ```

  Custom indent characters via `preset(indent_chars = " ")` (4 spaces),
  `preset(indent_chars = "> ")` (custom marker), or
  `preset(indent_chars = "")` (disable). The depth column is auto-hidden
  — no need to remember `visible = FALSE` on it.

  Works in flat listings too (no `group_display = "header_row"`
  required) — any column can declare `indent_by` to drive its own
  per-row depth.

### Breaking changes (default-on indent removed)

- The PR-#2 default-on behaviour (“every data row’s host-column text
  gets a uniform `indent_chars` prefix when
  `group_display = "header_row"` is active”) is removed. Indent now
  requires explicit `col_spec(indent_by = "<col>")` on the target
  column. Rationale: the default-on prefix mis-indented overall summary
  rows and SOC summary rows in the regulatory AE pattern; the new
  mechanism puts the user in control per row.

### Breaking changes (Task 4/5 slot cut)

- `preset_spec` class drops the five list-valued slots (`@alignment`,
  `@borders`, `@fonts`, `@colors`, `@padding`). These named-list knobs
  are still accepted by
  [`preset()`](https://vthanik.github.io/tabular/reference/preset.md)
  and
  [`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md),
  but they lower to `style_layer` records on `preset_spec@style` via
  `.preset_args_to_layers()` instead of landing on a slot. Direct
  `preset_spec(borders = list(...))` / `preset_spec(fonts = list(...))`
  / etc. now raise “unused argument” — wrap the chain in
  `tabular(...) |> preset(...)` to hit the lowering.
- `colors$border`, `colors$border_muted`, and `colors$text_muted` tokens
  are rejected at validation time. Use
  `style(at = cells_table(side = "rows"), border_top = brdr(color = ...))`
  (and analogous outer / cols variants) for table-wide stroke colour;
  `style(at = cells_footnotes(), color = ...)` for muted chrome text.
- Vector-form alignment (e.g.
  `alignment = list(title_halign = c("left", "right"))`) is rejected.
  Each `_halign` / `_valign` key now accepts a single character scalar.
- LaTeX backend no longer emits the table-wide preamble
  `\definecolor{tabular_text}{HTML}{...}` +
  `\AtBeginDocument{\color{tabular_text}}` block when
  `preset(colors = list(text = ...))` is set. Per-cell `\SetCell{...}`
  carries the colour via the cells_style cascade.
- HTML backend no longer emits the `.tabular-table td { color: ... }` /
  `.tabular-table { background: ... }` /
  `.tabular-table tbody td { padding: ... }` CSS overrides when
  `preset(colors = ...)` / `preset(padding = ...)` is set. Each body
  cell’s inline `style="..."` attribute now carries the colour /
  background / padding triple stamped by the cells_body() layer.
