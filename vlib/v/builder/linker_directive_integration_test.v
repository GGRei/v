module builder

import os
import v.pref

struct CppLinkerDriverPair {
	c   string
	cpp string
}

fn cpp_linker_windows_gnu_target(target string) bool {
	lower := target.to_lower_ascii()
	if lower.contains('msvc') {
		return false
	}
	return lower.contains('mingw') || lower.contains('windows-gnu')
}

fn cpp_linker_driver_target(executable string) ?string {
	result := os.execute('${os.quoted_path(executable)} -dumpmachine')
	if result.exit_code != 0 {
		return none
	}
	target := result.output.trim_space()
	if target.len == 0 {
		return none
	}
	return target
}

fn assert_cpp_linker_windows_gnu_target_classifier() {
	assert cpp_linker_windows_gnu_target('x86_64-w64-mingw32')
	assert cpp_linker_windows_gnu_target('x86_64-pc-windows-gnu')
	assert !cpp_linker_windows_gnu_target('x86_64-pc-windows-msvc')
	assert !cpp_linker_windows_gnu_target('x86_64-w64-windows-msvc')
	assert !cpp_linker_windows_gnu_target('x86_64-unknown-linux-gnu')
	assert !cpp_linker_windows_gnu_target('')
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
		$if windows {
			c_target_raw := cpp_linker_driver_target(c) or { continue }
			cpp_target_raw := cpp_linker_driver_target(cpp) or { continue }
			c_target := c_target_raw.to_lower_ascii()
			cpp_target := cpp_target_raw.to_lower_ascii()
			if c_target != cpp_target || !cpp_linker_windows_gnu_target(c_target) {
				eprintln('> ignoring non-GNU Windows C/C++ driver pair: ${c_target} / ${cpp_target}')
				continue
			}
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
	process.set_environment(env)
	process.set_redirect_stdio()
	process.wait()
	stdout := process.stdout_slurp()
	stderr := process.stderr_slurp()
	code := process.code
	process.close()
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
	assert_cpp_linker_windows_gnu_target_classifier()
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
