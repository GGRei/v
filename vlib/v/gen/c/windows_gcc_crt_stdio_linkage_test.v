// vtest build: windows && gcc
// vtest vflags: -cc gcc -cstrict -no-retry-compilation

fn C._fseeki64(stream &C.FILE, offset u64, whence int) int
fn C.fdopen(fd int, mode &char) &C.FILE

fn crt_stdio_linkage_noop() {}

@[noinline]
fn link_windows_gcc_crt_stdio_imports(run bool) {
	if !run {
		return
	}
	pipe := C.popen(c'cmd /c exit 0', c'r')
	if !isnil(pipe) {
		_ = C.pclose(unsafe { &C.FILE(pipe) })
	}
	file := C.fopen(c'NUL', c'rb')
	if !isnil(file) {
		_ = C._fileno(file)
		_ = C._fseeki64(file, 0, 0)
		_ = C.fclose(file)
	}
	fd_file := C.fdopen(-1, c'r')
	if !isnil(fd_file) {
		_ = C.fclose(fd_file)
	}
	at_exit(crt_stdio_linkage_noop) or {}
}

fn test_windows_gcc_crt_stdio_imports_compile_and_link() {
	$if !windows {
		$compile_error('this regression must be compiled on Windows')
	}
	$if !gcc {
		$compile_error('this regression must be compiled with GCC')
	}
	assert @CCOMPILER == 'gcc'
	link_windows_gcc_crt_stdio_imports(arguments().len == 0)
}
