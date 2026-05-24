# font_metrics.R — AFM-driven text width measurement.
#
# Foundation for `col_spec(width = "auto")` and any future
# pixel-aware engine logic (decimal_metrics = "afm" prefix em
# wiring is currently deferred — see preset.R::decimal_metrics).
#
# Two consumers:
#
#   .resolve_afm_name(font_family, bold, italic)
#     -> AFM lookup key (e.g. "Times-Roman", "Helvetica-Bold")
#
#   .text_width_em(text, afm_name)
#     -> total advance width in 1/1000 em units. Caller scales
#        by font size at use site.
#
# Data: 13 named AFM tables loaded from R/sysdata.rda (built by
# data-raw/build_font_metrics.R). Tables are byte-keyed; entries
# 32-255 only. Greek + math glyphs in Symbol live at Adobe
# Standard Encoding slots, not Unicode codepoints — `.text_width_em()`
# bridges that gap with a curated AGL subset (`.agl_symbol`).

# ---------------------------------------------------------------------
# Family-class -> AFM family mapping
# ---------------------------------------------------------------------

# Liberation faces aren't in the alias table (R/fonts.R) because
# the resolver treats them as "explicit named font, emit verbatim".
# For metric measurement we still need the family class — Liberation
# Serif is metric-compatible with Times-Roman, so we measure with
# Times-Roman AFM.
.font_to_family_class <- list(
  "Liberation Serif" = "serif",
  "Liberation Sans" = "sans",
  "Liberation Mono" = "mono"
)

# Pick the family class for a font_family chain. Walks top-to-bottom;
# first generic / aliased / Liberation hit wins. Defaults to "serif"
# (the dominant clinical-TFL face) when nothing matches.
.font_chain_family_class <- function(font_family) {
  if (length(font_family) == 0L) {
    return("serif")
  }
  for (nm in as.character(font_family)) {
    if (.is_generic_family(nm)) {
      return(.normalize_generic(nm))
    }
    alias <- .resolve_font_alias(nm)
    if (!is.null(alias)) {
      return(alias)
    }
    lib <- .font_to_family_class[[nm]]
    if (!is.null(lib)) {
      return(lib)
    }
  }
  "serif"
}

# Resolve a font_family chain + style to an AFM lookup key.
# Returns one of the 12 weighted Core-12 names — Symbol is never
# returned here (it's a glyph-fallback target, not a body face).
#
#   serif + regular     -> Times-Roman
#   serif + bold        -> Times-Bold
#   serif + italic      -> Times-Italic
#   serif + bold+italic -> Times-BoldItalic
#   sans  + ...         -> Helvetica + variant
#   mono  + ...         -> Courier + variant
#
# Naming quirks (Adobe AFM conventions):
#   - Times uses "Italic" / "BoldItalic" suffixes.
#   - Helvetica and Courier use "Oblique" / "BoldOblique".
#   - Helvetica regular is plain "Helvetica" (no -Roman suffix).
#   - Times regular is "Times-Roman" (with -Roman suffix).
.resolve_afm_name <- function(font_family, bold = FALSE, italic = FALSE) {
  fam <- .font_chain_family_class(font_family)
  switch(
    fam,
    serif = {
      if (bold && italic) {
        "Times-BoldItalic"
      } else if (bold) {
        "Times-Bold"
      } else if (italic) {
        "Times-Italic"
      } else {
        "Times-Roman"
      }
    },
    sans = {
      if (bold && italic) {
        "Helvetica-BoldOblique"
      } else if (bold) {
        "Helvetica-Bold"
      } else if (italic) {
        "Helvetica-Oblique"
      } else {
        "Helvetica"
      }
    },
    mono = {
      if (bold && italic) {
        "Courier-BoldOblique"
      } else if (bold) {
        "Courier-Bold"
      } else if (italic) {
        "Courier-Oblique"
      } else {
        "Courier"
      }
    }
  )
}

# ---------------------------------------------------------------------
# Symbol AGL subset (Unicode -> Adobe Standard Encoding slot)
# ---------------------------------------------------------------------

# Curated Adobe Glyph List subset for Symbol. Keys are Unicode
# codepoints (integer); values are the byte position 32-255 where
# the corresponding glyph lives in `Symbol.afm`'s metric table.
#
# Scope: Greek lowercase / uppercase + math operators that appear
# in real clinical-TFL prefix slots (p-values, CIs, units, factor
# levels). We do NOT bundle the full 4000-entry AGL — most entries
# are decorative and never appear in a regulatory table.
#
# Source: Adobe Symbol Encoding Vector (ToUnicode reverse map),
# cross-checked against `Symbol.afm` glyph names. Values are stable
# across PostScript revisions; the Symbol font has not changed
# encoding since the 1980s.
.agl_symbol <- c(
  # Greek lowercase (U+03B1 - U+03C9)
  "945" = 97L, # alpha     a
  "946" = 98L, # beta      b
  "947" = 103L, # gamma     g
  "948" = 100L, # delta     d
  "949" = 101L, # epsilon   e
  "950" = 122L, # zeta      z
  "951" = 104L, # eta       h
  "952" = 113L, # theta     q
  "953" = 105L, # iota      i
  "954" = 107L, # kappa     k
  "955" = 108L, # lambda    l
  "956" = 109L, # mu        m
  "957" = 110L, # nu        n
  "958" = 120L, # xi        x
  "959" = 111L, # omicron   o
  "960" = 112L, # pi        p
  "961" = 114L, # rho       r
  "963" = 115L, # sigma     s
  "964" = 116L, # tau       t
  "965" = 117L, # upsilon   u
  "966" = 102L, # phi       f
  "967" = 99L, # chi       c
  "968" = 121L, # psi       y
  "969" = 119L, # omega     w

  # Greek uppercase that don't look like Latin (U+0391 - U+03A9)
  "915" = 71L, # Gamma     G
  "916" = 68L, # Delta     D
  "920" = 81L, # Theta     Q
  "923" = 76L, # Lambda    L
  "926" = 88L, # Xi        X
  "928" = 80L, # Pi        P
  "931" = 83L, # Sigma     S
  "934" = 70L, # Phi       F
  "936" = 89L, # Psi       Y
  "937" = 87L, # Omega     W

  # Math operators that appear in clinical prefix slots
  "8804" = 163L, # lessequal       <=
  "8805" = 179L, # greaterequal    >=
  "177" = 177L, # plusminus       +/- (Latin-1, but Symbol also has it)
  "215" = 180L, # multiply        x
  "247" = 184L, # divide          /
  "8776" = 187L, # approxequal     ~=
  "8800" = 185L, # notequal        !=
  "8734" = 165L, # infinity        oo
  "8730" = 214L, # radical         sqrt
  "8721" = 229L, # summation       SUM
  "8747" = 242L, # integral        INT
  "8706" = 182L, # partialdiff     d
  "8711" = 209L # nabla           grad
)

# ---------------------------------------------------------------------
# .text_width_em — measure text in 1/1000 em
# ---------------------------------------------------------------------

# Total advance width of `text` under `afm_name`, in 1/1000 em
# units. Vectorised over `text`. Caller multiplies by font_size
# (pt) to convert to actual typographic width.
#
# Fast path (pure ASCII): build a 128-entry byte LUT (codepoints
# 32-127, where byte == Unicode codepoint == AFM slot — three-way
# match). Sum lookups via `as.integer(charToRaw(t))`.
#
# Slow path (non-ASCII): walk codepoints via `utf8ToInt()`. For
# Greek / math codepoints in the curated `.agl_symbol` table,
# look up the glyph in `afm_metrics$Symbol`. Unknown codepoints
# (Latin-1 supplements like é / ñ, CJK, etc.) fall back to the
# primary font's space width.
#
# Known limit: Latin-1 supplement characters (U+0080-U+00FF) are
# measured as space-width. The AFM Core fonts use Adobe Standard
# Encoding, which puts Oslash at slot 233 — not eacute. Looking
# up by Latin-1 byte position would return wrong glyphs (the
# `\xE9` slot holds Ø in Times-Roman, not é). Clinical TFLs are
# overwhelmingly ASCII; accented Latin in name / address fields
# is rare and conservatively treated as space-width. Future plan:
# extend `.agl_symbol` with Adobe Standard Encoding's 100-odd
# accented-Latin slots if production data needs them.
#
# Returns 0 for empty / NA input. Never errors on malformed UTF-8;
# unmappable codepoints become space-width contributions.
.text_width_em <- function(text, afm_name) {
  char_widths <- afm_metrics[[afm_name]]
  if (is.null(char_widths)) {
    cli::cli_abort(
      c(
        "Unknown AFM font {.val {afm_name}}.",
        "i" = "Available: {.val {names(afm_metrics)}}."
      ),
      class = "tabular_error_input"
    )
  }

  default_w <- unname(char_widths[" "])
  if (is.na(default_w)) {
    default_w <- 500L
  }
  # ASCII LUT only — codepoints 32-127 where byte == codepoint ==
  # AFM slot. Higher slots in the AFM exist but don't correspond
  # to Latin-1 codepoints (Adobe Standard Encoding mismatch),
  # so we don't fold them into a Unicode-keyed LUT here.
  lut <- rep(default_w, 128L)
  ascii_names <- names(char_widths)
  ascii_bytes <- as.integer(charToRaw(paste0(ascii_names, collapse = "")))
  ascii_keep <- ascii_bytes < 128L
  lut[ascii_bytes[ascii_keep]] <- unname(char_widths)[ascii_keep]

  symbol_widths <- afm_metrics[["Symbol"]]
  symbol_default <- if (!is.null(symbol_widths)) {
    unname(symbol_widths[" "]) %||% 500L
  } else {
    NA_integer_
  }

  vapply(
    text,
    function(t) {
      if (is.na(t) || !nzchar(t)) {
        return(0L)
      }
      raw_bytes <- charToRaw(t)
      if (all(raw_bytes < as.raw(0x80))) {
        return(sum(lut[as.integer(raw_bytes)]))
      }
      cps <- utf8ToInt(t)
      total <- 0L
      for (cp in cps) {
        if (cp < 128L) {
          total <- total + lut[[cp]]
          next
        }
        # Try Symbol via AGL for Greek / math codepoints. Single
        # bracket so a miss returns NA instead of erroring.
        slot <- .agl_symbol[as.character(cp)]
        if (!is.na(slot) && !is.null(symbol_widths)) {
          ch <- rawToChar(as.raw(unname(slot)))
          w <- symbol_widths[ch]
          total <- total + if (is.na(w)) symbol_default else unname(w)
          next
        }
        # Latin-1 supplement, CJK, anything else: space-width.
        total <- total + default_w
      }
      total
    },
    integer(1L),
    USE.NAMES = FALSE
  )
}
