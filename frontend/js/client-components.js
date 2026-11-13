
"use strict";

/**
 * CyberNexus Access
 * Client Components
 * Version: 0.0.1
 *
 * Shared frontend UI components and interactions.
 */

(() => {
    const state = window.CyberNexusState;

    const components = {
        init() {
            this.initSidebar();
            this.initPasswordVisibility();
            this.initPasswordStrength();
            this.initFileInputs();
            this.initNavigation();
            this.initAlerts();
            this.initChatControls();
        },

        initSidebar() {
            const toggle = document.querySelector("[data-sidebar-toggle]");
            const sidebar = document.querySelector("[data-sidebar]");

            if (!toggle || !sidebar) return;

            toggle.addEventListener("click", () => {
                const isOpen = sidebar.classList.toggle("is-open");

                toggle.setAttribute("aria-expanded", String(isOpen));

                state?.setState({
                    sidebarOpen: isOpen
                });
            });

            document.addEventListener("click", (event) => {
                if (
                    !sidebar.contains(event.target) &&
                    !toggle.contains(event.target) &&
                    sidebar.classList.contains("is-open")
                ) {
                    sidebar.classList.remove("is-open");
                    toggle.setAttribute("aria-expanded", "false");

                    state?.setState({
                        sidebarOpen: false
                    });
                }
            });
        },

        initPasswordVisibility() {
            document.querySelectorAll("[data-password-toggle]")
                .forEach((button) => {
                    button.addEventListener("click", () => {
                        const targetId = button.dataset.passwordToggle;
                        const input = document.getElementById(targetId);

                        if (!input || input.tagName !== "INPUT") return;

                        const isPassword = input.type === "password";

                        input.type = isPassword ? "text" : "password";

                        button.setAttribute(
                            "aria-label",
                            isPassword ? "Hide password" : "Show password"
                        );

                        button.setAttribute(
                            "aria-pressed",
                            String(isPassword)
                        );
                    });
                });
        },

        initPasswordStrength() {
            document.querySelectorAll("[data-password-strength]")
                .forEach((input) => {
                    const targetId = input.dataset.passwordStrength;
                    const output = document.getElementById(targetId);

                    if (!output) return;

                    input.addEventListener("input", () => {
                        const password = input.value;

                        let score = 0;

                        if (password.length >= 8) score++;
                        if (password.length >= 12) score++;
                        if (/[a-z]/.test(password) && /[A-Z]/.test(password)) score++;
                        if (/\d/.test(password)) score++;
                        if (/[^A-Za-z0-9]/.test(password)) score++;

                        const levels = [
                            "Very weak",
                            "Weak",
                            "Fair",
                            "Good",
                            "Strong",
                            "Very strong"
                        ];

                        const level = password.length === 0
                            ? ""
                            : levels[score];

                        output.textContent = level;
                        output.dataset.strength = password.length
                            ? String(score)
                            : "";
                    });
                });
        },

        initFileInputs() {
            document.querySelectorAll("[data-file-input]")
                .forEach((input) => {
                    input.addEventListener("change", () => {
                        const targetId = input.dataset.fileInput;
                        const output = document.getElementById(targetId);

                        if (!output) return;

                        const file = input.files?.[0];

                        output.textContent = file
                            ? file.name
                            : "No file selected";
                    });
                });
        },

        initNavigation() {
            document.querySelectorAll("[data-section-link]")
                .forEach((link) => {
                    link.addEventListener("click", () => {
                        const section = link.dataset.sectionLink;

                        if (!section) return;

                        document.querySelectorAll("[data-section]")
                            .forEach((item) => {
                                item.hidden = item.dataset.section !== section;
                            });

                        document.querySelectorAll("[data-section-link]")
                            .forEach((item) => {
                                const active = item === link;

                                item.classList.toggle("active", active);

                                if (active) {
                                    item.setAttribute("aria-current", "page");
                                } else {
                                    item.removeAttribute("aria-current");
                                }
                            });

                        state?.setState({
                            activeSection: section,
                            sidebarOpen: false
                        });

                        document.querySelector("[data-sidebar]")
                            ?.classList.remove("is-open");
                    });
                });
        },

        initAlerts() {
            document.querySelectorAll("[data-alert-dismiss]")
                .forEach((button) => {
                    button.addEventListener("click", () => {
                        button.closest("[data-alert]")?.remove();
                    });
                });
        },

        initChatControls() {
            const form = document.querySelector("[data-chat-form]");
            const input = document.querySelector("[data-chat-input]");
            const messages = document.querySelector("[data-chat-messages]");
            const status = document.querySelector("[data-chat-status]");
            const sendButton = form?.querySelector('[type="submit"]');

            if (!form || !input || !messages) return;

            let conversationId = null;

            function addMessage(content, sender) {
                const message = document.createElement("div");

                message.className = `ai-message ai-message-${sender}`;
                message.textContent = content;

                messages.appendChild(message);
                messages.scrollTop = messages.scrollHeight;
            }

            form.addEventListener("submit", async (event) => {
                event.preventDefault();

                const message = input.value.trim();

                if (!message || !window.CyberNexusChat) return;

                input.disabled = true;

                if (sendButton) sendButton.disabled = true;

                if (status) status.textContent = "Sending message...";

                addMessage(message, "user");
                input.value = "";

                try {
                    const response = await window.CyberNexusChat.sendMessage(
                        message,
                        conversationId
                    );

                    const reply =
                        response?.reply ||
                        response?.message ||
                        response?.answer;

                    if (typeof reply !== "string" || !reply.trim()) {
                        throw new Error("The assistant returned an empty response.");
                    }

                    conversationId =
                        response?.conversation_id || conversationId;

                    addMessage(reply, "assistant");

                    if (status) status.textContent = "Ready";

                } catch (error) {
                    addMessage(
                        error.message || "Unable to contact the assistant.",
                        "error"
                    );

                    if (status) status.textContent = "Unable to send message.";

                } finally {
                    input.disabled = false;

                    if (sendButton) sendButton.disabled = false;

                    input.focus();
                }
            });
        }
    };

    function showAlert(message, type = "info", container = null) {
        if (typeof message !== "string" || !message.trim()) return null;

        const allowedTypes = ["info", "success", "warning", "error"];

        const alertType = allowedTypes.includes(type)
            ? type
            : "info";

        const alert = document.createElement("div");

        alert.className = `message ${alertType}`;
        alert.dataset.alert = "";
        alert.setAttribute("role", "status");
        alert.textContent = message;

        const target = container || document.querySelector("main") || document.body;

        target.prepend(alert);

        return alert;
    }

    function closeModal(modal) {
        if (typeof modal === "string") {
            modal = document.getElementById(modal);
        }

        if (!modal) return;

        modal.hidden = true;
        modal.setAttribute("aria-hidden", "true");
    }

    function openModal(modal) {
        if (typeof modal === "string") {
            modal = document.getElementById(modal);
        }

        if (!modal) return;

        modal.hidden = false;
        modal.setAttribute("aria-hidden", "false");

        modal.querySelector(
            "button, input, select, textarea"
        )?.focus();
    }

    function formatDate(value) {
        const date = new Date(value);

        if (Number.isNaN(date.getTime())) {
            return "Unavailable";
        }

        return new Intl.DateTimeFormat("en-PH", {
            dateStyle: "medium",
            timeStyle: "short"
        }).format(date);
    }

    window.CyberNexusComponents = Object.freeze({
        init: () => components.init(),
        showAlert,
        openModal,
        closeModal,
        formatDate
    });
})();
