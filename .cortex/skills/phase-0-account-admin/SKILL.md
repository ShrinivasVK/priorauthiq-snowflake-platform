---
name: phase-0-account-admin
description: Configure Snowflake account-level settings, session defaults, and PUBLIC role lockdown. This is the absolute starting point; nothing else can proceed without it.
tools:
  - snowflake_sql_execute
---

# Phase 0 — Account Administration

## When to invoke
User is setting up the Snowflake account for the first time, or hardening account-level controls before any object creation.

## Dependencies
None. This is Phase 0.

## Context
This is a solo-developer build. There is no corporate identity provider, no SSO requirement, and no plan to onboard additional users. Security controls are scoped accordingly — structural hygiene is enforced, but enterprise-scale controls (SSO, MFA, IP restrictions) are out of scope.

## What to generate

1. **Account settings** — confirm region, edition (Enterprise+ required for masking/tagging), multi-cluster config.
2. **Network policies** — create a permissive baseline network policy. Do NOT restrict by IP allowlist — the developer works from multiple locations and devices with varying IPs. The policy exists as a named object so it can be tightened later without structural changes.
3. **Session defaults** — password policy (complexity, expiration) and session idle timeout.
4. **PUBLIC role lockdown** — revoke all default privileges from PUBLIC.

## Out of scope (not deferred — not needed)

| Item | Reason |
|---|---|
| SSO / SAML integration | No corporate identity provider; solo developer |
| MFA enforcement | Solo developer; no compliance mandate at this stage |
| IP-restricted network policy | Developer works from multiple locations with dynamic IPs |

## Non-negotiable rules

- PUBLIC role must have zero object privileges by end of this phase.
- Service accounts (e.g., GitHub Actions) use key-pair auth — never passwords.
- A named network policy MUST exist (even if permissive) so tightening is a config change, not a structural one.
- No databases, warehouses, roles, or grants are created in this phase — object creation starts in Phase 1.

## Network policy guidance

Generate a named, permissive policy:

```sql
CREATE NETWORK POLICY IF NOT EXISTS HEALTHCARE_NETWORK_POLICY
  ALLOWED_IP_LIST = ('0.0.0.0/0')
  COMMENT = 'Permissive baseline — tighten when static IPs or VPN are established';

ALTER ACCOUNT SET NETWORK_POLICY = HEALTHCARE_NETWORK_POLICY;
```

The policy object exists in IaC from day one. If IPs stabilize later, update ALLOWED_IP_LIST — no structural changes needed.

## Exit criteria (confirm before moving to Phase 1)

- [ ] Account region and edition confirmed (Enterprise+ for masking/tagging)
- [ ] Named network policy exists and is attached to account
- [ ] Password policy and session timeout configured
- [ ] PUBLIC role has no default object privileges

## Flag if
- User asks to create databases, warehouses, or roles — those are Phase 1+.
- User asks to configure SSO or MFA — out of scope for this project, explain why.
- User asks to skip PUBLIC role lockdown — non-negotiable even for solo dev.