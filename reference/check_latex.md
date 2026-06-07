# Check LaTeX-package availability for PDF output

Reports, for every TeX package the LaTeX / PDF backend can emit, whether
it is present in the local TeX tree, and prints the exact
[`tinytex::tlmgr_install()`](https://rdrr.io/pkg/tinytex/man/tlmgr.html)
call that installs any that are missing. Run this before
`emit(spec, "out.pdf")` on a fresh machine to turn a cryptic mid-compile
`File 'tabularray.sty' not found` into an up-front, actionable
checklist.

## Usage

``` r
check_latex(quiet = FALSE)
```

## Arguments

- quiet:

  *Suppress the printed cli report.* `<logical(1)>: default FALSE`. When
  `TRUE`, runs the checks and returns the result invisibly without
  printing. Use in scripts that branch on the return value.

## Value

*Invisibly returns a data frame* with one row per required package and
columns `package` (`<character>`) and `installed` (`<logical>`, `NA`
when undeterminable). Side effect: prints a cli report with a
per-package status marker and, when anything is missing, the exact
`tlmgr_install()` remedy.

## Details

The required set is a superset of every `\\usepackage{}` /
`\\UseTblrLibrary{}` directive the backend emits, across all conditional
branches (running headers / footers pull `fancyhdr` + `lastpage`;
`xelatex` pulls `fontspec`; `pdflatex` pulls the classic font bundles).
The check is informational, it does not install anything.

**OS-managed TeX Live gotcha.** On Linux distributions that ship TeX
Live through the system package manager (RHEL / Fedora via `dnf`, Debian
/ Ubuntu via `apt`), `tlmgr` is locked against user installs and
`tlmgr_install()` will fail. The fix is to install a user-space TinyTeX
with
[`tinytex::install_tinytex()`](https://rdrr.io/pkg/tinytex/man/install_tinytex.html)
and let that tree own the packages. Never force a locked `tlmgr` with
`--ignore-warning`: it leaves the system tree half-written.

**Slow / stuck install (often Windows).** The default CTAN repository
`mirror.ctan.org` redirects to a random mirror on every call, and a slow
or stale one makes
[`tinytex::tlmgr_install()`](https://rdrr.io/pkg/tinytex/man/tlmgr.html)
appear to hang. Pin a concrete mirror once with
[`tinytex::tlmgr_repo()`](https://rdrr.io/pkg/tinytex/man/tlmgr.html)`("auto")`
(it follows the redirect a single time and remembers the result), then
retry the install.

**Status markers:**

- `v` — package is installed in the local TeX tree.

- `x` — package is missing; the `tlmgr_install()` line at the bottom of
  the report installs every missing package at once.

- `?` — availability could not be determined (no `tinytex`, or `tlmgr`
  not reachable); treated as missing for remediation.

Requires the `tinytex` package (in `Suggests`); call
`install.packages("tinytex")` first if it isn't installed.

## See also

**Companion diagnostic:**
[`check_fonts()`](https://vthanik.github.io/tabular/reference/check_fonts.md).

**Consumes the result:**
[`emit()`](https://vthanik.github.io/tabular/reference/emit.md).

## Examples

``` r
# ---- Example 1: Audit the PDF toolchain before emitting ----
#
# Run check_latex() on a fresh machine to confirm every LaTeX
# package the PDF backend needs is present. The call prints a
# status line per package and, if any are missing, the exact
# tinytex::tlmgr_install() command to fix them in one shot. It is
# guarded on tinytex so it is a no-op where TeX is unavailable.
if (requireNamespace("tinytex", quietly = TRUE)) {
  check_latex()
}
#> 
#> ── LaTeX packages for PDF output 
#> v tabularray
#> v ninecolors
#> v xcolor
#> v graphics
#> v siunitx
#> v geometry
#> v hyperref
#> v iftex
#> v base
#> v fancyhdr
#> v lastpage
#> v fontspec
#> v tex-gyre
#> v psnfss
#> ✔ All required LaTeX packages are installed.
```
