module cleanc

import os
import v2.ast
import v2.parser
import v2.pref as vpref
import v2.token
import v2.transformer
import v2.types

fn struct_default_c_for_test(name string, source string) string {
	tmp_file := os.join_path(os.temp_dir(), 'v2_struct_default_codegen_${name}_${os.getpid()}.v')
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
	return gen.gen()
}

fn test_pointer_field_default_from_global_array_index_is_initialized() {
	csrc := struct_default_c_for_test('pointer_index_default', '
struct Theme {
	value int
}

fn theme_value(n int) int {
	return n
}

const themes = [
	&Theme{
		value: theme_value(11)
	},
	&Theme{
		value: theme_value(22)
	},
]

struct App {
mut:
	theme &Theme = themes[0]
	enabled bool = true
	count int = 7
	spare &Theme
}

fn make_ptr_default() &App {
	return &App{}
}

fn make_value_default() App {
	return App{}
}

fn make_ptr_override() &App {
	return &App{
		theme: themes[1]
	}
}

fn make_value_override() App {
	return App{
		theme: themes[1]
	}
}

fn main() {
	ptr_default := make_ptr_default()
	value_default := make_value_default()
	ptr_override := make_ptr_override()
	value_override := make_value_override()
	_ := ptr_default.theme.value + value_default.theme.value + ptr_override.theme.value + value_override.theme.value
}
')
	default_init := '.theme = ((Theme**)themes.data)[((int)(0))]'
	override_init := '.theme = ((Theme**)themes.data)[((int)(1))]'
	assert csrc.count(default_init) == 2, csrc
	assert csrc.count(override_init) == 2, csrc
	assert csrc.count('.enabled = true') == 4, csrc
	assert csrc.count('.count = 7') == 4, csrc
	assert !csrc.contains('.theme = ((Theme*)0)'), csrc
	assert !csrc.contains('.spare ='), csrc
	assert !csrc.contains('.spare = ((Theme*)0)'), csrc
	assert !csrc.contains('.spare = 0'), csrc
	assert csrc.contains('ptr_default->theme->value'), csrc
	assert csrc.contains('value_default.theme->value'), csrc
	assert csrc.contains('ptr_override->theme->value'), csrc
	assert csrc.contains('value_override.theme->value'), csrc
}
