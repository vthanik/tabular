# `tabular` cross-backend qualification — CDISC pilot

A self-contained acceptance test that rebuilds representative CDISC-pilot tables
with the `tabular` package from the **real PHUSE Test Data Factory ADaM**
(CDISCPILOT01 — the same data the `atorus-research/CDISC_pilot_replication` repo
consumes) and validates that every output backend renders correct, consistent
tables.

## What it proves

For 4 representative pilot tables it emits each backend and checks:

1. **Emit** — `emit()` writes the file with no error.
2. **Structural** — the file is a valid artifact (RTF `{\rtf` header / HTML
   `<table>` / DOCX = a `PK` zip with `word/document.xml`).
3. **Cross-backend parity** — an independent spot-check value (computed from the
   ADaM with plain dplyr, *not* from tabular) appears in the rendered text of
   **every** backend. Same spec → same numbers in RTF, HTML and DOCX.
4. **Independent numeric checks** — table-level counts recomputed from ADaM.

Tables:

| Table   | Content                                   | tabular features exercised |
|---------|-------------------------------------------|----------------------------|
| 14-2.01 | Demographics & Baseline (ITT)             | `ard_stack` + `pivot_across` (continuous + categorical), group headers, indent, decimal align, BigN labels |
| 14-1.01 | Analysis Populations                      | categorical n(%), `cols_apply` arm columns |
| 14-3.01 | TEAE overview by maximum severity         | categorical n(%) |
| 14-3.04 | TEAE by SOC & PT                           | 2-level hierarchy via header_row sections, frequency sort, large table |

## How to run

1. **Get the ADaM data** (not committed — ~9 MB). Download
   `phuse-scripts/data/adam/TDF_ADaM_v1.0.zip` from the PHUSE GitHub and unzip
   the `.xpt` files into `data/adam/`:

   ```r
   dir.create("data/adam", recursive = TRUE, showWarnings = FALSE)
   download.file(
     "https://github.com/phuse-org/phuse-scripts/raw/master/data/adam/TDF_ADaM_v1.0.zip",
     "data/adam/TDF_ADaM_v1.0.zip", mode = "wb")
   unzip("data/adam/TDF_ADaM_v1.0.zip", exdir = "data/adam")
   ```

2. **Run the qualification:**

   ```sh
   Rscript qualify_tabular_cdisc.R
   ```

   Deps: `haven dplyr tidyr stringr cards tabular`. Env overrides:
   `CDISC_ADAM` (ADaM dir, default `data/adam`), `CDISC_OUT` (output dir,
   default `qual_out`).

3. **Read the result:** `qual_out/QUALIFICATION_REPORT.md` (PASS/FAIL matrix +
   per-cell detail) and the rendered `qual_out/t_*.{rtf,html,docx}`.

## PDF

PDF is **enabled** in `BACKENDS`. It needs a LaTeX engine plus the LaTeX
packages the backend uses — check with `tabular::check_latex()` and install any
missing with `tinytex::tlmgr_install(...)` (locally only `siunitx` + `tex-gyre`
were missing on top of `tabularray`/`ninecolors`). On an OS-managed TeX Live,
install user-space TinyTeX instead (`tinytex::install_tinytex()`). The
cross-backend parity check reads PDF text via `pdftotext` when it is on PATH;
otherwise PDF is validated structurally only (`%PDF` magic + size).

To skip PDF (e.g. no LaTeX in a CI image), drop `"pdf"` from the `BACKENDS`
vector — the other three backends need no system dependencies.

## Notes

An earlier run of this qualification surfaced a DOCX bug: `emit()` failed for a
relative output path because the DOCX backend `setwd()`s into a temp staging dir
before `utils::zip`, so the relative path resolved against the stage and `zip`
aborted. **This is now fixed** in `emit()` itself (the path is absolutised once
at the backend handoff), so no caller-side workaround is needed. The driver
still absolutises `CDISC_OUT` with `normalizePath()`, but it is now belt-and-
braces rather than required.
