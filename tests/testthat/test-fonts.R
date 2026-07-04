# fonts.R — resolver + check_fonts() diagnostic.

# ---------------------------------------------------------------------
# .resolve_font_stack — three input shapes
# ---------------------------------------------------------------------

test_that("generic family leads with the Office face and ends with the CSS generic", {
  html_serif <- tabular:::.resolve_font_stack("serif", "html")
  expect_identical(html_serif[[1L]], "Times New Roman")
  expect_identical(html_serif[length(html_serif)], "serif")

  html_sans <- tabular:::.resolve_font_stack("sans", "html")
  expect_identical(html_sans[[1L]], "Arial")
  expect_identical(html_sans[length(html_sans)], "sans-serif")

  html_mono <- tabular:::.resolve_font_stack("mono", "html")
  expect_identical(html_mono[[1L]], "Courier New")
  expect_identical(html_mono[length(html_mono)], "monospace")
})

test_that("Liberation is the last named face before the generic tail (#phantom-in-Word)", {
  # Regression: leading with Liberation made Word show a phantom
  # "Liberation Mono" in its font menu. Office face leads, Liberation last.
  mono_rtf <- tabular:::.resolve_font_stack("mono", "rtf")
  expect_identical(mono_rtf[[1L]], "Courier New")
  expect_identical(mono_rtf[[length(mono_rtf)]], "Liberation Mono")
  # And a bare "Courier New" request now leads with Courier New, not
  # Liberation Mono (the latent alias bug).
  expect_identical(
    tabular:::.resolve_font_stack("Courier New", "rtf")[[1L]],
    "Courier New"
  )
})

test_that("CSS aliases sans-serif and monospace normalise to the same chains", {
  expect_identical(
    tabular:::.resolve_font_stack("sans-serif", "html"),
    tabular:::.resolve_font_stack("sans", "html")
  )
  expect_identical(
    tabular:::.resolve_font_stack("monospace", "html"),
    tabular:::.resolve_font_stack("mono", "html")
  )
})

test_that("LaTeX backend appends TeX Gyre + Latin Modern tail after the shared core", {
  expect_identical(
    tabular:::.resolve_font_stack("serif", "latex"),
    c(
      "Times New Roman",
      "Times",
      "Liberation Serif",
      "TeX Gyre Termes",
      "Latin Modern Roman"
    )
  )
  expect_identical(
    tabular:::.resolve_font_stack("sans", "latex"),
    c(
      "Arial",
      "Helvetica",
      "Liberation Sans",
      "TeX Gyre Heros",
      "Latin Modern Sans"
    )
  )
  expect_identical(
    tabular:::.resolve_font_stack("mono", "latex"),
    c(
      "Courier New",
      "Courier",
      "Liberation Mono",
      "TeX Gyre Cursor",
      "Latin Modern Mono"
    )
  )
})

test_that("RTF backend returns the shared core only (no tail)", {
  expect_identical(
    tabular:::.resolve_font_stack("serif", "rtf"),
    c("Times New Roman", "Times", "Liberation Serif")
  )
  expect_identical(
    tabular:::.resolve_font_stack("sans", "rtf"),
    c("Arial", "Helvetica", "Liberation Sans")
  )
  expect_identical(
    tabular:::.resolve_font_stack("mono", "rtf"),
    c("Courier New", "Courier", "Liberation Mono")
  )
})

test_that("PS-era named aliases expand to the corresponding generic chain", {
  # Times -> serif chain
  expect_identical(
    tabular:::.resolve_font_stack("Times", "rtf"),
    tabular:::.resolve_font_stack("serif", "rtf")
  )
  expect_identical(
    tabular:::.resolve_font_stack("Times New Roman", "html"),
    tabular:::.resolve_font_stack("serif", "html")
  )
  # Arial / Helvetica -> sans chain
  expect_identical(
    tabular:::.resolve_font_stack("Arial", "latex"),
    tabular:::.resolve_font_stack("sans", "latex")
  )
  expect_identical(
    tabular:::.resolve_font_stack("Helvetica", "html"),
    tabular:::.resolve_font_stack("sans", "html")
  )
  # Courier / Courier New -> mono chain
  expect_identical(
    tabular:::.resolve_font_stack("Courier", "rtf"),
    tabular:::.resolve_font_stack("mono", "rtf")
  )
  expect_identical(
    tabular:::.resolve_font_stack("Courier New", "latex"),
    tabular:::.resolve_font_stack("mono", "latex")
  )
})

test_that("non-aliased single named font still returns verbatim", {
  expect_identical(
    tabular:::.resolve_font_stack("Inter", "html"),
    "Inter"
  )
  expect_identical(
    tabular:::.resolve_font_stack("Source Serif Pro", "rtf"),
    "Source Serif Pro"
  )
})

test_that("explicit length-2 vector bypasses the alias table (escape hatch)", {
  # Without escape hatch, "Times" -> serif chain. With the
  # length>1 form, the user gets exactly what they typed.
  expect_identical(
    tabular:::.resolve_font_stack(c("Times", "Times"), "rtf"),
    c("Times", "Times")
  )
  expect_identical(
    tabular:::.resolve_font_stack(c("Courier New", "mono"), "latex"),
    c("Courier New", "mono")
  )
})

test_that("single non-aliased named font emits verbatim with no fabricated fallback", {
  # PS-era aliases (Times / Arial / Courier and _New variants) DO
  # expand to the generic chain — see the alias-expansion tests
  # below. This test pins the non-aliased path.
  expect_identical(
    tabular:::.resolve_font_stack("JetBrains Mono", "html"),
    "JetBrains Mono"
  )
  expect_identical(
    tabular:::.resolve_font_stack("Inter", "latex"),
    "Inter"
  )
})

test_that("explicit vector stack passes through verbatim", {
  expect_identical(
    tabular:::.resolve_font_stack(c("Courier New", "mono"), "html"),
    c("Courier New", "mono")
  )
  expect_identical(
    tabular:::.resolve_font_stack(
      c("Inter", "Source Sans Pro", "sans"),
      "latex"
    ),
    c("Inter", "Source Sans Pro", "sans")
  )
})

test_that("empty input falls back to mono default", {
  expect_identical(
    tabular:::.resolve_font_stack(character(), "html"),
    tabular:::.resolve_font_stack("mono", "html")
  )
})

# ---------------------------------------------------------------------
# .html_quote_font — CSS quoting rules
# ---------------------------------------------------------------------

test_that("html_quote_font leaves generics + single-word names unquoted", {
  expect_identical(tabular:::.html_quote_font("serif"), "serif")
  expect_identical(tabular:::.html_quote_font("monospace"), "monospace")
  expect_identical(tabular:::.html_quote_font("system-ui"), "system-ui")
  expect_identical(
    tabular:::.html_quote_font("-apple-system"),
    "-apple-system"
  )
  expect_identical(tabular:::.html_quote_font("Georgia"), "Georgia")
  expect_identical(tabular:::.html_quote_font("Inter"), "Inter")
})

test_that("html_quote_font wraps multi-word names in quotes", {
  expect_identical(
    tabular:::.html_quote_font("Times New Roman"),
    "\"Times New Roman\""
  )
  expect_identical(
    tabular:::.html_quote_font("Source Code Pro"),
    "\"Source Code Pro\""
  )
})

# ---------------------------------------------------------------------
# .is_generic_family + .normalize_generic
# ---------------------------------------------------------------------

test_that("is_generic_family recognises the five accepted keywords", {
  expect_true(tabular:::.is_generic_family("serif"))
  expect_true(tabular:::.is_generic_family("sans"))
  expect_true(tabular:::.is_generic_family("sans-serif"))
  expect_true(tabular:::.is_generic_family("mono"))
  expect_true(tabular:::.is_generic_family("monospace"))
})

test_that("is_generic_family rejects named fonts and vectors", {
  expect_false(tabular:::.is_generic_family("Times New Roman"))
  expect_false(tabular:::.is_generic_family("Inter"))
  expect_false(tabular:::.is_generic_family(c("serif", "sans")))
})

test_that("normalize_generic collapses CSS aliases", {
  expect_identical(tabular:::.normalize_generic("sans-serif"), "sans")
  expect_identical(tabular:::.normalize_generic("monospace"), "mono")
  expect_identical(tabular:::.normalize_generic("serif"), "serif")
})

# ---------------------------------------------------------------------
# check_fonts() — diagnostic
# ---------------------------------------------------------------------

test_that("check_fonts requires systemfonts and accepts tabular_spec input", {
  skip_if_not_installed("systemfonts")
  spec <- tabular(data.frame(x = 1L))
  msgs <- testthat::capture_messages(check_fonts(spec))
  joined <- paste(msgs, collapse = "")
  # Default font_family is "mono" — the chain header should show it.
  expect_match(joined, "mono", fixed = TRUE)
  expect_match(joined, "backend:", fixed = TRUE)
})

test_that("check_fonts accepts preset_spec input directly", {
  skip_if_not_installed("systemfonts")
  p <- preset_spec(font_family = "mono")
  msgs <- testthat::capture_messages(check_fonts(p))
  expect_match(paste(msgs, collapse = ""), "mono", fixed = TRUE)
})

test_that("check_fonts reports the default mono chain", {
  skip_if_not_installed("systemfonts")
  spec <- tabular(data.frame(x = 1L)) |> preset(font_family = "mono")
  joined <- paste(
    testthat::capture_messages(check_fonts(spec)),
    collapse = ""
  )
  expect_match(joined, "Courier New", fixed = TRUE)
  expect_match(joined, "Liberation Mono", fixed = TRUE)
  expect_match(joined, "Latin Modern Mono", fixed = TRUE)
})

test_that("check_fonts errors on non-spec input", {
  expect_error(check_fonts(data.frame()), class = "tabular_error_input")
  expect_error(check_fonts("string"), class = "tabular_error_input")
})

test_that(".font_status marks generics with the always-available token", {
  generic <- tabular:::.font_status("serif")
  expect_identical(generic$marker, "o")
  expect_match(generic$note, "generic", fixed = TRUE)
})

test_that(".font_status marks a clearly-missing font as not on this machine", {
  skip_if_not_installed("systemfonts")
  out <- tabular:::.font_status("This Font Definitely Does Not Exist 9999")
  expect_identical(out$marker, "x")
  expect_match(out$note, "not on this machine", fixed = TRUE)
})

test_that(".font_generic_class classifies stacks the same way for both Word backends", {
  # The shared SSOT both RTF and DOCX consult, so a font_family classes
  # identically across them. Mono wins first, then serif, then sans; an
  # unrecognised face returns NA_character_ (each backend then applies its
  # OWN unclassified default -- RTF \froman, DOCX swiss -- as asserted
  # below), it does NOT itself fall back to sans.
  expect_identical(tabular:::.font_generic_class("mono"), "mono")
  expect_identical(tabular:::.font_generic_class("serif"), "serif")
  expect_identical(tabular:::.font_generic_class("sans"), "sans")
  # Explicit mono stack (the PHUSE harness case) classes mono, not sans.
  expect_identical(
    tabular:::.font_generic_class(c(
      "Courier New",
      "Liberation Mono",
      "Courier"
    )),
    "mono"
  )
  # Mixed name + generic resolves to the in-stack signal.
  expect_identical(
    tabular:::.font_generic_class(c("Courier New", "mono")),
    "mono"
  )
  expect_identical(tabular:::.font_generic_class(c("Inter", "sans")), "sans")
  # Unrecognised single named face -> NA (each backend picks its own
  # unclassified default: RTF \froman, DOCX swiss).
  expect_identical(
    tabular:::.font_generic_class("Wingdings 9000"),
    NA_character_
  )
  expect_identical(tabular:::.rtf_family_class("Wingdings 9000"), "froman")
  # RTF maps the classifier to the same class DOCX gives the stack.
  rtf_cls <- tabular:::.rtf_family_class(c("Courier New", "Liberation Mono"))
  docx_cls <- tabular:::.docx_font_class(c("Courier New", "Liberation Mono"))
  expect_identical(rtf_cls, "fmodern")
  expect_identical(docx_cls, "modern")
  # DOCX maps the serif / sans / unclassified generic classes to OOXML:
  # serif -> roman, sans and unknown -> swiss (the variable-pitch default).
  expect_identical(tabular:::.docx_font_class("Times New Roman"), "roman")
  expect_identical(tabular:::.docx_font_class("Arial"), "swiss")
  expect_identical(tabular:::.docx_font_class("Wingdings 9000"), "swiss")
})

# ---------------------------------------------------------------------
# Arbitrary named fonts — verbatim, no bundling
# ---------------------------------------------------------------------

test_that("an arbitrary named font resolves verbatim with no fallback", {
  # tabular bundles no fonts: a named face is emitted as-is and the
  # consuming app substitutes when it is not installed.
  for (backend in c("html", "latex", "rtf")) {
    expect_identical(
      tabular:::.resolve_font_stack("IBM Plex Mono", backend),
      "IBM Plex Mono"
    )
    expect_identical(
      tabular:::.resolve_font_stack("Source Code Pro", backend),
      "Source Code Pro"
    )
  }
})

test_that("an unrecognised named font carries no Word class (backend default applies)", {
  # No .font_named_chains / SSOT entry -> NA -> RTF \froman, DOCX swiss.
  expect_identical(
    tabular:::.font_generic_class("IBM Plex Mono"),
    NA_character_
  )
  expect_identical(tabular:::.rtf_family_class("IBM Plex Mono"), "froman")
  expect_identical(tabular:::.docx_font_class("IBM Plex Mono"), "swiss")
})
