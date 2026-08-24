#include "string_view.h"

#include "base.h"

#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define MB (1024 * 1024)
#define CSTR_MAX_SIZE (4 * MB)

String_View string_view_from_cstr(char *str) {
    size_t const len = strnlen(str, CSTR_MAX_SIZE);
    assert(len < CSTR_MAX_SIZE);

    return (String_View){.str = str, .len = len};
}

void string_view_free(String_View sv) {
    free(sv.str);
}

bool string_view_parse_u32(String_View sv, u32 *result) {
    if (sv.len == 0) {
        return false;
    }

    u32 value = 0;

    for (size_t i = 0; i < sv.len; i += 1) {
        char const c = sv.str[i];

        if (c < '0' || c > '9') {
            return false;
        }

        u32 const digit = (u32)(c - '0');

        if (value > (UINT32_MAX - digit) / 10) {
            return false;
        }

        value = value * 10 + digit;
    }

    *result = value;
    return true;
}

internal void string_view_iterator_prepare_next(String_View_Iterator *iter) {
    if (iter->remaining.len == 0) {
        iter->current = (String_View){0};
        iter->has_next = false;
        return;
    }

    size_t line_end = 0;
    while (line_end < iter->remaining.len) {
        if (iter->remaining.str[line_end] == iter->delim) {
            break;
        }
        line_end += 1;
    }

    size_t content_len = line_end;
    if (content_len > 0 && iter->remaining.str[content_len - 1] == iter->delim) {
        content_len -= 1;
    }
    iter->current = (String_View){
        .str = iter->remaining.str,
        .len = content_len,
    };
    iter->has_next = true;

    if (line_end == iter->remaining.len) {
        iter->remaining = (String_View){0};
    } else {
        size_t const consumed = line_end + 1;
        iter->remaining.str += consumed;
        iter->remaining.len -= consumed;
    }
}

String_View_Iterator string_view_split_byte_iterator_create(String_View sv, char byte) {
    String_View_Iterator iter = {
        .remaining = sv,
        .current = {0},
        .delim = byte,
        .has_next = false,
    };
    string_view_iterator_prepare_next(&iter);
    return iter;
}

String_View_Iterator string_view_split_lines_iterator_create(String_View sv) {
    String_View_Iterator iter = {
        .remaining = sv,
        .current = {0},
        .delim = '\n',
        .has_next = false,
    };
    string_view_iterator_prepare_next(&iter);
    return iter;
}

String_View string_view_iterator_next(String_View_Iterator *iter) {
    if (iter == NULL || !iter->has_next) {
        return (String_View){0};
    }

    String_View const current = iter->current;
    string_view_iterator_prepare_next(iter);
    return current;
}
