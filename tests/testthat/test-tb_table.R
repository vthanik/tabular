test_that("tb_table() errors as unimplemented", {
  expect_error(
    tb_table(saf_demo),
    class = "tabular_error_runtime"
  )
})
