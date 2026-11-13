
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
-- File: data.sql
-- Purpose: Initial roles and permissions
-- Database: PostgreSQL
--
-- Prerequisite:
-- Execute schema.sql before this file.
--
-- IMPORTANT:
-- No production administrator account is created here.
-- Administrator creation must use a secure backend procedure.
-- ============================================================


BEGIN;

SET search_path TO cybernexus_access, public;


-- ============================================================
-- 1. INITIAL ROLES
-- ============================================================

INSERT INTO roles (
    name,
    description,
    is_system_role
)
VALUES
(
    'User',
    'Standard account with access to permitted personal account functions.',
    TRUE
),
(
    'Reviewer',
    'Authorized account responsible for reviewing registration requests.',
    TRUE
),
(
    'Administrator',
    'Privileged account responsible for authorized system administration.',
    TRUE
)
ON CONFLICT (name)
DO UPDATE SET
    description = EXCLUDED.description,
    is_system_role = EXCLUDED.is_system_role;


-- ============================================================
-- 2. INITIAL PERMISSIONS
-- ============================================================

INSERT INTO permissions (
    name,
    resource,
    action,
    description
)
VALUES

-- USER ACCOUNT

(
    'account.read.own',
    'account',
    'read_own',
    'View own account information.'
),
(
    'account.update.own',
    'account',
    'update_own',
    'Update permitted personal account information.'
),
(
    'account.change_password.own',
    'account',
    'change_password_own',
    'Change own account password.'
),
(
    'account.manage_sessions.own',
    'account',
    'manage_sessions_own',
    'View and revoke own authentication sessions.'
),

-- PROFILE

(
    'profile.read.own',
    'profile',
    'read_own',
    'View own user profile.'
),
(
    'profile.update.own',
    'profile',
    'update_own',
    'Update permitted profile information.'
),

-- AI ASSISTANT

(
    'ai.use',
    'ai',
    'use',
    'Use the CyberNexus Access AI assistant.'
),
(
    'ai.manage_conversations.own',
    'ai',
    'manage_conversations_own',
    'Manage own AI conversations.'
),

-- REGISTRATION REVIEW

(
    'registration.read',
    'registration',
    'read',
    'View registration requests.'
),
(
    'registration.approve',
    'registration',
    'approve',
    'Approve eligible registration requests.'
),
(
    'registration.reject',
    'registration',
    'reject',
    'Reject registration requests.'
),

-- ADMINISTRATION: ACCOUNTS

(
    'admin.accounts.read',
    'admin_accounts',
    'read',
    'View authorized account records.'
),
(
    'admin.accounts.update',
    'admin_accounts',
    'update',
    'Update permitted account information.'
),
(
    'admin.accounts.suspend',
    'admin_accounts',
    'suspend',
    'Suspend eligible accounts.'
),
(
    'admin.accounts.activate',
    'admin_accounts',
    'activate',
    'Reactivate eligible accounts.'
),
(
    'admin.accounts.deactivate',
    'admin_accounts',
    'deactivate',
    'Deactivate eligible accounts.'
),

-- ADMINISTRATION: ROLES

(
    'admin.roles.read',
    'admin_roles',
    'read',
    'View roles and role assignments.'
),
(
    'admin.roles.assign',
    'admin_roles',
    'assign',
    'Assign authorized roles to accounts.'
),
(
    'admin.roles.revoke',
    'admin_roles',
    'revoke',
    'Revoke authorized role assignments.'
),

-- AUDIT LOGS

(
    'audit.read',
    'audit',
    'read',
    'View authorized security audit records.'
),

-- SYSTEM

(
    'system.health.read',
    'system',
    'health_read',
    'View permitted system health information.'
),
(
    'system.settings.read',
    'system_settings',
    'read',
    'View authorized system settings.'
),
(
    'system.settings.update',
    'system_settings',
    'update',
    'Update authorized system settings.'
)

ON CONFLICT (resource, action)
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description;


-- ============================================================
-- 3. USER ROLE PERMISSIONS
-- ============================================================

INSERT INTO role_permissions (
    role_id,
    permission_id
)
SELECT
    r.id,
    p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'User'
AND p.name IN (
    'account.read.own',
    'account.update.own',
    'account.change_password.own',
    'account.manage_sessions.own',
    'profile.read.own',
    'profile.update.own',
    'ai.use',
    'ai.manage_conversations.own'
)
ON CONFLICT (role_id, permission_id)
DO NOTHING;


-- ============================================================
-- 4. REVIEWER ROLE PERMISSIONS
-- ============================================================

INSERT INTO role_permissions (
    role_id,
    permission_id
)
SELECT
    r.id,
    p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Reviewer'
AND p.name IN (
    'account.read.own',
    'account.update.own',
    'account.change_password.own',
    'account.manage_sessions.own',
    'profile.read.own',
    'profile.update.own',
    'ai.use',
    'ai.manage_conversations.own',
    'registration.read',
    'registration.approve',
    'registration.reject'
)
ON CONFLICT (role_id, permission_id)
DO NOTHING;


-- ============================================================
-- 5. ADMINISTRATOR ROLE PERMISSIONS
-- ============================================================

INSERT INTO role_permissions (
    role_id,
    permission_id
)
SELECT
    r.id,
    p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Administrator'
AND p.name IN (
    'account.read.own',
    'account.update.own',
    'account.change_password.own',
    'account.manage_sessions.own',
    'profile.read.own',
    'profile.update.own',
    'ai.use',
    'ai.manage_conversations.own',
    'registration.read',
    'registration.approve',
    'registration.reject',
    'admin.accounts.read',
    'admin.accounts.update',
    'admin.accounts.suspend',
    'admin.accounts.activate',
    'admin.accounts.deactivate',
    'admin.roles.read',
    'admin.roles.assign',
    'admin.roles.revoke',
    'audit.read',
    'system.health.read',
    'system.settings.read',
    'system.settings.update'
)
ON CONFLICT (role_id, permission_id)
DO NOTHING;


-- ============================================================
-- 6. INITIAL DATA VALIDATION
-- ============================================================

DO $$
DECLARE
    role_count INTEGER;
    permission_count INTEGER;
    assignment_count INTEGER;

    missing_roles INTEGER;
    missing_permissions INTEGER;
    missing_assignments INTEGER;
BEGIN

    -- Count initial roles.

    SELECT COUNT(*)
    INTO role_count
    FROM cybernexus_access.roles
    WHERE name IN (
        'User',
        'Reviewer',
        'Administrator'
    );

    -- Count initial permissions.

    SELECT COUNT(*)
    INTO permission_count
    FROM cybernexus_access.permissions
    WHERE name IN (
        'account.read.own',
        'account.update.own',
        'account.change_password.own',
        'account.manage_sessions.own',
        'profile.read.own',
        'profile.update.own',
        'ai.use',
        'ai.manage_conversations.own',
        'registration.read',
        'registration.approve',
        'registration.reject',
        'admin.accounts.read',
        'admin.accounts.update',
        'admin.accounts.suspend',
        'admin.accounts.activate',
        'admin.accounts.deactivate',
        'admin.roles.read',
        'admin.roles.assign',
        'admin.roles.revoke',
        'audit.read',
        'system.health.read',
        'system.settings.read',
        'system.settings.update'
    );

    -- Count all role assignments.

    SELECT COUNT(*)
    INTO assignment_count
    FROM cybernexus_access.role_permissions;

    -- Validate expected role count.

    IF role_count <> 3 THEN
        RAISE EXCEPTION
            'Initial role validation failed. Expected 3 roles, found %.',
            role_count;
    END IF;

    -- Validate expected permission count.

    IF permission_count <> 23 THEN
        RAISE EXCEPTION
            'Initial permission validation failed. Expected 23 permissions, found %.',
            permission_count;
    END IF;

    -- Validate expected role assignments.

    SELECT COUNT(*)
    INTO missing_assignments
    FROM (
        VALUES
            (
                'User',
                ARRAY[
                    'account.read.own',
                    'account.update.own',
                    'account.change_password.own',
                    'account.manage_sessions.own',
                    'profile.read.own',
                    'profile.update.own',
                    'ai.use',
                    'ai.manage_conversations.own'
                ]::TEXT[]
            ),
            (
                'Reviewer',
                ARRAY[
                    'account.read.own',
                    'account.update.own',
                    'account.change_password.own',
                    'account.manage_sessions.own',
                    'profile.read.own',
                    'profile.update.own',
                    'ai.use',
                    'ai.manage_conversations.own',
                    'registration.read',
                    'registration.approve',
                    'registration.reject'
                ]::TEXT[]
            ),
            (
                'Administrator',
                ARRAY[
                    'account.read.own',
                    'account.update.own',
                    'account.change_password.own',
                    'account.manage_sessions.own',
                    'profile.read.own',
                    'profile.update.own',
                    'ai.use',
                    'ai.manage_conversations.own',
                    'registration.read',
                    'registration.approve',
                    'registration.reject',
                    'admin.accounts.read',
                    'admin.accounts.update',
                    'admin.accounts.suspend',
                    'admin.accounts.activate',
                    'admin.accounts.deactivate',
                    'admin.roles.read',
                    'admin.roles.assign',
                    'admin.roles.revoke',
                    'audit.read',
                    'system.health.read',
                    'system.settings.read',
                    'system.settings.update'
                ]::TEXT[]
            )
    ) AS expected(role_name, permission_names)
    CROSS JOIN LATERAL
        UNNEST(expected.permission_names) AS expected_permission(permission_name)
    LEFT JOIN cybernexus_access.roles r
        ON r.name = expected.role_name
    LEFT JOIN cybernexus_access.permissions p
        ON p.name = expected_permission.permission_name
    LEFT JOIN cybernexus_access.role_permissions rp
        ON rp.role_id = r.id
        AND rp.permission_id = p.id
    WHERE rp.id IS NULL;

    IF missing_assignments <> 0 THEN
        RAISE EXCEPTION
            'Role permission validation failed. Missing assignments: %.',
            missing_assignments;
    END IF;

    RAISE NOTICE 'CyberNexus Access initial data loaded successfully.';
    RAISE NOTICE 'Initial roles: %', role_count;
    RAISE NOTICE 'Initial permissions: %', permission_count;
    RAISE NOTICE 'Total role assignments in database: %', assignment_count;
    RAISE NOTICE 'Missing expected role assignments: %', missing_assignments;

END;
$$;


COMMIT;


-- ============================================================
-- END OF CYBERNEXUS ACCESS INITIAL DATA
-- ============================================================
