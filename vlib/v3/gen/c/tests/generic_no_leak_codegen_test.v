import os
import time
import v3.flat
import v3.gen.c as cgen
import v3.parser
import v3.pref
import v3.transform
import v3.types

struct GenericModuleSource {
	rel_path string
	source   string
}

fn generic_no_leak_source_dir(name string) string {
	return os.join_path(os.vtmp_dir(),
		'v3_generic_no_leak_${name}_${os.getpid()}_${time.now().unix_micro()}')
}

fn write_generic_no_leak_source(path string, source string) {
	os.write_file(path, source) or { panic(err) }
}

fn parse_generic_no_leak_sources(root string, module_sources []GenericModuleSource, main_source string) (flat.FlatAst, string) {
	mut prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	os.mkdir_all(root) or { panic(err) }
	for module_source in module_sources {
		path := os.join_path(root, module_source.rel_path)
		os.mkdir_all(os.dir(path)) or { panic(err) }
		write_generic_no_leak_source(path, module_source.source)
		p.parse_into(path)
	}
	main_path := os.join_path(root, 'main.v')
	write_generic_no_leak_source(main_path, main_source)
	mut a := p.parse_file(main_path)
	return *a, main_path
}

fn checked_generic_no_leak_c(mut a flat.FlatAst, diagnostic_file string) string {
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

fn generic_no_leak_errors(mut a flat.FlatAst, diagnostic_file string) []string {
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
	return messages
}

fn has_generic_no_leak_error(messages []string, needle string) bool {
	for msg in messages {
		if msg.contains(needle) {
			return true
		}
	}
	return false
}

fn test_imported_unused_generic_struct_and_fn_do_not_emit_c_placeholders() {
	root := generic_no_leak_source_dir('unused_import')
	defer {
		os.rmdir_all(root) or {}
	}
	mut a, main_path := parse_generic_no_leak_sources(root, [
		GenericModuleSource{
			rel_path: 'dep/dep.v'
			source:   '
module dep

pub struct Box[T] {
	value T
}

pub fn id[T](x T) T {
	return x
}

pub fn noop[T]() {
}

pub struct Concrete {
	value int
}
'
		},
	], '
module main

import dep

fn use_import() {
	_ = dep.Concrete{value: 1}
}
')
	code := checked_generic_no_leak_c(mut a, main_path)

	assert code.contains('struct dep__Concrete')
	assert !code.contains('struct dep__Box')
	assert !code.contains('dep__id')
	assert !code.contains('dep__noop')
	assert !code.contains('dep__T')
	assert !code.contains('__T')
}

fn test_used_generic_function_call_fails_before_c_generation() {
	root := generic_no_leak_source_dir('used_generic_fn')
	defer {
		os.rmdir_all(root) or {}
	}
	mut a, main_path := parse_generic_no_leak_sources(root, [
		GenericModuleSource{
			rel_path: 'dep/dep.v'
			source:   '
module dep

pub fn noop[T]() {
}
'
		},
	], '
module main

import dep

fn main() {
	dep.noop()
}
')
	messages := generic_no_leak_errors(mut a, main_path)

	assert has_generic_no_leak_error(messages,
		'unsupported generic function application `dep.noop`'), messages.str()
}

fn test_used_explicit_generic_function_call_fails_before_c_generation() {
	root := generic_no_leak_source_dir('used_explicit_generic_fn')
	defer {
		os.rmdir_all(root) or {}
	}
	mut a, main_path := parse_generic_no_leak_sources(root, [
		GenericModuleSource{
			rel_path: 'dep/dep.v'
			source:   '
module dep

pub fn noop[T]() {
}
'
		},
	], '
module main

import dep

fn main() {
	dep.noop[int]()
}
')
	messages := generic_no_leak_errors(mut a, main_path)

	assert has_generic_no_leak_error(messages,
		'unsupported generic function application `dep.noop`'), messages.str()
}

fn test_used_same_module_explicit_generic_function_call_fails_before_c_generation() {
	root := generic_no_leak_source_dir('used_same_module_explicit_generic_fn')
	defer {
		os.rmdir_all(root) or {}
	}
	mut a, main_path := parse_generic_no_leak_sources(root, [], '
module main

fn id[T](x T) T {
	return x
}

fn main() {
	_ = id[int](1)
}
')
	messages := generic_no_leak_errors(mut a, main_path)

	assert has_generic_no_leak_error(messages, 'unsupported generic function application `id`'), messages.str()
}

fn test_local_shadow_indexed_call_does_not_report_generic_template_application() {
	root := generic_no_leak_source_dir('local_shadow_indexed_call')
	defer {
		os.rmdir_all(root) or {}
	}
	mut a, main_path := parse_generic_no_leak_sources(root, [], '
module main

fn id[T](x T) T {
	return x
}

fn main() {
	id := [0]
	id[0]()
}
')
	messages := generic_no_leak_errors(mut a, main_path)

	assert !has_generic_no_leak_error(messages, 'unsupported generic function application `id`'), messages.str()
}

fn test_used_generic_type_application_fails_before_c_generation() {
	root := generic_no_leak_source_dir('used_generic_type')
	defer {
		os.rmdir_all(root) or {}
	}
	mut a, main_path := parse_generic_no_leak_sources(root, [
		GenericModuleSource{
			rel_path: 'dep/dep.v'
			source:   '
module dep

pub struct Box[T] {
	value T
}
'
		},
	], '
module main

import dep

fn takes_box(x dep.Box[int]) {
	_ = x
}
')
	messages := generic_no_leak_errors(mut a, main_path)

	assert has_generic_no_leak_error(messages,
		'unsupported generic type application `dep.Box[int]`'), messages.str()
}

fn test_symbolic_fixed_array_postfix_length_is_not_generic_application() {
	root := generic_no_leak_source_dir('symbolic_fixed_array')
	defer {
		os.rmdir_all(root) or {}
	}
	mut a, main_path := parse_generic_no_leak_sources(root, [], '
module main

const n = 4

struct Packet {
	data u8[n]
}

fn use_packet() {
	_ = Packet{}
}
')
	code := checked_generic_no_leak_c(mut a, main_path)

	assert !code.contains('unsupported generic')
	assert !code.contains('__T')
}

fn test_used_generic_struct_init_fails_before_c_generation() {
	root := generic_no_leak_source_dir('used_generic_struct_init')
	defer {
		os.rmdir_all(root) or {}
	}
	mut a, main_path := parse_generic_no_leak_sources(root, [
		GenericModuleSource{
			rel_path: 'dep/dep.v'
			source:   '
module dep

pub struct Box[T] {
	value T
}
'
		},
	], '
module main

import dep

fn make_box() dep.Box[int] {
	return dep.Box[int]{value: 1}
}
')
	messages := generic_no_leak_errors(mut a, main_path)

	assert has_generic_no_leak_error(messages,
		'unsupported generic type application `dep.Box[int]`'), messages.str()
}

fn test_unused_generic_div_result_fixture_does_not_emit_placeholders() {
	root := generic_no_leak_source_dir('div_result')
	defer {
		os.rmdir_all(root) or {}
	}
	mut a, main_path := parse_generic_no_leak_sources(root, [
		GenericModuleSource{
			rel_path: 'dep/dep.v'
			source:   '
module dep

pub struct DivResult[T] {
	quot T
	rem T
}

pub fn div_floor[T](x T, y T) DivResult[T] {
	return DivResult[T]{
		quot: x
		rem: y
	}
}

pub struct Concrete {
	value int
}
'
		},
	], '
module main

import dep

fn use_concrete() {
	_ = dep.Concrete{value: 7}
}
')
	code := checked_generic_no_leak_c(mut a, main_path)

	assert code.contains('struct dep__Concrete')
	assert !code.contains('struct dep__DivResult')
	assert !code.contains('dep__div_floor')
	assert !code.contains('dep__T')
	assert !code.contains('__T')
}

fn test_unused_generic_type_alias_sum_alias_and_interface_do_not_emit_placeholders() {
	root := generic_no_leak_source_dir('generic_type_decls')
	defer {
		os.rmdir_all(root) or {}
	}
	mut a, main_path := parse_generic_no_leak_sources(root, [
		GenericModuleSource{
			rel_path: 'dep/dep.v'
			source:   '
module dep

pub type Alias[T] = T

pub struct Some {
	value int
}

pub struct Other {
	value int
}

pub type SumAlias[T] = Some | Other

pub interface Stream[T] {
	next() T
}

pub struct Concrete {
	value int
}
'
		},
	], '
module main

import dep

fn use_concrete() {
	_ = dep.Concrete{value: 9}
}
')
	code := checked_generic_no_leak_c(mut a, main_path)

	assert code.contains('struct dep__Concrete')
	assert !code.contains('typedef dep__T dep__Alias')
	assert !code.contains('struct dep__SumAlias')
	assert !code.contains('struct dep__Stream')
	assert !code.contains('dep__T')
	assert !code.contains('__T')
}
