-- =============================================================================
-- Phase 1 — Database Structure
-- =============================================================================
-- Project  : PriorAuthIQ Healthcare Data Platform
-- Phase    : 1 of 16
-- Dependency: Phase 0 complete (account-level controls in place)
-- Scope    : Databases and schemas
-- Owner    : SYSADMIN (all objects created in this phase)
-- CI/CD    : Deploy via GitHub Actions under SYSADMIN service credentials
-- =============================================================================
--
-- Databases:
--   PA_DEV_DB   — Development environment (engineers iterate here)
--   PA_QA_DB    — Quality assurance (CI/CD validates before prod promotion)
--   PA_PROD_DB  — Production (business consumption, AI, analytics)
--
-- Schema structure (identical across all three databases):
--   RAW        — Bronze: raw landing tables, VARIANT columns
--   CURATED    — Silver: cleansed, validated, conformed types
--   ANALYTICS  — Gold: business-ready fact/dimension tables, marts
--   AI         — Platinum: semantic layer, curated views for Cortex AI
--
-- Phase boundary — the following are NOT created here:
--   - Warehouses            (Phase 2)
--   - Roles, grants         (Phase 3)
--   - Resource monitors     (Phase 4)
--   - Masking policies      (Phase 8)
-- =============================================================================

USE ROLE SYSADMIN;


-- =============================================================================
-- SECTION 1: Databases
-- =============================================================================

CREATE DATABASE IF NOT EXISTS PA_DEV_DB
  DATA_RETENTION_TIME_IN_DAYS = 1
  COMMENT = 'Development environment — engineers iterate here';

CREATE DATABASE IF NOT EXISTS PA_QA_DB
  DATA_RETENTION_TIME_IN_DAYS = 1
  COMMENT = 'Quality assurance — CI/CD validates here before prod promotion';

CREATE DATABASE IF NOT EXISTS PA_PROD_DB
  DATA_RETENTION_TIME_IN_DAYS = 7
  COMMENT = 'Production — business consumption, AI, analytics';


-- =============================================================================
-- SECTION 2: Schemas — PA_DEV_DB
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS PA_DEV_DB.RAW
  COMMENT = 'Bronze — raw landing tables, VARIANT columns, schema-flexible ingestion';

CREATE SCHEMA IF NOT EXISTS PA_DEV_DB.CURATED
  COMMENT = 'Silver — cleansed, validated, conformed types';

CREATE SCHEMA IF NOT EXISTS PA_DEV_DB.ANALYTICS
  COMMENT = 'Gold — business-ready fact/dimension tables, marts';

CREATE SCHEMA IF NOT EXISTS PA_DEV_DB.AI
  COMMENT = 'Platinum — semantic layer, curated views optimized for Cortex AI';


-- =============================================================================
-- SECTION 2: Schemas — PA_QA_DB
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS PA_QA_DB.RAW
  COMMENT = 'Bronze — raw landing tables, VARIANT columns, schema-flexible ingestion';

CREATE SCHEMA IF NOT EXISTS PA_QA_DB.CURATED
  COMMENT = 'Silver — cleansed, validated, conformed types';

CREATE SCHEMA IF NOT EXISTS PA_QA_DB.ANALYTICS
  COMMENT = 'Gold — business-ready fact/dimension tables, marts';

CREATE SCHEMA IF NOT EXISTS PA_QA_DB.AI
  COMMENT = 'Platinum — semantic layer, curated views optimized for Cortex AI';


-- =============================================================================
-- SECTION 2: Schemas — PA_PROD_DB
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS PA_PROD_DB.RAW
  COMMENT = 'Bronze — raw landing tables, VARIANT columns, schema-flexible ingestion';

CREATE SCHEMA IF NOT EXISTS PA_PROD_DB.CURATED
  COMMENT = 'Silver — cleansed, validated, conformed types';

CREATE SCHEMA IF NOT EXISTS PA_PROD_DB.ANALYTICS
  COMMENT = 'Gold — business-ready fact/dimension tables, marts';

CREATE SCHEMA IF NOT EXISTS PA_PROD_DB.AI
  COMMENT = 'Platinum — semantic layer, curated views optimized for Cortex AI';


-- =============================================================================
-- EXIT CRITERIA — Verification Queries
-- =============================================================================
-- Run these after deployment to confirm Phase 1 is complete.
-- Uncomment and execute manually or via a CI/CD verification step.
--
-- -- 1. Confirm all three databases exist and are owned by SYSADMIN
-- SELECT "name", "owner"
--   FROM (SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())))
--  WHERE "name" IN ('PA_DEV_DB', 'PA_QA_DB', 'PA_PROD_DB');
-- -- Or directly:
-- SHOW DATABASES LIKE 'PA_%_DB';
--
-- -- 2. Confirm schemas exist in each database (expect 4 custom + 1 INFORMATION_SCHEMA per DB)
-- SHOW SCHEMAS IN DATABASE PA_DEV_DB;
-- SHOW SCHEMAS IN DATABASE PA_QA_DB;
-- SHOW SCHEMAS IN DATABASE PA_PROD_DB;
--
-- -- 3. Confirm all schemas are owned by SYSADMIN
-- SELECT "name", "database_name", "owner"
--   FROM SNOWFLAKE.INFORMATION_SCHEMA.SCHEMATA
--  WHERE "database_name" IN ('PA_DEV_DB', 'PA_QA_DB', 'PA_PROD_DB')
--    AND "schema_name" NOT IN ('INFORMATION_SCHEMA');
--
-- -- 4. Confirm no grants have been made (Phase 1 is objects only)
-- -- Spot-check: should return only SYSADMIN ownership grants
-- SHOW GRANTS ON DATABASE PA_DEV_DB;
-- SHOW GRANTS ON DATABASE PA_QA_DB;
-- SHOW GRANTS ON DATABASE PA_PROD_DB;
-- =============================================================================
-- END OF PHASE 1
-- =============================================================================
