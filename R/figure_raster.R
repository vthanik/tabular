# figure_raster.R — format-aware rasterisation and pure-R image helpers
# for figures. Zero new dependencies: plots render through base grDevices
# (and ggplot2 from Suggests only when a ggplot is passed); image headers
# are parsed and base64-encoded with base bit-arithmetic.

# Rasterise one plot for a target backend format.
#
# Returns list(bytes = <raw>, ext = "pdf" | "png" | "jpeg"). Plot inputs
# render to vector PDF for the LaTeX/PDF backends and to PNG at `dpi`
# everywhere else; file inputs pass through byte-for-byte (their own ext).
.figure_rasterise <- function(
  plot,
  format,
  width_in,
  height_in,
  dpi,
  index = 1L,
  call = rlang::caller_env()
) {
  kind <- .figure_single_kind(plot)

  # File input: pass the bytes through unchanged, keep the real ext.
  if (identical(kind, "file")) {
    bytes <- readBin(plot, "raw", n = file.info(plot)$size)
    ext <- if (grepl("\\.png$", plot, ignore.case = TRUE)) "png" else "jpeg"
    return(list(bytes = bytes, ext = ext))
  }

  # Plot input: vector PDF for LaTeX-family targets, PNG otherwise.
  vector_target <- format %in% c("pdf", "latex")
  ext <- if (vector_target) "pdf" else "png"
  tmp <- tempfile(fileext = paste0(".", ext))
  on.exit(unlink(tmp), add = TRUE)

  .figure_draw_to_device(
    plot = plot,
    kind = kind,
    path = tmp,
    width_in = width_in,
    height_in = height_in,
    dpi = dpi,
    vector_target = vector_target,
    index = index,
    call = call
  )

  bytes <- readBin(tmp, "raw", n = file.info(tmp)$size)
  list(bytes = bytes, ext = ext)
}

# Open a device sized to width_in x height_in inches, draw the plot, close.
# `index` names the page for the failed-render error (F5). The actual draw
# ops are wrapped so a throwing ggplot / recorded plot / drawing function
# aborts with a clear `tabular_error_input` naming the page, not a cryptic
# device-level error. The ggplot2 install check stays OUTSIDE the guard so
# its own "please install" message is preserved.
.figure_draw_to_device <- function(
  plot,
  kind,
  path,
  width_in,
  height_in,
  dpi,
  vector_target,
  index,
  call
) {
  if (identical(kind, "ggplot")) {
    rlang::check_installed(
      "ggplot2",
      reason = "to render ggplot figures.",
      call = call
    )
    args <- list(
      filename = path,
      plot = plot,
      width = width_in,
      height = height_in,
      units = "in",
      device = if (vector_target) "pdf" else "png"
    )
    if (!vector_target) {
      args$dpi <- dpi
    }
    .figure_try_draw(function() do.call(ggplot2::ggsave, args), index, call)
    return(invisible(path))
  }

  if (vector_target) {
    grDevices::pdf(path, width = width_in, height = height_in)
  } else {
    grDevices::png(
      path,
      width = width_in,
      height = height_in,
      units = "in",
      res = dpi
    )
  }
  on.exit(grDevices::dev.off(), add = TRUE)

  if (identical(kind, "recordedplot")) {
    .figure_try_draw(function() grDevices::replayPlot(plot), index, call)
  } else {
    # Zero-arg drawing function: `plot` is the user's closure, not base
    # plot(); calling it draws to the open device.
    .figure_try_draw(function() plot(), index, call)
  }
  invisible(path)
}

# Run one figure draw, converting any error into a typed, page-named abort.
.figure_try_draw <- function(draw, index, call) {
  tryCatch(
    draw(),
    error = function(e) {
      cli::cli_abort(
        c(
          "Failed to render figure plot {index}.",
          "x" = "The plot raised an error while drawing: {conditionMessage(e)}",
          "i" = "Check the plot object or zero-argument drawing function for errors."
        ),
        class = "tabular_error_input",
        call = call,
        parent = e
      )
    }
  )
}

# ---------------------------------------------------------------------
# Base64 — pure R, vectorised, byte-exact with RFC 4648 (+ / and =)
# ---------------------------------------------------------------------

.base64_encode_raw <- function(raw_bytes) {
  alphabet <- c(LETTERS, letters, as.character(0:9), "+", "/")
  n <- length(raw_bytes)
  if (n == 0L) {
    return("")
  }

  ints <- as.integer(raw_bytes)
  pad <- (3L - n %% 3L) %% 3L
  if (pad > 0L) {
    ints <- c(ints, rep(0L, pad))
  }

  # Three input bytes -> four 6-bit indices, all groups at once.
  m <- matrix(ints, nrow = 3L)
  a <- m[1L, ]
  b <- m[2L, ]
  cc <- m[3L, ]

  i1 <- bitwShiftR(a, 2L)
  i2 <- bitwOr(bitwShiftL(bitwAnd(a, 3L), 4L), bitwShiftR(b, 4L))
  i3 <- bitwOr(bitwShiftL(bitwAnd(b, 15L), 2L), bitwShiftR(cc, 6L))
  i4 <- bitwAnd(cc, 63L)

  # rbind then as.vector reads column-major: i1[1],i2[1],i3[1],i4[1],...
  chars <- alphabet[as.vector(rbind(i1, i2, i3, i4)) + 1L]

  # The padded input bytes encoded to real characters; overwrite the
  # trailing 1-2 positions with '=' to mark the padding.
  if (pad >= 1L) {
    chars[length(chars)] <- "="
  }
  if (pad >= 2L) {
    chars[length(chars) - 1L] <- "="
  }
  paste0(chars, collapse = "")
}

# ---------------------------------------------------------------------
# Intrinsic image dimensions (pixels) from raw bytes, no dependency
# ---------------------------------------------------------------------

# Dispatch on the declared ext. Returns c(width, height) in pixels, or
# c(NA, NA) when the header cannot be parsed.
.image_dims <- function(bytes, ext) {
  if (identical(ext, "png")) {
    return(.png_dims(bytes))
  }
  if (ext %in% c("jpeg", "jpg")) {
    return(.jpeg_dims(bytes))
  }
  c(width = NA_real_, height = NA_real_)
}

# Big-endian unsigned integers from raw (doubles, to dodge int overflow).
.be_uint16 <- function(b) as.numeric(b[1L]) * 256 + as.numeric(b[2L])
.be_uint32 <- function(b) {
  as.numeric(b[1L]) *
    16777216 +
    as.numeric(b[2L]) * 65536 +
    as.numeric(b[3L]) * 256 +
    as.numeric(b[4L])
}

# PNG: 8-byte signature, 4-byte length, "IHDR", width(4) height(4) BE.
# Width is bytes 17-20, height 21-24 (1-indexed).
.png_dims <- function(bytes) {
  if (length(bytes) < 24L) {
    return(c(width = NA_real_, height = NA_real_))
  }
  c(
    width = .be_uint32(bytes[17:20]),
    height = .be_uint32(bytes[21:24])
  )
}

# JPEG: scan segment markers from after SOI to the first SOF; SOF holds
# precision(1), height(2), width(2) BE after the 2-byte segment length.
.jpeg_dims <- function(bytes) {
  n <- length(bytes)
  na <- c(width = NA_real_, height = NA_real_)
  if (n < 4L) {
    return(na)
  }
  ff <- as.raw(0xFF)
  # Standalone markers (no length field): SOI, EOI, RSTn, TEM.
  standalone <- c(
    0xD8,
    0xD9,
    0xD0,
    0xD1,
    0xD2,
    0xD3,
    0xD4,
    0xD5,
    0xD6,
    0xD7,
    0x01
  )
  i <- 3L # past the SOI marker (FF D8)
  while (i < n) {
    if (bytes[i] != ff) {
      i <- i + 1L
      next
    }
    marker <- as.integer(bytes[i + 1L])
    if (marker %in% standalone) {
      i <- i + 2L
      next
    }
    # SOF0..SOF15 carry the frame size; skip DHT(C4), JPG(C8), DAC(CC).
    if (
      marker >= 0xC0 &&
        marker <= 0xCF &&
        !(marker %in% c(0xC4, 0xC8, 0xCC))
    ) {
      if (i + 8L > n) {
        return(na)
      }
      return(c(
        width = .be_uint16(bytes[(i + 7L):(i + 8L)]),
        height = .be_uint16(bytes[(i + 5L):(i + 6L)])
      ))
    }
    seg_len <- .be_uint16(bytes[(i + 2L):(i + 3L)])
    i <- i + 2L + seg_len
  }
  na
}
