---
name: phase-2-warehouse-provisioning
description: Create all virtual warehouses with correct sizing and auto-suspend. Compute objects only — no grants or resource monitors yet.
tools:
  - snowflake_sql_execute
---

# Phase 2 — Warehouse Provisioning

## When to invoke
Phase 1 is complete. User needs compute provisioned before RBAC can reference warehouse USAGE grants.

## Dependencies
Phase 1 complete (databases and schemas exist).

## What to generate

Create dedicated warehouses per workload type:
1. **Ingestion warehouse** — sized for continuous Snowpipe / batch loads
2. **Transformation warehouse** — sized for Silver/Gold Dynamic Table refreshes
3. **Query / BI warehouse** — sized for analyst consumption
4. **AI / Cortex warehouse** — sized for Cortex function / agent workloads
5. **Admin warehouse** — small, for DDL and administrative tasks

## Non-negotiable rules

- Every warehouse MUST have `AUTO_SUSPEND` and `AUTO_RESUME` set.
- **No grants yet** — warehouse USAGE grants happen in Phase 3.
- **No resource monitors yet** — monitor attachment happens in Phase 4.

## Why warehouses are a dedicated step
Warehouses are compute objects that RBAC grants reference directly (`GRANT USAGE ON WAREHOUSE`). They must exist before grants are written. Resource monitors are applied after RBAC because monitor assignments require both the warehouse and responsible role to exist.

## Exit criteria (confirm before moving to Phase 3)

- [ ] All warehouses exist with correct sizing
- [ ] AUTO_SUSPEND and AUTO_RESUME configured on all
- [ ] No grants or monitors attached

## Flag if
- User asks to grant warehouse access — that's Phase 3.
- User asks to attach a resource monitor — that's Phase 4.