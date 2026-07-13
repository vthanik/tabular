# Check Typst availability for PDF output

Reports whether a typst compiler is available (the standalone `typst`
binary, or the copy bundled inside Quarto), whether its version meets
tabular's floor, and which families of the default font chain the
compiler can actually see. Run this before
`emit(spec, "out.pdf", format = "typst")` on a fresh machine, and
whenever a Typst-compiled PDF renders in an unexpected face.

## Usage

``` r
check_typst(quiet = FALSE)
```

## Arguments

- quiet:

  *Suppress the printed cli report.* `<logical(1)>: default FALSE`. When
  `TRUE`, runs the checks and returns the result invisibly without
  printing. Use in scripts that branch on the return value.

## Value

*Invisibly returns a data frame* with one row per family in the resolved
default font chain and columns `font` (`<character>`) and `available`
(`<logical>`, `NA` when the font list could not be read), plus
attributes `typst_version` (`<numeric_version | NA>`) and
`typst_command` (`<character(1) | NA_character_>`, the discovered
compiler invocation). Side effect: prints a cli report with a status
marker per check and, when anything is missing, the remedy.

## Details

**Binary discovery.** A standalone `typst` on the `PATH` wins; otherwise
the check falls back to `quarto typst` (Quarto \>= 1.4 bundles the typst
compiler — so most machines with RStudio / Posit Workbench already have
one). The Typst PDF path needs no TeX installation and no package
downloads at all.

**Fonts are the silent failure mode.** Where a missing LaTeX package
stops a compile with an error, typst substitutes a missing font family
silently and only notes it on the compiler's stderr. The check therefore
lists every family in the resolved default chain with its availability.
The chain is a *fallback* chain: typst renders in the first family it
can see, so a missing later member is normal cross-OS variance, not a
defect — the check reports ready as soon as any family resolves, and
names the face PDFs will render in.
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md)
additionally warns after a Typst compile when a family the user
explicitly named cannot be found (missing members of the built-in
fallback chains stay silent, matching the other backends' silent
font-substitution behaviour).

**Status markers:**

- `v` — found (binary; version at or above the floor; font family
  visible to typst).

- `x` — missing (no binary; version below the floor; font family not
  visible).

- `?` — could not be determined (e.g. the font list could not be read);
  treated as missing for remediation.

## See also

**Companion diagnostics:**
[`check_latex()`](https://vthanik.github.io/tabular/dev/reference/check_latex.md),
[`check_fonts()`](https://vthanik.github.io/tabular/dev/reference/check_fonts.md).

**Consumes the result:**
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md).

## Examples

``` r
# ---- Example 1: Audit the Typst toolchain before emitting ----
#
# Run check_typst() on a fresh machine to confirm a typst compiler
# is present and to see which families of the default font chain it
# resolves. Where no binary is found every row reports `?` and the
# remedy lines print; the call never errors.
check_typst()
#> 
#> ── Typst toolchain for PDF output 
#> v quarto typst 0.14.2
#> x font Courier New
#> x font Courier
#> v font Liberation Mono
#> v font DejaVu Sans Mono
#> ✔ Typst is ready; PDFs render in "Liberation Mono" (the first available family of the chain).
```
