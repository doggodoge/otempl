package bubbletext

import "core:strings"
import "core:testing"

font_data := #load("./chunky.bin")

// A lot of hard coding as we just care about one font and it
// keeps things simple.

FONT_HEIGHT     :: 5
FONT_MAX_WIDTH  :: 20
FONT_NUM_CHARS  :: 101
FONT_FIRST_CHAR :: ' '

ALPHABET_OFFSET :: FONT_NUM_CHARS
SLOT_SIZE       :: FONT_HEIGHT * FONT_MAX_WIDTH
FONT_DATA_SIZE  :: FONT_NUM_CHARS + FONT_NUM_CHARS * SLOT_SIZE

get_bytes :: proc(str: string, allocator := context.allocator) -> []byte {
	rows: [FONT_HEIGHT][dynamic]byte
	for row in 0 ..< FONT_HEIGHT {
		rows[row] = make([dynamic]byte, allocator)
	}

	bubble_str := make([dynamic]byte, allocator)
	last_was_space := false

	for r in str {
		glyph_rows := _get_char_rows(r)
		is_space   := _char_idx(r) == 0
		overlap    := 0
		if !is_space && !last_was_space {
			overlap = _overlap_amount(rows, glyph_rows)
		}

		for row in 0 ..< FONT_HEIGHT {
			_append_smushed_row(&rows[row], glyph_rows[row], overlap)
		}
		last_was_space = is_space
	}

	for row in 0 ..< FONT_HEIGHT {
		append(&bubble_str, ..rows[row][:])
		append(&bubble_str, '\n')
		delete(rows[row])
	}

	return bubble_str[:]
}

_get_char_rows :: proc(letter: rune) -> [FONT_HEIGHT][]byte {
	glyph_rows: [FONT_HEIGHT][]byte
	for row in 0 ..< FONT_HEIGHT {
		glyph_rows[row] = _get_char_row(letter, row)
	}
	return glyph_rows
}

_get_char_row :: proc(letter: rune, row: int) -> []byte {
	idx    := _char_idx(letter)
	offset := idx * SLOT_SIZE + row * FONT_MAX_WIDTH
	width  := int(font_data[idx])
	return font_data[ALPHABET_OFFSET + offset:ALPHABET_OFFSET + offset + width]
}

_char_idx :: proc(letter: rune) -> int {
	idx := int(letter) - FONT_FIRST_CHAR
	if idx < 0 || idx >= FONT_NUM_CHARS {
		idx = 0
	}
	return idx
}

_overlap_amount :: proc(rows: [FONT_HEIGHT][dynamic]byte, glyph_rows: [FONT_HEIGHT][]byte) -> int {
	if len(rows[0]) == 0 {
		return 0
	}

	max_overlap := _max_boundary_overlap(rows, glyph_rows)
	for overlap := max_overlap; overlap > 0; overlap -= 1 {
		if _can_overlap(rows, glyph_rows, overlap) {
			return overlap
		}
	}

	return 0
}

_max_boundary_overlap :: proc(
	rows: [FONT_HEIGHT][dynamic]byte,
	glyph_rows: [FONT_HEIGHT][]byte,
) -> int {
	max_overlap := min(len(rows[0]), len(glyph_rows[0]))

	for row in 0 ..< FONT_HEIGHT {
		left_right_blanks := _trailing_spaces(rows[row][:])
		right_left_blanks := _leading_spaces(glyph_rows[row])

		left_edge  := len(rows[row]) - left_right_blanks - 1
		right_edge := right_left_blanks
		if left_edge < 0 || right_edge >= len(glyph_rows[row]) {
			continue
		}

		row_overlap := left_right_blanks + right_left_blanks
		if _, ok := _smush(rows[row][left_edge], glyph_rows[row][right_edge]); ok {
			row_overlap += 1
		}

		max_overlap = min(max_overlap, row_overlap)
	}

	return max_overlap
}

_leading_spaces :: proc(bytes: []byte) -> int {
	for i in 0 ..< len(bytes) {
		if bytes[i] != ' ' {
			return i
		}
	}
	return len(bytes)
}

_trailing_spaces :: proc(bytes: []byte) -> int {
	for i := len(bytes) - 1; i >= 0; i -= 1 {
		if bytes[i] != ' ' {
			return len(bytes) - i - 1
		}
	}
	return len(bytes)
}

_can_overlap :: proc(
	rows:       [FONT_HEIGHT][dynamic]byte,
	glyph_rows: [FONT_HEIGHT][]byte,
	overlap:    int,
) -> bool {
	for row in 0 ..< FONT_HEIGHT {
		row_start := len(rows[row]) - overlap
		for col in 0 ..< overlap {
			if _, ok := _smush(rows[row][row_start + col], glyph_rows[row][col]); !ok {
				return false
			}
		}
	}

	return true
}

_append_smushed_row :: proc(row: ^[dynamic]byte, glyph_row: []byte, overlap: int) {
	row_start := len(row^) - overlap
	for col in 0 ..< overlap {
		row^[row_start + col], _ = _smush(row^[row_start + col], glyph_row[col])
	}

	append(row, ..glyph_row[overlap:])
}

_smush :: proc(left, right: byte) -> (byte, bool) {
	if left == ' ' {
		return right, true
	}
	if right == ' ' {
		return left, true
	}

	if left == right {
		return left, true
	}

	if left == '_' && _can_smush_with_underscore(right) {
		return right, true
	}
	if right == '_' && _can_smush_with_underscore(left) {
		return left, true
	}

	left_group  := _hierarchy_group(left)
	right_group := _hierarchy_group(right)
	if left_group != 0 && right_group != 0 && left_group != right_group {
		if left_group > right_group {
			return left, true
		}
		return right, true
	}

	if _are_opposites(left, right) {
		return '|', true
	}

	return 0, false
}

_can_smush_with_underscore :: proc(ch: byte) -> bool {
	switch ch {
	case '|', '/', '\\', '[', ']', '{', '}', '(', ')', '<', '>':
		return true
	}
	return false
}

_hierarchy_group :: proc(ch: byte) -> int {
	switch ch {
	case '|':
		return 1
	case '/', '\\':
		return 2
	case '[', ']':
		return 3
	case '{', '}':
		return 4
	case '(', ')':
		return 5
	case '<', '>':
		return 6
	}
	return 0
}

_are_opposites :: proc(left, right: byte) -> bool {
	return(
		left == '[' && right == ']' ||
		left == ']' && right == '[' ||
		left == '{' && right == '}' ||
		left == '}' && right == '{' ||
		left == '(' && right == ')' ||
		left == ')' && right == '(' \
	)
}

@(test)
matches_chunky_figlet_output :: proc(t: ^testing.T) {
	testing.expect_value(t, len(font_data), FONT_DATA_SIZE)

	_expect_render(
		t,
		"a b",
		"         __    \n" +
		".---.-. |  |--.\n" +
		"|  _  | |  _  |\n" +
		"|___._| |_____|\n" +
		"               \n",
	)

	_expect_render(
		t,
		"fabulous",
		"  ___         __           __                    \n" +
		".'  _|.---.-.|  |--.--.--.|  |.-----.--.--.-----.\n" +
		"|   _||  _  ||  _  |  |  ||  ||  _  |  |  |__ --|\n" +
		"|__|  |___._||_____|_____||__||_____|_____|_____|\n" +
		"                                                 \n",
	)

	_expect_render(
		t,
		"my_app",
		"                                        \n" +
		".--------.--.--.     .---.-.-----.-----.\n" +
		"|        |  |  |     |  _  |  _  |  _  |\n" +
		"|__|__|__|___  |_____|___._|   __|   __|\n" +
		"         |_____|______|    |__|  |__|   \n",
	)

	_expect_render(
		t,
		"[]",
		" ____ ____ \n" + "|   _|_   |\n" + "|  |   |  |\n" + "|  |_ _|  |\n" + "|____|____|\n",
	)

	_expect_render(
		t,
		"{}",
		"  ___ ___  \n" +
		" |  _|_  | \n" +
		"/  /   \\  \\\n" +
		"\\  \\_ _/  /\n" +
		" |___|___| \n",
	)

	_expect_render(
		t,
		"()",
		"  ___ ___  \n" + ",'  _|_  `.\n" + "|  |   |  |\n" + "|  |_ _|  |\n" + "`.___|___,'\n",
	)

	_expect_render(t, "||", " __ __ \n" + "|  |  |\n" + "|  |  |\n" + "|  |  |\n" + "|__|__|\n")

	bytes := get_bytes("a b", context.temp_allocator)
	testing.expect_value(
		t,
		string(bytes),
		"         __    \n" +
		".---.-. |  |--.\n" +
		"|  _  | |  _  |\n" +
		"|___._| |_____|\n" +
		"               \n",
	)
}

_expect_render :: proc(t: ^testing.T, input, expected: string) {
	bytes := get_bytes(input)
	defer delete(bytes)

	testing.expect_value(t, string(bytes), expected)
	testing.expect(t, !strings.contains(string(bytes), "\x00"))
}
