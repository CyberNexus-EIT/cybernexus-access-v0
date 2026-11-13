
/**
 * CyberNexus Access
 * API Request and Response Types
 * Version: 0.0.1
 */

import type {
    User,
    UserProfile,
    UserRole,
    AccountStatus,
    AuthSession,
    AutomationRecord,
    AutomationType,
    AutomationStatus,
    AIMessage,
    AIModelInfo,
    AuditLog,
    Notification,
    SystemHealth,
    PaginatedData
} from "./types";


/* HTTP Configuration */

export type HTTPMethod =
    | "GET"
    | "POST"
    | "PUT"
    | "PATCH"
    | "DELETE";

export interface APIConfiguration {
    baseURL: string;
    timeout: number;
    credentials: RequestCredentials;
}


/* Standard API Response */

export interface APIResponse<T = unknown> {
    success: boolean;
    data?: T;
    message?: string;
    error?: APIError;
    timestamp?: string;
}

export interface APIError {
    code?: string;
    message: string;
    details?: unknown;
}

export interface APIValidationError {
    loc: (string | number)[];
    msg: string;
    type: string;
}

export interface APIValidationResponse {
    success: false;
    error: {
        message: string;
        details: APIValidationError[];
    };
}


/* Authentication API */

export namespace AuthAPI {

    export interface RegisterRequest {
        email: string;
        password: string;
    }

    export interface RegisterResponse {
        success: boolean;
        message: string;
        user_id?: string;
        email?: string;
        role?: UserRole;
    }

    export interface LoginRequest {
        email: string;
        password: string;
    }

    export interface LoginResponse {
        success: boolean;
        message: string;
        user_id?: string;
        email?: string;
        role?: UserRole;
    }

    export interface SessionResponse {
        success: boolean;
        message: string;
        user_id?: string;
        email?: string;
        role?: UserRole;
    }

    export interface LogoutResponse {
        success: boolean;
        message: string;
    }
}


/* Account API */

export namespace AccountAPI {

    export interface AccountResponse {
        user: User;
        profile?: UserProfile;
    }

    export interface UpdateProfileRequest {
        firstName?: string;
        lastName?: string;
        displayName?: string;
        bio?: string;
        avatarUrl?: string | null;
    }

    export interface UpdateSettingsRequest {
        language?: string;
        theme?: "light" | "dark" | "system";
        emailNotifications?: boolean;
        securityNotifications?: boolean;
    }

    export interface UpdateStatusRequest {
        status: AccountStatus;
    }

    export interface UpdateRoleRequest {
        role: UserRole;
    }
}


/* Password Recovery API */

export namespace PasswordAPI {

    export interface RequestReset {
        email: string;
    }

    export interface ConfirmReset {
        token: string;
        newPassword: string;
    }

    export interface PasswordResponse {
        success: boolean;
        message: string;
    }
}


/* AI API */

export namespace AIAPI {

    export interface ChatRequest {
        message: string;
        history: AIMessage[];
    }

    export interface ChatResponse {
        success: boolean;
        model: string;
        response: string;
    }

    export interface AIStatusResponse {
        success: boolean;
        service: string;
        model: string;
        provider: string;
        status: string;
    }

    export interface ModelResponse {
        models: AIModelInfo[];
    }
}


/* Automation API */

export namespace AutomationAPI {

    export interface ExecuteRequest {
        automation_type: AutomationType;
    }

    export interface ExecuteResponse {
        success: boolean;
        automation_id: string;
        automation_type: AutomationType;
        status: AutomationStatus;
        message: string;
        created_at: string;
    }

    export interface HistoryResponse {
        success: boolean;
        count: number;
        automations: AutomationRecord[];
    }

    export interface DetailsResponse {
        success: boolean;
        automation: AutomationRecord;
    }
}


/* Audit API */

export namespace AuditAPI {

    export interface AuditResponse {
        success: boolean;
        logs: AuditLog[];
        total: number;
    }

    export interface AuditFilter {
        userId?: string;
        action?: string;
        startDate?: string;
        endDate?: string;
        page?: number;
        pageSize?: number;
    }
}


/* Notification API */

export namespace NotificationAPI {

    export interface NotificationResponse {
        success: boolean;
        notifications: Notification[];
        unreadCount: number;
    }

    export interface MarkReadRequest {
        notificationIds: string[];
    }
}


/* System API */

export namespace SystemAPI {

    export interface HealthResponse extends SystemHealth {}

    export interface ServiceStatusResponse {
        success: boolean;
        services: {
            name: string;
            status: string;
            latencyMs?: number;
        }[];
    }
}


/* Pagination API */

export interface PaginationQuery {
    page?: number;
    pageSize?: number;
    search?: string;
    sortBy?: string;
    sortOrder?: "asc" | "desc";
}

export interface PaginatedResponse<T> {
    success: boolean;
    data: PaginatedData<T>;
}


/* API Endpoint Definitions */

export const API_ENDPOINTS = {

    system: {
        root: "/",
        health: "/health"
    },

    auth: {
        register: "/api/v1/auth/register",
        login: "/api/v1/auth/login",
        session: "/api/v1/auth/session",
        logout: "/api/v1/auth/logout"
    },

    account: {
        profile: "/api/v1/account/profile",
        settings: "/api/v1/account/settings"
    },

    password: {
        requestReset: "/api/v1/password/reset",
        confirmReset: "/api/v1/password/reset/confirm"
    },

    ai: {
        chat: "/api/v1/ai/chat",
        status: "/api/v1/ai/status"
    },

    automation: {
        execute: "/api/v1/automation/execute",
        history: "/api/v1/automation/history",
        details: "/api/v1/automation"
    },

    audit: {
        logs: "/api/v1/audit/logs"
    },

    notifications: {
        list: "/api/v1/notifications",
        markRead: "/api/v1/notifications/read"
    }

} as const;
