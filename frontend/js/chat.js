
"use strict";

/**
 * CyberNexus Access
 * AI Assistant Client
 * Version: 0.0.1
 *
 * Communicates with the backend AI service.
 * The backend controls model access and AI permissions.
 */

(() => {
    const api = window.CyberNexusAPI;

    if (!api) {
        console.error(
            "CyberNexus Access: API client is not loaded."
        );
        return;
    }

    const MAX_MESSAGE_LENGTH = 4000;

    function validateMessage(message) {
        if (
            typeof message !== "string" ||
            !message.trim()
        ) {
            throw new Error("Enter a message first.");
        }

        const normalized = message.trim();

        if (normalized.length > MAX_MESSAGE_LENGTH) {
            throw new Error(
                `Messages cannot exceed ${MAX_MESSAGE_LENGTH} characters.`
            );
        }

        return normalized;
    }

    async function sendMessage(message, conversationId = null) {
        const normalizedMessage = validateMessage(message);

        if (
            conversationId !== null &&
            (
                typeof conversationId !== "string" ||
                conversationId.length > 200
            )
        ) {
            throw new Error("Invalid conversation identifier.");
        }

        return api.assistant.sendMessage(
            normalizedMessage,
            conversationId
        );
    }

    async function getConversations() {
        return api.assistant.getConversations();
    }

    async function getConversation(conversationId) {
        if (
            typeof conversationId !== "string" ||
            !conversationId.trim() ||
            conversationId.length > 200
        ) {
            throw new Error("Invalid conversation identifier.");
        }

        return api.assistant.getConversation(conversationId);
    }

    function isAvailable() {
        return typeof api.assistant.sendMessage === "function";
    }

    window.CyberNexusChat = Object.freeze({
        sendMessage,
        getConversations,
        getConversation,
        isAvailable
    });
})();
