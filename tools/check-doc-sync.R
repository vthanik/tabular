# check-doc-sync.R — merge gate for the release-metadata and AI/Agents
# doc surfaces. Run from the package root:
#
#   Rscript tools/check-doc-sync.R
#
# Fails (non-zero exit) when a surface that must track the package has
# drifted:
#
#   1. CITATION.cff `version:` differs from DESCRIPTION `Version:`.
#   2. CITATION.cff `title:` differs from DESCRIPTION `Title:`
#      (modulo the "tabular: " prefix).
#   3. An exported function is missing from the AI/Agents skill
#      (pkgdown/assets/skills/tabular/SKILL.md — served on the pkgdown
#      site and indexed into llms.txt).
#
# Enforced in CI on every pull request into main (.github/workflows/
# doc-sync.yaml). Pure base R, no dependencies.

fails <- character()

desc <- read.dcf("DESCRIPTION", fields = c("Version", "Title"))
cff <- readLines("CITATION.cff", warn = FALSE)

# -- 1. version parity -------------------------------------------------
cff_version <- sub("^version:\\s*\"?([^\"]*)\"?\\s*$", "\\1",
  grep("^version:", cff, value = TRUE)[1]
)
if (!identical(cff_version, unname(desc[, "Version"]))) {
  fails <- c(fails, sprintf(
    "CITATION.cff version (%s) != DESCRIPTION Version (%s).",
    cff_version, desc[, "Version"]
  ))
}

# -- 2. title parity ---------------------------------------------------
cff_title <- sub("^title:\\s*\"?(.*?)\"?\\s*$", "\\1",
  grep("^title:", cff, value = TRUE)[1]
)
cff_title <- sub("^tabular:\\s*", "", cff_title)
desc_title <- gsub("\\s+", " ", unname(desc[, "Title"]))
if (!identical(cff_title, desc_title)) {
  fails <- c(fails, sprintf(
    "CITATION.cff title (%s) != DESCRIPTION Title (%s).",
    cff_title, desc_title
  ))
}

# -- 3. every export appears in the AI/Agents skill --------------------
skill_path <- "pkgdown/assets/skills/tabular/SKILL.md"
skill <- paste(readLines(skill_path, warn = FALSE), collapse = "\n")
exports <- sub(
  "^export\\((.*)\\)$", "\\1",
  grep("^export\\(", readLines("NAMESPACE", warn = FALSE), value = TRUE)
)
exports <- gsub("[\"`]", "", exports)
missing <- exports[!vapply(
  exports,
  function(fn) grepl(fn, skill, fixed = TRUE),
  logical(1)
)]
if (length(missing) > 0) {
  fails <- c(fails, sprintf(
    "exports missing from %s: %s.",
    skill_path, paste(missing, collapse = ", ")
  ))
}

if (length(fails) > 0) {
  cat("Doc-sync check FAILED:\n")
  cat(paste0("  - ", fails, collapse = "\n"), "\n")
  cat("Update CITATION.cff / the AI-Agents skill before merging to main.\n")
  quit(status = 1)
}
cat("Doc-sync check passed: CITATION.cff and the AI/Agents skill are current.\n")
