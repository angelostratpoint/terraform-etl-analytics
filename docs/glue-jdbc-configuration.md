# CDCU Glue JDBC Connection Configuration

This document covers the Glue JDBC connection setup for the two MySQL RDS source databases
used in the CDCU pipeline. The JDBC URLs are required inputs from BPI MS before
`terraform apply` can run against the BPI MS environment.

---

## Overview

The CDCU Glue module provisions two JDBC connections:

| Connection Name | Source Database | Secret Name |
|---|---|---|
| `cdcu-{env}-microsite-mysql` | Microsite MySQL RDS | `cdcu/{env}/microsite-mysql-connection` |
| `cdcu-{env}-legacy-mysql` | Legacy MySQL RDS | `cdcu/{env}/legacy-mysql-connection` |

Terraform provisions the connection resource and references the Secrets Manager secret name.
The actual database credentials (`host`, `port`, `dbname`, `username`, `password`) are stored
in Secrets Manager by BPI MS — Terraform does not read or store credential values.

---

## Required Inputs from BPI MS

Before running `terraform apply` in the BPI MS environment, BPI MS must provide the
JDBC URL for each MySQL RDS source database.

| Variable | Description | Example Format |
|---|---|---|
| `microsite_jdbc_url` | JDBC URL for the Microsite MySQL RDS | `jdbc:mysql://<host>:<port>/<dbname>` |
| `legacy_jdbc_url` | JDBC URL for the Legacy MySQL RDS | `jdbc:mysql://<host>:<port>/<dbname>` |

These go into `terraform.tfvars` (never committed to source control):

```hcl
microsite_jdbc_url = "jdbc:mysql://microsite-rds.xxxxxxxxxx.ap-southeast-1.rds.amazonaws.com:3306/microsite_db"
legacy_jdbc_url    = "jdbc:mysql://legacy-rds.xxxxxxxxxx.ap-southeast-1.rds.amazonaws.com:3306/legacy_db"
```

---

## Current Test Account Status

The test account (Stratpoint-owned, not BPI MS) uses placeholder JDBC URLs since the
BPI MS RDS instances are not accessible from this account:

```hcl
# TODO: Replace with actual BPI MS RDS endpoints before applying to BPI MS environment.
# These are placeholder values for test account use only.
# BPI MS must provide the real JDBC URLs from their MySQL RDS instances.
microsite_jdbc_url = "jdbc:mysql://placeholder.rds.amazonaws.com:3306/cdcu"
legacy_jdbc_url    = "jdbc:mysql://placeholder.rds.amazonaws.com:3306/cdcu"
```

The Glue connection resources are provisioned with these placeholders. The connections
will not be able to reach any database until the real BPI MS RDS endpoints are provided
and `terraform apply` is re-run.

---

## Validation

The `microsite_jdbc_url` and `legacy_jdbc_url` variables have built-in validation:

- Must start with `jdbc:mysql://`
- Must not contain `localhost` — prevents accidental use of test placeholders in BPI MS environment

If an invalid value is provided, `terraform plan` will fail with:

```
Error: Invalid value for variable
  microsite_jdbc_url must be a non-local MySQL JDBC URL from BPI MS.
```

---

## How Credentials Are Resolved at Runtime

The JDBC URL only contains the host, port, and database name — not the username or password.
Glue resolves credentials at job runtime from Secrets Manager using the `SECRET_ID`
connection property:

```
cdcu/{env}/microsite-mysql-connection
cdcu/{env}/legacy-mysql-connection
```

BPI MS owns and populates these secrets. The expected secret format is:

```json
{
  "host": "<rds-endpoint>",
  "port": "3306",
  "dbname": "<database-name>",
  "username": "<db-username>",
  "password": "<db-password>"
}
```

Terraform grants `secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret`
to the `ST-CDCU-{env}-GlueExecutionRole` scoped to `cdcu/{env}/*` secrets only.

---

## Steps When BPI MS Provides RDS Endpoints

1. Obtain the JDBC URLs from BPI MS Cloud Engineer
2. Update `terraform.tfvars` in the target environment:
   ```hcl
   microsite_jdbc_url = "jdbc:mysql://<actual-host>:3306/<actual-db>"
   legacy_jdbc_url    = "jdbc:mysql://<actual-host>:3306/<actual-db>"
   ```
3. Confirm Secrets Manager secrets are populated by BPI MS
4. Confirm the Glue subnet has a route to the RDS security group
5. Run plan and apply:
   ```powershell
   terraform plan -var-file="terraform.tfvars" -out=tfplan
   terraform apply tfplan
   ```
6. Test the connection by running the extraction job:
   ```powershell
   aws glue start-job-run `
     --job-name "cdcu-pre-prod-microsite-raw-extraction" `
     --region ap-southeast-1
   ```

---

## Network Prerequisites

For Glue to reach the RDS instances, BPI MS must confirm:

| Requirement | Details |
|---|---|
| RDS security group inbound rule | Allow port `3306` from the Glue security group (`sg-0a8de74edb2553215` in pre-prod) |
| S3 Gateway VPC endpoint | Must be associated with the route table used by the Glue subnet |
| Glue subnet route | Must have a route to the RDS subnet |

These are network-level prerequisites outside Terraform scope — owned and managed by BPI MS.
See `docs/errors-and-resolutions.md` Error 19 and Error 20 for related VPC issues encountered
during pre-prod testing.
