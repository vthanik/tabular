# tabular (development version)

## New features

* `check_latex()` reports LaTeX-package availability for PDF output and prints the exact `tlmgr_install()` remedy for anything missing.
* `cols()` gains a `.default` argument that sets a fallback `col_spec()` for columns not named explicitly.
* `cols_apply()` applies one `col_spec()` to many columns selected by name or by predicate.
* `emit()` gains `create_dir` to create missing parent directories instead of erroring.

## Bug fixes

* The DOCX backend now honours the `halign` cascade on group-header rows instead of always left-aligning them.
* The PDF backend now declares its full LaTeX package set, so a missing-dependency error names every required package.
* The RTF backend now renders `pagehead` / `pagefoot` page chrome at the preset `font_size` instead of the RTF default 12pt.
* `pivot_across()` no longer silently drops `ard_tabulate()` categorical rows from a mixed `ard_stack()` ARD.

# tabular 0.1.0

First release.

`tabular` renders pre-summarised clinical tables and listings to RTF,
LaTeX, HTML, PDF, and DOCX from one immutable verb pipeline, with no
external Java or SAS dependency.

**Scope.** This release covers tables and listings. Figure (graph)
output is not yet supported and is the focus of the next release.

## Build pipeline

* `tabular()` takes a pre-summarised wide data frame (one input row is
  one display row) plus multi-line `titles` and `footnotes`.
* `cols()` / `col_spec()` set per-column usage, label, format, width,
  alignment (including decimal alignment via bundled font metrics),
  visibility, NA text, per-row indent (`indent_by`), and group display.
* `headers()` builds multi-level column-header bands with passthrough
  leaves; `sort_rows()` sorts on hidden numeric keys; `subgroup()`
  partitions with a `{col}` banner template.
* `style()` applies predicate-targeted cell styling through the
  `cells_*()` location helpers; `preset()` / `set_preset()` /
  `get_preset()` set cosmetic defaults (fonts, colours, rules, padding,
  alignment, page chrome) per table or per session.
* `footnote()` attaches auto-numbered footnotes (letters, numbers, or
  symbols) to any cell, column header, or title, deduped by `id` and
  byte-identical across backends.
* `paginate()` does group-aware pagination with an auto-computed
  per-page row budget; `emit()` writes the chosen backend, and
  `as_grid()` resolves the grid without I/O.

## Rendering

* Native emission to RTF, LaTeX, HTML, PDF (via LaTeX), and DOCX from a
  single resolved grid; output is verified by per-backend byte snapshots.
* Inline markup via `md()` and `html()`.
* Glue-style `{expr}` interpolation in static labels, titles, footnotes,
  and header band labels, evaluated in the calling environment at build
  time.
* Significant-whitespace preservation across all backends
  (`preset(whitespace = "preserve")`, the default).

## Data

* Bundled synthetic CDISC-pilot demo data (`saf_demo`, `saf_aeoverall`,
  `saf_aesocpt`, `saf_vital`, `eff_resp`, and BigN frames `saf_n` /
  `eff_n`) for examples and vignettes.
