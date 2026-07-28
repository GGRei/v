// vtest build: windows && tinyc
// vtest vflags: -cc tcc -no-retry-compilation
import os

fn test_windows_tcc_output_uses_exact_dword_pointer_types() {
	root := os.join_path(os.vtmp_dir(), 'windows_tcc_winapi_output_types_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root)!
	defer {
		os.rmdir_all(root) or {}
	}

	assert @CCOMPILER == 'tinyc'
	source_path := os.join_path(root, 'main.v')
	executable_path := os.join_path(root, 'winapi_output_types')
	os.write_file(source_path, "fn main() {\n\tprintln('winapi output types')\n}\n")!
	build_result :=
		os.execute('${os.quoted_path(@VEXE)} -cstrict -gc none -d v2_native_windows_pe_minimal -o ${os.quoted_path(executable_path)} ${os.quoted_path(source_path)}')
	assert build_result.exit_code == 0, build_result.output
	run_result := os.execute(os.quoted_path(executable_path))
	assert run_result.exit_code == 0, run_result.output
}
