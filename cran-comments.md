## R CMD check results

0 errors | 0 warnings | 1 note

* This is an update from 0.2.0 to 0.3.0. The only NOTE lists some
  possibly-misspelled words in the `Description` (all intentional, see
  below). Local `R CMD check --as-cran` and the GitHub Actions runs
  report 0 errors / 0 warnings / 0 notes.

## Reason for the update timing

* 0.2.0 was published on 2026-07-06. This update follows sooner than the
  usual cadence because it fixes a bug that prevents installation and PDF
  output on locked-down corporate compute images: the `SystemRequirements`
  field named a TeX component in a way that pak's system-requirements
  scraper matched and answered by force-installing an OS `texlive` package,
  which fails (sudo denied) on such hosts even though the TeX distribution
  is optional. 0.3.0 removes that trigger and additionally ships a
  TeX-independent PDF path (a Typst backend), so users on those images can
  produce PDF output without any TeX installation. The release also folds
  in cross-backend rendering fixes and internal performance work; see
  `NEWS.md`.

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
