-- =============================================================================
-- AWS S3 Storage Integration — Step-by-Step Template
-- =============================================================================
-- Project  : PriorAuthIQ Healthcare Data Platform
-- Purpose  : Establish trust between Snowflake and an AWS S3 bucket so that
--            external stages, Snowpipe, and COPY INTO can access S3 without
--            embedding credentials in every SQL statement.
--
-- How it works (high level):
--   1. You create a STORAGE INTEGRATION in Snowflake (this file, Step 1).
--   2. Snowflake generates an IAM user ARN and an external ID.
--   3. You create an IAM role in AWS with a trust policy that trusts
--      Snowflake's IAM user ARN + external ID (Step 2 — done in AWS Console).
--   4. You update the integration in Snowflake with the IAM role ARN (Step 3).
--   5. You verify from both sides (Step 4).
--
-- Prerequisites:
--   - An AWS account with permissions to create IAM roles and S3 bucket policies.
--   - An S3 bucket already created (e.g., s3://priorauthiq-healthcare-data/).
--   - ACCOUNTADMIN role in Snowflake (CREATE INTEGRATION is an account-level
--     privilege; only ACCOUNTADMIN has it by default).
--
-- IMPORTANT: This is a TEMPLATE. Replace all <PLACEHOLDER> values with your
-- actual values before executing. Search for "<" to find all placeholders.
-- =============================================================================


-- =============================================================================
-- STEP 1: Create the Storage Integration in Snowflake
-- =============================================================================
-- This tells Snowflake which S3 bucket(s) it's allowed to access and which
-- AWS IAM role to assume when accessing them.
--
-- STORAGE_PROVIDER = 'S3'
--   Tells Snowflake this is an Amazon S3 integration. Use 'S3GOV' for
--   GovCloud regions or 'S3CHINA' for China regions.
--
-- STORAGE_AWS_ROLE_ARN
--   The ARN of the IAM role you will create in AWS (Step 2). You need to
--   provide a placeholder here first, then come back and update it after
--   creating the role in AWS. Alternatively, if you've already created the
--   IAM role, paste the real ARN now.
--
-- STORAGE_ALLOWED_LOCATIONS
--   Whitelist of S3 paths this integration can access. External stages
--   referencing this integration CANNOT point to paths outside this list.
--   Use the most restrictive path that covers your use case.
--   Format: 's3://<bucket-name>/<optional-prefix>/'
--
-- STORAGE_BLOCKED_LOCATIONS (optional)
--   Explicitly deny access to specific sub-paths even if the parent path
--   is allowed. Useful when STORAGE_ALLOWED_LOCATIONS is broad.
--
-- ENABLED = TRUE
--   The integration is active immediately. Set to FALSE if you want to
--   create it in a disabled state and enable later.
--
-- NOTE: CREATE INTEGRATION requires ACCOUNTADMIN. This is one of the few
-- statements in this project that cannot run under SYSADMIN.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

USE DATABASE PA_DEV_DB;

CREATE STORAGE INTEGRATION IF NOT EXISTS PA_S3_STORAGE_INTEGRATION
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::737185275582:role/priorauthiqdataaccess'
  ENABLED = TRUE
  STORAGE_ALLOWED_LOCATIONS = (
    's3://priorauthiq-data/'
  )
  COMMENT = 'S3 storage integration for PriorAuthIQ healthcare data ingestion';


-- =============================================================================
-- STEP 2: Retrieve Snowflake's IAM User ARN and External ID
-- =============================================================================
-- After creating the integration, Snowflake auto-generates two critical values:
--
--   STORAGE_AWS_IAM_USER_ARN  — The IAM user that Snowflake will use to assume
--                                your IAM role. Looks like:
--                                arn:aws:iam::123456789012:user/abc1-b-...
--
--   STORAGE_AWS_EXTERNAL_ID   — A unique ID that prevents the "confused deputy"
--                                attack. You MUST include this in your IAM role's
--                                trust policy (Step 3).
--
-- Run this command and note both values — you need them for AWS configuration.
-- =============================================================================

DESCRIBE INTEGRATION PA_S3_STORAGE_INTEGRATION;

-- Expected output columns of interest:
-- ┌──────────────────────────────────┬──────────────────────────────────────────────┐
-- │ property                         │ property_value                                │
-- ├──────────────────────────────────┼──────────────────────────────────────────────┤
-- │ STORAGE_AWS_IAM_USER_ARN         │ arn:aws:iam::XXXXXXXXXXXX:user/abc1-b-...    │
-- │ STORAGE_AWS_EXTERNAL_ID          │ ABC12345_SFCRole=1_abcdefg1234567890=        │
-- └──────────────────────────────────┴──────────────────────────────────────────────┘
--
-- Copy these two values. You'll paste them into the AWS IAM trust policy next.


-- =============================================================================
-- STEP 3: Configure AWS — Create IAM Role + Trust Policy + S3 Permissions
-- =============================================================================
-- This step happens ENTIRELY in the AWS Console (or via AWS CLI / Terraform).
-- The SQL below is NOT executable — it's a JSON reference for your AWS config.
--
-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │  3A. Create an IAM Role in AWS                                             │
-- │                                                                            │
-- │  Go to: AWS Console → IAM → Roles → Create Role                           │
-- │  - Trusted entity type: "Custom trust policy"                              │
-- │  - Paste the trust policy JSON below (Step 3B)                             │
-- │  - Role name: e.g., priorauthiq-snowflake-role                             │
-- │  - Attach the permissions policy from Step 3C                              │
-- └─────────────────────────────────────────────────────────────────────────────┘
--
-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │  3B. Trust Policy (who can assume this role)                                │
-- │                                                                            │
-- │  This policy tells AWS: "Only the Snowflake IAM user with this specific    │
-- │  external ID is allowed to assume this role."                              │
-- │                                                                            │
-- │  Replace the two <PLACEHOLDER> values with the output from Step 2.         │
-- │                                                                            │
-- │  {                                                                         │
-- │    "Version": "2012-10-17",                                                │
-- │    "Statement": [                                                          │
-- │      {                                                                     │
-- │        "Effect": "Allow",                                                  │
-- │        "Principal": {                                                      │
-- │          "AWS": "<STORAGE_AWS_IAM_USER_ARN from Step 2>"                   │
-- │        },                                                                  │
-- │        "Action": "sts:AssumeRole",                                         │
-- │        "Condition": {                                                      │
-- │          "StringEquals": {                                                 │
-- │            "sts:ExternalId": "<STORAGE_AWS_EXTERNAL_ID from Step 2>"       │
-- │          }                                                                 │
-- │        }                                                                   │
-- │      }                                                                     │
-- │    ]                                                                       │
-- │  }                                                                         │
-- │                                                                            │
-- │  WHY the external ID matters:                                              │
-- │  Without it, any AWS account that knows your IAM role ARN could            │
-- │  potentially assume the role (the "confused deputy" problem). The          │
-- │  external ID acts as a shared secret between Snowflake and your AWS        │
-- │  account, ensuring only YOUR Snowflake account can assume the role.        │
-- └─────────────────────────────────────────────────────────────────────────────┘
--
-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │  3C. Permissions Policy (what the role can do on S3)                        │
-- │                                                                            │
-- │  Attach this as an inline policy or create a managed policy and attach it. │
-- │  Replace <your-bucket-name> with your actual S3 bucket name.               │
-- │                                                                            │
-- │  This grants the MINIMUM permissions Snowflake needs:                      │
-- │  - s3:GetObject          — Read files from S3 (COPY INTO, Snowpipe)        │
-- │  - s3:GetObjectVersion   — Read specific versions (if versioning enabled)  │
-- │  - s3:ListBucket         — List files in the bucket (stage browsing)       │
-- │  - s3:PutObject          — Write files to S3 (COPY INTO <location>)        │
-- │  - s3:DeleteObject       — Clean up files after ingestion (optional)       │
-- │                                                                            │
-- │  If you only need READ access (no unloading to S3), remove PutObject       │
-- │  and DeleteObject.                                                         │
-- │                                                                            │
-- │  {                                                                         │
-- │    "Version": "2012-10-17",                                                │
-- │    "Statement": [                                                          │
-- │      {                                                                     │
-- │        "Effect": "Allow",                                                  │
-- │        "Action": [                                                         │
-- │          "s3:GetObject",                                                   │
-- │          "s3:GetObjectVersion"                                             │
-- │        ],                                                                  │
-- │        "Resource": "arn:aws:s3:::<your-bucket-name>/*"                     │
-- │      },                                                                    │
-- │      {                                                                     │
-- │        "Effect": "Allow",                                                  │
-- │        "Action": [                                                         │
-- │          "s3:ListBucket",                                                  │
-- │          "s3:GetBucketLocation"                                            │
-- │        ],                                                                  │
-- │        "Resource": "arn:aws:s3:::<your-bucket-name>"                       │
-- │      },                                                                    │
-- │      {                                                                     │
-- │        "Effect": "Allow",                                                  │
-- │        "Action": [                                                         │
-- │          "s3:PutObject",                                                   │
-- │          "s3:DeleteObject"                                                 │
-- │        ],                                                                  │
-- │        "Resource": "arn:aws:s3:::<your-bucket-name>/*"                     │
-- │      }                                                                     │
-- │    ]                                                                       │
-- │  }                                                                         │
-- │                                                                            │
-- │  NOTE: The Resource uses two different formats:                             │
-- │  - "arn:aws:s3:::bucket/*"  → applies to OBJECTS inside the bucket         │
-- │  - "arn:aws:s3:::bucket"    → applies to the BUCKET itself (for listing)   │
-- │  Both are required. Missing the bucket-level resource causes ListBucket    │
-- │  to fail with "Access Denied", even if object-level permissions work.      │
-- └─────────────────────────────────────────────────────────────────────────────┘
--
-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │  3D. Copy the IAM Role ARN                                                 │
-- │                                                                            │
-- │  After creating the role, copy its ARN from the AWS Console:               │
-- │  IAM → Roles → priorauthiq-snowflake-role → Summary → Role ARN            │
-- │  It looks like: arn:aws:iam::123456789012:role/priorauthiq-snowflake-role   │
-- │                                                                            │
-- │  If you used a placeholder in Step 1, update the integration now:          │
-- └─────────────────────────────────────────────────────────────────────────────┘

-- Uncomment and run ONLY if you used a placeholder ARN in Step 1:
-- ALTER STORAGE INTEGRATION PA_S3_STORAGE_INTEGRATION
--   SET STORAGE_AWS_ROLE_ARN = '<arn:aws:iam::123456789012:role/priorauthiq-snowflake-role>';


-- =============================================================================
-- STEP 4: Verification — Snowflake Side
-- =============================================================================
-- Confirm the integration is active and the IAM trust chain is configured.
-- =============================================================================

-- 4A. Verify integration exists and is enabled
SHOW INTEGRATIONS LIKE 'PA_S3_STORAGE_INTEGRATION';
-- Expected: One row. Check "enabled" = true, "type" = EXTERNAL_STAGE.

-- 4B. Verify the IAM user ARN and external ID match what you configured in AWS
DESCRIBE INTEGRATION PA_S3_STORAGE_INTEGRATION;
-- Expected: STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID match
-- the values you put in the AWS trust policy (Step 3B).

-- 4C. (Optional) Create a quick test external stage to validate end-to-end access
-- This stage references the integration. If the IAM trust chain is broken,
-- listing files will fail with an S3 access error.
--
-- CREATE OR REPLACE STAGE PA_DEV_DB.RAW.S3_TEST_STAGE
--   STORAGE_INTEGRATION = PA_S3_STORAGE_INTEGRATION
--   URL = 's3://<your-bucket-name>/<optional-prefix>/'
--   FILE_FORMAT = (TYPE = 'CSV');
--
-- LIST @PA_DEV_DB.RAW.S3_TEST_STAGE;
-- Expected: Returns a list of files in the S3 path (or empty if no files yet).
-- If you get "Access Denied" or "Credentials could not be verified", the IAM
-- trust policy or permissions policy is misconfigured — re-check Step 3B/3C.
--
-- Clean up test stage:
-- DROP STAGE IF EXISTS PA_DEV_DB.RAW.S3_TEST_STAGE;


-- =============================================================================
-- STEP 5: Verification — AWS Side
-- =============================================================================
-- These checks happen in the AWS Console or AWS CLI. Not executable in Snowflake.
--
-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │  5A. Verify the Trust Policy is correct                                    │
-- │                                                                            │
-- │  AWS Console → IAM → Roles → priorauthiq-snowflake-role → Trust tab       │
-- │                                                                            │
-- │  Confirm:                                                                  │
-- │  - The "Principal.AWS" matches STORAGE_AWS_IAM_USER_ARN from Step 2        │
-- │  - The "Condition.StringEquals.sts:ExternalId" matches                     │
-- │    STORAGE_AWS_EXTERNAL_ID from Step 2                                     │
-- │                                                                            │
-- │  Common mistake: Copy-pasting the ARN with trailing whitespace or          │
-- │  newlines. Trim carefully.                                                 │
-- └─────────────────────────────────────────────────────────────────────────────┘
--
-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │  5B. Verify the Permissions Policy grants S3 access                        │
-- │                                                                            │
-- │  AWS Console → IAM → Roles → priorauthiq-snowflake-role → Permissions tab │
-- │                                                                            │
-- │  Confirm:                                                                  │
-- │  - s3:GetObject and s3:GetObjectVersion on bucket/*                        │
-- │  - s3:ListBucket and s3:GetBucketLocation on bucket                        │
-- │  - (If unloading) s3:PutObject and s3:DeleteObject on bucket/*             │
-- │                                                                            │
-- │  Quick test with AWS CLI (optional):                                       │
-- │  aws sts assume-role \                                                     │
-- │    --role-arn arn:aws:iam::123456789012:role/priorauthiq-snowflake-role \   │
-- │    --role-session-name snowflake-test \                                    │
-- │    --external-id "<STORAGE_AWS_EXTERNAL_ID>"                               │
-- │                                                                            │
-- │  If this succeeds, the trust policy is correct. Then test S3 access:       │
-- │  aws s3 ls s3://<your-bucket-name>/ --profile <assumed-role-profile>       │
-- └─────────────────────────────────────────────────────────────────────────────┘
--
-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │  5C. Check S3 Bucket Policy (if applicable)                                │
-- │                                                                            │
-- │  If your S3 bucket has a bucket policy that restricts access, ensure it    │
-- │  does NOT deny the IAM role. A common pattern is a bucket policy that      │
-- │  denies all except specific principals — you must add Snowflake's IAM      │
-- │  role ARN to the allow list.                                               │
-- │                                                                            │
-- │  AWS Console → S3 → <bucket> → Permissions → Bucket policy                │
-- └─────────────────────────────────────────────────────────────────────────────┘
--
-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │  5D. Check S3 Block Public Access (if applicable)                          │
-- │                                                                            │
-- │  S3 "Block Public Access" settings do NOT affect IAM role-based access.    │
-- │  This is NOT the cause if you're getting "Access Denied" — look at the     │
-- │  trust policy and permissions policy instead.                              │
-- └─────────────────────────────────────────────────────────────────────────────┘


-- =============================================================================
-- TROUBLESHOOTING QUICK REFERENCE
-- =============================================================================
--
-- SYMPTOM                          | LIKELY CAUSE
-- ---------------------------------|-------------------------------------------
-- "Access Denied" on LIST @stage   | Trust policy Principal doesn't match
--                                  | STORAGE_AWS_IAM_USER_ARN, OR external ID
--                                  | mismatch, OR missing s3:ListBucket on the
--                                  | bucket-level resource.
--                                  |
-- "Credentials could not be        | STORAGE_AWS_ROLE_ARN in the integration
--  verified"                       | doesn't exist in AWS, or the role name is
--                                  | misspelled.
--                                  |
-- Integration shows ENABLED=FALSE  | Run:
--                                  | ALTER INTEGRATION PA_S3_STORAGE_INTEGRATION
--                                  |   SET ENABLED = TRUE;
--                                  |
-- "Insufficient privileges" on     | You need ACCOUNTADMIN to create/alter
-- CREATE STORAGE INTEGRATION       | storage integrations. Or grant:
--                                  | GRANT CREATE INTEGRATION ON ACCOUNT
--                                  |   TO ROLE <your_role>;
--                                  |
-- Can read files but COPY INTO     | Missing s3:GetObjectVersion if bucket
-- fails on specific files          | versioning is enabled.
--                                  |
-- Can read but cannot unload       | Missing s3:PutObject in the permissions
-- (COPY INTO <location>)           | policy.
-- =============================================================================


-- =============================================================================
-- NEXT STEPS (after verification passes)
-- =============================================================================
-- Once the integration is verified, you can:
--
-- 1. Create external stages that reference this integration:
--    CREATE STAGE PA_PROD_DB.RAW.S3_CLAIMS_STAGE
--      STORAGE_INTEGRATION = PA_S3_STORAGE_INTEGRATION
--      URL = 's3://<bucket>/claims/'
--      FILE_FORMAT = (FORMAT_NAME = 'PA_PROD_DB.RAW.CSV_FORMAT');
--
-- 2. Set up Snowpipe for automatic ingestion (Phase 7):
--    CREATE PIPE PA_PROD_DB.RAW.CLAIMS_PIPE
--      AUTO_INGEST = TRUE
--      AS COPY INTO PA_PROD_DB.RAW.CLAIMS
--      FROM @PA_PROD_DB.RAW.S3_CLAIMS_STAGE;
--
-- 3. Grant USAGE on the integration to SYSADMIN (so stages can be created
--    under SYSADMIN without needing ACCOUNTADMIN):
--    GRANT USAGE ON INTEGRATION PA_S3_STORAGE_INTEGRATION TO ROLE SYSADMIN;
-- =============================================================================
-- END OF TEMPLATE
-- =============================================================================
