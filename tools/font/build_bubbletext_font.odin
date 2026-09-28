package font

import "core:fmt"
import "core:os"

chunky_font := #load("../../bubbletext/chunky.flf")

FONT_HEIGHT        :: 5
FONT_MAX_WIDTH     :: 20
FONT_NUM_CHARS     :: 101
FONT_GLYPHS_OFFSET :: 82

WIDTHS_OFFSET   :: 0
ALPHABET_OFFSET :: FONT_NUM_CHARS
SLOT_SIZE       :: FONT_HEIGHT * FONT_MAX_WIDTH
BUFFER_SIZE     :: FONT_NUM_CHARS + FONT_NUM_CHARS * SLOT_SIZE

build_bubbletext_font :: proc() {
	buffer: [BUFFER_SIZE]byte
	i := FONT_GLYPHS_OFFSET

	for j in ALPHABET_OFFSET ..< len(buffer) {
		buffer[j] = ' '
	}

	for char_idx in 0 ..< FONT_NUM_CHARS {
		row_widths: [FONT_HEIGHT]int
		max_width := 0

		for row in 0 ..< FONT_HEIGHT {
			offset := ALPHABET_OFFSET + char_idx * SLOT_SIZE + row * FONT_MAX_WIDTH

			for chunky_font[i] != '@' {
				b := chunky_font[i]
				if b == '$' {
					b = ' '
				}

				buffer[offset + row_widths[row]] = b
				row_widths[row] += 1
				i += 1
			}

			max_width = max(max_width, row_widths[row])

			for chunky_font[i] != '\n' {
				i += 1
			}
			i += 1
		}

		buffer[WIDTHS_OFFSET + char_idx] = byte(max_width)
	}

	if err := os.write_entire_file("bubbletext/chunky.bin", buffer[:]); err != nil {
		fmt.eprintf("failed to write bubbletext/chunky.bin: %v\n", err)
		os.exit(1)
	}
}
