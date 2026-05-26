# tabular 0.0.0.9000

* Initial development. Public surface (verb signatures, S7 class
  shapes, error contracts) will churn until v0.1.0. This file is
  rewritten at first tagged release; see `git log` for live change
  history in the interim.

## Breaking changes (Task 4/5 slot cut)

* `preset_spec` class drops the five list-valued slots
  (`@alignment`, `@borders`, `@fonts`, `@colors`, `@padding`).
  These named-list knobs are still accepted by `preset()` and
  `set_preset()`, but they lower to `style_layer` records on
  `preset_spec@style` via `.preset_args_to_layers()` instead of
  landing on a slot. Direct `preset_spec(borders = list(...))` /
  `preset_spec(fonts = list(...))` / etc. now raise "unused
  argument" — wrap the chain in `tabular(...) |> preset(...)` to
  hit the lowering.
* `colors$border`, `colors$border_muted`, and `colors$text_muted`
  tokens are rejected at validation time. Use
  `style(at = cells_table(side = "rows"), border_top = brdr(color = ...))`
  (and analogous outer / cols variants) for table-wide stroke
  colour; `style(at = cells_footnotes(), color = ...)` for muted
  chrome text.
* Vector-form alignment (e.g.
  `alignment = list(title_halign = c("left", "right"))`) is
  rejected. Each `_halign` / `_valign` key now accepts a single
  character scalar.
* LaTeX backend no longer emits the table-wide preamble
  `\definecolor{tabular_text}{HTML}{...}` +
  `\AtBeginDocument{\color{tabular_text}}` block when
  `preset(colors = list(text = ...))` is set. Per-cell
  `\SetCell{...}` carries the colour via the cells_style cascade.
* HTML backend no longer emits the `.tabular-table td { color: ... }`
  / `.tabular-table { background: ... }` /
  `.tabular-table tbody td { padding: ... }` CSS overrides when
  `preset(colors = ...)` / `preset(padding = ...)` is set. Each
  body cell's inline `style="..."` attribute now carries the colour
  / background / padding triple stamped by the cells_body() layer.
