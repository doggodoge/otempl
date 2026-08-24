#pragma once

#include <stdbool.h>
#include <stddef.h>

typedef struct {
    void *mem;
    size_t offset;
    size_t committed;
    size_t cap;
    size_t page_size;
    size_t commit_size;
} Arena;

// Reserves 4 GiB of address space. Pages are made read/write as needed.
Arena arena_init(void);
Arena arena_init_sized(size_t capacity);

bool arena_is_valid(Arena const *arena);
void *arena_alloc(Arena *arena, size_t size);
void *arena_alloc_aligned(Arena *arena, size_t size, size_t alignment);
void arena_reset(Arena *arena);
// Like arena_reset, but also zeroes previously-commited memory so reused
// bytes read back as zero instead of stale data from prior allocations.
void arena_reset_zeroed(Arena *arena);
void arena_deinit(Arena *arena);
