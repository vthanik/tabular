# Development-only refresh of the bundled LaTeX packages in inst/tex/.
# Downloads the current CTAN copies verbatim (LPPL requires renaming
# modified files, so we never edit them) and prints each package's
# \ProvidesExplPackage version line. After running, update the matching
# entries in inst/COPYRIGHTS by hand.
#
# Run from the package root:  Rscript tools/update-latex-sty.R

sty <- c(
  tabularray = "https://mirror.ctan.org/macros/latex/contrib/tabularray/tabularray.sty",
  ninecolors = "https://mirror.ctan.org/macros/latex/contrib/ninecolors/ninecolors.sty"
)

dest_dir <- file.path("inst", "latex")
dir.create(dest_dir, showWarnings = FALSE, recursive = TRUE)

for (name in names(sty)) {
  out <- file.path(dest_dir, paste0(name, ".sty"))
  utils::download.file(sty[[name]], out, mode = "wb", quiet = TRUE)
  provides <- grep(
    "\\\\Provides(Expl)?Package",
    readLines(out, n = 50L, warn = FALSE),
    value = TRUE
  )
  cat(sprintf("%s: %s\n", out, provides[[1L]]))
}

cat("Done. Update inst/COPYRIGHTS with the versions above.\n")
