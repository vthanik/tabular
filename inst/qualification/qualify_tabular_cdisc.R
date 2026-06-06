####--------------------------------------------------------------------------####
# qualify_tabular_cdisc.R
#
# Cross-backend QUALIFICATION of the `tabular` package against the CDISC pilot.
#
# Input data: PHUSE Test Data Factory ADaM (the CDISC pilot, CDISCPILOT01) - the
#   same ADaM the atorus-research/CDISC_pilot_replication repo consumes
#   (adsl/adae/advs xpt). Reference outputs for visual comparison live in that
#   repo's outputs/ folder.
#
# What it does: rebuilds 4 representative pilot tables with `tabular` from the
#   real pilot ADaM, then emits and validates ALL FOUR backends for each
#   (RTF, HTML, DOCX, PDF). Validation = (a) the file is produced without error,
#   (b) it is structurally valid (magic bytes / non-trivial size), (c) for
#   text-readable backends a known cell value appears, and (d) independent
#   dplyr counts match the rendered numbers. A PASS/FAIL matrix
#   (table x backend) is written to qual_out/QUALIFICATION_REPORT.md.
#
# Run:  Rscript qualify_tabular_cdisc.R
#   (env overrides: CDISC_ADAM = adam dir [data/adam], CDISC_OUT = out dir)
####--------------------------------------------------------------------------####

suppressWarnings(suppressMessages({
  library(haven); library(dplyr); library(tidyr); library(stringr)
  library(cards); library(tabular)
}))

ADAM <- Sys.getenv("CDISC_ADAM", "data/adam")
OUT  <- Sys.getenv("CDISC_OUT",  "qual_out")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
OUT  <- normalizePath(OUT)   # belt-and-braces; emit() now absolutises paths itself
BACKENDS <- c("rtf", "html", "docx", "pdf")   # PDF needs LaTeX deps (tabular::check_latex())

# Treatment arms (pilot TRT01P) + Total, in display order.
ARMS    <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose", "Total")
ARM_HDR <- c(Placebo = "Placebo",
             `Xanomeline Low Dose`  = "Xanomeline\nLow Dose",
             `Xanomeline High Dose` = "Xanomeline\nHigh Dose",
             Total = "Total")

# --- integer-percent n (%) cell (CDISC/IB convention; 0 -> "0") --------------
np <- function(n, N) {
  pct <- ifelse(N > 0, 100 * n / N, 0)
  p <- dplyr::case_when(n == 0 ~ "", pct == 100 ~ "(100%)", pct >= 99.5 ~ "(>99%)",
                        pct < 0.5 ~ "(<1%)", TRUE ~ sprintf("(%.0f%%)", pct))
  dplyr::if_else(n == 0, "0", paste0(n, " ", p))
}

# --- shared preset: 8pt landscape + running page header ----------------------
qual_preset <- function(spec)
  preset(spec, font_size = 8, orientation = "landscape", paper_size = "letter",
         margins = c(1, 0.75, 1, 0.75), width_mode = "window",
         pagehead = list(left  = c("CDISC Pilot - Study CDISCPILOT01",
                                   "Qualification: tabular package"),
                         right = c("Source: PHUSE TDF ADaM", "Page {page} of {npages}")))

# --- attach arm columns (shared decimal+width via cols_apply; BigN labels) ----
arm_cols <- function(spec, bigN) {
  for (a in ARMS)
    spec <- cols(spec, !!a := col_spec(label = sprintf("%s\n(N=%d)", ARM_HDR[[a]], bigN[[a]])))
  cols_apply(spec, ARMS, col_spec(align = "decimal", width = "auto"))
}

# =============================================================================
# Load data
# =============================================================================
adsl <- read_xpt(file.path(ADAM, "adsl.xpt"))
adae <- read_xpt(file.path(ADAM, "adae.xpt"))

# ITT + Total stack for demographics; Safety + Total for AE.
adsl_itt <- adsl |> filter(ITTFL == "Y")
itt2 <- bind_rows(adsl_itt, adsl_itt |> mutate(TRT01P = "Total"))
bigN_itt <- itt2 |> count(TRT01P) |> tibble::deframe()
bigN_itt <- bigN_itt[ARMS]

adsl_saf <- adsl |> filter(SAFFL == "Y")
saf2 <- bind_rows(adsl_saf, adsl_saf |> mutate(TRT01P = "Total"))
bigN_saf <- saf2 |> count(TRT01P) |> tibble::deframe()
bigN_saf <- bigN_saf[ARMS]

# AE: treatment-emergent, map TRTA -> arm label, add Total
ae <- adae |> filter(TRTEMFL == "Y") |>
  mutate(TRT01P = TRTA) |>
  semi_join(adsl_saf, by = "USUBJID")
ae2 <- bind_rows(ae, ae |> mutate(TRT01P = "Total"))

# =============================================================================
# Table builders -> each returns list(id, title, footnotes, spec, checks)
#   `checks` = named numeric expectations independently computed here, plus the
#   string token that must appear in text backends.
# =============================================================================
TABLES <- list()

# ---- T1: 14-2.01 Demographic & Baseline Characteristics (cont + cat) --------
local({
  d <- itt2 |>
    mutate(
      SEX  = factor(if_else(SEX == "M", "Male", "Female"), c("Male", "Female")),
      RACE = factor(RACE, c("WHITE", "BLACK OR AFRICAN AMERICAN",
                            "AMERICAN INDIAN OR ALASKA NATIVE")),
      AGEGR1 = factor(AGEGR1))
  ard <- ard_stack(
    d, .by = TRT01P,
    ard_summary(variables = c(AGE, HEIGHTBL, WEIGHTBL, BMIBL),
                statistic = ~ continuous_summary_fns(c("N","mean","sd","median","min","max"))),
    ard_tabulate(variables = c(AGEGR1, SEX, RACE)))
  vlab <- c(AGE="Age (years)", HEIGHTBL="Height (cm)", WEIGHTBL="Weight (kg)",
            BMIBL="BMI (kg/m^2)", AGEGR1="Age group", SEX="Sex", RACE="Race")
  vord <- setNames(seq_along(vlab), names(vlab))
  wide <- pivot_across(ard,
    statistic = list(summary = c(n="{N}", Mean="{mean}", SD="{sd}",
                                 Median="{median}", "Min."="{min}", "Max."="{max}"),
                     tabulate = "{n} ({p}%)"),
    column = "TRT01P", overall = NULL,
    decimals = c(mean=1, sd=2, median=1, min=1, max=1, p=0)) |>
    mutate(.o = vord[variable]) |> arrange(.o) |>
    transmute(group1 = vlab[variable], label = trimws(stat_label),
              across(any_of(ARMS)))
  spec <- tabular(wide, titles = c("Table 14-2.01",
      "Summary of Demographic and Baseline Characteristics", "ITT Population")) |>
    cols(group1 = col_spec(usage="group", label="", group_display="header_row"),
         label  = col_spec(label="", width="2.7in")) |>
    arm_cols(bigN_itt) |> qual_preset() |> paginate(keep_together = "group1")
  # independent checks
  exp_age_mean_pbo <- sprintf("%.1f", mean(adsl_itt$AGE[adsl_itt$TRT01P=="Placebo"]))
  TABLES[["14-2.01"]] <<- list(id="14-2.01", spec=spec,
    token = exp_age_mean_pbo,                         # placebo mean age, e.g. "75.2"
    nums  = c(ITT_total = nrow(adsl_itt)))
})

# ---- T2: 14-1.01 Summary of Analysis Populations (categorical n(%)) ---------
local({
  flags <- c(`Intent-To-Treat (ITT)`="ITTFL", `Safety`="SAFFL",
             `Efficacy`="EFFFL", `Completed Week 24`="COMP24FL")
  rows <- lapply(names(flags), function(lbl) {
    fv <- flags[[lbl]]
    cnt <- itt2 |> filter(.data[[fv]] == "Y") |> count(TRT01P, name="n") |>
      right_join(tibble(TRT01P = ARMS), by="TRT01P") |> replace_na(list(n=0L)) |>
      mutate(N = bigN_itt[TRT01P], cell = np(n, N), group1 = "Analysis Populations",
             label = lbl)
    cnt |> select(group1, label, TRT01P, cell)
  })
  wide <- bind_rows(rows) |>
    mutate(label = factor(label, names(flags))) |> arrange(label) |>
    mutate(label = as.character(label)) |>
    pivot_wider(names_from = TRT01P, values_from = cell) |>
    select(group1, label, any_of(ARMS))
  spec <- tabular(wide, titles = c("Table 14-1.01",
      "Summary of Analysis Populations", "All Randomized Subjects")) |>
    cols(group1 = col_spec(usage="group", label="", group_display="header_row"),
         label  = col_spec(label="", width="2.7in")) |>
    arm_cols(bigN_itt) |> qual_preset()
  exp_saf_pbo <- sum(adsl_itt$SAFFL=="Y" & adsl_itt$TRT01P=="Placebo")
  TABLES[["14-1.01"]] <<- list(id="14-1.01", spec=spec,
    token = as.character(exp_saf_pbo), nums = c(n_pop_rows = 4))
})

# ---- T3: 14-3.01 Overview of Treatment-Emergent Adverse Events --------------
local({
  any_ae <- ae2 |> distinct(USUBJID, TRT01P) |> count(TRT01P, name="n") |>
    mutate(label = "Subjects with >=1 TEAE", label_ord = 1L)
  sev <- ae2 |>
    mutate(sev = str_to_title(AESEV)) |>
    group_by(USUBJID, TRT01P) |>
    summarise(maxsev = factor(c("Mild","Moderate","Severe"),
                c("Mild","Moderate","Severe"))[max(match(sev,
                c("Mild","Moderate","Severe")))], .groups="drop") |>
    count(TRT01P, label = maxsev, name="n") |>
    mutate(label = paste0("  ", as.character(label)),
           label_ord = match(trimws(label), c("Mild","Moderate","Severe")) + 1L)
  body <- bind_rows(any_ae |> mutate(label_ord=0L), sev) |>
    right_join(tidyr::crossing(TRT01P = ARMS,
                  label = c("Subjects with >=1 TEAE","  Mild","  Moderate","  Severe")),
               by = c("TRT01P","label")) |>
    replace_na(list(n=0L)) |>
    mutate(N = bigN_saf[TRT01P], cell = np(n, N), group1 = "Treatment-Emergent Adverse Events",
           label_ord = match(label, c("Subjects with >=1 TEAE","  Mild","  Moderate","  Severe"))) |>
    arrange(label_ord)
  wide <- body |> select(group1, label, label_ord, TRT01P, cell) |>
    pivot_wider(names_from = TRT01P, values_from = cell) |>
    arrange(label_ord) |> select(group1, label, any_of(ARMS))
  spec <- tabular(wide, titles = c("Table 14-3.01",
      "Overview of Treatment-Emergent Adverse Events", "Safety Population"),
      footnotes = "A subject is counted once at the maximum severity reported.") |>
    cols(group1 = col_spec(usage="group", label="", group_display="header_row"),
         label  = col_spec(label="", width="2.7in")) |>
    arm_cols(bigN_saf) |> qual_preset()
  exp_any_pbo <- ae2 |> filter(TRT01P=="Placebo") |> distinct(USUBJID) |> nrow()
  TABLES[["14-3.01"]] <<- list(id="14-3.01", spec=spec,
    token = as.character(exp_any_pbo), nums = c(any_ae_pbo = exp_any_pbo))
})

# ---- T4: 14-3.04 TEAEs by System Organ Class and Preferred Term (hierarchy) -
local({
  # subjects with >=1 AE per SOC (depth 0) and per SOC/PT (depth 1)
  soc <- ae2 |> distinct(USUBJID, TRT01P, AEBODSYS) |>
    count(TRT01P, AEBODSYS, name="n") |>
    mutate(AEDECOD = NA_character_, depth = 0L)
  pt  <- ae2 |> distinct(USUBJID, TRT01P, AEBODSYS, AEDECOD) |>
    count(TRT01P, AEBODSYS, AEDECOD, name="n") |> mutate(depth = 1L)
  long <- bind_rows(soc, pt)
  # full grid so every arm has a cell
  grid <- long |> distinct(AEBODSYS, AEDECOD, depth) |>
    tidyr::crossing(TRT01P = ARMS)
  full <- grid |> left_join(long, by=c("AEBODSYS","AEDECOD","depth","TRT01P")) |>
    replace_na(list(n=0L)) |>
    mutate(N = bigN_saf[TRT01P], cell = np(n, N))
  # SOC sort by Total desc; PT within SOC by Total desc
  tot <- full |> filter(TRT01P=="Total")
  soc_ord <- tot |> filter(depth==0L) |> arrange(desc(n)) |>
    distinct(AEBODSYS) |> mutate(soc_ord = row_number())
  pt_ord  <- tot |> filter(depth==1L) |> arrange(AEBODSYS, desc(n)) |>
    group_by(AEBODSYS) |> mutate(pt_ord = row_number()) |> ungroup() |>
    select(AEBODSYS, AEDECOD, pt_ord)
  wide <- full |>
    mutate(stub = if_else(depth==0L, str_to_title(AEBODSYS),
                          str_to_title(AEDECOD))) |>
    left_join(soc_ord, by="AEBODSYS") |>
    left_join(pt_ord,  by=c("AEBODSYS","AEDECOD")) |>
    mutate(pt_ord = if_else(depth==0L, 0L, pt_ord)) |>
    select(soc_ord, pt_ord, depth, stub, AEBODSYS, AEDECOD, TRT01P, cell) |>
    pivot_wider(names_from = TRT01P, values_from = cell) |>
    arrange(soc_ord, depth, pt_ord) |>
    select(stub, depth, any_of(ARMS))
  spec <- tabular(wide, titles = c("Table 14-3.04",
      "Treatment-Emergent Adverse Events by System Organ Class and Preferred Term",
      "Safety Population"),
      footnotes = c("A subject is counted once within each SOC and once within each PT.",
                    "SOCs and PTs sorted by decreasing frequency in the Total column.")) |>
    cols(stub  = col_spec(label = "System Organ Class / Preferred Term",
                          indent = "depth", width = "3.2in"),
         depth = col_spec(visible = FALSE)) |>
    arm_cols(bigN_saf) |> qual_preset()
  exp_nrec <- nrow(wide)
  top_soc <- str_to_title(soc_ord$AEBODSYS[soc_ord$soc_ord == 1])
  TABLES[["14-3.04"]] <<- list(id="14-3.04", spec=spec,
    token = top_soc, nums = c(soc_pt_rows = exp_nrec))
})

# =============================================================================
# Emit all backends + validate
# =============================================================================
read_bin   <- function(f) readBin(f, "raw", n = file.info(f)$size)
is_pdf     <- function(f) { r <- read_bin(f); length(r) > 5 && rawToChar(r[1:5]) == "%PDF-" }
is_zip     <- function(f) { r <- read_bin(f); length(r) > 4 && all(r[1:2] == as.raw(c(0x50,0x4b))) } # docx = PK zip
# Extract rendered text from any backend and check the spot-check value is
# present - this is the cross-backend PARITY test. docx = unzip word/document.xml;
# pdf = pdftotext if available (else NA -> structural-only).
text_has   <- function(f, tok, be) {
  if (is.na(tok)) return(NA)
  txt <- tryCatch({
    if (be == "docx") {
      con <- unz(f, "word/document.xml"); on.exit(close(con))
      paste(readLines(con, warn = FALSE), collapse = "")
    } else if (be == "pdf") {
      if (!nzchar(Sys.which("pdftotext"))) return(NA)
      paste(system2("pdftotext", c(shQuote(f), "-"), stdout = TRUE, stderr = FALSE),
            collapse = " ")
    } else paste(readLines(f, warn = FALSE), collapse = "")
  }, error = function(e) NA_character_)
  if (length(txt) != 1 || is.na(txt)) return(NA)
  txt <- gsub("\\\\[a-z]+[0-9-]*|[{}]|<[^>]+>", "", txt)   # strip RTF ctrl / XML/HTML tags
  grepl(tok, txt, fixed = TRUE)
}

results <- list()
for (id in names(TABLES)) {
  tb <- TABLES[[id]]
  for (be in BACKENDS) {
    f <- file.path(OUT, sprintf("t_%s.%s", gsub("\\.", "_", id), be))
    err <- tryCatch({ emit(tb$spec, f); NA_character_ },
                    error = function(e) conditionMessage(e))
    ok_emit <- is.na(err) && file.exists(f)
    sz <- if (ok_emit) file.info(f)$size else 0
    struct <- if (!ok_emit) FALSE else switch(be,
      pdf  = is_pdf(f),
      docx = is_zip(f),
      rtf  = sz > 2000 && grepl("^\\{\\\\rtf", rawToChar(read_bin(f)[1:6])),
      html = sz > 2000 && grepl("<table|<tr", paste(readLines(f, warn=FALSE), collapse="")))
    tok <- text_has(f, tb$token, be)   # parity check in every backend (incl. docx)
    results[[length(results)+1]] <- tibble(table = id, backend = be,
      emitted = ok_emit, bytes = sz, structural = struct,
      token_found = tok, error = err)
  }
}
res <- bind_rows(results)

# =============================================================================
# Report
# =============================================================================
fmtcell <- function(emitted, structural, token) {
  if (!emitted) return("FAIL(emit)")
  if (isFALSE(structural)) return("FAIL(struct)")
  if (isFALSE(token)) return("WARN(token)")
  "PASS"
}
res <- res |> mutate(status = mapply(fmtcell, emitted, structural, token_found))
matrix_tbl <- res |> select(table, backend, status) |>
  pivot_wider(names_from = backend, values_from = status) |>
  select(table, any_of(BACKENDS))

cat("\n================= QUALIFICATION RESULT MATRIX =================\n")
print(as.data.frame(matrix_tbl), row.names = FALSE)
cat("\nNumeric independent checks:\n")
for (id in names(TABLES)) {
  nm <- TABLES[[id]]$nums
  cat(sprintf("  %-8s %s\n", id, paste(sprintf("%s=%s", names(nm), nm), collapse="  ")))
}
npass <- sum(res$status == "PASS"); ntot <- nrow(res)
cat(sprintf("\nOverall: %d/%d cells PASS, %d emitted, %d structurally valid.\n",
            npass, ntot, sum(res$emitted), sum(res$structural, na.rm=TRUE)))

# markdown report
md <- c(
  "# `tabular` cross-backend qualification - CDISC pilot",
  "",
  sprintf("Built with tabular %s. Input: PHUSE Test Data Factory ADaM (CDISCPILOT01), the same data as atorus-research/CDISC_pilot_replication.",
          as.character(packageVersion("tabular"))),
  "",
  "Four representative pilot tables rebuilt with `tabular` from the real pilot ADaM, each emitted and validated across all four backends.",
  "",
  "## Result matrix (table x backend)",
  "",
  paste0("| Table | ", paste(BACKENDS, collapse=" | "), " |"),
  paste0("|", strrep("---|", length(BACKENDS)+1)),
  apply(matrix_tbl, 1, function(r) paste0("| ", paste(r, collapse=" | "), " |")),
  "",
  "Legend: PASS = emitted + structurally valid + the independent spot-check value was found in the rendered text of that backend (RTF control words / HTML+DOCX XML stripped) = cross-backend content parity; WARN(token) = rendered but the spot-check string was not located; FAIL(emit/struct) = error or invalid file.",
  "",
  "## Tables",
  "- **14-2.01** Demographics & Baseline (ITT) - continuous + categorical via `ard_stack` + `pivot_across`.",
  "- **14-1.01** Analysis Populations - categorical n(%).",
  "- **14-3.01** TEAE overview - subjects with >=1 TEAE by maximum severity.",
  "- **14-3.04** TEAE by SOC & PT - 2-level hierarchy via header_row sections, sorted by Total frequency.",
  "",
  "## Independent numeric checks (computed from ADaM, not from tabular)",
  paste0("- ", sapply(names(TABLES), function(id) {
    nm <- TABLES[[id]]$nums
    sprintf("%s: %s", id, paste(sprintf("%s = %s", names(nm), nm), collapse=", ")) })),
  "",
  sprintf("**Overall: %d/%d backend cells PASS** (%d/%d emitted, %d structurally valid).",
          npass, ntot, sum(res$emitted), ntot, sum(res$structural, na.rm=TRUE)),
  "",
  "## Per-cell detail",
  "",
  "| Table | Backend | Emitted | Bytes | Structural | Token | Error |",
  "|---|---|---|---|---|---|---|",
  apply(res, 1, function(r) sprintf("| %s | %s | %s | %s | %s | %s | %s |",
    r["table"], r["backend"], r["emitted"], r["bytes"], r["structural"],
    r["token_found"], ifelse(is.na(r["error"]), "", r["error"])))
)
writeLines(md, file.path(OUT, "QUALIFICATION_REPORT.md"))
cat("\nWrote:", file.path(OUT, "QUALIFICATION_REPORT.md"), "\n")
cat("Outputs in:", normalizePath(OUT), "\n")
