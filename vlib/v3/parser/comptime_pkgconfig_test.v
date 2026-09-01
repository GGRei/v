module parser

import os
import v3.pref

fn test_comptime_pkgconfig_function_keeps_dollar_prefix() {
	root := os.join_path(os.temp_dir(), 'v3_comptime_pkgconfig_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root)!
	old_path := os.getenv('PATH')
	old_pkgconfig_path := os.getenv_opt('PKG_CONFIG_PATH')
	defer {
		os.setenv('PATH', old_path, true)
		if value := old_pkgconfig_path {
			os.setenv('PKG_CONFIG_PATH', value, true)
		} else {
			os.unsetenv('PKG_CONFIG_PATH')
		}
		os.rmdir_all(root) or {}
	}
	$if windows {
		fixture_dir := os.join_path(@VEXEROOT, 'vlib', 'v', 'pkgconfig', 'testdata',
			'static_pkgconfig')
		os.setenv('PKG_CONFIG_PATH', fixture_dir, true)
	} $else {
		pkgconfig := os.join_path(root, 'pkg-config')
		os.write_file(pkgconfig,
			'#!/bin/sh\nif [ "$1" = "--exists" ] && [ "$2" = "mixed-case-dynamic-sentinel-74" ]; then\n\texit 0\nfi\nexit 1\n')!
		os.chmod(pkgconfig, 0o700)!
		os.setenv('PATH', root, true)
	}

	prefs := pref.new_preferences()
	p := Parser.new(prefs)
	assert p.eval_comptime_cond("\$pkgconfig('mixed-case-dynamic-sentinel-74')")
	assert !p.eval_comptime_cond("\$pkgconfig('issue74-v37-missing')")
}
