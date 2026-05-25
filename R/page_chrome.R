# page_chrome.R — machinery for preset@pagehead / @pagefoot, the
# per-page header / footer bands every paginated backend (RTF, LaTeX,
# PDF, HTML, DOCX) honours. Backed by the canonical submission Appendix I 4-section
# page layout contract, with the same three-slot (`left` / `center`
# / `right`) convention shared by galley, arframe, r2rtf, fancyhdr,
# and Word's UI.
#
# Two-phase token resolution:
#
#   {program}      -> static; engine phase. Base name of the calling
#                     script (e.g. `"t_demog.R"`).
#   {program_path} -> static; engine phase. Full normalised path
#                     (e.g. `"/proj/sap/programs/t_demog.R"`).
#   {datetime}     -> static; engine phase. `DDMMMYYYY HH:MM:SS`
#                     uppercase, UTC.
#   {page}         -> dynamic; backend phase. Each backend resolves
#                     to its native field code (Word / xelatex /
#                     browser fills the actual number at view time).
#   {npages}       -> dynamic; backend phase. Same.
#
# This file owns the engine-phase trio; backend files own the
# dynamic pair.
#
# Source-path resolution follows galley's 5-mode pattern (ported
# from `~/projects/r/_archive/2026-05-21/galley/R/tokens.R`):
# RStudio API -> source() frame walk -> Rscript / R CMD BATCH
# (`--file=` long form + `-f` short form, which covers Domino and
# Linux batch jobs) -> knitr current_input -> fallback. This
# matches the canonical submission Appendix I "Program Path / Program Name" two-
# line convention.
#
# Multi-row contract — index 1 = "body edge", index N = "far from
# body". The user always writes in increasing-distance-from-body
# order; backends invert the emission order for `pagehead` (rows
# grow upward) and keep it forward for `pagefoot` (rows grow
# downward). See backend_rtf / backend_latex / backend_html for the
# per-backend rendering.

# Slot vocabulary — the only legal slot names on a page band.
.page_band_slots <- c("left", "center", "right")

# Engine-phase tokens — substituted inside character strings BEFORE
# parse_inline runs. Stays out of inline_ast inputs (those are
# already parsed).
.page_band_engine_tokens <- c("program", "program_path", "datetime")

# ---------------------------------------------------------------------
# Shape validation
# ---------------------------------------------------------------------

# Return NULL when `x` is a valid page-band shape, otherwise a
# character scalar describing the first problem. Suitable for use
# inside an S7 validator (which returns NULL or character).
#
# Valid shapes:
#   list()                                                empty band
#   list(left = NULL | chr | inline_ast, ...)              one or more slots
.page_band_shape_error <- function(x) {
  if (length(x) == 0L) {
    return(NULL)
  }
  if (!is.list(x)) {
    return("must be a list")
  }
  nms <- names(x)
  if (
    is.null(nms) ||
      any(!nzchar(nms)) ||
      anyNA(nms)
  ) {
    return(sprintf(
      "every slot must be named (recognised: %s)",
      paste(.page_band_slots, collapse = ", ")
    ))
  }
  unknown <- setdiff(nms, .page_band_slots)
  if (length(unknown) > 0L) {
    return(sprintf(
      "unknown slot(s): %s; recognised: %s",
      paste(unknown, collapse = ", "),
      paste(.page_band_slots, collapse = ", ")
    ))
  }
  for (slot in nms) {
    v <- x[[slot]]
    if (is.null(v) || is_inline_ast(v) || is.character(v)) {
      next
    }
    return(sprintf(
      "slot '%s' must be NULL, character, or an inline_ast",
      slot
    ))
  }
  NULL
}

# Friendly variant: validate `x` and abort with tabular_error_input
# on any problem. `arg` names the user-facing knob (`"pagehead"` or
# `"pagefoot"`) so the error message points at the right slot.
.check_page_band <- function(x, arg, call) {
  err <- .page_band_shape_error(x)
  if (is.null(err)) {
    return(invisible())
  }
  slots <- .page_band_slots
  cli::cli_abort(
    c(
      "Bad {.arg {arg}}.",
      "x" = err,
      "i" = "Pass a named list with slots from {.val {slots}}."
    ),
    class = "tabular_error_input",
    call = call
  )
}

# ---------------------------------------------------------------------
# Normalisation
# ---------------------------------------------------------------------

# Normalise a pagehead / pagefoot input to the canonical engine
# shape: NULL (no band) OR
# `list(left = list-of-N, center = list-of-N, right = list-of-N)`
# where each list entry is either a character scalar (will be
# parse_inline'd downstream) or an inline_ast (already parsed).
#
# Padding semantics — shorter slots pad with "" AT THE END (high
# index). Since index 1 = body edge, a scalar slot lands on the
# body-edge row and the far-from-body rows are blank for that slot.
.normalize_page_band <- function(
  x,
  arg = "band",
  call = rlang::caller_env()
) {
  .check_page_band(x, arg = arg, call = call)
  if (length(x) == 0L) {
    return(NULL)
  }

  slot_to_list <- function(v) {
    if (is.null(v)) {
      return(list())
    }
    if (is_inline_ast(v)) {
      return(list(v))
    }
    as.list(as.character(v))
  }

  left <- slot_to_list(x$left)
  center <- slot_to_list(x$center)
  right <- slot_to_list(x$right)

  n <- max(length(left), length(center), length(right))
  if (n == 0L) {
    return(NULL)
  }

  pad <- function(s) {
    if (length(s) >= n) {
      return(s[seq_len(n)])
    }
    c(s, as.list(rep("", n - length(s))))
  }

  list(
    left = pad(left),
    center = pad(center),
    right = pad(right)
  )
}

# ---------------------------------------------------------------------
# Engine-phase token resolution
# ---------------------------------------------------------------------

# Resolve the calling script's full path across every common R
# execution environment. Ported from galley's `get_source_path()`
# (`~/projects/r/_archive/2026-05-21/galley/R/tokens.R`); covers:
#
#   1. RStudio interactive editing (rstudioapi::getSourceEditorContext)
#   2. source("script.R") (sys.frame "ofile" variable)
#   3. Rscript / R CMD BATCH (commandArgs "--file=" + "-f" — handles
#      Domino, Linux batch jobs, CI runners)
#   4. knitr / rmarkdown / quarto (knitr::current_input)
#   5. Fallback: `"<interactive>"` so neither token is ever left
#      literal.
#
# Returns the full path (normalised where the source layer gave us
# enough). `.resolve_program_token` and `.resolve_program_path_token`
# wrap this for the `{program}` / `{program_path}` user surface.
.resolve_source_path <- function() {
  # 1. RStudio API — interactive in RStudio / Positron.
  rs_path <- tryCatch(
    {
      if (
        requireNamespace("rstudioapi", quietly = TRUE) &&
          rstudioapi::isAvailable()
      ) {
        ctx <- rstudioapi::getSourceEditorContext()
        if (!is.null(ctx$path) && nzchar(ctx$path)) ctx$path else NULL
      } else {
        NULL
      }
    },
    error = function(e) NULL
  )
  if (!is.null(rs_path)) {
    return(rs_path)
  }

  # 2. source("script.R") — walk frames for the `ofile` variable
  # that source() stashes; this catches scripts run via source()
  # from an interactive session.
  for (i in seq_len(sys.nframe())) {
    env <- sys.frame(i)
    if (exists("ofile", envir = env, inherits = FALSE)) {
      ofile <- get("ofile", envir = env, inherits = FALSE)
      if (is.character(ofile) && length(ofile) == 1L && nzchar(ofile)) {
        return(ofile)
      }
    }
  }

  # 3. Rscript / R CMD BATCH — Domino, CI, Linux batch jobs all
  # land here because they ultimately invoke `Rscript script.R`
  # (`--file=` long form) or `R -f script.R` (short form).
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", cmd_args, value = TRUE)
  if (length(file_arg) > 0L) {
    return(normalizePath(
      sub("^--file=", "", file_arg[[1L]]),
      mustWork = FALSE
    ))
  }
  f_index <- which(cmd_args == "-f")
  if (length(f_index) > 0L && f_index[[1L]] < length(cmd_args)) {
    return(normalizePath(cmd_args[[f_index[[1L]] + 1L]], mustWork = FALSE))
  }

  # 4. knitr / rmarkdown / quarto — `knitr::current_input()` returns
  # the .Rmd / .qmd path during a render.
  kn_path <- tryCatch(
    {
      if (requireNamespace("knitr", quietly = TRUE)) {
        input <- knitr::current_input()
        if (!is.null(input) && nzchar(input)) input else NULL
      } else {
        NULL
      }
    },
    error = function(e) NULL
  )
  if (!is.null(kn_path)) {
    return(kn_path)
  }

  # 5. Fallback — interactive REPL with no source layer to consult.
  NA_character_
}

# Resolve `{program}` -> base name of the calling script (just the
# file name, no path). The canonical submission "Program Name" footer line.
.resolve_program_token <- function() {
  path <- .resolve_source_path()
  if (is.na(path) || !nzchar(path)) {
    return("<interactive>")
  }
  basename(path)
}

# Resolve `{program_path}` -> full normalised path of the calling
# script. The canonical submission "Program Path" footer line.
.resolve_program_path_token <- function() {
  path <- .resolve_source_path()
  if (is.na(path) || !nzchar(path)) {
    return("<interactive>")
  }
  path
}

# Resolve `{datetime}` -> DDMMMYYYY HH:MM:SS (uppercase month) in
# UTC. Matches the canonical submission convention: `24MAY2026 09:33:55`.
.resolve_datetime_token <- function() {
  toupper(format(Sys.time(), "%d%b%Y %H:%M:%S", tz = "UTC"))
}

# Substitute `{program}`, `{program_path}`, and `{datetime}` inside
# one character string. Idempotent on strings that contain none of
# them. `{program_path}` is substituted BEFORE `{program}` so the
# longer prefix wins (otherwise `{program}` would chew the leading
# `{program}` substring of `{program_path}`).
.substitute_engine_tokens <- function(text, program, program_path, datetime) {
  if (!is.character(text) || length(text) != 1L || is.na(text)) {
    return(text)
  }
  text <- gsub("{program_path}", program_path, text, fixed = TRUE)
  text <- gsub("{program}", program, text, fixed = TRUE)
  text <- gsub("{datetime}", datetime, text, fixed = TRUE)
  text
}

# ---------------------------------------------------------------------
# End-to-end: normalise + resolve engine tokens + parse_inline
# ---------------------------------------------------------------------

# Apply the full engine-phase pipeline to a pagehead / pagefoot
# input. Returns NULL for an empty input, otherwise
# `list(left = list-of-N-asts, center = list-of-N-asts,
# right = list-of-N-asts)` where each ast is an `inline_ast`.
#
# Empty cells (the `""` padding) parse to an empty `inline_ast`
# (`inline_ast(runs = list())`), which backends use as the sentinel
# for "skip this cell".
#
# `program` / `datetime` overrides exist for testing — the public
# entry resolves them inline at every call (per-render fresh
# timestamp).
.resolve_page_band <- function(
  x,
  arg = "band",
  call = rlang::caller_env(),
  program = NULL,
  program_path = NULL,
  datetime = NULL
) {
  band <- .normalize_page_band(x, arg = arg, call = call)
  if (is.null(band)) {
    return(NULL)
  }

  if (is.null(program)) {
    program <- .resolve_program_token()
  }
  if (is.null(program_path)) {
    program_path <- .resolve_program_path_token()
  }
  if (is.null(datetime)) {
    datetime <- .resolve_datetime_token()
  }

  resolve_cell <- function(cell) {
    if (is_inline_ast(cell)) {
      return(cell)
    }
    text <- .substitute_engine_tokens(cell, program, program_path, datetime)
    parse_inline(text, call = call)
  }

  list(
    left = lapply(band$left, resolve_cell),
    center = lapply(band$center, resolve_cell),
    right = lapply(band$right, resolve_cell)
  )
}

# ---------------------------------------------------------------------
# Backend helpers
# ---------------------------------------------------------------------

# Return TRUE when the resolved page band (output of
# `.resolve_page_band()`) carries at least one non-empty cell.
# Backends use this to decide whether to emit the chrome scaffolding
# at all (RTF `{\header}` / `{\footer}` groups, LaTeX `\fancyhead`
# blocks, HTML `@page` rules).
.page_band_is_populated <- function(band) {
  if (is.null(band)) {
    return(FALSE)
  }
  any_pop <- function(slot) {
    for (cell in slot) {
      if (is_inline_ast(cell) && length(cell@runs) > 0L) {
        return(TRUE)
      }
    }
    FALSE
  }
  any_pop(band$left) || any_pop(band$center) || any_pop(band$right)
}

# Row count of a resolved page band. Returns 0L when the band is
# empty / NULL.
.page_band_nrow <- function(band) {
  if (is.null(band)) {
    return(0L)
  }
  length(band$left %||% list())
}

# Extract one row's three slots from a resolved band. Returns
# `list(left = ast, center = ast, right = ast)` where any cell can
# be an empty `inline_ast`. Backends iterate rows and decide whether
# to emit each cell based on `length(ast@runs)`.
.page_band_row <- function(band, i) {
  list(
    left = band$left[[i]],
    center = band$center[[i]],
    right = band$right[[i]]
  )
}
