module cleanc

import os
import v2.ast
import v2.markused
import v2.parser
import v2.pref as vpref
import v2.token
import v2.transformer
import v2.types

fn module_init_c_for_test(name string, source string) string {
	tmp_file := os.join_path(os.temp_dir(), 'v2_module_init_codegen_${name}_${os.getpid()}.v')
	os.write_file(tmp_file, source) or { panic(err) }
	defer {
		os.rm(tmp_file) or {}
	}
	prefs := &vpref.Preferences{
		backend:               .cleanc
		target_os:             'linux'
		no_parallel:           true
		no_parallel_transform: true
	}
	mut file_set := token.FileSet.new()
	mut par := parser.Parser.new(prefs)
	files := par.parse_files([tmp_file], mut file_set)
	env := types.Environment.new()
	mut checker := types.Checker.new(prefs, file_set, env)
	checker.check_files(files)
	flat := ast.flatten_files(files)
	mut trans := transformer.Transformer.new_with_pref(env, prefs)
	trans.set_file_set(file_set)
	transformed_flat := trans.transform_flat_to_flat_direct(&flat, []ast.File{})
	mut gen := Gen.new_with_env_pref_and_flat(&transformed_flat, env, prefs)
	gen.set_used_fn_keys(markused.mark_used_flat(&transformed_flat, env))
	return gen.gen()
}

fn test_parameterized_init_callback_is_not_emitted_as_startup_call() {
	csrc := module_init_c_for_test('parameterized_init_callback', '
struct App {
mut:
	value int
}

fn run(mut app App, cb fn (mut App)) {
	cb(mut app)
}

fn init(mut app App) {
	app.value = 1
}

fn main() {
	mut app := App{}
	run(mut app, init)
}
')
	assert csrc.contains('void init(App* app)'), csrc
	assert csrc.contains('void run(App* app, void (*cb)(App*))'), csrc
	assert csrc.contains('run(&app, ((void (*)(App*))init));'), csrc
	assert !csrc.contains('\tinit(0);'), csrc
	assert !csrc.contains('\tinit();'), csrc
}

fn test_unused_parameterized_init_is_not_kept_by_lifecycle_fallback() {
	csrc := module_init_c_for_test('unused_parameterized_init', '
struct App {
mut:
	value int
}

fn init(mut app App) {
	app.value = helper()
}

fn helper() int {
	return 1
}

fn main() {
	mut app := App{}
	_ := app.value
}
')
	assert !csrc.contains('void init(App* app)'), csrc
	assert !csrc.contains('int helper()'), csrc
	assert !csrc.contains('\tinit();'), csrc
}
