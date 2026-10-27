package vendoring

import "core:os"
import "base:runtime"
import "core:strings"
import "core:c"
import "core:fmt"
import "vendor:curl"

Download_State :: struct {
	input:        ^os.File,
	odin_context: runtime.Context,
}

write_cb :: proc "c" (ptr: [^]c.char, size: c.size_t, nmemb: c.size_t, userdata: rawptr) -> c.size_t {
	download_state := cast(^Download_State)userdata
	context = download_state.odin_context

	total_bytes := size * nmemb
	remaining := transmute([]u8)ptr[:total_bytes]
	for len(remaining) > 0 {
		n, err := os.write(download_state.input, remaining)
		if err != nil || n == 0 {
			fmt.eprintfln("cannot write tar input: %v (%d bytes written)", err, n)
			// A short return tells curl to abort the download.
			return 0
		}
		remaining = remaining[n:]
	}

	return total_bytes
}

gunzip_download_and_extract_into_dir :: proc(download_url: string, output_dir: string) -> (ok: bool) {
	// Configure the download before starting tar.
	curl_state: ^curl.CURL
	curl_state = curl.easy_init()
	if curl_state == nil {
		fmt.eprintln("cannot initialize curl")
		return false
	}
	defer curl.easy_cleanup(curl_state)

	url := strings.clone_to_cstring(download_url)
	defer delete(url)
	curl.easy_setopt(curl_state, .URL, url)
	curl.easy_setopt(curl_state, .FOLLOWLOCATION, 1)
	curl.easy_setopt(curl_state, .FAILONERROR, 1)
	curl.easy_setopt(curl_state, .WRITEFUNCTION, write_cb)

	// Start the extractor before curl begins streaming.
	if err := os.make_directory_all(output_dir); err != nil && err != .Exist {
		fmt.eprintfln("cannot create %s: %v", output_dir, err)
		return false
	}

	input_r, input_w, pipe_err := os.pipe()
	if pipe_err != nil {
		fmt.eprintfln("cannot create tar input pipe: %v", pipe_err)
		return false
	}

	process, start_err := os.process_start({
		command = []string{"tar", "-xz", "-f", "-", "-C", output_dir},
		stdin = input_r,
		stdout = os.stdout,
		stderr = os.stderr,
	})
	os.close(input_r)
	if start_err != nil {
		os.close(input_w)
		fmt.eprintfln("cannot start tar: %v", start_err)
		return false
	}

	download_state := Download_State{
		input = input_w,
		odin_context = context,
	}
	curl.easy_setopt(curl_state, .WRITEDATA, cast(rawptr)&download_state)
	result := curl.easy_perform(curl_state)
	if result != .E_OK {
		fmt.eprintfln("cannot download %s: %v", download_url, result)
	}

	// Closing the writer sends EOF; do this before waiting for tar.
	close_err := os.close(input_w)
	if close_err != nil {
		fmt.eprintfln("cannot close tar input: %v", close_err)
	}
	state, wait_err := os.process_wait(process)
	if wait_err != nil {
		fmt.eprintfln("cannot wait for tar: %v", wait_err)
		return false
	}
	if !state.exited || !state.success || state.exit_code != 0 {
		fmt.eprintfln("tar failed with exit code %d", state.exit_code)
		return false
	}
	return result == .E_OK && close_err == nil
}
