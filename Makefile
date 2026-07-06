.PHONY: build run release debug install bubbletext-font clean

build:
	odin build .

run:
	odin run .

release:
	odin build . -o:speed -microarch:native

debug:
	odin build . -debug

bubbletext-font:
	odin run tools/build_bubbletext_font.odin -file

install: release
	strip otempl
	mkdir -p ~/.local/bin
	cp otempl ~/.local/bin/otempl
	chmod +x ~/.local/bin/otempl

clean:
	rm -rf otempl otempl.dSYM/
