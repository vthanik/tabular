## Reason for the update timing

This is a patch update (0.3.1 to 0.3.2) that fixes an ERROR on the CRAN
r-release-macos-arm64 and r-oldrel-macos-arm64 checks. A single unit test
verified that `check_latex()` resolves a TinyTeX installation when it is
off the `PATH`. Its skip guard relied on `tinytex::tinytex_root()` being
non-empty, but that returns an expected path even where no functional TeX
is installed at it (as on the CRAN macOS arm64 machine), so the test ran
and its assertion then demanded a LaTeX the machine did not have. The test
now carries `skip_on_cran()`, matching every other LaTeX-dependent test in
the package. No package code changed; the fix is test-only.

## R CMD check results

0 errors | 0 warnings | 1 note

* The only NOTE lists some possibly-misspelled words in the `Description`
  (all intentional, see below). Local `R CMD check --as-cran` reports
  0 errors / 0 warnings / 0 notes otherwise.

## Test environments

* local macOS, R release, `R CMD check --as-cran`
* GitHub Actions: ubuntu-latest (r-devel, r-release, r-oldrel-1),
  macos-latest (r-release), windows-latest (r-release)
* win-builder (r-devel and r-release)
* macbuilder (r-release)

## Notes for the reviewer

* Vignettes are built with Quarto, declared in `SystemRequirements`
  (`Quarto command line tool`). They build only when Quarto is
  available; the package itself has no runtime dependency on Quarto.
* PDF output is optional and needs either a TeX distribution or Typst,
  both declared in `SystemRequirements`. Tests and examples that compile
  a real PDF are guarded with `skip_on_cran()` plus a tool-presence check,
  so no PDF is compiled on the CRAN check farm.
* Some technical terms and file-format abbreviations in the
  `Description` (for example RTF, DOCX, ADaM) may be flagged as possibly
  misspelled. These are intentional.
* There are no reverse dependencies to check.
