# build_font_metrics.R — parse Adobe AFM files into R/sysdata.rda
#
# Tabular ships per-glyph advance widths for the PDF Core 14 fonts
# (Times / Helvetica / Courier in four weights each, plus Symbol +
# ZapfDingbats). The data feed `R/font_metrics.R::.text_width_em()`,
# which in turn powers `col_spec(width = "auto")` column-width
# auto-sizing and (Phase 3) decimal-metric padding.
#
# Source: R bundles the AFM files for these fonts under
# `R.home("library")/grDevices/afm/`. Adobe published them under a
# permissive licence; redistribution is fine.
#
# Two parallel maps are emitted per font:
#
#   afm_metrics[[font]]       named-by-char widths for ASCII +
#                             Latin-1 byte positions 32-255. Drives
#                             the fast-path ASCII LUT in
#                             `.text_width_em()`. Byte 233 here is
#                             whatever glyph Adobe Standard Encoding
#                             places at slot 233 — NOT the Latin-1
#                             character at that codepoint.
#
#   afm_glyph_widths[[font]]  named-by-glyph-name widths for every
#                             glyph in the font (including the
#                             `C -1` entries that have a glyph but
#                             no Adobe Standard Encoding slot —
#                             where every Latin-1 supplement
#                             accented Latin glyph lives). Looked
#                             up via the AGL bridge in `font_metrics.R`
#                             (Unicode codepoint -> glyph name ->
#                             width).
#
# Output: `R/sysdata.rda` — internal package data auto-loaded at
# package load time; never exported.
#
# Run: `Rscript data-raw/build_font_metrics.R`

afm_dir <- file.path(R.home("library"), "grDevices", "afm")

# Core 14: PDF Core 12 (Times / Helvetica / Courier × 4 weights)
# plus Symbol (Greek + math glyphs) and ZapfDingbats (checkmarks,
# bullets, arrows — usable through the AGL bridge for clinical
# pagination markers and validation badges).
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

  "Symbol" = "Symbol.afm.gz",
  "ZapfDingbats" = "ZapfDingbats.afm.gz"
)

# Parse one AFM file. Returns a list with two named-integer vectors:
#
#   by_byte   widths keyed by the single-byte character at Adobe
#             Standard Encoding slot 32-255 (e.g. "A" -> 722). The
#             AFM `C` field gives the slot; `rawToChar(as.raw(slot))`
#             gives the byte character used as the key.
#
#   by_name   widths keyed by glyph name (e.g. "eacute" -> 444).
#             Includes `C -1` entries (unencoded glyphs), so every
#             named glyph in the font has a width — that's what lets
#             the Unicode -> AGL -> glyph-name bridge in
#             `font_metrics.R` measure accented Latin characters.
parse_afm <- function(filepath) {
  con <- gzfile(filepath, "r")
  on.exit(close(con))
  lines <- readLines(con)

  metric_lines <- grep("^C\\s", lines, value = TRUE)

  by_byte_widths <- integer(0L)
  by_byte_names <- character(0L)
  by_name_widths <- integer(0L)
  by_name_names <- character(0L)

  for (line in metric_lines) {
    code_match <- regmatches(line, regexec("^C\\s+(-?\\d+)", line))[[1L]]
    code <- as.integer(code_match[[2L]])

    wx_match <- regmatches(line, regexec("WX\\s+(\\d+)", line))[[1L]]
    if (length(wx_match) < 2L) {
      next
    }
    wx <- as.integer(wx_match[[2L]])

    name_match <- regmatches(line, regexec("N\\s+(\\S+)", line))[[1L]]
    glyph_name <- if (length(name_match) >= 2L) {
      name_match[[2L]]
    } else {
      NA_character_
    }

    if (code >= 32L && code <= 255L) {
      ch <- rawToChar(as.raw(code))
      by_byte_names <- c(by_byte_names, ch)
      by_byte_widths <- c(by_byte_widths, wx)
    }
    if (!is.na(glyph_name) && nzchar(glyph_name)) {
      by_name_names <- c(by_name_names, glyph_name)
      by_name_widths <- c(by_name_widths, wx)
    }
  }

  names(by_byte_widths) <- by_byte_names
  names(by_name_widths) <- by_name_names
  list(by_byte = by_byte_widths, by_name = by_name_widths)
}

afm_metrics <- vector("list", length(afm_files))
names(afm_metrics) <- names(afm_files)
afm_glyph_widths <- vector("list", length(afm_files))
names(afm_glyph_widths) <- names(afm_files)

for (font_name in names(afm_files)) {
  filepath <- file.path(afm_dir, afm_files[[font_name]])
  if (!file.exists(filepath)) {
    stop("AFM file not found: ", filepath)
  }
  parsed <- parse_afm(filepath)
  afm_metrics[[font_name]] <- parsed$by_byte
  afm_glyph_widths[[font_name]] <- parsed$by_name
}

save(
  afm_metrics,
  afm_glyph_widths,
  file = "R/sysdata.rda",
  compress = "xz"
)
