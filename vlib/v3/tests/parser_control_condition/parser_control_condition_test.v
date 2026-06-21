module parser_control_condition

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

fn checker_errors_from_module_sources(name string, module_sources map[string]string, main_source string) []string {
	root := source_dir(name)
	defer {
		os.rmdir_all(root) or {}
	}
	os.mkdir_all(root) or { panic(err) }
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	for rel_path, source in module_sources {
		path := os.join_path(root, rel_path)
		os.mkdir_all(os.dir(path)) or { panic(err) }
		write_source(path, source)
		p.parse_into(path)
	}
	main_path := os.join_path(root, 'main.v')
	write_source(main_path, main_source)
	mut a := p.parse_file(main_path)
	return checker_errors(mut a, main_path)
}

fn checked_c_from_module_sources(name string, module_sources map[string]string, main_source string) string {
	root := source_dir(name)
	defer {
		os.rmdir_all(root) or {}
	}
	os.mkdir_all(root) or { panic(err) }
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	for rel_path, source in module_sources {
		path := os.join_path(root, rel_path)
		os.mkdir_all(os.dir(path)) or { panic(err) }
		write_source(path, source)
		p.parse_into(path)
	}
	main_path := os.join_path(root, 'main.v')
	write_source(main_path, main_source)
	mut a := p.parse_file(main_path)
	return checked_c(mut a, main_path)
}

fn parsed_ast_from_module_sources(name string, module_sources map[string]string, main_source string) &flat.FlatAst {
	root := source_dir(name)
	defer {
		os.rmdir_all(root) or {}
	}
	os.mkdir_all(root) or { panic(err) }
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	for rel_path, source in module_sources {
		path := os.join_path(root, rel_path)
		os.mkdir_all(os.dir(path)) or { panic(err) }
		write_source(path, source)
		p.parse_into(path)
	}
	main_path := os.join_path(root, 'main.v')
	write_source(main_path, main_source)
	return p.parse_file(main_path)
}

fn checker_errors(mut a flat.FlatAst, diagnostic_file string) []string {
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

fn checked_c(mut a flat.FlatAst, diagnostic_file string) string {
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

fn has_error(messages []string, needle string) bool {
	for msg in messages {
		if msg.contains(needle) {
			return true
		}
	}
	return false
}

fn count_struct_init_value(a &flat.FlatAst, value string) int {
	mut total := 0
	for node in a.nodes {
		if node.kind == .struct_init && node.value == value {
			total++
		}
	}
	return total
}

fn c_selector_fixture(condition string) string {
	return '
module fixture

fn retry_gate(cerror int) {
	${condition} {
		return
	}
}

pub fn exists(code int) bool {
	return code > 0
}
'
}

fn assert_imported_exists_is_known(name string, module_source string) {
	messages := checker_errors_from_module_sources(name, {
		'fixture/fixture.v': module_source
	}, '
module main

import fixture

fn main() {
	_ = fixture.exists(1)
}
')
	assert !has_error(messages, 'unknown function fixture.exists'), messages.str()
}

fn test_if_rhs_c_selector_keeps_later_imported_function_visible() {
	assert_imported_exists_is_known('if_rhs_c_selector', c_selector_fixture('if cerror == C.EINTR'))
}

fn test_if_lhs_c_selector_keeps_later_imported_function_visible() {
	assert_imported_exists_is_known('if_lhs_c_selector', c_selector_fixture('if C.EINTR == cerror'))
}

fn test_if_c_selector_block_with_literal_like_exprs_keeps_later_imported_function_visible() {
	assert_imported_exists_is_known('if_c_selector_literal_like_block', '
module fixture

fn helper() int {
	return 1
}

fn retry_array() {
	if C.EINTR {
		[1].len
	}
}

fn retry_none() {
	if C.EINTR {
		none
	}
}

fn retry_call() {
	if C.EINTR {
		helper()
	}
}

pub fn exists(code int) bool {
	return code > 0
}
')
}

fn test_if_guard_rhs_c_selector_keeps_later_imported_function_visible() {
	assert_imported_exists_is_known('if_guard_rhs_c_selector', '
module fixture

fn retry_gate(cerror int) {
	if ok := cerror == C.EINTR {
		_ = ok
	}
}

pub fn exists(code int) bool {
	return code > 0
}
')
}

fn test_if_comma_guard_rhs_c_selector_keeps_later_imported_function_visible() {
	assert_imported_exists_is_known('if_comma_guard_rhs_c_selector', '
module fixture

fn retry_gate(cerror int) {
	if a, b := cerror == C.EINTR {
		_ = a
		_ = b
	}
}

pub fn exists(code int) bool {
	return code > 0
}
')
}

fn test_condition_only_for_c_selector_keeps_later_imported_function_visible() {
	assert_imported_exists_is_known('for_condition_c_selector', '
module fixture

fn retry_gate(cerror int) {
	for cerror == C.EINTR {
		break
	}
}

pub fn exists(code int) bool {
	return code > 0
}
')
}

fn test_for_in_container_c_selector_keeps_later_imported_function_visible() {
	assert_imported_exists_is_known('for_in_container_c_selector', '
module fixture

fn retry_gate() {
	for item in C.EINTR {
		_ = item
		break
	}
}

pub fn exists(code int) bool {
	return code > 0
}
')
}

fn test_match_subject_c_selector_keeps_later_imported_function_visible() {
	assert_imported_exists_is_known('match_subject_c_selector', '
module fixture

fn retry_gate(cerror int) {
	match cerror == C.EINTR {
		else {
			return
		}
	}
}

pub fn exists(code int) bool {
	return code > 0
}
')
}

fn test_direct_match_c_selector_keeps_later_imported_function_visible() {
	assert_imported_exists_is_known('direct_match_c_selector', '
module fixture

fn retry_gate() {
	match C.EINTR {
		1 {
			return
		}
		else {
			return
		}
	}
}

pub fn exists(code int) bool {
	return code > 0
}
')
}

fn test_c_style_for_post_c_selector_keeps_later_imported_function_visible() {
	assert_imported_exists_is_known('for_post_c_selector', '
module fixture

fn retry_gate() {
	for i := 0; i < 1; C.EINTR {
		break
	}
}

pub fn exists(code int) bool {
	return code > 0
}
')
}

fn test_select_branch_c_selector_keeps_later_imported_function_visible() {
	assert_imported_exists_is_known('select_branch_c_selector', '
module fixture

fn helper() int {
	return 1
}

fn retry_cond() {
	select {
		C.EINTR {
			helper()
		}
	}
}

fn retry_assign() {
	select {
		got := C.EINTR {
			_ = got
		}
	}
}

pub fn exists(code int) bool {
	return code > 0
}
')
}

fn test_match_branch_c_selector_keeps_later_imported_function_visible() {
	assert_imported_exists_is_known('match_branch_c_selector', '
module fixture

fn retry_gate(code int) {
	match code {
		C.EINTR {
			return
		}
		else {
			return
		}
	}
}

pub fn exists(code int) bool {
	return code > 0
}
')
}

fn test_unknown_imported_function_still_errors() {
	messages := checker_errors_from_module_sources('unknown_imported_fn', {
		'fixture/fixture.v': '
module fixture

pub fn exists(code int) bool {
	return code > 0
}
'
	}, '
module main

import fixture

fn main() {
	_ = fixture.missing(1)
}
')
	assert has_error(messages, 'unknown function `fixture.missing`'), messages.str()
}

fn test_c_qualified_struct_literals_in_control_conditions_remain_literals() {
	a := parsed_ast_from_module_sources('c_qualified_literal_conditions', map[string]string{}, '
module main

fn probe() {
	if C.Color{} == C.Color{} {
		return
	}
	if C.Color{ 1 } == C.Color{ 2 } {
		return
	}
}
')
	assert count_struct_init_value(a, 'C.Color') == 4
}

fn test_direct_qualified_struct_literals_in_control_conditions_remain_literals() {
	a := parsed_ast_from_module_sources('direct_qualified_literal_conditions', {
		'gfx/gfx.v': '
module gfx

pub struct Color {
pub mut:
	r int
}
'
	}, '
module main

	import gfx

fn make_r() int {
	return 1
}

struct Holder {
	r int
}

fn probe(color gfx.Color) {
	ok := true
	other := Holder{ r: 3 }
	if gfx.Color{} == color {
		return
	}
	if color == gfx.Color{ r: 1 } {
		return
	}
	if color == gfx.Color{} {
		return
	}
	if color == gfx.Color{} && ok {
		return
	}
	if color == gfx.Color{ make_r() } {
		return
	}
	if color == gfx.Color{ other.r } {
		return
	}
	for color == gfx.Color{ r: 2 } {
		break
	}
}
')
	assert count_struct_init_value(a, 'gfx.Color') == 7
}

fn test_qualified_struct_literal_in_if_call_argument_still_codegen() {
	code := checked_c_from_module_sources('qualified_literal_call_arg', {
		'gfx/gfx.v': '
module gfx

pub struct Color {
pub mut:
	r int
}

pub fn accepts(c Color) bool {
	return c.r == 1
}
'
	}, '
module main

import gfx

fn probe() int {
	if gfx.accepts(gfx.Color{ r: 1 }) {
		return 1
	}
	return 0
}
')
	assert code.contains('gfx__Color')
	assert code.contains('.r = 1')
}
