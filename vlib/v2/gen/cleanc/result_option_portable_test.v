module cleanc

import os
import v2.parser
import v2.pref as vpref
import v2.token
import v2.transformer
import v2.types

fn portable_result_option_c_for_test(name string, code string) string {
	return portable_result_option_c_for_test_files(name, [code])
}

fn portable_result_option_c_for_test_files(name string, sources []string) string {
	tmp_dir := os.join_path(os.temp_dir(), 'v2_result_option_portable_${name}_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic('failed to create temp dir') }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	mut paths := []string{cap: sources.len}
	for i, code in sources {
		tmp_file := os.join_path(tmp_dir, 'file_${i}.v')
		os.write_file(tmp_file, code) or { panic('failed to write temp file') }
		paths << tmp_file
	}
	prefs := &vpref.Preferences{
		backend:     .cleanc
		no_parallel: true
	}
	mut file_set := token.FileSet.new()
	mut par := parser.Parser.new(prefs)
	files := par.parse_files(paths, mut file_set)
	env := types.Environment.new()
	mut checker := types.Checker.new(prefs, file_set, env)
	checker.check_files(files)
	mut trans := transformer.Transformer.new_with_pref(env, prefs)
	mut gen := Gen.new_with_env_and_pref(trans.transform_files(files), env, prefs)
	return gen.gen()
}

fn test_portable_generate_c_returns_option_none_with_valid_ierror() {
	csrc := portable_result_option_c_for_test('none_ierror', '
fn maybe_int() ?int {
	return none
}

fn main() {
	_ := maybe_int() or { 0 }
}
')
	assert csrc.contains('return (_option_int){ .state = 2, .err = none__ };')
	assert !csrc.contains('return (_option_int){ .state = 2 };')
}

fn test_portable_generate_c_preserves_option_or_return_none_and_error() {
	csrc := portable_result_option_c_for_test('or_return_none_error', '
fn ret_none() ?int {
	return none
}

fn ret_none_from_or() ?int {
	_ := ret_none() or { return none }
	return 1
}

fn ret_error_from_or() ?int {
	a := ret_none() or { return error("Nope") }
	return a
}

fn main() {
	_ := ret_none_from_or() or { 0 }
	_ := ret_error_from_or() or { 0 }
}
')
	assert csrc.contains('return (_option_int){ .state = 2, .err = none__ };')
	assert csrc.contains('return (_option_int){ .state = 2, .err = error(')
	assert !csrc.contains('return (_option_int){ .state = 2 };')
	assert !csrc.contains('return (_option_int){ .is_error=true')
}

fn test_portable_generate_c_binds_err_in_if_guard_failure_branches() {
	csrc := portable_result_option_c_for_test('if_guard_err_binding', '
fn fail_result() !int {
	return error("bad")
}

fn fail_option() ?int {
	return none
}

fn use_result() {
	if _ := fail_result() {
	} else {
		_ = err
	}
}

fn use_option() {
	if _ := fail_option() {
	} else {
		_ = err
	}
}

fn main() {
	use_result()
	use_option()
}
')
	assert csrc.count('IError err = _or_t') >= 2
}

fn test_portable_generate_c_binds_err_in_direct_or_failure_branch() {
	csrc := portable_result_option_c_for_test('direct_or_err_binding', '
fn fail_result() !int {
	return error("bad")
}

fn use_direct_or() int {
	value := fail_result() or {
		_ = err
		return 0
	}
	return value
}

fn main() {
	use_direct_or()
}
')
	assert csrc.contains('IError err = _or_t'), csrc
}

fn test_portable_generate_c_wraps_option_field_payload_assignments_once() {
	csrc := portable_result_option_c_for_test('option_field_wrap_once', '
struct Holder {
mut:
	n ?int
	name ?string
}

fn build() Holder {
	mut h := Holder{}
	h.n = 42
	h.name = "ok"
	return h
}

fn main() {
	_ := build()
}
')
	assert csrc.contains('h.n = ({ _option_int _opt = (_option_int){ .state = 2 }; int _val = 42;')
	assert csrc.contains('h.name = ({ _option_string _opt = (_option_string){ .state = 2 }; string _val =')
	assert !csrc.contains('h.n = 42;')
	assert !csrc.contains('int _val = ((_option_int)')
	assert !csrc.contains('int _val = ({ _option_int')
}

fn test_portable_generate_c_assigns_and_reads_option_payload_selector_lvalue() {
	csrc := portable_result_option_c_for_test('option_payload_lvalue', '
struct Box {
mut:
	name string
}

fn use_payload() {
	mut b := ?Box(Box{})
	b?.name = "foo"
	assert b?.name == "foo"
}

fn main() {
	use_payload()
}
')
	assert csrc.contains('(*(Box*)(((u8*)(&b.err)) + sizeof(IError))).name = (string){.str = "foo"')
	assert csrc.contains('string__eq((*(Box*)(((u8*)(&b.err)) + sizeof(IError))).name, (string){.str = "foo"')
	assert !csrc.contains('((Box)((*(Box*)(((u8*)(&b.err)) + sizeof(IError))))).name =')
	assert !csrc.contains('&((Box)((*(Box*)(((u8*)(&b.err)) + sizeof(IError))))).name')
}

fn test_portable_generate_c_emits_void_return_for_void_option_failure_branch() {
	csrc := portable_result_option_c_for_test('void_or_return', '
struct Box {}

fn maybe_box() ?&Box {
	return none
}

fn use_void() {
	_ := maybe_box() or { return }
}

fn main() {
	use_void()
}
')
	assert csrc.contains('return;')
	assert !csrc.contains('return none;')
}

fn test_portable_generate_c_uses_temp_for_non_addressable_option_payload_read() {
	csrc := portable_result_option_c_for_test('non_addressable_payload_temp', '
struct Box {
	name string
}

fn maybe_box() ?Box {
	return Box{
		name: "tmp"
	}
}

fn read_temp() ?string {
	return maybe_box()?.name
}

fn main() {
	_ := read_temp() or { "" }
}
')
	assert csrc.contains('_option_Box _or_t1 = maybe_box();'), csrc
	assert csrc.contains('(*(Box*)(((u8*)(&_or_t1.err)) + sizeof(IError))).name'), csrc
	assert !csrc.contains('&maybe_box().err')
	assert !csrc.contains('((Box)((*(Box*)(((u8*)(&maybe_box().err)) + sizeof(IError))))).name')
}

fn test_portable_generate_c_option_c_struct_payloads_use_c_struct_storage() {
	csrc := portable_result_option_c_for_test('c_struct_options', '
struct C.sample_record {
	value int
}

fn get_opt_pointer_to_c_struct() ?&C.sample_record {
	return none
}

fn get_opt_to_c_struct() ?C.sample_record {
	return none
}

fn use_c_struct_options() {
	_ := get_opt_pointer_to_c_struct() or { &C.sample_record{} }
	_ := get_opt_to_c_struct() or { C.sample_record{} }
}

fn main() {
	use_c_struct_options()
}
')
	assert csrc.contains('struct _option_struct_sample_recordptr')
	assert csrc.contains('struct _option_struct_sample_record')
	assert csrc.contains('(*(struct sample_record**)(((u8*)(&_or_t1.err)) + sizeof(IError)))')
	assert csrc.contains('(*(struct sample_record*)(((u8*)(&_or_t2.err)) + sizeof(IError)))')
	assert !csrc.contains('(*(sample_record**)')
	assert !csrc.contains('(*(sample_record*)')
	assert !csrc.contains('struct _option_sample_record')
}

fn test_portable_generate_c_option_c_struct_explicit_cast_uses_c_struct_payload_type() {
	csrc := portable_result_option_c_for_test('c_struct_option_casts', '
struct C.sample_record {
	value int
}

fn cast_c_struct_value() ?C.sample_record {
	value := C.sample_record{
		value: 7
	}
	return ?C.sample_record(value)
}

fn cast_c_struct_pointer(mut value C.sample_record) ?&C.sample_record {
	return ?&C.sample_record(&value)
}

fn main() {
	mut value := C.sample_record{
		value: 9
	}
	_ := cast_c_struct_value() or { C.sample_record{} }
	_ := cast_c_struct_pointer(mut value) or { &value }
}
')
	assert csrc.contains('struct sample_record _val = value;'), csrc
	assert csrc.contains('struct sample_record* _val = &value;'), csrc
	assert !csrc.contains('struct_sample_record _val')
	assert !csrc.contains('struct_sample_record* _val')
}

fn test_option_result_payload_canonicalizes_c_struct_pointer_payloads_portable() {
	mut g := Gen.new([])
	g.c_struct_types['sample_record'] = true
	payload := g.types_type_to_c(types.Type(types.OptionType{
		base_type: types.Type(types.Pointer{
			base_type: types.Type(types.Struct{
				name: 'sample_record'
			})
		})
	}))
	assert payload == '_option_struct_sample_recordptr'
	assert option_value_type(payload) == 'struct_sample_record*'
	assert g.option_result_payload_c_type(option_value_type(payload)) == 'struct sample_record*'
}

fn test_option_result_payload_canonicalizes_c_struct_value_payloads_portable() {
	mut g := Gen.new([])
	g.c_struct_types['sample_record'] = true
	payload := g.types_type_to_c(types.Type(types.OptionType{
		base_type: types.Type(types.Struct{
			name: 'sample_record'
		})
	}))
	assert payload == '_option_struct_sample_record'
	assert option_value_type(payload) == 'struct_sample_record'
	assert g.option_result_payload_c_type(option_value_type(payload)) == 'struct sample_record'
}
