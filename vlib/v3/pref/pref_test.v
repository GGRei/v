module pref

import os

// test_detect_vroot_from_subdir validates detect vroot from subdir behavior in v3 tests.
fn test_detect_vroot_from_subdir() {
	vroot := @VMODROOT
	v3_dir := os.join_path(vroot, 'vlib', 'v3')
	assert detect_vroot_from(v3_dir) == vroot
}

// test_detect_vroot_from_binary_path validates this v3 regression case.
fn test_detect_vroot_from_binary_path() {
	vroot := @VMODROOT
	v3_bin := os.join_path(vroot, 'vlib', 'v3', 'v3')
	assert detect_vroot_from(v3_bin) == vroot
}

fn test_pkgconfig_executable_candidate_requires_absolute_regular_executable_exe() {
	abs_exe := os.join_path(os.vtmp_dir(), 'pkg config', 'pkg-config.EXE')
	assert pkgconfig_executable_from_candidate(abs_exe, true, true, true) == abs_exe
	for candidate in [
		['pkg-config.exe', 'false', 'true', 'true'],
		[os.join_path(os.vtmp_dir(), 'pkg-config.bat'), 'true', 'true', 'true'],
		[os.join_path(os.vtmp_dir(), 'pkg-config.cmd'), 'true', 'true', 'true'],
		[os.join_path(os.vtmp_dir(), 'pkg-config'), 'true', 'true', 'true'],
		[os.join_path(os.vtmp_dir(), 'pkg-config.exe'), 'true', 'false', 'true'],
		[os.join_path(os.vtmp_dir(), 'pkg-config.exe'), 'true', 'true', 'false'],
	] {
		assert pkgconfig_executable_from_candidate(candidate[0], candidate[1] == 'true',
			candidate[2] == 'true', candidate[3] == 'true') == pkgconfig_executable_name
	}
}

fn test_pkgconfig_executable_resolves_only_windows_exe() {
	$if windows {
		root := os.join_path(os.vtmp_dir(), 'v3 pkgconfig executable ${os.getpid()}')
		os.rmdir_all(root) or {}
		os.mkdir_all(root) or { panic(err) }
		defer {
			os.rmdir_all(root) or {}
		}
		old_path := os.getenv('PATH')
		defer {
			os.setenv('PATH', old_path, true)
		}
		batch_dir := os.join_path(root, 'first batch script')
		cmd_dir := os.join_path(root, 'command script')
		extensionless_dir := os.join_path(root, 'extensionless tool')
		empty_dir := os.join_path(root, 'empty path')
		second := os.join_path(root, 'second executable')
		third := os.join_path(root, 'third executable')
		for dir in [batch_dir, cmd_dir, extensionless_dir, empty_dir, second, third] {
			os.mkdir_all(dir) or { panic(err) }
		}
		os.write_file(os.join_path(batch_dir, 'pkg-config.bat'), '@exit /b 0\n') or { panic(err) }
		os.write_file(os.join_path(cmd_dir, 'pkg-config.cmd'), '@exit /b 0\n') or { panic(err) }
		os.write_file(os.join_path(extensionless_dir, 'pkg-config'), '') or { panic(err) }
		second_exe := os.join_path(second, 'pkg-config.exe')
		third_exe := os.join_path(third, 'pkg-config.exe')
		os.write_file(second_exe, '') or { panic(err) }
		os.write_file(third_exe, '') or { panic(err) }

		os.setenv('PATH', '${batch_dir}${os.path_delimiter}${second}${os.path_delimiter}${third}',
			true)
		assert pkgconfig_executable() == os.real_path(second_exe)
		os.setenv('PATH', '${third}${os.path_delimiter}${second}', true)
		assert pkgconfig_executable() == os.real_path(third_exe)
		for dir in [batch_dir, cmd_dir, extensionless_dir, empty_dir] {
			os.setenv('PATH', dir, true)
			assert pkgconfig_executable() == pkgconfig_executable_name
		}
	} $else {
		assert pkgconfig_executable() == pkgconfig_executable_name
	}
}

fn test_comptime_pkgconfig_value_uses_pkgconfig_runner() {
	fixture_dir := os.join_path(@VEXEROOT, 'vlib', 'v', 'pkgconfig', 'testdata',
		'static_pkgconfig')
	old_pkgconfig_path := os.getenv_opt('PKG_CONFIG_PATH')
	old_pkgconfig_defaults := os.getenv_opt('PKG_CONFIG_PATH_DEFAULTS')
	old_path := os.getenv('PATH')
	defer {
		if value := old_pkgconfig_path {
			os.setenv('PKG_CONFIG_PATH', value, true)
		} else {
			os.unsetenv('PKG_CONFIG_PATH')
		}
		if value := old_pkgconfig_defaults {
			os.setenv('PKG_CONFIG_PATH_DEFAULTS', value, true)
		} else {
			os.unsetenv('PKG_CONFIG_PATH_DEFAULTS')
		}
		os.setenv('PATH', old_path, true)
	}
	os.setenv('PKG_CONFIG_PATH', fixture_dir, true)
	os.unsetenv('PKG_CONFIG_PATH_DEFAULTS')
	$if !windows {
		root := os.join_path(os.vtmp_dir(), 'v3_pref_pkgconfig_runner_${os.getpid()}')
		os.rmdir_all(root) or {}
		os.mkdir_all(root) or { panic(err) }
		defer {
			os.rmdir_all(root) or {}
		}
		tool := os.join_path(root, 'pkg-config')
		os.write_file(tool,
			'#!/bin/sh\n[ "$1" = "--exists" ] && [ "$2" = "mixed-case-dynamic-sentinel-74" ]\n') or {
			panic(err)
		}
		os.chmod(tool, 0o700) or { panic(err) }
		os.setenv('PATH', root, true)
	}
	assert comptime_pkgconfig_value('mixed-case-dynamic-sentinel-74')
	assert !comptime_pkgconfig_value('issue74-v37-missing')
}

fn test_get_module_path_resolves_alias_and_submodule() {
	root := os.join_path(os.temp_dir(), 'v3_pref_module_alias_${os.getpid()}')
	os.rmdir_all(root) or {}
	defer {
		os.rmdir_all(root) or {}
	}
	modules_dir := os.join_path_single(root, 'modules')
	canonical_dir := os.join_path_single(modules_dir, 'canonical')
	os.mkdir_all(os.join_path_single(canonical_dir, 'sub')) or { panic(err) }
	os.mkdir_all(os.join_path_single(modules_dir, 'legacy')) or { panic(err) }
	os.write_file(os.join_path_single(root, 'v.mod'), "Module { name: 'alias_test' }\n") or {
		panic(err)
	}
	os.write_file(os.join_path_single(canonical_dir, 'canonical.v'), 'module canonical\n') or {
		panic(err)
	}
	os.write_file(os.join_path(canonical_dir, 'sub', 'sub.v'), 'module sub\n') or { panic(err) }
	os.write_file(os.join_path(modules_dir, 'legacy', 'alias.v'),
		"@[alias: '@VMODROOT/modules/canonical'] module legacy\n") or { panic(err) }
	main_file := os.join_path_single(root, 'main.v')
	os.write_file(main_file, 'module main\n') or { panic(err) }
	prefs := new_preferences()
	assert prefs.get_module_path('modules.legacy', main_file) == os.real_path(canonical_dir)
	assert prefs.get_module_path('modules.legacy.sub', main_file) == os.real_path(os.join_path_single(canonical_dir,
		'sub'))
}

struct StaticPkgConfigPrefCase {
	raw_ccompiler string
	ccompiler     string
	cflags        []string
	ldflags       []string
	env_cflags    []string
	env_ldflags   []string
}

fn static_pkgconfig_preferences(tc StaticPkgConfigPrefCase) &Preferences {
	mut prefs := new_preferences()
	prefs.ccompiler = tc.ccompiler
	prefs.resolve_pkgconfig_mode(tc.raw_ccompiler, tc.cflags, tc.ldflags, tc.env_cflags,
		tc.env_ldflags)
	return prefs
}

fn test_static_pkgconfig_compiler_owned_names_are_exactly_reserved() {
	assert is_compiler_owned_define('v:static_pkgconfig')
	assert is_compiler_owned_define('v_static_pkgconfig')
	assert !is_compiler_owned_define('static_pkgconfig')
	assert !is_compiler_owned_define('v:user_value')
	assert !is_compiler_owned_define('v:flag:doc_attr')
}

fn test_static_pkgconfig_mode_and_canonical_value_matrix() {
	for tc in [
		StaticPkgConfigPrefCase{
			raw_ccompiler: 'gcc'
			ccompiler:     'gcc'
			cflags:        ['-static']
		},
		StaticPkgConfigPrefCase{
			raw_ccompiler: 'clang.exe'
			ccompiler:     'clang'
			ldflags:       ['-static']
		},
		StaticPkgConfigPrefCase{
			raw_ccompiler: 'x86_64-w64-mingw32-gcc'
			ccompiler:     'mingw'
			cflags:        ['-Wno-error', '-static']
		},
		StaticPkgConfigPrefCase{
			raw_ccompiler: 'c++'
			ccompiler:     'cplusplus'
			ldflags:       ['-static']
		},
	] {
		prefs := static_pkgconfig_preferences(tc)
		assert prefs.pkgconfig_mode == .static_, tc.raw_ccompiler
		assert prefs.compile_values['v:static_pkgconfig'] == 'true', tc.raw_ccompiler
		assert prefs.file_defines == ['v_static_pkgconfig'], tc.raw_ccompiler
		assert 'v_static_pkgconfig' in prefs.source_file_defines(), tc.raw_ccompiler
		assert 'v_static_pkgconfig' !in prefs.user_defines, tc.raw_ccompiler
	}
}

fn test_static_pkgconfig_mode_rejects_unsupported_drivers_and_lookalikes() {
	for tc in [
		StaticPkgConfigPrefCase{
			raw_ccompiler: 'tcc'
			ccompiler:     'tinyc'
			cflags:        ['-static']
		},
		StaticPkgConfigPrefCase{
			raw_ccompiler: 'cl.exe'
			ccompiler:     'msvc'
			ldflags:       ['-static']
		},
		StaticPkgConfigPrefCase{
			raw_ccompiler: 'gcc'
			ccompiler:     'gcc'
			cflags:        ['-static-libgcc']
		},
		StaticPkgConfigPrefCase{
			raw_ccompiler: 'gcc'
			ccompiler:     'gcc'
			ldflags:       ['-Wl,-Bstatic']
		},
		StaticPkgConfigPrefCase{
			raw_ccompiler: 'gcc'
			ccompiler:     'gcc'
			env_cflags:    ['-static']
		},
	] {
		prefs := static_pkgconfig_preferences(tc)
		assert prefs.pkgconfig_mode == .dynamic, tc.raw_ccompiler
		assert prefs.compile_values['v:static_pkgconfig'] == 'false', tc.raw_ccompiler
		assert prefs.file_defines == [], tc.raw_ccompiler
		assert 'v_static_pkgconfig' !in prefs.source_file_defines(), tc.raw_ccompiler
	}
}

fn test_static_pkgconfig_mode_excludes_clang_msvc_driver_dialect() {
	for tc in [
		StaticPkgConfigPrefCase{
			raw_ccompiler: 'clang-cl.exe'
			ccompiler:     'clang'
			cflags:        ['-static']
		},
		StaticPkgConfigPrefCase{
			raw_ccompiler: 'C:/msys64/ucrt64/bin/x86_64-w64-mingw32-clang-cl.exe'
			ccompiler:     'clang'
			cflags:        ['-static']
		},
		StaticPkgConfigPrefCase{
			raw_ccompiler: 'clang.exe'
			ccompiler:     'clang'
			cflags:        ['--driver-mode=cl', '-static']
		},
		StaticPkgConfigPrefCase{
			raw_ccompiler: 'clang.exe'
			ccompiler:     'clang'
			cflags:        ['-static']
			env_ldflags:   ['--driver-mode=cl']
		},
	] {
		prefs := static_pkgconfig_preferences(tc)
		assert prefs.pkgconfig_mode == .dynamic, tc.raw_ccompiler
		assert prefs.compile_values['v:static_pkgconfig'] == 'false', tc.raw_ccompiler
	}
	gnu_clang := static_pkgconfig_preferences(StaticPkgConfigPrefCase{
		raw_ccompiler: 'clang.exe'
		ccompiler:     'clang'
		cflags:        ['--driver-mode=cl-like', '-static']
	})
	assert gnu_clang.pkgconfig_mode == .static_
}

fn test_static_pkgconfig_reresolution_replaces_compiler_owned_state() {
	mut prefs := new_preferences()
	prefs.ccompiler = 'gcc'
	prefs.resolve_pkgconfig_mode('gcc', ['-static'], [], [], [])
	assert prefs.pkgconfig_mode == .static_
	assert prefs.compile_values['v:static_pkgconfig'] == 'true'
	assert prefs.file_defines == ['v_static_pkgconfig']
	prefs.ccompiler = 'tinyc'
	prefs.resolve_pkgconfig_mode('tcc', ['-static'], [], [], [])
	assert prefs.pkgconfig_mode == .dynamic
	assert prefs.compile_values['v:static_pkgconfig'] == 'false'
	assert prefs.file_defines == []
}

fn test_static_pkgconfig_file_define_selects_only_the_internal_variant() {
	root := os.join_path(os.vtmp_dir(), 'v3_static_pkgconfig_files_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	for file in ['bindings.v', 'bindings_d_v_static_pkgconfig.v',
		'bindings_notd_v_static_pkgconfig.v'] {
		os.write_file(os.join_path_single(root, file), 'module bindings\n') or { panic(err) }
	}
	dynamic := static_pkgconfig_preferences(StaticPkgConfigPrefCase{
		raw_ccompiler: 'gcc'
		ccompiler:     'gcc'
	})
	static_prefs := static_pkgconfig_preferences(StaticPkgConfigPrefCase{
		raw_ccompiler: 'gcc'
		ccompiler:     'gcc'
		cflags:        ['-static']
	})
	assert get_v_files_from_dir_for_target(root, dynamic.source_file_defines(), host_target()).map(os.base(it)) == [
		'bindings.v',
		'bindings_notd_v_static_pkgconfig.v',
	]
	assert get_v_files_from_dir_for_target(root, static_prefs.source_file_defines(), host_target()).map(os.base(it)) == [
		'bindings.v',
		'bindings_d_v_static_pkgconfig.v',
	]
}
