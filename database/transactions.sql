
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
-- File: transactions.sql
-- Purpose: Multi-step database transaction references
-- Database: PostgreSQL
--
-- PREREQUISITES:
-- 1. schema.sql
-- 2. data.sql
--
-- IMPORTANT:
-- These are independent transaction templates.
-- $1, $2, etc. are application-supplied parameters.
--
-- Execute each transaction separately through the backend.
-- Do not execute every example as one SQL script.
--
-- SECURITY:
-- 1. Verify authentication and authorization in the backend.
-- 2. Use prepared statements and parameterized queries.
-- 3. Never store plaintext passwords or tokens.
-- 4. Generate and hash tokens in the backend.
-- 5. Verify Argon2id passwords in the backend.
-- 6. Enforce RBAC permissions before privileged operations.
-- 7. Protect the last active Administrator from removal.
--
-- TRANSACTION MANAGEMENT:
-- These templates show SQL transaction boundaries.
-- In the application, use SQLAlchemy-managed transactions.
-- Do not issue nested BEGIN/COMMIT statements inside
-- an already-managed SQLAlchemy transaction.
-- ============================================================


SET search_path TO cybernexus_access, public;


-- ============================================================
-- 1. USER REGISTRATION TRANSACTION
-- ============================================================
--
-- Parameters:
-- $1 = full_name
-- $2 = email
-- $3 = Argon2id password hash
--
-- Expected result:
-- 1. Create pending account.
-- 2. Initialize default account settings.
-- 3. Record registration event.
--
-- Email verification token generation and delivery
-- should be handled separately by the backend.
-- ============================================================

BEGIN;

WITH new_user AS (
    INSERT INTO users (
        full_name,
        email,
        password_hash,
        account_status
    )
    VALUES (
        BTRIM($1::TEXT),
        BTRIM($2::TEXT),
        $3::TEXT,
        'pending'
    )
    RETURNING
        id,
        full_name,
        email,
        account_status
),
new_settings AS (
    INSERT INTO account_settings (
        user_id
    )
    SELECT id
    FROM new_user
    RETURNING user_id
),
audit_event AS (
    INSERT INTO audit_logs (
        actor_user_id,
        target_user_id,
        event_type,
        resource,
        action,
        outcome,
        description
    )
    SELECT
        NULL,
        u.id,
        'account.registration',
        'account',
        'create',
        'success',
        'New account registration submitted.'
    FROM new_user u
    JOIN new_settings s
        ON s.user_id = u.id
    RETURNING id
)
SELECT
    u.id,
    u.full_name,
    u.email,
    u.account_status
FROM new_user u
CROSS JOIN audit_event;

COMMIT;


-- ============================================================
-- 2. LOGIN SESSION TRANSACTION
-- ============================================================
--
-- Parameters:
-- $1 = authenticated user_id
-- $2 = hashed session token
-- $3 = IP address
-- $4 = user agent
-- $5 = expiration timestamp
--
-- Password verification happens in the backend BEFORE
-- this transaction.
--
-- Only approved accounts can create authentication sessions.
-- ============================================================

BEGIN;

WITH authenticated_user AS (
    UPDATE users
    SET last_login_at = NOW()
    WHERE id = $1::UUID
      AND account_status = 'approved'
    RETURNING id
),
new_session AS (
    INSERT INTO sessions (
        user_id,
        token_hash,
        ip_address,
        user_agent,
        expires_at
    )
    SELECT
        id,
        $2::TEXT,
        $3::INET,
        $4::TEXT,
        $5::TIMESTAMPTZ
    FROM authenticated_user
    RETURNING
        id,
        user_id,
        expires_at,
        created_at
),
audit_event AS (
    INSERT INTO audit_logs (
        actor_user_id,
        target_user_id,
        event_type,
        resource,
        action,
        outcome,
        description,
        ip_address,
        user_agent
    )
    SELECT
        user_id,
        user_id,
        'authentication.login',
        'session',
        'create',
        'success',
        'User authenticated and session created.',
        $3::INET,
        $4::TEXT
    FROM new_session
    RETURNING id
)
SELECT
    s.id,
    s.user_id,
    s.expires_at,
    s.created_at
FROM new_session s
CROSS JOIN audit_event;

COMMIT;


-- ============================================================
-- 3. LOGOUT TRANSACTION
-- ============================================================
--
-- Parameters:
-- $1 = session_id
-- $2 = authenticated user_id
-- ============================================================

BEGIN;

WITH revoked_session AS (
    UPDATE sessions
    SET revoked_at = NOW()
    WHERE id = $1::UUID
      AND user_id = $2::UUID
      AND revoked_at IS NULL
    RETURNING user_id
),
audit_event AS (
    INSERT INTO audit_logs (
        actor_user_id,
        target_user_id,
        event_type,
        resource,
        action,
        outcome,
        description
    )
    SELECT
        user_id,
        user_id,
        'authentication.logout',
        'session',
        'revoke',
        'success',
        'User session revoked.'
    FROM revoked_session
    RETURNING id
)
SELECT id
FROM audit_event;

COMMIT;


-- ============================================================
-- 4. PASSWORD RESET TRANSACTION
-- ============================================================
--
-- Parameters:
-- $1 = hashed reset token
-- $2 = new Argon2id password hash
--
-- Expected result:
-- 1. Lock and validate reset token.
-- 2. Update account password.
-- 3. Consume reset token.
-- 4. Revoke all active sessions.
-- 5. Record audit event.
--
-- The token is consumed only if the password update succeeds.
-- ============================================================

BEGIN;

WITH candidate_token AS (
    SELECT
        id,
        user_id
    FROM password_reset_tokens
    WHERE token_hash = $1::TEXT
      AND used_at IS NULL
      AND expires_at > NOW()
    FOR UPDATE
),
updated_user AS (
    UPDATE users u
    SET
        password_hash = $2::TEXT,
        password_changed_at = NOW()
    FROM candidate_token ct
    WHERE u.id = ct.user_id
      AND u.account_status = 'approved'
    RETURNING u.id
),
consumed_token AS (
    UPDATE password_reset_tokens t
    SET used_at = NOW()
    FROM candidate_token ct
    JOIN updated_user u
        ON u.id = ct.user_id
    WHERE t.id = ct.id
      AND t.used_at IS NULL
    RETURNING t.id, t.user_id
),
revoked_sessions AS (
    UPDATE sessions s
    SET revoked_at = NOW()
    FROM updated_user u
    WHERE s.user_id = u.id
      AND s.revoked_at IS NULL
    RETURNING s.id
),
audit_event AS (
    INSERT INTO audit_logs (
        actor_user_id,
        target_user_id,
        event_type,
        resource,
        action,
        outcome,
        description
    )
    SELECT
        NULL,
        ct.user_id,
        'account.password_reset',
        'account',
        'update',
        'success',
        'Account password reset successfully. Existing sessions revoked.'
    FROM consumed_token ct
    RETURNING id
)
SELECT
    ct.user_id,
    ct.id AS consumed_token_id
FROM consumed_token ct
CROSS JOIN audit_event;

COMMIT;


-- ============================================================
-- 5. EMAIL VERIFICATION TRANSACTION
-- ============================================================
--
-- Parameters:
-- $1 = hashed verification token
--
-- Expected result:
-- 1. Lock and validate verification token.
-- 2. Verify account email.
-- 3. Consume verification token.
-- 4. Record audit event.
--
-- The token is consumed only if email verification succeeds.
-- ============================================================

BEGIN;

WITH candidate_token AS (
    SELECT
        id,
        user_id
    FROM email_verification_tokens
    WHERE token_hash = $1::TEXT
      AND used_at IS NULL
      AND expires_at > NOW()
    FOR UPDATE
),
verified_user AS (
    UPDATE users u
    SET email_verified_at = NOW()
    FROM candidate_token ct
    WHERE u.id = ct.user_id
      AND u.email_verified_at IS NULL
    RETURNING
        u.id,
        u.email,
        u.email_verified_at
),
consumed_token AS (
    UPDATE email_verification_tokens t
    SET used_at = NOW()
    FROM candidate_token ct
    JOIN verified_user u
        ON u.id = ct.user_id
    WHERE t.id = ct.id
      AND t.used_at IS NULL
    RETURNING t.id, t.user_id
),
audit_event AS (
    INSERT INTO audit_logs (
        actor_user_id,
        target_user_id,
        event_type,
        resource,
        action,
        outcome,
        description
    )
    SELECT
        u.id,
        u.id,
        'account.email_verification',
        'account',
        'verify',
        'success',
        'Email address verified.'
    FROM verified_user u
    JOIN consumed_token ct
        ON ct.user_id = u.id
    RETURNING id
)
SELECT
    u.id,
    u.email,
    u.email_verified_at
FROM verified_user u
CROSS JOIN consumed_token ct
CROSS JOIN audit_event;

COMMIT;


-- ============================================================
-- 6. APPROVE REGISTRATION TRANSACTION
-- ============================================================
--
-- Parameters:
-- $1 = target_user_id
-- $2 = authenticated reviewer_user_id
--
-- Backend must verify registration.approve permission.
-- Self-approval is not allowed by this template.
-- ============================================================

BEGIN;

WITH approved_user AS (
    UPDATE users target
    SET
        account_status = 'approved',
        approved_at = NOW(),
        approved_by = reviewer.id,
        rejected_at = NULL,
        rejected_by = NULL,
        rejection_reason = NULL,
        suspended_at = NULL,
        deactivated_at = NULL
    FROM users reviewer
    WHERE target.id = $1::UUID
      AND reviewer.id = $2::UUID
      AND target.account_status = 'pending'
      AND reviewer.account_status = 'approved'
      AND target.id <> reviewer.id
    RETURNING target.id
),
audit_event AS (
    INSERT INTO audit_logs (
        actor_user_id,
        target_user_id,
        event_type,
        resource,
        action,
        outcome,
        description
    )
    SELECT
        $2::UUID,
        id,
        'registration.approval',
        'registration',
        'approve',
        'success',
        'Registration approved.'
    FROM approved_user
    RETURNING id
)
SELECT id
FROM approved_user
CROSS JOIN audit_event;

COMMIT;


-- ============================================================
-- 7. REJECT REGISTRATION TRANSACTION
-- ============================================================
--
-- Parameters:
-- $1 = target_user_id
-- $2 = authenticated reviewer_user_id
-- $3 = rejection_reason
--
-- Backend must verify registration.reject permission.
-- Self-review is not allowed by this template.
-- ============================================================

BEGIN;

WITH rejected_user AS (
    UPDATE users target
    SET
        account_status = 'rejected',
        rejected_at = NOW(),
        rejected_by = reviewer.id,
        rejection_reason = BTRIM($3::TEXT)
    FROM users reviewer
    WHERE target.id = $1::UUID
      AND reviewer.id = $2::UUID
      AND target.account_status = 'pending'
      AND reviewer.account_status = 'approved'
      AND target.id <> reviewer.id
      AND LENGTH(BTRIM($3::TEXT)) > 0
    RETURNING target.id
),
audit_event AS (
    INSERT INTO audit_logs (
        actor_user_id,
        target_user_id,
        event_type,
        resource,
        action,
        outcome,
        description,
        metadata
    )
    SELECT
        $2::UUID,
        id,
        'registration.rejection',
        'registration',
        'reject',
        'success',
        'Registration rejected.',
        JSONB_BUILD_OBJECT(
            'reason',
            BTRIM($3::TEXT)
        )
    FROM rejected_user
    RETURNING id
)
SELECT id
FROM rejected_user
CROSS JOIN audit_event;

COMMIT;


-- ============================================================
-- 8. ROLE ASSIGNMENT TRANSACTION
-- ============================================================
--
-- Parameters:
-- $1 = target_user_id
-- $2 = role_id
-- $3 = administrator_user_id
--
-- Backend must verify admin.roles.assign permission.
-- Self-role assignment is not allowed by this template.
-- Protect against privilege escalation and last-admin lockout.
-- ============================================================

BEGIN;

WITH assigned_role AS (
    INSERT INTO user_roles (
        user_id,
        role_id,
        assigned_by
    )
    SELECT
        target.id,
        r.id,
        actor.id
    FROM users target
    JOIN roles r
        ON r.id = $2::UUID
    JOIN users actor
        ON actor.id = $3::UUID
    WHERE target.id = $1::UUID
      AND target.account_status = 'approved'
      AND actor.account_status = 'approved'
      AND target.id <> actor.id
    ON CONFLICT (user_id, role_id)
    DO NOTHING
    RETURNING
        user_id,
        role_id
),
audit_event AS (
    INSERT INTO audit_logs (
        actor_user_id,
        target_user_id,
        event_type,
        resource,
        action,
        outcome,
        description,
        metadata
    )
    SELECT
        $3::UUID,
        ar.user_id,
        'authorization.role_assignment',
        'role',
        'assign',
        'success',
        'Role assigned to account.',
        JSONB_BUILD_OBJECT(
            'role_id',
            ar.role_id
        )
    FROM assigned_role ar
    RETURNING id
)
SELECT
    ar.user_id,
    ar.role_id
FROM assigned_role ar
CROSS JOIN audit_event;

COMMIT;


-- ============================================================
-- 9. ROLE REVOCATION TRANSACTION
-- ============================================================
--
-- Parameters:
-- $1 = target_user_id
-- $2 = role_id
-- $3 = administrator_user_id
--
-- Backend must verify admin.roles.revoke permission.
-- Protect the last active Administrator.
-- ============================================================

BEGIN;

WITH revoked_role AS (
    DELETE FROM user_roles ur
    USING users actor
    WHERE ur.user_id = $1::UUID
      AND ur.role_id = $2::UUID
      AND actor.id = $3::UUID
      AND actor.account_status = 'approved'
      AND ur.user_id <> actor.id
    RETURNING
        ur.user_id,
        ur.role_id
),
audit_event AS (
    INSERT INTO audit_logs (
        actor_user_id,
        target_user_id,
        event_type,
        resource,
        action,
        outcome,
        description,
        metadata
    )
    SELECT
        $3::UUID,
        rr.user_id,
        'authorization.role_revocation',
        'role',
        'revoke',
        'success',
        'Role revoked from account.',
        JSONB_BUILD_OBJECT(
            'role_id',
            rr.role_id
        )
    FROM revoked_role rr
    RETURNING id
)
SELECT
    rr.user_id,
    rr.role_id
FROM revoked_role rr
CROSS JOIN audit_event;

COMMIT;


-- ============================================================
-- 10. ACCOUNT SUSPENSION TRANSACTION
-- ============================================================
--
-- Parameters:
-- $1 = target_user_id
-- $2 = administrator_user_id
--
-- Expected result:
-- 1. Suspend approved account.
-- 2. Revoke active sessions.
-- 3. Record audit event.
--
-- Backend must verify admin.accounts.suspend permission.
-- Self-suspension is not allowed by this template.
-- ============================================================

BEGIN;

WITH suspended_user AS (
    UPDATE users target
    SET
        account_status = 'suspended',
        suspended_at = NOW()
    FROM users actor
    WHERE target.id = $1::UUID
      AND actor.id = $2::UUID
      AND target.account_status = 'approved'
      AND actor.account_status = 'approved'
      AND target.id <> actor.id
    RETURNING target.id
),
revoked_sessions AS (
    UPDATE sessions s
    SET revoked_at = NOW()
    FROM suspended_user su
    WHERE s.user_id = su.id
      AND s.revoked_at IS NULL
    RETURNING s.id
),
audit_event AS (
    INSERT INTO audit_logs (
        actor_user_id,
        target_user_id,
        event_type,
        resource,
        action,
        outcome,
        description
    )
    SELECT
        $2::UUID,
        id,
        'account.suspension',
        'account',
        'suspend',
        'success',
        'Account suspended and active sessions revoked.'
    FROM suspended_user
    RETURNING id
)
SELECT id
FROM suspended_user
CROSS JOIN audit_event;

COMMIT;


-- ============================================================
-- 11. ACCOUNT REACTIVATION TRANSACTION
-- ============================================================
--
-- Parameters:
-- $1 = target_user_id
-- $2 = administrator_user_id
--
-- Expected result:
-- 1. Reactivate suspended account.
-- 2. Clear current suspension timestamp.
-- 3. Record audit event.
--
-- Existing sessions remain revoked.
-- The user must authenticate again.
--
-- Backend must verify admin.accounts.activate permission.
-- ============================================================

BEGIN;

WITH reactivated_user AS (
    UPDATE users target
    SET
        account_status = 'approved',
        suspended_at = NULL
    FROM users actor
    WHERE target.id = $1::UUID
      AND actor.id = $2::UUID
      AND target.account_status = 'suspended'
      AND actor.account_status = 'approved'
      AND target.id <> actor.id
    RETURNING target.id
),
audit_event AS (
    INSERT INTO audit_logs (
        actor_user_id,
        target_user_id,
        event_type,
        resource,
        action,
        outcome,
        description
    )
    SELECT
        $2::UUID,
        id,
        'account.reactivation',
        'account',
        'activate',
        'success',
        'Suspended account reactivated.'
    FROM reactivated_user
    RETURNING id
)
SELECT id
FROM reactivated_user
CROSS JOIN audit_event;

COMMIT;


-- ============================================================
-- 12. ACCOUNT DEACTIVATION TRANSACTION
-- ============================================================
--
-- Parameters:
-- $1 = target_user_id
-- $2 = administrator_user_id
--
-- Expected result:
-- 1. Deactivate eligible account.
-- 2. Revoke active sessions.
-- 3. Record audit event.
--
-- Backend must verify admin.accounts.deactivate permission.
-- Self-deactivation is not allowed by this template.
-- ============================================================

BEGIN;

WITH deactivated_user AS (
    UPDATE users target
    SET
        account_status = 'deactivated',
        deactivated_at = NOW()
    FROM users actor
    WHERE target.id = $1::UUID
      AND actor.id = $2::UUID
      AND target.account_status IN (
          'approved',
          'suspended',
          'pending'
      )
      AND actor.account_status = 'approved'
      AND target.id <> actor.id
    RETURNING target.id
),
revoked_sessions AS (
    UPDATE sessions s
    SET revoked_at = NOW()
    FROM deactivated_user du
    WHERE s.user_id = du.id
      AND s.revoked_at IS NULL
    RETURNING s.id
),
audit_event AS (
    INSERT INTO audit_logs (
        actor_user_id,
        target_user_id,
        event_type,
        resource,
        action,
        outcome,
        description
    )
    SELECT
        $2::UUID,
        id,
        'account.deactivation',
        'account',
        'deactivate',
        'success',
        'Account deactivated and active sessions revoked.'
    FROM deactivated_user
    RETURNING id
)
SELECT id
FROM deactivated_user
CROSS JOIN audit_event;

COMMIT;


-- ============================================================
-- 13. AI CONVERSATION TRANSACTION
-- ============================================================
--
-- Parameters:
-- $1 = authenticated user_id
-- $2 = conversation title
-- $3 = model identifier
-- $4 = user message
-- $5 = AI response
-- $6 = input tokens
-- $7 = output tokens
--
-- The actual AI inference must happen in the backend.
-- This transaction only persists the completed conversation.
--
-- Both messages are stored in the same transaction.
-- ============================================================

BEGIN;

WITH eligible_user AS (
    SELECT id
    FROM users
    WHERE id = $1::UUID
      AND account_status = 'approved'
),
new_conversation AS (
    INSERT INTO ai_conversations (
        user_id,
        title,
        model_identifier
    )
    SELECT
        id,
        $2::TEXT,
        $3::TEXT
    FROM eligible_user
    RETURNING
        id,
        user_id
),
user_message AS (
    INSERT INTO ai_messages (
        conversation_id,
        role,
        content,
        model_identifier,
        response_status
    )
    SELECT
        id,
        'user',
        $4::TEXT,
        $3::TEXT,
        'completed'
    FROM new_conversation
    RETURNING conversation_id
),
assistant_message AS (
    INSERT INTO ai_messages (
        conversation_id,
        role,
        content,
        model_identifier,
        input_tokens,
        output_tokens,
        response_status
    )
    SELECT
        nc.id,
        'assistant',
        $5::TEXT,
        $3::TEXT,
        $6::INTEGER,
        $7::INTEGER,
        'completed'
    FROM new_conversation nc
    JOIN user_message um
        ON um.conversation_id = nc.id
    RETURNING
        conversation_id,
        id AS message_id
),
updated_conversation AS (
    UPDATE ai_conversations c
    SET updated_at = NOW()
    FROM assistant_message am
    WHERE c.id = am.conversation_id
    RETURNING
        c.id,
        c.user_id,
        c.title,
        c.model_identifier,
        c.updated_at
)
SELECT
    c.id AS conversation_id,
    c.user_id,
    c.title,
    c.model_identifier,
    c.updated_at,
    am.message_id AS assistant_message_id
FROM updated_conversation c
JOIN assistant_message am
    ON am.conversation_id = c.id;

COMMIT;


-- ============================================================
-- 14. ACCOUNT PROFILE UPDATE TRANSACTION
-- ============================================================
--
-- Parameters:
-- $1 = authenticated user_id
-- $2 = new full_name
-- $3 = new display_name
--
-- Expected result:
-- 1. Update user profile.
-- 2. Create or update account settings.
-- 3. Commit both changes together.
-- ============================================================

BEGIN;

WITH updated_profile AS (
    UPDATE users
    SET full_name = BTRIM($2::TEXT)
    WHERE id = $1::UUID
      AND LENGTH(BTRIM($2::TEXT)) > 0
    RETURNING id
),
updated_settings AS (
    INSERT INTO account_settings (
        user_id,
        display_name
    )
    SELECT
        id,
        BTRIM($3::TEXT)
    FROM updated_profile
    ON CONFLICT (user_id)
    DO UPDATE SET
        display_name = EXCLUDED.display_name
    RETURNING
        user_id,
        display_name,
        updated_at
)
SELECT
    p.id AS user_id,
    s.display_name,
    s.updated_at
FROM updated_profile p
JOIN updated_settings s
    ON s.user_id = p.id;

COMMIT;


-- ============================================================
-- END OF CYBERNEXUS ACCESS TRANSACTIONS
-- ============================================================
