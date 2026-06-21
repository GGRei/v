import os
import time
import v3.flat
import v3.gen.c as cgen
import v3.parser
import v3.pref
import v3.transform
import v3.types

fn struct_init_source_path(name string) string {
	return os.join_path(os.vtmp_dir(),
		'v3_struct_init_codegen_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
}

fn struct_init_source_dir(name string) string {
	return os.join_path(os.vtmp_dir(),
		'v3_struct_init_codegen_${name}_${os.getpid()}_${time.now().unix_micro()}')
}

fn write_struct_init_source(path string, source string) {
	os.write_file(path, source) or { panic(err) }
}

fn checked_struct_init_c_from_source(name string, source string) string {
	src := struct_init_source_path(name)
	defer {
		os.rm(src) or {}
	}
	write_struct_init_source(src, source)
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	mut a := p.parse_file(src)
	return checked_struct_init_c(mut a, src)
}

fn checked_struct_init_c_from_module_sources(root string, module_sources map[string]string, main_source string) string {
	mut prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	for rel_path, source in module_sources {
		path := os.join_path(root, rel_path)
		os.mkdir_all(os.dir(path)) or { panic(err) }
		write_struct_init_source(path, source)
		p.parse_into(path)
	}
	main_path := os.join_path(root, 'main.v')
	write_struct_init_source(main_path, main_source)
	mut a := p.parse_file(main_path)
	return checked_struct_init_c(mut a, main_path)
}

struct StructInitModuleSource {
	rel_path string
	source   string
}

fn checked_struct_init_c_from_ordered_module_sources(root string, module_sources []StructInitModuleSource, main_source string) string {
	mut prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	for module_source in module_sources {
		path := os.join_path(root, module_source.rel_path)
		os.mkdir_all(os.dir(path)) or { panic(err) }
		write_struct_init_source(path, module_source.source)
		p.parse_into(path)
	}
	main_path := os.join_path(root, 'main.v')
	write_struct_init_source(main_path, main_source)
	mut a := p.parse_file(main_path)
	return checked_struct_init_c(mut a, main_path)
}

fn checked_struct_init_c(mut a flat.FlatAst, diagnostic_file string) string {
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

fn test_positional_struct_init_emits_positional_c_initializer() {
	code := checked_struct_init_c_from_source('positional_struct_init', '
struct Pair {
	left int
	right int
}

fn make_pair() Pair {
	return Pair{1, 2}
}
')

	assert code.contains('return (Pair){1, 2};')
	assert !code.contains('. =')
}

fn test_named_struct_init_keeps_named_c_designators() {
	code := checked_struct_init_c_from_source('named_struct_init', '
struct Pair {
	left int
	right int
}

fn make_pair() Pair {
	return Pair{left: 1, right: 2}
}
')

	assert code.contains('return (Pair){.left = 1, .right = 2};')
	assert !code.contains('. =')
}

fn test_struct_init_uses_resolved_alias_type_not_short_name_collision() {
	root := struct_init_source_dir('qualified_alias_collision')
	defer {
		os.rmdir_all(root) or {}
	}
	code := checked_struct_init_c_from_module_sources(root, {
		'sgl/sgl.v': '
module sgl

pub struct C.sgl_context {}

pub type Context = C.sgl_context

pub const context = Context{0x00010001}
'
		'gg/gg.v':   '
module gg

pub struct Context {
	value int
}
'
	}, '
module main

import gg
import sgl

fn use_context() {
	ctx := sgl.context
	other := gg.Context{value: 1}
	_ = ctx
	_ = other
}
')

	assert code.contains('sgl__context = (struct sgl_context){0x00010001}')
	assert !code.contains('sgl__context = (gg__Context)')
	assert !code.contains('. =')
}

fn test_struct_init_default_fields_use_resolved_type_not_short_name_collision() {
	root := struct_init_source_dir('default_fields_collision')
	defer {
		os.rmdir_all(root) or {}
	}
	code := checked_struct_init_c_from_ordered_module_sources(root, [
		StructInitModuleSource{
			rel_path: 'gg/gg.v'
			source:   '
module gg

pub struct Context {
	wrong_default int = 99
}
'
		},
		StructInitModuleSource{
			rel_path: 'sgl/sgl.v'
			source:   '
module sgl

pub struct Context {
	id int
	owned_default int = 11
}

pub const context = Context{7}
'
		},
	], '
module main

import sgl

fn use_context() {
	ctx := sgl.context
	_ = ctx
}
')

	assert code.contains('sgl__context = (sgl__Context){7, .owned_default = 11}')
	assert !code.contains('sgl__context = (sgl__Context){7, .wrong_default = 99}')
	assert !code.contains('sgl__context = (gg__Context)')
	assert !code.contains('. =')
}

fn test_qualified_embedded_struct_field_uses_concrete_type_and_short_field_name() {
	root := struct_init_source_dir('qualified_embedded_field')
	defer {
		os.rmdir_all(root) or {}
	}
	code := checked_struct_init_c_from_ordered_module_sources(root, [
		StructInitModuleSource{
			rel_path: 'buffer/buffer.v'
			source:   '
module buffer

pub struct PRNGBuffer {
	cursor int
}
'
		},
	], '
module main

import buffer

struct WyRandRNG {
	buffer.PRNGBuffer
mut:
	state u64
	bytes_left int
	buffer u64
}

fn make_rng() WyRandRNG {
	return WyRandRNG{}
}
')

	assert code.contains('\tbuffer__PRNGBuffer PRNGBuffer;')
	assert code.contains('\tu64 buffer;')
	assert !code.contains('\tvoid buffer;')
	assert code.count('\tu64 buffer;') == 1
	assert !code.contains('. =')
}
