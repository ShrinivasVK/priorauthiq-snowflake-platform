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

## File Creation Rules
- Directory structure is pre-created. Never create, rename, or delete folders.
- Create files only at the exact path specified in the prompt.
- If a path's parent folder does not exist, stop and ask — do not create it.

---

## Naming Convention
- [define once, e.g. `NN_snake_case_description.sql`]

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
| `PA_DATA_ENGINEER_ROLE` | Pipeline development — ingestion, transformation, task management |
| `PA_ANALYST_ROLE` | Read-only business consumption on ANALYTICS schema |
| `PA_AI_ENGINEER_ROLE` | Cortex AI — builds AI pipelines, semantic views, agent specs |
| `PA_DATA_STEWARD_ROLE` | Governance — classification, tagging, masking policy management |
| `PA_AUDIT_ROLE` | Read access to audit DB — no write, no modify |
| `PA_PHI_ACCESS_ROLE` | Unmasked PHI access — break-glass tier, tightly controlled |
| `PA_CICD_ROLE` | GitHub Actions service account — deploys objects across environments |

### Role Hierarchy

```
ACCOUNTADMIN  (break-glass only — max 2 accounts)
    │
SECURITYADMIN  (manages roles and grants; no data access)
    │
    ├── PA_DATA_STEWARD_ROLE  (governance, tagging, masking policy creation)
    │
SYSADMIN  (owns ALL objects — databases, schemas, warehouses, pipes, tasks)
    │
    ├── PA_CICD_ROLE  (deploys objects across DEV → QA → PROD; granted to SYSADMIN)
    │
    ├── PA_DATA_ENGINEER_ROLE  (USAGE on ingestion/transform WHs, CREATE on RAW/CURATED/AI)
    │       │
    │       └── PA_ANALYST_ROLE  (USAGE on QUERY_WH, SELECT on ANALYTICS)
    │
    ├── PA_AI_ENGINEER_ROLE  (USAGE on AI_CORTEX_WH, CREATE on AI schema)
    │       │
    │       └── PA_ANALYST_ROLE  (inherited — read access on ANALYTICS)
    │
    ├── PA_PHI_ACCESS_ROLE  (unmasked PHI; not inherited by any other role)
    │
    └── PA_AUDIT_ROLE  (SELECT on audit DB only — grants deferred to Phase 11)
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
GRANT USAGE ON WAREHOUSE PA_TRANSFORM_WH TO ROLE PA_DATA_ENGINEER_ROLE;

-- Schema-level operational grants
GRANT USAGE ON DATABASE PA_PROD_DB TO ROLE PA_DATA_ENGINEER_ROLE;
GRANT USAGE ON SCHEMA PA_PROD_DB.CURATED TO ROLE PA_DATA_ENGINEER_ROLE;
GRANT CREATE DYNAMIC TABLE ON SCHEMA PA_PROD_DB.CURATED TO ROLE PA_DATA_ENGINEER_ROLE;

-- Read-only pattern for analysts
GRANT USAGE ON DATABASE PA_PROD_DB TO ROLE PA_ANALYST_ROLE;
GRANT USAGE ON SCHEMA PA_PROD_DB.ANALYTICS TO ROLE PA_ANALYST_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA PA_PROD_DB.ANALYTICS TO ROLE PA_ANALYST_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA PA_PROD_DB.ANALYTICS TO ROLE PA_ANALYST_ROLE;

-- AI Engineer pattern
GRANT USAGE ON WAREHOUSE PA_AI_CORTEX_WH TO ROLE PA_AI_ENGINEER_ROLE;
GRANT USAGE ON SCHEMA PA_PROD_DB.AI TO ROLE PA_AI_ENGINEER_ROLE;
GRANT CREATE TABLE ON SCHEMA PA_PROD_DB.AI TO ROLE PA_AI_ENGINEER_ROLE;

-- Hierarchy: lower roles granted to higher roles
GRANT ROLE PA_ANALYST_ROLE TO ROLE PA_DATA_ENGINEER_ROLE;
GRANT ROLE PA_ANALYST_ROLE TO ROLE PA_AI_ENGINEER_ROLE;
GRANT ROLE PA_CICD_ROLE TO ROLE SYSADMIN;
GRANT ROLE PA_DATA_STEWARD_ROLE TO ROLE SECURITYADMIN;
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
**Currently working on:** Phase 4 — Resource Monitors

---

## Available Project Skills

Invoke with `$<skill-name>` during a CLI session:

- `$phase-0-account-admin` — account-level config, SSO, network policies ([`.cortex\skills\phase-0-account-admin\SKILL.md`](.cortex\skills\phase-0-account-admin\SKILL.md))
- `$phase-1-database-structure` — databases, schemas, stages, file formats ([`.cortex\skills\phase-1-database-structure\SKILL.md`](.cortex\skills\phase-1-database-structure\SKILL.md))
- `$phase-2-warehouse-provisioning` — warehouse creation with auto-suspend ([`.cortex\skills\phase-2-warehouse-provisioning\SKILL.md`](.cortex\skills\phase-2-warehouse-provisioning\SKILL.md))
- `$phase-3-rbac-setup` — roles, hierarchy, grants, user assignment ([`.cortex\skills\phase-3-rbac-setup\SKILL.md`](.cortex\skills\phase-3-rbac-setup\SKILL.md))
- `$phase-4-resource-monitors` — credit budgets and suspension policies ([`.cortex\skills\phase-4-resource-monitors\SKILL.md`](.cortex\skills\phase-4-resource-monitors\SKILL.md))
- `$phase-5-github-cicd` — repo + GitHub Actions pipeline ([`.cortex\skills\phase-5-github-cicd\SKILL.md`](.cortex\skills\phase-5-github-cicd\SKILL.md))
- `$phase-6-medallion` — Bronze/Silver/Gold/Platinum Dynamic Tables ([`.cortex\skills\phase-6-medallion\SKILL.md`](.cortex\skills\phase-6-medallion\SKILL.md))
- `$phase-7-ingestion` — Snowpipe, Streams, Tasks ([`.cortex\skills\phase-7-ingestion\SKILL.md`](.cortex\skills\phase-7-ingestion\SKILL.md))
- `$phase-8-governance` — PHI tagging + masking policy creation ([`.cortex\skills\phase-8-governance\SKILL.md`](.cortex\skills\phase-8-governance\SKILL.md))
- `$phase-9-masking-assignment` — attach masking policies to columns ([`.cortex\skills\phase-9-masking-assignment\SKILL.md`](.cortex\skills\phase-9-masking-assignment\SKILL.md))
- `$phase-10-monitoring` — task/DT/stream/warehouse alerting ([`.cortex\skills\phase-10-monitoring\SKILL.md`](.cortex\skills\phase-10-monitoring\SKILL.md))
- `$phase-11-audit` — immutable audit log + share audit ([`.cortex\skills\phase-11-audit\SKILL.md`](.cortex\skills\phase-11-audit\SKILL.md))
- `$phase-12-verification` — end-to-end platform validation ([`.cortex\skills\phase-12-verification\SKILL.md`](.cortex\skills\phase-12-verification\SKILL.md))
- `$phase-13-ai-ready-layer` — semantic layer + curated Platinum views ([`.cortex\skills\phase-13-ai-ready-layer\SKILL.md`](.cortex\skills\phase-13-ai-ready-layer\SKILL.md))
- `$phase-14-cortex-agents` — agent specs + Snowflake Intelligence ([`.cortex\skills\phase-14-cortex-agents\SKILL.md`](.cortex\skills\phase-14-cortex-agents\SKILL.md))
- `$phase-15-phase-docs` — per-phase runbooks ([`.cortex\skills\phase-15-phase-docs\SKILL.md`](.cortex\skills\phase-15-phase-docs\SKILL.md))
- `$phase-16-complete-docs` — architecture + HIPAA compliance pack ([`.cortex\skills\phase-16-complete-docs\SKILL.md`](.cortex\skills\phase-16-complete-docs\SKILL.md))

---

## Behavioral Defaults

- **Plan before executing.** For any DDL/DML or schema change, summarize the plan and wait for confirmation.
- **Fully qualified names always.** Use `DATABASE.SCHEMA.OBJECT` — never rely on current session context.
- **Least privilege by default.** When generating grants, grant only what the role needs for its function.
- **Ownership to SYSADMIN always.** Never generate `GRANT OWNERSHIP` to a functional role. If an object is accidentally owned by the wrong role, flag it immediately.
- **Environment awareness.** Always ask which environment (DEV / QA / PROD) before generating DDL. Never default to PROD.
- **Flag deviations explicitly.** If the user asks for something that violates a Non-Negotiable Rule, flag it before generating — do not silently comply.
- **Reference, don't duplicate.** For detailed phase steps, pull in `@docs/healthcare-platform-execution-playbook.md` rather than restating.