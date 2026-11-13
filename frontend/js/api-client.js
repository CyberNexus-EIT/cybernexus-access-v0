
"use strict";

/**
 * CyberNexus Access
 * API Client
 * Version: 0.0.1
 *
 * Centralized API endpoint definitions.
 * Backend routes will be aligned during backend development.
 */

(() => {
    const http = window.CyberNexusHTTP;

    if (!http) {
        console.error(
            "CyberNexus Access: HTTP client is not loaded."
        );
        return;
    }

    const auth = {
        login: (credentials) =>
            http.post("/auth/login", credentials),

        logout: () =>
            http.post("/auth/logout"),

        register: (accountData) =>
            http.post("/auth/register", accountData),

        getSession: () =>
            http.get("/auth/session"),

        requestPasswordReset: (data) =>
            http.post("/auth/password-reset/request", data),

        verifyPasswordReset: (data) =>
            http.post("/auth/password-reset/verify", data),

        completePasswordReset: (data) =>
            http.post("/auth/password-reset/complete", data)
    };

    const account = {
        getProfile: () =>
            http.get("/account/profile"),

        updateProfile: (profileData) =>
            http.patch("/account/profile", profileData),

        getUpdateRequests: () =>
            http.get("/account/profile/requests"),

        uploadIdentityDocument: (formData) =>
            http.upload("/account/identity-documents", formData),

        getIdentityStatus: () =>
            http.get("/account/identity/status"),

        changePassword: (passwordData) =>
            http.post("/account/password/change", passwordData),

        getSessions: () =>
            http.get("/account/sessions"),

        revokeSession: (sessionId) =>
            http.delete(
                `/account/sessions/${encodeURIComponent(sessionId)}`
            ),

        getActivity: () =>
            http.get("/account/activity")
    };

    const admin = {
        getDashboard: () =>
            http.get("/admin/dashboard"),

        getAccounts: (params = {}) => {
            const query = new URLSearchParams(params);
            const suffix = query.toString()
                ? `?${query.toString()}`
                : "";

            return http.get(`/admin/accounts${suffix}`);
        },

        updateAccountStatus: (accountId, data) =>
            http.patch(
                `/admin/accounts/${encodeURIComponent(accountId)}/status`,
                data
            ),

        getRegistrationRequests: () =>
            http.get("/admin/registration-requests"),

        reviewRegistration: (requestId, decision) =>
            http.post(
                `/admin/registration-requests/${encodeURIComponent(requestId)}/review`,
                decision
            ),

        getProfileUpdateRequests: () =>
            http.get("/admin/profile-update-requests"),

        reviewProfileUpdate: (requestId, decision) =>
            http.post(
                `/admin/profile-update-requests/${encodeURIComponent(requestId)}/review`,
                decision
            ),

        getIdentitySubmissions: () =>
            http.get("/admin/identity-submissions"),

        reviewIdentitySubmission: (submissionId, decision) =>
            http.post(
                `/admin/identity-submissions/${encodeURIComponent(submissionId)}/review`,
                decision
            ),

        getPasswordResetRequests: () =>
            http.get("/admin/password-reset-requests"),

        reviewPasswordReset: (requestId, decision) =>
            http.post(
                `/admin/password-reset-requests/${encodeURIComponent(requestId)}/review`,
                decision
            ),

        updateAccountRole: (accountId, roleData) =>
            http.patch(
                `/admin/accounts/${encodeURIComponent(accountId)}/role`,
                roleData
            ),

        getAuditLogs: (params = {}) => {
            const query = new URLSearchParams(params);
            const suffix = query.toString()
                ? `?${query.toString()}`
                : "";

            return http.get(`/admin/audit-logs${suffix}`);
        }
    };

    const assistant = {
        sendMessage: (message, conversationId = null) =>
            http.post("/assistant/messages", {
                message,
                conversation_id: conversationId
            }),

        getConversations: () =>
            http.get("/assistant/conversations"),

        getConversation: (conversationId) =>
            http.get(
                `/assistant/conversations/${encodeURIComponent(conversationId)}`
            )
    };

    const system = {
        health: () =>
            http.get("/health"),

        getCsrfToken: () =>
            http.get("/auth/csrf-token")
    };

    window.CyberNexusAPI = Object.freeze({
        auth: Object.freeze(auth),
        account: Object.freeze(account),
        admin: Object.freeze(admin),
        assistant: Object.freeze(assistant),
        system: Object.freeze(system)
    });
})();
