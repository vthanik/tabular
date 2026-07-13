# Check LaTeX-package availability for PDF output

Reports, for every TeX package the LaTeX / PDF backend can emit, whether
the local TeX installation can resolve it, and prints the exact
[`tinytex::tlmgr_install()`](https://rdrr.io/pkg/tinytex/man/tlmgr.html)
call that installs any that are genuinely missing. Run this before
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
columns `package` (`<character>`), `installed` (`<logical>`, `NA` when
undeterminable), and `bundled` (`<logical>`, `TRUE` for packages tabular
ships a fallback copy of), plus a `texlive_year` attribute
(`<integer(1) | NA_integer_>`, the TeX Live release year of the active
`xelatex`). Side effect: prints a cli report with a per-package status
marker and, when anything is missing or the TeX Live release is older
than 2023, the exact remedy.

## Details

The required set is a superset of every `\\usepackage{}` /
`\\UseTblrLibrary{}` directive the backend emits, across all conditional
branches (running headers / footers pull `fancyhdr` + `lastpage`;
`xelatex` pulls `fontspec`; `pdflatex` pulls the classic font bundles).
The check is informational, it does not install anything.

**Minimum TeX Live version.** Package availability alone is not
sufficient: the bundled `tabularray` requires the 2022-11-01 LaTeX
kernel, shipped from **TeX Live 2023** onward. The report therefore
opens with the TeX Live year of the active `xelatex` and fails the check
when the kernel predates it — the classic symptom is an OS-managed or
containerised image (Domino, Posit Workbench) frozen on TeX Live 2018,
where every package resolves but the compile dies at
`\\ProvidesExplPackage`. The remedy is a newer TeX, not a package
install: update the image, or install a user-space TinyTeX with
[`tinytex::install_tinytex()`](https://rdrr.io/pkg/tinytex/man/install_tinytex.html)`(bundle = "TinyTeX")`
or `quarto install tinytex` — the Quarto route downloads from GitHub, so
it also works behind corporate proxies that block CTAN mirrors. Both
land in the standard TinyTeX location, which the compile (and this
check) prefer over the `PATH` automatically. MiKTeX is rolling-release
(always current), so its version reports as undetermined (`?`) rather
than failing.

**How availability is probed.** The check first resolves TeX the way the
compile does:
[`tinytex::latexmk()`](https://rdrr.io/pkg/tinytex/man/latexmk.html)
prefers a TinyTeX at the standard root (`~/.TinyTeX` on Linux,
`~/Library/TinyTeX` on macOS, `%APPDATA%/TinyTeX` on Windows — the
location used by both
[`tinytex::install_tinytex()`](https://rdrr.io/pkg/tinytex/man/install_tinytex.html)
and `quarto install tinytex`) over whatever is on the `PATH`, and the
report probes that same tree. Each package is then resolved through
`kpsewhich`, the same file resolver `xelatex` uses at compile time, so
the report reflects what a compile will actually find. This works on
every TeX layout — TinyTeX, a full TeX Live, or an OS-managed install
(Debian/apt, RHEL/dnf) where the `tlmgr` package database is absent and
database-backed checks report everything as missing.

**Bundled fallback packages.** tabular ships verbatim copies of
`tabularray` and `ninecolors` (the only requirements not included in any
TinyTeX flavor) and stages them next to the generated `.tex` at compile
time whenever the local TeX cannot resolve them. A bundled package
therefore always passes the check — no `tlmgr_install()` is ever needed
for those two. On the community TinyTeX bundle
(`tinytex::install_tinytex(bundle = "TinyTeX")`) or any larger
installation, everything else is already present, so PDF emission needs
no package installs at all — including on restricted servers where
`tlmgr` is locked.

**OS-managed TeX Live gotcha.** On Linux distributions that ship TeX
Live through the system package manager (RHEL / Fedora via `dnf`, Debian
/ Ubuntu via `apt`), `tlmgr` is locked against user installs and
`tlmgr_install()` will fail. The fix is to install a user-space TinyTeX
with
[`tinytex::install_tinytex()`](https://rdrr.io/pkg/tinytex/man/install_tinytex.html)`(bundle = "TinyTeX")`
and let that tree own the packages. Never force a locked `tlmgr` with
`--ignore-warning`: it leaves the system tree half-written. Where no TeX
install is possible at all, a missing single-file macro package can be
sideloaded without `tlmgr`: download its `.sty` from CTAN into
`~/texmf/tex/latex/<package>/` and set the `TEXMFHOME` environment
variable to `~/texmf`.

**Slow / stuck install (often Windows).** The default CTAN repository
`mirror.ctan.org` redirects to a random mirror on every call, and a slow
or stale one makes
[`tinytex::tlmgr_install()`](https://rdrr.io/pkg/tinytex/man/tlmgr.html)
appear to hang. Pin a concrete mirror once with
[`tinytex::tlmgr_repo()`](https://rdrr.io/pkg/tinytex/man/tlmgr.html)`("auto")`
(it follows the redirect a single time and remembers the result), then
retry the install.

**Status markers:**

- `v` — package resolves in the local TeX tree, or is missing but
  covered by a bundled copy (marked `bundled copy used`).

- `x` — package is missing; the `tlmgr_install()` line at the bottom of
  the report installs every missing package at once.

- `?` — availability could not be determined (`kpsewhich` not on the
  `PATH`, i.e. no TeX installation); treated as missing for remediation.

## See also

**Companion diagnostic:**
[`check_fonts()`](https://vthanik.github.io/tabular/dev/reference/check_fonts.md).

**Consumes the result:**
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md).

## Examples

``` r
# ---- Example 1: Audit the PDF toolchain before emitting ----
#
# Run check_latex() on a fresh machine to confirm every LaTeX
# package the PDF backend needs is present. The call prints a
# status line per package and, if any are missing, the exact
# tinytex::tlmgr_install() command to fix them in one shot. Where
# no TeX is installed every row reports `?` and the remedy lines
# print; the call never errors.
check_latex()
#> 
#> ── LaTeX packages for PDF output 
#> ? TeX Live version (xelatex missing, or a non-TeX-Live distribution
#> such as MiKTeX)
#> v tabularray (not found, bundled copy used)
#> v ninecolors (not found, bundled copy used)
#> v xcolor
#> v graphics
#> x siunitx
#> v geometry
#> v hyperref
#> v iftex
#> v base
#> v fancyhdr
#> x lastpage
#> v fontspec
#> v tex-gyre
#> v psnfss
#> ! Missing 2 LaTeX packages: "siunitx" and "lastpage".
#> Install with `tinytex::tlmgr_install(c('siunitx', 'lastpage'))`.
#> If the install stalls (commonly on Windows, where the default CTAN
#> mirror redirects on every call), pin a concrete mirror once with
#> `tinytex::tlmgr_repo("auto")` then retry.
#> On an OS-managed TeX Live (RHEL/dnf, Debian/apt) or wherever tlmgr is
#> locked: install a user-space TinyTeX with
#> `tinytex::install_tinytex(bundle = "TinyTeX")` instead (the community
#> bundle covers every package above). Never force a locked tlmgr with
#> `--ignore-warning`.
#> Where no TeX install is possible at all: download each missing `.sty`
#> from CTAN into ~/texmf/tex/latex/<package>/ and set `TEXMFHOME` to
#> ~/texmf; xelatex resolves it from there without tlmgr.
```
