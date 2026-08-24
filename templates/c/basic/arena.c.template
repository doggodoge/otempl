#include "arena.h"

#include "alignment.h"

#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#define ARENA_DEFAULT_CAPACITY (UINT64_C(4) * 1024 * 1024 * 1024)
#define ARENA_COMMIT_SIZE (64 * 1024)

Arena arena_init(void) {
    if (ARENA_DEFAULT_CAPACITY > SIZE_MAX) {
        errno = ENOMEM;
        return (Arena){0};
    }

    return arena_init_sized((size_t)ARENA_DEFAULT_CAPACITY);
}

Arena arena_init_sized(size_t capacity) {
    if (capacity == 0) {
        errno = EINVAL;
        return (Arena){0};
    }

    long const queried_page_size = sysconf(_SC_PAGESIZE);
    if (queried_page_size <= 0) {
        errno = EINVAL;
        return (Arena){0};
    }

    size_t const page_size = (size_t)queried_page_size;
    size_t rounded_capacity;
    size_t commit_size;
    if (!align_forward(capacity, page_size, &rounded_capacity) ||
        !align_forward(ARENA_COMMIT_SIZE, page_size, &commit_size) || rounded_capacity > SIZE_MAX - page_size) {
        errno = ENOMEM;
        return (Arena){0};
    }

    // The final page is never committed and acts as a guard page.
    size_t const mapping_size = rounded_capacity + page_size;
    void *mem = mmap(NULL, mapping_size, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (mem == MAP_FAILED) {
        return (Arena){0};
    }

    return (Arena){
        .mem = mem,
        .offset = 0,
        .committed = 0,
        .cap = rounded_capacity,
        .page_size = page_size,
        .commit_size = commit_size,
    };
}

bool arena_is_valid(Arena const *arena) {
    return arena != NULL && arena->page_size != 0;
}

void *arena_alloc(Arena *arena, size_t size) {
    return arena_alloc_aligned(arena, size, _Alignof(max_align_t));
}

void *arena_alloc_aligned(Arena *arena, size_t size, size_t alignment) {
    if (!arena_is_valid(arena) || size == 0 || !alignment_is_power_of_two(alignment)) {
        errno = EINVAL;
        return NULL;
    }

    uintptr_t const base = (uintptr_t)arena->mem;
    uintptr_t const current = base + arena->offset;
    uintptr_t aligned_address;
    if (!align_forward_address(current, alignment, &aligned_address)) {
        errno = ENOMEM;
        return NULL;
    }

    size_t const aligned_offset = (size_t)(aligned_address - base);
    if (aligned_offset > arena->cap || size > arena->cap - aligned_offset) {
        errno = ENOMEM;
        return NULL;
    }

    size_t const end = aligned_offset + size;
    if (end > arena->committed) {
        size_t new_committed;
        if (!align_forward(end, arena->commit_size, &new_committed) || new_committed > arena->cap) {
            new_committed = arena->cap;
        }

        size_t const commit_length = new_committed - arena->committed;
        void *commit_start = (unsigned char *)arena->mem + arena->committed;
        if (mprotect(commit_start, commit_length, PROT_READ | PROT_WRITE) != 0) {
            return NULL;
        }

        arena->committed = new_committed;
    }

    arena->offset = end;
    return (void *)aligned_address;
}

void arena_reset(Arena *arena) {
    if (arena_is_valid(arena)) {
        arena->offset = 0;
    }
}

void arena_reset_zeroed(Arena *arena) {
    if (arena_is_valid(arena)) {
        memset(arena->mem, 0, arena->committed);
        arena->offset = 0;
    }
}

void arena_deinit(Arena *arena) {
    if (!arena_is_valid(arena)) {
        return;
    }

    size_t const mapping_size = arena->cap + arena->page_size;
    if (munmap(arena->mem, mapping_size) == 0) {
        *arena = (Arena){0};
    }
}
