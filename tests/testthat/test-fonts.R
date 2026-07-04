# fonts.R — resolver + check_fonts() diagnostic.

# ---------------------------------------------------------------------
# .resolve_font_stack — three input shapes
# ---------------------------------------------------------------------

test_that("generic family leads with the Liberation face and ends with the CSS generic", {
  html_serif <- tabular:::.resolve_font_stack("serif", "html")
  expect_identical(html_serif[[1L]], "Liberation Serif")
  expect_identical(html_serif[length(html_serif)], "serif")

  html_sans <- tabular:::.resolve_font_stack("sans", "html")
  expect_identical(html_sans[[1L]], "Liberation Sans")
  expect_identical(html_sans[length(html_sans)], "sans-serif")

  html_mono <- tabular:::.resolve_font_stack("mono", "html")
  expect_identical(html_mono[[1L]], "Liberation Mono")
  expect_identical(html_mono[length(html_mono)], "monospace")
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
      "Liberation Serif",
      "Times New Roman",
      "Times",
      "TeX Gyre Termes",
      "Latin Modern Roman"
    )
  )
  expect_identical(
    tabular:::.resolve_font_stack("sans", "latex"),
    c(
      "Liberation Sans",
      "Arial",
      "Helvetica",
      "TeX Gyre Heros",
      "Latin Modern Sans"
    )
  )
  expect_identical(
    tabular:::.resolve_font_stack("mono", "latex"),
    c(
      "Liberation Mono",
      "Courier New",
      "Courier",
      "TeX Gyre Cursor",
      "Latin Modern Mono"
    )
  )
})

test_that("RTF backend returns the shared core only (no tail)", {
  expect_identical(
    tabular:::.resolve_font_stack("serif", "rtf"),
    c("Liberation Serif", "Times New Roman", "Times")
  )
  expect_identical(
    tabular:::.resolve_font_stack("sans", "rtf"),
    c("Liberation Sans", "Arial", "Helvetica")
  )
  expect_identical(
    tabular:::.resolve_font_stack("mono", "rtf"),
    c("Liberation Mono", "Courier New", "Courier")
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

test_that("check_fonts reports the full IBM Plex chain", {
  skip_if_not_installed("systemfonts")
  spec <- tabular(data.frame(x = 1L)) |> preset(font_family = "IBM Plex Mono")
  joined <- paste(
    testthat::capture_messages(check_fonts(spec)),
    collapse = ""
  )
  expect_match(joined, "IBM Plex Mono", fixed = TRUE)
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
# IBM Plex — recognised opt-in named family
# ---------------------------------------------------------------------

test_that("IBM Plex leads a metric-compatible chain per backend", {
  # HTML: lead + Liberation/Courier fallback + CSS generic tail.
  expect_identical(
    tabular:::.resolve_font_stack("IBM Plex Mono", "html"),
    c("IBM Plex Mono", "Liberation Mono", "Courier New", "monospace")
  )
  # LaTeX: ends in Latin Modern Mono so the \IfFontExistsTF cascade
  # cannot fail when IBM Plex is absent.
  expect_identical(
    tabular:::.resolve_font_stack("IBM Plex Mono", "latex"),
    c(
      "IBM Plex Mono",
      "Liberation Mono",
      "Courier New",
      "TeX Gyre Cursor",
      "Latin Modern Mono"
    )
  )
  # RTF: shared lead + fallback only (no tail; \*\falt handles it).
  expect_identical(
    tabular:::.resolve_font_stack("IBM Plex Mono", "rtf"),
    c("IBM Plex Mono", "Liberation Mono", "Courier New")
  )
  # Sans lead + Liberation Sans / Arial fallback.
  expect_identical(
    tabular:::.resolve_font_stack("IBM Plex Sans", "html"),
    c("IBM Plex Sans", "Liberation Sans", "Arial", "sans-serif")
  )
})

test_that("IBM Plex does not perturb the plain generic chains", {
  # The named family must never leak into the generic cores.
  expect_identical(
    tabular:::.resolve_font_stack("mono", "html"),
    c("Liberation Mono", "Courier New", "Courier", "monospace")
  )
  expect_identical(
    tabular:::.resolve_font_stack("sans", "html"),
    c("Liberation Sans", "Arial", "Helvetica", "sans-serif")
  )
})

test_that("every .font_named_chains key has a class in the shared SSOT", {
  # Drift guard: a named face with no .font_to_family_class entry would
  # resolve fam = NULL and drop its backend tail / mis-measure.
  named <- names(tabular:::.font_named_chains)
  classes <- vapply(
    named,
    function(nm) tabular:::.font_to_family_class[[nm]] %||% NA_character_,
    character(1L)
  )
  expect_false(anyNA(classes))
  expect_true(all(classes %in% c("mono", "sans", "serif")))
})

test_that("IBM Plex classifies for both Word backends via the SSOT", {
  expect_identical(tabular:::.font_generic_class("IBM Plex Mono"), "mono")
  expect_identical(tabular:::.font_generic_class("IBM Plex Sans"), "sans")
  expect_identical(tabular:::.rtf_family_class("IBM Plex Mono"), "fmodern")
  expect_identical(tabular:::.docx_font_class("IBM Plex Mono"), "modern")
  expect_identical(tabular:::.rtf_family_class("IBM Plex Sans"), "fswiss")
  expect_identical(tabular:::.docx_font_class("IBM Plex Sans"), "swiss")
})

test_that(".html_font_face_block emits only for a named IBM Plex face", {
  mono <- tabular:::.html_font_face_block(
    tabular:::.resolve_font_stack("IBM Plex Mono", "html")
  )
  expect_length(mono, 2L) # Regular + Medium
  expect_true(all(grepl("@font-face", mono, fixed = TRUE)))
  expect_true(any(grepl("font-weight: 500 700", mono, fixed = TRUE)))
  expect_true(all(grepl("unicode-range:", mono, fixed = TRUE)))
  expect_true(all(grepl('format("woff2")', mono, fixed = TRUE)))
  expect_true(all(grepl('local("IBM Plex Mono")', mono, fixed = TRUE)))

  sans <- tabular:::.html_font_face_block(
    tabular:::.resolve_font_stack("IBM Plex Sans", "html")
  )
  expect_length(sans, 3L) # Regular + Medium + SemiBold
  expect_true(any(grepl("font-weight: 600 700", sans, fixed = TRUE)))

  serif <- tabular:::.html_font_face_block(
    tabular:::.resolve_font_stack("IBM Plex Serif", "html")
  )
  expect_length(serif, 2L) # Regular + SemiBold
  expect_true(all(grepl('local("IBM Plex Serif")', serif, fixed = TRUE)))
  expect_true(any(grepl("font-weight: 600 700", serif, fixed = TRUE)))

  # The default (Liberation) chain injects nothing.
  expect_identical(
    tabular:::.html_font_face_block(
      tabular:::.resolve_font_stack("mono", "html")
    ),
    character()
  )
})
