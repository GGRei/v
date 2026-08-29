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
