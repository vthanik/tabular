# zzz.R — package load hook. Registers S3 methods on generics
# defined in Suggests-only packages (htmltools, knitr) so the
# methods dispatch correctly under `devtools::load_all()` AND
# after install. NAMESPACE's `S3method(pkg::generic, class)`
# directive covers the post-install case, but devtools' load
# path doesn't always reapply it for cross-package generics —
# registering here makes the dispatch deterministic in both
# environments.

.onLoad <- function(libname, pkgname) {
  # Activate S7 methods. `print` for a tabular_spec is an S7 method on
  # the base::print generic (R/print.R). Methods on a generic owned by
  # another package only register at install time when the defining
  # package calls this in its load hook; without it, `print(spec)`
  # falls back to S7's default struct dump after install (devtools'
  # load_all registers S7 methods itself, which masks the omission).
  S7::methods_register()

  # `S7::method(print, tabular_spec) <- ...` in R/print.R imports
  # `print` into tabular's namespace as a local binding. NAMESPACE's
  # `S3method(print, <class>)` then registers against that local
  # binding rather than `base::print`, so dispatch from user code
  # (which resolves `print` to `base::print`) misses the methods.
  # Re-register against `baseenv()` so `print(brdr(...))` etc. find
  # the per-class S3 method.
  for (cls in c(
    "tabular_brdr",
    "tabular_location",
    "tabular_style_template"
  )) {
    registerS3method(
      "print",
      cls,
      get(paste0("print.", cls), envir = asNamespace(pkgname)),
      envir = baseenv()
    )
  }
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
    registerS3method(
      "as.tags",
      "tabular::figure_spec",
      as.tags.figure_spec,
      envir = asNamespace("htmltools")
    )
    registerS3method(
      "as.tags",
      "figure_spec",
      as.tags.figure_spec,
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
    registerS3method(
      "knit_print",
      "tabular::figure_spec",
      knit_print.figure_spec,
      envir = asNamespace("knitr")
    )
    registerS3method(
      "knit_print",
      "figure_spec",
      knit_print.figure_spec,
      envir = asNamespace("knitr")
    )
  }
  invisible()
}
