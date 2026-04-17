# Healthcare Data Platform — Project Context

> Auto-loaded into every Cortex Code CLI session. Contains the non-negotiable rules, conventions, and phase state for this project. For full phase details, reference `@docs/healthcare-platform-execution-playbook.md`.

---

## Project Identity

HIPAA-compliant healthcare data platform on Snowflake, built via a strict 16-phase execution playbook. Phases execute in forward-only order — once a phase is complete, it is not revisited unless an intentional, documented amendment is made.

---

## Guiding Principles (enforce on every generated artifact)

1. **Objects before permissions** — Never generate a grant for an object that doesn't exist yet.
2. **Infrastructure before pipelines** — Warehouses, databases, schemas exist before any pipeline, policy, or CI/CD workflow targets them.
3. **Governance before AI** — Masking, tagging, RBAC must be complete before any AI layer is built.
4. **CI/CD from Phase 5 onward** — No manual object creation from Phase 6 forward. Every object deploys via GitHub Actions.
5. **Document last** — Runbooks reflect the final, verified state. Never document mid-build.
6. **Ownership stays with SYSADMIN** — Functional roles receive USAGE and operational grants, never ownership of objects. SYSADMIN owns all databases, schemas, warehouses, stages, file formats, and pipeline objects. No exceptions.

---

## Non-Negotiable Rules (check these on every code suggestion)

| Rule | Applies from |
|---|---|
| Never `SELECT *` in Dynamic Tables — always explicit column lists | Phase 6 |
| Always append `ALTER TASK <name> RESUME;` after any `CREATE TASK` | Phase 7 |
| Always include `WHEN SYSTEM$STREAM_HAS_DATA('<stream>')` on stream-driven tasks | Phase 7 |
| Never hardcode credentials — use `os.environ[]` or key-pair auth | Phase 5 onward |
| No unmasked PHI on Gold-layer views for non-privileged roles | Phase 9 |
| Always `LIMIT 10` test before full-table Cortex AI function runs | Phase 13–14 |
| Always use `AI_*` Cortex functions — deprecated names will break | Phase 13–14 |
| Use `$spec$` delimiter in Cortex Agent specs (not `$$`) | Phase 14 |
| `models` defined as an object, not an array | Phase 14 |
| `tool_resources` is a top-level key, not nested inside `tools` | Phase 14 |
| All objects deployed via CI/CD from Phase 6 onward — no manual creation | Phase 5 onward |
| Ownership of all objects remains with SYSADMIN — functional roles get USAGE only | All phases |

---

## Object Naming Conventions

### Databases — Environment-Level Isolation

CI/CD promotion happens at the database level. Each environment is a full, self-contained copy of the platform.

| Database | Purpose |
|---|---|
| `HEALTHCARE_DEV` | Development — engineers iterate here |
| `HEALTHCARE_QA` | Quality assurance — CI/CD validates here before prod promotion |
| `HEALTHCARE_PROD` | Production — business consumption, AI, analytics |
| `HEALTHCARE_AUDIT_DB` | Standalone — immutable audit log, environment-independent |

### Schemas (within each environment database)

Each environment database (`DEV`, `QA`, `PROD`) contains an identical schema structure:

| Schema | Layer | Purpose |
|---|---|---|
| `RAW` | Bronze | Raw landing tables, VARIANT columns, schema-flexible ingestion |
| `TRANSFORMED` | Silver | Cleansed, validated Dynamic Tables, conformed types |
| `ANALYTICS` | Gold | Business-ready fact/dimension tables, marts |
| `AI_READY` | Platinum | Semantic layer, curated views optimized for Cortex AI |
| `QUARANTINE` | — | Data contract violations, routed at ingest |

Fully qualified example: `HEALTHCARE_PROD.ANALYTICS.PATIENT_ENCOUNTERS`

### Warehouses — Dedicated per Workload

| Warehouse | Workload | Owned by |
|---|---|---|
| `INGESTION_WH` | Snowpipe, batch loads | SYSADMIN |
| `TRANSFORM_WH` | Silver/Gold Dynamic Table refreshes | SYSADMIN |
| `QUERY_WH` | Analyst/BI consumption | SYSADMIN |
| `AI_CORTEX_WH` | Cortex functions, agent workloads | SYSADMIN |
| `ADMIN_WH` | DDL, admin tasks | SYSADMIN |
| `CICD_WH` | GitHub Actions deployments | SYSADMIN |

---

## Role Architecture

### Custom Roles

| Role | Function |
|---|---|
| `DATA_ENGINEER_ROLE` | Pipeline development — ingestion, transformation, task management |
| `ANALYST_ROLE` | Read-only business consumption on ANALYTICS / AI_READY schemas |
| `DATA_STEWARD_ROLE` | Governance — classification, tagging, masking policy management |
| `AUDIT_ROLE` | Read access to HEALTHCARE_AUDIT_DB — no write, no modify |
| `PHI_ACCESS_ROLE` | Unmasked PHI access — break-glass tier, tightly controlled |
| `CICD_ROLE` | GitHub Actions service account — deploys objects across environments |

### Role Hierarchy

```
ACCOUNTADMIN  (break-glass only — max 2 accounts)
    │
SECURITYADMIN  (manages roles and grants; no data access)
    │
    ├── DATA_STEWARD_ROLE  (governance, tagging, masking policy creation)
    │
SYSADMIN  (owns ALL objects — databases, schemas, warehouses, pipes, tasks)
    │
    ├── CICD_ROLE  (deploys objects across DEV → QA → PROD; granted to SYSADMIN)
    │
    ├── DATA_ENGINEER_ROLE  (USAGE on ingestion/transform warehouses, CREATE on RAW/TRANSFORMED)
    │       │
    │       └── ANALYST_ROLE  (USAGE on QUERY_WH, SELECT on ANALYTICS/AI_READY)
    │
    ├── PHI_ACCESS_ROLE  (unmasked PHI; not inherited by any other role)
    │
    └── AUDIT_ROLE  (SELECT on HEALTHCARE_AUDIT_DB only)
```

### Ownership & Access Principles

1. **SYSADMIN owns everything.** Every database, schema, warehouse, stage, file format, Dynamic Table, Stream, Task, and pipe is owned by SYSADMIN. Functional roles never receive ownership.
2. **Functional roles get USAGE + operational grants.** Example: `DATA_ENGINEER_ROLE` gets `USAGE ON WAREHOUSE TRANSFORM_WH` and `CREATE DYNAMIC TABLE ON SCHEMA HEALTHCARE_PROD.TRANSFORMED` — but `TRANSFORM_WH` and the schema remain owned by SYSADMIN.
3. **CICD_ROLE is granted to SYSADMIN.** This allows the CI/CD pipeline to create and manage objects on SYSADMIN's behalf. The service account is assigned `CICD_ROLE`, which inherits into SYSADMIN.
4. **PHI_ACCESS_ROLE is isolated.** It does not inherit into any other role and is not inherited by any role. Access is granted on a per-user, break-glass basis.
5. **ACCOUNTADMIN is break-glass only.** Maximum two human accounts. Reviewed periodically via audit (Phase 11). No service account ever receives ACCOUNTADMIN.
6. **SECURITYADMIN manages the role hierarchy.** Role creation, grants of roles to roles, and grants of roles to users flow through SECURITYADMIN. SECURITYADMIN does not own data objects.

### Grant Patterns (use these templates when generating grants)

```sql
-- Warehouse access (USAGE, never ownership)
GRANT USAGE ON WAREHOUSE TRANSFORM_WH TO ROLE DATA_ENGINEER_ROLE;

-- Schema-level operational grants
GRANT USAGE ON DATABASE HEALTHCARE_PROD TO ROLE DATA_ENGINEER_ROLE;
GRANT USAGE ON SCHEMA HEALTHCARE_PROD.TRANSFORMED TO ROLE DATA_ENGINEER_ROLE;
GRANT CREATE DYNAMIC TABLE ON SCHEMA HEALTHCARE_PROD.TRANSFORMED TO ROLE DATA_ENGINEER_ROLE;

-- Read-only pattern for analysts
GRANT USAGE ON DATABASE HEALTHCARE_PROD TO ROLE ANALYST_ROLE;
GRANT USAGE ON SCHEMA HEALTHCARE_PROD.ANALYTICS TO ROLE ANALYST_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA HEALTHCARE_PROD.ANALYTICS TO ROLE ANALYST_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HEALTHCARE_PROD.ANALYTICS TO ROLE ANALYST_ROLE;

-- Hierarchy: lower roles granted to higher roles
GRANT ROLE ANALYST_ROLE TO ROLE DATA_ENGINEER_ROLE;
GRANT ROLE CICD_ROLE TO ROLE SYSADMIN;
GRANT ROLE DATA_STEWARD_ROLE TO ROLE SECURITYADMIN;
```

---

## Phase Dependency Chain (strict forward order)

```
0 Account Admin → 1 DB Structure → 2 Warehouses → 3 RBAC Setup
  → 4 Resource Monitors → 5 GitHub + CI/CD → 6 Medallion
    → 7 Ingestion → 8 Governance (create masking policies)
      → 9 RBAC Masking Assignment → 10 Monitoring → 11 Audit
        → 12 Verification → 13 AI-Ready Layer
          → 14 Cortex Agents & Intelligence
            → 15 Phase-wise Docs → 16 Complete Docs
```

**Rule:** If asked to generate code for a phase whose dependencies aren't met, stop and flag it. Do not proceed.

---

## Current Phase

<!-- UPDATE THIS LINE AS YOU PROGRESS -->
**Currently working on:** Phase 0 — Account Administration

---

## Available Project Skills

Invoke with `$<skill-name>` during a CLI session:

- `$phase-0-account-admin` — account-level config, SSO, network policies
- `$phase-1-database-structure` — databases, schemas, stages, file formats
- `$phase-2-warehouse-provisioning` — warehouse creation with auto-suspend
- `$phase-3-rbac-setup` — roles, hierarchy, grants, user assignment
- `$phase-4-resource-monitors` — credit budgets and suspension policies
- `$phase-5-github-cicd` — repo + GitHub Actions pipeline
- `$phase-6-medallion` — Bronze/Silver/Gold/Platinum Dynamic Tables
- `$phase-7-ingestion` — Snowpipe, Streams, Tasks
- `$phase-8-governance` — PHI tagging + masking policy creation
- `$phase-9-masking-assignment` — attach masking policies to columns
- `$phase-10-monitoring` — task/DT/stream/warehouse alerting
- `$phase-11-audit` — immutable audit log + share audit
- `$phase-12-verification` — end-to-end platform validation
- `$phase-13-ai-ready-layer` — semantic layer + curated Platinum views
- `$phase-14-cortex-agents` — agent specs + Snowflake Intelligence
- `$phase-15-phase-docs` — per-phase runbooks
- `$phase-16-complete-docs` — architecture + HIPAA compliance pack

---

## Behavioral Defaults

- **Plan before executing.** For any DDL/DML or schema change, summarize the plan and wait for confirmation.
- **Fully qualified names always.** Use `DATABASE.SCHEMA.OBJECT` — never rely on current session context.
- **Least privilege by default.** When generating grants, grant only what the role needs for its function.
- **Ownership to SYSADMIN always.** Never generate `GRANT OWNERSHIP` to a functional role. If an object is accidentally owned by the wrong role, flag it immediately.
- **Environment awareness.** Always ask which environment (DEV / QA / PROD) before generating DDL. Never default to PROD.
- **Flag deviations explicitly.** If the user asks for something that violates a Non-Negotiable Rule, flag it before generating — do not silently comply.
- **Reference, don't duplicate.** For detailed phase steps, pull in `@docs/healthcare-platform-execution-playbook.md` rather than restating.