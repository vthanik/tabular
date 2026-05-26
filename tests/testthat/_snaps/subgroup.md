# subgroup() unknown-var error message names the bad column

    Code
      subgroup(tabular(saf_demo), "not_a_column")
    Condition
      Error:
      ! `by` references column not present in .spec@data: "not_a_column".
      i Available columns: "variable", "stat_label", "placebo", "drug_100", "drug_50", and "Total".

# subgroup() template-unknown-col error message names the bad ref

    Code
      subgroup(tabular(saf_demo), "variable", label = "Cohort: {nonexistent}")
    Condition
      Error:
      ! `label` references column not in .spec@data: "nonexistent".
      i Available columns: "variable", "stat_label", "placebo", "drug_100", "drug_50", and "Total".

