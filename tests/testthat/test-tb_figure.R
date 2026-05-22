test_that("tb_figure() errors as unimplemented", {
  expect_error(
    tb_figure(list()),
    class = "tabular_error_runtime"
  )
})
