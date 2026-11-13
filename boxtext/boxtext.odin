package boxtext

import "core:fmt"
import "core:strings"
import "core:testing"

BOX_TOP_LEFT     :: "┏"
BOX_TOP_RIGHT    :: "┓"
BOX_BOTTOM_LEFT  :: "┗"
BOX_BOTTOM_RIGHT :: "┛"
BOX_HORIZONTAL   :: "━"
BOX_VERTICAL     :: "┃"

// Renders `pairs` as a boxed, aligned table of key/value rows.
//
// Widths are measured with len(), so input is assumed to be ASCII.
//
// The caller owns the returned string.
render :: proc(pairs: [][2]string, gap: int = 2, horizontal_padding: int = 1) -> string {
	// todo(gary): remove gap and introduce a const for it instead.
	builder := strings.builder_make() // we can precalculate what we need eventually.

	// max length calcs
	longest_key   := 0
	longest_value := 0
	for &kv in pairs {
		longest_key   = max(longest_key,   len(kv[0]))
		longest_value = max(longest_value, len(kv[1]))
	}

	// print top of box
	line_length := horizontal_padding + longest_key + gap + longest_value + horizontal_padding
	strings.write_string(&builder, BOX_TOP_LEFT)
	for n in 0..<line_length {
		strings.write_string(&builder, BOX_HORIZONTAL)
	}
	strings.write_string(&builder, BOX_TOP_RIGHT)
	strings.write_byte(&builder, '\n')

	// print pairs
	for pair in pairs {
		// bar and padding
		strings.write_string(&builder, BOX_VERTICAL)
		for n in 0..<horizontal_padding {
			strings.write_byte(&builder, ' ')
		}

		// key and whitespace for alignment
		strings.write_string(&builder, pair[0])
		between_whitespace := (longest_key - len(pair[0])) + gap
		for n in 0..<between_whitespace {
			strings.write_byte(&builder, ' ')
		}

		// value and padding
		strings.write_string(&builder, pair[1])
		end_whitespace := (longest_value - len(pair[1])) + horizontal_padding
		for n in 0..<end_whitespace {
			strings.write_byte(&builder, ' ')
		}

		// bar and newline
		strings.write_string(&builder, BOX_VERTICAL)
		strings.write_byte(&builder, '\n')
	}

	// print bottom of box
	strings.write_string(&builder, BOX_BOTTOM_LEFT)
	for n in 0..<line_length {
		strings.write_string(&builder, BOX_HORIZONTAL)
	}
	strings.write_string(&builder, BOX_BOTTOM_RIGHT)

	return strings.to_string(builder) // caller owns the string
}

@(test)
render_test :: proc(t: ^testing.T) {
	pairs := [][2]string{
		{ "Program",  "BoxText"            },
		{ "Version",  "1.0"                },
		{ "Features", "ascii_only, single" },
	}

	box := render(pairs)
	defer delete(box)

	fmt.println(box)
}
