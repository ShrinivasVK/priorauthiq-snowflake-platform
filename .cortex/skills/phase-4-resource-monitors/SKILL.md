---
name: phase-4-resource-monitors
description: Create resource monitors, set credit quotas, attach to warehouses. Prevents unconstrained credit burn.
tools:
  - snowflake_sql_execute
---

# Phase 4 — Resource Monitors

## When to invoke
Phases 2 and 3 are complete. Warehouses exist and roles exist as notification targets.

## Dependencies
Phase 2 (warehouses) + Phase 3 (roles for notification targets) complete.

## What to generate

1. **Resource monitors** — one per warehouse / workload
2. **Credit quota thresholds** — notify at 75%, suspend at 100% (adjust per workload)
3. **Notification recipients** — by role, not individual users
4. **Monitor-to-warehouse attachment** — every warehouse must have one

## Non-negotiable rules

- **Every warehouse MUST have a resource monitor attached.** No unconstrained compute.
- Notifications go to roles (e.g., DATA_STEWARD_ROLE), not individuals.
- Test the notification path before moving on.

## Exit criteria (confirm before moving to Phase 5)

- [ ] Every warehouse has a resource monitor attached
- [ ] Notification alerts configured and tested
- [ ] No warehouse can run unconstrained