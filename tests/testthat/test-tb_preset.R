test_that("tb_preset() errors as unimplemented", {
  expect_error(
    tb_preset(),
    class = "tabular_error_runtime"
  )
})

test_that("tb_set_preset() errors as unimplemented", {
  expect_error(
    tb_set_preset(font_size = 8),
    class = "tabular_error_runtime"
  )
  expect_error(
    tb_set_preset(reset = TRUE),
    class = "tabular_error_runtime"
  )
})

test_that("tb_get_preset() errors as unimplemented", {
  expect_error(
    tb_get_preset(),
    class = "tabular_error_runtime"
  )
})

test_that("tb_preset() unimplemented error has a stable message", {
  expect_snapshot(error = TRUE, tb_preset())
})
