# tabular (development version)

## Improvements

* `as_grid()` and `emit()` are 11-24% faster on long tables across every backend: cell inline-markup ASTs are parsed once per distinct string, style layers extract their overrides once per layer instead of per cell, subgroup splitting / decimal alignment / pagination keys are single-pass, XML/HTML escaping is vectorised, and body rows are assembled without quadratic append.

## New features

* `preset(font_family = )` generic chains (`"mono"` / `"serif"` / `"sans"`) gained the URW/Nimbus Core-35 clone (Nimbus Mono PS / Nimbus Roman / Nimbus Sans) between the PostScript name and the Liberation face, so the default still renders as Courier / Times / Helvetica on Linux images that ship only the ghostscript fonts (and whose Type 1 Courier the Typst compiler cannot read); all links are metric-compatible, so layout is unchanged wherever the chain resolves.

* `emit()` to `.tex`, `.typ`, and PDF now re-expresses plain group-separator blank rows as discardable space (a white tabularray hline band on LaTeX, a `row-gutter` entry on Typst), so a page never ends on a stray blank line above the repeated closing rule when the native page break lands at a group boundary, matching how Word renders the RTF/DOCX output; mid-page the gap keeps the blank row's exact height, and styled or ruled tables (rowrules, side frames, striped separators) keep the real blank row.

* `preset(decimal_metrics = "afm")` now measures a `font_family` with no bundled metric table (e.g. a system-installed face such as Courier 10 Pitch) through a temporary graphics device, so decimal alignment and width measurement stay exact whenever the host can resolve the font; the Times-fallback fidelity warning now fires only when that device probe also fails, and the probe can be disabled with `options(tabular.device_metrics = FALSE)`.

* `check_typst()` is a new diagnostic that audits the Typst PDF toolchain: which typst binary is discoverable (standalone `typst`, or the copy bundled inside Quarto), whether its version meets the 0.11 floor, and which families of the configured font chain the compiler can see; the chain is a fallback chain, so the check reports ready as soon as any family resolves and names the face PDFs render in. `emit()` warns after a Typst compile only when a family the user explicitly named cannot be found — missing members of the built-in cross-OS fallback chains substitute silently, matching the other backends.

* `emit()` gained a Typst backend: `emit(spec, "out.typ")` writes a standalone Typst document (native `#table` with repeating `table.header`/`table.footer`, page chrome via `#set page()` counters, native per-cell borders), and `emit(spec, "out.pdf", format = "typst")` compiles it through the standalone typst binary or Quarto's bundled copy, so PDF output no longer requires any TeX installation. The table centres on the page, the running header and footer anchor to the body edges (the header grows upward into the top margin, the footer downward, tracking the configured margins), and `paginate()`'s keep-with-next mask is enforced through unbreakable rowspans in a hidden zero-width column.

* `emit()` on a bare `.pdf` target now selects its compile engine by probing the machine, LaTeX first: a usable TeX (resolved the way the compile resolves it, and not frozen on a pre-2023 TeX Live kernel) keeps the historical LaTeX path byte-stable, a discoverable typst binary takes over otherwise, and with neither engine the call aborts up front naming both remedies; `format = "latex"` / `format = "typst"` pick the engine explicitly.

* `check_latex()` now reports the TeX Live release year of the active `xelatex` and fails the check when it predates 2023, the first release whose LaTeX kernel (2022-11-01) can load the bundled tabularray; the report and the `emit()` PDF compile error both explain the update / user-space TinyTeX remedy for images frozen on an old TeX Live.

* `check_latex()` and the PDF pre-compile staging now resolve TeX the same way the compile does, preferring a TinyTeX at the standard root (installed by either `tinytex::install_tinytex()` or `quarto install tinytex`) over the `PATH`, so the diagnostic can no longer describe a different TeX than the one `emit()` actually runs; remediation hints name the `quarto install tinytex` route, which downloads from GitHub and therefore works behind proxies that block CTAN.

* `cols()` accepts a bare string as label shorthand (`soc = "SOC / PT"` is `soc = col_spec(label = "SOC / PT")`, including glue interpolation and the deferred `{.name}` token) and a `.hide` argument that hides the named columns in one flat vector.

* `paginate()` keep-together protection on the natively-paginating backends (RTF, DOCX) now emits edge-only row glue instead of gluing a whole fitting block, so a block that fits a fresh page but not the space left on the current one no longer bumps wholesale and strands a near-empty page; widow/orphan floors count content rows only, with trailing blank spacer rows still riding with their block.

* `paginate(keep_together = )` now accepts any column of `data` (including hidden block-key columns), not only `usage = "group"` columns.

## Breaking changes

* `col_spec()` no longer has `usage`, `group_display`, or `group_skip` arguments; row grouping is a table-level fact and is now declared once with the new `group_rows()` verb. The inert-knob warning for `group_display`/`group_skip` on non-group columns is gone with them.

* `group_rows()` is the new structural verb: `group_rows(by, display, skip)` names only the structural grouping keys outer to inner (the section headers and any hidden break keys, not the visible label column, which stays an ordinary `cols()` column and is auto-indented). `display` is a single value applied to every key (`"section"`, `"collapse"`, or `"repeat"`); a hidden break-only key is expressed with `col_spec(visible = FALSE)` rather than a display mode. `skip` follows the `readr::read_csv(col_names = )` pattern: `TRUE` (the default) derives the blank spacers from `display` and key visibility, `FALSE` inserts none, and a character subset of `by` breaks on exactly those keys (e.g. `skip = "param"`). Nesting is just listing the header keys (`by = c("param", "visit")`). It replaces a prior declaration wholesale, and its keys may not overlap `subgroup(by = )`.

* `paginate()` gained `repeat_cols`, replacing the `usage = "id"` role: the horizontal-panel stub defaults to the visible `group_rows()` keys, and an explicit `repeat_cols` vector replaces that default.

## Minor improvements and bug fixes

* DESCRIPTION's SystemRequirements no longer contains the bare word "LaTeX", which pak's system-requirements scraper matched and answered by force-installing the `texlive` OS package (a sudo failure on locked-down hosts such as Domino); the TeX distribution remains optional for PDF output.

* Fidelity warnings now render their feature string as inline code instead of a quoted value, so a feature that itself contains quotes (`decimal_metrics = "afm"`) no longer prints with escaped quotes.

* `check_latex()` now probes package availability through `kpsewhich` (the resolver xelatex itself uses) instead of the tlmgr package database, fixing all-missing false negatives on apt-installed TeX Live and frozen TinyTeX images, no longer requires the tinytex R package, and reports a new `bundled` column.

* `emit()` to DOCX now stamps the body's left/right cell margins on section-header, blank-spacer, column-header, and subgroup-banner cells, so their text aligns with body text exactly as in RTF (section headers previously sat one cell margin further left, making nested indents read one character too wide in Word).

* `emit()` to Typst now folds 2+ space runs in body cells under `preset(whitespace = "collapse")`; the no-wrap hardening previously rewrote the run to non-breaking spaces first, so the knob was a silent no-op on Typst while every other backend honoured it.

* `emit()` to Typst now stamps the header surface background and padding on the column-label cells, so `preset(colors = list(header = ...))`, `preset(padding = list(header = ...))`, and the equivalent `style()` at `cells_headers()` render as they do on RTF, HTML, LaTeX, and DOCX.

* `emit()` to LaTeX/PDF and Typst now places the running header band so its bottom edge sits exactly on the top-margin line, growing upward into the margin, and keeps the body at exactly the configured top margin — matching the RTF and DOCX placement; the LaTeX head lengths moved onto the `geometry` option list (a post-load `\setlength{\headsep}` shifted the body off the margin instead of moving the header) and every band row now carries a `\strut` so the band's bottom edge no longer depends on descenders in its content.

* `emit()` to HTML and Markdown no longer drops a `group_rows()` blank spacer when a group transition coincides with a page boundary; the continuous flow keeps every spacer and only the very first row of the table suppresses one.

* `emit()` to Markdown now renders the indent of nested section headers as `&nbsp;` before the bold markers instead of spaces inside them, which CommonMark refused to parse as bold (literal `**` showed in the render).

* `emit()` to PDF now writes to a relative `file` path correctly; the path was previously resolved after switching into the temporary compile directory, so the output landed there and was deleted with it.

* `emit()` to RTF now resolves the row cell gap of header-band, column-label, blank-spacer, section-header, banner, and title rows from `preset(cell_padding = )` like body rows do (previously hardcoded, so a non-default padding skewed header text relative to body text).

* `figure()` output no longer spills onto a blank trailing page in Word: the RTF closing paragraph after the full-page image row now carries the body font size (a bare paragraph rendered at RTF's 12pt default, taller than the reserved row), and the page-size model now budgets the `preset(pagefoot = )` slot rows (and any `pagehead` rows that overflow the top margin), which intrude into the body exactly like footnote lines. The same budget applies to table pagination.

* `emit()` PDF output now works on TeX installations that lack `tabularray` / `ninecolors` and cannot run `tlmgr install` (locked-down Domino / Posit Workbench images): tabular ships verbatim CTAN copies of both single-file packages in `inst/tex/` and stages them next to the generated `.tex` at compile time whenever the local TeX cannot resolve them.

# tabular 0.2.0

## New features

* The documentation site gained an AI / Agents section linking a tabular skill
  (for LLM coding agents), the auto-generated `llms.txt`, and a concatenated
  `llms-full.txt`, mirroring the LLM-friendly documentation pattern.

* `col_spec(group_display = "header_row")` now collapses a single-member group
  to one flush-left row (the group value becomes the row label, still carrying
  any `cells_group_headers()` styling) instead of emitting a redundant header
  plus a lone indented child, and no longer emits an empty header for a blank
  or `NA` group value. Multi-member groups are unchanged.

* `figure()` renders a figure (the "F" in TFL) to every backend (RTF, LaTeX,
  PDF, HTML, DOCX, and Markdown), wrapping a ggplot, a recorded base-R plot, a
  zero-argument drawing function, or a PNG / JPG file in the same submission
  chrome as a table (titles, footnotes, page header and footer). The image is
  placed in the body content-box by `halign` and `valign` (both default to
  centred), exact on the paged backends and approximate on the continuous
  ones. A list input emits one figure per page, optionally driven by a `meta`
  data frame whose columns become per-page `{token}` values. On the continuous
  backends (HTML and Markdown) a multi-page figure's shared titles and
  footnotes render once above the stacked plots; supplying `meta` switches to
  per-page chrome. `is_figure_spec()` tests for the new spec, and `emit()`
  writes it to a file. A figure's titles, footnotes, and page header / footer
  honour `style()` and the `preset()` cosmetic knobs (fonts, colours,
  alignment, padding) and the `preset(spacing = ...)` inter-section gaps, just
  like a table; styling its (absent) body, headers, or subgroup is an error. A
  drawing function that raises an error aborts with a clear message naming the
  failing page. No new package dependency: plots rasterise through base
  `grDevices` and ggplot2 (Suggests) only when a ggplot is passed.

* `pivot_across()` gained an `aux` argument to bind auxiliary comparison
  columns (difference, hazard ratio, p-value) from a second ARD, aligned 1:1 on
  the `row_group` key and appended as trailing columns.

* `pivot_across()`'s `column` argument now accepts the reserved tokens
  `.variable` and `.stat` to make an analysis variable a column band:
  `c(".variable", "<arm>")` lays variables side by side with statistics as rows,
  and `c(".variable", ".stat")` spreads each statistic into its own column with
  the arm as a row stub. Per-variable `statistic` / `decimals` resolve inside
  each band.

* `pivot_across()`'s `decimals` may now be a list keyed by `row_group` values,
  for per-group precision in one call.

* `preset(font_family = ...)` generic chains (`"mono"` / `"sans"` / `"serif"`)
  now lead with the ubiquitous Microsoft Office face (Courier New / Arial /
  Times New Roman) and keep the metric-compatible Liberation face as the last
  fallback, so Word shows a font the reader actually has installed on Windows /
  macOS instead of a phantom "Liberation Mono" in its font menu. The faces are
  metric-compatible, so layout, line breaks, and decimal alignment are
  unchanged. A bare `font_family = "Courier New"` now also leads with Courier
  New (previously resolved led by Liberation Mono). The package bundles no
  fonts; an arbitrary named face (`"IBM Plex Mono"`, `"Source Code Pro"`, etc.)
  is emitted verbatim for the consuming application to resolve.

## Breaking changes

* `col_spec()` gained a single `indent` argument (an integer for a fixed
  level on every body row, or a column name for per-row depth); the previous
  `indent_by` argument and the `usage = "indent"` value were removed in favour
  of it. An explicit `indent` on a `group_display = "header_row"` host now
  suppresses the section auto-indent, yielding a single rather than double
  indent.
* `paginate()` removed the no-op `panels = "auto"`; `panels` is now a positive
  integer.
* `pivot_across()` no longer pre-indents `stat_label` with two leading spaces;
  indentation is applied downstream by the renderer via
  `col_spec(usage = "group")` / `group_display`, so a `header_row` stub no
  longer double-indents.

## Minor improvements and bug fixes

* Every warning now carries a `tabular_warning_<kind>` class (`input`,
  `runtime`, `layout`, `fidelity`) mirroring the `tabular_error_<kind>` error
  taxonomy, so warnings can be caught selectively; the former
  `tabular_warn_layout` class was renamed to `tabular_warning_layout`.
* `col_spec()` now warns when `group_display` or `group_skip` is set on a
  non-group column (the knobs are inert unless `usage = "group"`).
* `cols()` / `cols_apply()` now restore a column's visibility and reset
  `group_display` on a later call, and merge every column attribute
  field-completely (previously a default value could not be merged back and
  some fields could be dropped).
* `emit()` now centres decimal-aligned columns on every backend instead of
  right-aligning the uniformly NBSP-padded block, so the values sit under the
  centred column header (cross-backend parity).
* `emit()` to DOCX now declares an in-class `<w:altName>` fallback for each
  font, so a reader missing the primary face substitutes a metric-compatible
  face in the same class (mono stays mono) instead of panose-guessing to a
  serif. This brings DOCX in line with the RTF (`\*\falt`) and PDF / LaTeX
  (`\IfFontExistsTF` cascade) backends, which already declared the same
  in-class fallback chain.
* `emit()` to HTML now applies per-cell body alignment through a
  specificity-bumped `.tabular-table td.text-*` rule, so decimal, centred and
  right-aligned columns actually render aligned; previously the base
  `.tabular-table td { text-align: left }` rule outranked the plain alignment
  class and every body cell silently fell back to left.
* `emit()` to HTML now aligns the running page header and footer to the table
  width via a centred fit-content container, instead of spanning the full
  document width.
* `emit()` to HTML and Markdown no longer repeats a `subgroup()` banner
  mid-table when a group is taller than one estimated page. The continuous
  backends draw one banner per subgroup value; the print-only page-break
  markers within a group are unchanged, and the paged backends (RTF, LaTeX,
  DOCX) still repeat the banner on every continuation page by design.
* `emit()` to PDF / LaTeX no longer renders the table wider than the printable
  area: tabularray adds per-column separation outside each column's `wd`, so
  the column widths are now reduced by that separation and the rendered table
  total matches the resolved width (and the RTF / DOCX cell widths) instead of
  bleeding into the right margin. (#27)
* `emit()` to PDF / LaTeX now renders column headers in bold, matching the
  DOCX, RTF and HTML backends.
* `emit()` to PDF / LaTeX now sets the body font size after `\begin{document}`
  (where it survives) and re-asserts it inside the running header / footer, so
  an 8pt table no longer renders its body or page chrome at the 10pt
  document-class default. (#27)
* `emit()` to PDF / LaTeX now tightens the gap between a running page header
  and the title (and body to a running footer) to one line via `\headsep` and
  `\footskip`, instead of the wide document-class default.
* `emit()` to PDF / LaTeX no longer overflows a figure onto a second page:
  the image is placed with flexible `\vfill` glue rather than a fixed-height
  box that reconstructed to just over the page height, so a multi-page figure
  (for example one Kaplan-Meier plot per treatment arm) now fits one page per
  plot.
* `emit()` to RTF and DOCX no longer emits a phantom blank page after each
  figure plot. The figure box reserves a line for the closing paragraph every
  paged backend appends after the exact-height image, RTF exits table context
  with `\pard\par` before the next section break, and DOCX starts each
  continuation page with a structural `<w:pageBreakBefore/>` instead of a
  standalone page-break paragraph that stranded a blank page. A multi-page
  figure driven by per-page `meta` also sizes each page's image box from that
  page's interpolated footnotes, so a longer-footnote page no longer overflows.
* `emit()` aborts with a clear `tabular_error_layout` message when a figure's
  titles and footnotes alone exceed the printable height, instead of failing
  with an opaque graphics-device error.
* `emit()` to RTF now leads the body font slot with the first face of an
  explicit `font_family` stack instead of the Linux-first default chain, and
  classes a mono stack `\fmodern` (fixed pitch) the same way DOCX classes it
  `modern`. A `font_family = c("Courier New", "Liberation Mono", "Courier")`
  request now renders as Courier New mono in Word instead of substituting a
  serif, because the named primary face leads the font table rather than being
  demoted to a `\*\falt` alternate.
* `emit()` to RTF now emits a section break only BETWEEN panels (n-1 breaks for
  n panels) rather than after every panel, so a single-panel table no longer
  ends with a trailing section break that Word renders as a phantom blank page.
* `emit()` to RTF now reserves one line per running-header row in `\headery`,
  so a multi-row page header (for example a protocol row plus an analysis-set
  row) no longer bleeds back into the body and tips the last table rows, or the
  table's trailing paragraph, onto a phantom second page.
* `emit()` now renders a zero-row empty-state page as a normal table whose
  body is a single full-span, horizontally centred "no data" message row, where
  the first data row would sit: the table chrome (titles, column header) leads,
  the message follows in the body, and the footnote trails immediately, all
  flowing compactly at the top of the page with blank space below. The message
  is centred by each backend's native cell alignment on every backend (RTF,
  LaTeX, PDF, HTML, DOCX, Markdown); it is no longer vertically centred or
  relocated into the page margins. A natural-height message row plus trailing
  footnote cannot overflow, so the recurring phantom-page bug stays fixed. A
  `subgroup(keep_empty = TRUE)` empty crossing renders the same way, as one
  message row in its own panel.
* `emit()` now closes a zero-row empty-state table's data region with the body
  bottom rule on every backend, so the "no data" page carries the same closing
  rule a populated table does. The rule follows the `rules` preset (a custom
  `bottomrule` width / style / colour is honoured, and `bottomrule = "none"`
  drops it) instead of being absent (RTF / DOCX) or a fixed default.
* `emit()` to PDF / LaTeX now wraps a table footnote to the table width rather
  than overrunning it: the footnote minipage no longer double-counts the column
  separation that the column widths already fold in, so on a narrow table the
  footnote text stays within the table-width footnote rule instead of spilling
  past it (and past the printable width).
* `figure()` and paged-table pagination now size the body box from the number
  of wrapped chrome lines a long title or footnote actually occupies at the
  printable width, not the element count, so a wrapped footnote no longer pushes
  content onto a second page on DOCX (and any paged backend). Wrapping is
  computed by greedy word packing against the font metrics. (#26)
* `paginate()` now collapses a zero-row table to a single empty-state page;
  horizontal `panels` no longer multiply an empty table into several identical
  blank pages.
* `pivot_across()` now resolves a keyed `statistic` (e.g.
  `list(hierarchical = "{n} ({p}%)")`) against each row's real ARD context on
  the hierarchical path, so a list keyed by `hierarchical` no longer falls
  through to the bare `{n}` default and silently drops the percent.
* `pivot_across()` now warns when the `overall` label collides with an existing
  arm name, instead of silently merging the pooled rows into that arm's column.
* `preset()`'s `decimal_metrics` knob gained `"afm"` (now the default), making
  decimal alignment width-exact in proportional fonts via the bundled font
  metrics; Markdown output keeps character padding.
* `preset()` gained an `empty_text` knob, a house-style default for the
  zero-row message that a per-table `tabular(empty_text = ...)` still overrides.
* `preset(spacing = ...)` now drives the blank lines around a subgroup banner
  (the `subgroup` region) and around a `figure()` title and footnote; the
  Markdown table title and footnote gaps now follow the same knob.
* `preset(width_mode = "window")` now sizes auto columns proportionally to
  their content width to fill the page, instead of giving every column an
  equal share.
* `subgroup()` gained a `keep_empty` argument; with `keep_empty = TRUE` a
  zero-N crossing is retained and rendered as an empty-state page carrying its
  banner instead of being dropped.
* `subgroup()` no longer errors on a zero-row input; the table renders the
  empty-state placeholder once with no subgroup banner.
* `tabular()` gained `empty_text`, the message shown when a table has zero
  data rows (default "No data available to report"). Zero-row tables now
  render the full page chrome and the column headers with the message placed
  in the body, replacing the previous bare "(no rows)" marker.

# tabular 0.1.0

First release. `tabular` renders pre-summarised clinical tables and listings to
RTF, LaTeX, HTML, PDF, and DOCX from one immutable verb pipeline, with no
external Java or SAS dependency. This initial CRAN version consolidates the
entire pre-release development cycle: every feature and bug fix below was
designed, implemented, and tested before this first release.

**Scope.** This release covers tables and listings. Figure (graph) output is not
yet supported and is the focus of the next release.

## Build pipeline

* `tabular()` takes a pre-summarised wide data frame (one input row is
  one display row) plus multi-line `titles` and `footnotes`.
* `cols()` / `col_spec()` set per-column usage, label, format, width,
  alignment (including decimal alignment via bundled font metrics),
  visibility, NA text, per-row indent (`indent_by`), and group display.
  `cols()` takes a `.default` fallback `col_spec()`, and `cols_apply()`
  applies one `col_spec()` to many columns (by name or predicate),
  resolving a `{.name}` token in a label to each matched column.
* `headers()` builds multi-level column-header bands with passthrough
  leaves; `sort_rows()` sorts on hidden numeric keys; `subgroup()`
  partitions with a `{col}` banner template and optional per-page `big_n`.
* `style()` applies predicate-targeted cell styling through the
  `cells_*()` location helpers; `preset()` / `set_preset()` /
  `get_preset()` set cosmetic defaults (fonts, colours, rules, padding,
  alignment, page chrome) per table or per session, with reusable house
  styles via `style_template()`.
* `footnote()` attaches auto-numbered footnotes (letters, numbers, or
  symbols) to any cell, column header, or title, deduped by `id` and
  byte-identical across backends.
* `paginate()` does group-aware pagination with an auto-computed
  per-page row budget; `emit()` writes the chosen backend (creating
  parent directories with `create_dir`), and `as_grid()` resolves the
  grid without I/O.

## Rendering

* Native emission to RTF, LaTeX, HTML, PDF (via LaTeX), and DOCX from a
  single resolved grid; output is verified by per-backend byte snapshots
  and a cross-backend CDISC-pilot qualification (`inst/qualification/`).
* Inline markup via `md()` and `html()`.
* Glue-style `{expr}` interpolation in static labels, titles, footnotes,
  and header band labels, evaluated in the calling environment at build
  time.
* Significant-whitespace preservation across all backends
  (`preset(whitespace = "preserve")`, the default).
* `check_latex()` reports LaTeX-package availability for PDF output and
  prints the exact `tlmgr_install()` remedy for anything missing — including a
  CTAN-mirror pin (`tinytex::tlmgr_repo("auto")`) when an install stalls behind
  the redirecting default mirror (commonly on Windows); `check_fonts()` does the
  same for fonts, per backend.

## Data

* Bundled synthetic CDISC-pilot demo data (`cdisc_saf_demo`,
  `cdisc_saf_ae`, `cdisc_saf_aesocpt`, `cdisc_saf_vital`,
  `cdisc_eff_resp`, the BigN frames `cdisc_saf_n` / `cdisc_eff_n`, and the
  long-format ARD companions `cdisc_saf_demo_ard` / `cdisc_saf_aesocpt_ard`)
  for examples and vignettes.
