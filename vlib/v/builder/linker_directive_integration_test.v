module builder

import os
import v.pref

struct CppLinkerDriverPair {
	c   string
	cpp string
}

fn run_cpp_linker_v_args(root string, args []string) os.Result {
	return run_cpp_linker_v_args_in(root, args, @VEXEROOT)
}

fn run_cpp_linker_v_args_in(root string, args []string, work_folder string) os.Result {
	mut process := os.new_process(@VEXE)
	process.set_args(args)
	process.set_work_folder(work_folder)
	mut env := os.environ()
	for key in env.keys() {
		if key.to_upper_ascii() in ['CFLAGS', 'LDFLAGS', 'VFLAGS'] {
			env.delete(key)
		}
	}
	env['VCACHE'] = os.join_path(root, 'vcache')
	process.set_environment(env)
	process.set_redirect_stdio()
	process.wait()
	stdout := process.stdout_slurp()
	stderr := process.stderr_slurp()
	code := process.code
	process.close()
	return os.Result{
		exit_code: code
		output:    '${stdout}\n${stderr}'
	}
}

fn available_cpp_linker_driver_pairs() []CppLinkerDriverPair {
	mut pairs := []CppLinkerDriverPair{}
	for names in [
		['gcc', 'g++'],
		['clang', 'clang++'],
		['clang-17', 'clang++-17'],
	] {
		c := os.find_abs_path_of_executable(names[0]) or { continue }
		cpp := os.find_abs_path_of_executable(names[1]) or { continue }
		c_family := compiler_command_gnu_family(c)
		cpp_family := compiler_command_gnu_family(cpp)
		if c_family == '' || cpp_family == '' || c_family != cpp_family {
			continue
		}
		if !pairs.any(it.c == c && it.cpp == cpp) {
			pairs << CppLinkerDriverPair{
				c:   c
				cpp: cpp
			}
		}
	}
	return pairs
}

fn run_cpp_linker_v_compile(root string, pair CppLinkerDriverPair, mode string, extra_args []string, run_binary bool) os.Result {
	return run_cpp_linker_v_compile_source(root, pair, mode, extra_args, run_binary, 'main.v')
}

fn run_cpp_linker_v_compile_source(root string, pair CppLinkerDriverPair, mode string, extra_args []string, run_binary bool, source_name string) os.Result {
	output := os.join_path(root, '${mode}${if os.user_os() == 'windows' { '.exe' } else { '' }}')
	mut args := ['-gc', 'none', '-cc', pair.c, '-c++', pair.cpp, '-no-retry-compilation']
	args << extra_args
	diag_direct := os.user_os() == 'windows' && mode == 'direct'
		&& os.getenv('ISSUE74_WINGCC_CLANG_DIAG') != ''
		&& os.file_name(pair.c).to_lower().starts_with('clang')
	if diag_direct {
		args << '-showcc'
	}
	args << ['-o', output, os.join_path(root, source_name)]
	mut process := os.new_process(@VEXE)
	process.set_args(args)
	process.set_work_folder(@VEXEROOT)
	mut env := os.environ()
	for key in env.keys() {
		if key.to_upper_ascii() in ['CFLAGS', 'LDFLAGS', 'VFLAGS'] {
			env.delete(key)
		}
	}
	env['VCACHE'] = os.join_path(root, 'vcache')
	if diag_direct {
		env['VTMP'] = os.join_path(os.getenv('ISSUE74_WINGCC_CLANG_DIAG'), 'failure-vtmp')
		env['V_NO_RM_CLEANUP_FILES'] = '1'
	}
	process.set_environment(env)
	process.set_redirect_stdio()
	process.wait()
	stdout := process.stdout_slurp()
	stderr := process.stderr_slurp()
	code := process.code
	process.close()
	if diag_direct {
		issue74_write_bounded_log(os.join_path(os.getenv('ISSUE74_WINGCC_CLANG_DIAG'),
			'failure-build.log'), 'argv=${args.join(' ')}\nexit=${code}\n${stdout}\n${stderr}')
	}
	if code != 0 {
		return os.Result{
			exit_code: code
			output:    '${stdout}\n${stderr}'
		}
	}
	if !run_binary {
		return os.Result{
			exit_code: 0
			output:    '${stdout}\n${stderr}'
		}
	}
	run := os.execute(os.quoted_path(output))
	return os.Result{
		exit_code: run.exit_code
		output:    run.output
	}
}

fn issue74_write_bounded_log(path string, content string) {
	marker := '\n[TRUNCATED]\n'
	mut lines := content.split_into_lines()
	if lines.len > 299 {
		lines = lines[..299]
		lines << marker.trim_space()
	}
	mut bounded := lines.join('\n') + '\n'
	max_content := 255 * 1024 - marker.len
	if bounded.len > 255 * 1024 {
		bounded = bounded[..max_content] + marker
	}
	os.write_file(path, bounded) or {}
}

fn issue74_wingcc_diag_exec(root string, label string, executable string, args []string) os.Result {
	os.mkdir_all(root) or {}
	mut process := os.new_process(executable)
	process.set_args(args)
	process.set_work_folder(root)
	mut env := os.environ()
	for key in env.keys() {
		if key.to_upper_ascii() in ['CFLAGS', 'LDFLAGS', 'VFLAGS'] {
			env.delete(key)
		}
	}
	env['VTMP'] = os.join_path(root, 'vtmp')
	env['VCACHE'] = os.join_path(root, 'vcache')
	env['V_NO_RM_CLEANUP_FILES'] = '1'
	process.set_environment(env)
	process.set_redirect_stdio()
	process.wait()
	stdout := process.stdout_slurp()
	stderr := process.stderr_slurp()
	code := process.code
	process.close()
	log := 'command=${os.file_name(executable)} ${args.join(' ')}\nexit=${code}\n${stdout}\n${stderr}'
	issue74_write_bounded_log(os.join_path(root, '${label}.log'), log)
	return os.Result{ exit_code: code, output: '${stdout}\n${stderr}' }
}

fn issue74_capture_windows_clang_runtime_failure(root string, pair CppLinkerDriverPair) {
	diag_root := os.getenv('ISSUE74_WINGCC_CLANG_DIAG')
	if diag_root == '' || os.user_os() != 'windows' || !os.file_name(pair.c).to_lower().starts_with('clang') {
		return
	}
	os.mkdir_all(diag_root) or { return }
	issue74_wingcc_diag_exec(diag_root, 'c-version', pair.c, ['--version'])
	issue74_wingcc_diag_exec(diag_root, 'c-dumpmachine', pair.c, ['-dumpmachine'])
	issue74_wingcc_diag_exec(diag_root, 'cpp-version', pair.cpp, ['--version'])
	issue74_wingcc_diag_exec(diag_root, 'cpp-dumpmachine', pair.cpp, ['-dumpmachine'])
	failure_root := os.join_path(diag_root, 'failure')
	os.mkdir_all(failure_root) or {}
	for name in ['direct.exe', 'runtime.o', 'main.v', 'runtime.cpp', 'sentinel.c'] {
		source := os.join_path(root, name)
		if os.is_file(source) && !os.is_link(source) {
			os.cp(source, os.join_path(failure_root, name)) or {}
		}
	}
	failure_vtmp := os.join_path(diag_root, 'failure-vtmp')
	if os.is_dir(failure_vtmp) {
		for index, source in os.walk_ext(failure_vtmp, '.c') {
			if index >= 8 {
				break
			}
			if os.is_link(source) { continue }
			os.cp(source, os.join_path(failure_root, 'generated-${index}.c')) or {}
		}
		for index, source in os.walk_ext(failure_vtmp, '.rsp') {
			if index >= 4 { break }
			if os.is_link(source) { continue }
			os.cp(source, os.join_path(failure_root, 'response-${index}.rsp')) or {}
		}
	}
	// A: pure V compiled and linked by the selected C driver.
	a_root := os.join_path(diag_root, 'a-pure-v-c')
	os.mkdir_all(a_root) or { return }
	os.write_file(os.join_path(a_root, 'main.v'), 'fn main() { assert 7 == 7 }\n') or { return }
	a := issue74_wingcc_diag_exec(a_root, 'result', @VEXE, ['-gc', 'none', '-cc', pair.c, '-no-retry-compilation', '-no-rsp', '-showcc', '-o', os.join_path(a_root, 'a.exe'), os.join_path(a_root, 'main.v')])
	os.write_file(os.join_path(a_root, 'exit.txt'), '${a.exit_code}\n') or {}
	if a.exit_code == 0 {
		a_run := issue74_wingcc_diag_exec(a_root, 'runtime', os.join_path(a_root, 'a.exe'), [])
		os.write_file(os.join_path(a_root, 'runtime-exit.txt'), '${a_run.exit_code}\n') or {}
	}
	// B: pure V plus #linker c++, exercising the selected C/C++ pair.
	b_root := os.join_path(diag_root, 'b-pure-v-cpp-link')
	os.mkdir_all(b_root) or { return }
	os.write_file(os.join_path(b_root, 'main.v'), 'module main\n#linker c++\nfn main() { assert 7 == 7 }\n') or { return }
	b := issue74_wingcc_diag_exec(b_root, 'result', @VEXE, ['-gc', 'none', '-cc', pair.c, '-c++', pair.cpp, '-no-retry-compilation', '-no-rsp', '-showcc', '-o', os.join_path(b_root, 'b.exe'), os.join_path(b_root, 'main.v')])
	os.write_file(os.join_path(b_root, 'exit.txt'), '${b.exit_code}\n') or {}
	if b.exit_code == 0 {
		b_run := issue74_wingcc_diag_exec(b_root, 'runtime', os.join_path(b_root, 'b.exe'), [])
		os.write_file(os.join_path(b_root, 'runtime-exit.txt'), '${b_run.exit_code}\n') or {}
	}
	// C: a C main linked with a copied C++ runtime object by clang++.
	c_root := os.join_path(diag_root, 'c-native-runtime')
	os.mkdir_all(c_root) or { return }
	os.write_file(os.join_path(c_root, 'main.c'), 'int issue74_runtime(void); int main(void) { return issue74_runtime() == 7 ? 0 : 1; }\n') or { return }
	os.write_file(os.join_path(c_root, 'runtime.cpp'), 'extern "C" int issue74_runtime(void) { int* p = new int(7); int v = *p; delete p; return v; }\n') or { return }
	main_compile := issue74_wingcc_diag_exec(c_root, 'compile-main', pair.c, ['-c', os.join_path(c_root, 'main.c'), '-o', os.join_path(c_root, 'main.o')])
	os.write_file(os.join_path(c_root, 'main-compile-exit.txt'), '${main_compile.exit_code}\n') or {}
	compile := issue74_wingcc_diag_exec(c_root, 'compile-runtime', pair.cpp, ['-std=c++14', '-c', os.join_path(c_root, 'runtime.cpp'), '-o', os.join_path(c_root, 'runtime.o')])
	os.write_file(os.join_path(c_root, 'compile-exit.txt'), '${compile.exit_code}\n') or {}
	link := issue74_wingcc_diag_exec(c_root, 'link', pair.cpp, [os.join_path(c_root, 'main.o'), os.join_path(c_root, 'runtime.o'), '-o', os.join_path(c_root, 'c.exe')])
	os.write_file(os.join_path(c_root, 'link-exit.txt'), '${link.exit_code}\n') or {}
	if link.exit_code == 0 {
		c_run := issue74_wingcc_diag_exec(c_root, 'runtime', os.join_path(c_root, 'c.exe'), [])
		os.write_file(os.join_path(c_root, 'runtime-exit.txt'), '${c_run.exit_code}\n') or {}
	}
	readobj := os.join_path(os.dir(pair.c), 'llvm-readobj.exe')
	if os.is_executable(readobj) {
		preflight := issue74_wingcc_diag_exec(diag_root, 'readobj-version', readobj, ['--version'])
		if preflight.exit_code != 0 { return }
		artifacts := [os.join_path(failure_root, 'direct.exe'), os.join_path(failure_root, 'runtime.o'), os.join_path(a_root, 'a.exe'), os.join_path(b_root, 'b.exe'), os.join_path(c_root, 'c.exe'), os.join_path(c_root, 'main.o'), os.join_path(c_root, 'runtime.o')]
		labels := ['failure-direct', 'failure-runtime', 'control-a', 'control-b', 'control-c', 'control-main', 'control-runtime']
		for index, artifact in artifacts {
			if os.is_file(artifact) {
				issue74_wingcc_diag_exec(diag_root, 'readobj-${labels[index]}', readobj, ['--file-headers', '--coff-imports', '--symbols', artifact])
			}
		}
	}
}

fn run_cpp_linker_cache_route(root string, pair CppLinkerDriverPair, mode string, extra_args []string, source_name string) {
	cache_dir := os.join_path(root, 'vcache')
	os.rmdir_all(cache_dir) or {}
	for iteration in 0 .. 2 {
		mut args := ['-usecache', '-showcc']
		args << extra_args
		result := run_cpp_linker_v_compile_source(root, pair, mode, args, false, source_name)
		assert result.exit_code == 0, '${pair.c}/${pair.cpp} ${mode} ${iteration}: ${result.output}'
		assert result.output.contains(pair.cpp), result.output
		if iteration == 0 {
			assert os.is_dir(cache_dir), cache_dir
		}
		output := os.join_path(root, '${mode}${if os.user_os() == 'windows' { '.exe' } else { '' }}')
		assert os.is_file(output), output
	}
}

fn test_cpp_linker_real_drivers_keep_c_inputs_and_supply_their_runtime() {
	pairs := available_cpp_linker_driver_pairs()
	if pairs.len == 0 {
		eprintln('> skipping #linker c++ integration: no matching C/C++ GNU driver pair')
		return
	}
	for pair_index, pair in pairs {
		root := os.join_path(os.vtmp_dir(),
			'v cpp linker ${os.file_name(pair.cpp).replace('+', 'p')}')
		os.rmdir_all(root) or {}
		os.mkdir_all(root) or { panic(err) }
		defer {
			os.rmdir_all(root) or {}
		}
		os.write_file(os.join_path(root, 'v.mod'), "Module { name: 'cpp_linker_probe' }\n") or {
			panic(err)
		}
		os.write_file(os.join_path(root, 'sentinel.c'),
			'#ifdef __cplusplus\n#error V_C_SOURCE_WAS_COMPILED_AS_CXX\n#endif\nint v_c_sentinel(void) { return 7; }\n') or {
			panic(err)
		}
		os.write_file(os.join_path(root, 'runtime.cpp'),
			'extern "C" int v_cpp_runtime(void) { int* p = new int(7); int value = *p; delete p; return value; }\n') or {
			panic(err)
		}
		os.mkdir_all(os.join_path(root, 'cppdep')) or { panic(err) }
		os.write_file(os.join_path(root, 'cppdep', 'cppdep.v'),
			'module cppdep\n#linker c++\npub fn value() int { return 0 }\n') or { panic(err) }
		os.write_file(os.join_path(root, 'main.v'),
			'module main\nimport cppdep\n#flag @VMODROOT/sentinel.c\n#flag @VMODROOT/runtime.o\nfn C.v_c_sentinel() int\nfn C.v_cpp_runtime() int\nfn main() { println(cppdep.value() + C.v_c_sentinel() + C.v_cpp_runtime()) }\n') or {
			panic(err)
		}
		// Keep this parallel fixture free of external C sources. Parallel compilation of
		// user-supplied `#flag *.c` inputs is an independent, pre-existing limitation.
		os.write_file(os.join_path(root, 'parallel_main.v'),
			'module main\nimport cppdep\n#flag @VMODROOT/runtime.o\nfn C.v_cpp_runtime() int\nfn main() { println(cppdep.value() + C.v_cpp_runtime()) }\n') or {
			panic(err)
		}
		cpp_compile := os.execute('${os.quoted_path(pair.cpp)} -std=c++14 -c ${os.quoted_path(os.join_path(root,
			'runtime.cpp'))} -o ${os.quoted_path(os.join_path(root, 'runtime.o'))}')
		assert cpp_compile.exit_code == 0, '${pair.cpp}: ${cpp_compile.output}'
		mode_args := {
			'direct': ['-no-rsp']
			'rsp':    []string{}
			'prod':   ['-prod']
		}
		for mode in ['direct', 'rsp', 'prod'] {
			args := mode_args[mode]
			result := run_cpp_linker_v_compile(root, pair, mode, args, true)
			if mode == 'direct' && result.exit_code != 0 {
				issue74_capture_windows_clang_runtime_failure(root, pair)
			}
			assert result.exit_code == 0, '${pair.c}/${pair.cpp} ${mode}: ${result.output}'
			assert result.output.trim_space() == '14', '${pair.c}/${pair.cpp} ${mode}: ${result.output}'
		}
		parallel_result := run_cpp_linker_v_compile_source(root, pair, 'parallel', [
			'-parallel-cc',
			'-no-rsp',
		], true, 'parallel_main.v')
		assert parallel_result.exit_code == 0, '${pair.c}/${pair.cpp} parallel: ${parallel_result.output}'
		assert parallel_result.output.trim_space() == '7', '${pair.c}/${pair.cpp} parallel: ${parallel_result.output}'
		shared_result := run_cpp_linker_v_compile(root, pair, 'shared', [
			'-shared',
			'-showcc',
		], false)
		assert shared_result.exit_code == 0, '${pair.c}/${pair.cpp} shared: ${shared_result.output}'
		assert shared_result.output.contains(pair.cpp), '${pair.c}/${pair.cpp} shared: ${shared_result.output}'
		if pair_index == 0 {
			mut cache_route_count := 0
			run_cpp_linker_cache_route(root, pair, 'cache_direct', ['-no-rsp'], 'main.v')
			cache_route_count++
			run_cpp_linker_cache_route(root, pair, 'cache_rsp', [], 'main.v')
			cache_route_count++
			if os.user_os() != 'macos' {
				run_cpp_linker_cache_route(root, pair, 'cache_parallel', [
					'-parallel-cc',
					'-no-rsp',
				], 'parallel_main.v')
				cache_route_count++
			}
			expected_cache_route_count := if os.user_os() == 'macos' { 2 } else { 3 }
			assert cache_route_count == expected_cache_route_count
		}
	}
}

fn test_cpp_linker_compile_only_paths_do_not_probe_the_cpp_driver() {
	root := os.join_path(os.vtmp_dir(), 'v_cpp_linker_compile_only')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	source := os.join_path(root, 'main.v')
	os.write_file(source, 'module main\n#linker c++\nfn main() {}\n') or { panic(err) }
	missing_cpp := 'v_missing_cpp_driver_78362'
	for mode, extra_args in {
		'native_c': []string{}
		'cross_c':  ['-cross']
	} {
		output := os.join_path(root, '${mode}.c')
		mut args := ['-gc', 'none', '-c++', missing_cpp, '-no-retry-compilation']
		args << extra_args
		args << ['-o', output, source]
		result := run_cpp_linker_v_args(root, args)
		assert result.exit_code == 0, '${mode}: ${result.output}'
		assert os.is_file(output), mode
	}
	pairs := available_cpp_linker_driver_pairs()
	assert pairs.len > 0, 'no matching C/C++ GNU driver pair for build-module compile-only test'
	pair := pairs[0]
	module_dir := os.join_path(root, 'compile_only_module')
	os.mkdir_all(module_dir) or { panic(err) }
	os.write_file(os.join_path(module_dir, 'compile_only_module.v'),
		'module compile_only_module\n#linker c++\npub fn value() int { return 1 }\n') or {
		panic(err)
	}
	module_result := run_cpp_linker_v_args_in(root, [
		'-gc',
		'none',
		'-cc',
		pair.c,
		'-shared',
		'-c++',
		missing_cpp,
		'-no-retry-compilation',
		'build-module',
		'compile_only_module',
	], root)
	assert module_result.exit_code == 0, module_result.output
	assert !module_result.output.contains('requires the C++ driver'), module_result.output
}

fn test_cpp_linker_cross_target_executable_reports_before_driver_selection() {
	root := os.join_path(os.vtmp_dir(), 'v_cpp_linker_cross_diagnostic')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	source := os.join_path(root, 'main.v')
	os.write_file(source, 'module main\n#linker c++\nfn main() {}\n') or { panic(err) }
	target_os := if os.user_os() == 'windows' { 'linux' } else { 'windows' }
	cross_arch := if pref.get_host_arch() == .arm64 { 'amd64' } else { 'arm64' }
	for label, target_args in {
		'os':   ['-os', target_os]
		'arch': ['-arch', cross_arch]
	} {
		mut args := ['-gc', 'none']
		args << target_args
		args << ['-c++', 'v_missing_cpp_driver_78362', '-no-retry-compilation', '-o',
			os.join_path(root, 'cross-target-${label}'), source]
		result := run_cpp_linker_v_args(root, args)
		assert result.exit_code != 0
		assert result.output.contains('does not support cross-target linking yet'), result.output
		assert !result.output.contains('requires the C++ driver'), result.output
	}
}
