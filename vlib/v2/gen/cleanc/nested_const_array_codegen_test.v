module cleanc

import os
import v2.ast
import v2.parser
import v2.pref as vpref
import v2.token
import v2.transformer
import v2.types

fn nested_const_array_c_for_test(name string, source string) string {
	tmp_file := os.join_path(os.temp_dir(), 'v2_nested_const_array_${name}_${os.getpid()}.v')
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

fn test_nested_dynamic_array_const_gets_runtime_init() {
	csrc := nested_const_array_c_for_test('runtime_init', '
const nested_values = [[1, 2], [3, 4]]

fn main() {
	_ := nested_values.len
	_ := nested_values[0].len
	_ := nested_values[1][1]
}
')
	init_fn_pos := csrc.index('void __v_init_consts_main()') or { -1 }
	assign_pos := csrc.index('nested_values = new_array_from_c_array(') or { -1 }
	init_call_pos := csrc.index('\t__v_init_consts_main();') or { -1 }
	first_use_pos := csrc.index('(void)(nested_values.len);') or { -1 }
	assert csrc.contains('array nested_values = {0};')
	assert init_fn_pos >= 0, csrc
	assert assign_pos > init_fn_pos, csrc
	assert init_call_pos >= 0, csrc
	assert first_use_pos > init_call_pos, csrc
}

fn test_flat_dynamic_array_const_keeps_static_backing_without_runtime_init() {
	csrc := nested_const_array_c_for_test('flat_static_backing', '
const flat_values = [1, 2, 3]

fn main() {
	_ := flat_values.len
}
')
	assert csrc.contains('array flat_values = ((array){ .data = __const_array_data_flat_values')
	assert !csrc.contains('flat_values = builtin__new_array_from_c_array_noscan(')
	assert !csrc.contains('void __v_init_consts_main()')
}

fn test_empty_array_assignment_to_nested_array_field_uses_field_element_type() {
	csrc := nested_const_array_c_for_test('empty_nested_array_field', '
struct Holder {
mut:
	rows [][]int
}

fn main() {
	mut holder := Holder{}
	holder.rows = []
	_ := holder.rows.len
}
')
	assert csrc.contains('holder.rows = __new_array_with_array_default(0, 0, sizeof(Array_int),'), csrc
	assert !csrc.contains('holder.rows = __new_array_with_default_noscan(0, 0, sizeof(int), NULL);'), csrc
}
