# test-style-connectivity.R — style-surface connectivity guard.
#
# Locks the chrome-surface border wiring established by the style audit
# (issue #5): a `style(border_*, .at = cells_<surface>())` layer must
# reach that surface's element in HTML, and must do so through EXACTLY
# ONE channel (no region + surface-node double-emission). Single-instance
# fixtures (one group, one subgroup partition) keep the occurrence count
# meaningful: a correct border appears once, a dual-channel bug twice.

# One group value -> one group-header row; one subgroup partition -> one
# banner; one title line; one footnote line. So a per-surface border is
# expected exactly once in the HTML.
mk_one <- function(group = FALSE, sub = FALSE) {
  df <- data.frame(
    grp = c("A", "A"),
    v = c("1", "2"),
    stringsAsFactors = FALSE
  )
  spec <- tabular(df, titles = "Solo title", footnotes = "Solo footnote.")
  if (group) {
    spec <- cols(spec, grp = col_spec(label = "Group")) |>
      group_rows(by = "grp")
  } else {
    spec <- cols(spec, grp = col_spec(label = "Group"))
  }
  if (sub) {
    spec <- subgroup(spec, "grp")
  }
  spec
}

render_html <- function(spec) {
  f <- withr::local_tempfile(fileext = ".html")
  emit(spec, f)
  paste(readLines(f, warn = FALSE), collapse = "\n")
}

# The distinctive border token (thick dashed magenta) -- never a default.
BORDER <- function() brdr("thick", "dashed", "#ff1133")
TOKEN <- "dashed #ff1133"
count_tok <- function(txt) {
  m <- gregexpr(TOKEN, txt, fixed = TRUE)[[1]]
  if (length(m) == 1L && m[[1]] == -1L) 0L else length(m)
}

test_that("chrome-surface borders reach HTML exactly once (#issue5, no double-channel)", {
  cases <- list(
    headers = list(spec = mk_one(), loc = cells_headers()),
    group_headers = list(
      spec = mk_one(group = TRUE),
      loc = cells_group_headers()
    ),
    title = list(spec = mk_one(), loc = cells_title()),
    footnotes = list(spec = mk_one(), loc = cells_footnotes()),
    subgroup_labels = list(
      spec = mk_one(sub = TRUE),
      loc = cells_subgroup_labels()
    )
  )
  for (nm in names(cases)) {
    cs <- cases[[nm]]
    styled <- style(cs$spec, border_bottom = BORDER(), .at = cs$loc)
    txt <- render_html(styled)
    n <- count_tok(txt)
    # Reached the surface ...
    expect_gte(n, 1L)
    # ... through exactly one channel (region OR surface-node, never both).
    expect_equal(
      n,
      1L,
      info = sprintf("%s emitted the border %d times", nm, n)
    )
  }
})

test_that("border default colour resolves to ink in HTML, not currentColor (#issue6)", {
  # A recoloured header with a default-colour rule: text red, rule ink,
  # decoupled (the currentColor coupling is gone).
  spec <- mk_one() |>
    style(color = "#ff1133", .at = cells_headers()) |>
    style(border_bottom = brdr(), .at = cells_headers())
  txt <- render_html(spec)
  expect_false(grepl("currentColor", txt))
  expect_true(grepl("#212529", txt))
})
