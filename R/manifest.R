# manifest.R — CDISC ARS Output-aligned YAML audit manifest. Called
# from emit(spec, ..., manifest = TRUE); writes `<file>.audit.yml`
# alongside the rendered artefact. The schema-of-record is
# `~/.claude/projects/-Users-vignesh-projects-r-tabular/memory/
# reference_cdisc_ars.md` — top-level keys map 1:1 to CDISC ARS
# LDM v1.0 Output-side entities. LinkML camelCase is preserved
# verbatim; tabular-specific extensions live under the `x-tabular`
# namespace per LinkML convention.
#
# Top-level keys emitted:
#
#   id                  : derived from filename base + render format.
#   version             : 1.
#   name                : the first title line, or the filename base
#                         when no titles are configured.
#   programmingCode     : context = R; code = best-effort program
#                         path (NA_character_ when undetectable);
#                         parameters carry tabular_version,
#                         git_commit, rendered_at, r_version,
#                         platform.
#   fileSpecifications  : one entry per emitted artefact
#                         (render + optional data_file), each with
#                         {name, fileType, location, sha256}.
#   displays            : one ordered_display whose displaySections
#                         carry Title, Header, Body, Footnote
#                         sub-sections, populated from the resolved
#                         spec's titles, header tree, and footnotes.
#   referencedAnalyses  : empty list (v0.1; reserved for mintverse
#                         handoff in v0.5+).
#   x-tabular           : tabular-specific extension with preset,
#                         pagination, style trace, and input
#                         provenance.
#
# Determinism contract:
# - Byte-identical across two `emit()` runs modulo the
#   `rendered_at` parameter timestamp.
# - Round-trips through `yaml::read_yaml()` + `yaml::write_yaml()`.
#
# Soft dependencies (`yaml`, `digest`) are declared in DESCRIPTION
# Suggests; we call `rlang::check_installed()` from the top of the
# manifest writer so the failure mode is informative rather than a
# cryptic namespace error.

# ---------------------------------------------------------------------
# Public-ish entry point — called from emit(); not exported
# ---------------------------------------------------------------------

# Build the manifest list, write it to `<file>.audit.yml`, and
# return the manifest path invisibly. `data_file_path` is the
# absolute path of the QC artefact when one was written, or NULL.
.write_manifest <- function(
  spec,
  grid,
  file,
  format,
  data_file_path,
  call
) {
  rlang::check_installed(
    c("yaml", "digest"),
    reason = "to write the CDISC ARS audit manifest"
  )

  manifest_path <- .manifest_path(file)
  manifest <- .build_manifest(
    spec = spec,
    grid = grid,
    file = file,
    format = format,
    data_file_path = data_file_path
  )
  yaml::write_yaml(manifest, manifest_path)
  invisible(manifest_path)
}

# Construct the manifest list. Pure; testable without writing to
# disk. The same builder is used by tests to pin the manifest shape
# and by `.write_manifest()` to serialise it.
.build_manifest <- function(spec, grid, file, format, data_file_path) {
  list(
    id = .manifest_id(file, format),
    version = 1L,
    name = .manifest_name(spec, file),
    programmingCode = .manifest_programming_code(),
    fileSpecifications = .manifest_file_specifications(
      render_path = file,
      format = format,
      data_file_path = data_file_path
    ),
    displays = list(
      .manifest_display(spec = spec, grid = grid, file = file)
    ),
    referencedAnalyses = list(),
    `x-tabular` = .manifest_x_tabular(spec = spec, grid = grid)
  )
}

# ---------------------------------------------------------------------
# Top-level field builders
# ---------------------------------------------------------------------

# Manifest sidecar path: same directory + basename as the render,
# with `.audit.yml` appended after stripping the original extension.
# Example: `out.rtf` -> `out.audit.yml`.
.manifest_path <- function(file) {
  paste0(tools::file_path_sans_ext(file), ".audit.yml")
}

# Identifier: filename-base + format. Stable across renders for the
# same target file. Spaces and other non-id-safe characters collapse
# to "_"; if the sanitised base has no alphanumeric content at all
# (e.g. "___" or ""), fall back to "tabular" so the id is meaningful.
.manifest_id <- function(file, format) {
  base <- tools::file_path_sans_ext(basename(file))
  base <- gsub("[^A-Za-z0-9_.-]", "_", base)
  if (!grepl("[A-Za-z0-9]", base)) {
    base <- "tabular"
  }
  paste0(base, "_", format)
}

# Display name. The first non-empty title line is the canonical
# table name; when no titles are configured, fall back to the
# filename base so the field is never empty. A "filename" like
# ".md" (extension-only, no real base) collapses to "tabular".
.manifest_name <- function(spec, file) {
  titles <- spec@titles
  first <- if (length(titles) > 0L) titles[[1L]] else ""
  if (!nzchar(first)) {
    base <- tools::file_path_sans_ext(basename(file))
    if (!nzchar(base) || startsWith(base, ".")) {
      return("tabular")
    }
    return(base)
  }
  first
}

# `programmingCode`: best-effort provenance block. Every probe is
# wrapped in tryCatch so a missing git binary or a sandboxed
# environment cannot break the manifest writer.
.manifest_programming_code <- function() {
  list(
    context = "R",
    code = .program_path(),
    parameters = list(
      list(name = "tabular_version", value = .pkg_version_string()),
      list(name = "git_commit", value = .git_commit_probe()),
      list(name = "rendered_at", value = .now_iso8601()),
      list(name = "r_version", value = .r_version_string()),
      list(name = "platform", value = .platform_string())
    )
  )
}

# `fileSpecifications`: one ars_output_file per emitted artefact.
# Render is always present; data_file is appended when set.
.manifest_file_specifications <- function(
  render_path,
  format,
  data_file_path
) {
  specs <- list(.file_spec_entry(render_path, format))
  if (!is.null(data_file_path)) {
    data_ext <- tolower(tools::file_ext(data_file_path))
    specs[[length(specs) + 1L]] <- .file_spec_entry(
      data_file_path,
      data_ext
    )
  }
  specs
}

# Build a single ars_output_file entry. `location` is a
# relative-path-as-basename to match CDISC convention (submission
# folders are portable; absolute paths break on transfer).
.file_spec_entry <- function(path, file_type) {
  list(
    name = basename(path),
    fileType = file_type,
    location = paste0("./", basename(path)),
    sha256 = .file_sha256(path)
  )
}

# `displays`: one ordered_display with displaySections in canonical
# order Title -> Header -> Body -> Footnote. Empty sections are
# omitted entirely so the YAML stays compact.
.manifest_display <- function(spec, grid, file) {
  display_sections <- list()

  title_section <- .display_section_title(spec@titles)
  if (!is.null(title_section)) {
    display_sections[[length(display_sections) + 1L]] <- title_section
  }

  header_section <- .display_section_header(grid)
  if (!is.null(header_section)) {
    display_sections[[length(display_sections) + 1L]] <- header_section
  }

  display_sections[[length(display_sections) + 1L]] <-
    .display_section_body(file)

  footnote_section <- .display_section_footnote(spec@footnotes)
  if (!is.null(footnote_section)) {
    display_sections[[length(display_sections) + 1L]] <- footnote_section
  }

  list(
    order = 1L,
    display = list(
      id = paste0("d_", .manifest_id(file, "display")),
      version = 1L,
      name = .manifest_name(spec, file),
      displayTitle = .manifest_name(spec, file),
      displaySections = display_sections
    )
  )
}

# `x-tabular`: vendor namespace per LinkML convention. Pharma
# reviewers know to ignore unknown `x-*` keys; this is where every
# tabular-specific rendering detail lands.
.manifest_x_tabular <- function(spec, grid) {
  list(
    schema_version = .pkg_version_string(),
    preset = .x_tabular_preset(spec),
    pagination = .x_tabular_pagination(grid),
    styles = .x_tabular_styles(spec),
    inputProvenance = .x_tabular_input_provenance(grid)
  )
}

# ---------------------------------------------------------------------
# displaySection builders
# ---------------------------------------------------------------------

# Title section. Each title line becomes one ordered_sub_section
# with explicit `order` integer.
.display_section_title <- function(titles) {
  if (length(titles) == 0L) {
    return(NULL)
  }
  list(
    sectionType = "Title",
    orderedSubSections = .ordered_sub_sections(titles)
  )
}

# Header section. Each visible column label becomes one
# ordered_sub_section; multi-level header bands are flattened to
# their labels in depth-then-position order.
.display_section_header <- function(grid) {
  meta <- grid@metadata
  band_labels <- character()
  if (
    is.data.frame(meta$headers) &&
      nrow(meta$headers) > 0L
  ) {
    band_labels <- meta$headers$label
  }
  col_labels <- meta$col_names
  if (length(col_labels) == 0L && length(band_labels) == 0L) {
    return(NULL)
  }
  texts <- c(band_labels, col_labels)
  list(
    sectionType = "Header",
    orderedSubSections = .ordered_sub_sections(texts)
  )
}

# Body section. We do not inline cell text in the manifest (the
# render file is the canonical body); we emit a reference pointer
# instead.
.display_section_body <- function(file) {
  list(
    sectionType = "Body",
    text = paste0(
      "see fileSpecifications for resolved body of ./",
      basename(file)
    )
  )
}

# Footnote section. Same shape as Title.
.display_section_footnote <- function(footnotes) {
  if (length(footnotes) == 0L) {
    return(NULL)
  }
  list(
    sectionType = "Footnote",
    orderedSubSections = .ordered_sub_sections(footnotes)
  )
}

# Build the ordered_sub_section list from a character vector. Each
# entry carries an explicit 1-based `order` so downstream parsers
# can re-sort even when YAML list order is not preserved.
.ordered_sub_sections <- function(texts) {
  lapply(seq_along(texts), function(i) {
    list(
      order = as.integer(i),
      subSection = list(text = as.character(texts[[i]]))
    )
  })
}

# ---------------------------------------------------------------------
# x-tabular builders
# ---------------------------------------------------------------------

# Preset snapshot: every public preset field. Defaults are emitted
# (no NULL holes) so the YAML is self-documenting. font_size is
# numeric on the preset_spec but we cast to integer here so the
# manifest stays type-stable across renders that pass `9` vs `9L`.
.x_tabular_preset <- function(spec) {
  p <- if (is_preset_spec(spec@preset)) spec@preset else preset_spec()
  list(
    font_family = p@font_family,
    font_size = as.integer(p@font_size),
    paper_size = p@paper_size,
    orientation = p@orientation,
    margins = as.numeric(p@margins),
    hlines = p@hlines
  )
}

# Pagination snapshot: row + panel splits the engine derived.
.x_tabular_pagination <- function(grid) {
  meta <- grid@metadata
  list(
    rows_per_page = as.integer(meta$rows_per_page),
    total_pages = as.integer(meta$total_pages),
    total_panels = as.integer(meta$total_panels)
  )
}

# Style trace: one entry per declared layer. We do not evaluate any
# predicate here (engine_style already did that); we capture only
# the user-visible declaration so the manifest documents intent.
.x_tabular_styles <- function(spec) {
  styles <- spec@styles
  if (!is_style_spec(styles) || length(styles@layers) == 0L) {
    return(list(layers = list()))
  }
  list(
    layers = lapply(styles@layers, .x_tabular_one_layer)
  )
}

# One declared style layer -> manifest entry. Captures the
# location's surface + filters (i / j / where deparsed) plus the
# style attributes that were set.
.x_tabular_one_layer <- function(layer) {
  loc <- layer@location
  where_text <- NA_character_
  if (!is.null(loc$where)) {
    where_text <- tryCatch(
      paste(deparse(rlang::quo_get_expr(loc$where)), collapse = " "),
      error = function(e) NA_character_
    )
  }
  list(
    surface = loc$surface,
    i = if (is.null(loc$i)) NA else loc$i,
    j = if (is.null(loc$j)) NA_character_ else loc$j,
    where = where_text,
    side = if (is.null(loc$side)) NA_character_ else loc$side,
    level = if (is.null(loc$level)) NA_integer_ else loc$level,
    style = .style_node_to_list(layer@style)
  )
}

# Flatten a style_node into a manifest-friendly list, dropping NA
# fields so the YAML stays compact. The field set mirrors the S7
# class declaration in aaa_class.R; only fields that were actually
# set on the predicate survive into the manifest.
.style_node_to_list <- function(node) {
  if (!is_style_node(node)) {
    return(list())
  }
  fields <- list(
    bold = node@bold,
    italic = node@italic,
    underline = node@underline,
    color = node@color,
    background = node@background,
    font_family = node@font_family,
    font_size = node@font_size,
    rule_above = node@rule_above,
    rule_below = node@rule_below,
    border_left = node@border_left,
    border_right = node@border_right,
    padding = node@padding,
    blank_above = node@blank_above,
    blank_below = node@blank_below,
    pretext = node@pretext,
    posttext = node@posttext
  )
  Filter(function(v) length(v) > 0L && !all(is.na(v)), fields)
}

# Input provenance: shape of the resolved data frame (post-sort).
# Mirrors the field names in the CDISC ARS reference bible's
# example.
.x_tabular_input_provenance <- function(grid) {
  meta <- grid@metadata
  list(
    nrow = as.integer(meta$nrow_data),
    ncol = as.integer(meta$ncol_data),
    col_names = as.character(meta$col_names)
  )
}

# ---------------------------------------------------------------------
# Provenance probes (best-effort; all return scalar character)
# ---------------------------------------------------------------------

# Best-effort path to the program that produced this render. We
# look at `getOption("tabular.program_path")` first (sponsors can
# set this in their site `.Rprofile`); otherwise we inspect the
# script call stack via `commandArgs()`. Returns NA when neither
# probe yields a real path so the YAML stays honest.
.program_path <- function() {
  opt <- getOption("tabular.program_path", default = NULL)
  if (is.character(opt) && length(opt) == 1L && nzchar(opt)) {
    return(opt)
  }
  args <- commandArgs(trailingOnly = FALSE)
  hit <- args[grepl("^--file=", args)]
  if (length(hit) > 0L) {
    return(sub("^--file=", "", hit[[1L]]))
  }
  NA_character_
}

# Tabular package version (`Package: tabular` in DESCRIPTION).
.pkg_version_string <- function() {
  v <- tryCatch(
    utils::packageVersion("tabular"),
    error = function(e) NULL
  )
  if (is.null(v)) NA_character_ else as.character(v)
}

# Best-effort `git rev-parse HEAD` from the current working
# directory. Returns NA outside a git repo or when git is missing.
.git_commit_probe <- function() {
  out <- tryCatch(
    suppressWarnings(
      system2(
        "git",
        c("rev-parse", "HEAD"),
        stdout = TRUE,
        stderr = FALSE
      )
    ),
    error = function(e) NULL
  )
  if (is.null(out) || length(out) == 0L) {
    return(NA_character_)
  }
  val <- trimws(out[[1L]])
  if (!nzchar(val)) NA_character_ else val
}

# ISO-8601 UTC timestamp. The one parameter we explicitly DO NOT
# want byte-identical across runs; the determinism contract carves
# this field out as the documented exception.
.now_iso8601 <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

# Full R version string ("R version 4.4.1 (2024-06-14)").
.r_version_string <- function() {
  R.version.string
}

# OS / arch tag in the form used by R's distribution naming.
.platform_string <- function() {
  paste(
    R.version$arch,
    R.version$os,
    sep = "-"
  )
}

# SHA-256 of a file. Uses `digest::digest(file = path)` so the hash
# matches `shasum -a 256 path` byte-for-byte. Returns NA_character_
# when the file cannot be read (e.g. a backend writer was registered
# but did not actually create the file in tests).
.file_sha256 <- function(path) {
  if (!file.exists(path)) {
    return(NA_character_)
  }
  tryCatch(
    digest::digest(file = path, algo = "sha256"),
    error = function(e) NA_character_
  )
}
