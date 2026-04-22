-- =============================================================================
-- Phase 2 — Warehouse Provisioning
-- =============================================================================
-- Project  : PriorAuthIQ Healthcare Data Platform
-- Phase    : 2 of 16
-- Dependency: Phase 1 complete (databases and schemas exist)
-- Scope    : Virtual warehouses — compute objects only
-- Owner    : SYSADMIN (all warehouses created in this phase)
-- =============================================================================
--
-- Warehouses:
--   PA_INGESTION_WH   — Snowpipe, batch loads
--   PA_TRANSFORM_WH   — Silver/Gold Dynamic Table refreshes
--   PA_QUERY_WH       — Analyst/BI consumption
--   PA_AI_CORTEX_WH   — Cortex functions, agent workloads
--   PA_ADMIN_WH       — DDL, admin tasks
--   PA_CICD_WH        — GitHub Actions deployments
--
-- Phase boundary — the following are NOT done here:
--   - Grants / USAGE         (Phase 3)
--   - Resource monitors      (Phase 4)
-- =============================================================================

USE ROLE SYSADMIN;


-- =============================================================================
-- SECTION 1: Ingestion Warehouse
-- =============================================================================

CREATE WAREHOUSE IF NOT EXISTS PA_INGESTION_WH
  WAREHOUSE_SIZE      = 'SMALL'
  AUTO_SUSPEND        = 60
  AUTO_RESUME         = TRUE
  INITIALLY_SUSPENDED = TRUE
  MIN_CLUSTER_COUNT   = 1
  MAX_CLUSTER_COUNT   = 1
  COMMENT             = 'Ingestion workload — Snowpipe, batch loads';


-- =============================================================================
-- SECTION 2: Transformation Warehouse
-- =============================================================================

CREATE WAREHOUSE IF NOT EXISTS PA_TRANSFORM_WH
  WAREHOUSE_SIZE      = 'MEDIUM'
  AUTO_SUSPEND        = 120
  AUTO_RESUME         = TRUE
  INITIALLY_SUSPENDED = TRUE
  MIN_CLUSTER_COUNT   = 1
  MAX_CLUSTER_COUNT   = 1
  COMMENT             = 'Transformation workload — Silver/Gold Dynamic Table refreshes';


-- =============================================================================
-- SECTION 3: Query / BI Warehouse
-- =============================================================================

CREATE WAREHOUSE IF NOT EXISTS PA_QUERY_WH
  WAREHOUSE_SIZE      = 'SMALL'
  AUTO_SUSPEND        = 60
  AUTO_RESUME         = TRUE
  INITIALLY_SUSPENDED = TRUE
  MIN_CLUSTER_COUNT   = 1
  MAX_CLUSTER_COUNT   = 1
  COMMENT             = 'Query workload — analyst and BI consumption';


-- =============================================================================
-- SECTION 4: AI / Cortex Warehouse
-- =============================================================================

CREATE WAREHOUSE IF NOT EXISTS PA_AI_CORTEX_WH
  WAREHOUSE_SIZE      = 'MEDIUM'
  AUTO_SUSPEND        = 120
  AUTO_RESUME         = TRUE
  INITIALLY_SUSPENDED = TRUE
  MIN_CLUSTER_COUNT   = 1
  MAX_CLUSTER_COUNT   = 1
  COMMENT             = 'AI workload — Cortex functions, agent workloads';


-- =============================================================================
-- SECTION 5: Admin Warehouse
-- =============================================================================

CREATE WAREHOUSE IF NOT EXISTS PA_ADMIN_WH
  WAREHOUSE_SIZE      = 'XSMALL'
  AUTO_SUSPEND        = 60
  AUTO_RESUME         = TRUE
  INITIALLY_SUSPENDED = TRUE
  MIN_CLUSTER_COUNT   = 1
  MAX_CLUSTER_COUNT   = 1
  COMMENT             = 'Admin workload — DDL, administrative tasks';


-- =============================================================================
-- SECTION 6: CI/CD Warehouse
-- =============================================================================

CREATE WAREHOUSE IF NOT EXISTS PA_CICD_WH
  WAREHOUSE_SIZE      = 'XSMALL'
  AUTO_SUSPEND        = 60
  AUTO_RESUME         = TRUE
  INITIALLY_SUSPENDED = TRUE
  MIN_CLUSTER_COUNT   = 1
  MAX_CLUSTER_COUNT   = 1
  COMMENT             = 'CI/CD workload — GitHub Actions deployments';


-- =============================================================================
-- EXIT CRITERIA — Verification Queries
-- =============================================================================
-- Run these after deployment to confirm Phase 2 is complete.
--
-- -- 1. Confirm all six warehouses exist and are owned by SYSADMIN
-- SHOW WAREHOUSES LIKE 'PA_%_WH';
--
-- -- 2. Confirm AUTO_SUSPEND and AUTO_RESUME are set on all warehouses
-- SELECT "name", "size", "auto_suspend", "auto_resume", "owner"
--   FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
--  WHERE "name" IN (
--    'PA_INGESTION_WH', 'PA_TRANSFORM_WH', 'PA_QUERY_WH',
--    'PA_AI_CORTEX_WH', 'PA_ADMIN_WH', 'PA_CICD_WH'
--  );
--
-- -- 3. Confirm no grants beyond SYSADMIN ownership
-- SHOW GRANTS ON WAREHOUSE PA_INGESTION_WH;
-- SHOW GRANTS ON WAREHOUSE PA_TRANSFORM_WH;
-- SHOW GRANTS ON WAREHOUSE PA_QUERY_WH;
-- SHOW GRANTS ON WAREHOUSE PA_AI_CORTEX_WH;
-- SHOW GRANTS ON WAREHOUSE PA_ADMIN_WH;
-- SHOW GRANTS ON WAREHOUSE PA_CICD_WH;
-- =============================================================================
-- END OF PHASE 2
-- =============================================================================
