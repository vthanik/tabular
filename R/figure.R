# figure.R — entry verb for the "F" in TFL.
#
# figure() wraps a plot or image in the same canonical submission chrome
# (titles, footnotes, page header / footer) that tabular() gives a table,
# and returns a figure_spec (defined in aaa_class.R). The spec is resolved
# by .resolve_figure_to_grid() (figure.R, downstream) and written by each
# backend's figure path. A list input produces one figure per page.

#' Wrap a plot or image in submission chrome
#'
#' Builds a figure display, the "F" in TFL. `figure()` takes a ggplot, a
#' recorded base-R plot, a zero-argument drawing function, or a path to a
#' PNG / JPG file, and surrounds it with the same canonical submission
#' chrome as a table: up to four centred title lines, footnotes, and the
#' per-page header / footer drawn from the active [`preset()`]. Pass a
#' list to emit one figure per page in a single file.
#'
#' @details
#' **Two-axis placement.** The drawn image is usually smaller than the
#' body content box (the default `height` is 70% of the printable
#' height), so both `halign` and `valign` are load-bearing on the paged
#' backends. They place the image in the content box independently —
#' horizontally (`left` / `center` / `right`) and vertically
#' (`top` / `middle` / `bottom`), defaulting to centred on both axes.
#' Paged backends (RTF / PDF / DOCX) honour `valign` exactly against the
#' content-box height. The continuous backends (HTML / Markdown) render the
#' figure responsively, contained to the viewport, so `halign` still
#' applies but `valign` is a no-op there.
#'
#' **Format-aware rasterisation.** Plot inputs render to vector PDF for
#' `.pdf` / `.tex` targets and to PNG at `dpi` for every other backend;
#' file inputs pass through byte-for-byte. No raster work happens until
#' [`emit()`].
#'
#' @param plot *The figure to display.* One of: a `ggplot` object; a
#'   recorded base plot from [`grDevices::recordPlot()`]; a
#'   zero-argument function that draws to the active device when called;
#'   a length-1 path to a `.png`, `.jpg`, or `.jpeg` file; or a `list`
#'   of any of these for a multi-page figure.
#'
#'   **Tip:** a list may mix kinds freely — a ggplot, a recorded plot,
#'   and a PNG path can share one multi-page figure.
#'
#' @param titles *Title lines above the figure.* `<character> | NULL`.
#'   One element per line, up to four; same `{glue}` interpolation and
#'   [`md()`] / [`html()`] inline formatting as [`tabular()`]. `NULL`
#'   draws no titles.
#'
#' @param footnotes *Footnote lines below the figure.* `<character> |
#'   NULL`. One element per line; same interpolation and inline
#'   formatting as `titles`. `NULL` draws no footnotes.
#'
#' @param width *Drawn image width in inches.* `<numeric(1)> | NULL`.
#'   `NULL` fills the full printable width.
#'
#' @param height *Drawn image height in inches.* `<numeric(1)> | NULL`.
#'   `NULL` uses 70% of the printable height, leaving the image centred
#'   in the body region.
#'
#' @param halign *Horizontal placement in the content box.*
#'   `<character(1)>`. One of:
#'   - `"left"`
#'   - `"center"` (default)
#'   - `"right"`
#'
#' @param valign *Vertical placement in the content box.*
#'   `<character(1)>`. One of:
#'   - `"top"`
#'   - `"middle"` (default)
#'   - `"bottom"`
#'
#'   **Note:** continuous backends (HTML / Markdown) render the figure
#'   contained to the viewport with no fixed page height, so `valign` is a
#'   no-op there; the paged backends honour it exactly.
#'
#' @param dpi *Raster resolution for plot inputs.* `<numeric(1)>`.
#'   Resolution in dots per inch for PNG rasterisation. Ignored for file
#'   inputs (passed through unchanged) and for vector PDF targets.
#'
#' @param meta *Per-page token data frame.* `<data.frame> | NULL`.
#'   Multi-page only: one row per plot, whose columns become `{token}`
#'   values in that page's `titles` / `footnotes`. Ignored (with a
#'   warning) for a single-plot figure.
#'
#' @return *A `figure_spec`.* Pass it to [`emit()`] to write a file, or
#'   print it to preview the figure inline.
#'
#' @examples
#' # ---- Example 1: a single base-R figure with submission chrome ----
#' #
#' # A zero-argument drawing function is the simplest portable input: it
#' # draws to whatever device the backend opens. Here, subjects enrolled
#' # per treatment arm from the bundled BigN frame, wrapped in the
#' # canonical title block and a population footnote.
#' arms <- cdisc_saf_n[cdisc_saf_n$arm_short != "Total", ]
#'
#' draw_enrollment <- function() {
#'   barplot(
#'     arms$n,
#'     names.arg = arms$arm_short,
#'     ylab = "Subjects enrolled",
#'     col = "grey70"
#'   )
#' }
#'
#' fig <- figure(
#'   draw_enrollment,
#'   titles = c(
#'     "Figure 14.1.1",
#'     "Subjects Enrolled by Treatment Arm",
#'     "Safety Population"
#'   ),
#'   footnotes = "Total enrolled: N = 254."
#' )
#' fig
#'
#' # ---- Example 2: one figure per page from a list ----
#' #
#' # A list input emits one figure per page in a single file. Each arm
#' # gets its own page; the kinds may mix (a ggplot, a recorded plot, or
#' # a PNG path could share the list). Bottom-anchored here to show the
#' # two-axis placement.
#' draw_arm <- function(i) {
#'   force(i)
#'   function() {
#'     barplot(arms$n[i], names.arg = arms$arm_short[i], col = "grey70")
#'   }
#' }
#'
#' per_arm <- figure(
#'   lapply(seq_len(nrow(arms)), draw_arm),
#'   titles = c("Figure 14.1.2", "Enrollment by Arm, One Page per Arm"),
#'   valign = "bottom"
#' )
#' per_arm
#'
#' @seealso
#' **Terminal verb:** [`emit()`] (write the figure to a file).
#'
#' **Shared chrome:** [`preset()`] / [`set_preset()`] (page geometry,
#' fonts, header / footer), [`tabular()`] (the table sibling).
#'
#' **Class predicate:** [`is_figure_spec()`].
#'
#' @export
figure <- function(
  plot,
  titles = NULL,
  footnotes = NULL,
  width = NULL,
  height = NULL,
  halign = "center",
  valign = "middle",
  dpi = 300,
  meta = NULL
) {
  call <- rlang::caller_env()

  classified <- .figure_classify(plot, call = call)

  .check_figure_dim(width, "width", call = call)
  .check_figure_dim(height, "height", call = call)
  .check_figure_dpi(dpi, call = call)
  .check_figure_anchor(halign, "halign", .align_anchor_values, call = call)
  .check_figure_anchor(valign, "valign", .valign_values, call = call)
  meta_val <- .check_figure_meta(meta, classified, call = call)

  titles_val <- .normalise_text_block(titles, arg = "titles", call = call)
  footnotes_val <- .normalise_text_block(
    footnotes,
    arg = "footnotes",
    call = call
  )
  # Single figure (no per-page meta): interpolate {glue} tokens now against
  # the caller, exactly like tabular(). A multi-page figure with `meta`
  # defers interpolation to resolve time so each page can inject its own
  # meta-row tokens.
  if (is.null(meta_val)) {
    titles_val <- .interpolate_vec(titles_val, env = call, call = call)
    footnotes_val <- .interpolate_vec(footnotes_val, env = call, call = call)
  }

  figure_spec(
    source = plot,
    source_kind = classified$source_kind,
    plots = classified$plots,
    figure_meta = meta_val,
    titles = titles_val,
    footnotes = footnotes_val,
    width = width,
    height = height,
    halign = halign,
    valign = valign,
    dpi = dpi
  )
}

# ---------------------------------------------------------------------
# Classification — input -> (source_kind, normalised per-page list)
# ---------------------------------------------------------------------

# A bare list (one that is not itself a ggplot, which is also a list) is
# a multi-page figure; every element must be a supported single input.
.figure_classify <- function(plot, call) {
  if (.is_plot_list(plot)) {
    if (length(plot) == 0L) {
      cli::cli_abort(
        c(
          "{.arg plot} list must hold at least one figure.",
          "i" = "Pass one plot or image, or a non-empty list."
        ),
        class = "tabular_error_input",
        call = call
      )
    }
    for (i in seq_along(plot)) {
      if (is.na(.figure_single_kind(plot[[i]]))) {
        el <- plot[[i]]
        cli::cli_abort(
          c(
            "Element {i} of {.arg plot} is not a supported figure input.",
            "x" = "You supplied {.obj_type_friendly {el}}.",
            "i" = "Use a ggplot, a recorded base plot, a zero-arg function, or a .png / .jpg path."
          ),
          class = "tabular_error_input",
          call = call
        )
      }
    }
    return(list(source_kind = "multi", plots = as.list(plot)))
  }

  kind <- .figure_single_kind(plot)
  if (is.na(kind)) {
    cli::cli_abort(
      c(
        "{.arg plot} is not a supported figure input.",
        "x" = "You supplied {.obj_type_friendly {plot}}.",
        "i" = "Use a ggplot, a recorded base plot, a zero-arg function, or a .png / .jpg path."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  list(source_kind = kind, plots = list(plot))
}

# TRUE for a multi-page list: a plain list that is not a single input
# kind (ggplot and recordedplot are themselves lists, so exclude them).
.is_plot_list <- function(x) {
  is.list(x) &&
    !.is_ggplot(x) &&
    !inherits(x, "recordedplot")
}

# The single-input kind, or NA_character_ if unsupported. "multi" is
# never returned here (handled by .figure_classify).
.figure_single_kind <- function(x) {
  if (.is_ggplot(x)) {
    return("ggplot")
  }
  if (inherits(x, "recordedplot")) {
    return("recordedplot")
  }
  if (is.function(x)) {
    return("function")
  }
  if (.is_image_path(x)) {
    return("file")
  }
  NA_character_
}

.is_ggplot <- function(x) inherits(x, "ggplot") || inherits(x, "gg")

# A length-1, existing path with a raster image extension.
.is_image_path <- function(x) {
  is.character(x) &&
    length(x) == 1L &&
    !is.na(x) &&
    grepl("\\.(png|jpe?g)$", x, ignore.case = TRUE) &&
    file.exists(x)
}

# ---------------------------------------------------------------------
# Argument validators
# ---------------------------------------------------------------------

# width / height: NULL, or a single positive number of inches.
.check_figure_dim <- function(x, arg, call) {
  if (is.null(x)) {
    return(invisible())
  }
  if (!is.numeric(x) || length(x) != 1L || anyNA(x) || x <= 0) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must be NULL or a single positive number of inches.",
        "x" = "You supplied {.obj_type_friendly {x}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  invisible()
}

.check_figure_dpi <- function(x, call) {
  if (!is.numeric(x) || length(x) != 1L || anyNA(x) || x <= 0) {
    cli::cli_abort(
      c(
        "{.arg dpi} must be a single positive number.",
        "x" = "You supplied {.obj_type_friendly {x}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  invisible()
}

.check_figure_anchor <- function(x, arg, allowed, call) {
  if (!is.character(x) || length(x) != 1L || anyNA(x) || !(x %in% allowed)) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must be one of {.or {.val {allowed}}}.",
        "x" = "You supplied {.obj_type_friendly {x}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  invisible()
}

# meta: NULL, or a data frame with one row per plot (multi-page only).
# A single-plot figure ignores meta with a warning.
.check_figure_meta <- function(meta, classified, call) {
  if (is.null(meta)) {
    return(NULL)
  }
  if (!is.data.frame(meta)) {
    cli::cli_abort(
      c(
        "{.arg meta} must be a data frame or NULL.",
        "x" = "You supplied {.obj_type_friendly {meta}}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  if (!identical(classified$source_kind, "multi")) {
    cli::cli_warn(
      c(
        "{.arg meta} is ignored for a single-plot figure.",
        "i" = "Pass a list of plots to drive per-page tokens."
      ),
      call = call
    )
    return(NULL)
  }
  n_plots <- length(classified$plots)
  if (nrow(meta) != n_plots) {
    cli::cli_abort(
      c(
        "{.arg meta} must have one row per plot.",
        "x" = "{.arg plot} has {n_plots} element{?s}, {.arg meta} has {nrow(meta)} row{?s}."
      ),
      class = "tabular_error_input",
      call = call
    )
  }
  meta
}

# ---------------------------------------------------------------------
# Resolve — figure_spec -> tabular_grid (metadata$content_type "figure")
# ---------------------------------------------------------------------

# Compose a figure_spec into a tabular_grid: one page per plot, each
# carrying its rasterised image bytes, the drawn size in inches, and the
# shared chrome ASTs (titles / footnotes / page bands) every backend's
# chrome emitter already consumes. metadata$content_type = "figure" tells
# each backend to take its figure path instead of the table body loop.
.resolve_figure_to_grid <- function(spec, format, call) {
  eff_preset <- .effective_preset(spec)
  geom <- .figure_box(spec)

  # The image lives in the body content box; .place_block turns the two
  # anchors into the backend-neutral placement descriptor shared with the
  # empty-state message.
  place <- .place_block(
    spec@halign,
    spec@valign,
    list(
      width_in = geom$box_w_in,
      height_in = geom$box_h_in,
      width_twips = geom$printable_w_twips,
      height_twips = geom$box_h_twips
    )
  )

  pagehead_ast <- .resolve_page_band(
    eff_preset@pagehead,
    arg = "pagehead",
    call = call
  )
  pagefoot_ast <- .resolve_page_band(
    eff_preset@pagefoot,
    arg = "pagefoot",
    call = call
  )

  # Chrome ASTs. Without `meta` the titles / footnotes were already
  # interpolated at construction, so they parse once and ride every page.
  # With `meta`, figure() left them raw so each page can inject its own
  # meta-row {tokens} here (galley's figure_page_token_map).
  meta_df <- spec@figure_meta
  has_meta <- is.data.frame(meta_df)
  base_titles_ast <- .parse_string_vec(spec@titles, call = call)
  base_footnotes_ast <- .parse_string_vec(spec@footnotes, call = call)

  plots <- spec@plots
  n_pages <- length(plots)

  pages <- lapply(seq_len(n_pages), function(i) {
    img <- .resolve_figure_page(
      plot = plots[[i]],
      format = format,
      geom = geom,
      w_user = spec@width,
      h_user = spec@height,
      dpi = spec@dpi,
      call = call
    )
    page_ast <- if (has_meta) {
      .figure_page_chrome_ast(
        spec@titles,
        spec@footnotes,
        meta_df[i, , drop = FALSE],
        call = call
      )
    } else {
      list(titles_ast = base_titles_ast, footnotes_ast = base_footnotes_ast)
    }
    list(
      page_index = i,
      panel_index = 1L,
      is_continuation = i > 1L,
      is_figure_page = TRUE,
      image_bytes = img$bytes,
      image_ext = img$ext,
      draw_w_in = img$draw_w_in,
      draw_h_in = img$draw_h_in,
      titles_ast = page_ast$titles_ast,
      footnotes_ast = page_ast$footnotes_ast,
      place = place
    )
  })

  # Document-level chrome ASTs: page 1's resolved titles / footnotes (the
  # backends read the per-page copies; this is the fallback for inspection).
  meta_titles_ast <- pages[[1L]]$titles_ast
  meta_footnotes_ast <- pages[[1L]]$footnotes_ast

  tabular_grid(
    pages = pages,
    metadata = list(
      format = format,
      content_type = "figure",
      total_pages = n_pages,
      total_panels = 1L,
      # Chrome is identical across pages unless `meta` drove per-page
      # interpolation. On a continuous backend (HTML / Markdown) shared
      # chrome renders once, like a table; per-page chrome stays per page.
      shared_chrome = !has_meta,
      titles = spec@titles,
      footnotes = spec@footnotes,
      titles_ast = meta_titles_ast,
      footnotes_ast = meta_footnotes_ast,
      pagehead_ast = pagehead_ast,
      pagefoot_ast = pagefoot_ast,
      preset = eff_preset,
      place = place,
      box = geom,
      spacing = resolve_spacing(eff_preset@spacing),
      gaps = gap_counts(eff_preset@spacing)
    )
  )
}

# Interpolate one multi-page figure's raw titles / footnotes against a
# single meta row, then parse to inline ASTs. The row's columns become
# {token} values via an environment whose parent is baseenv() (so base
# functions resolve inside an expression but no caller-scope variable
# leaks in). Mirrors galley's per-page token map.
.figure_page_chrome_ast <- function(titles, footnotes, meta_row, call) {
  row_env <- list2env(as.list(meta_row), parent = baseenv())
  list(
    titles_ast = .parse_string_vec(
      .interpolate_vec(titles, env = row_env, call = call),
      call = call
    ),
    footnotes_ast = .parse_string_vec(
      .interpolate_vec(footnotes, env = row_env, call = call),
      call = call
    )
  )
}

# Page geometry for a figure: printable area plus the body content box
# (printable height minus the title / footnote chrome rows; a figure has
# NO column-header band, the one structural difference from .content_box).
# Twips with inch mirrors for device sizing.
.figure_box <- function(spec) {
  preset <- .effective_preset(spec)
  dims <- .paper_dims_twips(preset@paper_size, preset@orientation)
  mtb <- .margin_top_bottom_twips(preset@margins)
  mlr <- .margin_left_right_twips(preset@margins)
  one_row <- .row_height_twips(preset@font_size)

  n_title <- .count_lines(spec@titles)
  n_foot <- .count_lines(spec@footnotes)
  title_spacing <- if (n_title > 0L) 1L else 0L
  foot_spacing <- if (n_foot > 0L) 1L else 0L
  chrome_rows <- n_title + title_spacing + n_foot + foot_spacing

  printable_w <- dims[["width"]] - (mlr[["left"]] + mlr[["right"]])
  printable_h <- dims[["height"]] - (mtb[["top"]] + mtb[["bottom"]])
  box_h <- printable_h - chrome_rows * one_row

  list(
    printable_w_twips = printable_w,
    printable_h_twips = printable_h,
    box_h_twips = box_h,
    printable_w_in = printable_w / 1440,
    printable_h_in = printable_h / 1440,
    box_w_in = printable_w / 1440,
    box_h_in = box_h / 1440
  )
}

# Rasterise one plot and resolve its drawn size in inches. Plot inputs
# render at the resolved (w, h) directly; file inputs pass through and we
# derive any unset dimension from the intrinsic aspect ratio.
.resolve_figure_page <- function(
  plot,
  format,
  geom,
  w_user,
  h_user,
  dpi,
  call
) {
  kind <- .figure_single_kind(plot)
  if (identical(kind, "file")) {
    img <- .figure_rasterise(
      plot,
      format = format,
      width_in = NA,
      height_in = NA,
      dpi = dpi,
      call = call
    )
    dims <- .image_dims(img$bytes, img$ext)
    draw <- .figure_file_draw_size(w_user, h_user, dims, geom)
    return(list(
      bytes = img$bytes,
      ext = img$ext,
      draw_w_in = draw[["w"]],
      draw_h_in = draw[["h"]]
    ))
  }

  draw_w <- w_user %||% geom$printable_w_in
  draw_h <- h_user %||% (0.7 * geom$box_h_in)
  img <- .figure_rasterise(
    plot,
    format = format,
    width_in = draw_w,
    height_in = draw_h,
    dpi = dpi,
    call = call
  )
  list(
    bytes = img$bytes,
    ext = img$ext,
    draw_w_in = draw_w,
    draw_h_in = draw_h
  )
}

# Drawn size (inches) for a file input, preserving its intrinsic aspect
# ratio. Both NULL: largest fit within (printable_w, box_h). One set:
# derive the other from aspect. Both set: honour as given. Unparseable
# header: fall back to a box fit.
.figure_file_draw_size <- function(w_user, h_user, dims, geom) {
  iw <- dims[["width"]]
  ih <- dims[["height"]]
  aspect <- if (anyNA(c(iw, ih)) || ih == 0) NA_real_ else iw / ih

  if (!is.null(w_user) && !is.null(h_user)) {
    return(c(w = w_user, h = h_user))
  }
  if (is.na(aspect)) {
    return(c(
      w = w_user %||% geom$printable_w_in,
      h = h_user %||% geom$box_h_in
    ))
  }
  if (!is.null(w_user)) {
    return(c(w = w_user, h = w_user / aspect))
  }
  if (!is.null(h_user)) {
    return(c(w = h_user * aspect, h = h_user))
  }
  w <- geom$printable_w_in
  h <- w / aspect
  if (h > geom$box_h_in) {
    h <- geom$box_h_in
    w <- h * aspect
  }
  c(w = w, h = h)
}

# Inform the user about figure-image sidecars written next to a text-based
# output (`.tex` / `.md`), but ONLY for a real emit. The internal PDF
# compile and tempfile()-based tests write into tempdir(), where the
# sidecars are transient and the message would be noise. Shared by the
# LaTeX and Markdown backends.
.figure_inform_sidecars <- function(out_dir, sidecars, label) {
  if (length(sidecars) == 0L) {
    return(invisible())
  }
  tdir <- tryCatch(
    normalizePath(tempdir(), mustWork = FALSE),
    error = function(e) ""
  )
  here <- tryCatch(
    normalizePath(out_dir, mustWork = FALSE),
    error = function(e) out_dir
  )
  if (nzchar(tdir) && startsWith(here, tdir)) {
    return(invisible())
  }
  cli::cli_inform(c(
    "i" = "Wrote {length(sidecars)} figure image sidecar{?s} next to the {.path {label}} output.",
    stats::setNames(sidecars, rep("*", length(sidecars)))
  ))
}
