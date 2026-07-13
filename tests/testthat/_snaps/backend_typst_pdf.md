# no binary at all aborts with the install remedies

    Code
      tabular:::backend_typst_pdf(grid, out)
    Condition
      Error:
      ! PDF compilation via Typst failed.
      x No typst compiler found: neither `typst` nor `quarto` is on the `PATH`.
      i Install Quarto (>= 1.4, which bundles typst) from <https://quarto.org>, or the standalone typst binary from <https://github.com/typst/typst>.
      i With a TeX installation present you can compile via LaTeX instead: `emit(spec, "out.pdf", format = "latex")`.
      i Fallback: render to HTML or RTF instead via `emit(spec, "out.html")` or `emit(spec, "out.rtf")`.

# .typst_compile_abort leads with the version floor when too old

    Code
      tabular:::.typst_compile_abort(err, .version = numeric_version("0.10.0"))
    Condition
      Error:
      ! PDF compilation via Typst failed.
      x The typst binary is version 0.10.0; tabular requires typst >= 0.11.0.
      i Update Quarto to >= 1.6 (which bundles a newer typst), or install a current standalone typst from <https://github.com/typst/typst>.
      i Run `tabular::check_typst()` to audit the typst toolchain.
      i With a TeX installation present you can compile via LaTeX instead: `emit(spec, "out.pdf", format = "latex")`.
      i Fallback: render to HTML or RTF instead via `emit(spec, "out.html")` or `emit(spec, "out.rtf")`.

# .typst_compile_abort surfaces the compiler message otherwise

    Code
      tabular:::.typst_compile_abort(err, .version = numeric_version("0.14.2"))
    Condition
      Error:
      ! PDF compilation via Typst failed.
      x The typst compiler reported:
        error: expected semicolon or line break
      i Run `tabular::check_typst()` to audit the typst toolchain.
      i With a TeX installation present you can compile via LaTeX instead: `emit(spec, "out.pdf", format = "latex")`.
      i Fallback: render to HTML or RTF instead via `emit(spec, "out.html")` or `emit(spec, "out.rtf")`.

# check_typst validates quiet

    Code
      check_typst(quiet = NA)
    Condition
      Error:
      ! `quiet` must be a single <logical>.
      x You supplied `NA`.

# .check_typst_report prints every status branch

    Code
      tabular:::.check_typst_report(frame, version = numeric_version("0.14.2"),
      command = "quarto typst")
    Message
      
      -- Typst toolchain for PDF output 
      v quarto typst 0.14.2
      v font Courier New
      x font Liberation Mono
      ? font DejaVu Sans Mono
      v Typst is ready; PDFs render in "Courier New" (the first available family of the chain).

---

    Code
      tabular:::.check_typst_report(frame, version = NA, command = NA_character_)
    Message
      
      -- Typst toolchain for PDF output 
      x typst compiler (neither `typst` nor `quarto` on the PATH)
      v font Courier New
      x font Liberation Mono
      ? font DejaVu Sans Mono
      ! No typst compiler found; `emit(spec, "out.pdf", format = "typst")` cannot run.
      Install Quarto (>= 1.4, which bundles typst) from <https://quarto.org>, or the
      standalone typst binary from <https://github.com/typst/typst>.

---

    Code
      tabular:::.check_typst_report(frame, version = numeric_version("0.10.0"),
      command = "typst")
    Message
      
      -- Typst toolchain for PDF output 
      x typst 0.10.0 (tabular requires typst >= 0.11.0)
      v font Courier New
      x font Liberation Mono
      ? font DejaVu Sans Mono
      ! typst 0.10.0 is older than tabular's floor (0.11.0); compiles will fail on the table constructs the backend emits.
      Update Quarto to >= 1.6, or install a current standalone typst.

---

    Code
      tabular:::.check_typst_report(all_ok, version = numeric_version("0.14.2"),
      command = "typst")
    Message
      
      -- Typst toolchain for PDF output 
      v typst 0.14.2
      v font Courier New
      v Typst is ready; PDFs render in "Courier New" (the first available family of the chain).

---

    Code
      tabular:::.check_typst_report(none_ok, version = numeric_version("0.14.2"),
      command = "typst")
    Message
      
      -- Typst toolchain for PDF output 
      v typst 0.14.2
      x font Sponsor Sans
      x font Sponsor Serif
      ! No family of the configured chain is visible to typst; PDFs render in typst's embedded default face.
      Install one of the chain families, or point typst at a font directory via the
      `TYPST_FONT_PATHS` environment variable.

---

    Code
      tabular:::.check_typst_report(unknown, version = numeric_version("0.14.2"),
      command = "typst")
    Message
      
      -- Typst toolchain for PDF output 
      v typst 0.14.2
      ? font Courier New
      ! The typst font list could not be read, so font availability is unknown; typst substitutes its embedded default face for any missing family.

