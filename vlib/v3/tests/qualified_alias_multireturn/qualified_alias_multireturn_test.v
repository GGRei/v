module qualified_alias_multireturn

import os
import time
import v3.flat
import v3.gen.c as cgen
import v3.parser
import v3.pref
import v3.transform
import v3.types

fn source_dir(name string) string {
	return os.join_path(os.vtmp_dir(), 'v3_${name}_${os.getpid()}_${time.now().unix_micro()}')
}

fn write_source(path string, source string) {
	os.write_file(path, source) or { panic(err) }
}

fn has_odd_decl_assign(a &flat.FlatAst, id flat.NodeId) bool {
	if int(id) < 0 {
		return false
	}
	node := a.nodes[int(id)]
	if node.kind == .decl_assign && int(node.children_count) % 2 != 0 {
		return true
	}
	for i in 0 .. node.children_count {
		if has_odd_decl_assign(a, a.child(&node, i)) {
			return true
		}
	}
	return false
}

fn find_fn(a &flat.FlatAst, name string) flat.NodeId {
	for i, node in a.nodes {
		if node.kind == .fn_decl && node.value == name {
			return flat.NodeId(i)
		}
	}
	return flat.empty_node
}

fn count_selector_value(a &flat.FlatAst, id flat.NodeId, value string) int {
	if int(id) < 0 {
		return 0
	}
	node := a.nodes[int(id)]
	mut total := if node.kind == .selector && node.value == value { 1 } else { 0 }
	for i in 0 .. node.children_count {
		total += count_selector_value(a, a.child(&node, i), value)
	}
	return total
}

fn has_error(messages []string, needle string) bool {
	for msg in messages {
		if msg.contains(needle) {
			return true
		}
	}
	return false
}

fn write_fixture_module(root string) string {
	module_dir := os.join_path(root, 'fixture')
	os.mkdir_all(module_dir) or { panic(err) }
	module_path := os.join_path(module_dir, 'fixture.v')
	write_source(module_path, '
module fixture

struct C.FONScontext {}

pub type Context = C.FONScontext

pub const some_const = 3

pub fn (c &Context) pair() (int, int) {
	return 1, 2
}
')
	return module_path
}

fn write_main_source(root string, source string) string {
	main_path := os.join_path(root, 'main.v')
	write_source(main_path, 'module main\n\n' + source)
	return main_path
}

fn check_transform_recheck(module_path string, main_path string) (&flat.FlatAst, []string) {
	a, messages, _ := check_transform_recheck_gen_c(module_path, main_path)
	return a, messages
}

fn check_transform_recheck_gen_c(module_path string, main_path string) (&flat.FlatAst, []string, string) {
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	p.parse_into(module_path)
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
	if messages.len > 0 {
		return a, messages, ''
	}
	transform.transform(mut a, &tc)
	tc.diagnose_unknown_calls = true
	tc.annotate_types()
	tc.check_semantics()
	for err in tc.errors {
		messages << err.msg
	}
	if messages.len > 0 {
		return a, messages, ''
	}
	mut g := cgen.FlatGen.new()
	code := g.gen_with_used(a, map[string]bool{}, &tc)
	return a, messages, code
}

fn assert_multireturn_expanded(a &flat.FlatAst, fn_name string) {
	fn_id := find_fn(a, fn_name)
	assert int(fn_id) >= 0
	assert !has_odd_decl_assign(a, fn_id)
	assert count_selector_value(a, fn_id, 'arg0') == 1
	assert count_selector_value(a, fn_id, 'arg1') == 1
}

fn assert_c_output_uses_pointer_cast_and_multireturn_fields(code string) {
	assert code.contains('(FONScontext*)(uptr)')
	assert !code.contains('&(FONScontext)(uptr)')
	assert code.contains('.arg0')
	assert code.contains('.arg1')
}

fn test_imported_alias_type_call_preserves_multireturn_transform() {
	root := source_dir('qualified_alias_multireturn')
	defer {
		os.rmdir_all(root) or {}
	}
	module_path := write_fixture_module(root)
	main_path := write_main_source(root, '
import fixture

fn use_alias(uptr voidptr) {
	ctx := unsafe { &fixture.Context(uptr) }
	width, height := ctx.pair()
	_ = width
	_ = height
}
')

	a, messages, code := check_transform_recheck_gen_c(module_path, main_path)

	assert messages.len == 0, messages.str()
	assert_multireturn_expanded(a, 'use_alias')
	assert_c_output_uses_pointer_cast_and_multireturn_fields(code)
}

fn test_imported_alias_type_call_with_explicit_import_alias() {
	root := source_dir('qualified_alias_multireturn_as_alias')
	defer {
		os.rmdir_all(root) or {}
	}
	module_path := write_fixture_module(root)
	main_path := write_main_source(root, '
import fixture as fx

fn use_alias(uptr voidptr) {
	ctx := unsafe { &fx.Context(uptr) }
	width, height := ctx.pair()
	_ = width
	_ = height
}
')

	a, messages, code := check_transform_recheck_gen_c(module_path, main_path)

	assert messages.len == 0, messages.str()
	assert_multireturn_expanded(a, 'use_alias')
	assert_c_output_uses_pointer_cast_and_multireturn_fields(code)
}

fn test_missing_imported_alias_type_call_is_rejected() {
	root := source_dir('qualified_alias_missing')
	defer {
		os.rmdir_all(root) or {}
	}
	module_path := write_fixture_module(root)
	main_path := write_main_source(root, '
import fixture

fn use_missing(uptr voidptr) {
	ctx := unsafe { &fixture.Missing(uptr) }
	_ = ctx
}
')

	_, messages := check_transform_recheck(module_path, main_path)

	assert messages.len > 0, messages.str()
	assert has_error(messages, 'fixture.Missing'), messages.str()
}

fn test_local_value_does_not_become_import_namespace() {
	root := source_dir('qualified_alias_shadow')
	defer {
		os.rmdir_all(root) or {}
	}
	module_path := write_fixture_module(root)
	main_path := write_main_source(root, '
import fixture

fn use_shadow(uptr voidptr) {
	fixture := 1
	ctx := unsafe { &fixture.Context(uptr) }
	_ = ctx
}
')

	_, messages := check_transform_recheck(module_path, main_path)

	assert messages.len > 0, messages.str()
	has_shadow_error := has_error(messages, 'fixture.Context')
		|| has_error(messages, 'unknown field `Context`')
	assert has_shadow_error, messages.str()
}

fn test_local_value_does_not_resolve_imported_const_selector() {
	root := source_dir('qualified_alias_shadow_const')
	defer {
		os.rmdir_all(root) or {}
	}
	module_path := write_fixture_module(root)
	main_path := write_main_source(root, '
import fixture

fn use_shadow_const() {
	fixture := 1
	_ := fixture.some_const
}
')

	_, messages := check_transform_recheck(module_path, main_path)

	assert messages.len > 0, messages.str()
	assert has_error(messages, 'unknown field `some_const` on `int`')
}

fn test_field_method_selector_continues_when_base_is_local_value() {
	root := source_dir('qualified_alias_field_method')
	defer {
		os.rmdir_all(root) or {}
	}
	module_path := write_fixture_module(root)
	main_path := write_main_source(root, '
import fixture

struct Context {}

struct Wrapper {
	ctx Context
}

fn (c Context) run() int {
	return 7
}

fn use_field_method(wrapper Wrapper) {
	_ := wrapper.ctx.run()
}
')

	_, messages, _ := check_transform_recheck_gen_c(module_path, main_path)

	assert messages.len == 0, messages.str()
}

fn test_shadowed_value_method_named_like_imported_alias_is_not_cgen_type_constructor() {
	root := source_dir('qualified_alias_shadow_method_cgen')
	defer {
		os.rmdir_all(root) or {}
	}
	module_path := write_fixture_module(root)
	main_path := write_main_source(root, '
import fixture

struct LocalContext {}

struct FixtureValue {}

fn (f FixtureValue) Context(uptr voidptr) LocalContext {
	_ = uptr
	return LocalContext{}
}

fn use_shadow_method(uptr voidptr) {
	fixture := FixtureValue{}
	ctx := unsafe { &fixture.Context(uptr) }
	_ = ctx
}
')

	_, messages, code := check_transform_recheck_gen_c(module_path, main_path)

	assert messages.len == 0, messages.str()
	assert !code.contains('(FONScontext*)(uptr)')
	assert code.contains('FixtureValue__Context')
}

fn test_shadowed_function_field_named_like_imported_alias_is_not_cgen_type_constructor() {
	root := source_dir('qualified_alias_shadow_fn_field_cgen')
	defer {
		os.rmdir_all(root) or {}
	}
	module_path := write_fixture_module(root)
	main_path := write_main_source(root, '
import fixture

struct LocalContext {}

struct FixtureValue {
	Context fn (voidptr) LocalContext
}

fn make_context(uptr voidptr) LocalContext {
	_ = uptr
	return LocalContext{}
}

fn use_shadow_fn_field(uptr voidptr) {
	fixture := FixtureValue{
		Context: make_context
	}
	ctx := unsafe { &fixture.Context(uptr) }
	_ = ctx
}
')

	_, messages, code := check_transform_recheck_gen_c(module_path, main_path)

	assert messages.len == 0, messages.str()
	assert !code.contains('(FONScontext*)(uptr)')
	assert code.contains('make_context') || code.contains('.Context')
}
