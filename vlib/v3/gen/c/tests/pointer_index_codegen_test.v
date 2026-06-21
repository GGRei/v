import os
import time
import v3.gen.c as cgen
import v3.parser
import v3.pref
import v3.transform
import v3.types

fn source_path(name string) string {
	return os.join_path(os.vtmp_dir(), 'v3_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
}

fn checked_transformed_c_from_source(name string, source string) string {
	src := source_path(name)
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
	tc.diagnose_unknown_calls = true
	tc.diagnostic_files[src] = true
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

fn count_substr(haystack string, needle string) int {
	if needle.len == 0 {
		return 0
	}
	mut count := 0
	mut rest := haystack
	for {
		idx := rest.index(needle) or { break }
		count++
		rest = rest[idx + needle.len..]
	}
	return count
}

fn test_pointer_to_string_index_keeps_string_type_across_repeated_loops() {
	code := checked_transformed_c_from_source('ptr_string_repeated_loops', '
fn ptr_string_index(data_len int, input_base &string) int {
	mut total := 0
	for i := 0; i < data_len; i++ {
		part := input_base[i]
		total += part.len
	}
	unsafe {
		for i := 0; i < data_len; i++ {
			part := input_base[i]
			total += part.len
		}
	}
	return total
}
')

	assert count_substr(code, 'string part = input_base[i];') == 2
	assert !code.contains('u8 part = input_base[i];')
	assert code.contains('total += part.len;')
}

fn test_pointer_to_u8_index_stays_byte() {
	code := checked_transformed_c_from_source('ptr_u8_index', '
fn ptr_u8_index(input_base &u8) u8 {
	part := input_base[0]
	return part
}
')

	assert code.contains('u8 part = input_base[0];')
	assert !code.contains('string part = input_base[0];')
}
