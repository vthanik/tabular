test_that("tb_cols() errors as unimplemented", {
  expect_error(
    tb_cols(saf_demo),
    class = "tabular_error_runtime"
  )
})
