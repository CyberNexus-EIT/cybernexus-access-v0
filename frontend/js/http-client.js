
"use strict";

/**
 * CyberNexus Access
 * HTTP Client
 * Version: 0.0.1
 *
 * Centralized communication with the backend API.
 * Uses secure, HttpOnly session cookies.
 */

(() => {
    const API_BASE_URL = "/api/v1";

    class HttpError extends Error {
        constructor(message, status, data = null) {
            super(message);
            this.name = "HttpError";
            this.status = status;
            this.data = data;
        }
    }

    function buildUrl(endpoint) {
        if (
            typeof endpoint !== "string" ||
            !endpoint.trim()
        ) {
            throw new TypeError("A valid API endpoint is required.");
        }

        if (/^https?:\/\//i.test(endpoint)) {
            throw new Error("External API URLs are not allowed.");
        }

        const normalizedEndpoint = endpoint.startsWith("/")
            ? endpoint
            : `/${endpoint}`;

        return `${API_BASE_URL}${normalizedEndpoint}`;
    }

    async function request(endpoint, options = {}) {
        const method = (options.method || "GET").toUpperCase();

        const headers = new Headers(options.headers || {});

        headers.set("Accept", "application/json");

        const requestOptions = {
            method,
            headers,
            credentials: "include",
            cache: "no-store",
            redirect: "error"
        };

        if (options.body instanceof FormData) {
            requestOptions.body = options.body;
        } else if (options.body !== undefined) {
            headers.set("Content-Type", "application/json");
            requestOptions.body = JSON.stringify(options.body);
        }

        if (options.signal) {
            requestOptions.signal = options.signal;
        }

        let response;

        try {
            response = await fetch(
                buildUrl(endpoint),
                requestOptions
            );
        } catch (error) {
            if (error.name === "AbortError") {
                throw error;
            }

            throw new HttpError(
                "Unable to connect to the server. Please try again.",
                0
            );
        }

        if (response.status === 204) {
            if (!response.ok) {
                throw new HttpError(
                    "The request could not be completed.",
                    response.status
                );
            }

            return null;
        }

        const contentType = response.headers.get("content-type") || "";

        let data = null;

        if (contentType.includes("application/json")) {
            try {
                data = await response.json();
            } catch {
                throw new HttpError(
                    "The server returned an invalid response.",
                    response.status
                );
            }
        } else {
            const responseText = await response.text();

            data = responseText
                ? { message: responseText }
                : null;
        }

        if (!response.ok) {
            const message =
                data?.detail ||
                data?.message ||
                "The request could not be completed.";

            throw new HttpError(
                message,
                response.status,
                data
            );
        }

        return data;
    }

    function get(endpoint, options = {}) {
        return request(endpoint, {
            ...options,
            method: "GET"
        });
    }

    function post(endpoint, body, options = {}) {
        return request(endpoint, {
            ...options,
            method: "POST",
            body
        });
    }

    function put(endpoint, body, options = {}) {
        return request(endpoint, {
            ...options,
            method: "PUT",
            body
        });
    }

    function patch(endpoint, body, options = {}) {
        return request(endpoint, {
            ...options,
            method: "PATCH",
            body
        });
    }

    function deleteRequest(endpoint, options = {}) {
        return request(endpoint, {
            ...options,
            method: "DELETE"
        });
    }

    function upload(endpoint, formData, options = {}) {
        if (!(formData instanceof FormData)) {
            throw new TypeError("Upload requires FormData.");
        }

        return request(endpoint, {
            ...options,
            method: "POST",
            body: formData
        });
    }

    window.CyberNexusHTTP = Object.freeze({
        request,
        get,
        post,
        put,
        patch,
        delete: deleteRequest,
        upload,
        HttpError
    });
})();
