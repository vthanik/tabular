test_that("tb_render() errors as unimplemented", {
  expect_error(
    tb_render(saf_demo, tempfile(fileext = ".rtf")),
    class = "tabular_error_runtime"
  )
})
