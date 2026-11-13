
/*
 * CyberNexus Access
 * Memory Management
 * Version: 0.0.1
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#define CNX_MEMORY_MAX_BLOCKS 1024
#define CNX_MEMORY_TAG_SIZE 64

typedef struct {
    void *address;
    size_t size;
    char tag[CNX_MEMORY_TAG_SIZE];
    bool active;
} CNXMemoryBlock;

typedef struct {
    size_t active_blocks;
    size_t total_allocated;
    size_t peak_allocated;
    size_t allocation_count;
    size_t release_count;
} CNXMemoryStats;


/* Memory Registry */

static CNXMemoryBlock memory_blocks[CNX_MEMORY_MAX_BLOCKS];

static CNXMemoryStats memory_stats = {0};


/* Internal Utilities */

static void cnx_memory_set_tag(
    char *destination,
    const char *source
) {
    if (destination == NULL) {
        return;
    }

    if (source == NULL) {
        source = "untagged";
    }

    snprintf(
        destination,
        CNX_MEMORY_TAG_SIZE,
        "%s",
        source
    );
}


static CNXMemoryBlock *cnx_memory_find_free_slot(void) {

    for (size_t i = 0; i < CNX_MEMORY_MAX_BLOCKS; i++) {

        if (!memory_blocks[i].active) {
            return &memory_blocks[i];
        }
    }

    return NULL;
}


static CNXMemoryBlock *cnx_memory_find_block(
    const void *address
) {

    if (address == NULL) {
        return NULL;
    }

    for (size_t i = 0; i < CNX_MEMORY_MAX_BLOCKS; i++) {

        if (
            memory_blocks[i].active &&
            memory_blocks[i].address == address
        ) {
            return &memory_blocks[i];
        }
    }

    return NULL;
}


/* Memory Allocation */

void *cnx_memory_allocate(
    size_t size,
    const char *tag
) {

    if (size == 0) {
        return NULL;
    }

    if (size > SIZE_MAX - memory_stats.total_allocated) {
        return NULL;
    }

    CNXMemoryBlock *slot = cnx_memory_find_free_slot();

    if (slot == NULL) {
        return NULL;
    }

    void *address = calloc(1, size);

    if (address == NULL) {
        return NULL;
    }

    slot->address = address;
    slot->size = size;

    cnx_memory_set_tag(slot->tag, tag);

    slot->active = true;

    memory_stats.active_blocks++;
    memory_stats.total_allocated += size;
    memory_stats.allocation_count++;

    if (
        memory_stats.total_allocated >
        memory_stats.peak_allocated
    ) {
        memory_stats.peak_allocated =
            memory_stats.total_allocated;
    }

    return address;
}


/* Memory Release */

bool cnx_memory_release(void *address) {

    CNXMemoryBlock *block =
        cnx_memory_find_block(address);

    if (block == NULL) {
        return false;
    }

    if (memory_stats.total_allocated >= block->size) {
        memory_stats.total_allocated -= block->size;
    }

    memory_stats.active_blocks--;
    memory_stats.release_count++;

    free(block->address);

    memset(block, 0, sizeof(*block));

    return true;
}


/* Memory Validation */

bool cnx_memory_is_valid(const void *address) {

    return cnx_memory_find_block(address) != NULL;
}


/* Memory Size */

size_t cnx_memory_get_size(const void *address) {

    CNXMemoryBlock *block =
        cnx_memory_find_block(address);

    if (block == NULL) {
        return 0;
    }

    return block->size;
}


/* Memory Statistics */

CNXMemoryStats cnx_memory_get_stats(void) {

    return memory_stats;
}


/* Memory Diagnostics */

void cnx_memory_print_stats(void) {

    printf("CyberNexus Memory Diagnostics\n");

    printf(
        "Active Blocks: %zu\n",
        memory_stats.active_blocks
    );

    printf(
        "Current Allocation: %zu bytes\n",
        memory_stats.total_allocated
    );

    printf(
        "Peak Allocation: %zu bytes\n",
        memory_stats.peak_allocated
    );

    printf(
        "Total Allocations: %zu\n",
        memory_stats.allocation_count
    );

    printf(
        "Total Releases: %zu\n",
        memory_stats.release_count
    );
}


/* Release All Tracked Memory */

void cnx_memory_cleanup(void) {

    for (size_t i = 0; i < CNX_MEMORY_MAX_BLOCKS; i++) {

        if (memory_blocks[i].active) {

            free(memory_blocks[i].address);

            memset(
                &memory_blocks[i],
                0,
                sizeof(memory_blocks[i])
            );

            memory_stats.release_count++;
        }
    }

    memory_stats.active_blocks = 0;
    memory_stats.total_allocated = 0;
}


/* Memory Reset */

void cnx_memory_reset_stats(void) {

    if (memory_stats.active_blocks != 0) {
        return;
    }

    memset(&memory_stats, 0, sizeof(memory_stats));
}
