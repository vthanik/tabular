# zzz — package load hook. `.onLoad` registers S3 methods on
# generics from Suggests-only packages (htmltools, knitr) so they
# dispatch under both devtools::load_all() and post-install.
#
# `.onLoad` runs once at namespace load time, before the test harness
# is even running. To exercise it explicitly we call the internal
# function in the test process.

test_that(".onLoad registers htmltools as.tags + knitr knit_print S3 methods", {
  # Calling .onLoad here is idempotent — registerS3method overwrites
  # any prior registration. We just need the function body to execute
  # so coverage tooling sees it.
  expect_silent(tabular:::.onLoad(libname = NULL, pkgname = "tabular"))
})

test_that(".onLoad calls S7::methods_register so installed print(spec) dispatches (#print-s7)", {
  # `print` for a tabular_spec is an S7 method on the base::print
  # generic (R/print.R: `S7::method(print, tabular_spec) <- ...`).
  # Methods on an EXTERNAL generic only activate in an installed
  # package if `.onLoad` calls `S7::methods_register()`. Without it,
  # `print(spec)` falls back to S7's default struct dump after install.
  #
  # This cannot be reproduced behaviourally inside the test harness:
  # devtools::load_all() (and thus devtools::test()) registers S7
  # methods itself, so `print(spec)` renders correctly here regardless
  # of the bug. We therefore guard the load-time registration call
  # directly — it is the only in-process signal of the install-only
  # defect.
  onload_src <- paste(deparse(body(tabular:::.onLoad)), collapse = "\n")
  expect_match(onload_src, "methods_register", fixed = TRUE)
})

test_that("print(tabular_spec) renders the HTML preview, not the S7 fallback", {
  # Contract test for the user-facing preview. (Green under load_all
  # whether or not the install-only bug above is fixed; documents the
  # behaviour the fix protects when installed.)
  spec <- tabular(cdisc_saf_demo) |>
    cols(
      variable = col_spec(usage = "group"),
      stat_label = col_spec(label = "Statistic"),
      placebo = col_spec(align = "decimal"),
      drug_50 = col_spec(align = "decimal"),
      drug_100 = col_spec(align = "decimal"),
      Total = col_spec(align = "decimal")
    )
  out <- paste(capture.output(print(spec)), collapse = "\n")
  expect_no_match(out, "<tabular::tabular_spec>", fixed = TRUE)
  expect_match(out, "tabular-table")
})
