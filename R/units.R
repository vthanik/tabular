# units.R — page-geometry unit parsing + conversion. Used by
# `preset_spec`'s validator, `backend_latex`'s `\geometry{}`
# composer, `geometry.R`'s row-budget twips math, and the RTF /
# DOCX backends (Steps 18 / 19) when they land.
#
# Accepted unit syntax (TeX-style, what `geometry`, `RTF`, and
# OOXML all consume natively):
#
#   in   inches              (1 in = 1440 twips)
#   cm   centimetres         (1 cm = 567   twips, 1/2.54 in)
#   mm   millimetres         (1 mm = 56.7  twips)
#   pt   TeX points          (1 pt = 20    twips, 1/72.27 in)
#   pc   picas (12pt)        (1 pc = 240   twips)
#
# Rejected:
#
#   %    print pages have no viewport; percent has no meaning
#   em / ex / rem            font-relative — margins live in
#                            page geometry, not text flow
#   px   screen-relative; print rendering has no fixed DPI
#
# Numeric input (no unit suffix) is interpreted as inches —
# matches the pre-existing preset-margin contract and keeps
# back-compat with every spec already in the codebase.

# Twips conversion factors. Twips is the universal print-
# typography integer unit (1/1440 inch); all backends end up
# converting to it eventually for pagination math.
.tabular_unit_twips <- c(
  "in" = 1440,
  "cm" = 1440 / 2.54,
  "mm" = 1440 / 25.4,
  "pt" = 20,
  "pc" = 240,
  # CSS px: 96 px = 1 in by CSS spec, so 1 px = 15 twips
  # (matches gt's `convert_to_pt()` factor of 0.75 pt/px in
  # gt/R/utils_render_latex.R).
  "px" = 15
)

# Parse one dimension string into `list(value, unit)`. Accepts
# either a bare numeric (interpreted as inches) or a character
# of the form `<number><unit>` where `<unit>` is one of in / cm
# / mm / pt / pc. Used by the per-side margin validator.
.parse_dim <- function(
  x,
  allow_percent = FALSE,
  call = rlang::caller_env()
) {
  if (is.numeric(x)) {
    if (length(x) != 1L || is.na(x) || !is.finite(x) || x < 0) {
      cli::cli_abort(
        c(
          "Bad dimension {.val {x}}.",
          "i" = "Numeric values must be length-1, non-negative, and finite."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(list(value = as.numeric(x), unit = "in"))
  }
  if (is.character(x)) {
    if (length(x) != 1L || is.na(x) || !nzchar(x)) {
      cli::cli_abort(
        c(
          "Bad dimension {.val {x}}.",
          "i" = "Character values must be length-1 and non-empty."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    m <- regmatches(
      x,
      regexec(
        "^\\s*([0-9]*\\.?[0-9]+)\\s*([a-zA-Z%]+)?\\s*$",
        x
      )
    )[[1L]]
    if (length(m) < 3L || !nzchar(m[[2L]])) {
      cli::cli_abort(
        c(
          "Cannot parse dimension {.val {x}}.",
          "i" = "Expected the form {.code <number><unit>}, e.g. {.val 2cm}, {.val 0.75in}, {.val 30pt}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    value <- as.numeric(m[[2L]])
    unit <- tolower(m[[3L]])
    if (!nzchar(unit)) {
      unit <- "in"
    }
    accepted <- names(.tabular_unit_twips)
    if (allow_percent) {
      accepted <- c(accepted, "%")
    }
    if (!(unit %in% accepted)) {
      hint <- if (allow_percent) {
        "Percent is only valid for column widths, not for page geometry."
      } else {
        "Percent, em / ex / rem, and px are not valid for page geometry."
      }
      cli::cli_abort(
        c(
          "Unsupported unit {.val {unit}} in {.val {x}}.",
          "i" = "Accepted units: {.val {accepted}}.",
          "i" = hint
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    if (is.na(value) || !is.finite(value) || value < 0) {
      cli::cli_abort(
        c(
          "Bad dimension {.val {x}}.",
          "i" = "Numeric component must be non-negative, finite, and parseable."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    if (identical(unit, "%") && value > 100) {
      cli::cli_abort(
        c(
          "Bad percent dimension {.val {x}}.",
          "i" = "Percent values must be between 0 and 100."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(list(value = value, unit = unit))
  }
  cli::cli_abort(
    c(
      "Bad dimension {.obj_type_friendly {x}}.",
      "i" = "Pass a number (interpreted as inches) or a character with a TeX unit suffix (e.g. {.val 2cm})."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# Convenience predicate: is this parsed dimension a percent?
# Useful for backends that route percent to a proportional column
# spec (tabularray `X[N]`, HTML `style="width:N%"`).
.is_percent_dim <- function(parsed) {
  identical(parsed$unit, "%")
}

# Convert a parsed dimension to twips. Inverse of `.parse_dim`.
.dim_to_twips <- function(parsed) {
  parsed$value * .tabular_unit_twips[[parsed$unit]]
}

# Convert a parsed dimension to inches. Used by code paths that
# still think in inches (e.g. some legacy helpers); the canonical
# path is twips.
.dim_to_inches <- function(parsed) {
  .dim_to_twips(parsed) / 1440
}

# Round-trip a parsed dimension back to its string form. Used by
# `backend_latex` when emitting `\geometry{top=Xunit, ...}`.
.dim_format <- function(parsed) {
  sprintf("%g%s", parsed$value, parsed$unit)
}

# Parse a `preset@margins` vector into a list of parsed
# dimensions. Accepts length 1, 2, or 4 vectors (CSS shorthand);
# the caller is responsible for length validation. Always
# returns a list-of-parsed, regardless of whether the input was
# numeric or character.
.parse_margins <- function(margins, call = rlang::caller_env()) {
  lapply(seq_along(margins), function(i) {
    .parse_dim(margins[[i]], call = call)
  })
}
