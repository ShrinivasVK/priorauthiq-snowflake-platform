---
name: phase-5-github-cicd
description: Set up GitHub repo, IaC manifests, and GitHub Actions CI/CD. From this point forward, no manual Snowflake object creation.
tools:
  - Bash
  - Read
  - Write
---

# Phase 5 — GitHub Integration & CI/CD

## When to invoke
Phases 0–4 are complete. The Snowflake foundation is in place and needs to be captured as versioned IaC.

## Dependencies
Phases 0–4 complete.

## What to generate — in this order

### Step 5.1 — GitHub Integration
- Branching strategy: `main`, `staging`, `dev`
- Folder structure for: IaC manifests, pipelines, agent specs, documentation
- Store all Phase 0–4 Snowflake objects as versioned IaC manifests
- Configure Snowflake connection secrets in GitHub Secrets — **never hardcoded**

### Step 5.2 — GitHub Actions CI/CD
- Workflows: lint → test → deploy-to-dev → promote-to-staging → promote-to-prod
- Environment-specific Snowflake connection variables
- Schema comparison and rollback capability between environments
- **Required approval gates** for staging → prod promotions

## Non-negotiable rules

- Credentials live in GitHub Secrets or key-pair auth — never committed.
- Use `os.environ[]` for any credential access in Python code.
- **From Phase 6 onward, nothing is created manually.** Every Snowflake object flows through this pipeline.

## Why CI/CD comes before pipeline work
From this point on, every Dynamic Table, Stream, Task, and Agent spec deploys through the pipeline — not manually. This ensures consistency, auditability, and rollback from day one of pipeline development.

## Exit criteria (confirm before moving to Phase 6)

- [ ] All Phase 0–4 IaC committed and deployable via CI/CD
- [ ] Test deployment dev → staging succeeds end-to-end
- [ ] Approval gates functional for prod promotion
- [ ] No Snowflake objects created manually from this point forward

## Flag if
- User asks to create a Dynamic Table or Task directly in Snowsight — redirect them to the pipeline.