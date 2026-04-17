# PROJECT_CONTEXT.md

> **Purpose of this file.** This is the reusable, authoritative context for the project. Any human teammate or AI agent (Claude Code, Cortex Code CLI, Cursor, etc.) should read this before touching the repo. Terms are defined inline the first time they appear — treat the first-use definition as canonical. Sections are ordered so that skimming the first line of each gives you the whole project.

---

## 1. Project identity

- **Project name:** PriorAuthIQ
- **One-line description:** An AI-native prior authorization appeal assistant built on Snowflake Cortex, targeting safety-net clinics and patient advocates — segments ignored by incumbent enterprise vendors.
- **Execution framework:** This project is executed strictly according to `healthcare-platform-execution-playbook.md` (phases 0 → 16, no skipping, no backward dependencies).
- **Deployment constraints:** Must fit inside a Snowflake trial account (30 days, $400 USD credits). No external compute, no managed services beyond Snowflake + GitHub Actions.

---

## 2. Glossary (read this first if you're new to US healthcare)

US healthcare is acronym-dense. Every term below is used repeatedly in the codebase, semantic models, and Cortex agent specs. Definitions are scoped to this project — formal industry definitions may be broader.

| Term | Plain-English meaning | Why it matters here |
|---|---|---|
| **Payer** | The entity that pays the medical bill. Usually a private insurance company (UnitedHealthcare, Aetna, Cigna) or a government program (Medicare for elderly, Medicaid for low-income). | Payers issue denials. Their medical policies are the ground truth the agent retrieves against. |
| **Provider** | The entity delivering care — doctor, clinic, hospital, pharmacy. | Providers submit PA requests and appeals on behalf of patients. |
| **Prior Authorization (PA)** | A permission slip. Before certain expensive procedures/drugs, the provider must ask the payer for approval. If denied, the payer won't pay. | The central object of this project. Every data pipeline terminates in PA-related facts. |
| **Denial** | A payer's "no" response to a PA request. Arrives as a formal letter (PDF or electronic) citing reason codes and policy references. | Denial letters are the primary unstructured document type we process. |
| **Appeal** | A provider/patient's formal pushback against a denial. Submitted as a letter with clinical evidence and policy citations. | The agent's primary output is a drafted appeal letter. |
| **Overturn** | When an appeal succeeds and the payer reverses the original denial. | Overturn rates are our ground-truth signal for "was the original denial wrong?" |
| **Medicare Advantage (MA)** | Medicare coverage delivered through private insurers (not the government directly). MA plans deny at far higher rates than traditional Medicare. | The statistical motivation for this project (82% appeal overturn rate) comes from MA data. |
| **Safety-net clinic** | A clinic whose mission is to treat patients regardless of ability to pay — uninsured, Medicaid, homeless, immigrant populations. | Primary user segment. Under-resourced, no IT teams, ignored by enterprise PA vendors. |
| **FQHC** | Federally Qualified Health Center. A specific legal category of safety-net clinic that receives federal funding. | A concrete deployment target and persona for the agent UX. |
| **Patient advocate** | A person (professional, nonprofit volunteer, or family member) who helps patients navigate the insurance system. Usually not a clinician. | Secondary user persona. Needs plain-language output, not clinical jargon. |
| **CPT code** | Current Procedural Terminology. A 5-digit code identifying a specific medical procedure (e.g. `72148` = lumbar MRI without contrast). | Primary join key between claims, denials, and medical policies. |
| **ICD-10 code** | International Classification of Diseases, 10th revision. Alphanumeric code identifying a diagnosis (e.g. `M54.5` = low back pain). | Co-key with CPT; together they define what was done and why. |
| **LCD / NCD** | Local Coverage Determination / National Coverage Determination. Official Medicare policy documents stating when a given procedure will be covered. | Public PDFs that form the core of our Cortex Search policy corpus. |
| **Medical policy** | A payer's written rules defining when a given procedure is considered medically necessary. Every major insurer publishes these. | The ground truth for appeal arguments. Retrieved via Cortex Search. |
| **Medical necessity** | The clinical justification that a procedure was needed. The single most common denial reason code. | Most appeals hinge on proving this. |
| **Step therapy** | A rule requiring patients to try cheaper treatments first before the payer approves the expensive one. | A common denial reason; appeals often document prior failed therapies. |
| **PHI** | Protected Health Information. US federal law (HIPAA) restricts who can see it. Includes names, DOB, MRN, SSN, diagnosis when patient-linkable. | Drives Phases 8–9 of the playbook. Everything PHI-adjacent gets masked or tagged. |
| **Medical Record Number (MRN)** | A patient's ID within a single provider's records. PHI. | Always masked except under `PA_PHI_ACCESS_ROLE`. |
| **Utilization management (UM)** | The payer-side process of reviewing PA requests. The broader system our tool pushes back against. | Context term; appears in medical policies and denial letters. |

If a term appears in the code or semantic model that isn't in this glossary, add it here rather than defining it locally. Single source of truth.

---

## 3. The business problem

### 3.1 The setup (non-healthcare reader version)

In the US, when a patient needs an expensive procedure (MRI, surgery, specialty drug), the provider must first ask the insurance company for permission. This is **prior authorization**. The insurance company can approve or deny. If denied, the provider or patient can **appeal**, and the insurance company reviews again.

### 3.2 The core dysfunction

Two statistics define the problem:

- **When denials are appealed in Medicare Advantage, ~82% get overturned.** This means the original denial was wrong the vast majority of the time.
- **Only ~0.2% of denied patients ever appeal.** The other 99.8% accept the denial, skip care, pay out of pocket, or drop out of treatment.

The system denies aggressively because it knows almost nobody will push back. Appeals are hard — they require understanding medical jargon, payer-specific policies, clinical evidence standards, and appeal procedure rules. Most patients can't write them. Most small clinics don't have staff with the time or expertise either.

Total industry cost: ~$35B/year in administrative overhead; ~92% of reported care delays trace to PA.

### 3.3 The market gap (why this is an untapped problem)

Enterprise PA automation vendors already exist: **Availity, Innovaccer, Cohere Health, R1 RCM, UiPath** are the major names. They all sell to **large payers and large hospital systems** — expensive seat-licensed software, multi-month implementations, IT team required.

Nobody serves the opposite end of the market:

- Small rural clinics (1–5 providers, no IT department)
- FQHCs and safety-net clinics (chronically under-resourced)
- Patient advocacy nonprofits
- Patients themselves, directly

This population is **most harmed by PA denials** (Medicaid and uninsured patients face the highest denial rates) and has **zero AI tooling available**. Clear whitespace.

### 3.4 What we're building

A Snowflake-native AI application with a single conversational interface (Snowflake Intelligence) that accepts:

1. A denial letter (PDF or text)
2. Relevant portions of the patient's clinical chart
3. The patient's claim / PA history
4. A natural-language question from a non-expert user

And returns:

1. A plain-English explanation of why the denial likely happened
2. Identification of the specific clinical evidence that was missing or under-documented
3. An appeal strength score (0–100) based on historical overturn rates for similar denial-reason × CPT × ICD × payer combinations
4. A draft appeal letter citing the relevant medical policy sections and clinical chart evidence, labeled "DRAFT — CLINICIAN REVIEW REQUIRED"

All responses are grounded: every clinical claim must trace back to a retrieved chart note, every policy citation must trace back to a retrieved medical policy document. Ungrounded generation is treated as a defect, not a feature.

---

## 4. Why Snowflake Cortex specifically

The problem shape maps 1:1 to the Cortex primitive set. This is not a post-hoc justification — the problem was selected partly because it fits.

| Problem dimension | Cortex primitive | Role |
|---|---|---|
| Structured claims, denials, codes | **Cortex Analyst** (text-to-SQL over semantic model) | Answers "what's the overturn rate for CPT 72148 with Humana?" |
| Medical policy PDFs, clinical guidelines | **Cortex Search** service #1 (policy corpus) | Retrieves relevant policy sections for a given denial |
| Historical denial letters + appeal outcomes | **Cortex Search** service #2 (denial corpus) | Retrieves similar past cases + successful appeal patterns |
| Multi-step reasoning across both | **Cortex Agent** | Orchestrates Analyst + Search + custom tools |
| Appeal-strength scoring (deterministic, auditable) | **Custom tool** (stored procedure) | Pure SQL over historical overturn data — no LLM in the loop |
| Appeal-letter drafting (generative, grounded) | **Custom tool** calling `SNOWFLAKE.CORTEX.COMPLETE` | Constrained prompt, retrieval-augmented, always labeled as draft |
| PHI extraction from free-text denials | `AI_EXTRACT`, `AI_CLASSIFY` | Silver-layer enrichment |
| PHI redaction in unstructured text | `AI_REDACT` | Governance layer, Phase 8 |
| End-user conversational UI | **Snowflake Intelligence** | Zero frontend code; the chat interface is free |

If this were, say, a medical imaging problem, Snowflake would be the wrong platform. The fit here is deliberate.

---

## 5. Dataset strategy

### 5.1 Chosen path: Path A — Synthea + CMS SynPUFs + Cortex-generated denials

All three components are free, public, and redistribution-safe. No real PHI ever enters the system.

### 5.2 Component 1 — Clinical charts (Synthea)

- **What it is:** Open-source synthetic patient generator from MITRE. Produces realistic-but-not-real patient records including demographics, encounters, conditions (ICD-10), procedures (CPT), medications, observations, and social determinants.
- **Export format used:** CSV (simplest for Snowpipe ingestion); optionally FHIR R4 bundles if we want unstructured clinical notes.
- **Volume target:** ~10,000 patients. Generated for Texas and Ohio specifically (both are WISeR-program pilot states, which adds narrative cohesion and lets us frame the demo around real regulatory context).
- **License:** Apache 2.0. Safe to redistribute, safe to commit sample files.
- **Source:** https://github.com/synthetichealth/synthea
- **Snowflake landing:** `PA_RAW_DB.BRONZE.SYNTHEA_*` (one table per Synthea CSV: patients, encounters, conditions, procedures, medications, observations, careplans).

### 5.3 Component 2 — Claims (CMS SynPUF)

- **What it is:** CMS-published Synthetic Public Use Files. Realistic Medicare claim structures with diagnosis codes, procedure codes, provider IDs, payment amounts, dates. Synthetic — no real beneficiaries.
- **Volume target:** Inpatient + outpatient + carrier claim samples, ~2–3 GB total.
- **License:** Public domain (US federal government work).
- **Source:** https://www.cms.gov/data-research/statistics-trends-and-reports/medicare-claims-synthetic-public-use-files
- **Snowflake landing:** `PA_RAW_DB.BRONZE.SYNPUF_*`.
- **Why both Synthea and SynPUF:** Synthea gives us rich clinical narrative; SynPUF gives us realistic claims-side structure. We don't attempt to join them 1:1 at the patient level — they serve different demonstration purposes (Synthea = "here's the chart," SynPUF = "here's what the claims system looks like at volume").

### 5.4 Component 3 — Medical policies (public PDFs)

- **What it is:** Curated set of ~50–100 public medical policy documents.
- **Sources:**
  - Medicare LCDs and NCDs from CMS.gov (public domain).
  - Major insurer public clinical policy bulletins (Aetna, UHC, Cigna, BCBS all publish these on their public websites for provider reference).
- **Volume target:** ~200 MB of PDFs, indexed into a Cortex Search service.
- **License note:** Medicare docs are public domain. Insurer policy bulletins are publicly published for provider reference; we use them under fair-use educational framing. This is demo / portfolio scope — for any commercial use, licensing would need re-evaluation.
- **Snowflake landing:** Internal stage `@PA_RAW_DB.BRONZE.POLICY_STAGE`, with parsed text and metadata landing in `PA_TRANSFORM_DB.SILVER.MEDICAL_POLICIES`.

### 5.5 Component 4 — Denial letters (Cortex-generated synthetic)

- **What it is:** ~500–1,000 synthetic denial letters, generated using `SNOWFLAKE.CORTEX.COMPLETE` (Claude 4 Sonnet or equivalent).
- **Generation method:** A parameterized prompt template that takes (patient profile, CPT code, ICD-10 code, payer name, denial reason code) and outputs a realistic denial letter matching the style and structure of real payer denials.
- **Why this works:** The denial letters reference the same CPT/ICD codes and policy sections that appear in our actual policy corpus. This creates a self-consistent universe where Cortex Search retrieval genuinely matches the denial reasoning — which is exactly what we'd see in production.
- **Reason-code taxonomy:** Driven by the CMS Claim Adjustment Reason Codes (public) — common ones include `50` (not medically necessary), `197` (prior auth required), step-therapy-related codes, experimental/investigational, frequency limits.
- **Appeal-outcome labeling:** For each generated denial, we also generate a ground-truth "was this denial overturnable?" label by sampling from realistic overturn-rate distributions per reason code. This gives us a labeled dataset for evaluating the appeal-strength scorer.
- **Snowflake landing:** `PA_RAW_DB.BRONZE.DENIAL_LETTERS_RAW` (text column) with structured metadata in `PA_TRANSFORM_DB.SILVER.DENIALS`.

### 5.6 Total footprint

Estimated ~5–8 GB across all layers. Comfortably inside trial-account limits.

### 5.7 Data strategy fallbacks (not currently used)

If Path A breaks, fallbacks are documented but deferred:

- **Path B:** Kaggle synthetic health insurance claims datasets + CMS LCDs/NCDs. Simpler, less clinically rich.
- **Path C:** Full synthetic generation via Python (Faker + CMS reason-code taxonomy) + scraped public policy PDFs. Last resort.

---

## 6. User personas (who the agent serves)

These drive UX decisions, tone of agent responses, and masking policy targeting.

### 6.1 Primary: Clinic nurse or office manager at a small/rural/safety-net clinic

- Clinically literate but not an insurance expert.
- Limited time, limited staff, no IT support.
- Wants: "just tell me if it's worth appealing and help me write the letter."
- Agent response tone: clinical-professional, assumes medical vocabulary, no hand-holding on clinical terms.

### 6.2 Primary: Patient advocate at a nonprofit

- Not a clinician. May be a social worker, paralegal, or trained volunteer.
- Needs plain-English translation of clinical content.
- Wants: "explain why this was denied and whether we have a case."
- Agent response tone: plain-English, expands medical abbreviations, explains policy language.

### 6.3 Secondary: Clinic administrator / operations lead

- Not interacting case-by-case. Wants aggregate insight.
- Uses Cortex Analyst via Snowflake Intelligence for metrics: "what's our denial rate by payer this quarter? which CPT codes are we losing on?"
- Agent response tone: analytical, chart-oriented, numerical.

### 6.4 Secondary: Compliance / audit role

- Doesn't interact with agent directly. Consumes audit logs from Phase 11.
- Needs: every agent response must be traceable to retrieved sources and logged user identity.

---

## 7. Scope boundaries (what we are NOT building)

Explicit non-goals, to prevent scope creep. If a request would violate one of these, push back.

- **Not building an EHR integration.** No FHIR API consumers, no HL7 listeners. Users upload relevant chart excerpts as files or paste text.
- **Not building a payer-facing tool.** We are strictly provider/patient side. No utilization management dashboards for payers.
- **Not automating appeal submission.** The agent drafts; a human clinician reviews, signs, and sends. This is a safety requirement, not a feature gap.
- **Not handling real PHI.** Entire project runs on synthetic data. Even in production, architecture assumes a customer deployment would use their own tenant with their own real data — we demo with synthetic.
- **Not building custom frontend.** Snowflake Intelligence is the UI. If we ever need a richer UX, it's a Streamlit-in-Snowflake app, not an external web app.
- **Not a clinical decision-support tool.** We do not tell clinicians what to prescribe or diagnose. We only help argue with insurance companies about coverage.
- **Not a legal-advice tool.** Appeal letters are drafts for clinician review. We do not provide legal representation, and the agent must not claim to.
- **Not real-time.** Denials take days; appeals take weeks. Batch / near-real-time processing is fine. No streaming architecture.

---

## 8. Architecture summary

Full architecture lives in later documentation (Phase 16). This section is the orientation version.

### 8.1 Data layers (medallion, per playbook Phase 6)

- **Bronze** (`PA_RAW_DB`): raw CSVs, raw PDFs-as-text, raw LLM-generated letters. No transformations.
- **Silver** (`PA_TRANSFORM_DB`): parsed, cleaned, PHI-tagged. Dynamic Tables with explicit column lists. Claim-to-denial-to-policy joins resolved here.
- **Gold** (`PA_SERVING_DB`): business-ready fact/dim tables optimized for Cortex Analyst semantic model. Denial fact, appeal outcome fact, policy dim, patient dim (synthetic, masked), CPT dim, payer dim.
- **Audit** (`PA_AUDIT_DB`): immutable logs (Phase 11).
- **Quarantine** (schema in `PA_RAW_DB`): data-contract violations routed here.

### 8.2 Compute (per playbook Phase 2)

- `WH_INGEST_XS` — Snowpipe, file loads
- `WH_TRANSFORM_S` — Dynamic Table refreshes
- `WH_CORTEX_S` — Cortex function calls (indexing, agent inference)
- `WH_BI_XS` — Snowflake Intelligence query execution
- `WH_ADMIN_XS` — ad-hoc admin

All with `AUTO_SUSPEND = 60`, resource monitors enforcing hard suspension at the trial-credit threshold.

### 8.3 Roles (per playbook Phase 3)

- `PA_INGEST_ROLE` — writes to Bronze
- `PA_TRANSFORM_ROLE` — reads Bronze, writes Silver/Gold
- `PA_ANALYST_ROLE` — reads Gold, runs Cortex Analyst
- `PA_PATIENT_ADVOCATE_ROLE` — reads Gold with PHI masked; invokes agent
- `PA_PHI_ACCESS_ROLE` — reads Gold with PHI unmasked; invokes agent; intended for break-glass clinician review
- `PA_AUDIT_ROLE` — reads audit logs only, writes nothing

### 8.4 AI surface

- **Cortex Search services:**
  - `CSS_MEDICAL_POLICIES` over `PA_SERVING_DB.GOLD.MEDICAL_POLICIES`
  - `CSS_HISTORICAL_DENIALS` over `PA_SERVING_DB.GOLD.DENIAL_LETTERS_INDEXED`
- **Cortex Analyst semantic model:** `pa_semantic_model.yaml` covering denial fact + appeal outcome fact + dims.
- **Cortex Agent:** `APPEAL_ASSISTANT_AGENT`, spec using `$spec$` delimiter, `models` as object, `tool_resources` top-level.
- **Snowflake Intelligence:** exposes agent to `PA_ANALYST_ROLE`, `PA_PATIENT_ADVOCATE_ROLE`, `PA_PHI_ACCESS_ROLE`.

---

## 9. Invariants (rules that must never be violated)

These exist as both playbook rules and hard agent-instruction constraints. Any code or content that would break one of these is a defect.

- Never `SELECT *` in Dynamic Tables — explicit column lists only.
- Always `ALTER TASK name RESUME` after task creation.
- Always include `WHEN SYSTEM$STREAM_HAS_DATA('<stream>')` on stream-driven tasks.
- Never hardcode credentials; use GitHub Actions secrets → Snowflake key-pair auth.
- All objects from Phase 6 onward deploy through CI/CD — no manual `CREATE` in Snowsight.
- Cortex Agent specs use `$spec$` delimiter, not `$$`.
- Cortex Agent `models` is an object; `tool_resources` is a top-level key.
- Every agent response involving clinical claims must cite retrieved chart notes.
- Every agent response involving policy claims must cite retrieved policy documents.
- Every drafted appeal letter carries the label "DRAFT — CLINICIAN REVIEW REQUIRED" in its output.
- No real PHI in the repo, ever. All test fixtures are synthetic.
- PHI columns on Gold layer must be masked by default; only `PA_PHI_ACCESS_ROLE` sees unmasked values.

---

## 10. Execution sequence

Execution strictly follows `healthcare-platform-execution-playbook.md`. Phases are gated by exit criteria. Do not skip, do not reorder, do not return to a prior phase without a documented amendment.

Current phase is tracked in `README.md` and in the top-level GitHub project board.

---

## 11. Related documents

- `healthcare-platform-execution-playbook.md` — the phase-by-phase execution framework. Authoritative for sequencing.
- `README.md` — project entry point, current phase, quick-start.
- `AGENTS.md` — instructions specifically for AI coding agents working in this repo.
- `professional_summary.yml` — maintainer background (context for AI agents to calibrate response depth).

---

*This document is versioned. Material changes to problem framing, dataset strategy, or architecture must be committed as amendments with rationale.*
