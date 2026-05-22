test_that("tb_styles() errors as unimplemented", {
  expect_error(
    tb_styles(saf_aesocpt),
    class = "tabular_error_runtime"
  )
})
