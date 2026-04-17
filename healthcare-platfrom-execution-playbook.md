# Healthcare Data Platform — Team Execution Playbook

> **Purpose:** This is the authoritative sequence every team member follows when building the healthcare data platform on Snowflake. Each phase is designed so that once completed, you do not revisit it unless an intentional change is required. All dependencies flow forward — never backward.

---

## Guiding Principles

- **Objects before permissions** — You cannot grant access to something that does not exist.
- **Infrastructure before pipelines** — Warehouses, databases, and schemas must exist before any pipeline, governance policy, or CI/CD workflow targets them.
- **Governance before AI** — Masking policies, tagging, and RBAC must be fully in place before AI layers are built on top of data.
- **CI/CD from day one** — Every phase from Phase 2 onward deploys through the GitHub Actions pipeline, not manually.
- **Document last** — Documentation reflects the final, stable, verified state. Never document mid-build.

---

## Phase Overview

| Phase | Name | Components |
|---|---|---|
| **0** | Account Administration | Account settings, SSO, network policies |
| **1** | Database Structure | Databases, Schemas, Stages, File Formats |
| **2** | Warehouse Provisioning | Warehouses (dedicated step) |
| **3** | RBAC Setup | Roles, grants, masking policy assignments |
| **4** | Resource Monitors | Credit budgets, suspension policies |
| **5** | GitHub Integration & CI/CD | Repo setup, GitHub Actions pipeline |
| **6** | Medallion Architecture | Bronze / Silver / Gold layer objects |
| **7** | Data Ingestion | Snowpipe, Streams, Tasks, connectors |
| **8** | Data Governance | Masking policy creation, classification tagging |
| **9** | RBAC — Masking Policy Assignment | Attach governance policies to roles (completes RBAC) |
| **10** | Monitoring & Alerts | Task history, DT refresh, warehouse utilization |
| **11** | Audit | Immutable audit log, access event capture |
| **12** | Verification | End-to-end validation of data, lineage, RBAC, masking |
| **13** | AI-Ready Layer | Semantic layer, curated Gold views |
| **14** | Cortex Agents & Snowflake Intelligence | Agent specs, NLQ, stakeholder interface |
| **15** | Phase-wise Documentation | Per-phase runbooks, decision logs |
| **16** | Complete Project Documentation | Architecture overview, data dictionary, compliance pack |

---

## Phase 0 — Account Administration

**Dependency:** None. This is the absolute starting point.

**What happens here:**
- Configure Snowflake account-level settings (region, edition, multi-cluster)
- Set up SSO / SAML identity provider integration
- Define and apply network policies (IP allowlisting)
- Configure MFA enforcement for all human users
- Set password policy and session timeout defaults
- Disable default PUBLIC role privileges

**Exit criteria:**
- Account is accessible only from approved IP ranges
- SSO is functional for all human users
- MFA is enforced
- PUBLIC role has no default object privileges

**Do not proceed to Phase 1 until all exit criteria are met.**

---

## Phase 1 — Database Structure

**Dependency:** Phase 0 complete. Account-level controls are in place.

**What happens here:**
- Create all databases (e.g., `HEALTHCARE_RAW_DB`, `HEALTHCARE_TRANSFORM_DB`, `HEALTHCARE_SERVING_DB`, `HEALTHCARE_AUDIT_DB`)
- Create all schemas within each database (e.g., `BRONZE`, `SILVER`, `GOLD`, `AUDIT`, `QUARANTINE`)
- Create all internal and external Stages under `SYSADMIN` role
- Create all File Formats under `SYSADMIN` role
- Apply consistent naming conventions across all objects

> **Why Stages and File Formats are created here:** They are structural objects that pipelines and ingestion tasks depend on. Creating them under `SYSADMIN` now means grants can be precisely defined in Phase 3 (RBAC).

**Exit criteria:**
- All databases and schemas exist and are fully qualified
- All Stages and File Formats exist under `SYSADMIN` ownership
- No grants have been made yet — object creation only

**Do not proceed to Phase 2 until all exit criteria are met.**

---

## Phase 2 — Warehouse Provisioning

**Dependency:** Phase 1 complete. Databases and schemas exist.

**What happens here:**
- Create all virtual warehouses with appropriate sizes per workload type:
  - Ingestion warehouse
  - Transformation warehouse
  - Query / BI warehouse
  - AI / Cortex warehouse
  - Admin warehouse
- Set AUTO_SUSPEND and AUTO_RESUME on all warehouses
- Do NOT assign resource monitors yet (Phase 4)
- Do NOT grant warehouse usage yet (Phase 3)

> **Why warehouses are a dedicated step:** Warehouses are compute objects that RBAC grants reference directly (`GRANT USAGE ON WAREHOUSE`). They must exist before grants are written. Resource monitors are applied after RBAC because monitor assignments require both the warehouse and the responsible role to exist.

**Exit criteria:**
- All warehouses exist with correct sizing and auto-suspend settings
- No grants or monitors attached yet

**Do not proceed to Phase 3 until all exit criteria are met.**

---

## Phase 3 — RBAC Setup

**Dependency:** Phases 1 and 2 complete. All objects that grants will reference now exist.

**What happens here:**

**Step 3.1 — Role Creation and Hierarchy**
- Create all custom roles (e.g., `INGESTION_ROLE`, `TRANSFORM_ROLE`, `ANALYST_ROLE`, `DATA_STEWARD_ROLE`, `AUDIT_ROLE`, `PHI_ACCESS_ROLE`)
- Define role hierarchy — grant lower roles to higher roles as appropriate
- Never assign users to roles in this step

**Step 3.2 — Object-Level Grants**
- Grant `USAGE` on databases and schemas to appropriate roles
- Grant `USAGE` on warehouses to appropriate roles
- Grant `READ` / `WRITE` on Stages to ingestion and transform roles
- Grant `USAGE` on File Formats to ingestion roles
- Grant `CREATE TABLE`, `CREATE VIEW`, `CREATE DYNAMIC TABLE`, `CREATE STREAM`, `CREATE TASK` on schemas to appropriate roles
- Follow least-privilege: grant only what each role needs, nothing more

**Step 3.3 — User-to-Role Assignment**
- Assign human users and service accounts to their designated roles
- Verify no user is directly granted `ACCOUNTADMIN` except break-glass accounts

> **Note on masking policy assignment:** Masking policies will be created in Phase 8 (Data Governance). The assignment of masking policies to columns is handled in Phase 9, which completes RBAC. This two-step split is intentional — policies cannot be assigned before they exist.

**Exit criteria:**
- All roles exist with correct hierarchy
- All object-level grants are in place
- All users are assigned to correct roles
- `SHOW GRANTS OF ROLE ACCOUNTADMIN;` returns only break-glass accounts

**Do not proceed to Phase 4 until all exit criteria are met.**

---

## Phase 4 — Resource Monitors

**Dependency:** Phase 2 (warehouses exist) and Phase 3 (roles exist for notification targets).

**What happens here:**
- Create resource monitors per warehouse / workload
- Set credit quota thresholds (e.g., notify at 75%, suspend at 100%)
- Assign notification recipients by role
- Attach monitors to warehouses

**Exit criteria:**
- Every warehouse has a resource monitor attached
- Notification alerts are configured and tested
- No warehouse can run unconstrained

**Do not proceed to Phase 5 until all exit criteria are met.**

---

## Phase 5 — GitHub Integration & CI/CD

**Dependency:** Phases 0–4 complete. The entire Snowflake foundation is in place.

**What happens here:**

**Step 5.1 — GitHub Integration**
- Initialize repository with agreed branching strategy (`main`, `staging`, `dev`)
- Define folder structure for IaC, pipelines, agent specs, and documentation
- Store all Snowflake object definitions from Phases 0–4 as versioned IaC manifests
- Configure Snowflake connection secrets in GitHub (never hardcoded)

**Step 5.2 — GitHub Actions CI/CD Setup**
- Define workflows for: lint → test → deploy to dev → promote to staging → promote to prod
- Configure environment-specific Snowflake connection variables
- Add schema comparison and rollback capability between environments
- Require approval gates for staging → prod promotions

> **Why CI/CD comes before any pipeline work:** From this point forward, every Snowflake object — Dynamic Tables, Streams, Tasks, Agent specs — is deployed through the pipeline, not manually. This ensures consistency, auditability, and rollback capability from day one of pipeline development.

**Exit criteria:**
- All Phase 0–4 IaC is committed and deployable via CI/CD
- A test deployment from dev → staging succeeds end-to-end
- No Snowflake objects are created manually from Phase 6 onward

**Do not proceed to Phase 6 until all exit criteria are met.**

---

## Phase 6 — Medallion Architecture

**Dependency:** Phase 5 complete. All objects deploy through CI/CD from this point.

**What happens here:**
- Define and deploy Bronze layer objects (raw landing tables, VARIANT columns)
- Define and deploy Silver layer objects (cleansed, validated Dynamic Tables)
- Define and deploy Gold layer objects (business-ready fact/dimension tables, marts)
- Define and deploy Quarantine schema for data contract violations
- Set `TARGET_LAG` progressively: tighter at Bronze, looser at Gold
- Use explicit column lists on all Dynamic Tables — never `SELECT *`
- Enable Change Tracking on all source tables that feed Streams

**Medallion promotion criteria to enforce:**
- Bronze → Silver: schema validated, nullability enforced, source metadata attached
- Silver → Gold: deduplication complete, business keys conformed, PHI fields present but not yet masked (masking applied in Phase 8–9)

**Exit criteria:**
- All three layers exist as deployed objects
- Dynamic Table DAG has no circular dependencies
- No views sit between two Dynamic Tables in the DAG
- All objects deployed via CI/CD — no manual creation

**Do not proceed to Phase 7 until all exit criteria are met.**

---

## Phase 7 — Data Ingestion

**Dependency:** Phase 6 complete. Target Bronze layer objects exist.

**What happens here:**
- Configure Snowpipe for continuous file ingestion from cloud storage into Bronze
- Configure Streams on Bronze tables for CDC-driven downstream propagation
- Create Tasks to drive imperative ingestion logic; always include `WHEN SYSTEM$STREAM_HAS_DATA('stream_name')` on stream-driven tasks
- Implement data contract enforcement at ingest: route violations to Quarantine schema
- Attach source metadata (origin, timestamp, record hash, run ID) to every ingested record
- Resume all Tasks after creation: `ALTER TASK task_name RESUME;`

**Exit criteria:**
- Data flows end-to-end from source → Bronze → Silver → Gold
- Contract violations are routed to Quarantine (not silently dropped)
- All Tasks are in RESUMED state
- No hardcoded credentials anywhere in pipeline code

**Do not proceed to Phase 8 until all exit criteria are met.**

---

## Phase 8 — Data Governance

**Dependency:** Phase 7 complete. Data is flowing through all layers and PHI fields are identifiable.

**What happens here:**

**Step 8.1 — PHI Classification and Tagging**
- Identify and tag all PHI columns (SSN, MRN, DOB, diagnosis codes, etc.) using Snowflake data classification policies
- Apply sensitivity tags to all relevant columns across Bronze, Silver, and Gold layers
- Register all objects in the data catalog with business glossary, ownership, and sensitivity attribution

**Step 8.2 — Masking Policy Creation**
- Create dynamic masking policies for each PHI field type
- Policies are role-sensitive: reveal full value to `PHI_ACCESS_ROLE`, mask for all others
- Use `AI_REDACT` for unstructured text fields containing PII
- Do NOT assign policies to columns yet — assignment happens in Phase 9

> **Why policy creation is separated from assignment:** Masking policies are governance artifacts that must be defined, reviewed, and version-controlled independently of the RBAC assignment step. This allows policies to be audited before activation.

**Exit criteria:**
- All PHI columns are tagged and classified
- All masking policies are created, reviewed, and committed to version control
- No policies are assigned to columns yet

**Do not proceed to Phase 9 until all exit criteria are met.**

---

## Phase 9 — RBAC: Masking Policy Assignment

**Dependency:** Phase 8 complete. Masking policies exist and are ready for assignment.

**What happens here:**
- Assign masking policies created in Phase 8 to their target PHI columns across all layers
- Assign row access policies for multi-tenant isolation where applicable
- Verify that querying PHI columns under non-privileged roles returns masked output
- Verify that querying under `PHI_ACCESS_ROLE` returns unmasked output

> **This step completes RBAC.** The full access control picture — roles, grants, and masking — is now in place.

**Exit criteria:**
- Every tagged PHI column has a masking policy attached
- Masking verified by querying as both privileged and non-privileged roles
- No unmasked PHI is accessible on Gold-layer views by non-privileged roles

**Do not proceed to Phase 10 until all exit criteria are met.**

---

## Phase 10 — Monitoring & Alerts

**Dependency:** Phases 6–9 complete. The full data platform (pipelines + governance) is operational.

**What happens here:**
- Set up Task history monitoring and failure alerting
- Set up Dynamic Table refresh history monitoring
- Set up Stream staleness monitoring (`stale_after` column checks)
- Configure warehouse utilization alerts (credit burn rate, queue depth)
- Set up data quality alerting (anomalous row counts, null rates, contract violation spikes)
- All monitoring queries deployed via CI/CD as scheduled Tasks or Snowflake Alerts

**Exit criteria:**
- All pipeline components have failure alerting
- Stream staleness is actively monitored
- Warehouse credit burn is visible and alerted

**Do not proceed to Phase 11 until all exit criteria are met.**

---

## Phase 11 — Audit

**Dependency:** Phase 10 complete. Monitoring is operational and the system is running.

**What happens here:**
- Configure immutable audit log capturing: all data access, modifications, sharing events, and query fingerprints
- Capture identity, timestamp, role, warehouse, and query hash for every event
- Set up periodic `ACCOUNTADMIN` role membership review
- Configure external share audit — log every share event with recipient identity and dataset version
- Validate that audit log is append-only and cannot be modified by any role

**Exit criteria:**
- Audit log is active and capturing all required event types
- `ACCOUNTADMIN` membership review process is documented and scheduled
- Audit log immutability is verified

**Do not proceed to Phase 12 until all exit criteria are met.**

---

## Phase 12 — Verification

**Dependency:** Phases 0–11 complete. The entire platform is operational, governed, monitored, and audited.

**What happens here:**
- End-to-end data flow verification: source → Bronze → Silver → Gold
- Lineage verification: column-level lineage is traceable from source to consumption
- RBAC spot check: verify each role can only access what it is granted
- Masking spot check: verify PHI masking behaves correctly for all role combinations
- Resource monitor verification: confirm credit suspension triggers correctly
- Task and Dynamic Table health check: confirm all objects are in healthy, resumed state
- Data quality check: row counts, null rates, and duplicate checks across all layers

**Exit criteria:**
- All verification checks pass with documented evidence
- Any failures resolved before proceeding
- Platform is signed off as production-ready

**Do not proceed to Phase 13 until all exit criteria are met.**

---

## Phase 13 — AI-Ready Layer

**Dependency:** Phase 12 complete. Data is verified, governed, and masking is confirmed active.

**What happens here:**
- Build and publish the semantic layer: metric definitions, entity relationships, business terminology
- Create curated Gold-layer views optimised for AI consumption
- Define and register vector embeddings if retrieval-augmented generation (RAG) is required
- Validate that all AI-facing datasets inherit masking policies from underlying columns
- Sample all Cortex AI functions before running on full tables (`LIMIT 10` test first — billed per token)

**Exit criteria:**
- Semantic layer is documented and version-controlled
- AI-facing views inherit correct masking from Gold layer
- Cortex function sampling validated before full-table runs

**Do not proceed to Phase 14 until all exit criteria are met.**

---

## Phase 14 — Cortex Agents & Snowflake Intelligence

**Dependency:** Phase 13 complete. Semantic layer and AI-ready views exist.

**What happens here:**
- Define Cortex Agent specs using `$spec$` delimiter (not `$$`)
- `models` defined as an object, not an array
- `tool_resources` defined as a top-level key, not nested inside `tools`
- Configure Snowflake Intelligence for natural language querying against the semantic layer
- Build conversational agent orchestration via Oracle Code CLI with memory and context continuity
- Ground all AI responses in verified platform data (RAG) to prevent hallucination
- Configure stakeholder feedback capture for continuous improvement

**Exit criteria:**
- Agents respond accurately to natural language queries against the semantic layer
- Responses are grounded — no hallucinated data references
- Agent specs are version-controlled alongside pipeline code

**Do not proceed to Phase 15 until all exit criteria are met.**

---

## Phase 15 — Phase-wise Documentation

**Dependency:** Phase 14 complete. The entire platform is built and verified.

**What happens here:**
- Write per-phase runbooks documenting the exact steps executed, decisions made, and deviations from this playbook
- Capture IaC manifest inventory per phase
- Document all role definitions and grant matrices
- Document masking policy specifications and PHI column registry
- Document CI/CD pipeline architecture and environment promotion process

**Exit criteria:**
- Every phase has a corresponding runbook
- All decision logs are captured

---

## Phase 16 — Complete Project Documentation

**Dependency:** Phase 15 complete.

**What happens here:**
- Architecture overview diagram (end-to-end platform)
- Data dictionary (all tables, columns, types, descriptions, sensitivity tags)
- HIPAA compliance evidence pack (masking policies, audit log samples, RBAC matrix)
- Operational runbook (how to monitor, respond to alerts, rotate credentials, promote changes)
- Stakeholder guide (how to use Snowflake Intelligence and self-service analytics)

**Exit criteria:**
- Complete documentation package is reviewed, approved, and stored in the repository
- HIPAA compliance evidence pack is ready for audit

---

## Quick Reference — Dependency Chain

```
Phase 0: Account Admin
    └── Phase 1: Database Structure (databases, schemas, stages, file formats)
            └── Phase 2: Warehouse Provisioning
                    └── Phase 3: RBAC Setup (roles + grants — NO masking assignment yet)
                            └── Phase 4: Resource Monitors
                                    └── Phase 5: GitHub Integration + CI/CD
                                            └── Phase 6: Medallion Architecture
                                                    └── Phase 7: Data Ingestion
                                                            └── Phase 8: Data Governance (create masking policies)
                                                                    └── Phase 9: RBAC — Masking Policy Assignment (completes RBAC)
                                                                            └── Phase 10: Monitoring & Alerts
                                                                                    └── Phase 11: Audit
                                                                                            └── Phase 12: Verification
                                                                                                    └── Phase 13: AI-Ready Layer
                                                                                                            └── Phase 14: Cortex Agents & Snowflake Intelligence
                                                                                                                    └── Phase 15: Phase-wise Documentation
                                                                                                                            └── Phase 16: Complete Project Documentation
```

---

## Key Rules — At a Glance

| Rule | Enforcement Point |
|---|---|
| Never `SELECT *` in Dynamic Tables | Phase 6 |
| Always `ALTER TASK name RESUME` after creation | Phase 7 |
| Always `WHEN SYSTEM$STREAM_HAS_DATA` on stream-driven tasks | Phase 7 |
| Never hardcode credentials — use `os.environ[]` or key pair auth | Phase 5 onward |
| Always `LIMIT 10` test before full Cortex AI table runs | Phase 13–14 |
| No unmasked PHI on Gold-layer views for non-privileged roles | Phase 9 |
| Always use `AI_*` Cortex functions — deprecated names will break | Phase 13–14 |
| Use `$spec$` delimiter in Cortex Agent specs (not `$$`) | Phase 14 |
| All objects deployed via CI/CD from Phase 6 onward — no manual creation | Phase 5 onward |

---

*This playbook is versioned alongside the platform codebase. Any intentional changes to phase sequence or exit criteria must be committed as a documented amendment.*
