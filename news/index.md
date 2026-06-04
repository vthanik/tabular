# Changelog

## tabular 0.1.0

First release.

`tabular` renders pre-summarised clinical tables, listings, and figures
to RTF, LaTeX, HTML, PDF, and DOCX from one immutable verb pipeline,
with no external Java or SAS dependency.

### Build pipeline

- [`tabular()`](https://vthanik.github.io/tabular/reference/tabular.md)
  takes a pre-summarised wide data frame (one input row is one display
  row) plus multi-line `titles` and `footnotes`.
- [`cols()`](https://vthanik.github.io/tabular/reference/cols.md) /
  [`col_spec()`](https://vthanik.github.io/tabular/reference/col_spec.md)
  set per-column usage, label, format, width, alignment (including
  decimal alignment via bundled font metrics), visibility, NA text,
  per-row indent (`indent_by`), and group display.
- [`headers()`](https://vthanik.github.io/tabular/reference/headers.md)
  builds multi-level column-header bands with passthrough leaves;
  [`sort_rows()`](https://vthanik.github.io/tabular/reference/sort_rows.md)
  sorts on hidden numeric keys;
  [`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md)
  partitions with a `{col}` banner template.
- [`style()`](https://vthanik.github.io/tabular/reference/style.md)
  applies predicate-targeted cell styling through the `cells_*()`
  location helpers;
  [`preset()`](https://vthanik.github.io/tabular/reference/preset.md) /
  [`set_preset()`](https://vthanik.github.io/tabular/reference/set_preset.md)
  /
  [`get_preset()`](https://vthanik.github.io/tabular/reference/get_preset.md)
  set cosmetic defaults (fonts, colours, rules, padding, alignment, page
  chrome) per table or per session.
- [`footnote()`](https://vthanik.github.io/tabular/reference/footnote.md)
  attaches auto-numbered footnotes (letters, numbers, or symbols) to any
  cell, column header, or title, deduped by `id` and byte-identical
  across backends.
- [`paginate()`](https://vthanik.github.io/tabular/reference/paginate.md)
  does group-aware pagination with an auto-computed per-page row budget;
  [`emit()`](https://vthanik.github.io/tabular/reference/emit.md) writes
  the chosen backend, and
  [`as_grid()`](https://vthanik.github.io/tabular/reference/as_grid.md)
  resolves the grid without I/O.

### Rendering

- Native emission to RTF, LaTeX, HTML, PDF (via LaTeX), and DOCX from a
  single resolved grid; output is verified by per-backend byte
  snapshots.
- Inline markup via
  [`md()`](https://vthanik.github.io/tabular/reference/md.md) and
  [`html()`](https://vthanik.github.io/tabular/reference/html.md).
- Glue-style `{expr}` interpolation in static labels, titles, footnotes,
  and header band labels, evaluated in the calling environment at build
  time.
- Significant-whitespace preservation across all backends
  (`preset(whitespace = "preserve")`, the default).

### Data

- Bundled synthetic CDISC-pilot demo data (`saf_demo`, `saf_aeoverall`,
  `saf_aesocpt`, `saf_vital`, `eff_resp`, and BigN frames `saf_n` /
  `eff_n`) for examples and vignettes.
