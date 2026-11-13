
"use strict";

/**
 * CyberNexus Access
 * Authentication Client
 * Version: 0.0.1
 *
 * Communicates with backend authentication endpoints.
 * Authentication authority remains on the server.
 */

(() => {
    const api = window.CyberNexusAPI;

    if (!api) {
        console.error(
            "CyberNexus Access: API client is not loaded."
        );
        return;
    }

    let currentSession = null;

    function normalizeLoginIdentifier(value) {
        if (typeof value !== "string") {
            throw new TypeError("Login identifier is required.");
        }

        const identifier = value.trim();

        if (!identifier || identifier.length > 254) {
            throw new Error("Enter a valid login identifier.");
        }

        return identifier;
    }

    function validatePassword(value) {
        if (
            typeof value !== "string" ||
            value.length < 1 ||
            value.length > 128
        ) {
            throw new Error("Enter a valid password.");
        }

        return value;
    }

    async function login(loginIdentifier, password) {
        const credentials = {
            login_identifier:
                normalizeLoginIdentifier(loginIdentifier),
            password: validatePassword(password)
        };

        const response = await api.auth.login(credentials);

        // The backend sets the secure session cookie.
        // Do not store session tokens in localStorage.
        await refreshSession();

        return response;
    }

    async function register(accountData) {
        if (
            !accountData ||
            typeof accountData !== "object" ||
            Array.isArray(accountData)
        ) {
            throw new TypeError("Invalid registration data.");
        }

        const payload = { ...accountData };

        // Never trust a client-submitted role.
        delete payload.role;
        delete payload.requested_role;
        delete payload.is_admin;
        delete payload.is_administrator;

        return api.auth.register(payload);
    }

    async function logout() {
        try {
            return await api.auth.logout();
        } finally {
            currentSession = null;
        }
    }

    async function refreshSession() {
        try {
            const response = await api.auth.getSession();

            currentSession = response?.authenticated === true
                ? response
                : null;

            return currentSession;
        } catch (error) {
            if ([401, 403].includes(error.status)) {
                currentSession = null;
                return null;
            }

            throw error;
        }
    }

    function getSession() {
        return currentSession
            ? { ...currentSession }
            : null;
    }

    function isAuthenticated() {
        return currentSession?.authenticated === true;
    }

    function hasRole(requiredRole) {
        if (
            !isAuthenticated() ||
            typeof requiredRole !== "string"
        ) {
            return false;
        }

        return currentSession?.user?.role ===
            requiredRole.toLowerCase();
    }

    async function requestPasswordReset(loginIdentifier) {
        return api.auth.requestPasswordReset({
            login_identifier:
                normalizeLoginIdentifier(loginIdentifier)
        });
    }

    async function verifyPasswordReset(data) {
        if (!data || typeof data !== "object") {
            throw new TypeError("Invalid verification data.");
        }

        return api.auth.verifyPasswordReset({
            request_id: data.request_id,
            otp: data.otp,
            identity_verification: data.identity_verification
        });
    }

    async function completePasswordReset(data) {
        if (!data || typeof data !== "object") {
            throw new TypeError("Invalid password reset data.");
        }

        const password = validatePassword(data.new_password);

        if (password !== data.confirm_password) {
            throw new Error("Passwords do not match.");
        }

        return api.auth.completePasswordReset({
            request_id: data.request_id,
            recovery_token: data.recovery_token,
            new_password: password
        });
    }

    window.CyberNexusAuth = Object.freeze({
        login,
        register,
        logout,
        refreshSession,
        getSession,
        isAuthenticated,
        hasRole,
        requestPasswordReset,
        verifyPasswordReset,
        completePasswordReset
    });
})();
