test_that("tb_rows() errors as unimplemented", {
  expect_error(
    tb_rows(saf_demo),
    class = "tabular_error_runtime"
  )
})
