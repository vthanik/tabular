# tabular (development version)

* Initial package skeleton. S7 classes (`tabular_spec`, `tabular_grid`,
  `column_spec`) declared in `R/aaa_class.R`; nine `tb_*` verbs stubbed
  with full roxygen signatures and `tabular_error_runtime` aborts until
  backends land.
* Five pre-summarised demo datasets bundled (`saf_demo`, `saf_aeoverall`,
  `saf_aesocpt`, `saf_vital`, `eff_resp`) derived from
  `pharmaverseadam` via `data-raw/bundle-demo.R`.
* pkgdown site scaffolded (light-mode, Bootstrap 5; `_pkgdown.yml`,
  `pkgdown/extra.scss`).
