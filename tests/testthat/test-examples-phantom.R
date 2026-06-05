# test-examples-phantom.R — guard for issue #3: a roxygen @examples spec
# that leaks a raw HELPER column (a sort / partition / indent key) as a
# visible table header. Runs every R/ @examples block, renders any
# resulting tabular_spec, and asserts no helper column surfaces as a
# <th>. Runs against the package SOURCE (devtools::test); skipped under
# R CMD check where R/ source is not installed.

HELPER_COLS <- c(
  "n_total",
  "soc_n",
  "groupid",
  "group_label",
  "paramcd",
  "row_type",
  "soc",
  "indent_level",
  "display_order",
  "sex_n",
  "agegr_n"
)

# Extract @examples code (the `#' ` prefix stripped) from a roxygen file.
.extract_examples <- function(path) {
  lines <- readLines(path, warn = FALSE)
  starts <- grep("^#'\\s*@examples", lines)
  out <- character()
  for (st in starts) {
    i <- st + 1L
    while (i <= length(lines) && grepl("^#'", lines[[i]])) {
      if (grepl("^#'\\s*@[a-zA-Z]+", lines[[i]])) {
        break
      }
      out <- c(out, sub("^#'\\s?", "", lines[[i]]))
      i <- i + 1L
    }
  }
  out
}

.visible_headers <- function(spec) {
  f <- withr::local_tempfile(fileext = ".html")
  suppressWarnings(suppressMessages(emit(spec, f)))
  o <- paste(readLines(f, warn = FALSE), collapse = "\n")
  th <- regmatches(o, gregexpr("<th[^>]*>.*?</th>", o, perl = TRUE))[[1]]
  trimws(gsub("<[^>]+>", "", th))
}

test_that("no @examples renders a raw helper column as a header (#issue3)", {
  r_dir <- test_path("..", "..", "R")
  skip_if(!dir.exists(r_dir), "R/ source not present (installed pkg)")
  files <- list.files(r_dir, pattern = "\\.R$", full.names = TRUE)

  offenders <- character()
  for (f in files) {
    code <- .extract_examples(f)
    if (length(code) == 0L) {
      next
    }
    exprs <- tryCatch(
      parse(text = paste(code, collapse = "\n")),
      error = function(e) NULL
    )
    if (is.null(exprs)) {
      next
    }
    env <- new.env(parent = globalenv())
    for (e in exprs) {
      val <- tryCatch(
        suppressWarnings(suppressMessages(eval(e, env))),
        error = function(err) err
      )
      if (is_tabular_spec(val)) {
        hdrs <- tryCatch(.visible_headers(val), error = function(x) {
          character()
        })
        hit <- intersect(HELPER_COLS, hdrs)
        if (length(hit) > 0L) {
          offenders <- c(
            offenders,
            sprintf("%s: %s", basename(f), paste(hit, collapse = "/"))
          )
        }
      }
    }
  }
  expect_identical(
    offenders,
    character(),
    info = paste(
      "Phantom helper columns in examples:",
      paste(offenders, collapse = "; ")
    )
  )
})

test_that("no @examples auto-launches a browser non-interactively (#cran-detritus)", {
  # CRAN's Debian incoming check rejected 0.1.0 for browser temp-dir
  # detritus ("calibre-*"): the as.tags() example ended on
  # htmltools::browsable(...), whose autoprint calls html_print() ->
  # browseURL() even when !interactive(), leaving a browser temp dir.
  # This is the permanent, in-suite analog of that CRAN failure mode: eval
  # EVERY example exactly as R CMD check does (non-interactive, with
  # autoprint) under browser / viewer traps; any launch -- via browsable(),
  # print(spec, view = TRUE), or any other construct -- trips a trap and
  # names the offender. Not filtered to browsable()-bearing examples, so a
  # future leak through a different call is caught too.
  r_dir <- test_path("..", "..", "R")
  skip_if(!dir.exists(r_dir), "R/ source not present (installed pkg)")
  skip_if_not_installed("htmltools")

  # html_print() consults getOption("viewer") first, then browseURL().
  withr::local_options(
    browser = function(url) {
      stop("browser launched in non-interactive example")
    },
    viewer = function(url, ...) {
      stop("viewer launched in non-interactive example")
    }
  )

  offenders <- character()
  files <- list.files(r_dir, pattern = "\\.R$", full.names = TRUE)
  for (f in files) {
    code <- .extract_examples(f)
    if (length(code) == 0L) {
      next
    }
    exprs <- tryCatch(
      parse(text = paste(code, collapse = "\n")),
      error = function(e) NULL
    )
    if (is.null(exprs)) {
      next
    }
    env <- new.env(parent = globalenv())
    for (e in exprs) {
      msg <- tryCatch(
        {
          v <- withVisible(eval(e, env))
          if (v$visible) {
            print(v$value)
          }
          NULL
        },
        error = function(err) conditionMessage(err)
      )
      if (!is.null(msg) && grepl("launched in non-interactive", msg)) {
        offenders <- c(offenders, basename(f))
      }
    }
  }
  expect_identical(offenders, character())
})
