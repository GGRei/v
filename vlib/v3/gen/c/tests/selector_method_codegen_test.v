import os
import time
import v3.flat
import v3.gen.c as cgen
import v3.parser
import v3.pref
import v3.transform
import v3.types

fn selector_method_source_path(name string) string {
	return os.join_path(os.vtmp_dir(),
		'v3_selector_method_codegen_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
}

fn selector_method_source_dir(name string) string {
	return os.join_path(os.vtmp_dir(),
		'v3_selector_method_codegen_${name}_${os.getpid()}_${time.now().unix_micro()}')
}

fn write_selector_method_source(path string, source string) {
	os.write_file(path, source) or { panic(err) }
}

fn selector_method_checked_c_from_source(name string, source string) string {
	src := selector_method_source_path(name)
	defer {
		os.rm(src) or {}
	}
	write_selector_method_source(src, source)
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	mut a := p.parse_file(src)
	return selector_method_checked_c(mut a, src)
}

fn selector_method_checked_transformed_c_from_source(name string, source string) string {
	src := selector_method_source_path(name)
	defer {
		os.rm(src) or {}
	}
	write_selector_method_source(src, source)
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	mut a := p.parse_file(src)
	return selector_method_checked_transformed_c(mut a, src)
}

fn selector_method_checked_c_from_module_sources(root string, module_sources map[string]string, main_source string) string {
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	for rel_path, source in module_sources {
		path := os.join_path(root, rel_path)
		os.mkdir_all(os.dir(path)) or { panic(err) }
		write_selector_method_source(path, source)
		p.parse_into(path)
	}
	main_path := os.join_path(root, 'main.v')
	write_selector_method_source(main_path, main_source)
	mut a := p.parse_file(main_path)
	return selector_method_checked_c(mut a, main_path)
}

fn selector_method_checked_transformed_c_from_module_sources(root string, module_sources map[string]string, main_source string) string {
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	for rel_path, source in module_sources {
		path := os.join_path(root, rel_path)
		os.mkdir_all(os.dir(path)) or { panic(err) }
		write_selector_method_source(path, source)
		p.parse_into(path)
	}
	main_path := os.join_path(root, 'main.v')
	write_selector_method_source(main_path, main_source)
	mut a := p.parse_file(main_path)
	return selector_method_checked_transformed_c(mut a, main_path)
}

fn selector_method_checked_c(mut a flat.FlatAst, diagnostic_file string) string {
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
	mut g := cgen.FlatGen.new()
	return g.gen_with_used(a, map[string]bool{}, &tc)
}

fn selector_method_checked_transformed_c(mut a flat.FlatAst, diagnostic_file string) string {
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
	tc.diagnose_unknown_calls = false
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

fn selector_method_errors_from_source(name string, source string) []string {
	src := selector_method_source_path(name)
	defer {
		os.rm(src) or {}
	}
	write_selector_method_source(src, source)
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
	return messages
}

fn selector_method_errors_from_module_sources(root string, module_sources map[string]string, main_source string) []string {
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	for rel_path, source in module_sources {
		path := os.join_path(root, rel_path)
		os.mkdir_all(os.dir(path)) or { panic(err) }
		write_selector_method_source(path, source)
		p.parse_into(path)
	}
	main_path := os.join_path(root, 'main.v')
	write_selector_method_source(main_path, main_source)
	mut a := p.parse_file(main_path)
	mut tc := types.TypeChecker.new(a)
	tc.collect(a)
	tc.annotate_types()
	tc.diagnose_unknown_calls = true
	tc.diagnostic_files[main_path] = true
	tc.check_semantics()
	mut messages := []string{}
	for err in tc.errors {
		messages << err.msg
	}
	return messages
}

fn selector_method_errors_contain(messages []string, needle string) bool {
	for msg in messages {
		if msg.contains(needle) {
			return true
		}
	}
	return false
}

fn test_array_rune_string_uses_typed_receiver_method() {
	code := selector_method_checked_c_from_source('array_rune_string_method', '
fn (ra []rune) string() string {
	return ""
}

fn use_runes() string {
	runes := []rune{len: 2}
	return runes.string()
}
')

	assert code.contains('Array_rune__string(runes)')
	assert !code.contains('rand__PRNG__string')
}

fn test_array_rune_slice_string_does_not_address_rvalue_slice() {
	code := selector_method_checked_c_from_source('array_rune_slice_string_method', '
fn (ra []rune) string() string {
	return ""
}

fn use_rune_slice() string {
	runes := []rune{len: 2}
	return runes[0..1].string()
}
')

	assert code.contains('Array_rune__string(array_slice')
	assert !code.contains('Array_rune__string(&array_slice')
	assert !code.contains('rand__PRNG__string')
}

fn test_struct_receiver_string_and_plain_module_string_still_resolve() {
	root := selector_method_source_dir('rand_string_collision')
	defer {
		os.rmdir_all(root) or {}
	}
	code := selector_method_checked_c_from_module_sources(root, {
		'rand/rand.v': '
module rand

pub struct PRNG {}

pub fn (mut rng PRNG) string(len int) string {
	return ""
}

pub fn string(len int) string {
	return ""
}
'
	}, '
module main

import rand

fn use_rand() {
	mut rng := rand.PRNG{}
	_ := rng.string(4)
	_ := rand.string(5)
}
')

	assert code.contains('rand__PRNG__string(&rng, 4)')
	assert code.contains('rand__string(5)')
}

fn test_array_alias_receiver_methods_use_resolved_alias_method_symbols() {
	root := selector_method_source_dir('array_alias_receiver_methods')
	defer {
		os.rmdir_all(root) or {}
	}
	code := selector_method_checked_transformed_c_from_module_sources(root, {
		'strings/strings.v': '
module strings

pub type Builder = []u8

pub fn new_builder(initial_size int) Builder {
	return Builder([]u8{len: initial_size})
}

pub fn (mut b Builder) write_string(s string) {}

pub fn (mut b Builder) write_runes(runes []rune) {}

pub fn (mut b Builder) write_byte(data u8) {}
'
	}, '
module main

import strings

struct Holder {
mut:
	sb strings.Builder
}

fn use_builder_alias_methods() {
	mut sb := strings.new_builder(0)
	runes := []rune{len: 2}
	sb.write_string("x")
	sb.write_runes(runes)
	mut h := Holder{
		sb: strings.new_builder(0)
	}
	h.sb.write_byte(33)
}
')

	assert code.contains('strings__Builder__write_string(&sb')
	assert code.contains('strings__Builder__write_runes(&sb, runes)')
	assert code.contains('strings__Builder__write_byte(&h.sb, 33)')
	assert !code.contains('.write_string(')
	assert !code.contains('.write_runes(')
	assert !code.contains('.write_byte(')
}

fn test_plain_array_does_not_inherit_alias_receiver_methods() {
	root := selector_method_source_dir('plain_array_alias_receiver_rejected')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := selector_method_errors_from_module_sources(root, {
		'strings/strings.v': '
module strings

pub type Builder = []u8

pub fn (mut b Builder) write_string(s string) {}
'
	}, '
module main

import strings

fn bad_plain_array_alias_method() {
	mut bytes := []u8{}
	bytes.write_string("x")
}
')

	assert selector_method_errors_contain(messages, 'unknown function `bytes.write_string`'), messages.str()
}

fn test_alias_receiver_inner_raw_array_free_uses_array_builtin() {
	root := selector_method_source_dir('alias_receiver_inner_raw_array_free')
	defer {
		os.rmdir_all(root) or {}
	}
	code := selector_method_checked_transformed_c_from_module_sources(root, {
		'strings/strings.v': '
module strings

pub type Builder = []u8

@[unsafe]
pub fn (mut b Builder) free() {
	if b.data != 0 {
		mut arr := unsafe { &[]u8(b) }
		unsafe { arr.free() }
	}
}
'
	}, '
module main

import strings

fn use_builder_free(mut b strings.Builder) {
	b.free()
}
')

	assert code.contains('array__free(arr)')
	assert !code.contains('strings__Builder__free(arr)')
	assert code.contains('strings__Builder__free(')
}

fn test_alias_receiver_inner_raw_array_ensure_cap_uses_array_builtin() {
	root := selector_method_source_dir('alias_receiver_inner_raw_array_ensure_cap')
	defer {
		os.rmdir_all(root) or {}
	}
	code := selector_method_checked_transformed_c_from_module_sources(root, {
		'strings/strings.v': '
module strings

pub type Builder = []u8

pub fn (mut b Builder) ensure_cap(n int) {
	mut arr := unsafe { &[]u8(b) }
	arr.ensure_cap(n)
}
'
	}, '
module main

import strings

fn use_builder_ensure_cap(mut b strings.Builder) {
	b.ensure_cap(8)
}
')

	assert code.contains('array_ensure_cap(arr, n)')
	assert !code.contains('strings__Builder__ensure_cap(arr, n)')
	assert code.contains('strings__Builder__ensure_cap(')
}

fn test_array_prepend_builtin_uses_runtime_array_insert() {
	code := selector_method_checked_transformed_c_from_source('array_prepend_builtin', '
fn use_array_prepend() {
	mut xs := []int{}
	xs.prepend(7)
}
')

	assert code.contains('array__prepend(&xs, &(int[]){7})')
	assert !code.contains('xs.prepend(xs)')
}

fn test_qualified_array_element_method_does_not_fall_back_to_local_short_element_method() {
	root := selector_method_source_dir('qualified_array_method_collision')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := selector_method_errors_from_module_sources(root, {
		'gfx/gfx.v': '
module gfx

pub struct Color {}
'
	}, '
module main

import gfx

struct Color {}

fn (xs []Color) swatch() string {
	return ""
}

fn bad_qualified_array_call() {
	xs := []gfx.Color{}
	_ := xs.swatch()
}
')

	assert selector_method_errors_contain(messages, 'unknown function `xs.swatch`'), messages.str()
}

fn test_unknown_array_receiver_method_is_rejected() {
	messages := selector_method_errors_from_source('unknown_array_receiver_method', '
fn bad_array_call() {
	xs := []int{}
	xs.no_such_array_method()
}
')

	assert selector_method_errors_contain(messages, 'unknown function `xs.no_such_array_method`'), messages.str()
}
