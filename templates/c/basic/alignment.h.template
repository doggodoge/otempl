#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

bool alignment_is_power_of_two(size_t value);

// Alignment must be non-zero. Forward alignment can also fail on overflow.
bool align_forward(size_t value, size_t alignment, size_t *result);
bool align_backward(size_t value, size_t alignment, size_t *result);
bool is_aligned(size_t value, size_t alignment);

// Address variants avoid assuming that size_t and uintptr_t have equal ranges.
bool align_forward_address(uintptr_t address, size_t alignment, uintptr_t *result);
bool align_backward_address(uintptr_t address, size_t alignment, uintptr_t *result);
bool is_address_aligned(uintptr_t address, size_t alignment);
