
/*
 * CyberNexus Access
 * Core System Operations
 * Version: 0.0.1
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <time.h>
#include <stdint.h>

#define CNX_NAME "CyberNexus Access"
#define CNX_VERSION "0.0.1"
#define CNX_STATUS_RUNNING 1
#define CNX_STATUS_STOPPED 0

typedef struct {
    char name[64];
    char version[16];
    bool initialized;
    int status;
    time_t started_at;
} CNXCore;


/* Core Instance */

static CNXCore core;


/* Internal Utilities */

static void set_string(
    char *destination,
    size_t capacity,
    const char *source
) {
    if (destination == NULL || source == NULL || capacity == 0) {
        return;
    }

    snprintf(destination, capacity, "%s", source);
}


/* Core Initialization */

int cnx_core_initialize(void) {

    if (core.initialized) {
        return 0;
    }

    memset(&core, 0, sizeof(core));

    set_string(core.name, sizeof(core.name), CNX_NAME);
    set_string(core.version, sizeof(core.version), CNX_VERSION);

    core.status = CNX_STATUS_RUNNING;
    core.started_at = time(NULL);
    core.initialized = true;

    return 1;
}


/* Core Shutdown */

void cnx_core_shutdown(void) {

    if (!core.initialized) {
        return;
    }

    core.status = CNX_STATUS_STOPPED;
    core.initialized = false;
}


/* Core Information */

const CNXCore *cnx_core_get_info(void) {

    if (!core.initialized) {
        return NULL;
    }

    return &core;
}


/* Runtime Status */

bool cnx_core_is_running(void) {

    return core.initialized &&
           core.status == CNX_STATUS_RUNNING;
}


/* Runtime Uptime */

double cnx_core_get_uptime(void) {

    if (!core.initialized) {
        return 0.0;
    }

    time_t current_time = time(NULL);

    if (current_time == (time_t)-1 ||
        core.started_at == (time_t)-1) {
        return 0.0;
    }

    return difftime(current_time, core.started_at);
}


/* System Timestamp */

int64_t cnx_core_get_timestamp(void) {

    time_t current_time = time(NULL);

    if (current_time == (time_t)-1) {
        return -1;
    }

    return (int64_t)current_time;
}


/* Core Diagnostics */

void cnx_core_print_info(void) {

    if (!core.initialized) {
        printf("CyberNexus Core is not initialized.\n");
        return;
    }

    printf("Application: %s\n", core.name);
    printf("Version: %s\n", core.version);

    printf(
        "Status: %s\n",
        cnx_core_is_running() ? "Running" : "Stopped"
    );

    printf(
        "Uptime: %.2f seconds\n",
        cnx_core_get_uptime()
    );
}


/* Standalone Entry Point */

#ifdef CNX_CORE_STANDALONE

int main(void) {

    if (cnx_core_initialize() != 1) {
        fprintf(stderr, "Core initialization failed.\n");
        return EXIT_FAILURE;
    }

    cnx_core_print_info();

    cnx_core_shutdown();

    return EXIT_SUCCESS;
}

#endif
