test_that("tb_preset() errors as unimplemented", {
  expect_error(
    tb_preset(),
    class = "tabular_error_runtime"
  )
})
