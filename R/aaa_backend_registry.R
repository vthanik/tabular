# aaa_backend_registry.R — package-internal backend registry.
#
# Lives in an `aaa_*` file so it loads before any `backend_*.R`
# file (R sources package files alphabetically). Each backend
# self-registers from the bottom of its R/backend_<fmt>.R file
# with `.register_backend(<fmt>, <writer_fn>)`. emit() looks the
# writer up via `.resolve_backend()`.
#
# Keys are canonical format strings ("md", "html", "latex", "pdf",
# "rtf", "docx") — never extensions. emit() maps file extensions
# to formats before consulting this registry.
#
# Tests register stub backends inside individual `test_that()`
# blocks and unregister via `withr::defer()` so registry state
# never leaks across test files.

# Package-internal environment that backend_*.R files mutate at
# load time. Empty until at least one backend has self-registered.
.tabular_backends <- new.env(parent = emptyenv())

# Register a backend writer. Replaces any existing entry for the
# same format. Errors are bare `stop()` (not cli_abort) because
# hitting them is a package-development bug, not a user error.
.register_backend <- function(format, fn) {
  if (!is.character(format) || length(format) != 1L || is.na(format)) {
    stop("`.register_backend()`: `format` must be a scalar character.")
  }
  if (!is.function(fn)) {
    stop("`.register_backend()`: `fn` must be a function.")
  }
  assign(format, fn, envir = .tabular_backends)
  invisible()
}

# Drop a backend registration. Used primarily by tests via
# `withr::defer()` to undo a registration inside a single test.
.unregister_backend <- function(format) {
  if (exists(format, envir = .tabular_backends, inherits = FALSE)) {
    rm(list = format, envir = .tabular_backends)
  }
  invisible()
}

# Test whether a backend is currently registered for `format`.
# Cheaper than calling `.resolve_backend()` solely to check
# existence.
.has_backend <- function(format) {
  exists(format, envir = .tabular_backends, inherits = FALSE)
}

# List the format strings of every currently registered backend,
# sorted alphabetically. Used in error messages so the user can see
# which backends are available.
.registered_backend_formats <- function() {
  sort(ls(.tabular_backends))
}

# Look up the backend writer for `format`; abort with
# `tabular_error_input` when none is registered (e.g. an extension
# whose backend has not yet shipped, or a typoed `format` override).
.resolve_backend <- function(format, call) {
  fn <- .tabular_backends[[format]]
  if (is.null(fn)) {
    registered <- .registered_backend_formats()
    msg <- c(
      "No backend registered for format {.val {format}}."
    )
    if (length(registered) > 0L) {
      msg <- c(
        msg,
        "i" = "Registered backends: {.val {registered}}."
      )
    } else {
      msg <- c(
        msg,
        "i" = "No backends are registered. This is a package-internal state."
      )
    }
    cli::cli_abort(msg, class = "tabular_error_input", call = call)
  }
  fn
}
