module driver

import os
import v3.pref
import v3.types

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

fn test_v3_cpp_linker_marker_keeps_abi_flags_and_drops_link_or_c_only_flags() {
	source_root := os.join_path(os.vtmp_dir(), 'v3_cpp_flags_fixture')
	include_path := os.abs_path(os.join_path(source_root, 'relative/include'))
	config_path := os.abs_path(os.join_path(source_root, 'relative/config.h'))
	macros_path := os.abs_path(os.join_path(source_root, 'relative/macros.h'))
	assert v3_cpp_marker_compile_flags([
		'-m32',
		'--target=x86_64-w64-mingw32',
		'-target',
		'x86_64-pc-windows-gnu',
		'--sysroot=/sdk',
		'-isysroot',
		'/Apple SDK',
		'-stdlib=libc++',
		'-fPIC',
		'-I',
		'/fixture/include',
		'-std=gnu11',
		'-std=c++17',
		'-flto=auto',
		'-Wl,--as-needed',
		'-L/fixture/lib',
		'-lfixture',
		'-o',
		'app',
		'-xobjective-c',
		'generated.c',
	], source_root) == [
		'-m32',
		'--target=x86_64-w64-mingw32',
		'-target',
		'x86_64-pc-windows-gnu',
		'--sysroot=/sdk',
		'-isysroot',
		'/Apple SDK',
		'-stdlib=libc++',
		'-fPIC',
		'-I',
		'/fixture/include',
	]
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
		requirements := types.NativeLinkRequirements{
			requires_cpp: requires_cpp
		}
		encoded := encode_v3_cgen_metadata(['-DFIXTURE'], 'iface', 'prefix', requirements,
			[]V3CachedTypeDiagnostic{})
		decoded := decode_v3_cgen_metadata(encoded) or { panic('metadata did not decode') }
		assert decoded.native_link_requirements.requires_cpp == requires_cpp
		assert decoded.flags == ['-DFIXTURE']
		assert encoded.starts_with(if requires_cpp {
			'v3-cgen-metadata-v5\x00'
		} else {
			'v3-cgen-metadata-v4\x00'
		})
	}
	dynamic_requirements := types.NativeLinkRequirements{}
	dynamic_metadata := encode_v3_cgen_metadata(['-DFIXTURE'], 'iface', 'prefix',
		dynamic_requirements, []V3CachedTypeDiagnostic{})
	assert dynamic_metadata == ['v3-cgen-metadata-v4', 'iface', 'prefix', '1', '-DFIXTURE', '0'].join('\x00')
	assert v3_cgen_generation_signature(['-DFIXTURE'], dynamic_requirements) == '-DFIXTURE'
	assert v3_cgen_generation_signature(['-DFIXTURE'], types.NativeLinkRequirements{
		requires_cpp: true
	}) == '-DFIXTURE\x00native_link=c++'
}

fn test_v3_default_linker_flags_do_not_duplicate_existing_flags() {
	mut flags := ['-lpthread', '-lm']
	add_v3_default_linker_flags(mut flags, 'linux', false)
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
}

fn test_v3_object_mode_ignores_link_only_user_flags() {
	plan := v3_c_compiler_flag_plan(V3CCompilerFlagOptions{
		user_ld_flags: ['-lfixture_final']
		target_os:     'windows'
		is_o:          true
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
