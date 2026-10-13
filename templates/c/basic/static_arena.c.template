#include "static_arena.h"

#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "alignment.h"
#include "base.h"

Static_Arena static_arena_init(void *buffer, usize size) {
	return (Static_Arena){
		.buf = buffer,
		.cap = size,
	};
}

void *static_arena_alloc(Static_Arena *arena, usize size) {
	if (size == 0) {
		errno = EINVAL;
		return NULL;
	}

	uintptr_t aligned_address;
	uintptr_t current_address = (uintptr_t)arena->buf + arena->len;
	if (!align_forward_address(current_address, _Alignof(max_align_t), &aligned_address)) {
		errno = ENOMEM;
		return NULL;
	}

	usize aligned_offset = (usize)(aligned_address - (uintptr_t)arena->buf);
	if (aligned_offset > arena->cap || size > arena->cap - aligned_offset) {
		errno = ENOMEM;
		return NULL;
	}

	arena->len = aligned_offset + size;
	return (void *)aligned_address;
}

void *static_arena_realloc(Static_Arena *arena, void *memory, usize old_size, usize new_size) {
	if (memory == NULL) {
		return static_arena_alloc(arena, new_size);
	}

	if (new_size == 0) {
		errno = EINVAL;
		return NULL;
	}

	if (new_size <= old_size) {
		return memory;
	}

	uintptr_t base = (uintptr_t)arena->buf;
	uintptr_t address = (uintptr_t)memory;
	if (address < base || address - base > arena->len ||
		old_size > arena->len - (usize)(address - base)) {
		errno = EINVAL;
		return NULL;
	}

	usize memory_end = (usize)(address - base) + old_size;
	usize growth = new_size - old_size;
	if (memory_end == arena->len && growth <= arena->cap - arena->len) {
		arena->len += growth;
		return memory;
	}

	void *new_memory = static_arena_alloc(arena, new_size);
	if (new_memory != NULL) {
		memcpy(new_memory, memory, old_size);
	}
	return new_memory;
}

void static_arena_reset(Static_Arena *arena) {
	memset(arena->buf, 0, arena->len);
	arena->len = 0;
}
