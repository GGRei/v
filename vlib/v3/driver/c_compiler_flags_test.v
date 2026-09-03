module driver

import os
import v3.pref
import v3.types

fn stage_windows_tcc_fls_def_for_test(cache_dir string, start chan bool) string {
	_ := <-start
	return v3_windows_tcc_fls_def_input_in_dir('windows', true, false, cache_dir) or {
		return 'error: ${err.msg()}'
	}
}

fn test_v3_tcc_backtrace_enabled() {
	assert !v3_tcc_backtrace_enabled('macos', 'arm64', false)
	assert v3_tcc_backtrace_enabled('macos', 'amd64', false)
	assert v3_tcc_backtrace_enabled('linux', 'arm64', false)
	assert !v3_tcc_backtrace_enabled('linux', 'arm64', true)
}

fn test_v3_explicit_tcc_flag_plan_skips_backtrace_on_macos_arm64() {
	vroot := os.join_path(os.temp_dir(), 'v3_tcc_flag_plan')
	plan := v3_c_compiler_flag_plan(V3CCompilerFlagOptions{
		explicit_tcc: true
		target_os:    'macos'
		target_arch:  'arm64'
		vroot:        vroot
	})
	assert '-bt25' !in plan.before_inputs
	tcc_install_dir := os.join_path(vroot, 'thirdparty', 'tcc', 'lib')
	assert '-B${tcc_install_dir}' in plan.before_inputs
	assert '-I${os.join_path_single(tcc_install_dir, 'include')}' in plan.before_inputs
	assert '-L${tcc_install_dir}' in plan.before_inputs
}

fn test_v3_explicit_tcc_flag_plan_restores_native_local_prefix() {
	host_os := os.user_os()
	plan := v3_c_compiler_flag_plan(V3CCompilerFlagOptions{
		explicit_tcc: true
		target_os:    host_os
		target_arch:  'amd64'
		vroot:        os.join_path(os.temp_dir(), 'v3_tcc_native_flag_plan')
	})
	if host_os == 'windows' {
		assert '-I/usr/local/include' !in plan.before_inputs
		assert '-L/usr/local/lib' !in plan.before_inputs
	} else {
		assert '-I/usr/local/include' in plan.before_inputs
		assert '-L/usr/local/lib' in plan.before_inputs
	}
}

fn test_v3_tcc_resource_flags_absolutizes_only_relative_nonempty_vroot() {
	old_cwd := os.getwd()
	root := os.join_path(os.vtmp_dir(), 'v3 tcc resource flags ${os.getpid()}')
	caller_cwd := os.join_path(root, 'caller cwd')
	distinct_build_cwd := os.join_path(root, 'distinct build cwd')
	relative_vroot := os.join_path('relative vroot', 'with spaces')
	relative_tcc_root := os.join_path(caller_cwd, relative_vroot, 'thirdparty', 'tcc')
	relative_lib_dir := os.join_path_single(relative_tcc_root, 'lib')
	relative_include_dir := os.join_path_single(relative_tcc_root, 'include')
	relative_winapi_include_dir := os.join_path_single(relative_include_dir, 'winapi')
	absolute_anchor := os.join_path(root, 'absolute spelling anchor')
	absolute_physical_vroot := os.join_path(root, 'absolute vroot with spaces')
	absolute_vroot := os.join_path(absolute_anchor, '..', 'absolute vroot with spaces')
	absolute_include_dir := os.join_path(absolute_physical_vroot, 'thirdparty', 'tcc',
		'lib', 'include')
	os.rmdir_all(root) or {}
	defer {
		os.chdir(old_cwd) or { panic(err) }
		os.rmdir_all(root) or {}
	}
	os.mkdir_all(relative_lib_dir) or { panic(err) }
	os.mkdir_all(relative_winapi_include_dir) or { panic(err) }
	os.mkdir_all(absolute_anchor) or { panic(err) }
	os.mkdir_all(absolute_include_dir) or { panic(err) }
	os.mkdir_all(distinct_build_cwd) or { panic(err) }

	os.chdir(caller_cwd) or { panic(err) }
	caller_wd := os.getwd()
	relative_flags := v3_tcc_resource_flags(relative_vroot)
	expected_relative_vroot := os.join_path(caller_wd, relative_vroot)
	expected_relative_lib := os.join_path(expected_relative_vroot, 'thirdparty', 'tcc',
		'lib')
	expected_relative_include := os.join_path(expected_relative_vroot, 'thirdparty', 'tcc',
		'include')
	expected_relative_winapi_include := os.join_path_single(expected_relative_include, 'winapi')
	assert relative_flags.install_dir == expected_relative_lib
	assert relative_flags.base_arg == '-B${expected_relative_lib}'
	assert relative_flags.include_arg == '-I${expected_relative_include}'
	assert relative_flags.winapi_include_arg == '-I${expected_relative_winapi_include}'
	assert relative_flags.library_arg == '-L${expected_relative_lib}'
	relative_paths := [
		relative_flags.install_dir,
		relative_flags.base_arg[2..],
		relative_flags.include_arg[2..],
		relative_flags.winapi_include_arg[2..],
		relative_flags.library_arg[2..],
	]
	for path in relative_paths {
		assert os.is_abs_path(path)
	}

	empty_flags := v3_tcc_resource_flags('')
	empty_lib := os.join_path('thirdparty', 'tcc', 'lib')
	assert empty_flags.install_dir == empty_lib
	assert empty_flags.base_arg == '-B${empty_lib}'
	assert empty_flags.include_arg == '-I${os.join_path_single(empty_lib, 'include')}'
	assert empty_flags.winapi_include_arg == ''
	assert empty_flags.library_arg == '-L${empty_lib}'
	assert !os.is_abs_path(empty_flags.install_dir)

	assert os.is_abs_path(absolute_vroot)
	assert absolute_vroot != os.abs_path(absolute_vroot)
	absolute_flags := v3_tcc_resource_flags(absolute_vroot)
	absolute_lib := os.join_path(absolute_vroot, 'thirdparty', 'tcc', 'lib')
	assert absolute_flags.install_dir == absolute_lib
	assert absolute_flags.base_arg == '-B${absolute_lib}'
	assert absolute_flags.include_arg == '-I${os.join_path_single(absolute_lib, 'include')}'
	assert absolute_flags.winapi_include_arg == ''
	assert absolute_flags.library_arg == '-L${absolute_lib}'

	os.chdir(distinct_build_cwd) or { panic(err) }
	assert os.getwd() != caller_wd
	for path in relative_paths {
		assert os.is_dir(path)
	}
}

fn test_v3_windows_tcc_fls_def_is_content_addressed_race_safe_and_link_only() {
	root := os.join_path(os.vtmp_dir(), 'v3 windows tcc fls ${os.getpid()}')
	cache_dir := os.join_path(root, 'shared cache')
	defer {
		os.rmdir_all(root) or {}
	}
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	root_stat := os.lstat(root) or { panic(err) }
	assert root_stat.get_filetype() == .directory
	assert !os.is_link(root)

	for gate in [
		v3_windows_tcc_fls_def_input_in_dir('linux', true, false, cache_dir) or { panic(err) },
		v3_windows_tcc_fls_def_input_in_dir('windows', false, false, cache_dir) or {
			panic(err)
		},
		v3_windows_tcc_fls_def_input_in_dir('windows', true, true, cache_dir) or { panic(err) },
	] {
		assert gate == ''
	}
	assert !os.exists(cache_dir)

	expected_content := 'LIBRARY kernel32.dll\nEXPORTS\nFlsAlloc\nFlsGetValue\nFlsSetValue\n'
	expected_digest := 'f247dfbecd121c6a3229b38f088cce1f8cc0537fff489c2e3251b2bd4d180c0f'
	assert v3_windows_tcc_fls_def_content == expected_content
	assert os.file_name(v3_windows_tcc_fls_def_path(cache_dir)) == 'v3_windows_tcc_fls_${expected_digest}.def'
	worker_count := 8
	start := chan bool{cap: worker_count}
	mut workers := []thread string{cap: worker_count}
	for _ in 0 .. worker_count {
		workers << spawn stage_windows_tcc_fls_def_for_test(cache_dir, start)
	}
	for _ in 0 .. worker_count {
		start <- true
	}
	mut published_paths := []string{cap: worker_count}
	for worker in workers {
		published_paths << worker.wait()
	}
	first := published_paths[0]
	for path in published_paths {
		assert !path.starts_with('error:'), path
		assert path == first
	}
	assert os.is_abs_path(first)
	assert first == os.abs_path(v3_windows_tcc_fls_def_path(cache_dir))
	assert os.read_file(first) or { panic(err) } == expected_content
	stat := os.lstat(first) or { panic(err) }
	assert stat.get_filetype() == .regular
	assert stat.size == u64(v3_windows_tcc_fls_def_content.len)
	assert !os.is_link(first)
	assert os.ls(cache_dir) or { panic(err) } == [os.file_name(first)]
	assert v3_windows_tcc_fls_def_input_in_dir('windows', true, false, cache_dir) or {
		panic(err)
	} == first

	file_cache_dir := os.join_path(root, 'file cache')
	os.write_file(file_cache_dir, 'not a directory') or { panic(err) }
	if _ := v3_windows_tcc_fls_def_input_in_dir('windows', true, false, file_cache_dir) {
		assert false, 'a regular file must not be accepted as the FLS cache directory'
	} else {
		assert err.msg().contains('failed to create Windows TCC FLS cache directory')
	}
	assert os.read_file(file_cache_dir) or { panic(err) } == 'not a directory'

	missing_cache_dir := os.join_path(root, 'missing parent', 'cache')
	if _ := v3_windows_tcc_fls_def_input_in_dir('windows', true, false, missing_cache_dir) {
		assert false, 'the FLS cache directory parent must already exist'
	} else {
		assert err.msg().contains('failed to create Windows TCC FLS cache directory')
	}
	assert !os.exists(os.dir(missing_cache_dir))

	$if !windows {
		cache_target := os.join_path(root, 'cache link target')
		os.mkdir(cache_target) or { panic(err) }
		cache_link := os.join_path(root, 'cache link')
		os.symlink(cache_target, cache_link) or { panic(err) }
		if _ := v3_windows_tcc_fls_def_input_in_dir('windows', true, false, cache_link) {
			assert false, 'a linked FLS cache directory must be rejected'
		} else {
			assert err.msg().contains('failed to create Windows TCC FLS cache directory')
		}
		cache_target_entries := os.ls(cache_target) or { panic(err) }
		assert cache_target_entries.len == 0
	}

	invalid_dir := os.join_path(root, 'invalid cache')
	os.mkdir_all(invalid_dir) or { panic(err) }
	invalid_path := v3_windows_tcc_fls_def_path(invalid_dir)
	os.write_file(invalid_path, 'invalid') or { panic(err) }
	mut rejected_invalid := false
	if _ := v3_windows_tcc_fls_def_input_in_dir('windows', true, false, invalid_dir) {
		assert false, 'an invalid preexisting FLS import file must be rejected'
	} else {
		rejected_invalid = true
		assert err.msg().contains('refusing invalid cached Windows TCC FLS import file')
	}
	assert rejected_invalid
	assert os.read_file(invalid_path) or { panic(err) } == 'invalid'

	$if !windows {
		link_dir := os.join_path(root, 'link cache')
		os.mkdir_all(link_dir) or { panic(err) }
		target := os.join_path(root, 'link target')
		os.write_file(target, v3_windows_tcc_fls_def_content) or { panic(err) }
		link_path := v3_windows_tcc_fls_def_path(link_dir)
		os.symlink(target, link_path) or { panic(err) }
		if _ := v3_windows_tcc_fls_def_input_in_dir('windows', true, false, link_dir) {
			assert false, 'a linked FLS import destination must be rejected'
		} else {
			assert err.msg().contains('refusing invalid cached Windows TCC FLS import file')
		}
	}
}

fn test_v3_windows_tcc_fls_def_stays_between_native_inputs_and_user_libraries() {
	root := os.join_path(os.vtmp_dir(), 'v3_windows_tcc_fls_order_${os.getpid()}')
	defer {
		os.rmdir_all(root) or {}
	}
	os.rmdir_all(root) or {}
	fls_def := v3_windows_tcc_fls_def_input_in_dir('windows', true, false, root) or {
		panic(err)
	}
	plan := V3CCompilerFlagPlan{
		before_inputs: ['-std=gnu11']
		after_inputs:  ['-luser']
	}
	args := plan.compiler_args('out', ['src.c'], ['atomic.o', fls_def])
	dump_flags := plan.all_flags(['atomic.o', fls_def])
	for flags in [args, dump_flags] {
		atomic_pos := flags.index('atomic.o')
		fls_pos := flags.index(fls_def)
		user_pos := flags.index('-luser')
		assert atomic_pos >= 0 && atomic_pos < fls_pos
		assert fls_pos < user_pos
		assert flags.count(it == fls_def) == 1
	}
	source_pos := args.index('src.c')
	fls_pos := args.index(fls_def)
	assert source_pos >= 0 && source_pos < fls_pos

	driver_source := os.read_file(os.join_path(os.dir(@FILE), 'driver.v')) or { panic(err) }
	// One definition plus the main, FastC, cached-dev and full-TCC link routes.
	assert driver_source.count('v3_windows_tcc_fls_def_input(') == 5
}

fn test_add_v3_tcc_compat_defines() {
	mut macos_arm64 := []string{}
	add_v3_tcc_compat_defines(mut macos_arm64, 'macos', 'arm64', false, true)
	assert macos_arm64 == ['no_backtrace']

	mut shared_defines := ['custom']
	add_v3_tcc_compat_defines(mut shared_defines, 'linux', 'amd64', true, true)
	assert shared_defines == ['custom', 'no_backtrace']

	mut supported := []string{}
	add_v3_tcc_compat_defines(mut supported, 'linux', 'arm64', false, true)
	assert supported.len == 0

	mut other_compiler := []string{}
	add_v3_tcc_compat_defines(mut other_compiler, 'macos', 'arm64', false, false)
	assert other_compiler.len == 0
}

fn test_v3_default_linker_flags() {
	assert v3_default_linker_flags('windows', false) == ['-lm']
	assert v3_default_linker_flags('linux', false) == ['-lm', '-lpthread']
	assert v3_default_linker_flags('freebsd', false) == ['-lm', '-lpthread', '-lexecinfo', '-lelf']
	assert v3_default_linker_flags('netbsd', false) == ['-lm', '-lpthread', '-lexecinfo', '-lelf']
	assert v3_default_linker_flags('linux', true) == []
}

fn test_v3_explicit_tcc_skips_only_windows_libm() {
	mut windows_tcc := []string{}
	add_v3_default_linker_flags(mut windows_tcc, 'windows', false, true)
	assert windows_tcc == []

	mut windows_native := []string{}
	add_v3_default_linker_flags(mut windows_native, 'windows', false, false)
	assert windows_native == ['-lm']

	mut linux_tcc := []string{}
	add_v3_default_linker_flags(mut linux_tcc, 'linux', false, true)
	assert linux_tcc == ['-lm', '-lpthread']

	mut windows_tcc_object := []string{}
	add_v3_default_linker_flags(mut windows_tcc_object, 'windows', true, true)
	assert windows_tcc_object == []
}

fn test_v3_cpp_linker_wraps_only_implicit_c_sources() {
	args := ['-std=gnu11', '-o', 'app', 'generated.c', 'support.o', '-x', 'c++', 'explicit.c',
		'-x', 'none', 'extra.c', '-xc++', 'compact.c', '-xnone', 'final.c', 'native.C',
		'-xobjective-c', 'darwin.c', '-lfixture']
	assert v3_cpp_linker_c_source_args(args) == [
		'-std=gnu11',
		'-o',
		'app',
		'-x',
		'c',
		'generated.c',
		'-x',
		'none',
		'support.o',
		'-x',
		'c++',
		'explicit.c',
		'-x',
		'none',
		'-x',
		'c',
		'extra.c',
		'-x',
		'none',
		'-xc++',
		'compact.c',
		'-xnone',
		'-x',
		'c',
		'final.c',
		'-x',
		'none',
		'native.C',
		'-xobjective-c',
		'darwin.c',
		'-lfixture',
	]
	assert v3_link_args_have_c_source(args)
	assert !v3_link_args_have_c_source(['-xc++', 'explicit.c', 'native.C', 'support.o'])
	assert v3_link_args_have_c_source(['-xobjective-c', 'darwin.c'])
}

fn test_v3_native_source_compile_flags_keep_only_the_selected_language_standard() {
	flags := ['-I', 'include dir', '-std=c++20', '-DVALUE=1', '-Wl,--as-needed', '-municode',
		'-lfixture', 'native.c', 'native.cpp']
	c_flags := v3_c_source_compile_flags(flags, '/source', 'c', '-std=gnu11')
	assert '-std=gnu11' in c_flags
	assert '-std=c++20' !in c_flags
	assert '-Wl,--as-needed' !in c_flags
	assert '-municode' in c_flags
	assert '-lfixture' !in c_flags
	assert !c_flags.any(it.ends_with('.c') || it.ends_with('.cpp'))
	cpp_flags := v3_cpp_source_compile_flags(flags, '/source')
	assert '-std=gnu11' !in cpp_flags
	assert '-std=c++20' in cpp_flags
	assert '-Wl,--as-needed' !in cpp_flags
	assert '-municode' in cpp_flags
	assert '-lfixture' !in cpp_flags
	assert !cpp_flags.any(it.ends_with('.c') || it.ends_with('.cpp'))
	c_args := v3_native_source_compile_args(['-std=c99', '-DBEFORE=1'], ['-DAFTER=1', '-std=c17'],
		'/source', 'c', '-std=gnu11', 'src.c', 'src.o')
	c99_index := c_args.index('-std=c99')
	gnu11_index := c_args.index('-std=gnu11')
	c_input_index := c_args.index('src.c')
	c_output_index := c_args.index('src.o')
	c17_index := c_args.index('-std=c17')
	assert c99_index >= 0 && c99_index < gnu11_index
	assert gnu11_index < c_input_index
	assert c_input_index < c_output_index
	assert c_output_index < c17_index
	assert c_args.filter(it.starts_with('-std=')).last() == '-std=c17'
	cpp_args := v3_native_source_compile_args(['-std=c99', '-std=c++17'],
		['-std=c17', '-std=c++23'], '/source', 'c++', '-std=gnu11', 'src.cpp', 'src.o')
	assert '-std=c99' !in cpp_args
	assert '-std=c17' !in cpp_args
	assert '-std=gnu11' !in cpp_args
	cpp17_index := cpp_args.index('-std=c++17')
	cpp_input_index := cpp_args.index('src.cpp')
	cpp_output_index := cpp_args.index('src.o')
	cpp23_index := cpp_args.index('-std=c++23')
	assert cpp17_index >= 0 && cpp17_index < cpp_input_index
	assert cpp_input_index < cpp_output_index
	assert cpp_output_index < cpp23_index
	assert cpp_args.filter(it.starts_with('-std=')).last() == '-std=c++23'
}

fn test_v3_cpp_linker_response_file_is_private_and_length_driven() {
	assert !v3_cpp_linker_response_file_required('c++', ['-o', 'app', 'main.c'])
	assert !v3_cpp_linker_response_file_required_for_limit('c++', ['1234', '5678'], 19)
	assert v3_cpp_linker_response_file_required_for_limit('c++', ['1234', '5678'], 18)
	args := ['marker.o', 'C:\\fixture path\\generated.c', 'café.o', '-lfixture']
	content := v3_cpp_linker_response_content(args)
	lines := content.split_into_lines()
	assert lines.len == args.len
	assert lines[0] == '"marker.o"'
	assert lines[1].contains('fixture path')
	assert lines[1].contains('generated.c')
	assert lines[2] == '"café.o"'
	assert lines[3] == '"-lfixture"'
}

fn test_v3_cpp_source_flags_keep_compile_inputs_and_drop_link_flags() {
	source_root := os.join_path(os.vtmp_dir(), 'v3_cpp_flags_fixture')
	include_path := os.abs_path(os.join_path(source_root, 'relative/include'))
	config_path := os.abs_path(os.join_path(source_root, 'relative/config.h'))
	macros_path := os.abs_path(os.join_path(source_root, 'relative/macros.h'))
	assert v3_cpp_source_compile_flags([
		'-O3',
		'-m64',
		'--target=x86_64-w64-mingw32',
		'-Irelative/include',
		'-include',
		'relative/config.h',
		'-imacrosrelative/macros.h',
		'-std=gnu11',
		'-std=c++17',
		'-flto=auto',
		'-Wextra',
		'-o',
		'app',
		'generated.cpp',
		'-Wl,--as-needed',
		'-lfixture',
	], source_root) == [
		'-O3',
		'-m64',
		'--target=x86_64-w64-mingw32',
		'-I${include_path}',
		'-include',
		config_path,
		'-imacros${macros_path}',
		'-std=c++17',
		'-flto=auto',
		'-Wextra',
	]
}

fn test_v3_cpp_linker_default_driver_follows_c_driver_family() {
	assert v3_default_cpp_compiler('cc') == 'c++'
	assert v3_default_cpp_compiler('gcc') == 'g++'
	assert v3_default_cpp_compiler('gcc-14') == 'g++-14'
	assert v3_default_cpp_compiler('x86_64-w64-mingw32-gcc.exe') == 'x86_64-w64-mingw32-g++.exe'
	assert os.norm_path(v3_default_cpp_compiler('C:/msys64/ucrt64/bin/clang.exe')) == os.norm_path('C:/msys64/ucrt64/bin/clang++.exe')
	assert os.norm_path(v3_default_cpp_compiler('/opt/llvm/bin/clang-22')) == os.norm_path('/opt/llvm/bin/clang++-22')
	assert v3_default_cpp_compiler('clang-cl.exe') == ''
	assert v3_default_cpp_compiler('clang-wrapper') == ''
	assert v3_driver_name_pattern_family('x86_64-w64-mingw32-gcc.exe') == 'gcc'
	assert v3_driver_name_pattern_family('clang++-22') == 'clang'
	assert v3_driver_name_pattern_family('gcc-wrapper') == ''
}

fn test_v3_cgen_metadata_roundtrips_native_link_requirements() {
	for requires_cpp in [false, true] {
		for emits_main in [false, true] {
			requirements := types.NativeLinkRequirements{
				requires_cpp: requires_cpp
			}
			encoded := encode_v3_cgen_metadata(['-DFIXTURE'], 'iface', 'prefix', requirements,
				emits_main, []V3CachedTypeDiagnostic{})
			decoded := decode_v3_cgen_metadata(encoded) or { panic('metadata did not decode') }
			assert decoded.native_link_requirements.requires_cpp == requires_cpp
			assert decoded.emits_main == emits_main
			assert decoded.flags == ['-DFIXTURE']
			assert encoded.starts_with('v3-cgen-metadata-v6\x00')
		}
	}
	dynamic_requirements := types.NativeLinkRequirements{}
	dynamic_metadata := encode_v3_cgen_metadata(['-DFIXTURE'], 'iface', 'prefix',
		dynamic_requirements, true, []V3CachedTypeDiagnostic{})
	assert dynamic_metadata == ['v3-cgen-metadata-v6', 'iface', 'prefix', 'false', 'true',
		'1', '-DFIXTURE', '0'].join('\x00')
	assert v3_cgen_generation_signature(['-DFIXTURE'], dynamic_requirements) == '-DFIXTURE'
	assert v3_cgen_generation_signature(['-DFIXTURE'], types.NativeLinkRequirements{
		requires_cpp: true
	}) == '-DFIXTURE\x00native_link=c++'
}

fn test_v3_default_linker_flags_do_not_duplicate_existing_flags() {
	mut flags := ['-lpthread', '-lm']
	add_v3_default_linker_flags(mut flags, 'linux', false, false)
	assert flags == ['-lpthread', '-lm']
}

fn test_v3_user_ldflags_are_final_and_do_not_change_dynamic_plan_when_absent() {
	dynamic := v3_c_compiler_flag_plan(V3CCompilerFlagOptions{
		dependencies:         ['-lpublic']
		environment_ld_flags: ['-lenvironment']
		target_os:            'windows'
	})
	assert dynamic.after_inputs == ['-lpublic', '-lm', '-lenvironment']

	static_plan := v3_c_compiler_flag_plan(V3CCompilerFlagOptions{
		dependencies:         ['-lpublic', '-lprivate']
		environment_ld_flags: ['-lenvironment']
		user_ld_flags:        ['-lfixture_first', '-lfixture_final']
		target_os:            'windows'
	})
	assert static_plan.after_inputs == [
		'-lpublic',
		'-lprivate',
		'-lm',
		'-lenvironment',
		'-lfixture_first',
		'-lfixture_final',
	]
	assert static_plan.after_inputs.last() == '-lfixture_final'

	explicit_tcc := v3_c_compiler_flag_plan(V3CCompilerFlagOptions{
		dependencies:         ['-lpublic', '-lprivate']
		environment_ld_flags: ['-lenvironment']
		user_ld_flags:        ['-lfixture_first', '-lfixture_final']
		target_os:            'windows'
		explicit_tcc:         true
	})
	assert explicit_tcc.after_inputs == [
		'-lpublic',
		'-lprivate',
		'-lenvironment',
		'-lfixture_first',
		'-lfixture_final',
	]
	assert explicit_tcc.after_inputs.last() == '-lfixture_final'

	windows_unicode := v3_c_compiler_flag_plan(V3CCompilerFlagOptions{
		dependencies:         ['-lpublic']
		environment_ld_flags: ['-lenvironment']
		user_ld_flags:        ['-lfixture_final']
		target_os:            'windows'
		linker_family:        'clang'
		emits_v3_main:        true
	})
	assert windows_unicode.after_inputs == [
		'-lpublic',
		'-lm',
		'-municode',
		'-lenvironment',
		'-lfixture_final',
	]
	assert windows_unicode.after_inputs.count(it == '-municode') == 1
	assert windows_unicode.after_inputs.last() == '-lfixture_final'
	assert '-mwindows' !in windows_unicode.before_inputs
	assert '-mwindows' !in windows_unicode.after_inputs

	windows_tcc_unicode := v3_c_compiler_flag_plan(V3CCompilerFlagOptions{
		dependencies:  ['-lpublic']
		target_os:     'windows'
		linker_family: 'tinyc'
		explicit_tcc:  true
		emits_v3_main: true
	})
	assert windows_tcc_unicode.after_inputs == ['-lpublic', '-municode']
	assert v3_active_linker_family('c-driver-family', 'cpp-driver-family', true) == 'cpp-driver-family'
	assert v3_active_linker_family('c-driver-family', 'cpp-driver-family', false) == 'c-driver-family'
	last_target, last_target_valid := v3_last_explicit_compiler_target([
		'--target=x86_64-pc-windows-msvc',
		'-target',
		'x86_64-w64-windows-gnu',
	])
	assert last_target == 'x86_64-w64-windows-gnu'
	assert last_target_valid
	missing_target, missing_target_valid := v3_last_explicit_compiler_target(['--target'])
	assert missing_target == ''
	assert !missing_target_valid
	assert v3_windows_gnu_linker_target('x86_64-w64-mingw32')
	assert v3_windows_gnu_linker_target('x86_64-pc-windows-gnu')
	assert !v3_windows_gnu_linker_target('x86_64-pc-windows-msvc')
	assert !v3_windows_gnu_linker_target('x86_64-unknown-linux-gnu')
	assert v3_windows_unicode_linker_family('windows', 'clang.exe', 'clang', [
		'--target=x86_64-w64-windows-gnu',
	]) == 'clang'
	assert v3_windows_unicode_linker_family('windows', 'clang++.exe', 'clang', [
		'-target',
		'x86_64-pc-windows-msvc',
	]) == ''
	assert v3_windows_unicode_linker_family('windows', 'c++.exe', 'cplusplus', [
		'--target=x86_64-w64-mingw32',
	]) == 'cplusplus'
	assert v3_windows_unicode_linker_family('windows', 'clang-cl.exe', 'clang', [
		'--target=x86_64-w64-windows-gnu',
	]) == ''
	assert v3_windows_unicode_linker_family('windows', 'clang-cl.exe', 'clang', [
		'--driver-mode=gcc',
		'--target=x86_64-w64-windows-gnu',
	]) == 'clang'
	assert v3_windows_unicode_linker_family('windows', 'clang.exe', 'clang', [
		'--driver-mode=gcc',
		'--driver-mode=cl',
		'--target=x86_64-w64-windows-gnu',
	]) == ''
	assert v3_windows_unicode_linker_family('linux', 'clang', 'clang', [
		'--target=x86_64-w64-windows-gnu',
	]) == ''

	for family in ['gcc', 'mingw', 'clang', 'cplusplus', 'tinyc'] {
		mut flags := []string{}
		add_v3_windows_unicode_entrypoint_flag(mut flags, []string{}, 'windows', family,
			true, false, false)
		assert flags == ['-municode'], family
	}
	mut msvc := []string{}
	add_v3_windows_unicode_entrypoint_flag(mut msvc, []string{}, 'windows', 'msvc', true,
		false, false)
	assert msvc == []
	assert v3_compiler_uses_msvc_driver_mode('clang-cl.exe', []string{}, []string{})
	mut clang_cl := []string{}
	add_v3_windows_unicode_entrypoint_flag(mut clang_cl, []string{}, 'windows', 'msvc',
		true, false, false)
	assert clang_cl == []
	mut non_windows := []string{}
	add_v3_windows_unicode_entrypoint_flag(mut non_windows, []string{}, 'linux', 'gcc', true,
		false, false)
	assert non_windows == []
	mut shared_flags := []string{}
	add_v3_windows_unicode_entrypoint_flag(mut shared_flags, []string{}, 'windows', 'gcc', true,
		true, false)
	assert shared_flags == []
	mut object := []string{}
	add_v3_windows_unicode_entrypoint_flag(mut object, []string{}, 'windows', 'gcc', true,
		false, true)
	assert object == []
	assert v3_link_plan_emits_main(true, false, false, false, false, false, false)
	assert v3_link_plan_emits_main(true, true, true, false, false, false, false)
	assert !v3_link_plan_emits_main(false, false, false, false, false, false, false)
	assert !v3_link_plan_emits_main(true, true, false, false, false, false, false)
	assert !v3_link_plan_emits_main(true, false, false, true, false, false, false)
	assert !v3_link_plan_emits_main(true, false, false, false, true, false, false)
	assert !v3_link_plan_emits_main(true, false, false, false, false, true, false)
	assert !v3_link_plan_emits_main(true, false, false, false, false, false, true)
	mut without_generated_main := []string{}
	add_v3_windows_unicode_entrypoint_flag(mut without_generated_main, []string{}, 'windows',
		'gcc', false, false, false)
	assert without_generated_main == []
	mut already_present := ['-lpublic']
	add_v3_windows_unicode_entrypoint_flag(mut already_present, ['-municode'], 'windows',
		'gcc', true, false, false)
	assert already_present == ['-lpublic']

	driver_source := os.read_file(os.join_path(os.dir(@FILE), 'driver.v')) or { panic(err) }
	// One definition plus the normal, cached-dev and full-TCC link routes.
	assert driver_source.count('add_v3_windows_unicode_entrypoint_flag(') == 4
}

fn test_v3_object_mode_ignores_link_only_user_flags() {
	plan := v3_c_compiler_flag_plan(V3CCompilerFlagOptions{
		user_ld_flags: ['-lfixture_final']
		target_os:     'windows'
		linker_family: 'gcc'
		is_o:          true
		emits_v3_main: true
	})
	assert plan.after_inputs == []
}

fn test_v3_pkgconfig_mode_has_a_distinct_cache_salt() {
	assert v3_pkgconfig_cache_salt(pref.PkgConfigMode.dynamic) == 'pkgconfig_mode=dynamic'
	assert v3_pkgconfig_cache_salt(pref.PkgConfigMode.static_) == 'pkgconfig_mode=static_'
	assert v3_pkgconfig_cache_salt(.dynamic) != v3_pkgconfig_cache_salt(.static_)
}

fn test_v3_tcc_fast_link_never_bypasses_static_mode_or_user_ldflags() {
	assert v3_tcc_fast_link_allowed(.dynamic, [])
	assert !v3_tcc_fast_link_allowed(.static_, [])
	assert !v3_tcc_fast_link_allowed(.dynamic, ['-lfixture_final'])
}
