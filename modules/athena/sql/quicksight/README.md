# QuickSight Athena Setup Saved Queries

Source: DE-supplied `cdcu partitions and views.docx`. The 9 partition projection statements and 16 view statements retain the supplied SQL and business labels. Only the SIT bucket path is replaced by the configured environment bucket. Terraform template escaping preserves Athena's literal `${run_date}` and `${extraction_date}` placeholders.

UAT enables this feature; SIT and PROD remain disabled by default. Terraform creates saved queries only. It does not execute SQL, copy source data, or import QuickSight assets.

## Deployment

Include the entire `modules/athena/sql/quicksight/` directory, `modules/athena/quicksight_saved_queries.tf`, `modules/athena/variables.tf`, `modules/athena/outputs.tf`, `environments/uat/main.tf`, and `environments/uat/outputs.tf` in the approved repository update. Do not upload only the new `.tf` file: it reads the SQL templates at plan time.

In the approved UAT checkout, using the environment-owned backend and inputs:

```bash
cd environments/uat
terraform init
terraform validate
terraform plan -out=uat-quicksight.tfplan
# Review and approve the complete plan before executing it.
terraform apply uat-quicksight.tfplan
terraform output quicksight_setup_queries
```

The plan can include other pending repository/environment changes. Do not assume it contains only these 29 saved queries. Apply only the reviewed and approved plan. Do not change or replace the environment-owned `terraform.tfvars`.

## Sir Archie's Run Order

1. Open Athena in Singapore (`ap-southeast-1`). Select data source `AwsDataCatalog`, database `cdcu_uat_catalog`, and workgroup **`cdcu-uat-workgroup`** (hyphens, not underscores).
2. Confirm the extraction/matching jobs and required crawler/schema updates have completed. All 9 source tables must already exist. These queries do not create missing base tables or fix missing columns.
3. In **Saved queries**, filter names beginning `cdcu-uat-qs-`. Open and run **one saved query at a time** in the order below. Wait for `SUCCEEDED` before the next query; stop on any failure.

| Steps | Action | Acceptance |
| --- | --- | --- |
| `00`, `01` | Capture source counts by partition and inspect source columns. | Save the count baseline. DE confirms the required columns, table locations, partition keys and formats match the supplied SQL. |
| `10` through `18` | Apply projection to `merged`, then the 8 matching tables. | Each ALTER succeeds. Actual folders use `extraction_date=yyyy-MM-dd` for merged and `run_date=yyyy-MM-dd` for matching. |
| `20` through `35` | Create/replace all 16 views in dependency order. | Each CREATE succeeds. Do not skip the foundation views even if QuickSight does not directly import them. |
| `90` | Repeat the source counts query. | Counts for the baseline partitions match step `00`, with no pipeline changes during comparison. Investigate differences before continuing. |
| `91` | Query `vw_record_reconciliation` for the latest dates. | DE/QA validates reconciliation results against expected output. An empty result is not proof of successful data validation. |

The 16 views in order are `vw_all_pairs`, `vw_exec_summary`, `vw_classification_breakdown`, `vw_std_success_by_field`, `vw_manual_review_reasons`, `vw_ingestion_summary`, `vw_source_comparison`, `vw_field_score_analysis`, `vw_score_distribution`, `vw_dq_issue_detail`, `vw_field_score_unpivoted`, `vw_contract_type_exposure`, `vw_unique_bestpair_summary`, `vw_unique_bestpair_scoredist`, `vw_unique_bestpair_detail`, and `vw_record_reconciliation`.

The two existing legacy saved queries (`validate-merged-count`, `matching-summary`) are not part of this setup sequence. `vw_monthly_trend` and `vw_cluster_analysis` are not in the supplied attachment and are not added here.

## Preconditions and Controls

- The approved operator needs Athena execution and result-bucket access plus the appropriate Glue/Lake Formation permissions for table-property updates and view creation. QuickSight Reader access alone is not sufficient.
- DE must validate contract-type, field-score JSON and best-pair columns against the current UAT schema. Step `01` displays column metadata; it does not automatically certify compatibility.
- Check the actual table LOCATION and partition layout before enabling projection. The projection range is retained from the source: `2026-01-01,NOW+1DAYS`. Data outside it is not covered.
- Coordinate subsequent Glue crawls: a crawler may overwrite table properties. This change does not disable crawlers or change partition registration. Check that projection remains correct after any crawl.
- Count queries scan source tables and incur Athena query costs. The existing workgroup scan limit still applies; use an approved date-filtered check if the full scan exceeds it.
- ALTER statements change catalog properties; CREATE OR REPLACE VIEW replaces any existing view definitions. Before execution, retain the current table properties/view definitions if rollback is required. Terraform removal of a saved query does not undo executed SQL.
- After successful Athena validation, proceed with the QuickSight import using UAT data-source/workgroup overrides and target-account permissions. This source SQL is not a CSV/S3-manifest configuration and does not transfer SIT data into UAT.

## Local Verification

`modules/athena/tests/quicksight_saved_queries.tftest.hcl` uses a mock AWS provider. It checks disabled-by-default behavior, the 29-query inventory and run order, UAT bindings, configurable bucket substitution, literal Athena partition placeholders, identical before/after counts, and rejection of a missing bucket. These tests do not execute SQL against Athena or validate live data.

## References

- [Athena saved query execution](https://docs.aws.amazon.com/athena/latest/ug/saved-queries-run.html)
- [CreateNamedQuery API](https://docs.aws.amazon.com/athena/latest/APIReference/API_CreateNamedQuery.html)
- [Athena partition projection](https://docs.aws.amazon.com/athena/latest/ug/partition-projection.html)
