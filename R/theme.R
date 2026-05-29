# theme.R — single source of truth for the styling SSOT.
#
# Every border / rule / chrome literal that used to be scattered and
# hardcoded across the backends now lives here:
#
#   * LaTeX  `0.4pt`            -> `.tabular_rule_width` (0.5pt)
#   * HTML   `1px #212529`      -> `.tabular_rule_width` + `.tabular_ink`
#   * HTML   `#adb5bd`          -> `.tabular_muted`
#   * RTF    `\brdrw10`         -> `.tabular_rule_width` (10 twips = 0.5pt)
#   * DOCX   `w:sz="4"`         -> `.tabular_rule_width` (4 eighths = 0.5pt)
#
# The file exposes three pure resolvers consumed by the preset
# lowering (`.preset_rules_to_layers()` / `_spacing_` / `_stripe_`)
# and the engine (`as_grid()` metadata):
#
#   resolve_rules(rules)    -> per-key resolved border triple list
#   resolve_spacing(sp)     -> per-region c(above, below) list
#   gap_counts(sp)          -> the five physical inter-section gaps
#   resolve_stripe(st)      -> c(odd, even) zebra fills or NULL
#
# plus `.fidelity_warn()`, the deduped one-shot warning emitted when a
# backend cannot natively honour a resolved style and must emulate it.

# ---------------------------------------------------------------------
# Palette + canonical rule width
# ---------------------------------------------------------------------

# Primary ink — rules, body text, header text. The clinical Appendix-I
# baseline draws thin solid ink rules around the header and footer
# blocks. `#212529` is Bootstrap's default body colour (matches the
# HTML backend's prior literal).
.tabular_ink <- "#212529"

# Muted ink — column-spanner underlines and other secondary rules.
# Lighter than the primary ink so a spanner band reads as subordinate
# to the column-label divider.
.tabular_muted <- "#adb5bd"

# Chrome text — page-head / page-foot band text (program path,
# pagination). Mid-grey, never as dark as the table body.
.tabular_chrome <- "#495057"

# Canonical thin rule width in points. RTF's `\brdrw10` (10 twips) and
# DOCX's `w:sz="4"` (4 eighths-of-a-point) are already 0.5pt; LaTeX's
# `0.4pt` and HTML's `1px` (~0.75pt) are the two outliers this constant
# normalises.
.tabular_rule_width <- 0.5

# ---------------------------------------------------------------------
# Rule vocabulary
# ---------------------------------------------------------------------

# The nine rules, all sharing the `*rule` suffix for one consistent
# family. Six horizontal (the booktabs top/mid/bottom plus span / row /
# footnote) and three vertical (left / right outer edges plus the
# interior column separator).
.tabular_rule_keys <- c(
  "toprule",
  "midrule",
  "bottomrule",
  "spanrule",
  "rowrule",
  "footnoterule",
  "leftrule",
  "rightrule",
  "colrule"
)

.tabular_rule_horizontal <- c(
  "toprule",
  "midrule",
  "bottomrule",
  "spanrule",
  "rowrule",
  "footnoterule"
)

.tabular_rule_vertical <- c("leftrule", "rightrule", "colrule")

# The named string-sugar presets accepted as `rules = "<name>"`.
.tabular_rule_presets <- c("booktabs", "grid", "frame", "none")

# A resolved rule triple uses the colour TOKENS "ink" / "muted"; the
# final pass (`.resolve_rule_tokens()`) maps them to hex. Storing the
# token keeps the baseline declarative and lets a single palette edit
# recolour every default rule.
.rule_ink <- function() {
  list(style = "solid", width = .tabular_rule_width, color = "ink")
}
.rule_muted <- function() {
  list(style = "solid", width = .tabular_rule_width, color = "muted")
}

# Baseline rule set — the clinical Appendix-I default and the value of
# `rules = "booktabs"`. NOTE this is the regulatory baseline, not the
# bare three-rule LaTeX booktabs look: the column-spanner underline
# (`spanrule`, muted) is ON because it is a load-bearing layout
# invariant in the canonical submission contract.
#
# `bottomrule` and `footnoterule` are MUTUALLY EXCLUSIVE: exactly one
# rule sits at the data -> footnote boundary, never two. The default is
# `bottomrule` (table-width, ink, closing the body); `footnoterule` is
# OFF. A user who prefers the footnote-section-opens-with-a-rule look
# turns `footnoterule` on (and, to avoid the double rule, `bottomrule`
# off) through the `rules` knob. When drawn, `footnoterule` matches the
# `toprule` width (table/content width), NOT the full page width.
#
# `footnoterule` is drawn as a distinct footnote-section rule only by
# the PAGINATED backends: RTF, LaTeX / PDF, and DOCX. HTML is continuous
# (no separate footnote section), so it FOLDS both into one rule:
# whichever of `bottomrule` / `footnoterule` is active becomes the
# table's bottom edge (bottomrule wins when both are set). `rowrule` and
# the three verticals are OFF.
.tabular_rule_booktabs <- function() {
  list(
    toprule = .rule_ink(),
    midrule = .rule_ink(),
    bottomrule = .rule_ink(),
    spanrule = .rule_muted(),
    rowrule = NULL,
    footnoterule = NULL,
    leftrule = NULL,
    rightrule = NULL,
    colrule = NULL
  )
}

# Full grid — every edge inked: the six horizontals plus the three
# verticals. Uniform ink (the spanner divider is no longer subordinate
# when the whole table is gridded).
.tabular_rule_grid <- function() {
  out <- stats::setNames(
    rep(list(.rule_ink()), length(.tabular_rule_keys)),
    .tabular_rule_keys
  )
  out
}

# Outer box only — the four outer edges (top / bottom / left / right),
# no interior rules. `midrule` (under the column labels) is interior,
# so it is OFF for a frame.
.tabular_rule_frame <- function() {
  out <- .tabular_rule_none()
  out$toprule <- .rule_ink()
  out$bottomrule <- .rule_ink()
  out$leftrule <- .rule_ink()
  out$rightrule <- .rule_ink()
  out
}

# No rules at all.
.tabular_rule_none <- function() {
  stats::setNames(
    rep(list(NULL), length(.tabular_rule_keys)),
    .tabular_rule_keys
  )
}

.tabular_rule_preset_table <- function(name) {
  switch(
    name,
    booktabs = .tabular_rule_booktabs(),
    grid = .tabular_rule_grid(),
    frame = .tabular_rule_frame(),
    none = .tabular_rule_none(),
    NULL
  )
}

# Resolve "ink" / "muted" colour tokens to hex; pass every other value
# (explicit hex, CSS name, "currentColor") through unchanged.
.resolve_rule_color <- function(color) {
  if (is.null(color) || length(color) != 1L || is.na(color)) {
    return(color)
  }
  switch(color, ink = .tabular_ink, muted = .tabular_muted, color)
}

.resolve_rule_tokens <- function(triple) {
  if (is.null(triple)) {
    return(NULL)
  }
  triple$color <- .resolve_rule_color(triple$color)
  triple
}

# Coerce one `rules` named-list entry to a resolved triple-or-NULL.
# Accepts a `tabular_brdr`, a bare list(style, width, color), the
# "none"/"off" clear sentinel, or NULL.
.rule_entry_to_triple <- function(v) {
  if (is.null(v)) {
    return(NULL)
  }
  if (is.character(v) && length(v) == 1L && v %in% c("none", "off")) {
    return(NULL)
  }
  if (is_brdr(v)) {
    triple <- unclass(v)
    if (identical(triple$style, "none")) {
      return(NULL)
    }
    return(triple)
  }
  if (is.list(v) && all(c("style", "width", "color") %in% names(v))) {
    if (identical(v$style, "none")) {
      return(NULL)
    }
    return(v[c("style", "width", "color")])
  }
  NULL
}

#' Resolve the `rules` knob into a per-rule border triple list
#'
#' Pure knob-expander. Accepts the three `preset(rules = )` input
#' forms and returns a fixed-shape named list over the nine rule keys
#' (`toprule`, `midrule`, ..., `colrule`), each entry either a resolved
#' `list(style, width, color)` triple (colour tokens mapped to hex) or
#' `NULL` (rule off). Consumed by `.preset_rules_to_layers()`.
#'
#' @param rules One of:
#'   * `character(1)` string sugar: `"booktabs"` (default, the clinical
#'     baseline), `"grid"`, `"frame"`, `"none"`.
#'   * a single `brdr()` broadcast to every active (non-NULL) baseline
#'     rule, recolouring / reweighting them in one line.
#'   * a named list keyed by rule name, overlaid onto the booktabs
#'     baseline (unlisted rules keep their default; the bare string
#'     `"none"` drops a rule).
#' @param call Caller environment for error reporting.
#' @return Named list of length 9; each entry a triple or `NULL`.
#' @keywords internal
#' @noRd
resolve_rules <- function(rules = "booktabs", call = rlang::caller_env()) {
  base <- .rules_from_input(rules, call = call)
  lapply(base, .resolve_rule_tokens)
}

.rules_from_input <- function(rules, call) {
  # Form 1 — string sugar.
  if (is.character(rules) && length(rules) == 1L && !is.na(rules)) {
    out <- .tabular_rule_preset_table(rules)
    if (is.null(out)) {
      presets <- .tabular_rule_presets
      cli::cli_abort(
        c(
          "Unknown {.arg rules} preset {.val {rules}}.",
          "i" = "Use one of {.val {presets}}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    return(out)
  }
  # Form 2 — single brdr() broadcast onto every active baseline rule.
  if (is_brdr(rules)) {
    triple <- unclass(rules)
    base <- .tabular_rule_booktabs()
    for (key in .tabular_rule_keys) {
      if (!is.null(base[[key]])) {
        base[[key]] <- triple[c("style", "width", "color")]
      }
    }
    return(base)
  }
  # Form 3 — named list overlay onto the booktabs baseline.
  if (is.list(rules)) {
    valid <- .tabular_rule_keys
    bad <- setdiff(names(rules), valid)
    if (length(bad) > 0L) {
      cli::cli_abort(
        c(
          "Unknown rule name{?s} {.val {bad}}.",
          "i" = "Valid rule names: {.val {valid}}."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    base <- .tabular_rule_booktabs()
    for (key in names(rules)) {
      base[[key]] <- .rule_entry_to_triple(rules[[key]])
    }
    return(base)
  }
  cli::cli_abort(
    c(
      "{.arg rules} must be a preset name, a single {.fn brdr}, or a named list.",
      "x" = "You supplied {.obj_type_friendly {rules}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# ---------------------------------------------------------------------
# Spacing
# ---------------------------------------------------------------------

# The four spacing regions and which sides each accepts. `footnote`
# only carries an `above` gap (the bottomrule already closes the body;
# nothing sits below the footnotes inside the data section).
.tabular_spacing_keys <- c("title", "body", "subgroup", "footnote")
.tabular_spacing_sides <- list(
  title = c("above", "below"),
  body = c("above", "below"),
  subgroup = c("above", "below"),
  footnote = "above"
)

# Region defaults. `title` 1/1 enforces the Appendix-I blank line above
# and below the title block; every other region defaults to 0.
.tabular_spacing_default <- function() {
  list(
    title = c(above = 1L, below = 1L),
    body = c(above = 0L, below = 0L),
    subgroup = c(above = 0L, below = 0L),
    footnote = c(above = 0L)
  )
}

#' Resolve the `spacing` knob into a per-region gap list
#'
#' Pure resolver. Overlays a user `spacing` named list onto the region
#' defaults, returning a fixed-shape list keyed by the four regions,
#' each a named integer vector of its accepted sides.
#'
#' @param spacing `NULL` (all defaults) or a named list keyed by
#'   region (`title` / `body` / `subgroup` / `footnote`), each a named
#'   numeric vector `c(above = , below = )` (footnote: `above` only).
#' @param call Caller environment for error reporting.
#' @return Named list of length 4.
#' @keywords internal
#' @noRd
resolve_spacing <- function(spacing = NULL, call = rlang::caller_env()) {
  out <- .tabular_spacing_default()
  if (is.null(spacing)) {
    return(out)
  }
  if (!is.list(spacing)) {
    cli::cli_abort(
      c(
        "{.arg spacing} must be a named list keyed by region.",
        "x" = "You supplied {.obj_type_friendly {spacing}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  regions <- .tabular_spacing_keys
  bad <- setdiff(names(spacing), regions)
  if (length(bad) > 0L) {
    cli::cli_abort(
      c(
        "Unknown spacing region{?s} {.val {bad}}.",
        "i" = "Valid regions: {.val {regions}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  for (region in names(spacing)) {
    val <- spacing[[region]]
    sides <- .tabular_spacing_sides[[region]]
    for (side in names(val)) {
      if (!(side %in% sides)) {
        cli::cli_abort(
          c(
            "Region {.val {region}} accepts only {.val {sides}}.",
            "x" = "You supplied side {.val {side}}."
          ),
          class = "tabular_error_input",
          call = call
        )
      }
      n <- val[[side]]
      if (
        !is.numeric(n) ||
          length(n) != 1L ||
          is.na(n) ||
          n < 0 ||
          n != as.integer(n)
      ) {
        cli::cli_abort(
          c(
            "Spacing {.val {region}}.{.val {side}} must be a non-negative integer.",
            "x" = "You supplied {.val {n}}."
          ),
          class = "tabular_error_input",
          call = call
        )
      }
      out[[region]][[side]] <- as.integer(n)
    }
  }
  out
}

#' Reduce a resolved spacing list to the five physical inter-section gaps
#'
#' Two adjoining region-sides can target the same physical gap; each
#' gap resolves to the MAX of its contributors (never the sum), so a
#' gap can never be accidentally doubled.
#'
#' @param spacing A resolved spacing list (from `resolve_spacing()`) or
#'   a raw `spacing` knob value (resolved internally).
#' @return Named integer vector of the five gaps: `above_title`,
#'   `title_to_body`, `subgroup_above`, `subgroup_to_body`,
#'   `body_to_footnote`.
#' @keywords internal
#' @noRd
gap_counts <- function(spacing = NULL) {
  sp <- if (
    is.list(spacing) &&
      all(.tabular_spacing_keys %in% names(spacing)) &&
      is.numeric(spacing[["title"]])
  ) {
    spacing
  } else {
    resolve_spacing(spacing)
  }
  g <- function(region, side) {
    v <- sp[[region]][[side]]
    if (is.null(v) || is.na(v)) 0L else as.integer(v)
  }
  c(
    above_title = g("title", "above"),
    title_to_body = max(g("title", "below"), g("body", "above")),
    subgroup_above = g("subgroup", "above"),
    subgroup_to_body = max(g("subgroup", "below"), g("body", "above")),
    body_to_footnote = max(g("body", "below"), g("footnote", "above"))
  )
}

# ---------------------------------------------------------------------
# Zebra striping
# ---------------------------------------------------------------------

#' Resolve the `stripe` knob into odd / even body-row fills
#'
#' @param stripe `NULL` (off), a single fill `character(1)` (applied to
#'   even rows; odd rows stay default), or a named vector
#'   `c(odd = , even = )`.
#' @param call Caller environment for error reporting.
#' @return `NULL` (off) or a named character vector `c(odd, even)`
#'   where an absent side is `NA_character_` (transparent).
#' @keywords internal
#' @noRd
resolve_stripe <- function(stripe = NULL, call = rlang::caller_env()) {
  if (is.null(stripe)) {
    return(NULL)
  }
  if (!is.character(stripe) || anyNA(stripe) || !all(nzchar(stripe))) {
    cli::cli_abort(
      c(
        "{.arg stripe} must be a non-empty colour or a named c(odd, even).",
        "x" = "You supplied {.obj_type_friendly {stripe}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (length(stripe) == 1L && is.null(names(stripe))) {
    return(c(odd = NA_character_, even = unname(stripe)))
  }
  nms <- names(stripe)
  bad <- setdiff(nms, c("odd", "even"))
  if (is.null(nms) || length(bad) > 0L) {
    cli::cli_abort(
      c(
        "{.arg stripe} names must be {.val odd} and / or {.val even}.",
        "x" = "You supplied {.val {nms}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  c(
    odd = if ("odd" %in% nms) unname(stripe[["odd"]]) else NA_character_,
    even = if ("even" %in% nms) unname(stripe[["even"]]) else NA_character_
  )
}

# ---------------------------------------------------------------------
# Fidelity warnings
# ---------------------------------------------------------------------

# Per-render dedup set for `.fidelity_warn()`. Backends clear it at the
# start of a render via `.fidelity_warn_reset()` so each (feature,
# backend) pair warns at most once per `tb_render()` call.
.tabular_fidelity_seen <- new.env(parent = emptyenv())

.fidelity_warn_reset <- function() {
  rm(
    list = ls(.tabular_fidelity_seen, all.names = TRUE),
    envir = .tabular_fidelity_seen
  )
  invisible(NULL)
}

# Emit a one-time warning that `backend` cannot natively honour
# `feature` and is emulating it. Deduped per render. `detail` is an
# optional extra cli bullet.
.fidelity_warn <- function(feature, backend, detail = NULL) {
  key <- paste(backend, feature, sep = "\r")
  if (!is.null(.tabular_fidelity_seen[[key]])) {
    return(invisible(NULL))
  }
  assign(key, TRUE, envir = .tabular_fidelity_seen)
  msg <- c(
    "{.field {backend}} cannot natively honour {.val {feature}}; emulating.",
    if (!is.null(detail)) c("i" = detail)
  )
  cli::cli_warn(msg, class = "tabular_warning_fidelity")
  invisible(NULL)
}
