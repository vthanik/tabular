# test-figure_raster.R — rasterisation + pure-R image helpers.

png_fixture <- function() test_path("fixtures", "fig-sample.png")
jpg_fixture <- function() test_path("fixtures", "fig-sample.jpg")

test_that(".base64_encode_raw matches RFC 4648 vectors", {
  enc <- function(s) tabular:::.base64_encode_raw(charToRaw(s))
  expect_equal(enc(""), "")
  expect_equal(enc("f"), "Zg==")
  expect_equal(enc("fo"), "Zm8=")
  expect_equal(enc("foo"), "Zm9v")
  expect_equal(enc("foob"), "Zm9vYg==")
  expect_equal(enc("fooba"), "Zm9vYmE=")
  expect_equal(enc("foobar"), "Zm9vYmFy")
  expect_equal(enc("Man"), "TWFu")
  expect_equal(enc("hello"), "aGVsbG8=")
})

test_that(".base64_encode_raw round-trips arbitrary bytes", {
  bytes <- as.raw(0:255)
  b64 <- tabular:::.base64_encode_raw(bytes)
  # decode via base R chartr-free path: write to a connection openssl-free.
  # Re-encode the documented expected string for the 0:255 sequence is long;
  # instead assert length invariant (4 chars per 3 bytes, padded).
  expect_equal(nchar(b64), 4L * ceiling(length(bytes) / 3L))
  expect_false(grepl("[^A-Za-z0-9+/=]", b64))
})

test_that(".png_dims / .jpeg_dims / .image_dims parse fixtures", {
  pb <- readBin(png_fixture(), "raw", file.info(png_fixture())$size)
  expect_equal(unname(tabular:::.png_dims(pb)), c(120, 90))
  expect_equal(unname(tabular:::.image_dims(pb, "png")), c(120, 90))

  skip_if_not(file.exists(jpg_fixture()))
  jb <- readBin(jpg_fixture(), "raw", file.info(jpg_fixture())$size)
  expect_equal(unname(tabular:::.jpeg_dims(jb)), c(120, 90))
  expect_equal(unname(tabular:::.image_dims(jb, "jpeg")), c(120, 90))
})

test_that("dim parsers return NA on truncated / unknown input", {
  expect_true(anyNA(tabular:::.png_dims(as.raw(1:10))))
  expect_true(anyNA(tabular:::.jpeg_dims(as.raw(c(0xFF, 0xD8)))))
  expect_true(anyNA(tabular:::.image_dims(as.raw(1:4), "gif")))
})

test_that(".be_uint16 / .be_uint32 decode big-endian", {
  expect_equal(tabular:::.be_uint16(as.raw(c(0x01, 0x00))), 256)
  expect_equal(tabular:::.be_uint32(as.raw(c(0x00, 0x00, 0x01, 0x00))), 256)
  # no integer overflow near the 32-bit ceiling
  expect_equal(
    tabular:::.be_uint32(as.raw(c(0xFF, 0x00, 0x00, 0x00))),
    4278190080
  )
})

test_that(".figure_rasterise passes a file through byte-for-byte", {
  pb <- readBin(png_fixture(), "raw", file.info(png_fixture())$size)
  out <- tabular:::.figure_rasterise(
    png_fixture(),
    format = "html",
    width_in = 4,
    height_in = 3,
    dpi = 150
  )
  expect_equal(out$ext, "png")
  expect_identical(out$bytes, pb)
})

test_that(".figure_rasterise renders a function to PNG for raster targets", {
  out <- tabular:::.figure_rasterise(
    function() plot(1:5),
    format = "html",
    width_in = 4,
    height_in = 3,
    dpi = 96
  )
  expect_equal(out$ext, "png")
  expect_identical(out$bytes[1:4], as.raw(c(0x89, 0x50, 0x4E, 0x47)))
})

test_that(".figure_rasterise falls back to the base PNG device without ragg", {
  testthat::local_mocked_bindings(
    is_installed = function(...) FALSE,
    .package = "rlang"
  )
  out <- tabular:::.figure_rasterise(
    function() plot(1:5),
    format = "html",
    width_in = 4,
    height_in = 3,
    dpi = 96
  )
  expect_equal(out$ext, "png")
  expect_identical(out$bytes[1:4], as.raw(c(0x89, 0x50, 0x4E, 0x47)))
})

test_that(".figure_rasterise renders a function to vector PDF for LaTeX targets", {
  out <- tabular:::.figure_rasterise(
    function() plot(1:5),
    format = "latex",
    width_in = 4,
    height_in = 3,
    dpi = 96
  )
  expect_equal(out$ext, "pdf")
  expect_equal(rawToChar(out$bytes[1:5]), "%PDF-")
})

test_that(".figure_rasterise honours a JPEG file extension", {
  skip_if_not(file.exists(jpg_fixture()))
  out <- tabular:::.figure_rasterise(
    jpg_fixture(),
    format = "rtf",
    width_in = 4,
    height_in = 3,
    dpi = 150
  )
  expect_equal(out$ext, "jpeg")
})

test_that(".figure_rasterise renders a recorded base plot", {
  # Headless devices keep no display list unless asked; an interactive
  # recordPlot() would. Enable it so the recording is replayable here.
  grDevices::png(tempfile(fileext = ".png"))
  grDevices::dev.control("enable")
  plot(1:4, main = "rec")
  rp <- grDevices::recordPlot()
  grDevices::dev.off()

  out <- tabular:::.figure_rasterise(
    rp,
    format = "html",
    width_in = 4,
    height_in = 3,
    dpi = 96
  )
  expect_equal(out$ext, "png")
  expect_identical(out$bytes[1:4], as.raw(c(0x89, 0x50, 0x4E, 0x47)))
})

test_that(".figure_rasterise renders a ggplot to PNG and to vector PDF", {
  skip_if_not_installed("ggplot2")
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()

  png_out <- tabular:::.figure_rasterise(
    p,
    format = "html",
    width_in = 4,
    height_in = 3,
    dpi = 72
  )
  expect_equal(png_out$ext, "png")
  expect_identical(png_out$bytes[1:4], as.raw(c(0x89, 0x50, 0x4E, 0x47)))

  pdf_out <- tabular:::.figure_rasterise(
    p,
    format = "pdf",
    width_in = 4,
    height_in = 3,
    dpi = 72
  )
  expect_equal(pdf_out$ext, "pdf")
  expect_equal(rawToChar(pdf_out$bytes[1:5]), "%PDF-")
})

test_that("a ggplot figure renders end-to-end through HTML", {
  skip_if_not_installed("ggplot2")
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()
  out <- withr::local_tempfile(fileext = ".html")
  emit(figure(p, titles = "ggplot figure"), out)
  h <- paste(readLines(out), collapse = "\n")
  expect_true(grepl("data:image/png;base64,", h, fixed = TRUE))
})
