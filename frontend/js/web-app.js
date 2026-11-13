
"use strict";

/**
 * CyberNexus Access
 * Main Web Application
 * Version: 0.0.1
 *
 * Initializes frontend modules and page behavior.
 * All authentication and authorization decisions
 * must be verified by the backend.
 */

(() => {
    const auth = window.CyberNexusAuth;
    const api = window.CyberNexusAPI;
    const account = window.CyberNexusAccount;
    const components = window.CyberNexusComponents;
    const chat = window.CyberNexusChat;
    const voice = window.CyberNexusVoice;

    const page = document.body.dataset.page || "home";

    function showAlert(message, type = "error") {
        if (components?.showAlert) {
            components.showAlert(message, type);
            return;
        }

        console.error(message);
    }

    function redirect(path) {
        window.location.replace(path);
    }

    function getPagePath(filename) {
        return new URL(filename, window.location.href).href;
    }

    async function protectPage() {
        const requiresAuth =
            document.body.dataset.requiresAuth === "true";

        const requiredRole =
            document.body.dataset.requiredRole;

        if (!requiresAuth) return true;

        if (!auth) {
            showAlert("Authentication service is unavailable.");
            return false;
        }

        try {
            const session = await auth.refreshSession();

            if (!session) {
                redirect(getPagePath("login.html"));
                return false;
            }

            if (
                requiredRole &&
                session.user?.role !== requiredRole.toLowerCase()
            ) {
                redirect(getPagePath("account.html"));
                return false;
            }

            return true;

        } catch {
            showAlert("Unable to verify your session. Please try again.");
            return false;
        }
    }

    function redirectAuthenticatedGuest() {
        if (document.body.dataset.guestOnly !== "true") return;

        if (auth?.isAuthenticated()) {
            redirect(getPagePath("account.html"));
        }
    }

    function initLoginForm() {
        const form = document.querySelector("[data-login-form]");

        if (!form) return;

        form.addEventListener("submit", async (event) => {
            event.preventDefault();

            const identifier = form.querySelector(
                '[name="login_identifier"]'
            )?.value;

            const password = form.querySelector(
                '[name="password"]'
            )?.value;

            const submitButton = form.querySelector(
                '[type="submit"]'
            );

            try {
                if (submitButton) submitButton.disabled = true;

                await auth.login(identifier, password);

                const session = auth.getSession();

                const destination =
                    session?.user?.role === "administrator"
                        ? "admin-console.html"
                        : "account.html";

                redirect(getPagePath(destination));

            } catch (error) {
                showAlert(
                    error.message || "Unable to sign in.",
                    "error"
                );

            } finally {
                if (submitButton) submitButton.disabled = false;
            }
        });
    }

    function initRegistrationForm() {
        const form = document.querySelector("[data-register-form]");

        if (!form) return;

        form.addEventListener("submit", async (event) => {
            event.preventDefault();

            const formData = new FormData(form);
            const payload = Object.fromEntries(formData.entries());

            if (
                payload.password !== payload.confirm_password
            ) {
                showAlert("Passwords do not match.");
                return;
            }

            const submitButton = form.querySelector(
                '[type="submit"]'
            );

            try {
                if (submitButton) submitButton.disabled = true;

                delete payload.confirm_password;
                delete payload.requested_role;
                delete payload.role;
                delete payload.terms_accepted;
                delete payload.information_accuracy;
                payload.full_name = [payload.first_name, payload.middle_name, payload.last_name, payload.suffix]
                    .filter(Boolean).join(" ").trim();
                delete payload.first_name;
                delete payload.middle_name;
                delete payload.last_name;
                delete payload.suffix;

                await auth.register(payload);

                showAlert(
                    "Registration submitted. Wait for administrator review.",
                    "success"
                );

                form.reset();

            } catch (error) {
                showAlert(
                    error.message || "Unable to submit registration."
                );

            } finally {
                if (submitButton) submitButton.disabled = false;
            }
        });
    }

    function initPasswordResetForm() {
        const form = document.querySelector("[data-reset-form]");

        if (!form) return;

        form.addEventListener("submit", async (event) => {
            event.preventDefault();

            const activeStage = form.querySelector(
                '[data-reset-stage]:not([hidden])'
            );

            if (!activeStage) return;

            const stage = activeStage.dataset.resetStage;
            const formData = new FormData(activeStage);
            const data = Object.fromEntries(formData.entries());

            const submitButton = activeStage.querySelector(
                '[type="submit"]'
            );

            try {
                if (submitButton) submitButton.disabled = true;

                let response;

                if (stage === "identify") {
                    response = await auth.requestPasswordReset(
                        data.login_identifier
                    );

                } else if (stage === "verify") {
                    response = await auth.verifyPasswordReset(data);

                } else if (stage === "complete") {
                    response = await auth.completePasswordReset(data);

                } else {
                    return;
                }

                const nextStage = response?.next_stage;

                if (nextStage) {
                    showResetStage(form, nextStage);
                } else if (response?.completed === true) {
                    showAlert(
                        "Password reset completed. You can now sign in.",
                        "success"
                    );

                    redirect(getPagePath("login.html"));
                }

            } catch (error) {
                showAlert(
                    error.message || "Unable to process password reset."
                );

            } finally {
                if (submitButton) submitButton.disabled = false;
            }
        });
    }

    function showResetStage(form, stageName) {
        form.querySelectorAll("[data-reset-stage]")
            .forEach((stage) => {
                stage.hidden =
                    stage.dataset.resetStage !== stageName;
            });

        form.querySelectorAll("[data-reset-indicator]")
            .forEach((indicator) => {
                const active =
                    indicator.dataset.resetIndicator === stageName;

                indicator.classList.toggle("active", active);
            });
    }

    function initLogout() {
        document.querySelectorAll("[data-logout]")
            .forEach((button) => {
                button.addEventListener("click", async () => {
                    button.disabled = true;

                    try {
                        await auth.logout();
                        redirect(getPagePath("login.html"));

                    } catch (error) {
                        showAlert(
                            error.message || "Unable to sign out."
                        );

                    } finally {
                        button.disabled = false;
                    }
                });
            });
    }

    async function initAccountPage() {
        if (page !== "account" || !account) return;

        try {
            const profile = await account.getProfile();

            document.querySelectorAll("[data-profile-field]")
                .forEach((element) => {
                    const field = element.dataset.profileField;

                    if (
                        field &&
                        Object.prototype.hasOwnProperty.call(profile, field)
                    ) {
                        element.textContent = profile[field] ?? "";
                    }
                });

        } catch (error) {
            showAlert(
                error.message || "Unable to load account information."
            );
        }
    }

    function initVoiceControls() {
        if (!voice) return;

        document.querySelectorAll("[data-voice-start]")
            .forEach((button) => {
                button.addEventListener("click", () => {
                    try {
                        voice.startListening({
                            language: button.dataset.voiceLanguage || "en-US"
                        });
                    } catch (error) {
                        showAlert(error.message);
                    }
                });
            });

        document.querySelectorAll("[data-voice-stop]")
            .forEach((button) => {
                button.addEventListener("click", () => {
                    voice.stopListening();
                });
            });

        document.querySelectorAll("[data-voice-speak]")
            .forEach((button) => {
                button.addEventListener("click", () => {
                    const targetId = button.dataset.voiceSpeak;
                    const target = document.getElementById(targetId);

                    if (target?.textContent) {
                        try {
                            voice.speak(target.textContent);
                        } catch (error) {
                            showAlert(error.message);
                        }
                    }
                });
            });

        document.querySelectorAll("[data-voice-cancel]")
            .forEach((button) => {
                button.addEventListener("click", () => {
                    voice.stopAll();
                });
            });

        voice.on("result", (result) => {
            const input = document.querySelector("[data-chat-input]");

            if (input && result.finalTranscript) {
                input.value = result.finalTranscript;
                input.dispatchEvent(new Event("input", {
                    bubbles: true
                }));
            }
        });
    }

    async function init() {
        components?.init();

        const allowed = await protectPage();

        if (!allowed) return;

        redirectAuthenticatedGuest();

        initLoginForm();
        initRegistrationForm();
        initPasswordResetForm();
        initLogout();
        initVoiceControls();

        await initAccountPage();

        if (page === "admin-console") {
            const session = auth?.getSession();

            if (session?.user?.role !== "administrator") {
                redirect(getPagePath("account.html"));
            }
        }
    }

    document.addEventListener("DOMContentLoaded", init);
})();
