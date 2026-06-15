## R CMD check results

0 errors | 0 warnings | 1 note

* This is an update from 0.1.0 to 0.2.0, adding figure (graph) output
  alongside the existing tables and listings. The only NOTE lists some
  possibly-misspelled words in the Description (all intentional, see
  below). Local `R CMD check --as-cran` and the GitHub Actions runs
  report 0 errors / 0 warnings / 0 notes.

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
* Some technical terms and file-format abbreviations in the
  `Description` (for example RTF, DOCX, ADaM) may be flagged as possibly
  misspelled. These are intentional.
* There are no reverse dependencies to check.
