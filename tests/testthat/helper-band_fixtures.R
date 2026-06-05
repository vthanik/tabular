# helper-band_fixtures.R — shared per-scenario tabular_spec builders
# for header-band rule-scope edge-case coverage. Six visible columns
# (`label`, `soc_n`, `placebo`, `drug_50`, `drug_100`, `Total`) so
# positions are predictable across all backend snapshots.
#
# Scenarios A–J cover the cmidrule(lr) edge-case matrix; scenario G
# is the user's reported bug (band over `drug_50` + `drug_100` only,
# with unmapped columns on both sides).

band_fixture <- function(
  scenario = c("A", "B", "C", "D", "E", "F", "G", "H", "I", "J")
) {
  scenario <- match.arg(scenario)
  base <- tabular(
    cdisc_saf_aesocpt,
    titles = "Band rule scope test",
    footnotes = "Fixture for header-band cmidrule(lr) coverage."
  ) |>
    cols(
      label = col_spec(label = "SOC / PT"),
      soc = col_spec(visible = FALSE),
      row_type = col_spec(visible = FALSE),
      indent_level = col_spec(visible = FALSE),
      n_total = col_spec(visible = FALSE),
      soc_n = col_spec(label = "SOC N"),
      placebo = col_spec(label = "Placebo"),
      drug_50 = col_spec(label = "Drug 50"),
      drug_100 = col_spec(label = "Drug 100"),
      Total = col_spec(label = "Total")
    )

  switch(
    scenario,
    A = headers(base, "Var" = "label"),
    B = headers(base, "Sum" = "Total"),
    C = headers(base, "Arm" = "placebo"),
    D = headers(
      base,
      "All" = c("label", "soc_n", "placebo", "drug_50", "drug_100", "Total")
    ),
    E = headers(base, "Right" = c("drug_50", "drug_100", "Total")),
    F = headers(base, "Left" = c("label", "soc_n", "placebo")),
    G = headers(base, "Active Treatment" = c("drug_50", "drug_100")),
    H = headers(
      base,
      "A" = "placebo",
      "B" = c("drug_50", "drug_100")
    ),
    I = headers(
      base,
      "A" = "placebo",
      "B" = c("drug_50", "drug_100", "Total")
    ),
    J = headers(
      base,
      "Treatment" = list(
        "Control" = "placebo",
        "Active" = c("drug_50", "drug_100")
      )
    )
  )
}

# Render one fixture to the named backend, returning the emitted bytes
# as a character scalar (HTML / LaTeX / RTF / MD) or the unzipped
# word/document.xml (DOCX). Keeps per-backend test code terse.
band_emit <- function(scenario, ext = c("html", "tex", "rtf", "md", "docx")) {
  ext <- match.arg(ext)
  spec <- band_fixture(scenario)
  path <- tempfile(fileext = paste0(".", ext))
  on.exit(unlink(path), add = TRUE)
  emit(spec, path)
  if (ext == "docx") {
    tmp <- tempfile()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    utils::unzip(path, files = "word/document.xml", exdir = tmp)
    paste(readLines(file.path(tmp, "word", "document.xml")), collapse = "\n")
  } else {
    paste(readLines(path, warn = FALSE), collapse = "\n")
  }
}

# Scenarios, exposed as a vector so per-backend tests can iterate.
band_scenarios <- function() {
  c("A", "B", "C", "D", "E", "F", "G", "H", "I", "J")
}
