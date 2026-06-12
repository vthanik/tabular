# Changelog

## tabular (development version)

### Breaking changes

- [`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md)
  gained a single `indent` argument (an integer for a fixed level on
  every body row, or a column name for per-row depth); the previous
  `indent_by` argument and the `usage = "indent"` value were removed in
  favour of it. An explicit `indent` on a `group_display = "header_row"`
  host now suppresses the section auto-indent, yielding a single rather
  than double indent.
- [`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md)
  removed the no-op `panels = "auto"`; `panels` is now a positive
  integer.

### Minor improvements and bug fixes

- [`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md)
  now warns when `group_display` or `group_skip` is set on a non-group
  column (the knobs are inert unless `usage = "group"`).
- [`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md) /
  [`cols_apply()`](https://vthanik.github.io/tabular/dev/reference/cols_apply.md)
  now restore a column’s visibility and reset `group_display` on a later
  call, and merge every column attribute field-completely (previously a
  default value could not be merged back and some fields could be
  dropped).
- [`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)’s
  `decimal_metrics` knob gained `"afm"` (now the default), making
  decimal alignment width-exact in proportional fonts via the bundled
  font metrics; Markdown output keeps character padding.

## tabular 0.1.0

CRAN release: 2026-06-11

First release. `tabular` renders pre-summarised clinical tables and
listings to RTF, LaTeX, HTML, PDF, and DOCX from one immutable verb
pipeline, with no external Java or SAS dependency. This initial CRAN
version consolidates the entire pre-release development cycle: every
feature and bug fix below was designed, implemented, and tested before
this first release.

**Scope.** This release covers tables and listings. Figure (graph)
output is not yet supported and is the focus of the next release.

### Build pipeline

- [`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md)
  takes a pre-summarised wide data frame (one input row is one display
  row) plus multi-line `titles` and `footnotes`.
- [`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md) /
  [`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md)
  set per-column usage, label, format, width, alignment (including
  decimal alignment via bundled font metrics), visibility, NA text,
  per-row indent (`indent_by`), and group display.
  [`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md)
  takes a `.default` fallback
  [`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md),
  and
  [`cols_apply()`](https://vthanik.github.io/tabular/dev/reference/cols_apply.md)
  applies one
  [`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md)
  to many columns (by name or predicate), resolving a `{.name}` token in
  a label to each matched column.
- [`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md)
  builds multi-level column-header bands with passthrough leaves;
  [`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md)
  sorts on hidden numeric keys;
  [`subgroup()`](https://vthanik.github.io/tabular/dev/reference/subgroup.md)
  partitions with a `{col}` banner template and optional per-page
  `big_n`.
- [`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
  applies predicate-targeted cell styling through the `cells_*()`
  location helpers;
  [`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)
  /
  [`set_preset()`](https://vthanik.github.io/tabular/dev/reference/set_preset.md)
  /
  [`get_preset()`](https://vthanik.github.io/tabular/dev/reference/get_preset.md)
  set cosmetic defaults (fonts, colours, rules, padding, alignment, page
  chrome) per table or per session, with reusable house styles via
  [`style_template()`](https://vthanik.github.io/tabular/dev/reference/style_template.md).
- [`footnote()`](https://vthanik.github.io/tabular/dev/reference/footnote.md)
  attaches auto-numbered footnotes (letters, numbers, or symbols) to any
  cell, column header, or title, deduped by `id` and byte-identical
  across backends.
- [`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md)
  does group-aware pagination with an auto-computed per-page row budget;
  [`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md)
  writes the chosen backend (creating parent directories with
  `create_dir`), and
  [`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md)
  resolves the grid without I/O.

### Rendering

- Native emission to RTF, LaTeX, HTML, PDF (via LaTeX), and DOCX from a
  single resolved grid; output is verified by per-backend byte snapshots
  and a cross-backend CDISC-pilot qualification (`inst/qualification/`).
- Inline markup via
  [`md()`](https://vthanik.github.io/tabular/dev/reference/md.md) and
  [`html()`](https://vthanik.github.io/tabular/dev/reference/html.md).
- Glue-style `{expr}` interpolation in static labels, titles, footnotes,
  and header band labels, evaluated in the calling environment at build
  time.
- Significant-whitespace preservation across all backends
  (`preset(whitespace = "preserve")`, the default).
- [`check_latex()`](https://vthanik.github.io/tabular/dev/reference/check_latex.md)
  reports LaTeX-package availability for PDF output and prints the exact
  `tlmgr_install()` remedy for anything missing — including a
  CTAN-mirror pin (`tinytex::tlmgr_repo("auto")`) when an install stalls
  behind the redirecting default mirror (commonly on Windows);
  [`check_fonts()`](https://vthanik.github.io/tabular/dev/reference/check_fonts.md)
  does the same for fonts, per backend.

### Data

- Bundled synthetic CDISC-pilot demo data (`cdisc_saf_demo`,
  `cdisc_saf_ae`, `cdisc_saf_aesocpt`, `cdisc_saf_vital`,
  `cdisc_eff_resp`, the BigN frames `cdisc_saf_n` / `cdisc_eff_n`, and
  the long-format ARD companions `cdisc_saf_demo_ard` /
  `cdisc_saf_aesocpt_ard`) for examples and vignettes.
