# preset_validators.R — shape validators for the named-list knobs
# accepted by `preset()` / `set_preset()` (rules / alignment / fonts
# / colors / padding) plus the `spacing` / `stripe` slots. The lowered
# knobs (rules / alignment / fonts / colors / padding) lower to
# `style_layer` records on `@style` via `.preset_args_to_layers()` and
# are validated at `preset()` call time through
# `.validate_lowered_knobs()` (in `R/preset.R`). `spacing` / `stripe`
# are scalar slots validated by the `preset_spec` S7 validator. Every
# validator returns NULL on well-formed input, otherwise an
# error-message string the caller surfaces as `tabular_error_input`.

# ---------------------------------------------------------------------
# rules knob — string preset, single brdr() broadcast, or named list
# keyed by the nine rule names
# ---------------------------------------------------------------------

.preset_rules_shape_error <- function(ru) {
  if (length(ru) == 0L) {
    return(NULL)
  }
  # Form 1 — string sugar.
  if (is.character(ru) && length(ru) == 1L && !is.na(ru)) {
    if (!(ru %in% .tabular_rule_presets)) {
      return(paste0(
        "preset ",
        .sh_quote(ru),
        " is unknown; use one of ",
        paste(.sh_quote(.tabular_rule_presets), collapse = ", ")
      ))
    }
    return(NULL)
  }
  # Form 2 — single brdr() broadcast.
  if (is_brdr(ru)) {
    return(NULL)
  }
  # Form 3 — named list keyed by rule names.
  if (!is.list(ru)) {
    return(paste0(
      "must be a preset name, a single brdr(), or a named list; got ",
      class(ru)[[1]]
    ))
  }
  nms <- names(ru)
  if (is.null(nms) || any(!nzchar(nms)) || anyNA(nms)) {
    return("entries must all be named")
  }
  unknown <- setdiff(nms, .tabular_rule_keys)
  if (length(unknown) > 0L) {
    return(paste0(
      "contains unknown rule(s): ",
      paste(.sh_quote(unknown), collapse = ", "),
      "; recognised: ",
      paste(.sh_quote(.tabular_rule_keys), collapse = ", ")
    ))
  }
  for (k in nms) {
    v <- ru[[k]]
    if (is.null(v)) {
      next
    }
    if (identical(v, "none") || identical(v, "off")) {
      next
    }
    if (is_brdr(v)) {
      next
    }
    if (is.list(v) && all(c("style", "width", "color") %in% names(v))) {
      next
    }
    return(paste0(
      "rule ",
      .sh_quote(k),
      " must be a brdr() value, \"none\", or NULL"
    ))
  }
  NULL
}

# ---------------------------------------------------------------------
# spacing slot — named list keyed by region, each a named numeric
# vector of its accepted sides
# ---------------------------------------------------------------------

.spacing_shape_error <- function(sp) {
  if (length(sp) == 0L) {
    return(NULL)
  }
  if (!is.list(sp)) {
    return(paste0("must be a named list; got ", class(sp)[[1]]))
  }
  nms <- names(sp)
  if (is.null(nms) || any(!nzchar(nms)) || anyNA(nms)) {
    return("entries must all be named")
  }
  unknown <- setdiff(nms, .tabular_spacing_keys)
  if (length(unknown) > 0L) {
    return(paste0(
      "contains unknown region(s): ",
      paste(.sh_quote(unknown), collapse = ", "),
      "; recognised: ",
      paste(.sh_quote(.tabular_spacing_keys), collapse = ", ")
    ))
  }
  for (region in nms) {
    val <- sp[[region]]
    sides <- .tabular_spacing_sides[[region]]
    if (!is.numeric(val) || is.null(names(val))) {
      return(paste0(
        "region ",
        .sh_quote(region),
        " must be a named numeric vector (e.g. c(above = 1, below = 1))"
      ))
    }
    bad_sides <- setdiff(names(val), sides)
    if (length(bad_sides) > 0L) {
      return(paste0(
        "region ",
        .sh_quote(region),
        " accepts only ",
        paste(.sh_quote(sides), collapse = ", "),
        "; got ",
        paste(.sh_quote(bad_sides), collapse = ", ")
      ))
    }
    for (n in val) {
      if (is.na(n) || n < 0 || n != as.integer(n)) {
        return(paste0(
          "region ",
          .sh_quote(region),
          " gaps must be non-negative integers"
        ))
      }
    }
  }
  NULL
}

# ---------------------------------------------------------------------
# stripe slot — NULL, a single fill colour, or a named c(odd, even)
# ---------------------------------------------------------------------

.stripe_shape_error <- function(st) {
  if (is.null(st)) {
    return(NULL)
  }
  if (!is.character(st) || anyNA(st) || !all(nzchar(st))) {
    return("must be NULL, a colour string, or a named c(odd, even)")
  }
  if (length(st) == 1L && is.null(names(st))) {
    return(NULL)
  }
  nms <- names(st)
  if (is.null(nms)) {
    return("a multi-element stripe must be named c(odd = , even = )")
  }
  bad <- setdiff(nms, c("odd", "even"))
  if (length(bad) > 0L) {
    return(paste0(
      "names must be 'odd' and / or 'even'; got ",
      paste(.sh_quote(bad), collapse = ", ")
    ))
  }
  NULL
}

# ---------------------------------------------------------------------
# fonts knob
# ---------------------------------------------------------------------

.preset_fonts_shape_error <- function(fn) {
  if (length(fn) == 0L) {
    return(NULL)
  }
  if (!is.list(fn)) {
    return(paste0("must be a named list; got ", class(fn)[[1]]))
  }
  nms <- names(fn)
  if (is.null(nms) || any(!nzchar(nms)) || anyNA(nms)) {
    return("entries must all be named")
  }
  unknown <- setdiff(nms, .preset_font_surfaces)
  if (length(unknown) > 0L) {
    return(paste0(
      "contains unknown surface(s): ",
      paste(.sh_quote(unknown), collapse = ", "),
      "; recognised: ",
      paste(.sh_quote(.preset_font_surfaces), collapse = ", ")
    ))
  }
  for (k in nms) {
    v <- fn[[k]]
    if (is.null(v)) {
      next
    }
    if (!is.list(v)) {
      return(paste0(
        "key ",
        .sh_quote(k),
        " must be a named list with any of family / size / weight"
      ))
    }
    spec_nms <- names(v)
    if (is.null(spec_nms) || anyNA(spec_nms) || any(!nzchar(spec_nms))) {
      return(paste0(
        "key ",
        .sh_quote(k),
        " entries must all be named"
      ))
    }
    unknown_keys <- setdiff(spec_nms, c("family", "size", "weight"))
    if (length(unknown_keys) > 0L) {
      return(paste0(
        "key ",
        .sh_quote(k),
        " has unknown sub-key(s): ",
        paste(.sh_quote(unknown_keys), collapse = ", "),
        "; recognised: 'family', 'size', 'weight'"
      ))
    }
    if (!is.null(v$family) && (!is.character(v$family) || anyNA(v$family))) {
      return(paste0(
        "key ",
        .sh_quote(k),
        " family must be a non-NA character"
      ))
    }
    if (
      !is.null(v$size) &&
        (!is.numeric(v$size) ||
          length(v$size) != 1L ||
          is.na(v$size) ||
          v$size <= 0)
    ) {
      return(paste0(
        "key ",
        .sh_quote(k),
        " size must be a single positive numeric"
      ))
    }
    if (
      !is.null(v$weight) &&
        (!is.character(v$weight) || length(v$weight) != 1L || is.na(v$weight))
    ) {
      return(paste0(
        "key ",
        .sh_quote(k),
        " weight must be a single character (e.g. 'normal' / 'bold')"
      ))
    }
  }
  NULL
}

# ---------------------------------------------------------------------
# colors knob
# ---------------------------------------------------------------------

.preset_colors_shape_error <- function(co) {
  if (length(co) == 0L) {
    return(NULL)
  }
  if (!is.list(co)) {
    return(paste0("must be a named list; got ", class(co)[[1]]))
  }
  nms <- names(co)
  if (is.null(nms) || any(!nzchar(nms)) || anyNA(nms)) {
    return("entries must all be named")
  }
  unknown <- setdiff(nms, .preset_color_surfaces)
  if (length(unknown) > 0L) {
    return(paste0(
      "contains unknown surface(s): ",
      paste(.sh_quote(unknown), collapse = ", "),
      "; recognised: ",
      paste(.sh_quote(.preset_color_surfaces), collapse = ", ")
    ))
  }
  for (k in nms) {
    v <- co[[k]]
    if (is.null(v)) {
      next
    }
    if (!is.list(v)) {
      return(paste0(
        "surface ",
        .sh_quote(k),
        " must be a named list with any of text / background"
      ))
    }
    sub_nms <- names(v)
    if (is.null(sub_nms) || anyNA(sub_nms) || any(!nzchar(sub_nms))) {
      return(paste0("surface ", .sh_quote(k), " entries must all be named"))
    }
    unknown_keys <- setdiff(sub_nms, .preset_color_tokens)
    if (length(unknown_keys) > 0L) {
      return(paste0(
        "surface ",
        .sh_quote(k),
        " has unknown token(s): ",
        paste(.sh_quote(unknown_keys), collapse = ", "),
        "; recognised: ",
        paste(.sh_quote(.preset_color_tokens), collapse = ", ")
      ))
    }
    for (tok in sub_nms) {
      tv <- v[[tok]]
      if (is.null(tv)) {
        next
      }
      if (!is.character(tv) || length(tv) != 1L || is.na(tv) || !nzchar(tv)) {
        return(paste0(
          "surface ",
          .sh_quote(k),
          " token ",
          .sh_quote(tok),
          " must be a single non-empty character (hex, CSS name, or 'currentColor' / 'transparent')"
        ))
      }
    }
  }
  NULL
}

# ---------------------------------------------------------------------
# padding knob
# ---------------------------------------------------------------------

.preset_padding_shape_error <- function(pa) {
  if (length(pa) == 0L) {
    return(NULL)
  }
  if (!is.list(pa)) {
    return(paste0("must be a named list; got ", class(pa)[[1]]))
  }
  nms <- names(pa)
  if (is.null(nms) || any(!nzchar(nms)) || anyNA(nms)) {
    return("entries must all be named")
  }
  unknown <- setdiff(nms, .preset_padding_surfaces)
  if (length(unknown) > 0L) {
    return(paste0(
      "contains unknown surface(s): ",
      paste(.sh_quote(unknown), collapse = ", "),
      "; recognised: ",
      paste(.sh_quote(.preset_padding_surfaces), collapse = ", ")
    ))
  }
  for (k in nms) {
    v <- pa[[k]]
    if (is.null(v)) {
      next
    }
    if (is.numeric(v) && length(v) == 1L && !is.na(v) && v >= 0) {
      next
    }
    if (is.list(v)) {
      spec_nms <- names(v)
      if (is.null(spec_nms) || anyNA(spec_nms) || any(!nzchar(spec_nms))) {
        return(paste0("key ", .sh_quote(k), " entries must all be named"))
      }
      unknown_keys <- setdiff(spec_nms, c("top", "right", "bottom", "left"))
      if (length(unknown_keys) > 0L) {
        return(paste0(
          "key ",
          .sh_quote(k),
          " has unknown side(s): ",
          paste(.sh_quote(unknown_keys), collapse = ", "),
          "; recognised: 'top', 'right', 'bottom', 'left'"
        ))
      }
      for (side in spec_nms) {
        sv <- v[[side]]
        if (
          !is.numeric(sv) ||
            length(sv) != 1L ||
            is.na(sv) ||
            sv < 0
        ) {
          return(paste0(
            "key ",
            .sh_quote(k),
            " side ",
            .sh_quote(side),
            " must be a single non-negative numeric"
          ))
        }
      }
      next
    }
    return(paste0(
      "key ",
      .sh_quote(k),
      " must be a non-negative numeric or a list of top/right/bottom/left"
    ))
  }
  NULL
}
