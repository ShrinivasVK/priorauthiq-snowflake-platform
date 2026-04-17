---
name: phase-3-rbac-setup
description: Create roles, define hierarchy, grant object-level access, assign users. Does NOT include masking policy assignment — that's Phase 9.
tools:
  - snowflake_sql_execute
---

# Phase 3 — RBAC Setup

## When to invoke
Phases 1 and 2 are complete. All objects that grants will reference now exist.

## Dependencies
Phase 1 (databases, schemas, stages, file formats) + Phase 2 (warehouses) complete.

## What to generate — in this order

### Step 3.1 — Role Creation and Hierarchy
- Create custom roles: `INGESTION_ROLE`, `TRANSFORM_ROLE`, `ANALYST_ROLE`, `DATA_STEWARD_ROLE`, `AUDIT_ROLE`, `PHI_ACCESS_ROLE`
- Define hierarchy — grant lower roles to higher roles as appropriate
- **Never assign users to roles in this step**

### Step 3.2 — Object-Level Grants
- `USAGE` on databases and schemas to appropriate roles
- `USAGE` on warehouses to appropriate roles
- `READ` / `WRITE` on stages to ingestion and transform roles
- `USAGE` on file formats to ingestion roles
- `CREATE TABLE`, `CREATE VIEW`, `CREATE DYNAMIC TABLE`, `CREATE STREAM`, `CREATE TASK` on schemas to appropriate roles
- **Least privilege** — grant only what each role needs

### Step 3.3 — User-to-Role Assignment
- Assign human users and service accounts to designated roles
- Verify no user is directly granted `ACCOUNTADMIN` except break-glass accounts

## Non-negotiable rules

- **Do NOT assign masking policies here.** Masking policies don't exist yet — they're created in Phase 8 and assigned in Phase 9.
- `ACCOUNTADMIN` restricted to break-glass accounts only.
- Follow strict least-privilege.

## Exit criteria (confirm before moving to Phase 4)

- [ ] All roles exist with correct hierarchy
- [ ] All object-level grants in place
- [ ] All users assigned to correct roles
- [ ] `SHOW GRANTS OF ROLE ACCOUNTADMIN;` returns only break-glass accounts

## Flag if
- User asks to create masking policies — that's Phase 8.
- User asks to assign masking policies to columns — that's Phase 9.