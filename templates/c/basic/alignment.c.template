#include "alignment.h"

#include <limits.h>

bool alignment_is_power_of_two(size_t value) {
    return value != 0 && (value & (value - 1)) == 0;
}

bool align_forward(size_t value, size_t alignment, size_t *result) {
    if (alignment == 0 || result == NULL) {
        return false;
    }

    size_t const remainder = value % alignment;
    if (remainder == 0) {
        *result = value;
        return true;
    }

    size_t const addition = alignment - remainder;
    if (value > SIZE_MAX - addition) {
        return false;
    }

    *result = value + addition;
    return true;
}

bool align_backward(size_t value, size_t alignment, size_t *result) {
    if (alignment == 0 || result == NULL) {
        return false;
    }

    *result = value - value % alignment;
    return true;
}

bool is_aligned(size_t value, size_t alignment) {
    return alignment != 0 && value % alignment == 0;
}

bool align_forward_address(uintptr_t address, size_t alignment, uintptr_t *result) {
    if (alignment == 0 || result == NULL) {
        return false;
    }

    uintptr_t const wide_alignment = (uintptr_t)alignment;
    if ((size_t)wide_alignment != alignment) {
        return false;
    }

    uintptr_t const remainder = address % wide_alignment;
    if (remainder == 0) {
        *result = address;
        return true;
    }

    uintptr_t const addition = wide_alignment - remainder;
    if (address > UINTPTR_MAX - addition) {
        return false;
    }

    *result = address + addition;
    return true;
}

bool align_backward_address(uintptr_t address, size_t alignment, uintptr_t *result) {
    if (alignment == 0 || result == NULL) {
        return false;
    }

    uintptr_t const wide_alignment = (uintptr_t)alignment;
    if ((size_t)wide_alignment != alignment) {
        return false;
    }

    *result = address - address % wide_alignment;
    return true;
}

bool is_address_aligned(uintptr_t address, size_t alignment) {
    if (alignment == 0) {
        return false;
    }

    uintptr_t const wide_alignment = (uintptr_t)alignment;
    return (size_t)wide_alignment == alignment && address % wide_alignment == 0;
}
