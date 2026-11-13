
"use strict";

/**
 * CyberNexus Access
 * Account Client
 * Version: 0.0.1
 *
 * Handles authenticated account operations.
 * All permissions and approvals are enforced by the backend.
 */

(() => {
    const api = window.CyberNexusAPI;
    const auth = window.CyberNexusAuth;

    if (!api || !auth) {
        console.error(
            "CyberNexus Access: Required clients are not loaded."
        );
        return;
    }

    const MAX_DOCUMENT_SIZE = 10 * 1024 * 1024;

    const ALLOWED_DOCUMENT_TYPES = [
        "image/jpeg",
        "image/png",
        "image/webp",
        "application/pdf"
    ];

    function requireAuthentication() {
        if (!auth.isAuthenticated()) {
            throw new Error("Please sign in to continue.");
        }
    }

    function validateObject(data, label) {
        if (
            !data ||
            typeof data !== "object" ||
            Array.isArray(data)
        ) {
            throw new TypeError(`Invalid ${label}.`);
        }
    }

    async function getProfile() {
        requireAuthentication();
        return api.account.getProfile();
    }

    async function requestProfileUpdate(profileData) {
        requireAuthentication();
        validateObject(profileData, "profile information");

        return api.account.updateProfile(profileData);
    }

    async function getUpdateRequests() {
        requireAuthentication();
        return api.account.getUpdateRequests();
    }

    async function uploadIdentityDocument(file, documentType) {
        requireAuthentication();

        if (!(file instanceof File)) {
            throw new TypeError("Select a valid document.");
        }

        if (!ALLOWED_DOCUMENT_TYPES.includes(file.type)) {
            throw new Error(
                "Only JPEG, PNG, WebP, and PDF files are allowed."
            );
        }

        if (file.size === 0 || file.size > MAX_DOCUMENT_SIZE) {
            throw new Error(
                "The document must be smaller than 10 MB."
            );
        }

        if (
            typeof documentType !== "string" ||
            !documentType.trim() ||
            documentType.length > 60
        ) {
            throw new Error("Select a valid document type.");
        }

        const formData = new FormData();

        formData.append("document", file);
        formData.append("document_type", documentType.trim());

        return api.account.uploadIdentityDocument(formData);
    }

    async function getIdentityStatus() {
        requireAuthentication();
        return api.account.getIdentityStatus();
    }

    async function changePassword(currentPassword, newPassword) {
        requireAuthentication();

        if (
            typeof currentPassword !== "string" ||
            !currentPassword ||
            typeof newPassword !== "string" ||
            newPassword.length < 1 ||
            newPassword.length > 128
        ) {
            throw new Error("Enter valid password information.");
        }

        return api.account.changePassword({
            current_password: currentPassword,
            new_password: newPassword
        });
    }

    async function getSessions() {
        requireAuthentication();
        return api.account.getSessions();
    }

    async function revokeSession(sessionId) {
        requireAuthentication();

        if (
            typeof sessionId !== "string" ||
            !sessionId.trim() ||
            sessionId.length > 200
        ) {
            throw new Error("Invalid session identifier.");
        }

        return api.account.revokeSession(sessionId);
    }

    async function getActivity() {
        requireAuthentication();
        return api.account.getActivity();
    }

    window.CyberNexusAccount = Object.freeze({
        getProfile,
        requestProfileUpdate,
        getUpdateRequests,
        uploadIdentityDocument,
        getIdentityStatus,
        changePassword,
        getSessions,
        revokeSession,
        getActivity
    });
})();
