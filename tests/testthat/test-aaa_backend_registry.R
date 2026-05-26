# aaa_backend_registry — internal registry for backend writers.
# emit() resolves the writer for a given format via this registry.
# Tests register stub backends in isolated blocks and tear down with
# withr::defer() so the package-internal env never leaks across files.

test_that(".has_backend returns TRUE for live registrations and FALSE otherwise", {
  expect_true(tabular:::.has_backend("rtf"))
  expect_true(tabular:::.has_backend("html"))
  expect_false(tabular:::.has_backend("not_a_real_format_xyz"))
})

test_that(".registered_backend_formats returns the registered formats sorted", {
  formats <- tabular:::.registered_backend_formats()
  expect_type(formats, "character")
  expect_identical(formats, sort(formats))
  expect_true(all(
    c("docx", "html", "latex", "md", "pdf", "rtf") %in% formats
  ))
})

test_that(".register_backend rejects bad inputs", {
  expect_error(
    tabular:::.register_backend(c("a", "b"), function(...) NULL),
    "scalar character"
  )
  expect_error(
    tabular:::.register_backend("rtf", "not a function"),
    "must be a function"
  )
})

test_that(".unregister_backend drops then-removes silently", {
  tabular:::.register_backend("scratch_test", function(...) NULL)
  withr::defer(tabular:::.unregister_backend("scratch_test"))
  expect_true(tabular:::.has_backend("scratch_test"))
  tabular:::.unregister_backend("scratch_test")
  expect_false(tabular:::.has_backend("scratch_test"))
  # idempotent — second unregister is a no-op
  expect_silent(tabular:::.unregister_backend("scratch_test"))
})

test_that(".resolve_backend with NO registered backends emits the empty-registry hint", {
  # Snapshot every existing registration, clear them all, then
  # call .resolve_backend so the empty-registry branch fires.
  prior_formats <- tabular:::.registered_backend_formats()
  prior_fns <- lapply(prior_formats, function(f) {
    tabular:::.tabular_backends[[f]]
  })
  names(prior_fns) <- prior_formats
  withr::defer({
    for (f in prior_formats) {
      tabular:::.register_backend(f, prior_fns[[f]])
    }
  })
  for (f in prior_formats) {
    tabular:::.unregister_backend(f)
  }
  expect_identical(tabular:::.registered_backend_formats(), character(0L))
  expect_error(
    tabular:::.resolve_backend("any_format", call = rlang::caller_env()),
    class = "tabular_error_input"
  )
})
