---
name: phase-1-database-structure
description: Create environment databases (DEV/QA/PROD), standalone audit database, schemas, stages, and file formats under SYSADMIN. Object creation only — no grants yet.
tools:
  - snowflake_sql_execute
---

# Phase 1 — Database Structure

## When to invoke
Phase 0 is complete. User needs the foundational object skeleton before warehouses and RBAC.

## Dependencies
Phase 0 complete (account-level controls in place).

## What to generate

### 1. Databases — Environment-Level Isolation

CI/CD promotion happens at the database level. Each environment is a full, self-contained copy of the platform.

```sql
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS HEALTHCARE_DEV
  COMMENT = 'Development environment — engineers iterate here';

CREATE DATABASE IF NOT EXISTS HEALTHCARE_QA
  COMMENT = 'Quality assurance — CI/CD validates here before prod promotion';

CREATE DATABASE IF NOT EXISTS HEALTHCARE_PROD
  COMMENT = 'Production — business consumption, AI, analytics';

CREATE DATABASE IF NOT EXISTS HEALTHCARE_AUDIT_DB
  COMMENT = 'Standalone immutable audit log — environment-independent';
```

### 2. Schemas — Identical Structure in Each Environment Database

Create the following schemas inside `HEALTHCARE_DEV`, `HEALTHCARE_QA`, and `HEALTHCARE_PROD`:

| Schema | Layer | Purpose |
|---|---|---|
| `RAW` | Bronze | Raw landing tables, VARIANT columns, schema-flexible ingestion |
| `TRANSFORMED` | Silver | Cleansed, validated Dynamic Tables, conformed types |
| `ANALYTICS` | Gold | Business-ready fact/dimension tables, marts |
| `AI_READY` | Platinum | Semantic layer, curated views optimized for Cortex AI |
| `QUARANTINE` | — | Data contract violations, routed at ingest |

```sql
-- Repeat for each environment: HEALTHCARE_DEV, HEALTHCARE_QA, HEALTHCARE_PROD
CREATE SCHEMA IF NOT EXISTS <ENV_DB>.RAW
  COMMENT = 'Bronze — raw landing tables';
CREATE SCHEMA IF NOT EXISTS <ENV_DB>.TRANSFORMED
  COMMENT = 'Silver — cleansed, validated Dynamic Tables';
CREATE SCHEMA IF NOT EXISTS <ENV_DB>.ANALYTICS
  COMMENT = 'Gold — business-ready fact/dimension tables';
CREATE SCHEMA IF NOT EXISTS <ENV_DB>.AI_READY
  COMMENT = 'Platinum — semantic layer, AI-optimized views';
CREATE SCHEMA IF NOT EXISTS <ENV_DB>.QUARANTINE
  COMMENT = 'Data contract violations routed at ingest';
```

For `HEALTHCARE_AUDIT_DB`, create only:

```sql
CREATE SCHEMA IF NOT EXISTS HEALTHCARE_AUDIT_DB.AUDIT
  COMMENT = 'Immutable audit event capture — append-only';
```

### 3. Stages — Internal and External

- Created under `SYSADMIN` ownership
- Placed in the `RAW` schema of each environment database (ingestion landing zone)
- External stages point to cloud storage (S3/GCS/Azure Blob)

### 4. File Formats

- Created under `SYSADMIN` ownership
- Placed in the `RAW` schema of each environment database
- Define formats for expected source types (CSV, JSON, Parquet, etc.)

## Non-negotiable rules

- **All objects owned by SYSADMIN.** Use `USE ROLE SYSADMIN;` before every DDL statement.
- **No grants in this phase.** Object creation only. Grants happen in Phase 3.
- **Identical schema structure across all three environment databases.** DEV, QA, and PROD must be structurally identical — CI/CD promotes code, not structure.
- Use fully qualified names in every DDL statement (e.g., `HEALTHCARE_DEV.RAW`, never just `RAW`).
- Apply consistent naming conventions across all objects.

## Why stages and file formats are created here
They are structural objects that pipelines and ingestion tasks depend on. Creating them under `SYSADMIN` now means grants can be precisely defined in Phase 3.

## Why HEALTHCARE_AUDIT_DB is standalone
Audit logs must be immutable and environment-independent. A single audit database prevents dev/QA activity from mixing with prod audit trails while keeping a unified compliance view.

## Exit criteria (confirm before moving to Phase 2)

- [ ] `HEALTHCARE_DEV`, `HEALTHCARE_QA`, `HEALTHCARE_PROD` databases exist
- [ ] `HEALTHCARE_AUDIT_DB` exists as standalone database
- [ ] Each environment database contains: `RAW`, `TRANSFORMED`, `ANALYTICS`, `AI_READY`, `QUARANTINE` schemas
- [ ] `HEALTHCARE_AUDIT_DB` contains `AUDIT` schema
- [ ] All stages and file formats exist under SYSADMIN ownership in `RAW` schemas
- [ ] All objects fully qualified and owned by SYSADMIN
- [ ] No grants have been made yet

## Flag if
- User asks to create warehouses — that's Phase 2.
- User asks to grant access — that's Phase 3.
- User asks to create pipeline objects (streams, tasks, pipes) — Phase 6/7.
- Schema structure differs between DEV, QA, and PROD — reject and enforce identical structure.