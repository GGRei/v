import os
import strings
import time
import v3.flat
import v3.gen.c as cgen
import v3.markused
import v3.parser
import v3.pref
import v3.transform
import v3.types

const function_value_vexe = @VEXE
const function_value_test_file = @FILE

fn function_value_source_dir(name string) string {
	return os.join_path(os.vtmp_dir(),
		'v3_function_value_codegen_${name}_${os.getpid()}_${time.now().unix_micro()}')
}

fn write_function_value_source(path string, source string) {
	os.write_file(path, source) or { panic(err) }
}

fn function_value_parse_sources(root string, module_sources map[string]string, main_source string) (flat.FlatAst, string) {
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	os.mkdir_all(root) or { panic(err) }
	for rel_path, source in module_sources {
		path := os.join_path(root, rel_path)
		os.mkdir_all(os.dir(path)) or { panic(err) }
		write_function_value_source(path, source)
		p.parse_into(path)
	}
	main_path := os.join_path(root, 'main.v')
	write_function_value_source(main_path, main_source)
	mut a := p.parse_file(main_path)
	return *a, main_path
}

fn function_value_checked_c_from_sources(root string, module_sources map[string]string, main_source string) string {
	mut a, main_path := function_value_parse_sources(root, module_sources, main_source)
	mut tc := types.TypeChecker.new(a)
	function_value_check_transform_recheck(mut a, mut tc, main_path)
	used := markused.mark_used(a, tc)
	mut g := cgen.FlatGen.new()
	return g.gen_with_used(a, used, &tc)
}

fn function_value_used_from_sources(root string, module_sources map[string]string, main_source string) map[string]bool {
	mut a, main_path := function_value_parse_sources(root, module_sources, main_source)
	mut tc := types.TypeChecker.new(a)
	function_value_check_transform_recheck(mut a, mut tc, main_path)
	return markused.mark_used(a, tc)
}

fn function_value_check_transform_recheck(mut a flat.FlatAst, mut tc types.TypeChecker, main_path string) {
	tc.collect(a)
	tc.annotate_types()
	tc.diagnose_unknown_calls = true
	tc.diagnostic_files[main_path] = true
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
}

fn function_value_errors_from_sources(root string, module_sources map[string]string, main_source string) []string {
	mut a, main_path := function_value_parse_sources(root, module_sources, main_source)
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

fn function_value_has_error(messages []string, needle string) bool {
	for msg in messages {
		if msg.contains(needle) {
			return true
		}
	}
	return false
}

fn function_value_has_line_with(code string, needles []string) bool {
	for line in code.split_into_lines() {
		mut ok := true
		for needle in needles {
			if !line.contains(needle) {
				ok = false
				break
			}
		}
		if ok {
			return true
		}
	}
	return false
}

fn function_value_optional_local_assigned_from_call(code string, opt_type string, call string) string {
	suffix := ' = ${call};'
	for raw_line in code.split('\n') {
		line := raw_line.trim_space()
		if line.starts_with('${opt_type} ') && line.ends_with(suffix) {
			return line[opt_type.len + 1..line.len - suffix.len]
		}
	}
	return ''
}

fn function_value_capi_sources() map[string]string {
	return {
		'capi/capi.v': '
module capi

pub struct Event {
	code int
}

pub type EventCb = fn (const_event &Event, user_data voidptr)
pub type MutableEventCb = fn (&Event, voidptr)

pub struct C.desc {
	cb fn (voidptr)
	event_cb fn (const_event &Event, user_data voidptr)
}

pub type Desc = C.desc

pub struct C.mutable_desc {
	event_cb fn (&Event, voidptr)
}

pub type MutableDesc = C.mutable_desc

pub struct C.alias_desc {
	event_cb EventCb
}

pub type AliasDesc = C.alias_desc

pub struct C.mutable_alias_desc {
	event_cb MutableEventCb
}

pub type MutableAliasDesc = C.mutable_alias_desc

pub struct C.outer {
	desc Desc
}

pub type Outer = C.outer
'
	}
}

fn test_parallel_function_value_codegen_runs_under_parallel_define() {
	if os.getenv('V3_FUNCTION_VALUE_PARALLEL_CHILD') == '1' {
		return
	}
	result :=
		os.execute('V3_FUNCTION_VALUE_PARALLEL_CHILD=1 VJOBS=2 ${function_value_vexe} -d parallel ${function_value_test_file}')
	assert result.exit_code == 0, result.output
}

fn test_parallel_cgen_preserves_function_value_facts_in_workers() {
	if os.getenv('V3_FUNCTION_VALUE_PARALLEL_CHILD') != '1' {
		return
	}
	root := function_value_source_dir('parallel_workers')
	defer {
		os.rmdir_all(root) or {}
	}
	mut main_source := strings.new_builder(96_000)
	main_source.writeln('module main')
	main_source.writeln('')
	main_source.writeln('import util')
	main_source.writeln('')
	main_source.writeln('struct Config {')
	main_source.writeln('\tcb fn (int) int')
	main_source.writeln('}')
	main_source.writeln('')
	main_source.writeln('struct App {')
	main_source.writeln('\tvalue int')
	main_source.writeln('}')
	main_source.writeln('')
	main_source.writeln('struct TypedConfig {')
	main_source.writeln('\tcb fn (voidptr)')
	main_source.writeln('}')
	main_source.writeln('')
	main_source.writeln('fn main_only_dep() int {')
	main_source.writeln('\treturn 40')
	main_source.writeln('}')
	main_source.writeln('')
	main_source.writeln('fn local_handler(x int) int {')
	main_source.writeln('\treturn x + main_only_dep()')
	main_source.writeln('}')
	main_source.writeln('')
	main_source.writeln('fn frame(app &App) {')
	main_source.writeln('\t_ := app.value')
	main_source.writeln('}')
	main_source.writeln('')
	main_source.writeln('fn make_config() Config {')
	main_source.writeln('\treturn Config{')
	main_source.writeln('\t\tcb: util.local_handler')
	main_source.writeln('\t}')
	main_source.writeln('}')
	main_source.writeln('')
	main_source.writeln('fn make_typed_config() TypedConfig {')
	main_source.writeln('\treturn TypedConfig{')
	main_source.writeln('\t\tcb: frame')
	main_source.writeln('\t}')
	main_source.writeln('}')
	main_source.writeln('')
	for i in 0 .. 1100 {
		next_call := if i == 1099 { '0' } else { 'worker_${i + 1}()' }
		main_source.writeln('fn worker_${i}() int {')
		main_source.writeln('\treturn ${next_call}')
		main_source.writeln('}')
	}
	main_source.writeln('')
	main_source.writeln('fn main() {')
	main_source.writeln('\t_ := make_config()')
	main_source.writeln('\t_ := make_typed_config()')
	main_source.writeln('\t_ := worker_0()')
	main_source.writeln('}')
	code := function_value_checked_c_from_sources(root, {
		'util/util.v': '
module util

pub fn util_only_dep() int {
	return 4
}

pub fn local_handler(x int) int {
	return x + util_only_dep()
}
'
	}, main_source.str())
	assert code.contains('.cb = util__local_handler')
	assert code.contains('int util__local_handler(int x)')
	assert code.contains('int util__util_only_dep(')
	assert !code.contains('.cb = util.local_handler')
	assert !code.contains('.cb = local_handler')
	assert !code.contains('int local_handler(int x)')
	assert !code.contains('int main_only_dep(')
	assert code.contains('.cb = __v_fn_value_')
	assert code.contains('void __v_fn_value_')
	assert code.contains('frame((App*)arg0);')
	assert !code.contains('.cb = frame')
}

fn test_struct_callback_field_uses_resolved_symbol_and_roots_function_value() {
	root := function_value_source_dir('struct_field')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {
		'util/util.v': '
module util

pub fn util_only_dep() int {
	return 10
}

pub fn local_handler(x int) int {
	return x + util_only_dep()
}
'
	}, '
module main

import util

struct Config {
	cb fn (int) int
}

fn local_only_dep() int {
	return 1
}

fn local_handler(x int) int {
	return x + local_only_dep()
}

fn unused_handler(x int) int {
	return x + 2
}

fn make_config() Config {
	return Config{
		cb: local_handler
	}
}

fn main() {
	_ := make_config()
}
')

	assert code.contains('.cb = local_handler')
	assert code.contains('int local_handler(int x)')
	assert code.contains('int local_only_dep(')
	assert !code.contains('util__local_handler')
	assert !code.contains('util__util_only_dep')
	assert !code.contains('int unused_handler(int x)')
}

fn test_import_alias_callback_value_uses_module_symbol() {
	root := function_value_source_dir('import_alias')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {
		'util/util.v': '
module util

pub fn handler(x int) int {
	return x + 3
}
'
	}, '
module main

import util as m

struct Config {
	cb fn (int) int
}

fn make_config() Config {
	return Config{
		cb: m.handler
	}
}

fn main() {
	_ := make_config()
}
')

	assert code.contains('.cb = util__handler')
	assert !code.contains('.cb = handler')
	assert !code.contains('.cb = m.handler')
	assert code.contains('int util__handler(int x)')
	assert !code.contains('__v_fn_value_')
}

fn test_nested_struct_callback_field_uses_resolved_symbol() {
	root := function_value_source_dir('nested_struct_field')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {
		'util/util.v': '
module util

pub fn handler(x int) int {
	return x + 7
}
'
	}, '
module main

import util

struct Config {
	cb fn (int) int
}

struct Outer {
	cfg Config
}

fn make_outer() Outer {
	return Outer{
		cfg: Config{
			cb: util.handler
		}
	}
}

fn main() {
	_ := make_outer()
}
')

	assert code.contains('.cb = util__handler')
	assert code.contains('int util__handler(int x)')
	assert !code.contains('.cb = handler')
	assert !code.contains('__v_fn_value_')
}

fn test_local_shadow_selector_does_not_become_imported_callback() {
	root := function_value_source_dir('local_shadow')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {
		'util/util.v': '
module util

pub fn handler(x int) int {
	return x + 3
}
'
	}, '
module main

import util as m

struct Box {
	handler fn (int) int
}

struct Config {
	cb fn (int) int
}

fn fallback(x int) int {
	return x
}

fn make_config() Config {
	m := Box{
		handler: fallback
	}
	return Config{
		cb: m.handler
	}
}

fn main() {
	_ := make_config()
}
')

	assert code.contains('.cb = m.handler')
	assert !code.contains('.cb = util__handler')
}

fn test_call_arg_callback_value_uses_resolved_module_symbol() {
	root := function_value_source_dir('call_arg')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {
		'util/util.v': '
module util

pub fn util_only_dep() int {
	return 4
}

pub fn local_handler(x int) int {
	return x + util_only_dep()
}
'
	}, '
module main

import util

fn main_only_dep() int {
	return 40
}

fn local_handler(x int) int {
	return x + main_only_dep()
}

fn set_cb(cb fn (int) int) int {
	return cb(2)
}

fn main() {
	_ := set_cb(util.local_handler)
}
')

	assert code.contains('set_cb(util__local_handler)')
	assert code.contains('int util__local_handler(int x)')
	assert code.contains('int util__util_only_dep(')
	assert !code.contains('int local_handler(int x)')
	assert !code.contains('int main_only_dep(')
}

fn test_assignment_callback_value_uses_resolved_module_symbol() {
	root := function_value_source_dir('assign')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {
		'util/util.v': '
module util

pub fn handler(x int) int {
	return x + 5
}
'
	}, '
module main

import util

fn fallback(x int) int {
	return x
}

fn set_cb(cb fn (int) int) int {
	return cb(3)
}

fn main() {
	mut cb := fallback
	cb = util.handler
	_ := set_cb(cb)
}
')

	assert code.contains('cb = util__handler;')
	assert code.contains('int util__handler(int x)')
}

fn test_local_option_return_function_value_call_uses_fn_ptr_storage() {
	root := function_value_source_dir('local_option_fn_value_call')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {}, '
module main

fn maybe_value(x int) ?int {
	if x > 0 {
		return x
	}
	return none
}

fn use_value(x int) int {
	f := maybe_value
	value := f(x) or { return 0 }
	return value
}

fn main() {
	_ := use_value(1)
}
')

	assert code.contains('_fn_ptr_')
	assert code.contains('f = maybe_value;')
	assert code.contains('Optional_int')
	opt_tmp := function_value_optional_local_assigned_from_call(code, 'Optional_int', 'f(x)')
	assert opt_tmp.len > 0
	assert code.contains('= f(x);')
	assert code.contains('${opt_tmp}.ok')
	assert code.contains('${opt_tmp}.value')
	opt_pos := code.index('typedef struct { bool ok; int value; } Optional_int;') or { -1 }
	fn_ptr_pos := code.index('typedef Optional_int (*_fn_ptr_') or { -1 }
	assert opt_pos >= 0
	assert fn_ptr_pos > opt_pos
	assert !code.contains('int f = maybe_value')
	assert !code.contains('fn(')
}

fn test_imported_option_return_function_value_call_uses_exact_symbol_and_roots_target() {
	root := function_value_source_dir('imported_option_fn_value_call')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {
		'util/util.v': '
module util

pub fn helper() int {
	return 3
}

pub fn maybe_value(x int) ?int {
	if x > 0 {
		return x + helper()
	}
	return none
}
'
	}, '
module main

import util

fn use_value(x int) int {
	f := util.maybe_value
	value := f(x) or { return 0 }
	return value
}

fn main() {
	_ := use_value(1)
}
')

	assert code.contains('f = util__maybe_value;')
	assert code.contains('Optional_int util__maybe_value(int x)')
	assert code.contains('int util__helper(')
	opt_tmp := function_value_optional_local_assigned_from_call(code, 'Optional_int', 'f(x)')
	assert opt_tmp.len > 0
	assert code.contains('= f(x);')
	assert code.contains('${opt_tmp}.ok')
	assert code.contains('${opt_tmp}.value')
	assert !code.contains('f = maybe_value')
	assert !code.contains('util.maybe_value')
	assert !code.contains('int f =')
	assert !code.contains('fn(')
}

fn test_reassigned_imported_option_function_value_keeps_fn_ptr_storage() {
	root := function_value_source_dir('reassigned_imported_option_fn_value')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {
		'dep/dep.v': '
module dep

pub fn read_a(path string) ?int {
	if path.len > 0 {
		return 1
	}
	return none
}

pub fn read_b(path string) ?int {
	if path.len > 0 {
		return 2
	}
	return none
}
'
	}, "
module main

import dep

fn use_read(path string) int {
	mut f := dep.read_a
	f = dep.read_b
	value := f(path) or { return 0 }
	return value
}

fn main() {
	_ := use_read('x')
}
")

	assert function_value_has_line_with(code, ['_fn_ptr_', ' f = dep__read_a;'])
	assert code.contains('f = dep__read_b;')
	opt_tmp := function_value_optional_local_assigned_from_call(code, 'Optional_int', 'f(path)')
	assert opt_tmp.len > 0
	assert code.contains('= f(path);')
	assert code.contains('${opt_tmp}.ok')
	assert code.contains('${opt_tmp}.value')
	assert !code.contains('int f =')
	assert !code.contains('voidptr f =')
	assert !code.contains('void* f =')
	assert !code.contains('fn(')
	assert !code.contains('dep.read_b')
}

fn test_function_value_call_does_not_suffix_root_unrelated_homonym() {
	root := function_value_source_dir('fn_value_no_suffix_homonym_root')
	defer {
		os.rmdir_all(root) or {}
	}
	module_sources := {
		'dep/dep.v':     '
module dep

pub fn unique_dep() int {
	return 7
}

pub fn path() int {
	return 1
}

pub fn maybe_value(x int) ?int {
	if x > 0 {
		return x + unique_dep()
	}
	return none
}
'
		'other/other.v': '
module other

pub fn other_only_dep() int {
	return 99
}

pub fn f(x int) ?int {
	if x > 0 {
		return other_only_dep()
	}
	return none
}
'
	}
	main_source := '
module main

import dep
import other

fn use_value(x int) int {
	f := dep.maybe_value
	value := f(dep.path()) or { return 0 }
	return value
}

fn main() {
	_ := use_value(1)
}
'
	used := function_value_used_from_sources(root, module_sources, main_source)
	assert 'dep.maybe_value' in used
	assert 'dep.unique_dep' in used
	assert 'dep.path' in used
	assert 'other.f' !in used
	assert 'other__f' !in used
	assert 'other.other_only_dep' !in used
	assert 'other__other_only_dep' !in used
	code := function_value_checked_c_from_sources(root, module_sources, main_source)

	assert code.contains('f = dep__maybe_value;')
	assert code.contains('Optional_int dep__maybe_value(int x)')
	assert code.contains('int dep__unique_dep(')
	assert code.contains('int dep__path(')
	opt_tmp := function_value_optional_local_assigned_from_call(code, 'Optional_int',
		'f(dep__path())')
	assert opt_tmp.len > 0
	assert code.contains('= f(dep__path());')
	assert code.contains('${opt_tmp}.ok')
	assert code.contains('${opt_tmp}.value')
	assert !code.contains('other__f')
	assert !code.contains('other__other_only_dep')
}

fn test_const_alias_function_value_roots_exact_target_not_homonym() {
	root := function_value_source_dir('const_alias_fn_value_no_suffix_homonym_root')
	defer {
		os.rmdir_all(root) or {}
	}
	module_sources := {
		'dep/dep.v':     '
module dep

pub fn unique_dep() int {
	return 7
}

pub fn path() int {
	return 1
}

pub fn maybe_value(x int) ?int {
	if x > 0 {
		return x + unique_dep()
	}
	return none
}
'
		'other/other.v': '
module other

pub fn other_only_dep() int {
	return 99
}

pub fn f(x int) ?int {
	if x > 0 {
		return other_only_dep()
	}
	return none
}
'
	}
	main_source := '
module main

import dep
import other

const cb = dep.maybe_value

fn use_value() int {
	f := cb
	value := f(dep.path()) or { return 0 }
	return value
}

fn main() {
	_ := use_value()
}
'
	used := function_value_used_from_sources(root, module_sources, main_source)
	assert 'dep.maybe_value' in used
	assert 'dep.unique_dep' in used
	assert 'dep.path' in used
	assert 'other.f' !in used
	assert 'other__f' !in used
	assert 'other.other_only_dep' !in used
	assert 'other__other_only_dep' !in used
	code := function_value_checked_c_from_sources(root, module_sources, main_source)

	assert code.contains('f = dep__maybe_value;')
	assert code.contains('Optional_int dep__maybe_value(int x)')
	assert code.contains('int dep__unique_dep(')
	assert code.contains('int dep__path(')
	opt_tmp := function_value_optional_local_assigned_from_call(code, 'Optional_int',
		'f(dep__path())')
	assert opt_tmp.len > 0
	assert code.contains('= f(dep__path());')
	assert code.contains('${opt_tmp}.ok')
	assert code.contains('${opt_tmp}.value')
	assert !code.contains('main__cb')
	assert !code.contains('other__f')
	assert !code.contains('other__other_only_dep')
}

fn test_local_function_value_shadows_const_alias_without_suffix_rooting() {
	root := function_value_source_dir('local_fn_value_shadows_const_alias')
	defer {
		os.rmdir_all(root) or {}
	}
	module_sources := {
		'dep/dep.v':     '
module dep

pub fn unique_dep() int {
	return 7
}

pub fn path() int {
	return 1
}

pub fn maybe_value(x int) ?int {
	if x > 0 {
		return x + unique_dep()
	}
	return none
}
'
		'other/other.v': '
module other

pub fn other_only_dep() int {
	return 99
}

pub fn f(x int) ?int {
	if x > 0 {
		return other_only_dep()
	}
	return none
}
'
	}
	main_source := '
module main

import dep
import other

const cb = other.f

fn use_value() int {
	cb := dep.maybe_value
	value := cb(dep.path()) or { return 0 }
	return value
}

fn main() {
	_ := use_value()
}
'
	used := function_value_used_from_sources(root, module_sources, main_source)
	assert 'dep.maybe_value' in used
	assert 'dep.unique_dep' in used
	assert 'dep.path' in used
	assert 'other.f' !in used
	assert 'other__f' !in used
	assert 'other.other_only_dep' !in used
	assert 'other__other_only_dep' !in used
	code := function_value_checked_c_from_sources(root, module_sources, main_source)

	assert code.contains('Optional_int dep__maybe_value(int x)')
	assert code.contains('int dep__unique_dep(')
	assert code.contains('int dep__path(')
	assert !code.contains('main__cb')
	assert !code.contains('other__f')
	assert !code.contains('other__other_only_dep')
}

fn test_non_option_function_value_call_uses_concrete_return_type() {
	root := function_value_source_dir('non_option_fn_value_call')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {}, '
module main

fn add_one(x int) int {
	return x + 1
}

fn use_value(x int) int {
	f := add_one
	value := f(x)
	return value
}

fn main() {
	_ := use_value(1)
}
')

	assert code.contains('f = add_one;')
	assert code.contains('int value = f(x);')
	assert !code.contains('int f = add_one')
	assert !code.contains('fn(')
}

fn test_function_value_call_uses_pointer_argument_adaptation() {
	root := function_value_source_dir('fn_value_pointer_arg_adaptation')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {}, '
module main

struct Payload {
	value int
}

fn take(payload &Payload) int {
	return payload.value
}

fn use_value() int {
	payload := Payload{
		value: 9
	}
	f := take
	return f(payload)
}

fn main() {
	_ := use_value()
}
')

	assert code.contains('f = take;')
	assert code.contains('return f(&payload);')
	assert !code.contains('return f(payload);')
}

fn test_alias_fntype_local_call_materializes_function_pointer() {
	root := function_value_source_dir('alias_fn_type_local_call')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {}, '
module main

type Reader = fn (int) ?int

fn maybe_value(x int) ?int {
	if x > 0 {
		return x
	}
	return none
}

fn use_value(x int) int {
	f := Reader(maybe_value)
	value := f(x) or { return 0 }
	return value
}

fn main() {
	_ := use_value(1)
}
')

	assert code.contains('_fn_ptr_')
	assert code.contains('maybe_value')
	assert function_value_has_line_with(code, ['_fn_ptr_', ' f = ', 'maybe_value'])
	opt_tmp := function_value_optional_local_assigned_from_call(code, 'Optional_int', 'f(x)')
	assert opt_tmp.len > 0
	assert code.contains('= f(x);')
	assert code.contains('${opt_tmp}.ok')
	assert code.contains('${opt_tmp}.value')
	assert !code.contains('fn(')
	assert !code.contains('fn_ptr:')
	assert !code.contains('int f = maybe_value')
	assert !code.contains('voidptr f =')
	assert !code.contains('void* f =')
}

fn test_function_value_call_wrong_arity_is_rejected_before_c() {
	root := function_value_source_dir('fn_value_wrong_arity')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, {}, '
module main

fn add_one(x int) int {
	return x + 1
}

fn use_value() int {
	f := add_one
	return f()
}
')

	assert function_value_has_error(messages, 'expected 1, got 0')
}

fn test_function_value_call_return_mismatch_is_rejected_before_c() {
	root := function_value_source_dir('fn_value_return_mismatch')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, {}, '
module main

fn add_one(x int) int {
	return x + 1
}

fn use_value(x int) string {
	f := add_one
	return f(x)
}
')

	assert function_value_has_error(messages, 'cannot return `int` as `string`')
}

fn test_shadowed_import_function_value_selector_does_not_use_module_fallback() {
	root := function_value_source_dir('fn_value_import_shadow')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, {
		'util/util.v': '
module util

pub fn maybe_value(x int) ?int {
	if x > 0 {
		return x
	}
	return none
}
'
	}, '
module main

import util

struct Holder {
	maybe_value int
}

fn use_value() {
	util := Holder{
		maybe_value: 1
	}
	f := util.maybe_value
	_ := f(1)
}
')

	has_unknown_call := function_value_has_error(messages, 'unknown function `f`')
	has_non_function_call := function_value_has_error(messages, 'cannot call non-function')
	assert has_unknown_call || has_non_function_call
}

fn test_typed_userdata_callback_field_uses_wrapper() {
	root := function_value_source_dir('typed_userdata')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {}, '
module main

struct App {
	value int
}

struct Config {
	cb fn (voidptr)
}

fn frame(app &App) {
	_ := app.value
}

fn make_config() Config {
	return Config{
		cb: frame
	}
}

fn main() {
	_ := make_config()
}
')

	assert code.contains('.cb = __v_fn_value_')
	assert code.contains('void __v_fn_value_')
	assert code.contains('frame((App*)arg0);')
	assert !code.contains('.cb = frame')
	assert code.contains('void frame(App* app)')
}

fn test_typed_event_userdata_callback_field_uses_wrapper() {
	root := function_value_source_dir('typed_event_userdata')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {}, '
module main

struct Event {
	code int
}

struct App {
	value int
}

struct Config {
	cb fn (const_event &Event, user_data voidptr)
}

fn on_event(const_event &Event, app &App) {
	_ := const_event.code
	_ := app.value
}

fn make_config() Config {
	return Config{
		cb: on_event
	}
}

fn main() {
	_ := make_config()
}
')

	assert code.contains('.cb = __v_fn_value_')
	assert code.contains('void __v_fn_value_')
	assert code.contains('const Event* arg0')
	assert code.contains('on_event(arg0, (App*)arg1);')
	assert !code.contains('.cb = on_event')
	assert code.contains('void on_event(const Event* const_event, App* app)')
}

fn test_named_params_alias_userdata_callback_field_uses_wrapper() {
	root := function_value_source_dir('named_params_alias_userdata')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {}, '
module main

struct App {
	value int
}

type Cb = fn (data voidptr)

@[params]
struct Config {
	cb Cb
}

fn frame(mut app App) {
	_ := app.value
}

fn make_config(cfg Config) {}

fn main() {
	make_config(cb: frame)
}
')

	assert code.contains('.cb = __v_fn_value_')
	assert code.contains('void __v_fn_value_')
	assert code.contains('frame((App*)arg0);')
	assert !code.contains('.cb = frame')
}

fn test_named_params_alias_event_userdata_callback_field_uses_wrapper() {
	root := function_value_source_dir('named_params_alias_event_userdata')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {}, '
module main

struct Event {
	code int
}

struct App {
	value int
}

type EventCb = fn (e &Event, data voidptr)

@[params]
struct Config {
	event_cb EventCb
}

fn on_event(e &Event, mut app App) {
	_ := e.code
	_ := app.value
}

fn make_config(cfg Config) {}

fn main() {
	make_config(event_cb: on_event)
}
')

	assert code.contains('.event_cb = __v_fn_value_')
	assert code.contains('void __v_fn_value_')
	assert code.contains('Event* arg0, void* arg1')
	assert code.contains('on_event(arg0, (App*)arg1);')
	assert !code.contains('on_event((Event*)arg0')
	assert !code.contains('.event_cb = on_event')
}

fn test_named_params_exact_alias_callback_field_uses_direct_symbol() {
	root := function_value_source_dir('named_params_alias_direct')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {}, '
module main

type Cb = fn (data voidptr)

@[params]
struct Config {
	cb Cb
}

fn direct(data voidptr) {
	_ := data
}

fn make_config(cfg Config) {}

fn main() {
	make_config(cb: direct)
}
')

	assert code.contains('.cb = direct')
	assert code.contains('void direct(void* data)')
	assert !code.contains('__v_fn_value_')
}

fn test_named_params_alias_callback_wrong_arity_is_rejected_before_c() {
	root := function_value_source_dir('named_params_alias_wrong_arity')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, {}, '
module main

struct App {
	value int
}

type Cb = fn (data voidptr)

@[params]
struct Config {
	cb Cb
}

fn wrong(app &App, extra int) {
	_ := extra
}

fn make_config(cfg Config) {}

fn main() {
	make_config(cb: wrong)
}
')

	assert function_value_has_error(messages, 'for named field `cb`')
}

fn test_named_params_alias_callback_wrong_return_is_rejected_before_c() {
	root := function_value_source_dir('named_params_alias_wrong_return')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, {}, '
module main

struct App {
	value int
}

type Cb = fn (data voidptr)

@[params]
struct Config {
	cb Cb
}

fn wrong(app &App) int {
	return app.value
}

fn make_config(cfg Config) {}

fn main() {
	make_config(cb: wrong)
}
')

	assert function_value_has_error(messages, 'for named field `cb`')
}

fn test_named_params_alias_callback_non_pointer_is_rejected_before_c() {
	root := function_value_source_dir('named_params_alias_non_pointer')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, {}, '
module main

type Cb = fn (data voidptr)

@[params]
struct Config {
	cb Cb
}

fn wrong(app int) {
	_ := app
}

fn make_config(cfg Config) {}

fn main() {
	make_config(cb: wrong)
}
')

	assert function_value_has_error(messages, 'for named field `cb`')
}

fn test_named_params_alias_callback_function_variable_is_rejected_before_c() {
	root := function_value_source_dir('named_params_alias_fn_var')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, {}, '
module main

struct App {
	value int
}

type Cb = fn (data voidptr)

@[params]
struct Config {
	cb Cb
}

fn frame(mut app App) {
	_ := app.value
}

fn make_config(cfg Config) {}

fn main() {
	cb_var := frame
	make_config(cb: cb_var)
}
')

	assert function_value_has_error(messages, 'for named field `cb`')
}

fn test_non_pointer_const_param_name_does_not_emit_const_c_type() {
	root := function_value_source_dir('non_pointer_const_name')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {}, '
module main

fn count(const_value int) int {
	return const_value + 1
}

fn main() {
	_ := count(1)
}
')

	assert code.contains('int count(int const_value)')
	assert !code.contains('const int const_value')
}

fn test_mutable_const_named_fn_type_param_does_not_emit_const_c_type() {
	root := function_value_source_dir('mutable_const_fn_type')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, {}, '
module main

struct Event {
	code int
}

struct Config {
	cb fn (mut const_event &Event, user_data voidptr)
}

fn on_event(mut const_event Event, user_data voidptr) {
	_ := const_event
	_ := user_data
}

fn make_config() Config {
	return Config{
		cb: on_event
	}
}

fn main() {
	_ := make_config()
}
')

	assert code.contains('void on_event(Event* const_event, void* user_data)')
	assert code.contains(')(Event*, void*)')
	assert !code.contains('const Event*')
}

fn test_imported_c_struct_callback_field_uses_resolved_module_symbol_without_wrapper() {
	root := function_value_source_dir('imported_c_struct_callback_direct')
	defer {
		os.rmdir_all(root) or {}
	}
	mut modules := function_value_capi_sources()
	modules['util/util.v'] = '
module util

pub fn direct(user_data voidptr) {
	_ := user_data
}
'
	code := function_value_checked_c_from_sources(root, modules, '
module main

import capi
import util

fn direct(user_data voidptr) {
	_ := user_data
}

fn make_desc() capi.Desc {
	return capi.Desc{
		cb: util.direct
	}
}

fn main() {
	_ := make_desc()
}
')

	assert code.contains('.cb = util__direct')
	assert code.contains('void util__direct(void* user_data)')
	assert !code.contains('.cb = direct')
	assert !code.contains('void direct(void* user_data)')
	assert !code.contains('__v_fn_value_')
}

fn test_nested_imported_c_struct_callback_field_uses_userdata_wrapper() {
	root := function_value_source_dir('nested_imported_c_struct_callback_wrapper')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, function_value_capi_sources(), '
module main

import capi

struct App {
	value int
}

fn frame(app &App) {
	_ := app.value
}

fn make_outer() capi.Outer {
	return capi.Outer{
		desc: capi.Desc{
			cb: frame
		}
	}
}

fn main() {
	_ := make_outer()
}
')

	assert code.contains('.cb = __v_fn_value_')
	assert code.contains('void __v_fn_value_')
	assert code.contains('frame((App*)arg0);')
	assert !code.contains('.cb = frame')
}

fn test_imported_c_struct_event_userdata_wrapper_casts_only_userdata() {
	root := function_value_source_dir('imported_c_struct_event_userdata_wrapper')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, function_value_capi_sources(), '
module main

import capi

struct App {
	value int
}

fn on_event(const_event &capi.Event, app &App) {
	_ := const_event.code
	_ := app.value
}

fn make_desc() capi.Desc {
	return capi.Desc{
		event_cb: on_event
	}
}

fn main() {
	_ := make_desc()
}
')

	assert code.contains('.event_cb = __v_fn_value_')
	assert code.contains('void __v_fn_value_')
	assert code.contains('const capi__Event* arg0')
	assert code.contains('on_event(arg0, (App*)arg1);')
	assert !code.contains('on_event((capi__Event*)arg0')
	assert !code.contains('.event_cb = on_event')
}

fn test_imported_c_struct_const_event_alias_userdata_wrapper_casts_only_userdata() {
	root := function_value_source_dir('imported_c_struct_const_event_alias_wrapper')
	defer {
		os.rmdir_all(root) or {}
	}
	code := function_value_checked_c_from_sources(root, function_value_capi_sources(), '
module main

import capi

struct App {
	value int
}

fn on_event(const_event &capi.Event, app &App) {
	_ := const_event.code
	_ := app.value
}

fn make_desc() capi.AliasDesc {
	return capi.AliasDesc{
		event_cb: on_event
	}
}

fn main() {
	_ := make_desc()
}
')

	assert code.contains('.event_cb = __v_fn_value_')
	assert code.contains('void __v_fn_value_')
	assert code.contains('const capi__Event* arg0')
	assert code.contains('on_event(arg0, (App*)arg1);')
	assert !code.contains('on_event((capi__Event*)arg0')
	assert !code.contains('.event_cb = on_event')
}

fn test_imported_c_struct_const_event_callback_field_uses_direct_symbol() {
	root := function_value_source_dir('imported_c_struct_const_event_direct')
	defer {
		os.rmdir_all(root) or {}
	}
	mut modules := function_value_capi_sources()
	modules['util/util.v'] = '
module util

import capi

pub fn event_direct(const_event &capi.Event, user_data voidptr) {
	_ := const_event.code
	_ := user_data
}
'
	code := function_value_checked_c_from_sources(root, modules, '
module main

import capi
import util

fn make_desc() capi.Desc {
	return capi.Desc{
		event_cb: util.event_direct
	}
}

fn main() {
	_ := make_desc()
}
')

	assert code.contains('.event_cb = util__event_direct')
	assert code.contains('void util__event_direct(const capi__Event* const_event, void* user_data)')
	assert code.contains(')(const capi__Event*, void*)')
	assert !code.contains('.event_cb = event_direct')
	assert !code.contains('__v_fn_value_')
}

fn test_imported_c_struct_const_event_alias_callback_field_uses_direct_symbol() {
	root := function_value_source_dir('imported_c_struct_const_event_alias_direct')
	defer {
		os.rmdir_all(root) or {}
	}
	mut modules := function_value_capi_sources()
	modules['util/util.v'] = '
module util

import capi

pub fn event_direct(const_event &capi.Event, user_data voidptr) {
	_ := const_event.code
	_ := user_data
}
'
	code := function_value_checked_c_from_sources(root, modules, '
module main

import capi
import util

fn make_desc() capi.AliasDesc {
	return capi.AliasDesc{
		event_cb: util.event_direct
	}
}

fn main() {
	_ := make_desc()
}
')

	assert code.contains('.event_cb = util__event_direct')
	assert code.contains('void util__event_direct(const capi__Event* const_event, void* user_data)')
	assert code.contains(')(const capi__Event*, void*)')
	assert !code.contains('.event_cb = event_direct')
	assert !code.contains('__v_fn_value_')
}

fn test_nested_imported_c_struct_const_event_callback_field_uses_direct_symbol() {
	root := function_value_source_dir('nested_imported_const_event_direct')
	defer {
		os.rmdir_all(root) or {}
	}
	mut modules := function_value_capi_sources()
	modules['util/util.v'] = '
module util

import capi

pub fn event_direct(const_event &capi.Event, user_data voidptr) {
	_ := const_event.code
	_ := user_data
}
'
	code := function_value_checked_c_from_sources(root, modules, '
module main

import capi
import util

fn make_outer() capi.Outer {
	return capi.Outer{
		desc: capi.Desc{
			event_cb: util.event_direct
		}
	}
}

fn main() {
	_ := make_outer()
}
')

	assert code.contains('.event_cb = util__event_direct')
	assert code.contains('void util__event_direct(const capi__Event* const_event, void* user_data)')
	assert !code.contains('.event_cb = event_direct')
	assert !code.contains('__v_fn_value_')
}

fn test_imported_c_struct_const_event_callback_rejects_non_const_target() {
	root := function_value_source_dir('imported_c_struct_const_event_non_const')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, function_value_capi_sources(), '
module main

import capi

fn on_event(event &capi.Event, user_data voidptr) {
	_ := event.code
	_ := user_data
}

fn make_desc() capi.Desc {
	return capi.Desc{
		event_cb: on_event
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `event_cb`')
}

fn test_imported_c_struct_const_event_alias_callback_rejects_non_const_target() {
	root := function_value_source_dir('imported_c_struct_const_event_alias_non_const')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, function_value_capi_sources(), '
module main

import capi

fn on_event(event &capi.Event, user_data voidptr) {
	_ := event.code
	_ := user_data
}

fn make_desc() capi.AliasDesc {
	return capi.AliasDesc{
		event_cb: on_event
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `event_cb`')
}

fn test_imported_c_struct_const_event_callback_rejects_mutable_const_named_target() {
	root := function_value_source_dir('imported_c_struct_const_event_mut_target')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, function_value_capi_sources(), '
module main

import capi

fn on_event(mut const_event capi.Event, user_data voidptr) {
	_ := const_event
	_ := user_data
}

fn make_desc() capi.Desc {
	return capi.Desc{
		event_cb: on_event
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `event_cb`')
}

fn test_non_const_callback_field_rejects_const_target() {
	root := function_value_source_dir('non_const_field_const_target')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, function_value_capi_sources(), '
module main

import capi

fn on_event(const_event &capi.Event, user_data voidptr) {
	_ := const_event.code
	_ := user_data
}

fn make_desc() capi.MutableDesc {
	return capi.MutableDesc{
		event_cb: on_event
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `event_cb`')
}

fn test_non_const_alias_callback_field_rejects_const_target() {
	root := function_value_source_dir('non_const_alias_field_const_target')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, function_value_capi_sources(), '
module main

import capi

fn on_event(const_event &capi.Event, user_data voidptr) {
	_ := const_event.code
	_ := user_data
}

fn make_desc() capi.MutableAliasDesc {
	return capi.MutableAliasDesc{
		event_cb: on_event
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `event_cb`')
}

fn test_imported_c_struct_callback_field_shadowed_selector_is_rejected_before_c() {
	root := function_value_source_dir('imported_c_struct_callback_shadow')
	defer {
		os.rmdir_all(root) or {}
	}
	mut modules := function_value_capi_sources()
	modules['util/util.v'] = '
module util

pub fn handler(user_data voidptr) {
	_ := user_data
}
'
	messages := function_value_errors_from_sources(root, modules, '
module main

import capi
import util

struct Holder {
	handler int
}

fn make_desc() capi.Desc {
	util := Holder{
		handler: 3
	}
	return capi.Desc{
		cb: util.handler
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `cb`')
}

fn test_imported_c_struct_callback_function_variable_is_rejected_before_c() {
	root := function_value_source_dir('imported_c_struct_callback_fn_var')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, function_value_capi_sources(), '
module main

import capi

struct App {
	value int
}

fn frame(app &App) {
	_ := app.value
}

fn make_desc() capi.Desc {
	cb_var := frame
	return capi.Desc{
		cb: cb_var
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `cb`')
}

fn test_imported_c_struct_callback_wrong_arity_is_rejected_before_c() {
	root := function_value_source_dir('imported_c_struct_callback_wrong_arity')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, function_value_capi_sources(), '
module main

import capi

struct App {
	value int
}

fn wrong(app &App, extra int) {
	_ := extra
}

fn make_desc() capi.Desc {
	return capi.Desc{
		cb: wrong
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `cb`')
}

fn test_imported_c_struct_callback_wrong_return_is_rejected_before_c() {
	root := function_value_source_dir('imported_c_struct_callback_wrong_return')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, function_value_capi_sources(), '
module main

import capi

struct App {
	value int
}

fn wrong(app &App) int {
	return app.value
}

fn make_desc() capi.Desc {
	return capi.Desc{
		cb: wrong
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `cb`')
}

fn test_imported_c_struct_callback_non_pointer_is_rejected_before_c() {
	root := function_value_source_dir('imported_c_struct_callback_non_pointer')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, function_value_capi_sources(), '
module main

import capi

fn wrong(app int) {
	_ := app
}

fn make_desc() capi.Desc {
	return capi.Desc{
		cb: wrong
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `cb`')
}

fn test_typed_userdata_callback_function_variable_is_rejected_before_c() {
	root := function_value_source_dir('typed_userdata_fn_var')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, {}, '
struct App {
	value int
}

struct Config {
	cb fn (voidptr)
}

fn frame(app &App) {
	_ := app.value
}

fn make_config() Config {
	cb_var := frame
	return Config{
		cb: cb_var
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `cb`')
}

fn test_typed_userdata_callback_wrong_arity_is_rejected_before_c() {
	root := function_value_source_dir('typed_userdata_wrong_arity')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, {}, '
struct App {
	value int
}

struct Config {
	cb fn (voidptr)
}

fn wrong(app &App, extra int) {
	_ := extra
}

fn make_config() Config {
	return Config{
		cb: wrong
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `cb`')
}

fn test_typed_userdata_callback_wrong_return_is_rejected_before_c() {
	root := function_value_source_dir('typed_userdata_wrong_return')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, {}, '
struct App {
	value int
}

struct Config {
	cb fn (voidptr)
}

fn wrong(app &App) int {
	return app.value
}

fn make_config() Config {
	return Config{
		cb: wrong
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `cb`')
}

fn test_typed_userdata_callback_non_pointer_is_rejected_before_c() {
	root := function_value_source_dir('typed_userdata_non_pointer')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, {}, '
struct Config {
	cb fn (voidptr)
}

fn wrong(app int) {
	_ := app
}

fn make_config() Config {
	return Config{
		cb: wrong
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `cb`')
}

fn test_unknown_function_value_is_rejected_before_c() {
	root := function_value_source_dir('unknown')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, {}, '
struct Config {
	cb fn (int) int
}

fn make_config() Config {
	return Config{
		cb: missing_handler
	}
}
')

	assert function_value_has_error(messages, 'unknown identifier `missing_handler`')
}

fn test_local_shadow_function_value_is_rejected_before_c() {
	root := function_value_source_dir('local_shadow_rejected')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, {}, '
struct Config {
	cb fn (int) int
}

fn make_config() Config {
	handler := 1
	return Config{
		cb: handler
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `cb`')
}

fn test_incompatible_function_value_signature_is_rejected_before_c() {
	root := function_value_source_dir('wrong_signature')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := function_value_errors_from_sources(root, {}, '
struct Config {
	cb fn (int) int
}

fn wrong_handler(s string) int {
	return s.len
}

fn make_config() Config {
	return Config{
		cb: wrong_handler
	}
}
')

	assert function_value_has_error(messages, 'cannot initialize field `cb`')
}
