# build_font_metrics.R — parse Adobe AFM files into R/sysdata.rda
#
# Tabular ships per-character glyph widths for the PDF Core 13 fonts
# (Times / Helvetica / Courier in four weights each, plus Symbol).
# The data feed `R/font_metrics.R::.text_width_em()`, which in turn
# powers `col_spec(width = "auto")` column-width auto-sizing.
#
# Source: R bundles the AFM files for these fonts under
# `R.home("library")/grDevices/afm/`. Adobe published them under a
# permissive licence; redistribution is fine.
#
# Output: `R/sysdata.rda` — internal package data auto-loaded at
# package load time; never exported.
#
# Run: `Rscript data-raw/build_font_metrics.R`

afm_dir <- file.path(R.home("library"), "grDevices", "afm")

# Core 13: PDF Core 12 (Times / Helvetica / Courier × 4 weights)
# plus Symbol (Greek + math glyphs in Adobe Standard Encoding).
# ZapfDingbats is intentionally omitted — decorative arrows and
# checkmarks have no clinical-TFL use case.
afm_files <- c(
  "Helvetica" = "Helvetica.afm.gz",
  "Helvetica-Bold" = "Helvetica-Bold.afm.gz",
  "Helvetica-Oblique" = "Helvetica-Oblique.afm.gz",
  "Helvetica-BoldOblique" = "Helvetica-BoldOblique.afm.gz",

  "Times-Roman" = "Times-Roman.afm.gz",
  "Times-Bold" = "Times-Bold.afm.gz",
  "Times-Italic" = "Times-Italic.afm.gz",
  "Times-BoldItalic" = "Times-BoldItalic.afm.gz",

  "Courier" = "Courier.afm.gz",
  "Courier-Bold" = "Courier-Bold.afm.gz",
  "Courier-Oblique" = "Courier-Oblique.afm.gz",
  "Courier-BoldOblique" = "Courier-BoldOblique.afm.gz",

  "Symbol" = "Symbol.afm.gz"
)

# Parse one AFM file into a named integer vector. Names are the
# single-byte characters (Latin-1 codepoints 32-255 for Times /
# Helvetica / Courier; Adobe Standard Encoding slots for Symbol).
# Values are advance widths in 1/1000 em units.
#
# Symbol note: indices are POSITIONAL in Adobe Standard Encoding,
# not Unicode codepoints. Downstream consumers must NOT index
# `afm_metrics$Symbol` by codepoint directly — go through
# `.text_width_em()`'s AGL fallback path in `R/font_metrics.R`.
parse_afm <- function(filepath) {
  con <- gzfile(filepath, "r")
  on.exit(close(con))
  lines <- readLines(con)

  metric_lines <- grep("^C\\s", lines, value = TRUE)

  widths <- integer(0L)
  names_vec <- character(0L)

  for (line in metric_lines) {
    code_match <- regmatches(line, regexec("^C\\s+(-?\\d+)", line))[[1L]]
    code <- as.integer(code_match[[2L]])

    wx_match <- regmatches(line, regexec("WX\\s+(\\d+)", line))[[1L]]
    if (length(wx_match) < 2L) {
      next
    }
    wx <- as.integer(wx_match[[2L]])

    if (code >= 32L && code <= 255L) {
      ch <- rawToChar(as.raw(code))
      names_vec <- c(names_vec, ch)
      widths <- c(widths, wx)
    }
  }

  names(widths) <- names_vec
  widths
}

afm_metrics <- vector("list", length(afm_files))
names(afm_metrics) <- names(afm_files)

for (font_name in names(afm_files)) {
  filepath <- file.path(afm_dir, afm_files[[font_name]])
  if (!file.exists(filepath)) {
    stop("AFM file not found: ", filepath)
  }
  afm_metrics[[font_name]] <- parse_afm(filepath)
}

save(afm_metrics, file = "R/sysdata.rda", compress = "xz")
