# font_metrics.R — AFM-driven text width measurement.
#
# Foundation for `col_spec(width = "auto")` and the em-aware
# decimal padding behind decimal_metrics = "afm" (the default —
# see preset.R::decimal_metrics and the as_grid.R decimal block).
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

# Named faces that carry a family class but aren't in the PS-era
# alias table (R/fonts.R). This is the shared SSOT consulted by both
# `.font_chain_family_class` (AFM measurement, below) and
# `.font_generic_class` (RTF/DOCX class, R/fonts.R) — extend it here,
# never by touching the generic `.stack_*` cores.
#
# Liberation faces: metric-compatible with the Adobe Core faces
# (Liberation Serif = Times-Roman, Sans = Helvetica, Mono = Courier),
# so we measure with the matching Core AFM. IBM Plex Mono has the
# identical 0.6em advance as Courier, so measuring it as Courier is
# exact; Plex Sans as Helvetica is a close approximation.
.font_to_family_class <- list(
  "Liberation Serif" = "serif",
  "Liberation Sans" = "sans",
  "Liberation Mono" = "mono",
  "IBM Plex Mono" = "mono",
  "IBM Plex Sans" = "sans",
  "IBM Plex Serif" = "serif"
)

# Pick the family class for a font_family chain. Walks top-to-bottom;
# first generic / aliased / Liberation hit wins. Falls back to `default`
# — "serif" (the dominant clinical-TFL face) unless the caller needs to
# detect the no-match case (pass `default = NA_character_`).
.font_chain_family_class <- function(font_family, default = "serif") {
  if (length(font_family) == 0L) {
    return(default)
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
  default
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
# Latin-1 supplement codepoints (U+00A0 - U+00FF) -> Adobe Glyph
# List names. Drives the bridge that lets `.text_width_em()` measure
# accented Latin glyphs (é, ñ, ü, ø, etc.) at their true AFM widths
# instead of falling back to the default space width.
#
# Source: Adobe Glyph List for New Fonts (AGLFN). Names match the
# `N` field in every Core-14 AFM's `C -1 ; WX <w> ; N <name>` entry
# (unencoded glyphs — accented Latin lives at Adobe Standard
# Encoding's `C -1` lines because byte slots 128-255 hold a different
# set in Adobe Standard Encoding than in Latin-1).
#
# Names that resolve to a Latin-character look-alike (no-break space
# -> "space", soft hyphen -> "hyphen") share width with the ASCII
# original. Names that don't exist in a particular font (e.g.
# "Aacute" in Symbol) fall back to default space-width via the lookup
# path in `.text_width_em()`.
.agl_latin1 <- c(
  "160" = "space", # U+00A0 no-break space
  "161" = "exclamdown", # U+00A1
  "162" = "cent", # U+00A2
  "163" = "sterling", # U+00A3
  "164" = "currency", # U+00A4
  "165" = "yen", # U+00A5
  "166" = "brokenbar", # U+00A6
  "167" = "section", # U+00A7
  "168" = "dieresis", # U+00A8
  "169" = "copyright", # U+00A9
  "170" = "ordfeminine", # U+00AA
  "171" = "guillemotleft", # U+00AB
  "172" = "logicalnot", # U+00AC
  "173" = "hyphen", # U+00AD soft hyphen
  "174" = "registered", # U+00AE
  "175" = "macron", # U+00AF
  "176" = "degree", # U+00B0
  "177" = "plusminus", # U+00B1
  "178" = "twosuperior", # U+00B2
  "179" = "threesuperior", # U+00B3
  "180" = "acute", # U+00B4
  "181" = "mu", # U+00B5 micro sign
  "182" = "paragraph", # U+00B6
  "183" = "periodcentered", # U+00B7
  "184" = "cedilla", # U+00B8
  "185" = "onesuperior", # U+00B9
  "186" = "ordmasculine", # U+00BA
  "187" = "guillemotright", # U+00BB
  "188" = "onequarter", # U+00BC
  "189" = "onehalf", # U+00BD
  "190" = "threequarters", # U+00BE
  "191" = "questiondown", # U+00BF
  "192" = "Agrave", # U+00C0
  "193" = "Aacute", # U+00C1
  "194" = "Acircumflex", # U+00C2
  "195" = "Atilde", # U+00C3
  "196" = "Adieresis", # U+00C4
  "197" = "Aring", # U+00C5
  "198" = "AE", # U+00C6
  "199" = "Ccedilla", # U+00C7
  "200" = "Egrave", # U+00C8
  "201" = "Eacute", # U+00C9
  "202" = "Ecircumflex", # U+00CA
  "203" = "Edieresis", # U+00CB
  "204" = "Igrave", # U+00CC
  "205" = "Iacute", # U+00CD
  "206" = "Icircumflex", # U+00CE
  "207" = "Idieresis", # U+00CF
  "208" = "Eth", # U+00D0
  "209" = "Ntilde", # U+00D1
  "210" = "Ograve", # U+00D2
  "211" = "Oacute", # U+00D3
  "212" = "Ocircumflex", # U+00D4
  "213" = "Otilde", # U+00D5
  "214" = "Odieresis", # U+00D6
  "215" = "multiply", # U+00D7
  "216" = "Oslash", # U+00D8
  "217" = "Ugrave", # U+00D9
  "218" = "Uacute", # U+00DA
  "219" = "Ucircumflex", # U+00DB
  "220" = "Udieresis", # U+00DC
  "221" = "Yacute", # U+00DD
  "222" = "Thorn", # U+00DE
  "223" = "germandbls", # U+00DF
  "224" = "agrave", # U+00E0
  "225" = "aacute", # U+00E1
  "226" = "acircumflex", # U+00E2
  "227" = "atilde", # U+00E3
  "228" = "adieresis", # U+00E4
  "229" = "aring", # U+00E5
  "230" = "ae", # U+00E6
  "231" = "ccedilla", # U+00E7
  "232" = "egrave", # U+00E8
  "233" = "eacute", # U+00E9
  "234" = "ecircumflex", # U+00EA
  "235" = "edieresis", # U+00EB
  "236" = "igrave", # U+00EC
  "237" = "iacute", # U+00ED
  "238" = "icircumflex", # U+00EE
  "239" = "idieresis", # U+00EF
  "240" = "eth", # U+00F0
  "241" = "ntilde", # U+00F1
  "242" = "ograve", # U+00F2
  "243" = "oacute", # U+00F3
  "244" = "ocircumflex", # U+00F4
  "245" = "otilde", # U+00F5
  "246" = "odieresis", # U+00F6
  "247" = "divide", # U+00F7
  "248" = "oslash", # U+00F8
  "249" = "ugrave", # U+00F9
  "250" = "uacute", # U+00FA
  "251" = "ucircumflex", # U+00FB
  "252" = "udieresis", # U+00FC
  "253" = "yacute", # U+00FD
  "254" = "thorn", # U+00FE
  "255" = "ydieresis" # U+00FF
)

# Look up a Unicode codepoint's glyph name via the AGL bridge.
# Returns the glyph name (suitable for indexing
# `afm_glyph_widths[[font]]`) or NA_character_ when the codepoint
# isn't in our curated AGL. ASCII codepoints (32-127) pass through
# as the raw character — every AFM stores ASCII glyph names as the
# raw character (e.g. "A", "space"), so the lookup works directly.
.unicode_to_glyph_name <- function(cp) {
  if (cp < 32L) {
    return(NA_character_)
  }
  if (cp < 128L) {
    # ASCII: AFM glyph names for letters / digits are the raw
    # character ("A", "B", "0", "1"). Punctuation has named glyphs
    # ("space", "exclam"); we don't bridge these here because the
    # ASCII fast path in .text_width_em() consumes them already.
    return(NA_character_)
  }
  nm <- .agl_latin1[as.character(cp)]
  if (!is.na(nm)) {
    return(unname(nm))
  }
  NA_character_
}

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

  # Glyph-name keyed widths for the primary font. Drives the
  # Latin-1 supplement bridge (cp 160-255 -> AGL name -> width).
  primary_glyph_widths <- afm_glyph_widths[[afm_name]]

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
        # Latin-1 supplement via AGL bridge: codepoint -> glyph
        # name (e.g. "eacute") -> width in the primary font. Every
        # Core-14 AFM ships these glyphs at `C -1` unencoded slots
        # with their canonical AGL names.
        if (cp >= 160L && cp <= 255L && !is.null(primary_glyph_widths)) {
          glyph_name <- .unicode_to_glyph_name(cp)
          if (!is.na(glyph_name)) {
            w <- primary_glyph_widths[glyph_name]
            if (!is.na(w)) {
              total <- total + unname(w)
              next
            }
          }
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
        # CJK, anything else outside the curated bridges: space-width.
        total <- total + default_w
      }
      total
    },
    integer(1L),
    USE.NAMES = FALSE
  )
}

# ---------------------------------------------------------------------
# Indent unit helpers — backend-native padding-left, per depth level
# ---------------------------------------------------------------------
#
# Single source of truth for the per-depth-level indent magnitude in
# each backend's native unit. All three read `preset@indent_size` and
# AFM-derive one space-width of the active body font, then convert to
# the backend's unit. Backends multiply the result by per-cell depth
# (from `page$cells_indent`) at emit time.
#
# Returns 0 when `preset@indent_size <= 0L` so the backends can skip
# native padding emission without a branch.

# `em` per indent level. HTML reads this and emits
# `padding-left: calc(.6rem + Xem)` where X = level * depth. CSS `em`
# is browser-resolved at render time against the current font-size,
# so no further font_size scaling is needed.
.indent_em_per_level <- function(preset) {
  size <- if (is_preset_spec(preset)) preset@indent_size else 2L
  unit_text <- .indent_text_unit(size)
  if (!nzchar(unit_text)) {
    return(0)
  }
  afm_name <- .resolve_afm_name(.effective_font_family(preset))
  as.numeric(.text_width_em(unit_text, afm_name)) / 1000
}

# `pt` per indent level. LaTeX reads this and emits
# `\SetCell{leftsep+=Xpt}` per cell. AFM width is in 1/1000-em units;
# multiplied by the body font size in pt to get absolute pt.
.indent_native_pt_per_level <- function(preset) {
  em <- .indent_em_per_level(preset)
  if (em == 0) {
    return(0)
  }
  font_pt <- if (is_preset_spec(preset)) preset@font_size else 9
  em * font_pt
}

# Twips per indent level. RTF emits `\liN`, DOCX emits
# `<w:ind w:left="N"/>`. 1 pt = 20 twips. Result rounds to the nearest
# whole twip so backends can paste an integer string.
.indent_native_twips_per_level <- function(preset) {
  pt <- .indent_native_pt_per_level(preset)
  if (pt == 0) {
    return(0L)
  }
  as.integer(round(pt * 20))
}
