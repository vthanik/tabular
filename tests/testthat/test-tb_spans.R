test_that("tb_spans() errors as unimplemented", {
  expect_error(
    tb_spans(saf_aesocpt),
    class = "tabular_error_runtime"
  )
})
