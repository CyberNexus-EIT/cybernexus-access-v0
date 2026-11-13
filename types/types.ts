
/**
 * CyberNexus Access
 * Shared Application Types
 * Version: 0.0.1
 */

/* Application */

export interface ApplicationInfo {
    name: string;
    version: string;
    status: ApplicationStatus;
    environment: ApplicationEnvironment;
}

export type ApplicationStatus =
    | "running"
    | "stopped"
    | "maintenance"
    | "error";

export type ApplicationEnvironment =
    | "development"
    | "testing"
    | "staging"
    | "production";


/* User and Account */

export type UserRole =
    | "User"
    | "Reviewer"
    | "Administrator";

export type AccountStatus =
    | "Pending"
    | "Approved"
    | "Rejected"
    | "Suspended"
    | "Disabled";

export interface User {
    id: string;
    email: string;
    username?: string;
    role: UserRole;
    status: AccountStatus;
    createdAt: string;
    updatedAt?: string;
    lastLoginAt?: string | null;
}

export interface UserProfile {
    userId: string;
    firstName?: string;
    lastName?: string;
    displayName?: string;
    avatarUrl?: string | null;
    bio?: string;
    timezone?: string;
}

export interface AccountSettings {
    userId: string;
    language: string;
    theme: "light" | "dark" | "system";
    emailNotifications: boolean;
    securityNotifications: boolean;
}


/* Authentication */

export interface AuthCredentials {
    email: string;
    password: string;
}

export interface RegistrationData extends AuthCredentials {
    confirmPassword: string;
}

export interface AuthSession {
    userId: string;
    email: string;
    role: UserRole;
    expiresAt?: string;
}

export interface PasswordResetRequest {
    email: string;
}

export interface PasswordResetConfirmation {
    token: string;
    newPassword: string;
    confirmPassword: string;
}


/* Permissions */

export type Permission =
    | "account:read"
    | "account:update"
    | "account:approve"
    | "account:reject"
    | "account:suspend"
    | "user:manage"
    | "session:manage"
    | "audit:read"
    | "system:read"
    | "system:manage"
    | "automation:execute"
    | "ai:use";

export interface RolePermissions {
    role: UserRole;
    permissions: Permission[];
}


/* Sessions */

export type SessionStatus =
    | "active"
    | "expired"
    | "revoked";

export interface SessionRecord {
    id: string;
    userId: string;
    status: SessionStatus;
    createdAt: string;
    expiresAt: string;
    lastActivityAt?: string;
    ipAddress?: string;
    userAgent?: string;
}


/* AI Assistant */

export type AIMessageRole =
    | "system"
    | "user"
    | "assistant";

export interface AIMessage {
    id?: string;
    role: AIMessageRole;
    content: string;
    createdAt?: string;
}

export interface AIConversation {
    id: string;
    userId: string;
    title?: string;
    messages: AIMessage[];
    createdAt: string;
    updatedAt?: string;
}

export interface AIModelInfo {
    name: string;
    provider: string;
    status: "available" | "unavailable";
}


/* Automation */

export type AutomationStatus =
    | "pending"
    | "running"
    | "completed"
    | "failed"
    | "cancelled";

export type AutomationType =
    | "account_activity_report"
    | "session_cleanup"
    | "system_health_check";

export interface AutomationRecord {
    automationId: string;
    userId: string;
    automationType: AutomationType;
    status: AutomationStatus;
    createdAt: string;
    completedAt?: string | null;
    message?: string;
}


/* Audit Logs */

export type AuditAction =
    | "account.register"
    | "account.login"
    | "account.logout"
    | "account.update"
    | "account.approve"
    | "account.reject"
    | "account.suspend"
    | "session.create"
    | "session.revoke"
    | "automation.execute"
    | "system.update";

export interface AuditLog {
    id: string;
    userId?: string;
    action: AuditAction;
    resource?: string;
    resourceId?: string;
    ipAddress?: string;
    userAgent?: string;
    timestamp: string;
    metadata?: Record<string, unknown>;
}


/* Notifications */

export type NotificationType =
    | "information"
    | "success"
    | "warning"
    | "error"
    | "security";

export interface Notification {
    id: string;
    userId: string;
    title: string;
    message: string;
    type: NotificationType;
    read: boolean;
    createdAt: string;
}


/* System Health */

export interface SystemHealth {
    status: "healthy" | "degraded" | "unavailable";
    application: string;
    version: string;
    checkedAt: string;
}

export interface ServiceHealth {
    name: string;
    status: "healthy" | "degraded" | "unavailable";
    latencyMs?: number;
}


/* Pagination */

export interface Pagination {
    page: number;
    pageSize: number;
    total: number;
    totalPages: number;
}

export interface PaginatedData<T> {
    items: T[];
    pagination: Pagination;
}


/* Common Utilities */

export type UUID = string;

export type ISODateTime = string;

export type JSONPrimitive =
    | string
    | number
    | boolean
    | null;

export type JSONValue =
    | JSONPrimitive
    | JSONValue[]
    | { [key: string]: JSONValue };

export type JSONRecord = Record<string, JSONValue>;
