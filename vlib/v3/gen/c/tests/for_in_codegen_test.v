import os
import time
import v3.flat
import v3.gen.c as cgen
import v3.parser
import v3.pref
import v3.transform
import v3.types

fn gen_c_from_source(name string, source string) string {
	src := os.join_path(os.vtmp_dir(), 'v3_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
	defer {
		os.rm(src) or {}
	}
	os.write_file(src, source) or { panic(err) }
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	mut a := p.parse_file(src)
	mut tc := types.TypeChecker.new(a)
	tc.collect(a)
	tc.annotate_types()
	mut g := cgen.FlatGen.new()
	return g.gen_with_used(a, map[string]bool{}, &tc)
}

fn transformed_c_from_source(name string, source string) string {
	src := os.join_path(os.vtmp_dir(), 'v3_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
	defer {
		os.rm(src) or {}
	}
	os.write_file(src, source) or { panic(err) }
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	mut a := p.parse_file(src)
	return transformed_c(mut a, src)
}

fn transformed_c(mut a flat.FlatAst, diagnostic_file string) string {
	mut tc := types.TypeChecker.new(a)
	tc.collect(a)
	tc.annotate_types()
	tc.diagnose_unknown_calls = true
	tc.diagnostic_files[diagnostic_file] = true
	tc.check_semantics()
	mut messages := []string{}
	for err in tc.errors {
		messages << err.msg
	}
	assert messages.len == 0, messages.str()
	transform.transform(mut a, &tc)
	tc.annotate_types()
	tc.check_semantics()
	messages.clear()
	for err in tc.errors {
		messages << err.msg
	}
	assert messages.len == 0, messages.str()
	mut g := cgen.FlatGen.new()
	return g.gen_with_used(a, map[string]bool{}, &tc)
}

fn assert_no_for_in_fallback(code string, iter_var string, elem_var string) {
	assert !code.contains('${iter_var} < 0')
	assert !code.contains('int ${elem_var} = 0;')
}

fn test_for_in_mut_array_receiver_uses_pointer_array_shape() {
	code := gen_c_from_source('for_in_mut_array_receiver', '
fn cleanup(mut a []string) {
	for s in a {
		value := s.len
		_ = value
	}
}
')

	assert code.contains('void cleanup(Array* a)')
	assert code.contains('for (int __iter_s = 0; __iter_s < (a)->len; __iter_s++) {')
	assert code.contains('string s = *(string*)array_get(*(a), __iter_s);')
	assert_no_for_in_fallback(code, '__iter_s', 's')
}

fn test_transformed_for_in_nested_fixed_array_preserves_aggregate_element() {
	code := transformed_c_from_source('transformed_for_in_nested_fixed_array', '
fn scan_rows() int {
	rows := [[1, 2]!, [3, 4]!]!
	mut total := 0
	for row in rows {
		for x in row {
			total += x
		}
	}
	return total
}
')

	assert code.contains('int rows[2][2] = {{1, 2}, {3, 4}};')
	assert code.contains('int row[2];')
	assert code.contains('memmove(row,')
	assert code.contains('sizeof(row)')
	assert code.contains('int x = row[')
	assert !code.contains('int row =')
	assert !code.contains('array row =')
	assert !code.contains('Array row =')
	assert !code.contains('row < 0')
	assert !code.contains('int row = 0;')
}

fn test_transformed_for_in_const_nested_fixed_array_preserves_aggregate_element() {
	code := transformed_c_from_source('transformed_for_in_const_nested_fixed_array', '
const rows = [[1, 2]!, [3, 4]!]!

fn scan_const_rows() int {
	mut total := 0
	for row in rows {
		for x in row {
			total += x
		}
	}
	return total
}
')

	assert code.contains('const int main__rows[2][2] = {{1, 2}, {3, 4}};')
	assert code.contains('int row[2];')
	assert code.contains('memmove(row,')
	assert code.contains('sizeof(row)')
	assert code.contains('int x = row[')
	assert !code.contains('int row =')
	assert !code.contains('array row =')
	assert !code.contains('Array row =')
	assert !code.contains('row < 0')
	assert !code.contains('int row = 0;')
}

fn test_for_in_mut_array_receiver_keeps_index_and_value_types() {
	code := gen_c_from_source('for_in_mut_array_receiver_index_value', '
fn cleanup(mut a []string) {
	for i, s in a {
		value := s.len + i
		_ = value
	}
}
')

	assert code.contains('void cleanup(Array* a)')
	assert code.contains('for (int i = 0; i < (a)->len; i++) {')
	assert code.contains('string s = *(string*)array_get(*(a), i);')
	assert_no_for_in_fallback(code, 'i', 's')
}

fn test_for_in_pointer_string_uses_unwrapped_string_shape() {
	code := gen_c_from_source('for_in_pointer_string', '
fn scan(s &string) {
	for ch in s {
		value := int(ch)
		_ = value
	}
}
')

	assert code.contains('void scan(string* s)')
	assert code.contains('for (int __iter_ch = 0; __iter_ch < (s)->len; __iter_ch++) {')
	assert code.contains('u8 ch = ((u8*)(s)->str)[__iter_ch];')
	assert_no_for_in_fallback(code, '__iter_ch', 'ch')
}

fn test_for_in_mut_map_still_uses_map_iteration_shape() {
	code := gen_c_from_source('for_in_mut_map', '
fn scan(mut m map[string]int) {
	for name, value in m {
		_ = name
		_ = value
	}
}
')

	assert code.contains('void scan(map* m)')
	assert code.contains('(m)->key_values')
	assert code.contains('string name = *(string*)((m)->key_values.keys')
	assert code.contains('int value = *(int*)((m)->key_values.values')
	assert_no_for_in_fallback(code, 'name', 'value')
}
