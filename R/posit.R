# posit.R — A tiny set of environment-detection helpers. The
# print router intentionally does NOT use `is_rstudio()` /
# `is_positron()` for dispatch — htmltools handles IDE viewer
# routing on its own. These predicates stay around for the one
# corner case htmltools doesn't cover (Databricks `displayHTML`)
# and so we can expose a `is_*()` family from `tabular:::`
# without making downstream tooling guess at env vars.

# TRUE when the current R session was launched by RStudio
# Desktop / Server. RStudio sets `RSTUDIO=1` in the spawned
# environment.
.is_rstudio <- function() {
  identical(Sys.getenv("RSTUDIO"), "1")
}

# TRUE when the current R session was launched by Positron.
# Positron sets `POSITRON=1` analogously.
.is_positron <- function() {
  identical(Sys.getenv("POSITRON"), "1")
}

# TRUE when running inside a Databricks notebook runtime.
# Databricks sets `DATABRICKS_RUNTIME_VERSION` to the runtime
# version string ("14.3.x-scala2.12", etc.). The print router
# branches on this and calls Databricks' `displayHTML()` because
# the notebook runtime registers no `viewer` option and
# htmltools would otherwise just `cat()` raw HTML.
.is_databricks <- function() {
  nzchar(Sys.getenv("DATABRICKS_RUNTIME_VERSION"))
}

# TRUE when running inside a pkgdown site build (reference examples
# or articles). pkgdown sets `IN_PKGDOWN=true` for the build's
# duration via `withr::local_envvar` (see `pkgdown:::in_pkgdown` /
# `pkgdown:::local_envvar_pkgdown`). The print router branches on this
# to return a browsable tag list so pkgdown's autoprint handler embeds
# a live HTML table instead of `cat()`-ing the raw document as text.
.is_in_pkgdown <- function() {
  identical(Sys.getenv("IN_PKGDOWN"), "true")
}
