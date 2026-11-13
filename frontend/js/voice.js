
"use strict";

/**
 * CyberNexus Access
 * Voice Interaction Client
 * Version: 0.0.1
 *
 * Browser-based speech recognition and speech synthesis.
 * AI processing remains on the backend through chat.js.
 */

(() => {
    const SpeechRecognition =
        window.SpeechRecognition ||
        window.webkitSpeechRecognition;

    const speechSynthesis = window.speechSynthesis;

    let recognition = null;
    let isListening = false;
    let isSpeaking = false;

    const listeners = new Map();

    function emit(eventName, detail = {}) {
        const callback = listeners.get(eventName);

        if (typeof callback === "function") {
            callback(detail);
        }
    }

    function on(eventName, callback) {
        if (
            typeof eventName !== "string" ||
            typeof callback !== "function"
        ) {
            throw new TypeError("Invalid voice event listener.");
        }

        listeners.set(eventName, callback);

        return () => {
            listeners.delete(eventName);
        };
    }

    function isRecognitionSupported() {
        return typeof SpeechRecognition === "function";
    }

    function isSpeechSupported() {
        return typeof speechSynthesis !== "undefined";
    }

    function startListening(options = {}) {
        if (!isRecognitionSupported()) {
            throw new Error(
                "Speech recognition is not supported by this browser."
            );
        }

        if (isListening) {
            return;
        }

        const language =
            typeof options.language === "string"
                ? options.language
                : "en-US";

        recognition = new SpeechRecognition();

        recognition.lang = language;
        recognition.continuous = false;
        recognition.interimResults = true;
        recognition.maxAlternatives = 1;

        recognition.onstart = () => {
            isListening = true;
            emit("start");
        };

        recognition.onresult = (event) => {
            let transcript = "";
            let finalTranscript = "";

            for (
                let index = event.resultIndex;
                index < event.results.length;
                index++
            ) {
                const result = event.results[index];
                const text = result[0].transcript;

                transcript += text;

                if (result.isFinal) {
                    finalTranscript += text;
                }
            }

            emit("result", {
                transcript,
                finalTranscript,
                isFinal: Boolean(finalTranscript)
            });
        };

        recognition.onerror = (event) => {
            emit("error", {
                error: event.error || "speech-recognition-error"
            });
        };

        recognition.onend = () => {
            isListening = false;
            recognition = null;
            emit("end");
        };

        recognition.start();
    }

    function stopListening() {
        if (recognition && isListening) {
            recognition.stop();
        }
    }

    function cancelListening() {
        if (recognition) {
            recognition.abort();
            recognition = null;
            isListening = false;
        }
    }

    function speak(text, options = {}) {
        if (!isSpeechSupported()) {
            throw new Error(
                "Speech synthesis is not supported by this browser."
            );
        }

        if (typeof text !== "string" || !text.trim()) {
            throw new Error("There is no text to speak.");
        }

        const message = text.trim();

        if (message.length > 4000) {
            throw new Error(
                "Speech text cannot exceed 4,000 characters."
            );
        }

        stopSpeaking();

        const utterance = new SpeechSynthesisUtterance(message);

        utterance.lang =
            typeof options.language === "string"
                ? options.language
                : "en-US";

        utterance.rate = Number.isFinite(options.rate)
            ? Math.min(1.5, Math.max(0.5, options.rate))
            : 1;

        utterance.pitch = Number.isFinite(options.pitch)
            ? Math.min(2, Math.max(0, options.pitch))
            : 1;

        utterance.volume = Number.isFinite(options.volume)
            ? Math.min(1, Math.max(0, options.volume))
            : 1;

        utterance.onstart = () => {
            isSpeaking = true;
            emit("speech-start");
        };

        utterance.onend = () => {
            isSpeaking = false;
            emit("speech-end");
        };

        utterance.onerror = (event) => {
            isSpeaking = false;

            emit("speech-error", {
                error: event.error || "speech-synthesis-error"
            });
        };

        speechSynthesis.speak(utterance);

        return utterance;
    }

    function stopSpeaking() {
        if (!isSpeechSupported()) {
            return;
        }

        speechSynthesis.cancel();
        isSpeaking = false;
    }

    function getVoices() {
        if (!isSpeechSupported()) {
            return [];
        }

        return speechSynthesis.getVoices();
    }

    function getStatus() {
        return Object.freeze({
            listening: isListening,
            speaking: isSpeaking,
            recognitionSupported: isRecognitionSupported(),
            speechSupported: isSpeechSupported()
        });
    }

    function stopAll() {
        cancelListening();
        stopSpeaking();
    }

    window.CyberNexusVoice = Object.freeze({
        on,
        startListening,
        stopListening,
        cancelListening,
        speak,
        stopSpeaking,
        getVoices,
        getStatus,
        stopAll,
        isRecognitionSupported,
        isSpeechSupported
    });
})();
