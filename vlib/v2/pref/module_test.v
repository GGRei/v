module pref

import os

fn test_get_module_path_finds_sibling_module_from_importing_file_ancestor() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_pref_sibling_module_${os.getpid()}')
	project_dir := os.join_path(tmp_dir, 'app')
	project_subdir := os.join_path(project_dir, 'ui')
	sibling_module_dir := os.join_path(tmp_dir, 'viper')
	os.mkdir_all(project_subdir) or { panic(err) }
	os.mkdir_all(sibling_module_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	os.write_file(os.join_path(project_dir, 'v.mod'), "Module { name: 'app' }") or { panic(err) }
	os.write_file(os.join_path(sibling_module_dir, 'v.mod'), "Module { name: 'viper' }") or {
		panic(err)
	}

	prefs := Preferences{
		vroot:         tmp_dir
		vmodules_path: os.join_path(tmp_dir, '.vmodules')
	}
	importing_file := os.join_path(project_subdir, 'text.v')
	assert prefs.get_module_path('viper', importing_file) == sibling_module_dir
}

fn test_get_module_path_skips_sibling_directory_without_matching_module() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_pref_sibling_non_module_${os.getpid()}')
	app_dir := os.join_path(tmp_dir, 'examples', 'game')
	example_dir := os.join_path(tmp_dir, 'examples', 'draw')
	vlib_dir := os.join_path(tmp_dir, 'vlib', 'draw')
	os.mkdir_all(app_dir) or { panic(err) }
	os.mkdir_all(example_dir) or { panic(err) }
	os.mkdir_all(vlib_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	os.write_file(os.join_path(app_dir, 'main.v'), 'module main\nimport draw\n') or { panic(err) }
	os.write_file(os.join_path(example_dir, 'sample.v'), 'module main\nfn main() {}\n') or {
		panic(err)
	}
	os.write_file(os.join_path(vlib_dir, 'draw.v'), 'module draw\npub struct Context {}\n') or {
		panic(err)
	}

	prefs := Preferences{
		vroot:         tmp_dir
		vmodules_path: os.join_path(tmp_dir, '.vmodules')
	}
	importing_file := os.join_path(app_dir, 'main.v')
	assert prefs.get_module_path('draw', importing_file) == vlib_dir
}

fn test_get_module_path_keeps_valid_local_module_before_vlib() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_pref_valid_local_module_${os.getpid()}')
	app_dir := os.join_path(tmp_dir, 'app')
	local_dir := os.join_path(tmp_dir, 'widgets')
	vlib_dir := os.join_path(tmp_dir, 'vlib', 'widgets')
	os.mkdir_all(app_dir) or { panic(err) }
	os.mkdir_all(local_dir) or { panic(err) }
	os.mkdir_all(vlib_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	os.write_file(os.join_path(tmp_dir, 'v.mod'), "Module { name: 'app' }\n") or { panic(err) }
	os.write_file(os.join_path(app_dir, 'main.v'), 'module main\nimport widgets\n') or {
		panic(err)
	}
	os.write_file(os.join_path(local_dir, 'widgets.v'), 'module widgets\npub struct Local {}\n') or {
		panic(err)
	}
	os.write_file(os.join_path(vlib_dir, 'widgets.v'), 'module widgets\npub struct Std {}\n') or {
		panic(err)
	}

	prefs := Preferences{
		vroot:         tmp_dir
		vmodules_path: os.join_path(tmp_dir, '.vmodules')
	}
	importing_file := os.join_path(app_dir, 'main.v')
	assert prefs.get_module_path('widgets', importing_file) == local_dir
}

fn test_get_module_path_ignores_non_module_manifest_name_mentions() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_pref_manifest_non_name_mentions_${os.getpid()}')
	app_dir := os.join_path(tmp_dir, 'app')
	local_dir := os.join_path(tmp_dir, 'graphics')
	vlib_dir := os.join_path(tmp_dir, 'vlib', 'graphics')
	os.mkdir_all(app_dir) or { panic(err) }
	os.mkdir_all(local_dir) or { panic(err) }
	os.mkdir_all(vlib_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	os.write_file(os.join_path(app_dir, 'main.v'), 'module main\nimport graphics\n') or {
		panic(err)
	}
	os.write_file(os.join_path(local_dir, 'v.mod'), 'Module {
	display_name: "graphics"
	description: "name: \'graphics\'"
	// name: "graphics"
	/* name: "graphics" */
	/*
	name: "graphics"
	*/
}
') or {
		panic(err)
	}
	os.write_file(os.join_path(local_dir, 'main.v'), 'module main\n') or { panic(err) }
	os.write_file(os.join_path(vlib_dir, 'graphics.v'), 'module graphics\npub struct Context {}\n') or {
		panic(err)
	}

	prefs := Preferences{
		vroot:         tmp_dir
		vmodules_path: os.join_path(tmp_dir, '.vmodules')
	}
	importing_file := os.join_path(app_dir, 'main.v')
	assert prefs.get_module_path('graphics', importing_file) == vlib_dir
}
