# zzz.R — package load hook. Registers S3 methods on generics
# defined in Suggests-only packages (htmltools, knitr) so the
# methods dispatch correctly under `devtools::load_all()` AND
# after install. NAMESPACE's `S3method(pkg::generic, class)`
# directive covers the post-install case, but devtools' load
# path doesn't always reapply it for cross-package generics —
# registering here makes the dispatch deterministic in both
# environments.

.onLoad <- function(libname, pkgname) {
  # S7 stamps class strings with the namespace prefix
  # ("tabular::tabular_spec") so S3 dispatch on the bare name
  # ("tabular_spec") would miss. Register against both so
  # `htmltools::as.tags(spec)` and `knitr::knit_print(spec)`
  # route correctly whether the caller sees the bare class
  # (S7 internal coercion) or the namespaced one (S3 dispatch
  # via `inherits()`).
  if (requireNamespace("htmltools", quietly = TRUE)) {
    registerS3method(
      "as.tags",
      "tabular::tabular_spec",
      as.tags.tabular_spec,
      envir = asNamespace("htmltools")
    )
    registerS3method(
      "as.tags",
      "tabular_spec",
      as.tags.tabular_spec,
      envir = asNamespace("htmltools")
    )
  }
  if (requireNamespace("knitr", quietly = TRUE)) {
    registerS3method(
      "knit_print",
      "tabular::tabular_spec",
      knit_print.tabular_spec,
      envir = asNamespace("knitr")
    )
    registerS3method(
      "knit_print",
      "tabular_spec",
      knit_print.tabular_spec,
      envir = asNamespace("knitr")
    )
  }
  invisible()
}
