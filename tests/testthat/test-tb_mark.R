test_that("tb_mark() errors as unimplemented", {
  expect_error(
    tb_mark("x", "super"),
    class = "tabular_error_runtime"
  )
})
