package main

import bubbletext "./bubbletext"
import "core:flags"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "core:testing"

// Re: ownership. Everything lasts the lifetime of the app.
// This is only really intended to run for a few ms anyway.

Template_Type :: enum {
	basic,
	raylib,
	library,
}

Language :: enum {
	odin,
	c,
	go,
}

Substitution :: struct {
	key:   string,
	value: string,
}

Template_File :: struct {
	name: string,
	data: []byte,
}

Template :: struct {
	files:         []Template_File,
	substitutions: []Substitution,
}

TEMP_ARENA_SIZE :: 128 * mem.Kilobyte

temp_arena_buffer: [TEMP_ARENA_SIZE]byte
temp_arena:        mem.Arena

basic_template_files := [?]Template_File {
	{name = ".gitignore", data = #load("./templates/basic/.gitignore.template")},
	{name = "main.odin",  data = #load("./templates/basic/main.odin.template") },
	{name = "Makefile",   data = #load("./templates/basic/Makefile.template")  },
	{name = "README",     data = #load("./templates/basic/README.template")    },
}

raylib_template_files := [?]Template_File {
	{name = ".gitignore", data = #load("./templates/raylib/.gitignore.template")},
	{name = "main.odin",  data = #load("./templates/raylib/main.odin.template") },
	{name = "Makefile",   data = #load("./templates/raylib/Makefile.template")  },
	{name = "README",     data = #load("./templates/raylib/README.template")    },
}

library_template_files := [?]Template_File {
	{name = "{{name}}.odin",            data = #load("./templates/library/main.odin.template")         },
	{name = "examples/basic/main.odin", data = #load("./templates/library/examples/main.odin.template")},
	{name = "Makefile",                 data = #load("./templates/library/Makefile.template")          },
	{name = ".gitignore",               data = #load("./templates/library/.gitignore.template")        },
	{name = "ols.json",                 data = #load("./templates/library/ols.json.template")          },
	{name = "README",                   data = #load("./templates/library/README.template")            },
}

c_basic_template_files := [?]Template_File {
	// standard files
	{name = ".gitignore", data = #load("./templates/c/basic/.gitignore.template")},
	{name = "main.c",     data = #load("./templates/c/basic/main.c.template")    },
	{name = "Makefile",   data = #load("./templates/c/basic/Makefile.template")  },
	{name = "README",     data = #load("./templates/c/basic/README.template")    },
	{name = ".clangd",    data = #load("./templates/c/basic/.clangd.template")   },

	// my specific personal lib stuff
	{name = "base.h",        data = #load("./templates/c/basic/base.h.template")       },
	{name = "alignment.c",   data = #load("./templates/c/basic/alignment.c.template")  },
	{name = "alignment.h",   data = #load("./templates/c/basic/alignment.h.template")  },
	{name = "arena.c",       data = #load("./templates/c/basic/arena.c.template")      },
	{name = "arena.h",       data = #load("./templates/c/basic/arena.h.template")      },
	{name = "string_view.c", data = #load("./templates/c/basic/string_view.c.template")},
	{name = "string_view.h", data = #load("./templates/c/basic/string_view.h.template")},
	{name = "files.h",       data = #load("./templates/c/basic/files.h.template")      },
	{name = "files.c",       data = #load("./templates/c/basic/files.c.template")      },
}

go_basic_template_files := [?]Template_File {
	{name = ".gitignore", data = #load("./templates/go/basic/.gitignore.template")},
	{name = "main.go",    data = #load("./templates/go/basic/main.go.template")   },
	{name = "README",     data = #load("./templates/go/basic/README.template")    },
}

go_basic_template_post_commands := [?][]string{
	{"go", "mod", "init", "{{name}}"},
	{"go", "mod", "tidy"},
}

template_create :: proc(files: []Template_File, name, description: string) -> Template {
	figlet := bubbletext.get_bytes(name)

	// note: Forced to use this awkward syntax to allocate to the heap. -gary
	substitutions := make([]Substitution, 3)
	substitutions[0] = {
		key   = "name",
		value = name,
	}
	substitutions[1] = {
		key   = "figlet",
		value = string(figlet),
	}
	substitutions[2] = {
		key   = "description",
		value = description,
	}

	return Template{files = files, substitutions = substitutions}
}

commands_apply_substitutions :: proc(commands: [][]string, substitutions: []Substitution) {
	for &cmd in commands {
		for &token in cmd {
			for substitution in substitutions {
				placeholder := fmt.aprintf("{{{{%s}}}}", substitution.key)
				token, _ = strings.replace_all(token, placeholder, substitution.value)
			}
		}
	}
}

@(test)
does_apply_substitutions :: proc(t: ^testing.T) {
	buffer: [mem.Kilobyte]byte
	arena: mem.Arena
	mem.arena_init(&arena, buffer[:])
	context.allocator = mem.arena_allocator(&arena)

	commands := [][]string{{"go", "mod", "init", "example.com/{{name}}"}}
	substitutions := []Substitution{{key = "name", value = "test_passes"}}

	commands_apply_substitutions(commands, substitutions)
	testing.expect_value(t, commands[0][3], "example.com/test_passes")
}

template_produce_many :: proc(template: Template) -> []Template_File {
	transformed_templates := make([dynamic]Template_File)

	for file in template.files {
		name := file.name
		data := string(file.data)

		for substitution in template.substitutions {
			placeholder := fmt.aprintf("{{{{%s}}}}", substitution.key)
			name, _ = strings.replace_all(name, placeholder, substitution.value)
			data, _ = strings.replace_all(data, placeholder, substitution.value)
		}

		append(&transformed_templates, Template_File{name = name, data = transmute([]byte)data})
	}

	return transformed_templates[:]
}

template_write_many :: proc(files: []Template_File, output_dir: string) -> bool {
	if err := os.make_directory(output_dir); err != nil {
		fmt.eprintfln("error: failed to create project directory %q: %v", output_dir, err)
		return false
	}

	cleanup :: proc(output_dir: string) {
		if os.remove_all(output_dir) != nil {
			panic("failed to clean up project directory after a write error")
		}
	}

	for file in files {
		file_path := fmt.aprintf("%s/%s", output_dir, file.name)
		dir_path, _ := os.split_path(file_path)

		if !os.exists(dir_path) {
			if err := os.make_directory_all(dir_path); err != nil {
				fmt.eprintfln("error: failed to create directory %q: %v", dir_path, err)
				cleanup(output_dir)
				return false
			}
		}

		if err := os.write_entire_file(file_path, file.data); err != nil {
			fmt.eprintfln("error: failed to write %q: %v", file_path, err)
			cleanup(output_dir)
			return false
		}
	}

	return true
}

basic_template_create :: proc(name, description: string) -> Template {
	return template_create(basic_template_files[:], name, description)
}

raylib_template_create :: proc(name, description: string) -> Template {
	return template_create(raylib_template_files[:], name, description)
}

library_template_create :: proc(name, description: string) -> Template {
	return template_create(library_template_files[:], name, description)
}

c_basic_template_create :: proc(name, description: string) -> Template {
	return template_create(c_basic_template_files[:], name, description)
}

go_basic_template_create :: proc(name, description: string) -> Template {
	return template_create(go_basic_template_files[:], name, description)
}

main :: proc() {
	mem.arena_init(&temp_arena, temp_arena_buffer[:])
	context.temp_allocator = mem.arena_allocator(&temp_arena)
	context.allocator = context.temp_allocator

	Options :: struct {
		type:        Template_Type `usage:"basic for minimal template, raylib for a raylib window template, library for a reusable package template."`,
		lang:        Language      `usage:"Project language: odin, c, or go. C and Go support only the Basic template."`,
		name:        string        `args:"pos=0,required" usage:"The name of the project."`,
		description: string        `usage:"Optional description for project."`,
		with_jj:     bool          `usage:"Init a Jujutsu repo."`,
		create_repo: bool          `usage:"Create a Forgejo repo."`
	}

	opt: Options
	style: flags.Parsing_Style = .Unix

	flags.parse_or_exit(&opt, os.args, style)

	template: Template
	template_name: string
	template_post_commands: [][]string

	switch opt.lang {
	case .odin:
		switch opt.type {
		case .basic:
			template = basic_template_create(opt.name, opt.description)
			template_name = "basic"
		case .raylib:
			template = raylib_template_create(opt.name, opt.description)
			template_name = "raylib"
		case .library:
			template = library_template_create(opt.name, opt.description)
			template_name = "library"
		}

	case .c:
		if opt.type != .basic {
			fmt.eprintfln("error: the %s template is not available for C", opt.type)
			os.exit(1)
		}
		template = c_basic_template_create(opt.name, opt.description)
		template_name = "C basic"

	case .go:
		if opt.type != .basic {
			fmt.eprintfln("error: the %s template is not available for Go", opt.type)
			os.exit(1)
		}
		template = go_basic_template_create(opt.name, opt.description)
		template_name = "Go basic"
		template_post_commands = go_basic_template_post_commands[:]

	case:
		fmt.eprintln("error: unsupported programming language")
		os.exit(1)
	}

	fmt.printfln("Generating %s template in %q...", template_name, opt.name)
	files := template_produce_many(template)
	if !template_write_many(files, opt.name) {
		panic(fmt.aprintf("failed to create %s template", template_name))
	}
	fmt.printfln("Created %s template in %q", template_name, opt.name)

	exec :: proc(command: []string, dir: string) -> bool {
		cwd_str, _ := os.get_working_directory(context.allocator)
		cwd := fmt.aprintf("%s/%s", cwd_str, dir)
		state, _, stderr, err := os.process_exec(
			{working_dir = cwd, command = command},
			context.allocator,
		)
		if err != nil || state.exit_code != 0 {
			fmt.eprintfln("%s command failed: %q", command[0], command)
			if err != nil {
				fmt.eprintfln("  error: %v", err)
			}
			if len(stderr) > 0 {
				fmt.eprintfln("  stderr: %s", stderr)
			}
			return false
		}
		return true
	}

	if len(template_post_commands) > 0 {
		commands_apply_substitutions(template_post_commands, template.substitutions)
		for cmd in template_post_commands {
			if !exec(cmd, opt.name) {
				os.exit(1)
			}
		}
	}

	with_jj := opt.with_jj || opt.create_repo

	if with_jj {
		fmt.println("Creating a jj repo...")

		remote := fmt.aprintf("ssh://git@git.mooremoore.net/gmoore/%s", opt.name)
		exec({"jj", "git", "init", "--colocate"}, opt.name)
		exec({"jj", "desc", "-r", "@", "-m", "initial commit"}, opt.name)
		exec({"jj", "git", "remote", "add", "origin", remote}, opt.name)
		exec({"jj", "bookmark", "create", "-r", "@", "main"}, opt.name)
		exec({"jj", "bookmark", "track", "main", "--remote=origin"}, opt.name)
		exec({"jj", "new"}, opt.name)

		fmt.println("Created jj repo")

		if opt.create_repo {
			fmt.println("Creating repo on Forgejo...")
			exec({"fj", "repo", "create", "--ssh", "true", "--private", opt.name}, opt.name)
			fmt.println("Created repo on Forejo")
		}
	}
}
