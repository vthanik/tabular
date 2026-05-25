# `inst/templates/` — bundled OOXML / static assets

This directory is the single-source-of-truth for verbatim-shipped
OOXML and static assets that the DOCX backend (and future native
backends) load at render time. Assets are byte-read straight from
the installed package: no templating, no string interpolation.

The byte-deterministic read path is load-bearing for FDA-style
reproducibility — re-rendering the same `tabular_spec` on the same
package version produces a byte-identical `.docx` modulo the
mtime-pinned ZIP entries.

## Current assets

| File | OOXML section | Loaded by | Render slot |
|------|----------------|-----------|--------------|
| `theme1.xml` | ECMA-376 Part 1 §14.2.8 (`<a:theme>` — clrScheme / fontScheme / fmtScheme) | `.docx_theme_xml()` in `R/backend_docx.R` | `word/theme/theme1.xml` in every emitted `.docx` |

## Why the theme is not customisable today

`preset_spec@colors` carries five semantic tokens — `text`,
`background`, `border`, `border_muted`, `text_muted` — that drive
shading, borders, and text colour on body cells through direct
OOXML attribute overrides (`<w:shd>`, `<w:tcBorders>`, `<w:color>`).

Word's `<a:clrScheme>` carries ten slots — `dk1`, `lt1`, `dk2`,
`lt2`, `accent1` through `accent6`, `hlink`, `folHlink` — designed
to drive office-document branding (gallery themes, SmartArt fills,
hyperlink colours). The two vocabularies serve different purposes,
and the mapping from five table-semantic tokens onto ten branding
slots is opinionated either way.

Skipping theme customisation keeps the surface area small:

- Body-cell rendering already honours `preset@colors` directly
  (shading, borders, text colour), so users never reach for the
  theme to change how their tables look.
- The bundled `theme1.xml` is rendered cosmetic — it influences
  default font choices and palette panels in the Word UI, but does
  not change how the emitted table renders.
- Users with strict house-style requirements can fork
  `theme1.xml` and re-install the package, or replace
  `word/theme/theme1.xml` in the emitted `.docx` post-hoc.

This decision is intentional. If a real driver appears (a sponsor
demands theme-level branding consistency across non-table OOXML
content), the path is to add a `preset@docx_theme` knob that
parametrises `theme1.xml` directly rather than to retrofit the
existing `preset@colors` mapping.

## Byte determinism

Assets in this directory are read verbatim by `.docx_theme_xml()`
and friends. Any future templating layer must preserve byte-
identical output for an unchanged input:

- The DOCX backend pins ZIP entry mtimes to `.docx_fixed_mtime`
  (see `R/backend_docx.R`) so two re-renders of the same spec
  produce byte-identical `.docx` files.
- Hand-editing `theme1.xml` is fine — the next package install
  carries the new bytes through verbatim.
- Programmatic templating must produce deterministic XML
  (canonicalised attribute order, no microsecond timestamps, no
  random IDs).
