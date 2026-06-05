# Output & qualification: backends, requirements, and the CDISC pilot

This article is about *rendering and proving* — choosing a backend,
meeting its system requirements, and the cross-backend validation. It
does not cover building or styling a table (see the other articles).

## `emit()` and `as_grid()`

[`emit()`](https://vthanik.github.io/tabular/reference/emit.md) writes a
file, dispatching on the extension:

``` r

emit(spec, "table.rtf") # RTF
emit(spec, "table.html") # HTML
emit(spec, "table.docx") # Word
emit(spec, "table.pdf") # PDF (via LaTeX)
emit(spec, "table.md") # Markdown
```

`as_grid(spec)` resolves the fully-laid-out grid **without** writing a
file — useful for testing or programmatic inspection.

## Backend capability matrix

One spec renders to every backend, but the page-oriented features
differ:

| Capability | RTF | HTML | DOCX | PDF/LaTeX | MD |
|----|:--:|:--:|:--:|:--:|:--:|
| Vertical pagination | ✓ | n/a¹ | ✓ | ✓ | n/a |
| Horizontal panels (`panels=`) | ✓ | n/a¹ | ✓ | ✓ | n/a |
| Per-page running header/footer | ✓ | – | ✓ | ✓ | – |
| [`subgroup()`](https://vthanik.github.io/tabular/reference/subgroup.md) per-page BigN | ✓ | row² | ✓ | ✓ | row² |
| Continuation marker | panels only | – | – | ✓ | – |
| Decimal alignment (NBSP) | ✓ | ✓ | ✓ | ✓ | ✓ |
| System dependency | none | none | none | LaTeX | none |

¹ HTML/MD are one continuous document; the browser repeats `<thead>` on
print.

² On HTML/MD the per-page N renders as a row under each subgroup banner
instead of in the repeating header.

## System requirements

**RTF, HTML, DOCX, Markdown need nothing beyond the R package.** Only
PDF has a system dependency — a LaTeX engine plus the packages the
backend uses (`tabularray`, `ninecolors`, `siunitx`, `tex-gyre`, …).
Check and install:

``` r

check_latex() # reports what's missing + the exact command
tinytex::tlmgr_install(c("tabularray", "ninecolors", "siunitx", "tex-gyre"))
```

> **OS-managed TeX Live (RHEL/dnf, Debian/apt):** `tlmgr` is locked and
> refuses to install (“will likely destroy the … TeXLive install”). Do
> **not** force it with `--ignore-warning`. Install a user-space TinyTeX
> you control instead:
> [`tinytex::install_tinytex()`](https://rdrr.io/pkg/tinytex/man/install_tinytex.html),
> restart R, then `tlmgr_install(...)`.

For decimal alignment in paper backends, metric-compatible fonts matter
— check with
[`check_fonts()`](https://vthanik.github.io/tabular/reference/check_fonts.md).

## Troubleshooting

- **A relative DOCX path works.** `emit(spec, "out/x.docx")` resolves
  the path against your working directory like every other backend (the
  output path is absolutised before the OOXML zip is staged). No
  [`normalizePath()`](https://rdrr.io/r/base/normalizePath.html) dance
  is needed.
- **If a PDF build appears to hang,** it is the LaTeX engine stopping at
  an interactive error prompt — fix the underlying LaTeX dependency (run
  [`check_latex()`](https://vthanik.github.io/tabular/reference/check_latex.md));
  render RTF/HTML to keep working in the meantime.

## Cross-backend qualification (CDISC pilot)

The package ships a qualification (`inst/qualification/`) that rebuilds
representative CDISC-pilot tables (demographics, populations, AE
overview, AE by SOC/PT) from the public PHUSE Test Data Factory ADaM and
renders **each to every backend**, checking three things per cell: it
emits without error, the file is structurally valid, and an
**independent count computed from the ADaM appears in the rendered text
of that backend** (cross-backend content parity). The four pilot tables
across all four file backends give a 16/16 PASS matrix:

| Table                  | RTF  | HTML | DOCX | PDF¹ |
|------------------------|:----:|:----:|:----:|:----:|
| 14-2.01 Demographics   | PASS | PASS | PASS | PASS |
| 14-1.01 Populations    | PASS | PASS | PASS | PASS |
| 14-3.01 TEAE overview  | PASS | PASS | PASS | PASS |
| 14-3.04 TEAE by SOC/PT | PASS | PASS | PASS | PASS |

¹ The PDF column is verified **manually in a local environment** with a
LaTeX engine
([`check_latex()`](https://vthanik.github.io/tabular/reference/check_latex.md))
and `pdftotext` for the text-parity check. It is **not run in continuous
integration**, which carries no TeX install; CI exercises the RTF, HTML,
and DOCX backends.

The runnable script (`inst/qualification/qualify_tabular_cdisc.R`) and
how to fetch the data are in the qualification README in that same
`inst/qualification/` folder; it is the most direct evidence that one
`tabular` spec produces consistent, correct output across all backends.
