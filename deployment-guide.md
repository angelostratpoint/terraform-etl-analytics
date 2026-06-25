# CDCU Deployment Handoff Guide

## Purpose

This document is the executive deployment handoff reference for the BPI-MS
Customer Data Clean-Up (CDCU) Terraform repository. It ties together the
detailed technical documents in this repository and provides a single starting
point for deployment reviewers, implementers, and approvers.

The detailed deployment and validation procedures remain in the files under
`docs/`. This document exists to make the full documentation set easier to
navigate during SIT, UAT, and production review.

## Documentation Set

Use the following documents together as the controlled CDCU deployment
documentation set:

| Document | Purpose |
|---|---|
| `README.md` | Repository overview, scope, structure, and deployment-document map |
| `docs/bootstrap-guide.md` | One-time Terraform backend bootstrap and verification |
| `docs/deployment-guide.md` | Environment deployment prerequisites, inputs, and Terraform execution sequence |
| `docs/iam-service-role-reference.md` | IAM groups, runtime roles, PassRole boundaries, and validation approach |
| `docs/runtime-connectivity-validation.md` | Runtime connectivity, control-plane validation, and smoke-test procedures |
| `docs/terraform-vpc-production-readiness.md` | Architecture, ownership boundary, `vpc-assessment.yaml`, and production-readiness checklist |

## Deployment Coverage

The document set supports the controlled deployment of the CDCU Terraform-owned
application layer:

```text
MySQL RDS sources -> AWS Glue -> S3 -> SageMaker -> Athena -> QuickSight
```

The documentation also defines the boundary between:

- BPI-MS owned baseline infrastructure and governance controls; and
- CDCU Terraform-managed application resources and operational validation.

## Recommended Review Order

For technical review and deployment planning, use the following reading order:

1. `README.md`
2. `docs/terraform-vpc-production-readiness.md`
3. `docs/deployment-guide.md`
4. `docs/iam-service-role-reference.md`
5. `docs/runtime-connectivity-validation.md`
6. `docs/bootstrap-guide.md`

This sequence helps reviewers understand the architecture first, then the
deployment steps, then the access model, runtime checks, and backend setup.

## Environment Deployment Summary

The approved operating model uses separate environment roots:

| Environment | Terraform root |
|---|---|
| SIT | `environments/sit` |
| UAT | `environments/uat` |
| Prod | `environments/prod` |

Each environment follows the same high-level sequence:

1. Confirm the approved BPI-MS baseline inputs.
2. Deploy or verify `vpc-assessment.yaml`, when used.
3. Deploy or verify `cdcu-access.yaml` for human access.
4. Bootstrap or verify the Terraform backend.
5. Populate environment-specific `terraform.tfvars`.
6. Run `terraform init`, `terraform validate`, `terraform plan`, and
   `terraform apply`.
7. Perform post-deployment validation for IAM, Glue, Athena, SageMaker,
   QuickSight, and runtime connectivity as applicable.

## Current Architecture Position

The current deployment architecture allows incremental refinement and
operational stabilization without requiring major infrastructure redesign or
environment rebuild activities.

This means:

- SIT and UAT can continue to be refined through controlled IAM, runtime,
  package, and sizing updates;
- production preparation can proceed through documented validation and approval
  gates rather than by rebuilding the environment model; and
- operational issues discovered during lower-environment support can be
  resolved within the current Terraform and CloudFormation structure.

## Review and Approval Record

Reviewed by: Lester Gamier

Approved by: Charwin Dale L. Chua

Approved by: Emmanuel H Tolentino

Approved by: Aubrey S. Macaspac

## Notes

- This document is a handoff/index document and does not replace the detailed
  procedures in `docs/`.
- If any detailed technical procedure changes, the corresponding source
  document under `docs/` should be updated first, then this handoff guide
  should be aligned if necessary.
