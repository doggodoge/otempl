.PHONY: build run release debug install clean

build:
	odin build .

run:
	odin run .

release:
	odin build . -o:speed -microarch:native

debug:
	odin build . -debug

install: release
	mkdir -p ~/.local/bin
	cp otempl ~/.local/bin/otempl
	chmod +x ~/.local/bin/otempl

clean:
	rm -rf otempl otempl.dSYM/
