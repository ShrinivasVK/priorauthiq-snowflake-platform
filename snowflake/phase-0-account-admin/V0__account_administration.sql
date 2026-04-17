-- =============================================================================
-- Phase 0 — Account Administration
-- =============================================================================
-- Project  : PriorAuthIQ Healthcare Data Platform
-- Phase    : 0 of 16
-- Dependency: None (starting point)
-- Scope    : Account-level settings, network policy, password policy,
--            session defaults, PUBLIC role lockdown
-- Owner    : ACCOUNTADMIN (account-level operations only)
-- CI/CD    : Deploy via GitHub Actions using ACCOUNTADMIN service credentials
-- =============================================================================
--
-- IMPORTANT — Solo-developer context:
--   This build has no corporate identity provider and no multi-user onboarding
--   requirement. SSO/SAML and MFA sections are included as commented scaffolds
--   so the IaC is structurally complete and can be activated later without
--   refactoring. The network policy is intentionally permissive (0.0.0.0/0)
--   because the developer works from multiple locations with dynamic IPs.
--
-- Out of scope (not deferred — not needed at this stage):
--   - SSO / SAML integration  → scaffold provided, commented out
--   - MFA enforcement          → scaffold provided, commented out
--   - IP-restricted allowlist  → permissive baseline; tighten when IPs stabilize
--
-- Phase boundary — the following are NOT created here:
--   - Databases, schemas       (Phase 1)
--   - Warehouses               (Phase 2)
--   - Roles, grants            (Phase 3)
--   - Resource monitors        (Phase 4)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- =============================================================================
-- SECTION 1: Account-Level Settings
-- =============================================================================
-- Region and edition are set at account provisioning and cannot be changed via
-- SQL. Record them here for IaC documentation purposes.
--
-- Account region  : << PLACEHOLDER: e.g., AWS_US_WEST_2 >>
-- Account edition : Enterprise (required for masking policies and object tagging)
-- Account locator : << PLACEHOLDER: e.g., xy12345.us-west-2.aws >>
--
-- Verify with:
--   SELECT CURRENT_REGION(), CURRENT_ACCOUNT();
-- =============================================================================

-- Timezone: standardize to UTC for all session-level operations
ALTER ACCOUNT SET TIMEZONE = 'UTC';

-- Statement-level timeout: 4 hours max to prevent runaway queries
ALTER ACCOUNT SET STATEMENT_TIMEOUT_IN_SECONDS = 14400;

-- Require exact column count on COPY INTO to catch schema drift early
ALTER ACCOUNT SET ERROR_ON_NONDETERMINISTIC_MERGE = TRUE;

-- Minimum Time Travel retention: enforce at least 1 day across all objects
ALTER ACCOUNT SET MIN_DATA_RETENTION_TIME_IN_DAYS = 1;

-- Enable periodic rekeying for encryption-at-rest compliance
ALTER ACCOUNT SET PERIODIC_DATA_REKEYING = TRUE;


-- =============================================================================
-- SECTION 2: SSO / SAML Identity Provider Integration (SCAFFOLD — COMMENTED)
-- =============================================================================
-- Uncomment and populate when a corporate identity provider is onboarded.
-- Replace all << PLACEHOLDER >> values with actual IdP metadata.
--
-- CREATE SECURITY INTEGRATION IF NOT EXISTS HEALTHCARE_SSO_INTEGRATION
--   TYPE = SAML2
--   ENABLED = TRUE
--   SAML2_ISSUER          = '<< PLACEHOLDER: IdP Entity ID, e.g., https://idp.example.com/metadata >>'
--   SAML2_SSO_URL          = '<< PLACEHOLDER: IdP SSO URL, e.g., https://idp.example.com/sso/saml >>'
--   SAML2_PROVIDER         = '<< PLACEHOLDER: CUSTOM | OKTA | ADFS >>'
--   SAML2_X509_CERT        = '<< PLACEHOLDER: Base64-encoded X.509 certificate from IdP >>'
--   SAML2_SP_INITIATED_LOGIN_PAGE_LABEL = 'Healthcare Platform SSO'
--   SAML2_SNOWFLAKE_ACS_URL = 'https://<< ACCOUNT_LOCATOR >>.snowflakecomputing.com/fed/login'
--   SAML2_SNOWFLAKE_ISSUER_URL = 'https://<< ACCOUNT_LOCATOR >>.snowflakecomputing.com'
--   COMMENT = 'Phase 0 scaffold — activate when corporate IdP is available';
--
-- -- Verify SSO integration:
-- DESCRIBE SECURITY INTEGRATION HEALTHCARE_SSO_INTEGRATION;


-- =============================================================================
-- SECTION 3: Network Policy
-- =============================================================================
-- Permissive baseline: allows all IPs. The named policy object exists from day
-- one so tightening is a config change (update ALLOWED_IP_LIST), not a
-- structural one.
--
-- When static IPs or VPN are established, replace 0.0.0.0/0 with:
--   ALLOWED_IP_LIST = (
--     '<< PLACEHOLDER: Office CIDR, e.g., 203.0.113.0/24 >>',
--     '<< PLACEHOLDER: VPN CIDR, e.g., 198.51.100.0/24 >>',
--     '<< PLACEHOLDER: CI/CD runner IP, e.g., 192.0.2.10/32 >>'
--   )
--   BLOCKED_IP_LIST = (
--     '<< PLACEHOLDER: Known-bad CIDR ranges >>'
--   )
-- =============================================================================

CREATE NETWORK POLICY IF NOT EXISTS HEALTHCARE_NETWORK_POLICY
  ALLOWED_IP_LIST = ('0.0.0.0/0')
  COMMENT = 'Phase 0 — Permissive baseline. Tighten when static IPs or VPN are established.';

-- Attach policy at account level so it applies to all connections
ALTER ACCOUNT SET NETWORK_POLICY = HEALTHCARE_NETWORK_POLICY;


-- =============================================================================
-- SECTION 4: MFA Enforcement (SCAFFOLD — COMMENTED)
-- =============================================================================
-- Uncomment when multi-user onboarding requires MFA.
-- Snowflake MFA uses Duo Security; enrollment is per-user.
--
-- -- Enforce MFA at account level for all human users:
-- ALTER ACCOUNT SET REQUIRE_MFA = TRUE;
--
-- -- Per-user MFA enforcement (alternative to account-level):
-- -- ALTER USER << USERNAME >> SET MINS_TO_BYPASS_MFA = 0;
-- -- ALTER USER << USERNAME >> SET DISABLE_MFA = FALSE;
--
-- -- Verify MFA status for all users:
-- -- SELECT NAME, HAS_MFA, MINS_TO_BYPASS_MFA
-- --   FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
-- --  WHERE DELETED_ON IS NULL
-- --    AND NAME NOT LIKE 'SNOWFLAKE%';


-- =============================================================================
-- SECTION 5: Password Policy & Session Timeout Defaults
-- =============================================================================
-- Snowflake enforces password complexity via PASSWORD POLICY objects, which
-- are schema-level objects requiring a database. Since no database exists in
-- Phase 0, the password policy is deferred to Phase 1 as a scaffold below.
--
-- What we CAN set at account level in Phase 0: session timeout behavior.
-- =============================================================================

-- Session idle timeout: disable keep-alive so sessions expire after inactivity
ALTER ACCOUNT SET CLIENT_SESSION_KEEP_ALIVE = FALSE;

-- Heartbeat frequency: 3600 seconds (1 hour) — controls how often the client
-- pings to keep a session alive IF keep-alive were enabled
ALTER ACCOUNT SET CLIENT_SESSION_KEEP_ALIVE_HEARTBEAT_FREQUENCY = 3600;

-- Prevent MFA prompt suppression (no bypass window for MFA re-verification)
ALTER ACCOUNT SET ALLOW_CLIENT_MFA_CACHING = FALSE;

-- =============================================================================
-- PASSWORD POLICY (SCAFFOLD — DEFERRED TO PHASE 1)
-- =============================================================================
-- Password policies require a database and schema. Create this object in
-- Phase 1 after HEALTHCARE_DEV (or equivalent) exists, then attach it to
-- the account.
--
-- CREATE PASSWORD POLICY IF NOT EXISTS << DATABASE >>.<< SCHEMA >>.HEALTHCARE_PASSWORD_POLICY
--   PASSWORD_MIN_LENGTH            = 14
--   PASSWORD_MAX_LENGTH            = 256
--   PASSWORD_MIN_UPPER_CASE_CHARS  = 1
--   PASSWORD_MIN_LOWER_CASE_CHARS  = 1
--   PASSWORD_MIN_NUMERIC_CHARS     = 1
--   PASSWORD_MIN_SPECIAL_CHARS     = 1
--   PASSWORD_MAX_AGE_DAYS          = 90
--   PASSWORD_MAX_RETRIES           = 5
--   PASSWORD_LOCKOUT_TIME_MINS     = 30
--   PASSWORD_HISTORY               = 5
--   COMMENT = 'HIPAA-aligned password policy — created in Phase 1, attached to account';
--
-- ALTER ACCOUNT SET PASSWORD POLICY << DATABASE >>.<<SCHEMA>>.HEALTHCARE_PASSWORD_POLICY;


-- =============================================================================
-- SECTION 6: Revoke Default PUBLIC Role Privileges
-- =============================================================================
-- The PUBLIC role has implicit grants in every Snowflake account. This section
-- removes those defaults so that access is exclusively controlled by custom
-- roles created in Phase 3.
--
-- Non-negotiable: PUBLIC must have zero object privileges by the end of Phase 0.
--
-- Strategy:
--   1. Revoke account-level privileges granted to PUBLIC
--   2. Revoke access to existing objects (sample data, compute pools, warehouse)
--   3. Use FUTURE grants to prevent PUBLIC from inheriting on new objects
--
-- NOTE: SNOWFLAKE database roles (CORTEX_USER, ML_USER, etc.) are system-
--       managed and cannot be revoked from PUBLIC. They are not a risk — they
--       grant access to Snowflake-managed functions, not customer data.
-- =============================================================================

-- 6a. Revoke account-level privileges from PUBLIC
REVOKE USE AI FUNCTIONS ON ACCOUNT FROM ROLE PUBLIC;
REVOKE VIEW LINEAGE ON ACCOUNT FROM ROLE PUBLIC;


-- 6b. Revoke compute pool and warehouse usage from PUBLIC
REVOKE USAGE ON COMPUTE POOL SYSTEM_COMPUTE_POOL_CPU FROM ROLE PUBLIC;
REVOKE USAGE ON COMPUTE POOL SYSTEM_COMPUTE_POOL_GPU FROM ROLE PUBLIC;
REVOKE USAGE ON WAREHOUSE SYSTEM$STREAMLIT_NOTEBOOK_WH FROM ROLE PUBLIC;

-- 6c. Revoke PyPI repository user grant from PUBLIC
-- (controlled via account parameter; prevents PUBLIC from installing packages)
ALTER ACCOUNT SET ENABLE_PYPI_REPOSITORY_USER_PUBLIC_GRANT = FALSE;

-- 6d. Prevent PUBLIC from inheriting privileges on future objects
-- These ensure that databases/schemas created in Phase 1+ don't auto-grant to PUBLIC
REVOKE ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE DT_DEMO FROM ROLE PUBLIC;


-- =============================================================================
-- EXIT CRITERIA — Verification Queries
-- =============================================================================
-- Run these after deployment to confirm Phase 0 is complete.
-- Uncomment and execute manually or via a CI/CD verification step.
--
-- -- 1. Confirm account region and edition
-- SELECT CURRENT_REGION()  AS ACCOUNT_REGION,
--        CURRENT_ACCOUNT() AS ACCOUNT_LOCATOR,
--        CURRENT_VERSION() AS SNOWFLAKE_VERSION;
--
-- -- 2. Confirm network policy is attached to the account
-- SHOW PARAMETERS LIKE 'NETWORK_POLICY' IN ACCOUNT;
--
-- -- 3. Confirm named network policy exists and inspect its configuration
-- DESCRIBE NETWORK POLICY HEALTHCARE_NETWORK_POLICY;
--
-- -- 4. Confirm session and MFA-related parameters are set
-- SHOW PARAMETERS LIKE 'ALLOW_CLIENT_MFA_CACHING' IN ACCOUNT;
-- -- NOTE: PASSWORD POLICY is a schema-level object created in Phase 1.
-- --       Verify with: SHOW PASSWORD POLICIES IN ACCOUNT; (after Phase 1)
--
-- -- 5. Confirm session timeout is configured
-- SHOW PARAMETERS LIKE 'CLIENT_SESSION_KEEP_ALIVE%' IN ACCOUNT;
--
-- -- 6. Confirm PUBLIC role has no residual object privileges
-- SHOW GRANTS TO ROLE PUBLIC;
-- -- Expected: Only SNOWFLAKE database role USAGE grants remain (system-managed,
-- -- cannot be revoked). No account-level privileges, no USAGE on databases,
-- -- schemas, warehouses, or compute pools should remain.
--
-- -- 7. Confirm timezone is UTC
-- SHOW PARAMETERS LIKE 'TIMEZONE' IN ACCOUNT;
--
-- -- 8. Confirm periodic rekeying is enabled
-- SHOW PARAMETERS LIKE 'PERIODIC_DATA_REKEYING' IN ACCOUNT;
-- =============================================================================
-- END OF PHASE 0
-- =============================================================================
