test_that("is_tabular_spec() recognises specs and rejects non-specs", {
  spec <- tb_table(saf_demo)
  expect_true(is_tabular_spec(spec))

  expect_false(is_tabular_spec(list()))
  expect_false(is_tabular_spec(data.frame()))
  expect_false(is_tabular_spec("not a spec"))
  expect_false(is_tabular_spec(NULL))
})

test_that("is_tabular_grid() recognises grids and rejects non-grids", {
  grid <- tabular_grid()
  expect_true(is_tabular_grid(grid))

  expect_false(is_tabular_grid(list()))
  expect_false(is_tabular_grid(tb_table(saf_demo)))
  expect_false(is_tabular_grid(NULL))
})

test_that("column_spec() builds an S7 column_spec object", {
  col <- column_spec(name = "trt_a", label = "Treatment A", width = 1.5)
  expect_true(S7::S7_inherits(col, column_spec))
  expect_identical(col@name, "trt_a")
  expect_identical(col@label, "Treatment A")
  expect_identical(col@width, 1.5)
  expect_true(col@visible)
})
