mock_provider "aws" {}

variables {
  environment           = "uat"
  athena_results_bucket = "cdcu-uat-athena-results"
  glue_catalog_database = "cdcu_uat_catalog"
}

run "disabled_by_default" {
  command = plan

  assert {
    condition     = length(aws_athena_named_query.quicksight_setup) == 0 && length(output.quicksight_setup_queries) == 0
    error_message = "Existing environments must not gain QuickSight setup queries unless explicitly enabled."
  }
}

run "enabled_uat" {
  command = plan

  variables {
    enable_quicksight_setup_queries = true
    quicksight_data_lake_bucket     = "cdcu-uat-data-lake"
  }

  assert {
    condition     = length(aws_athena_named_query.quicksight_setup) == 29
    error_message = "Expected 9 projections, 16 views, and 4 precheck/validation queries."
  }

  assert {
    condition = alltrue([
      for filename, query in aws_athena_named_query.quicksight_setup :
      query.database == "cdcu_uat_catalog" && query.workgroup == "cdcu-uat-workgroup" &&
      query.name == "cdcu-uat-qs-${trimsuffix(filename, ".sql.tftpl")}" &&
      !strcontains(query.query, "bpims-cdcu-sit-data-lake") &&
      !strcontains(query.query, "$${data_lake_bucket}")
    ])
    error_message = "Saved queries must target UAT and must not retain SIT paths or unresolved bucket variables."
  }

  assert {
    condition = alltrue([
      for filename, query in aws_athena_named_query.quicksight_setup :
      strcontains(query.query, "s3://cdcu-uat-data-lake/") &&
      strcontains(query.query, filename == "10-projection-merged.sql.tftpl" ? "$${extraction_date}" : "$${run_date}")
      if strcontains(filename, "-projection-")
    ])
    error_message = "Projection paths must use the configured bucket and retain literal Athena partition placeholders."
  }

  assert {
    condition = (
      aws_athena_named_query.quicksight_setup["00-precheck-source-counts.sql.tftpl"].query ==
      aws_athena_named_query.quicksight_setup["90-validate-source-counts.sql.tftpl"].query
    )
    error_message = "Before/after source counts must use the same query."
  }

  assert {
    condition = (
      output.quicksight_setup_queries[0].step == "00" &&
      output.quicksight_setup_queries[28].step == "91" &&
      [for query in output.quicksight_setup_queries : query.step] ==
      ["00", "01", "10", "11", "12", "13", "14", "15", "16", "17", "18", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "90", "91"]
    )
    error_message = "The operator output must preserve numeric execution order."
  }
}

run "configured_bucket_not_hardcoded" {
  command = plan

  variables {
    enable_quicksight_setup_queries = true
    quicksight_data_lake_bucket     = "approved-uat-data-lake"
  }

  assert {
    condition = alltrue([
      for filename, query in aws_athena_named_query.quicksight_setup :
      strcontains(query.query, "s3://approved-uat-data-lake/") && !strcontains(query.query, "s3://cdcu-uat-data-lake/")
      if strcontains(filename, "-projection-")
    ])
    error_message = "Every projection must follow the actual configured bucket name."
  }
}

run "enabled_requires_bucket" {
  command = plan

  variables {
    enable_quicksight_setup_queries = true
    quicksight_data_lake_bucket     = ""
  }

  expect_failures = [aws_athena_named_query.quicksight_setup]
}
