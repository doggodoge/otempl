package main

import "core:flags"
import "core:fmt"
import "core:os"
import "core:strings"

Template_Type :: enum {
	Basic,
	Raylib,
	Library,
}

Basic_Template :: struct {
	gitignore: []byte,
	main:      []byte,
	makefile:  []byte,
	readme:    []byte,
}

basic_template :: Basic_Template {
	gitignore = #load("./templates/basic/.gitignore.template"),
	main      = #load("./templates/basic/main.odin.template"),
	makefile  = #load("./templates/basic/Makefile.template"),
	readme    = #load("./templates/basic/README.template"),
}

raylib_template :: Basic_Template {
	gitignore = #load("./templates/raylib/.gitignore.template"),
	main      = #load("./templates/raylib/main.odin.template"),
	makefile  = #load("./templates/raylib/Makefile.template"),
	readme    = #load("./templates/raylib/README.template"),
}

Library_Template :: struct {
	main_odin:    []byte,
	example_main: []byte,
	makefile:     []byte,
	gitignore:    []byte,
	ols_json:     []byte,
	readme:       []byte,
}

library_template :: Library_Template {
	main_odin    = #load("./templates/library/main.odin.template", []byte),
	example_main = #load("./templates/library/examples/main.odin.template", []byte),
	makefile     = #load("./templates/library/Makefile.template", []byte),
	gitignore    = #load("./templates/library/.gitignore.template", []byte),
	ols_json     = #load("./templates/library/ols.json.template", []byte),
	readme       = #load("./templates/library/README.template", []byte),
}

basic_template_create :: proc(
	template: Basic_Template,
	name: string,
	description: string,
) -> bool {
	readme_str := string(template.readme)
	makefile_str := string(template.makefile)
	gitignore_str := string(template.gitignore)

	figlet_cmd := []string{"figlet", "-f", "chunky", name}
	state, stdout, stderr, err := os.process_exec({command = figlet_cmd}, context.allocator)
	if err != nil || state.exit_code != 0 {
		fmt.eprintf("figlet command failed: %q\n", figlet_cmd)
		fmt.eprintf("  stderr: %s\n", stderr)
	}

	readme_templated: string

	figlet_template_result, _readme_templated_allocated := strings.replace(
		readme_str,
		"{figlet}",
		string(stdout),
		-1,
	)
	readme_templated = figlet_template_result

	if description == "" {
		res, _allocated := strings.replace(readme_templated, "{description}", "", -1)
		readme_templated = res
	} else {
		res, _allocated := strings.replace(readme_templated, "{description}", description, 1000)
		readme_templated = res
	}

	makefile_templated, _makefile_templated_allocated := strings.replace(
		makefile_str,
		"{name}",
		name,
		100,
	)

	gitignore_templated, _gitignore_templated_allocated := strings.replace(
		gitignore_str,
		"{name}",
		name,
		100,
	)

	make_dir_err := os.make_directory(name)
	if make_dir_err != nil do return false

	remove_dir_or_panic :: proc(name: string) {
		if os.remove_all(name) != nil {
			panic("Something has gone horribly wrong with fs operations")
		}
	}

	readme_write_err := os.write_entire_file(fmt.aprintf("%s/README", name), readme_templated)
	if readme_write_err != nil {
		remove_dir_or_panic(name)
		return false
	}

	makefile_write_err := os.write_entire_file(
		fmt.aprintf("%s/Makefile", name),
		makefile_templated,
	)
	if makefile_write_err != nil {
		remove_dir_or_panic(name)
		return false
	}

	main_write_err := os.write_entire_file(fmt.aprintf("%s/main.odin", name), template.main)
	if main_write_err != nil {
		remove_dir_or_panic(name)
		return false
	}

	gitignore_write_err := os.write_entire_file(
		fmt.aprintf("%s/.gitignore", name),
		gitignore_templated,
	)
	if gitignore_write_err != nil {
		remove_dir_or_panic(name)
		return false
	}

	return true
}

main :: proc() {
	context.allocator = context.temp_allocator

	Options :: struct {
		type:        Template_Type `usage:"Basic for minimal template, Raylib for a raylib window template, Library for a reusable package template."`,
		name:        string `args:"pos=0,required" usage:"The name of the project"`,
		description: string `usage:"Optional description for project."`,
		with_jj:     bool `usage:"Init a Jujutsu repo"`,
	}

	opt: Options
	style: flags.Parsing_Style = .Unix

	flags.parse_or_exit(&opt, os.args, style)

	switch opt.type {
	case .Basic:
		fmt.printfln("Generating basic template in %q...", opt.name)
		ok := basic_template_create(basic_template, opt.name, opt.description)
		if !ok do panic("failed to create basic template")
		fmt.printfln("Created basic template in %q", opt.name)
	case .Raylib:
		fmt.printfln("Generating raylib template in %q...", opt.name)
		ok := basic_template_create(raylib_template, opt.name, opt.description)
		if !ok do panic("Failed to create raylib template")
		fmt.printfln("Created raylib template in %q", opt.name)

	case .Library:
		fmt.printfln("Generating library template in %q...", opt.name)

		template_file :: proc(content: []byte, name: string) -> string {
			result, ok := strings.replace(string(content), "{name}", name, 100)
			if !ok do panic("failed to template library file")
			return result
		}

		// Template all files with the project name.
		main_odin := template_file(library_template.main_odin, opt.name)
		example_main := template_file(library_template.example_main, opt.name)
		makefile := template_file(library_template.makefile, opt.name)
		gitignore := template_file(library_template.gitignore, opt.name)
		ols_json := template_file(library_template.ols_json, opt.name)
		readme_str := template_file(library_template.readme, opt.name)

		figlet_cmd := []string{"figlet", "-f", "chunky", opt.name}
		state, stdout, stderr, err := os.process_exec({command = figlet_cmd}, context.allocator)
		if err != nil || state.exit_code != 0 {
			fmt.eprintf("figlet command failed: %q\n", figlet_cmd)
			fmt.eprintf("  stderr: %s\n", stderr)
		}

		readme := readme_str
		figlet_result, _ := strings.replace(readme, "{figlet}", string(stdout), -1)
		readme = figlet_result

		if opt.description == "" {
			res, _ := strings.replace(readme, "{description}", "", -1)
			readme = res
		} else {
			res, _ := strings.replace(readme, "{description}", opt.description, 1000)
			readme = res
		}

		// Create directory tree.
		if os.make_directory(opt.name) != nil {
			panic("failed to create project directory")
		}

		examples_dir := fmt.aprintf("%s/examples", opt.name)
		if os.make_directory(examples_dir) != nil {
			os.remove_all(opt.name)
			panic("failed to create examples directory")
		}

		examples_basic_dir := fmt.aprintf("%s/examples/basic", opt.name)
		if os.make_directory(examples_basic_dir) != nil {
			os.remove_all(opt.name)
			panic("failed to create examples/basic directory")
		}

		// Write all files, cleaning up on any failure.
		write_or_cleanup :: proc(path, content: string, project_dir: string) {
			if os.write_entire_file(path, content) != nil {
				os.remove_all(project_dir)
				panic(fmt.aprintf("failed to write %s", path))
			}
		}

		write_or_cleanup(fmt.aprintf("%s/%s.odin", opt.name, opt.name), main_odin, opt.name)
		write_or_cleanup(
			fmt.aprintf("%s/examples/basic/main.odin", opt.name),
			example_main,
			opt.name,
		)
		write_or_cleanup(fmt.aprintf("%s/Makefile", opt.name), makefile, opt.name)
		write_or_cleanup(fmt.aprintf("%s/.gitignore", opt.name), gitignore, opt.name)
		write_or_cleanup(fmt.aprintf("%s/ols.json", opt.name), ols_json, opt.name)
		write_or_cleanup(fmt.aprintf("%s/README", opt.name), readme, opt.name)

		fmt.printfln("Created library template in %q", opt.name)
	}


	if opt.with_jj {
		fmt.println("Creating a jj repo...")

		exec :: proc(command: []string, dir: string) {
			cwd_str, _ := os.get_working_directory(context.allocator)
			cwd := fmt.aprintf("%s/%s", cwd_str, dir)
			state, _, stderr, err := os.process_exec(
				{working_dir = cwd, command = command},
				context.allocator,
			)
			if err != nil || state.exit_code != 0 {
				fmt.eprintf("jj command failed: %q\n", command)
				fmt.eprintf("  stderr: %s\n", stderr)
			}
		}

		remote := fmt.aprintf("git@git.sr.ht:~gary_moore/%s", opt.name)
		exec({"jj", "git", "init", "--colocate"}, opt.name)
		exec({"jj", "desc", "-r", "@", "-m", "initial commit"}, opt.name)
		exec({"jj", "git", "remote", "add", "origin", remote}, opt.name)
		exec({"jj", "bookmark", "create", "-r", "@", "main"}, opt.name)
		exec({"jj", "bookmark", "track", "main", "--remote=origin"}, opt.name)
		exec({"jj", "new"}, opt.name)

		fmt.println("Created jj repo")
	}
}
