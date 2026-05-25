# preset_validators.R — shape validators for the named-list knobs
# on `preset_spec` (borders / fonts / colors / padding). Mirrors the
# `.preset_alignment_shape_error` pattern in `R/align.R`: each helper
# returns NULL when well-formed, otherwise an error-message string
# suitable for the S7 validator (caller prepends "@<knob> ").

# ---------------------------------------------------------------------
# preset@borders
# ---------------------------------------------------------------------

.preset_borders_shape_error <- function(br) {
  if (length(br) == 0L) {
    return(NULL)
  }
  if (!is.list(br)) {
    return(paste0("must be a named list; got ", class(br)[[1]]))
  }
  nms <- names(br)
  if (is.null(nms) || any(!nzchar(nms)) || anyNA(nms)) {
    return("entries must all be named")
  }
  unknown <- setdiff(nms, .preset_border_regions)
  if (length(unknown) > 0L) {
    return(paste0(
      "contains unknown region(s): ",
      paste(.sh_quote(unknown), collapse = ", "),
      "; recognised: ",
      paste(.sh_quote(.preset_border_regions), collapse = ", ")
    ))
  }
  for (k in nms) {
    v <- br[[k]]
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
      "key ",
      .sh_quote(k),
      " must be a brdr() value, \"none\", or NULL"
    ))
  }
  NULL
}

# ---------------------------------------------------------------------
# preset@fonts
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
# preset@colors
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
  unknown <- setdiff(nms, .preset_color_tokens)
  if (length(unknown) > 0L) {
    return(paste0(
      "contains unknown token(s): ",
      paste(.sh_quote(unknown), collapse = ", "),
      "; recognised: ",
      paste(.sh_quote(.preset_color_tokens), collapse = ", ")
    ))
  }
  for (k in nms) {
    v <- co[[k]]
    if (is.null(v)) {
      next
    }
    if (
      !is.character(v) ||
        length(v) != 1L ||
        is.na(v) ||
        !nzchar(v)
    ) {
      return(paste0(
        "key ",
        .sh_quote(k),
        " must be a single non-empty character (hex, CSS name, or 'currentColor' / 'transparent')"
      ))
    }
  }
  NULL
}

# ---------------------------------------------------------------------
# preset@padding
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
