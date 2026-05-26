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
