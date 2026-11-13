
-- ============================================================
-- CyberNexus Access
-- Account Management and Access Control System
--
-- Brand: CyberNexus PH
-- Platform: CyberNexus Platform
-- Owner: Mark C. Pangilinan
-- Software Version: 0.0.1
-- Repository: cybernexus-access-v0
--
-- File: query.sql
-- Purpose: Reusable PostgreSQL queries
-- Database: PostgreSQL
--
-- Prerequisite:
-- 1. schema.sql
-- 2. data.sql
--
-- IMPORTANT:
-- $1, $2, $3 are parameter placeholders.
-- Execute through prepared statements or application code.
-- Never concatenate untrusted user input into SQL.
-- ============================================================


SET search_path TO cybernexus_access, public;


-- ============================================================
-- 1. USER REGISTRATION
-- ============================================================

-- 1.1 Check whether an email already exists.
-- Parameter: $1 = email

SELECT EXISTS (
    SELECT 1
    FROM users
    WHERE email_normalized = LOWER(BTRIM($1::TEXT))
) AS email_exists;


-- 1.2 Create a pending account.
-- Parameters:
-- $1 = full_name
-- $2 = email
-- $3 = Argon2id password hash

INSERT INTO users (
    full_name,
    email,
    password_hash,
    account_status
)
VALUES (
    $1,
    $2,
    $3,
    'pending'
)
RETURNING
    id,
    full_name,
    email,
    account_status,
    created_at;


-- ============================================================
-- 2. AUTHENTICATION
-- ============================================================

-- 2.1 Retrieve account credentials for backend verification.
-- Parameter: $1 = normalized email
--
-- The backend must verify the supplied password using
-- the Argon2id library. Never compare plaintext passwords
-- directly in SQL.

SELECT
    id,
    email,
    password_hash,
    account_status,
    email_verified_at,
    password_changed_at
FROM users
WHERE email_normalized = LOWER(BTRIM($1::TEXT));


-- 2.2 Update last login timestamp.
-- Parameter: $1 = user_id

UPDATE users
SET last_login_at = NOW()
WHERE id = $1::UUID
  AND account_status = 'approved'
RETURNING id, last_login_at;


-- 2.3 Create authentication session.
-- Parameters:
-- $1 = user_id
-- $2 = hashed session token
-- $3 = IP address
-- $4 = user agent
-- $5 = expiration timestamp

INSERT INTO sessions (
    user_id,
    token_hash,
    ip_address,
    user_agent,
    expires_at
)
SELECT
    u.id,
    $2,
    $3::INET,
    $4,
    $5::TIMESTAMPTZ
FROM users u
WHERE u.id = $1::UUID
  AND u.account_status = 'approved'
RETURNING
    id,
    user_id,
    expires_at;


-- 2.4 Validate an authentication session.
-- Parameter: $1 = hashed session token

SELECT
    s.id AS session_id,
    s.user_id,
    s.expires_at,
    u.account_status
FROM sessions s
JOIN users u ON u.id = s.user_id
WHERE s.token_hash = $1
  AND s.revoked_at IS NULL
  AND s.expires_at > NOW()
  AND u.account_status = 'approved';


-- 2.5 Revoke a specific session.
-- Parameters:
-- $1 = session_id
-- $2 = authenticated user_id

UPDATE sessions
SET revoked_at = NOW()
WHERE id = $1::UUID
  AND user_id = $2::UUID
  AND revoked_at IS NULL
RETURNING id, revoked_at;


-- 2.6 Revoke all sessions belonging to an account.
-- Parameter: $1 = user_id

UPDATE sessions
SET revoked_at = NOW()
WHERE user_id = $1::UUID
  AND revoked_at IS NULL
RETURNING id, revoked_at;


-- ============================================================
-- 3. PASSWORD RECOVERY
-- ============================================================

-- 3.1 Create password reset token.
-- Parameters:
-- $1 = user_id
-- $2 = hashed reset token
-- $3 = expiration timestamp

INSERT INTO password_reset_tokens (
    user_id,
    token_hash,
    expires_at
)
SELECT
    id,
    $2,
    $3::TIMESTAMPTZ
FROM users
WHERE id = $1::UUID
  AND account_status = 'approved'
RETURNING id, expires_at;


-- 3.2 Validate password reset token.
-- Parameter: $1 = hashed reset token

SELECT
    id,
    user_id,
    expires_at
FROM password_reset_tokens
WHERE token_hash = $1
  AND used_at IS NULL
  AND expires_at > NOW();


-- 3.3 Mark reset token as used.
-- Parameter: $1 = reset_token_id

UPDATE password_reset_tokens
SET used_at = NOW()
WHERE id = $1::UUID
  AND used_at IS NULL
  AND expires_at > NOW()
RETURNING id, used_at;


-- 3.4 Retrieve expired and used reset tokens for cleanup.

SELECT id
FROM password_reset_tokens
WHERE expires_at <= NOW()
   OR used_at IS NOT NULL;


-- ============================================================
-- 4. EMAIL VERIFICATION
-- ============================================================

-- 4.1 Create email verification token.
-- Parameters:
-- $1 = user_id
-- $2 = hashed verification token
-- $3 = expiration timestamp

INSERT INTO email_verification_tokens (
    user_id,
    token_hash,
    expires_at
)
VALUES (
    $1::UUID,
    $2,
    $3::TIMESTAMPTZ
)
RETURNING id, expires_at;


-- 4.2 Validate verification token.
-- Parameter: $1 = hashed verification token

SELECT
    id,
    user_id,
    expires_at
FROM email_verification_tokens
WHERE token_hash = $1
  AND used_at IS NULL
  AND expires_at > NOW();


-- 4.3 Verify user email.
-- Parameter: $1 = user_id

UPDATE users
SET email_verified_at = NOW()
WHERE id = $1::UUID
  AND email_verified_at IS NULL
RETURNING id, email_verified_at;


-- 4.4 Mark verification token as used.
-- Parameter: $1 = token_id

UPDATE email_verification_tokens
SET used_at = NOW()
WHERE id = $1::UUID
  AND used_at IS NULL
  AND expires_at > NOW()
RETURNING id, used_at;


-- ============================================================
-- 5. USER PROFILE
-- ============================================================

-- 5.1 Retrieve own profile.
-- Parameters:
-- $1 = authenticated user_id

SELECT
    id,
    full_name,
    email,
    account_status,
    email_verified_at,
    approved_at,
    created_at,
    last_login_at
FROM users
WHERE id = $1::UUID;


-- 5.2 Update own profile.
-- Parameters:
-- $1 = authenticated user_id
-- $2 = new full_name

UPDATE users
SET full_name = $2
WHERE id = $1::UUID
RETURNING
    id,
    full_name,
    email,
    updated_at;


-- 5.3 Retrieve own account settings.
-- Parameter: $1 = authenticated user_id

SELECT *
FROM account_settings
WHERE user_id = $1::UUID;


-- 5.4 Create default account settings.
-- Parameter: $1 = user_id

INSERT INTO account_settings (
    user_id
)
VALUES (
    $1::UUID
)
ON CONFLICT (user_id)
DO NOTHING
RETURNING *;


-- 5.5 Update account settings.
-- Parameters:
-- $1 = user_id
-- $2 = display_name
-- $3 = theme
-- $4 = language
-- $5 = notification_preferences JSON
-- $6 = interface_preferences JSON

INSERT INTO account_settings (
    user_id,
    display_name,
    theme,
    language,
    notification_preferences,
    interface_preferences
)
VALUES (
    $1::UUID,
    $2,
    $3,
    $4,
    $5::JSONB,
    $6::JSONB
)
ON CONFLICT (user_id)
DO UPDATE SET
    display_name = EXCLUDED.display_name,
    theme = EXCLUDED.theme,
    language = EXCLUDED.language,
    notification_preferences =
        EXCLUDED.notification_preferences,
    interface_preferences =
        EXCLUDED.interface_preferences
RETURNING *;


-- ============================================================
-- 6. REGISTRATION APPROVAL
-- ============================================================

-- 6.1 List pending registrations.
-- Parameters:
-- $1 = limit
-- $2 = offset

SELECT
    id,
    full_name,
    email,
    account_status,
    created_at
FROM users
WHERE account_status = 'pending'
ORDER BY created_at ASC
LIMIT $1
OFFSET $2;


-- 6.2 Approve a pending registration.
-- Parameters:
-- $1 = target_user_id
-- $2 = reviewer_user_id

UPDATE users
SET
    account_status = 'approved',
    approved_at = NOW(),
    approved_by = $2::UUID,
    rejected_at = NULL,
    rejected_by = NULL,
    rejection_reason = NULL
WHERE id = $1::UUID
  AND account_status = 'pending'
RETURNING
    id,
    account_status,
    approved_at,
    approved_by;


-- 6.3 Reject a pending registration.
-- Parameters:
-- $1 = target_user_id
-- $2 = reviewer_user_id
-- $3 = rejection_reason

UPDATE users
SET
    account_status = 'rejected',
    rejected_at = NOW(),
    rejected_by = $2::UUID,
    rejection_reason = $3
WHERE id = $1::UUID
  AND account_status = 'pending'
RETURNING
    id,
    account_status,
    rejected_at,
    rejected_by,
    rejection_reason;


-- ============================================================
-- 7. ADMINISTRATIVE ACCOUNT MANAGEMENT
-- ============================================================

-- 7.1 List accounts.
-- Parameters:
-- $1 = limit
-- $2 = offset

SELECT
    id,
    full_name,
    email,
    account_status,
    created_at,
    last_login_at
FROM users
ORDER BY created_at DESC
LIMIT $1
OFFSET $2;


-- 7.2 Search accounts by email or name.
-- Parameters:
-- $1 = search text

SELECT
    id,
    full_name,
    email,
    account_status,
    created_at
FROM users
WHERE full_name ILIKE '%' || $1 || '%'
   OR email_normalized ILIKE
        '%' || LOWER($1) || '%'
ORDER BY created_at DESC;


-- 7.3 Filter accounts by status.
-- Parameter: $1 = account_status

SELECT
    id,
    full_name,
    email,
    account_status,
    created_at
FROM users
WHERE account_status = $1
ORDER BY created_at DESC;


-- 7.4 Suspend an account.
-- Parameter: $1 = target_user_id

UPDATE users
SET
    account_status = 'suspended',
    suspended_at = NOW()
WHERE id = $1::UUID
  AND account_status = 'approved'
RETURNING id, account_status, suspended_at;


-- 7.5 Reactivate a suspended account.
-- Parameter: $1 = target_user_id

UPDATE users
SET
    account_status = 'approved',
    suspended_at = NULL
WHERE id = $1::UUID
  AND account_status = 'suspended'
RETURNING id, account_status;


-- 7.6 Deactivate an account.
-- Parameter: $1 = target_user_id

UPDATE users
SET
    account_status = 'deactivated',
    deactivated_at = NOW()
WHERE id = $1::UUID
  AND account_status IN (
      'approved',
      'suspended',
      'pending'
  )
RETURNING id, account_status, deactivated_at;


-- ============================================================
-- 8. ROLE-BASED ACCESS CONTROL
-- ============================================================

-- 8.1 Retrieve user roles.
-- Parameter: $1 = user_id

SELECT
    r.id,
    r.name,
    r.description
FROM user_roles ur
JOIN roles r ON r.id = ur.role_id
WHERE ur.user_id = $1::UUID;


-- 8.2 Retrieve user permissions.
-- Parameter: $1 = user_id

SELECT DISTINCT
    p.name,
    p.resource,
    p.action
FROM user_roles ur
JOIN role_permissions rp
    ON rp.role_id = ur.role_id
JOIN permissions p
    ON p.id = rp.permission_id
JOIN users u
    ON u.id = ur.user_id
WHERE ur.user_id = $1::UUID
  AND u.account_status = 'approved';


-- 8.3 Check whether user has a permission.
-- Parameters:
-- $1 = user_id
-- $2 = permission_name

SELECT EXISTS (
    SELECT 1
    FROM users u
    JOIN user_roles ur ON ur.user_id = u.id
    JOIN role_permissions rp ON rp.role_id = ur.role_id
    JOIN permissions p ON p.id = rp.permission_id
    WHERE u.id = $1::UUID
      AND u.account_status = 'approved'
      AND p.name = $2
) AS has_permission;


-- 8.4 Assign role to user.
-- Parameters:
-- $1 = target_user_id
-- $2 = role_id
-- $3 = administrator_user_id

INSERT INTO user_roles (
    user_id,
    role_id,
    assigned_by
)
VALUES (
    $1::UUID,
    $2::UUID,
    $3::UUID
)
ON CONFLICT (user_id, role_id)
DO NOTHING
RETURNING *;


-- 8.5 Revoke role from user.
-- Parameters:
-- $1 = target_user_id
-- $2 = role_id

DELETE FROM user_roles
WHERE user_id = $1::UUID
  AND role_id = $2::UUID
RETURNING *;


-- ============================================================
-- 9. AUDIT LOGGING
-- ============================================================

-- 9.1 Insert audit event.
-- Parameters:
-- $1 = actor_user_id (nullable)
-- $2 = target_user_id (nullable)
-- $3 = event_type
-- $4 = resource
-- $5 = action
-- $6 = outcome
-- $7 = description
-- $8 = IP address (nullable)
-- $9 = user agent (nullable)
-- $10 = metadata JSON

INSERT INTO audit_logs (
    actor_user_id,
    target_user_id,
    event_type,
    resource,
    action,
    outcome,
    description,
    ip_address,
    user_agent,
    metadata
)
VALUES (
    $1::UUID,
    $2::UUID,
    $3,
    $4,
    $5,
    $6,
    $7,
    $8::INET,
    $9,
    $10::JSONB
)
RETURNING id, event_type, outcome, created_at;


-- 9.2 Retrieve recent audit logs.
-- Parameters:
-- $1 = limit
-- $2 = offset

SELECT *
FROM audit_logs
ORDER BY created_at DESC
LIMIT $1
OFFSET $2;


-- 9.3 Retrieve audit logs for an account.
-- Parameters:
-- $1 = target_user_id
-- $2 = limit

SELECT *
FROM audit_logs
WHERE target_user_id = $1::UUID
ORDER BY created_at DESC
LIMIT $2;


-- 9.4 Filter audit logs by event type.
-- Parameter: $1 = event_type

SELECT *
FROM audit_logs
WHERE event_type = $1
ORDER BY created_at DESC;


-- ============================================================
-- 10. AI CONVERSATIONS
-- ============================================================

-- 10.1 Create AI conversation.
-- Parameters:
-- $1 = authenticated user_id
-- $2 = conversation title
-- $3 = model identifier

INSERT INTO ai_conversations (
    user_id,
    title,
    model_identifier
)
VALUES (
    $1::UUID,
    $2,
    $3
)
RETURNING *;


-- 10.2 Retrieve own AI conversations.
-- Parameters:
-- $1 = authenticated user_id
-- $2 = limit
-- $3 = offset

SELECT *
FROM ai_conversations
WHERE user_id = $1::UUID
ORDER BY updated_at DESC
LIMIT $2
OFFSET $3;


-- 10.3 Insert AI message.
-- Parameters:
-- $1 = conversation_id
-- $2 = role
-- $3 = content
-- $4 = model_identifier
-- $5 = input_tokens
-- $6 = output_tokens

INSERT INTO ai_messages (
    conversation_id,
    role,
    content,
    model_identifier,
    input_tokens,
    output_tokens
)
SELECT
    c.id,
    $2,
    $3,
    $4,
    $5,
    $6
FROM ai_conversations c
WHERE c.id = $1::UUID
RETURNING *;


-- 10.4 Retrieve conversation messages.
-- Parameters:
-- $1 = conversation_id
-- $2 = authenticated user_id

SELECT
    m.id,
    m.role,
    m.content,
    m.model_identifier,
    m.response_status,
    m.created_at
FROM ai_messages m
JOIN ai_conversations c
    ON c.id = m.conversation_id
WHERE c.id = $1::UUID
  AND c.user_id = $2::UUID
ORDER BY m.created_at ASC;


-- ============================================================
-- 11. DATABASE MAINTENANCE
-- ============================================================

-- 11.1 Remove expired sessions.
-- Execute through a controlled maintenance task.

DELETE FROM sessions
WHERE expires_at <= NOW();


-- 11.2 Remove expired password reset tokens.

DELETE FROM password_reset_tokens
WHERE expires_at <= NOW()
   OR used_at IS NOT NULL;


-- 11.3 Remove expired email verification tokens.

DELETE FROM email_verification_tokens
WHERE expires_at <= NOW()
   OR used_at IS NOT NULL;


-- 11.4 Retrieve database schema version.

SELECT
    software_name,
    software_version,
    schema_version,
    installed_at
FROM schema_metadata
WHERE id = 1;


-- ============================================================
-- END OF CYBERNEXUS ACCESS QUERIES
-- ============================================================
