test_that(".resolve_afm_name picks the right family per chain shape", {
  # Empty / NULL -> defaults to serif.
  expect_identical(tabular:::.resolve_afm_name(character(0)), "Times-Roman")

  # Generic family.
  expect_identical(tabular:::.resolve_afm_name("serif"), "Times-Roman")
  expect_identical(tabular:::.resolve_afm_name("sans"), "Helvetica")
  expect_identical(tabular:::.resolve_afm_name("mono"), "Courier")
  expect_identical(tabular:::.resolve_afm_name("sans-serif"), "Helvetica")
  expect_identical(tabular:::.resolve_afm_name("monospace"), "Courier")

  # Alias name (PostScript-era + _New variants).
  expect_identical(tabular:::.resolve_afm_name("Times"), "Times-Roman")
  expect_identical(
    tabular:::.resolve_afm_name("Times New Roman"),
    "Times-Roman"
  )
  expect_identical(tabular:::.resolve_afm_name("Arial"), "Helvetica")
  expect_identical(tabular:::.resolve_afm_name("Courier New"), "Courier")

  # Liberation: not in alias table, but recognised by class.
  expect_identical(
    tabular:::.resolve_afm_name("Liberation Serif"),
    "Times-Roman"
  )
  expect_identical(
    tabular:::.resolve_afm_name("Liberation Sans"),
    "Helvetica"
  )
  expect_identical(
    tabular:::.resolve_afm_name("Liberation Mono"),
    "Courier"
  )

  # Explicit stack: walks top-to-bottom, first hit wins.
  expect_identical(
    tabular:::.resolve_afm_name(c("Liberation Serif", "Times New Roman")),
    "Times-Roman"
  )
  expect_identical(
    tabular:::.resolve_afm_name(c("Arial", "sans")),
    "Helvetica"
  )

  # Unknown font: defaults to serif.
  expect_identical(tabular:::.resolve_afm_name("Inter"), "Times-Roman")
})

test_that(".resolve_afm_name appends weight + italic suffixes", {
  expect_identical(
    tabular:::.resolve_afm_name("serif", bold = TRUE),
    "Times-Bold"
  )
  expect_identical(
    tabular:::.resolve_afm_name("serif", italic = TRUE),
    "Times-Italic"
  )
  expect_identical(
    tabular:::.resolve_afm_name("serif", bold = TRUE, italic = TRUE),
    "Times-BoldItalic"
  )
  # Helvetica + Courier use Oblique, not Italic.
  expect_identical(
    tabular:::.resolve_afm_name("sans", italic = TRUE),
    "Helvetica-Oblique"
  )
  expect_identical(
    tabular:::.resolve_afm_name("mono", bold = TRUE, italic = TRUE),
    "Courier-BoldOblique"
  )
})

test_that(".text_width_em returns canonical AFM widths for ASCII", {
  # Pinned against the Adobe AFM tables R ships under
  # `R.home("library")/grDevices/afm/`. If these shift, our
  # build_font_metrics.R parser is broken.
  expect_identical(tabular:::.text_width_em("M", "Helvetica"), 833L)
  expect_identical(tabular:::.text_width_em("M", "Times-Roman"), 889L)
  expect_identical(tabular:::.text_width_em("M", "Times-Bold"), 944L)
  expect_identical(tabular:::.text_width_em("M", "Courier"), 600L)

  # Sum of glyph widths.
  expect_identical(
    tabular:::.text_width_em("Mi", "Helvetica"),
    833L + 222L
  )

  # Courier is monospaced — every glyph is 600 em.
  expect_identical(
    tabular:::.text_width_em("Hello", "Courier"),
    5L * 600L
  )
})

test_that(".text_width_em handles empty / NA / vector input", {
  expect_identical(tabular:::.text_width_em("", "Helvetica"), 0L)
  expect_identical(tabular:::.text_width_em(NA_character_, "Helvetica"), 0L)
  # Vectorised — one result per element.
  expect_identical(
    tabular:::.text_width_em(c("M", "Mi", ""), "Helvetica"),
    c(833L, 833L + 222L, 0L)
  )
})

test_that(".text_width_em routes Greek through Symbol AGL fallback", {
  # alpha (U+03B1) lives at Symbol slot 97 with width 631.
  expect_identical(
    tabular:::.text_width_em("α", "Times-Roman"),
    631L
  )
  # Mixed Latin + Greek: ASCII portion uses Times-Roman, Greek
  # portion uses Symbol.
  # "p=" measured in Times-Roman + alpha measured in Symbol.
  p_w <- tabular:::.text_width_em("p=", "Times-Roman")
  pa_w <- tabular:::.text_width_em("p=α", "Times-Roman")
  expect_identical(pa_w, p_w + 631L)
})

test_that(".text_width_em routes math operators through Symbol", {
  # ≤ (less-or-equal) lives at Symbol slot 163 with width 549.
  expect_identical(
    tabular:::.text_width_em("≤", "Times-Roman"),
    549L
  )
  # "<0.05" (all ASCII) measured against Times-Roman, vs.
  # "≤0.05" with the math symbol routed to Symbol.
  ascii_w <- tabular:::.text_width_em("<0.05", "Times-Roman")
  math_w <- tabular:::.text_width_em("≤0.05", "Times-Roman")
  expect_true(math_w > 0L)
  # The math glyph is wider than ASCII '<' (Times-Roman '<' is
  # 564 from ≤'s 549 — close, but the structure of the test
  # is that we get a positive width and not the default).
  # Stricter: the math version should NOT equal the case where
  # the codepoint fell back to space width.
  space_w <- tabular:::.text_width_em(" ", "Times-Roman")
  rest_w <- tabular:::.text_width_em("0.05", "Times-Roman")
  expect_false(math_w == space_w + rest_w)
})

test_that(".text_width_em falls back to space-width for unmapped codepoints", {
  # CJK codepoint (U+4E2D, Chinese "middle") — not in any AGL bridge.
  # Falls back to the primary font's space width.
  space_w <- tabular:::.text_width_em(" ", "Times-Roman")
  cjk_w <- tabular:::.text_width_em("中", "Times-Roman")
  expect_identical(cjk_w, space_w)
})

test_that(".text_width_em uses the Latin-1 AGL bridge for accented Latin glyphs", {
  # Æ (U+00C6) is the AE ligature — its AFM width (889 in Times-
  # Roman) is dramatically different from the space fallback (250).
  # The bridge resolves U+00C6 -> "AE" -> 889.
  ae_w <- tabular:::.text_width_em("Æ", "Times-Roman")
  expected <- tabular:::afm_glyph_widths[["Times-Roman"]][["AE"]]
  expect_identical(ae_w, unname(expected))

  # Same for ñ (U+00F1) -> "ntilde". The width matches the AFM's
  # `C -1 ; WX <w> ; N ntilde` entry exactly.
  ntilde_w <- tabular:::.text_width_em("ñ", "Times-Roman")
  expected_n <- tabular:::afm_glyph_widths[["Times-Roman"]][["ntilde"]]
  expect_identical(ntilde_w, unname(expected_n))
})

test_that(".text_width_em handles a full Latin-1 word", {
  # "Müller" — ASCII letters around an Umlaut. Width should be the
  # sum of per-glyph widths.
  glyphs <- tabular:::afm_glyph_widths[["Times-Roman"]]
  expected <- sum(c(
    glyphs[["M"]],
    glyphs[["udieresis"]],
    glyphs[["l"]],
    glyphs[["l"]],
    glyphs[["e"]],
    glyphs[["r"]]
  ))
  actual <- tabular:::.text_width_em("Müller", "Times-Roman")
  expect_identical(actual, as.integer(expected))
})

test_that(".unicode_to_glyph_name returns AGL names for Latin-1 codepoints", {
  expect_equal(tabular:::.unicode_to_glyph_name(0x00E9L), "eacute")
  expect_equal(tabular:::.unicode_to_glyph_name(0x00C6L), "AE")
  expect_equal(tabular:::.unicode_to_glyph_name(0x00F1L), "ntilde")
  expect_equal(tabular:::.unicode_to_glyph_name(0x00F8L), "oslash")
  # ASCII passes through as NA (caller already has a fast path).
  expect_true(is.na(tabular:::.unicode_to_glyph_name(0x0041L)))
  # Outside Latin-1 supplement: NA.
  expect_true(is.na(tabular:::.unicode_to_glyph_name(0x4E2DL)))
})

test_that("ZapfDingbats AFM is bundled with > 100 glyphs", {
  # Phase 4 adds ZapfDingbats to the AFM bundle for Core-14
  # completeness. The font carries decorative checkmarks / bullets
  # / arrows that future presets can pull glyphs from.
  expect_true("ZapfDingbats" %in% names(tabular:::afm_metrics))
  expect_true(length(tabular:::afm_glyph_widths[["ZapfDingbats"]]) > 100L)
})

test_that(".agl_latin1 entries match a real glyph in every Core-12 AFM", {
  # The bridge is only as good as the AFM coverage. Every name in
  # .agl_latin1 must resolve to a non-missing width in every
  # Latin-text Core-12 font (Times, Helvetica, Courier × 4). Symbol
  # / ZapfDingbats are excluded — they don't carry Latin glyphs.
  core_latin_fonts <- c(
    "Helvetica",
    "Helvetica-Bold",
    "Helvetica-Oblique",
    "Helvetica-BoldOblique",
    "Times-Roman",
    "Times-Bold",
    "Times-Italic",
    "Times-BoldItalic",
    "Courier",
    "Courier-Bold",
    "Courier-Oblique",
    "Courier-BoldOblique"
  )
  for (font in core_latin_fonts) {
    tbl <- tabular:::afm_glyph_widths[[font]]
    for (name in unname(tabular:::.agl_latin1)) {
      expect_false(
        is.na(tbl[name]),
        info = sprintf("%s missing in %s", name, font)
      )
    }
  }
})

test_that(".text_width_em errors on unknown AFM name", {
  expect_error(
    tabular:::.text_width_em("M", "Bembo"),
    class = "tabular_error_input"
  )
})

test_that(".agl_symbol entries match Symbol AFM slot widths", {
  # Sanity check that the curated table indexes real slots in
  # Symbol.afm (not a fat-fingered byte position). Every value
  # in .agl_symbol must resolve to a non-missing width in
  # afm_metrics$Symbol.
  symbol_tbl <- tabular:::afm_metrics[["Symbol"]]
  for (cp in names(tabular:::.agl_symbol)) {
    slot <- tabular:::.agl_symbol[[cp]]
    glyph <- rawToChar(as.raw(slot))
    expect_false(
      is.na(symbol_tbl[glyph]),
      info = sprintf("U+%s -> slot %d missing in Symbol AFM", cp, slot)
    )
  }
})
