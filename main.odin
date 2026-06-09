package main

import "core:flags"
import "core:fmt"
import "core:os"
import "core:strings"

Template_Type :: enum {
	Basic,
	Raylib,
}

Basic_Template :: struct {
	gitignore: []byte,
	main:      []byte,
	makefile:  []byte,
}

basic_template :: Basic_Template {
	gitignore = #load("./templates/basic/.gitignore.template"),
	main      = #load("./templates/basic/main.odin.template"),
	makefile  = #load("./templates/basic/Makefile.template"),
}

raylib_template :: Basic_Template {
	gitignore = #load("./templates/raylib/.gitignore.template"),
	main      = #load("./templates/raylib/main.odin.template"),
	makefile  = #load("./templates/raylib/Makefile.template"),
}

basic_template_create :: proc(name: string, template: Basic_Template) -> bool {
	makefile_str := string(template.makefile)
	gitignore_str := string(template.gitignore)

	makefile_templated, makefile_templated_ok := strings.replace(makefile_str, "{name}", name, 100)
	if !makefile_templated_ok do return false

	gitignore_templated, gitignore_templated_ok := strings.replace(
		gitignore_str,
		"{name}",
		name,
		100,
	)
	if !gitignore_templated_ok do return false

	make_dir_err := os.make_directory(name)
	if make_dir_err != nil do return false

	makefile_write_err := os.write_entire_file(
		fmt.aprintf("%s/Makefile", name),
		makefile_templated,
	)
	if makefile_write_err != nil do return false

	main_write_err := os.write_entire_file(fmt.aprintf("%s/main.odin", name), template.main)
	if main_write_err != nil do return false

	gitignore_write_err := os.write_entire_file(
		fmt.aprintf("%s/.gitignore", name),
		gitignore_templated,
	)
	if gitignore_write_err != nil do return false

	return true
}

main :: proc() {
	Options :: struct {
		type: Template_Type `usage:"Basic for minimal template, Raylib for a raylib window template."`,
		name: string `args:"pos=0,required" usage:"The name of the project"`,
	}

	opt: Options
	style: flags.Parsing_Style = .Odin

	flags.parse_or_exit(&opt, os.args, style)

	switch opt.type {
	case .Basic:
		fmt.printfln("Generating basic template in %q...", opt.name)
		ok := basic_template_create(opt.name, basic_template)
		if !ok do panic("failed to create basic template")
		fmt.printfln("Created basic template in %q", opt.name)
	case .Raylib:
		fmt.printfln("Generating raylib template in %q...", opt.name)
		ok := basic_template_create(opt.name, raylib_template)
		if !ok do panic("Failed to create raylib template")
		fmt.printfln("Created raylib template in %q", opt.name)
	}
}
