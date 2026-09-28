package main

import "core:fmt"
import "core:os"
import "./font"

main :: proc() {
	args := os.args
	if len(args) > 2 && args[1] != "run" {
		usage()
		os.exit(1)
	}

	command := "build"
	if len(args) >= 2 {
		command = args[1]
	}

	ok := false
	switch command {
	case "build":
		ok = exec({"odin", "build", ".", "-out:otempl"}, "Building otempl")
	case "run":
		run_command := make([dynamic]string, 0, 6 + len(args))
		append(&run_command, ..[]string{"odin", "run", ".", "-out:otempl"})
		if len(args) > 2 {
			append(&run_command, "--")
			append(&run_command, ..args[2:])
		}
		ok = exec(run_command[:], "Building and running otempl")
	case "release":
		ok = release()
	case "debug":
		ok = exec({"odin", "build", ".", "-out:otempl", "-debug"}, "Building debug version")
	case "bubbletext-font", "bubbletext_font":
		fmt.println("Generating bubbletext font...")
		font.build_bubbletext_font()
		fmt.println("Bubbletext font generated.")
		ok = true
	case "install":
		ok = install()
	case "clean":
		ok = clean()
	case:
		fmt.eprintfln("unknown command: %s", command)
		usage()
	}

	if !ok {
		os.exit(1)
	}
}

usage :: proc() {
	fmt.eprintln("usage: build [build|run [app arguments...]|release|debug|bubbletext-font|install|clean]")
}

release :: proc() -> bool {
	return exec({"odin", "build", ".", "-out:otempl", "-o:speed", "-microarch:native"}, "Building release version")
}

install :: proc() -> bool {
	if !release() || !exec({"strip", "otempl"}, "Stripping otempl") {
		return false
	}

	home, err := os.user_home_dir(context.allocator)
	if err != nil {
		fmt.eprintfln("cannot find home directory: %v", err)
		return false
	}
	dir := fmt.aprintf("%s/.local/bin", home)
	if os.exists(dir) && !os.is_directory(dir) {
		fmt.eprintfln("install path is not a directory: %s", dir)
		return false
	}
	if !os.is_directory(dir) {
		if err = os.make_directory_all(dir); err != nil && err != .Exist {
			fmt.eprintfln("cannot create %s: %v", dir, err)
			return false
		}
	}
	dst := fmt.aprintf("%s/otempl", dir)
	fmt.printfln("Installing otempl to %s...", dst)
	if err = os.copy_file(dst, "otempl"); err != nil {
		fmt.eprintfln("cannot install %s: %v", dst, err)
		return false
	}
	if err = os.change_mode(dst, os.Permissions_Read_All + os.Permissions_Execute_All + os.Permissions{.Write_User}); err != nil {
		fmt.eprintfln("cannot make %s executable: %v", dst, err)
		return false
	}
	fmt.println("Installed otempl.")
	return true
}

clean :: proc() -> bool {
	fmt.println("Cleaning build output...")
	if os.exists("otempl") {
		if err := os.remove("otempl"); err != nil {
			fmt.eprintfln("cannot remove otempl: %v", err)
			return false
		}
	}
	if os.exists("otempl.dSYM") {
		if err := os.remove_all("otempl.dSYM"); err != nil {
			fmt.eprintfln("cannot remove otempl.dSYM: %v", err)
			return false
		}
	}
	fmt.println("Build output cleaned.")
	return true
}

exec :: proc(command: []string, action: string) -> bool {
	fmt.printfln("%s...", action)
	process, err := os.process_start({
		command = command,
		stdin = os.stdin,
		stdout = os.stdout,
		stderr = os.stderr,
	})
	if err != nil {
		fmt.eprintfln("cannot start %s: %v", command[0], err)
		return false
	}
	state: os.Process_State
	state, err = os.process_wait(process)
	if err != nil {
		fmt.eprintfln("cannot wait for %s: %v", command[0], err)
		return false
	}
	if !state.success || state.exit_code != 0 {
		fmt.eprintfln("%s failed with exit code %d", command[0], state.exit_code)
		return false
	}
	fmt.println("Done.")
	return true
}
