import os
import time
import v3.flat
import v3.gen.c as cgen
import v3.parser
import v3.pref
import v3.transform
import v3.types

fn source_path(name string) string {
	return os.join_path(os.vtmp_dir(), 'v3_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
}

fn source_dir(name string) string {
	return os.join_path(os.vtmp_dir(), 'v3_${name}_${os.getpid()}_${time.now().unix_micro()}')
}

fn write_source(path string, source string) {
	os.write_file(path, source) or { panic(err) }
}

fn checked_transformed_c_from_source(name string, source string) string {
	src := source_path(name)
	defer {
		os.rm(src) or {}
	}
	write_source(src, source)
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	mut a := p.parse_file(src)
	return checked_transformed_c(mut a, src)
}

fn checked_transformed_c_from_module_sources(root string, module_sources map[string]string, main_source string) string {
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
	return checked_transformed_c(mut a, main_path)
}

fn checked_transformed_c(mut a flat.FlatAst, diagnostic_file string) string {
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

fn checker_errors_from_source(name string, source string) []string {
	src := source_path(name)
	defer {
		os.rm(src) or {}
	}
	write_source(src, source)
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	mut a := p.parse_file(src)
	return checker_errors(mut a, src)
}

fn checker_errors_from_module_sources(root string, module_sources map[string]string, main_source string) []string {
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

fn errors_contain(messages []string, needle string) bool {
	for msg in messages {
		if msg.contains(needle) {
			return true
		}
	}
	return false
}

fn test_fixed_array_literal_bang_uses_c_fixed_storage() {
	code := checked_transformed_c_from_source('fixed_array_literal_bang', '
fn consume(p &u32) {}

fn fixed_hash_shape() u32 {
	mut state := [u32(0x6A09E667), 0xBB67AE85]!
	mut w := [64]u32{}
	consume(&state[0])
	state[1] = w[0]
	return state[1]
}
')

	assert code.contains('u32 state[2] = {(u32)(0x6A09E667), 0xBB67AE85};')
	assert code.contains('u32 w[64] = {0};')
	assert code.contains('consume(&state[0]);')
	assert code.contains('state[1] = w[0];')
	assert !code.contains('Array state =')
	assert !code.contains('array_get(state')
}

fn test_fixed_array_whole_assignment_uses_storage_copy() {
	code := checked_transformed_c_from_source('fixed_array_whole_assignment', '
fn fixed_assign_shape() int {
	mut pair := [1, 2]!
	mut other := [3, 4]!
	pair = [5, 6]!
	other = pair
	pair = pair
	pair = [2]int{}
	return pair[0] + other[1]
}
')

	assert code.contains('int pair[2] = {1, 2};')
	assert code.contains('int other[2] = {3, 4};')
	assert code.contains('memcpy(pair, (int[]){5, 6}, sizeof(pair));')
	assert code.contains('memmove(other, pair, sizeof(other));')
	assert code.contains('memmove(pair, pair, sizeof(pair));')
	assert code.contains('memset(pair, 0, sizeof(pair));')
	assert !code.contains('pair = {')
	assert !code.contains('other = pair;')
	assert !code.contains('memcpy(other, pair')
}

fn test_fixed_array_init_assignment_does_not_zero_init_value() {
	code := checked_transformed_c_from_source('fixed_array_init_assignment', '
fn fixed_init_shape() int {
	mut b := [1, 2, 3]!
	b = [3]int{init: 5}
	return b[0]
}
')

	assert code.contains('int b[3] = {1, 2, 3};')
	assert code.contains('for (int _t')
	assert code.contains(' < 3; ')
	assert code.contains('b[_t')
	assert code.contains('] = 5;')
	assert !code.contains('memset(b, 0, sizeof(b));')
}

fn test_fixed_array_init_declaration_fills_value() {
	code := checked_transformed_c_from_source('fixed_array_init_declaration', '
fn fixed_init_decl_shape() int {
	mut a := [3]int{init: 5}
	mut z := [3]int{}
	return a[0] + z[0]
}
')

	assert code.contains('int a[3];')
	assert code.contains('for (int _t')
	assert code.contains(' < 3; ')
	assert code.contains('a[_t')
	assert code.contains('] = 5;')
	assert code.contains('int z[3] = {0};')
	assert !code.contains('int a[3] = {0};')
}

fn test_multi_return_fixed_array_payload_stays_indexable_storage() {
	code := checked_transformed_c_from_source('multi_return_fixed_array_payload', '
fn metrics() (f32, [4]f32) {
	bounds := [f32(1.0), 2.0, 3.0, 4.0]!
	return 1.5, bounds
}

fn use_metrics() f32 {
	_, bounds := metrics()
	return bounds[3]
}
')

	assert code.contains('float arg1[4];')
	assert code.contains('float bounds[4];')
	assert code.contains('memmove(bounds,')
	assert code.contains('.arg1')
	assert code.contains('sizeof(bounds)')
	assert code.contains('return bounds[3];')
	assert !code.contains('array bounds =')
	assert !code.contains('Array bounds =')
}

fn test_fixed_array_init_index_is_rejected_before_codegen() {
	messages := checker_errors_from_source('fixed_array_init_index_rejected', '
fn fixed_index_init_shape() int {
	mut b := [0, 0, 0]!
	b = [3]int{init: index}
	return b[2]
}
')

	assert messages == ['unknown identifier `index`']
}

fn test_dynamic_array_assignment_stays_dynamic() {
	code := checked_transformed_c_from_source('dynamic_array_assignment_canary', '
fn dynamic_shape() int {
	mut xs := [1, 2]
	xs = [3, 4]
	return xs.len
}
')

	assert code.contains('Array xs')
	assert code.contains('array_new(sizeof(int), 0, 2)')
	assert code.contains('array_push(&')
	assert !code.contains('int xs[2]')
	assert !code.contains('memcpy(xs')
}

fn test_fixed_array_struct_field_propagates_element_type_to_nested_alias_c_struct_literals() {
	root := source_dir('fixed_array_imported_nested_alias_c_struct_literal')
	defer {
		os.rmdir_all(root) or {}
	}
	code := checked_transformed_c_from_module_sources(root, {
		'gfx/gfx.v': '
module gfx

pub struct C.color {
	r f32
	g f32
	b f32
	a f32
}

pub type Color = C.color

pub enum LoadAction {
	dontcare
	load
}

pub struct C.attachment {
	load_action LoadAction
	clear_value Color
}

pub type Attachment = C.attachment

pub struct C.pass_action {
	colors [2]Attachment
}

pub type PassAction = C.pass_action
'
	}, '
module main

import gfx

struct PassAction {
	wrong int = 99
}

struct Attachment {
	wrong int = 88
}

const pass = gfx.PassAction{
	colors: [
		gfx.Attachment{
			load_action: .dontcare
			clear_value: gfx.Color{1.0, 0.0, 0.0, 1.0}
		},
		gfx.Attachment{
			load_action: .load
			clear_value: gfx.Color{0.0, 1.0, 0.0, 1.0}
		},
	]!
}

fn use_pass() {
	_ = pass
}
')

	assert code.contains('.colors = {(struct attachment){')
	assert code.contains('.clear_value = (struct color){1.0, 0.0, 0.0, 1.0}')
	assert !code.contains('array_new(sizeof(struct attachment)')
	assert !code.contains('array_push(&')
	assert !code.contains('.wrong = 99')
	assert !code.contains('.wrong = 88')
	assert !code.contains('.clear_value = gfx__Color')
	assert !code.contains('gfx__Color,')
	assert !code.contains('.clear_value = C__color')
	assert !code.contains('. =')
}

fn test_dynamic_array_of_alias_c_struct_literals_stays_runtime_array() {
	code := checked_transformed_c_from_source('dynamic_array_alias_c_struct_literal', '
struct C.color {
	r f32
	g f32
	b f32
	a f32
}

type Color = C.color

struct C.attachment {
	clear_value Color
}

type Attachment = C.attachment

fn make_attachments() []Attachment {
	return [
		Attachment{
			clear_value: Color{1.0, 0.0, 0.0, 1.0}
		},
	]
}
')

	assert code.contains('Array make_attachments(')
	assert code.contains('.clear_value = (struct color){1.0, 0.0, 0.0, 1.0}')
	assert !code.contains('struct attachment make_attachments')
	assert !code.contains('struct attachment make_attachments[1]')
}

fn test_qualified_empty_and_named_struct_literals_stay_struct_inits() {
	root := source_dir('qualified_empty_named_struct_literal')
	defer {
		os.rmdir_all(root) or {}
	}
	code := checked_transformed_c_from_module_sources(root, {
		'gfx/gfx.v': '
module gfx

pub struct C.color {
	r f32
	g f32
	b f32
	a f32
}

pub type Color = C.color
'
	}, '
module main

import gfx

const empty = gfx.Color{}
const named = gfx.Color{r: 1.0, g: 0.5, b: 0.25, a: 1.0}
')

	assert code.contains('empty = (struct color){}')
	assert code.contains('named = (struct color){.r = 1.0, .g = 0.5, .b = 0.25, .a = 1.0}')
	assert !code.contains('gfx__Color')
}

fn test_import_alias_qualified_struct_literal_uses_canonical_type() {
	root := source_dir('qualified_import_alias_struct_literal')
	defer {
		os.rmdir_all(root) or {}
	}
	code := checked_transformed_c_from_module_sources(root, {
		'gfx/gfx.v': '
module gfx

pub struct C.color {
	r f32
	g f32
	b f32
	a f32
}

pub type Color = C.color
'
	}, '
module main

import gfx as fx

const aliased = fx.Color{1.0, 0.0, 0.0, 1.0}
')

	assert code.contains('aliased = (struct color){1.0, 0.0, 0.0, 1.0}')
	assert !code.contains('fx__Color')
	assert !code.contains('gfx__Color')
}

fn test_c_qualified_struct_literal_remains_valid() {
	code := checked_transformed_c_from_source('c_qualified_struct_literal', '
struct C.color {
	r f32
	g f32
	b f32
	a f32
}

const c_color = C.color{1.0, 0.0, 0.0, 1.0}
')

	assert code.contains('c_color = (struct color){1.0, 0.0, 0.0, 1.0}')
}

fn test_lowercase_or_value_selector_is_not_parsed_as_struct_literal() {
	code := checked_transformed_c_from_source('lowercase_selector_not_struct_literal', '
struct Holder {
	value int
}

fn use_selector() {
	obj := Holder{}
	_ := obj.value{1}
}
')

	assert !code.contains('(value){')
	assert !code.contains('(Holder){1}')
}

fn test_missing_qualified_struct_does_not_bind_local_short_name() {
	messages := checker_errors_from_source('missing_qualified_struct_no_short_fallback', '
struct PassAction {
	wrong int = 99
}

const bad = missing.PassAction{}
')

	assert errors_contain(messages, 'unknown type'), messages.str()
	assert errors_contain(messages, 'missing.PassAction'), messages.str()
}

fn test_shadowed_import_alias_qualified_struct_init_is_rejected() {
	root := source_dir('shadowed_import_alias_struct_init')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := checker_errors_from_module_sources(root, {
		'gfx/gfx.v': '
module gfx

pub struct C.color {
	r f32
	g f32
	b f32
	a f32
}

pub type Color = C.color
'
	}, '
module main

import gfx

fn use_shadowed_alias() {
	gfx := 1
	_ := gfx.Color{}
}
')

	assert errors_contain(messages, 'unknown type'), messages.str()
	assert errors_contain(messages, 'gfx.Color'), messages.str()
}

fn test_named_struct_arg_fixed_array_field_uses_initializer_context() {
	code := checked_transformed_c_from_source('named_struct_arg_fixed_array_field', '
struct Opt {
	values [2]int
}

fn consume(opt Opt) int {
	return opt.values[0]
}

fn use_named_arg() int {
	return consume(values: [1, 2]!)
}
')

	assert code.contains('consume((Opt){.values = {1, 2}})')
	assert !code.contains('.values = (int[]){1, 2}')
}

fn test_fixed_array_expected_type_expression_uses_compound_data_context() {
	code := checked_transformed_c_from_source('fixed_array_expected_expression_context', '
fn consume(values [2]int) int {
	return values[0]
}

fn use_arg() int {
	return consume([1, 2]!)
}
')

	assert code.contains('consume((int[]){1, 2})')
	assert !code.contains('consume({1, 2})')
}
