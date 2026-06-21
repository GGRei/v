module markused

import os
import time
import v3.parser
import v3.pref
import v3.types

fn used_for_source(name string, source string) map[string]bool {
	src := os.join_path(os.vtmp_dir(),
		'v3_markused_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
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
	return mark_used(a, &tc)
}

fn used_for_module_sources(name string, module_sources map[string]string, main_source string, check_semantics bool) map[string]bool {
	root := os.join_path(os.vtmp_dir(),
		'v3_markused_${name}_${os.getpid()}_${time.now().unix_micro()}')
	defer {
		os.rmdir_all(root) or {}
	}
	os.mkdir_all(root) or { panic(err) }
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	for rel_path, source in module_sources {
		path := os.join_path(root, rel_path)
		os.mkdir_all(os.dir(path)) or { panic(err) }
		os.write_file(path, source) or { panic(err) }
		p.parse_into(path)
	}
	main_path := os.join_path(root, 'main.v')
	os.write_file(main_path, main_source) or { panic(err) }
	mut a := p.parse_file(main_path)
	mut tc := types.TypeChecker.new(a)
	tc.collect(a)
	tc.annotate_types()
	if check_semantics {
		tc.diagnose_unknown_calls = true
		tc.diagnostic_files[main_path] = true
		tc.check_semantics()
		mut messages := []string{}
		for err in tc.errors {
			messages << err.msg
		}
		assert messages.len == 0, messages.str()
	}
	return mark_used(a, &tc)
}

fn test_option_result_helpers_do_not_root_error_constructors() {
	used := used_for_source('option_helpers', '
fn maybe(flag bool) ?int {
	if flag {
		return 1
	}
	return none
}

fn main() {}
')

	assert used['IError.str']
	assert !used['error']
	assert !used['error_with_code']
}

fn test_reachable_error_constructors_are_marked_by_call_graph() {
	used := used_for_source('reachable_error_constructors', '
fn error(message string) int {
	return message.len
}

fn error_with_code(message string, code int) int {
	return message.len + code
}

fn make_error() int {
	return error("bad")
}

fn make_error_with_code() int {
	return error_with_code("bad", 7)
}

fn main() {
	_ := make_error()
	_ := make_error_with_code()
}
')

	assert used['make_error']
	assert used['make_error_with_code']
	assert used['error']
	assert used['error_with_code']
}

fn test_synthetic_c_lowered_root_traverses_canonical_function_body() {
	used := used_for_module_sources('synthetic_c_lowered_root', {
		'dep/dep.v': '
module dep

pub fn inner() int {
	return 1
}

pub fn outer() int {
	return inner()
}
'
	}, '
module main

fn main() {
	_ := dep__outer()
}
', false)

	assert used['dep__outer']
	assert used['dep.outer']
	assert used['dep.inner']
}

fn test_chained_selector_receiver_call_roots_inner_and_outer_methods() {
	used := used_for_module_sources('chained_selector_receiver_call', {}, '
module main

struct Builder {
	step_sw StopWatch
}

struct StopWatch {}

struct Duration {}

fn duration_helper() i64 {
	return 1
}

fn (sw StopWatch) elapsed() Duration {
	return Duration{}
}

fn (d Duration) microseconds() i64 {
	return duration_helper()
}

fn outer(b Builder) i64 {
	return b.step_sw.elapsed().microseconds()
}

fn main() {
	_ := outer(Builder{})
}
', true)

	assert used['outer']
	assert used['StopWatch.elapsed']
	assert used['Duration.microseconds']
	assert used['duration_helper']
}

fn test_function_value_call_does_not_suffix_root_unrelated_homonym() {
	used := used_for_module_sources('function_value_no_suffix_homonym', {
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
	}, '
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
', true)

	assert used['dep.maybe_value']
	assert used['dep.unique_dep']
	assert used['dep.path']
	assert !used['other.f']
	assert !used['other__f']
	assert !used['other.other_only_dep']
	assert !used['other__other_only_dep']
}
