#pragma once

#include "base.h"

typedef struct {
	u8 *buf;
	usize len;
	usize cap;
} Static_Arena;

Static_Arena static_arena_init(void *buffer, usize size);
void *static_arena_alloc(Static_Arena *arena, usize size);
void *static_arena_realloc(Static_Arena *arena, void *memory, usize old_size, usize new_size);
void static_arena_reset(Static_Arena *arena);
