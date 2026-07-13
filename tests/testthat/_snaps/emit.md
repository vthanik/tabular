# emit() rejects when parent directory does not exist

    Code
      emit(spec, missing)
    Condition
      Error:
      ! Parent directory of `file` does not exist.
      x Missing directory: <path>.
      i Create it first, pass `create_dir = TRUE`, or use an existing directory.

# bare .pdf probes LaTeX first, then typst, then aborts

    Code
      tabular:::.pdf_default_format(NULL, .tex_ok = function() FALSE, .typst_ok = function()
        FALSE)
    Condition
      Error:
      ! No PDF engine found.
      x PDF output compiles via LaTeX (a TeX installation) or Typst (the typst binary, bundled with Quarto), and neither was found.
      i Install a TeX with `tinytex::install_tinytex(bundle = "TinyTeX")` or `quarto install tinytex`, or install Quarto (>= 1.4, which bundles typst) from <https://quarto.org>.
      i Audit either toolchain with `tabular::check_latex()` or `tabular::check_typst()`.
      i Or render to another format: `emit(spec, "out.rtf")` / `emit(spec, "out.html")`.

