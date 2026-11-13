
-- ============================================================
-- CyberNexus Access
-- Account Management and Access Control System
--
-- Brand: CyberNexus PH
-- Platform: CyberNexus Platform
-- System: CyberNexus Access
-- Owner: Mark C. Pangilinan
-- Software Version: 0.0.1
-- Repository: cybernexus-access-v0
-- Database: PostgreSQL
--
-- File: schema.sql
-- Purpose: Initial database structure
--
-- IMPORTANT:
-- 1. This file defines database structure only.
-- 2. Initial roles and permissions belong in data.sql.
-- 3. Production schema changes must use Alembic migrations.
-- 4. Passwords must be hashed using Argon2id in the backend.
-- 5. Tokens must be cryptographically generated and hashed
--    before being stored.
-- ============================================================


-- ============================================================
-- 1. DATABASE SCHEMA
-- ============================================================

CREATE SCHEMA IF NOT EXISTS cybernexus_access;

SET search_path TO cybernexus_access, public;


-- ============================================================
-- 2. USERS
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    full_name VARCHAR(150) NOT NULL,

    username VARCHAR(32) NOT NULL,

    phone VARCHAR(20) NOT NULL,

    email VARCHAR(254) NOT NULL,

    email_normalized VARCHAR(254)
        GENERATED ALWAYS AS (LOWER(BTRIM(email))) STORED,

    password_hash VARCHAR(255) NOT NULL,

    account_status VARCHAR(20) NOT NULL
        DEFAULT 'pending',

    email_verified_at TIMESTAMPTZ,

    approved_at TIMESTAMPTZ,

    approved_by UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    rejected_at TIMESTAMPTZ,

    rejected_by UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    rejection_reason TEXT,

    suspended_at TIMESTAMPTZ,

    deactivated_at TIMESTAMPTZ,

    last_login_at TIMESTAMPTZ,

    password_changed_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_users_email
        UNIQUE (email_normalized),

    CONSTRAINT uq_users_username
        UNIQUE (username),

    CONSTRAINT uq_users_phone
        UNIQUE (phone),

    CONSTRAINT chk_users_full_name
        CHECK (BTRIM(full_name) <> ''),

    CONSTRAINT chk_users_username
        CHECK (username ~ '^[A-Za-z0-9._-]{3,32}
    CONSTRAINT chk_users_email
        CHECK (
            email = BTRIM(email)
            AND POSITION('@' IN email) > 1
        ),

    CONSTRAINT chk_users_password_hash
        CHECK (BTRIM(password_hash) <> ''),

    CONSTRAINT chk_users_account_status
        CHECK (
            account_status IN (
                'pending',
                'approved',
                'rejected',
                'suspended',
                'deactivated'
            )
        ),

    CONSTRAINT chk_users_approval
        CHECK (
            account_status <> 'approved'
            OR approved_at IS NOT NULL
        ),

    CONSTRAINT chk_users_rejection
        CHECK (
            account_status <> 'rejected'
            OR rejected_at IS NOT NULL
        ),

    CONSTRAINT chk_users_suspension
        CHECK (
            account_status <> 'suspended'
            OR suspended_at IS NOT NULL
        ),

    CONSTRAINT chk_users_deactivation
        CHECK (
            account_status <> 'deactivated'
            OR deactivated_at IS NOT NULL
        )
);


CREATE INDEX IF NOT EXISTS idx_users_status
    ON users(account_status);

CREATE INDEX IF NOT EXISTS idx_users_created_at
    ON users(created_at DESC);


-- ============================================================
-- 3. ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(50) NOT NULL UNIQUE,

    description TEXT,

    is_system_role BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 4. PERMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(100) NOT NULL UNIQUE,

    resource VARCHAR(100) NOT NULL,

    action VARCHAR(50) NOT NULL,

    description TEXT,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_permissions_resource_action
        UNIQUE (resource, action)
);


-- ============================================================
-- 5. USER ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    role_id UUID NOT NULL
        REFERENCES roles(id)
        ON DELETE RESTRICT,

    assigned_by UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    assigned_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_user_roles
        UNIQUE (user_id, role_id)
);


CREATE INDEX IF NOT EXISTS idx_user_roles_user_id
    ON user_roles(user_id);

CREATE INDEX IF NOT EXISTS idx_user_roles_role_id
    ON user_roles(role_id);


-- ============================================================
-- 6. ROLE PERMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    role_id UUID NOT NULL
        REFERENCES roles(id)
        ON DELETE CASCADE,

    permission_id UUID NOT NULL
        REFERENCES permissions(id)
        ON DELETE CASCADE,

    assigned_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_role_permissions
        UNIQUE (role_id, permission_id)
);


-- ============================================================
-- 7. AUTHENTICATION SESSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    token_hash VARCHAR(255) NOT NULL UNIQUE,

    ip_address INET,

    user_agent TEXT,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    last_activity_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    expires_at TIMESTAMPTZ NOT NULL,

    revoked_at TIMESTAMPTZ,

    CONSTRAINT chk_sessions_expiration
        CHECK (expires_at > created_at),

    CONSTRAINT chk_sessions_revocation
        CHECK (
            revoked_at IS NULL
            OR revoked_at >= created_at
        )
);


CREATE INDEX IF NOT EXISTS idx_sessions_user_id
    ON sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_sessions_expires_at
    ON sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_sessions_active
    ON sessions(user_id, expires_at)
    WHERE revoked_at IS NULL;


-- ============================================================
-- 8. PASSWORD RESET TOKENS
-- ============================================================

CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    token_hash VARCHAR(255) NOT NULL UNIQUE,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    expires_at TIMESTAMPTZ NOT NULL,

    used_at TIMESTAMPTZ,

    CONSTRAINT chk_password_reset_expiration
        CHECK (expires_at > created_at),

    CONSTRAINT chk_password_reset_used
        CHECK (
            used_at IS NULL
            OR used_at >= created_at
        )
);


CREATE INDEX IF NOT EXISTS idx_password_reset_user
    ON password_reset_tokens(user_id);


-- ============================================================
-- 9. EMAIL VERIFICATION TOKENS
-- ============================================================

CREATE TABLE IF NOT EXISTS email_verification_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    token_hash VARCHAR(255) NOT NULL UNIQUE,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    expires_at TIMESTAMPTZ NOT NULL,

    used_at TIMESTAMPTZ,

    CONSTRAINT chk_email_verification_expiration
        CHECK (expires_at > created_at),

    CONSTRAINT chk_email_verification_used
        CHECK (
            used_at IS NULL
            OR used_at >= created_at
        )
);


CREATE INDEX IF NOT EXISTS idx_email_verification_user
    ON email_verification_tokens(user_id);


-- ============================================================
-- 10. ACCOUNT SETTINGS
-- ============================================================

CREATE TABLE IF NOT EXISTS account_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL UNIQUE
        REFERENCES users(id)
        ON DELETE CASCADE,

    display_name VARCHAR(150),

    theme VARCHAR(20)
        NOT NULL DEFAULT 'system',

    language VARCHAR(20)
        NOT NULL DEFAULT 'en',

    notification_preferences JSONB
        NOT NULL DEFAULT '{}'::JSONB,

    interface_preferences JSONB
        NOT NULL DEFAULT '{}'::JSONB,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_account_settings_theme
        CHECK (
            theme IN ('light', 'dark', 'system')
        ),

    CONSTRAINT chk_notification_preferences
        CHECK (
            jsonb_typeof(notification_preferences) = 'object'
        ),

    CONSTRAINT chk_interface_preferences
        CHECK (
            jsonb_typeof(interface_preferences) = 'object'
        )
);


-- ============================================================
-- 11. AI CONVERSATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    title VARCHAR(200),

    model_identifier VARCHAR(150),

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW()
);


CREATE INDEX IF NOT EXISTS idx_ai_conversations_user
    ON ai_conversations(user_id, updated_at DESC);


-- ============================================================
-- 12. AI MESSAGES
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    conversation_id UUID NOT NULL
        REFERENCES ai_conversations(id)
        ON DELETE CASCADE,

    role VARCHAR(20) NOT NULL,

    content TEXT NOT NULL,

    model_identifier VARCHAR(150),

    input_tokens INTEGER,

    output_tokens INTEGER,

    response_status VARCHAR(20)
        NOT NULL DEFAULT 'completed',

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_ai_message_role
        CHECK (
            role IN ('user', 'assistant')
        ),

    CONSTRAINT chk_ai_message_status
        CHECK (
            response_status IN (
                'pending',
                'completed',
                'failed'
            )
        ),

    CONSTRAINT chk_ai_message_input_tokens
        CHECK (
            input_tokens IS NULL OR input_tokens >= 0
        ),

    CONSTRAINT chk_ai_message_output_tokens
        CHECK (
            output_tokens IS NULL OR output_tokens >= 0
        )
);


CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation
    ON ai_messages(conversation_id, created_at);


-- ============================================================
-- 13. AUDIT LOGS
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    actor_user_id UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    target_user_id UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    event_type VARCHAR(100) NOT NULL,

    resource VARCHAR(100),

    action VARCHAR(50),

    outcome VARCHAR(30) NOT NULL,

    description TEXT,

    ip_address INET,

    user_agent TEXT,

    metadata JSONB
        NOT NULL DEFAULT '{}'::JSONB,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_audit_outcome
        CHECK (
            outcome IN (
                'success',
                'failure',
                'denied',
                'warning'
            )
        ),

    CONSTRAINT chk_audit_metadata
        CHECK (
            jsonb_typeof(metadata) = 'object'
        )
);


CREATE INDEX IF NOT EXISTS idx_audit_logs_actor
    ON audit_logs(actor_user_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_target
    ON audit_logs(target_user_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_event
    ON audit_logs(event_type);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created
    ON audit_logs(created_at DESC);


-- ============================================================
-- 14. AUTHENTICATION RATE LIMIT BUCKETS
-- ============================================================

CREATE TABLE IF NOT EXISTS auth_rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    key_hash VARCHAR(255) NOT NULL,

    scope VARCHAR(50) NOT NULL,

    window_started_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    attempts INTEGER NOT NULL DEFAULT 0,

    blocked_until TIMESTAMPTZ,

    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_auth_rate_limit_key_scope
        UNIQUE (key_hash, scope),

    CONSTRAINT chk_auth_rate_limit_attempts
        CHECK (attempts >= 0)
);


CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_blocked
    ON auth_rate_limits(blocked_until);


-- ============================================================
-- 15. DATABASE VERSION TRACKING
-- ============================================================

CREATE TABLE IF NOT EXISTS schema_metadata (
    id INTEGER PRIMARY KEY,

    software_name VARCHAR(100) NOT NULL,

    software_version VARCHAR(20) NOT NULL,

    schema_version VARCHAR(50) NOT NULL,

    installed_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_schema_metadata_singleton
        CHECK (id = 1)
);


-- ============================================================
-- 16. UPDATED_AT AUTOMATIC TIMESTAMP FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION cybernexus_access.update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


-- ============================================================
-- 17. UPDATED_AT TRIGGERS
-- ============================================================

DROP TRIGGER IF EXISTS trg_users_updated_at
    ON users;

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


DROP TRIGGER IF EXISTS trg_account_settings_updated_at
    ON account_settings;

CREATE TRIGGER trg_account_settings_updated_at
BEFORE UPDATE ON account_settings
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


DROP TRIGGER IF EXISTS trg_ai_conversations_updated_at
    ON ai_conversations;

CREATE TRIGGER trg_ai_conversations_updated_at
BEFORE UPDATE ON ai_conversations
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


DROP TRIGGER IF EXISTS trg_auth_rate_limits_updated_at
    ON auth_rate_limits;

CREATE TRIGGER trg_auth_rate_limits_updated_at
BEFORE UPDATE ON auth_rate_limits
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


-- ============================================================
-- 18. AUDIT LOG IMMUTABILITY
-- ============================================================

CREATE OR REPLACE FUNCTION cybernexus_access.prevent_audit_modification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'Audit logs cannot be updated or deleted';
END;
$$;


DROP TRIGGER IF EXISTS trg_audit_logs_immutable
    ON audit_logs;

CREATE TRIGGER trg_audit_logs_immutable
BEFORE UPDATE OR DELETE ON audit_logs
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.prevent_audit_modification();


-- ============================================================
-- 19. INITIAL SCHEMA METADATA
-- ============================================================

INSERT INTO schema_metadata (
    id,
    software_name,
    software_version,
    schema_version
)
VALUES (
    1,
    'CyberNexus Access',
    '0.0.1',
    '0.0.1'
)
ON CONFLICT (id) DO NOTHING;


-- ============================================================
-- END OF CYBERNEXUS ACCESS SCHEMA
-- ============================================================
),

    CONSTRAINT chk_users_phone
        CHECK (BTRIM(phone) <> ''),

    CONSTRAINT chk_users_email
        CHECK (
            email = BTRIM(email)
            AND POSITION('@' IN email) > 1
        ),

    CONSTRAINT chk_users_password_hash
        CHECK (BTRIM(password_hash) <> ''),

    CONSTRAINT chk_users_account_status
        CHECK (
            account_status IN (
                'pending',
                'approved',
                'rejected',
                'suspended',
                'deactivated'
            )
        ),

    CONSTRAINT chk_users_approval
        CHECK (
            account_status <> 'approved'
            OR approved_at IS NOT NULL
        ),

    CONSTRAINT chk_users_rejection
        CHECK (
            account_status <> 'rejected'
            OR rejected_at IS NOT NULL
        ),

    CONSTRAINT chk_users_suspension
        CHECK (
            account_status <> 'suspended'
            OR suspended_at IS NOT NULL
        ),

    CONSTRAINT chk_users_deactivation
        CHECK (
            account_status <> 'deactivated'
            OR deactivated_at IS NOT NULL
        )
);


CREATE INDEX IF NOT EXISTS idx_users_status
    ON users(account_status);

CREATE INDEX IF NOT EXISTS idx_users_created_at
    ON users(created_at DESC);


-- ============================================================
-- 3. ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(50) NOT NULL UNIQUE,

    description TEXT,

    is_system_role BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 4. PERMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(100) NOT NULL UNIQUE,

    resource VARCHAR(100) NOT NULL,

    action VARCHAR(50) NOT NULL,

    description TEXT,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_permissions_resource_action
        UNIQUE (resource, action)
);


-- ============================================================
-- 5. USER ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    role_id UUID NOT NULL
        REFERENCES roles(id)
        ON DELETE RESTRICT,

    assigned_by UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    assigned_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_user_roles
        UNIQUE (user_id, role_id)
);


CREATE INDEX IF NOT EXISTS idx_user_roles_user_id
    ON user_roles(user_id);

CREATE INDEX IF NOT EXISTS idx_user_roles_role_id
    ON user_roles(role_id);


-- ============================================================
-- 6. ROLE PERMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    role_id UUID NOT NULL
        REFERENCES roles(id)
        ON DELETE CASCADE,

    permission_id UUID NOT NULL
        REFERENCES permissions(id)
        ON DELETE CASCADE,

    assigned_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_role_permissions
        UNIQUE (role_id, permission_id)
);


-- ============================================================
-- 7. AUTHENTICATION SESSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    token_hash VARCHAR(255) NOT NULL UNIQUE,

    ip_address INET,

    user_agent TEXT,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    last_activity_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    expires_at TIMESTAMPTZ NOT NULL,

    revoked_at TIMESTAMPTZ,

    CONSTRAINT chk_sessions_expiration
        CHECK (expires_at > created_at),

    CONSTRAINT chk_sessions_revocation
        CHECK (
            revoked_at IS NULL
            OR revoked_at >= created_at
        )
);


CREATE INDEX IF NOT EXISTS idx_sessions_user_id
    ON sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_sessions_expires_at
    ON sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_sessions_active
    ON sessions(user_id, expires_at)
    WHERE revoked_at IS NULL;


-- ============================================================
-- 8. PASSWORD RESET TOKENS
-- ============================================================

CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    token_hash VARCHAR(255) NOT NULL UNIQUE,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    expires_at TIMESTAMPTZ NOT NULL,

    used_at TIMESTAMPTZ,

    CONSTRAINT chk_password_reset_expiration
        CHECK (expires_at > created_at),

    CONSTRAINT chk_password_reset_used
        CHECK (
            used_at IS NULL
            OR used_at >= created_at
        )
);


CREATE INDEX IF NOT EXISTS idx_password_reset_user
    ON password_reset_tokens(user_id);


-- ============================================================
-- 9. EMAIL VERIFICATION TOKENS
-- ============================================================

CREATE TABLE IF NOT EXISTS email_verification_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    token_hash VARCHAR(255) NOT NULL UNIQUE,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    expires_at TIMESTAMPTZ NOT NULL,

    used_at TIMESTAMPTZ,

    CONSTRAINT chk_email_verification_expiration
        CHECK (expires_at > created_at),

    CONSTRAINT chk_email_verification_used
        CHECK (
            used_at IS NULL
            OR used_at >= created_at
        )
);


CREATE INDEX IF NOT EXISTS idx_email_verification_user
    ON email_verification_tokens(user_id);


-- ============================================================
-- 10. ACCOUNT SETTINGS
-- ============================================================

CREATE TABLE IF NOT EXISTS account_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL UNIQUE
        REFERENCES users(id)
        ON DELETE CASCADE,

    display_name VARCHAR(150),

    theme VARCHAR(20)
        NOT NULL DEFAULT 'system',

    language VARCHAR(20)
        NOT NULL DEFAULT 'en',

    notification_preferences JSONB
        NOT NULL DEFAULT '{}'::JSONB,

    interface_preferences JSONB
        NOT NULL DEFAULT '{}'::JSONB,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_account_settings_theme
        CHECK (
            theme IN ('light', 'dark', 'system')
        ),

    CONSTRAINT chk_notification_preferences
        CHECK (
            jsonb_typeof(notification_preferences) = 'object'
        ),

    CONSTRAINT chk_interface_preferences
        CHECK (
            jsonb_typeof(interface_preferences) = 'object'
        )
);


-- ============================================================
-- 11. AI CONVERSATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    title VARCHAR(200),

    model_identifier VARCHAR(150),

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW()
);


CREATE INDEX IF NOT EXISTS idx_ai_conversations_user
    ON ai_conversations(user_id, updated_at DESC);


-- ============================================================
-- 12. AI MESSAGES
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    conversation_id UUID NOT NULL
        REFERENCES ai_conversations(id)
        ON DELETE CASCADE,

    role VARCHAR(20) NOT NULL,

    content TEXT NOT NULL,

    model_identifier VARCHAR(150),

    input_tokens INTEGER,

    output_tokens INTEGER,

    response_status VARCHAR(20)
        NOT NULL DEFAULT 'completed',

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_ai_message_role
        CHECK (
            role IN ('user', 'assistant')
        ),

    CONSTRAINT chk_ai_message_status
        CHECK (
            response_status IN (
                'pending',
                'completed',
                'failed'
            )
        ),

    CONSTRAINT chk_ai_message_input_tokens
        CHECK (
            input_tokens IS NULL OR input_tokens >= 0
        ),

    CONSTRAINT chk_ai_message_output_tokens
        CHECK (
            output_tokens IS NULL OR output_tokens >= 0
        )
);


CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation
    ON ai_messages(conversation_id, created_at);


-- ============================================================
-- 13. AUDIT LOGS
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    actor_user_id UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    target_user_id UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    event_type VARCHAR(100) NOT NULL,

    resource VARCHAR(100),

    action VARCHAR(50),

    outcome VARCHAR(30) NOT NULL,

    description TEXT,

    ip_address INET,

    user_agent TEXT,

    metadata JSONB
        NOT NULL DEFAULT '{}'::JSONB,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_audit_outcome
        CHECK (
            outcome IN (
                'success',
                'failure',
                'denied',
                'warning'
            )
        ),

    CONSTRAINT chk_audit_metadata
        CHECK (
            jsonb_typeof(metadata) = 'object'
        )
);


CREATE INDEX IF NOT EXISTS idx_audit_logs_actor
    ON audit_logs(actor_user_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_target
    ON audit_logs(target_user_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_event
    ON audit_logs(event_type);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created
    ON audit_logs(created_at DESC);


-- ============================================================
-- 14. AUTHENTICATION RATE LIMIT BUCKETS
-- ============================================================

CREATE TABLE IF NOT EXISTS auth_rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    key_hash VARCHAR(255) NOT NULL,

    scope VARCHAR(50) NOT NULL,

    window_started_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    attempts INTEGER NOT NULL DEFAULT 0,

    blocked_until TIMESTAMPTZ,

    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_auth_rate_limit_key_scope
        UNIQUE (key_hash, scope),

    CONSTRAINT chk_auth_rate_limit_attempts
        CHECK (attempts >= 0)
);


CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_blocked
    ON auth_rate_limits(blocked_until);


-- ============================================================
-- 15. DATABASE VERSION TRACKING
-- ============================================================

CREATE TABLE IF NOT EXISTS schema_metadata (
    id INTEGER PRIMARY KEY,

    software_name VARCHAR(100) NOT NULL,

    software_version VARCHAR(20) NOT NULL,

    schema_version VARCHAR(50) NOT NULL,

    installed_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_schema_metadata_singleton
        CHECK (id = 1)
);


-- ============================================================
-- 16. UPDATED_AT AUTOMATIC TIMESTAMP FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION cybernexus_access.update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


-- ============================================================
-- 17. UPDATED_AT TRIGGERS
-- ============================================================

DROP TRIGGER IF EXISTS trg_users_updated_at
    ON users;

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


DROP TRIGGER IF EXISTS trg_account_settings_updated_at
    ON account_settings;

CREATE TRIGGER trg_account_settings_updated_at
BEFORE UPDATE ON account_settings
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


DROP TRIGGER IF EXISTS trg_ai_conversations_updated_at
    ON ai_conversations;

CREATE TRIGGER trg_ai_conversations_updated_at
BEFORE UPDATE ON ai_conversations
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


DROP TRIGGER IF EXISTS trg_auth_rate_limits_updated_at
    ON auth_rate_limits;

CREATE TRIGGER trg_auth_rate_limits_updated_at
BEFORE UPDATE ON auth_rate_limits
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


-- ============================================================
-- 18. AUDIT LOG IMMUTABILITY
-- ============================================================

CREATE OR REPLACE FUNCTION cybernexus_access.prevent_audit_modification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'Audit logs cannot be updated or deleted';
END;
$$;


DROP TRIGGER IF EXISTS trg_audit_logs_immutable
    ON audit_logs;

CREATE TRIGGER trg_audit_logs_immutable
BEFORE UPDATE OR DELETE ON audit_logs
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.prevent_audit_modification();


-- ============================================================
-- 19. INITIAL SCHEMA METADATA
-- ============================================================

INSERT INTO schema_metadata (
    id,
    software_name,
    software_version,
    schema_version
)
VALUES (
    1,
    'CyberNexus Access',
    '0.0.1',
    '0.0.1'
)
ON CONFLICT (id) DO NOTHING;


-- ============================================================
-- END OF CYBERNEXUS ACCESS SCHEMA
-- ============================================================
),

    CONSTRAINT chk_users_email
        CHECK (
            email = BTRIM(email)
            AND POSITION('@' IN email) > 1
        ),

    CONSTRAINT chk_users_password_hash
        CHECK (BTRIM(password_hash) <> ''),

    CONSTRAINT chk_users_account_status
        CHECK (
            account_status IN (
                'pending',
                'approved',
                'rejected',
                'suspended',
                'deactivated'
            )
        ),

    CONSTRAINT chk_users_approval
        CHECK (
            account_status <> 'approved'
            OR approved_at IS NOT NULL
        ),

    CONSTRAINT chk_users_rejection
        CHECK (
            account_status <> 'rejected'
            OR rejected_at IS NOT NULL
        ),

    CONSTRAINT chk_users_suspension
        CHECK (
            account_status <> 'suspended'
            OR suspended_at IS NOT NULL
        ),

    CONSTRAINT chk_users_deactivation
        CHECK (
            account_status <> 'deactivated'
            OR deactivated_at IS NOT NULL
        )
);


CREATE INDEX IF NOT EXISTS idx_users_status
    ON users(account_status);

CREATE INDEX IF NOT EXISTS idx_users_created_at
    ON users(created_at DESC);


-- ============================================================
-- 3. ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(50) NOT NULL UNIQUE,

    description TEXT,

    is_system_role BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 4. PERMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(100) NOT NULL UNIQUE,

    resource VARCHAR(100) NOT NULL,

    action VARCHAR(50) NOT NULL,

    description TEXT,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_permissions_resource_action
        UNIQUE (resource, action)
);


-- ============================================================
-- 5. USER ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    role_id UUID NOT NULL
        REFERENCES roles(id)
        ON DELETE RESTRICT,

    assigned_by UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    assigned_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_user_roles
        UNIQUE (user_id, role_id)
);


CREATE INDEX IF NOT EXISTS idx_user_roles_user_id
    ON user_roles(user_id);

CREATE INDEX IF NOT EXISTS idx_user_roles_role_id
    ON user_roles(role_id);


-- ============================================================
-- 6. ROLE PERMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    role_id UUID NOT NULL
        REFERENCES roles(id)
        ON DELETE CASCADE,

    permission_id UUID NOT NULL
        REFERENCES permissions(id)
        ON DELETE CASCADE,

    assigned_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_role_permissions
        UNIQUE (role_id, permission_id)
);


-- ============================================================
-- 7. AUTHENTICATION SESSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    token_hash VARCHAR(255) NOT NULL UNIQUE,

    ip_address INET,

    user_agent TEXT,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    last_activity_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    expires_at TIMESTAMPTZ NOT NULL,

    revoked_at TIMESTAMPTZ,

    CONSTRAINT chk_sessions_expiration
        CHECK (expires_at > created_at),

    CONSTRAINT chk_sessions_revocation
        CHECK (
            revoked_at IS NULL
            OR revoked_at >= created_at
        )
);


CREATE INDEX IF NOT EXISTS idx_sessions_user_id
    ON sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_sessions_expires_at
    ON sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_sessions_active
    ON sessions(user_id, expires_at)
    WHERE revoked_at IS NULL;


-- ============================================================
-- 8. PASSWORD RESET TOKENS
-- ============================================================

CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    token_hash VARCHAR(255) NOT NULL UNIQUE,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    expires_at TIMESTAMPTZ NOT NULL,

    used_at TIMESTAMPTZ,

    CONSTRAINT chk_password_reset_expiration
        CHECK (expires_at > created_at),

    CONSTRAINT chk_password_reset_used
        CHECK (
            used_at IS NULL
            OR used_at >= created_at
        )
);


CREATE INDEX IF NOT EXISTS idx_password_reset_user
    ON password_reset_tokens(user_id);


-- ============================================================
-- 9. EMAIL VERIFICATION TOKENS
-- ============================================================

CREATE TABLE IF NOT EXISTS email_verification_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    token_hash VARCHAR(255) NOT NULL UNIQUE,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    expires_at TIMESTAMPTZ NOT NULL,

    used_at TIMESTAMPTZ,

    CONSTRAINT chk_email_verification_expiration
        CHECK (expires_at > created_at),

    CONSTRAINT chk_email_verification_used
        CHECK (
            used_at IS NULL
            OR used_at >= created_at
        )
);


CREATE INDEX IF NOT EXISTS idx_email_verification_user
    ON email_verification_tokens(user_id);


-- ============================================================
-- 10. ACCOUNT SETTINGS
-- ============================================================

CREATE TABLE IF NOT EXISTS account_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL UNIQUE
        REFERENCES users(id)
        ON DELETE CASCADE,

    display_name VARCHAR(150),

    theme VARCHAR(20)
        NOT NULL DEFAULT 'system',

    language VARCHAR(20)
        NOT NULL DEFAULT 'en',

    notification_preferences JSONB
        NOT NULL DEFAULT '{}'::JSONB,

    interface_preferences JSONB
        NOT NULL DEFAULT '{}'::JSONB,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_account_settings_theme
        CHECK (
            theme IN ('light', 'dark', 'system')
        ),

    CONSTRAINT chk_notification_preferences
        CHECK (
            jsonb_typeof(notification_preferences) = 'object'
        ),

    CONSTRAINT chk_interface_preferences
        CHECK (
            jsonb_typeof(interface_preferences) = 'object'
        )
);


-- ============================================================
-- 11. AI CONVERSATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    title VARCHAR(200),

    model_identifier VARCHAR(150),

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW()
);


CREATE INDEX IF NOT EXISTS idx_ai_conversations_user
    ON ai_conversations(user_id, updated_at DESC);


-- ============================================================
-- 12. AI MESSAGES
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    conversation_id UUID NOT NULL
        REFERENCES ai_conversations(id)
        ON DELETE CASCADE,

    role VARCHAR(20) NOT NULL,

    content TEXT NOT NULL,

    model_identifier VARCHAR(150),

    input_tokens INTEGER,

    output_tokens INTEGER,

    response_status VARCHAR(20)
        NOT NULL DEFAULT 'completed',

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_ai_message_role
        CHECK (
            role IN ('user', 'assistant')
        ),

    CONSTRAINT chk_ai_message_status
        CHECK (
            response_status IN (
                'pending',
                'completed',
                'failed'
            )
        ),

    CONSTRAINT chk_ai_message_input_tokens
        CHECK (
            input_tokens IS NULL OR input_tokens >= 0
        ),

    CONSTRAINT chk_ai_message_output_tokens
        CHECK (
            output_tokens IS NULL OR output_tokens >= 0
        )
);


CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation
    ON ai_messages(conversation_id, created_at);


-- ============================================================
-- 13. AUDIT LOGS
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    actor_user_id UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    target_user_id UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    event_type VARCHAR(100) NOT NULL,

    resource VARCHAR(100),

    action VARCHAR(50),

    outcome VARCHAR(30) NOT NULL,

    description TEXT,

    ip_address INET,

    user_agent TEXT,

    metadata JSONB
        NOT NULL DEFAULT '{}'::JSONB,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_audit_outcome
        CHECK (
            outcome IN (
                'success',
                'failure',
                'denied',
                'warning'
            )
        ),

    CONSTRAINT chk_audit_metadata
        CHECK (
            jsonb_typeof(metadata) = 'object'
        )
);


CREATE INDEX IF NOT EXISTS idx_audit_logs_actor
    ON audit_logs(actor_user_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_target
    ON audit_logs(target_user_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_event
    ON audit_logs(event_type);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created
    ON audit_logs(created_at DESC);


-- ============================================================
-- 14. AUTHENTICATION RATE LIMIT BUCKETS
-- ============================================================

CREATE TABLE IF NOT EXISTS auth_rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    key_hash VARCHAR(255) NOT NULL,

    scope VARCHAR(50) NOT NULL,

    window_started_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    attempts INTEGER NOT NULL DEFAULT 0,

    blocked_until TIMESTAMPTZ,

    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_auth_rate_limit_key_scope
        UNIQUE (key_hash, scope),

    CONSTRAINT chk_auth_rate_limit_attempts
        CHECK (attempts >= 0)
);


CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_blocked
    ON auth_rate_limits(blocked_until);


-- ============================================================
-- 15. DATABASE VERSION TRACKING
-- ============================================================

CREATE TABLE IF NOT EXISTS schema_metadata (
    id INTEGER PRIMARY KEY,

    software_name VARCHAR(100) NOT NULL,

    software_version VARCHAR(20) NOT NULL,

    schema_version VARCHAR(50) NOT NULL,

    installed_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_schema_metadata_singleton
        CHECK (id = 1)
);


-- ============================================================
-- 16. UPDATED_AT AUTOMATIC TIMESTAMP FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION cybernexus_access.update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


-- ============================================================
-- 17. UPDATED_AT TRIGGERS
-- ============================================================

DROP TRIGGER IF EXISTS trg_users_updated_at
    ON users;

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


DROP TRIGGER IF EXISTS trg_account_settings_updated_at
    ON account_settings;

CREATE TRIGGER trg_account_settings_updated_at
BEFORE UPDATE ON account_settings
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


DROP TRIGGER IF EXISTS trg_ai_conversations_updated_at
    ON ai_conversations;

CREATE TRIGGER trg_ai_conversations_updated_at
BEFORE UPDATE ON ai_conversations
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


DROP TRIGGER IF EXISTS trg_auth_rate_limits_updated_at
    ON auth_rate_limits;

CREATE TRIGGER trg_auth_rate_limits_updated_at
BEFORE UPDATE ON auth_rate_limits
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


-- ============================================================
-- 18. AUDIT LOG IMMUTABILITY
-- ============================================================

CREATE OR REPLACE FUNCTION cybernexus_access.prevent_audit_modification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'Audit logs cannot be updated or deleted';
END;
$$;


DROP TRIGGER IF EXISTS trg_audit_logs_immutable
    ON audit_logs;

CREATE TRIGGER trg_audit_logs_immutable
BEFORE UPDATE OR DELETE ON audit_logs
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.prevent_audit_modification();


-- ============================================================
-- 19. INITIAL SCHEMA METADATA
-- ============================================================

INSERT INTO schema_metadata (
    id,
    software_name,
    software_version,
    schema_version
)
VALUES (
    1,
    'CyberNexus Access',
    '0.0.1',
    '0.0.1'
)
ON CONFLICT (id) DO NOTHING;


-- ============================================================
-- END OF CYBERNEXUS ACCESS SCHEMA
-- ============================================================
),

    CONSTRAINT chk_users_phone
        CHECK (BTRIM(phone) <> ''),

    CONSTRAINT chk_users_email
        CHECK (
            email = BTRIM(email)
            AND POSITION('@' IN email) > 1
        ),

    CONSTRAINT chk_users_password_hash
        CHECK (BTRIM(password_hash) <> ''),

    CONSTRAINT chk_users_account_status
        CHECK (
            account_status IN (
                'pending',
                'approved',
                'rejected',
                'suspended',
                'deactivated'
            )
        ),

    CONSTRAINT chk_users_approval
        CHECK (
            account_status <> 'approved'
            OR approved_at IS NOT NULL
        ),

    CONSTRAINT chk_users_rejection
        CHECK (
            account_status <> 'rejected'
            OR rejected_at IS NOT NULL
        ),

    CONSTRAINT chk_users_suspension
        CHECK (
            account_status <> 'suspended'
            OR suspended_at IS NOT NULL
        ),

    CONSTRAINT chk_users_deactivation
        CHECK (
            account_status <> 'deactivated'
            OR deactivated_at IS NOT NULL
        )
);


CREATE INDEX IF NOT EXISTS idx_users_status
    ON users(account_status);

CREATE INDEX IF NOT EXISTS idx_users_created_at
    ON users(created_at DESC);


-- ============================================================
-- 3. ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(50) NOT NULL UNIQUE,

    description TEXT,

    is_system_role BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 4. PERMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(100) NOT NULL UNIQUE,

    resource VARCHAR(100) NOT NULL,

    action VARCHAR(50) NOT NULL,

    description TEXT,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_permissions_resource_action
        UNIQUE (resource, action)
);


-- ============================================================
-- 5. USER ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    role_id UUID NOT NULL
        REFERENCES roles(id)
        ON DELETE RESTRICT,

    assigned_by UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    assigned_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_user_roles
        UNIQUE (user_id, role_id)
);


CREATE INDEX IF NOT EXISTS idx_user_roles_user_id
    ON user_roles(user_id);

CREATE INDEX IF NOT EXISTS idx_user_roles_role_id
    ON user_roles(role_id);


-- ============================================================
-- 6. ROLE PERMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    role_id UUID NOT NULL
        REFERENCES roles(id)
        ON DELETE CASCADE,

    permission_id UUID NOT NULL
        REFERENCES permissions(id)
        ON DELETE CASCADE,

    assigned_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_role_permissions
        UNIQUE (role_id, permission_id)
);


-- ============================================================
-- 7. AUTHENTICATION SESSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    token_hash VARCHAR(255) NOT NULL UNIQUE,

    ip_address INET,

    user_agent TEXT,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    last_activity_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    expires_at TIMESTAMPTZ NOT NULL,

    revoked_at TIMESTAMPTZ,

    CONSTRAINT chk_sessions_expiration
        CHECK (expires_at > created_at),

    CONSTRAINT chk_sessions_revocation
        CHECK (
            revoked_at IS NULL
            OR revoked_at >= created_at
        )
);


CREATE INDEX IF NOT EXISTS idx_sessions_user_id
    ON sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_sessions_expires_at
    ON sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_sessions_active
    ON sessions(user_id, expires_at)
    WHERE revoked_at IS NULL;


-- ============================================================
-- 8. PASSWORD RESET TOKENS
-- ============================================================

CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    token_hash VARCHAR(255) NOT NULL UNIQUE,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    expires_at TIMESTAMPTZ NOT NULL,

    used_at TIMESTAMPTZ,

    CONSTRAINT chk_password_reset_expiration
        CHECK (expires_at > created_at),

    CONSTRAINT chk_password_reset_used
        CHECK (
            used_at IS NULL
            OR used_at >= created_at
        )
);


CREATE INDEX IF NOT EXISTS idx_password_reset_user
    ON password_reset_tokens(user_id);


-- ============================================================
-- 9. EMAIL VERIFICATION TOKENS
-- ============================================================

CREATE TABLE IF NOT EXISTS email_verification_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    token_hash VARCHAR(255) NOT NULL UNIQUE,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    expires_at TIMESTAMPTZ NOT NULL,

    used_at TIMESTAMPTZ,

    CONSTRAINT chk_email_verification_expiration
        CHECK (expires_at > created_at),

    CONSTRAINT chk_email_verification_used
        CHECK (
            used_at IS NULL
            OR used_at >= created_at
        )
);


CREATE INDEX IF NOT EXISTS idx_email_verification_user
    ON email_verification_tokens(user_id);


-- ============================================================
-- 10. ACCOUNT SETTINGS
-- ============================================================

CREATE TABLE IF NOT EXISTS account_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL UNIQUE
        REFERENCES users(id)
        ON DELETE CASCADE,

    display_name VARCHAR(150),

    theme VARCHAR(20)
        NOT NULL DEFAULT 'system',

    language VARCHAR(20)
        NOT NULL DEFAULT 'en',

    notification_preferences JSONB
        NOT NULL DEFAULT '{}'::JSONB,

    interface_preferences JSONB
        NOT NULL DEFAULT '{}'::JSONB,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_account_settings_theme
        CHECK (
            theme IN ('light', 'dark', 'system')
        ),

    CONSTRAINT chk_notification_preferences
        CHECK (
            jsonb_typeof(notification_preferences) = 'object'
        ),

    CONSTRAINT chk_interface_preferences
        CHECK (
            jsonb_typeof(interface_preferences) = 'object'
        )
);


-- ============================================================
-- 11. AI CONVERSATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    title VARCHAR(200),

    model_identifier VARCHAR(150),

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW()
);


CREATE INDEX IF NOT EXISTS idx_ai_conversations_user
    ON ai_conversations(user_id, updated_at DESC);


-- ============================================================
-- 12. AI MESSAGES
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    conversation_id UUID NOT NULL
        REFERENCES ai_conversations(id)
        ON DELETE CASCADE,

    role VARCHAR(20) NOT NULL,

    content TEXT NOT NULL,

    model_identifier VARCHAR(150),

    input_tokens INTEGER,

    output_tokens INTEGER,

    response_status VARCHAR(20)
        NOT NULL DEFAULT 'completed',

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_ai_message_role
        CHECK (
            role IN ('user', 'assistant')
        ),

    CONSTRAINT chk_ai_message_status
        CHECK (
            response_status IN (
                'pending',
                'completed',
                'failed'
            )
        ),

    CONSTRAINT chk_ai_message_input_tokens
        CHECK (
            input_tokens IS NULL OR input_tokens >= 0
        ),

    CONSTRAINT chk_ai_message_output_tokens
        CHECK (
            output_tokens IS NULL OR output_tokens >= 0
        )
);


CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation
    ON ai_messages(conversation_id, created_at);


-- ============================================================
-- 13. AUDIT LOGS
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    actor_user_id UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    target_user_id UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    event_type VARCHAR(100) NOT NULL,

    resource VARCHAR(100),

    action VARCHAR(50),

    outcome VARCHAR(30) NOT NULL,

    description TEXT,

    ip_address INET,

    user_agent TEXT,

    metadata JSONB
        NOT NULL DEFAULT '{}'::JSONB,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_audit_outcome
        CHECK (
            outcome IN (
                'success',
                'failure',
                'denied',
                'warning'
            )
        ),

    CONSTRAINT chk_audit_metadata
        CHECK (
            jsonb_typeof(metadata) = 'object'
        )
);


CREATE INDEX IF NOT EXISTS idx_audit_logs_actor
    ON audit_logs(actor_user_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_target
    ON audit_logs(target_user_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_event
    ON audit_logs(event_type);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created
    ON audit_logs(created_at DESC);


-- ============================================================
-- 14. AUTHENTICATION RATE LIMIT BUCKETS
-- ============================================================

CREATE TABLE IF NOT EXISTS auth_rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    key_hash VARCHAR(255) NOT NULL,

    scope VARCHAR(50) NOT NULL,

    window_started_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    attempts INTEGER NOT NULL DEFAULT 0,

    blocked_until TIMESTAMPTZ,

    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_auth_rate_limit_key_scope
        UNIQUE (key_hash, scope),

    CONSTRAINT chk_auth_rate_limit_attempts
        CHECK (attempts >= 0)
);


CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_blocked
    ON auth_rate_limits(blocked_until);


-- ============================================================
-- 15. DATABASE VERSION TRACKING
-- ============================================================

CREATE TABLE IF NOT EXISTS schema_metadata (
    id INTEGER PRIMARY KEY,

    software_name VARCHAR(100) NOT NULL,

    software_version VARCHAR(20) NOT NULL,

    schema_version VARCHAR(50) NOT NULL,

    installed_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_schema_metadata_singleton
        CHECK (id = 1)
);


-- ============================================================
-- 16. UPDATED_AT AUTOMATIC TIMESTAMP FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION cybernexus_access.update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


-- ============================================================
-- 17. UPDATED_AT TRIGGERS
-- ============================================================

DROP TRIGGER IF EXISTS trg_users_updated_at
    ON users;

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


DROP TRIGGER IF EXISTS trg_account_settings_updated_at
    ON account_settings;

CREATE TRIGGER trg_account_settings_updated_at
BEFORE UPDATE ON account_settings
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


DROP TRIGGER IF EXISTS trg_ai_conversations_updated_at
    ON ai_conversations;

CREATE TRIGGER trg_ai_conversations_updated_at
BEFORE UPDATE ON ai_conversations
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


DROP TRIGGER IF EXISTS trg_auth_rate_limits_updated_at
    ON auth_rate_limits;

CREATE TRIGGER trg_auth_rate_limits_updated_at
BEFORE UPDATE ON auth_rate_limits
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.update_updated_at();


-- ============================================================
-- 18. AUDIT LOG IMMUTABILITY
-- ============================================================

CREATE OR REPLACE FUNCTION cybernexus_access.prevent_audit_modification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'Audit logs cannot be updated or deleted';
END;
$$;


DROP TRIGGER IF EXISTS trg_audit_logs_immutable
    ON audit_logs;

CREATE TRIGGER trg_audit_logs_immutable
BEFORE UPDATE OR DELETE ON audit_logs
FOR EACH ROW
EXECUTE FUNCTION cybernexus_access.prevent_audit_modification();


-- ============================================================
-- 19. INITIAL SCHEMA METADATA
-- ============================================================

INSERT INTO schema_metadata (
    id,
    software_name,
    software_version,
    schema_version
)
VALUES (
    1,
    'CyberNexus Access',
    '0.0.1',
    '0.0.1'
)
ON CONFLICT (id) DO NOTHING;


-- ============================================================
-- END OF CYBERNEXUS ACCESS SCHEMA
-- ============================================================
