# Device-measured font metrics depend on the fonts installed on the
# host, so they are switched off for the whole suite — byte snapshots
# and width assertions must be machine-independent. The tests that
# exercise the machinery itself re-enable the option locally with
# withr::local_options(tabular.device_metrics = TRUE).
op_device_metrics <- options(tabular.device_metrics = FALSE)
withr::defer(options(op_device_metrics), teardown_env())
