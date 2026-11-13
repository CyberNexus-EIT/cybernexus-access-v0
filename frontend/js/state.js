
"use strict";

/**
 * CyberNexus Access
 * Centralized Frontend State
 * Version: 0.0.1
 *
 * Stores non-sensitive UI and account state.
 * Authentication must be verified by the backend.
 */

(() => {
    const STORAGE_KEY = "cybernexus_access_preferences";

    const defaultState = {
        theme: "dark",
        sidebarOpen: false,
        activeSection: "overview",
        notificationsEnabled: true
    };

    let state = { ...defaultState };

    const listeners = new Set();

    function loadPreferences() {
        try {
            const saved = localStorage.getItem(STORAGE_KEY);

            if (!saved) return;

            const parsed = JSON.parse(saved);

            if (
                parsed &&
                typeof parsed === "object" &&
                !Array.isArray(parsed)
            ) {
                state = {
                    ...defaultState,
                    theme: parsed.theme === "dark" ? "dark" : "dark",
                    notificationsEnabled:
                        typeof parsed.notificationsEnabled === "boolean"
                            ? parsed.notificationsEnabled
                            : defaultState.notificationsEnabled
                };
            }
        } catch (error) {
            console.warn(
                "CyberNexus Access: Unable to load preferences.",
                error
            );
        }
    }

    function savePreferences() {
        try {
            localStorage.setItem(
                STORAGE_KEY,
                JSON.stringify({
                    theme: state.theme,
                    notificationsEnabled: state.notificationsEnabled
                })
            );
        } catch (error) {
            console.warn(
                "CyberNexus Access: Unable to save preferences.",
                error
            );
        }
    }

    function getState() {
        return Object.freeze({ ...state });
    }

    function setState(updates = {}) {
        if (
            !updates ||
            typeof updates !== "object" ||
            Array.isArray(updates)
        ) {
            throw new TypeError("State updates must be an object.");
        }

        const allowedKeys = [
            "theme",
            "sidebarOpen",
            "activeSection",
            "notificationsEnabled"
        ];

        for (const key of Object.keys(updates)) {
            if (!allowedKeys.includes(key)) {
                continue;
            }

            const value = updates[key];

            if (key === "theme" && value !== "dark") {
                continue;
            }

            if (
                ["sidebarOpen", "notificationsEnabled"].includes(key) &&
                typeof value !== "boolean"
            ) {
                continue;
            }

            if (
                key === "activeSection" &&
                (typeof value !== "string" || value.length > 60)
            ) {
                continue;
            }

            state[key] = value;
        }

        savePreferences();
        notifyListeners();

        return getState();
    }

    function resetState() {
        state = { ...defaultState };
        savePreferences();
        notifyListeners();

        return getState();
    }

    function subscribe(callback) {
        if (typeof callback !== "function") {
            throw new TypeError("Subscriber must be a function.");
        }

        listeners.add(callback);

        return () => {
            listeners.delete(callback);
        };
    }

    function notifyListeners() {
        const snapshot = getState();

        listeners.forEach((callback) => {
            try {
                callback(snapshot);
            } catch (error) {
                console.error(
                    "CyberNexus Access: State subscriber error.",
                    error
                );
            }
        });
    }

    loadPreferences();

    window.CyberNexusState = Object.freeze({
        getState,
        setState,
        resetState,
        subscribe
    });
})();
