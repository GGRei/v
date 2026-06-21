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

fn checked_transformed_c_from_module_sources(root string, module_sources map[string]string, main_source string) string {
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
	tc.diagnose_unknown_calls = true
	tc.diagnostic_files[main_path] = true
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

fn checked_transformed_c_from_source_with_decl_type(name string, source string, lhs_name string, decl_type string) string {
	src := source_path(name)
	defer {
		os.rm(src) or {}
	}
	os.write_file(src, source) or { panic(err) }
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	mut a := p.parse_file(src)
	mark_decl_type(mut a, lhs_name, decl_type)
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

fn mark_decl_type(mut a flat.FlatAst, lhs_name string, decl_type string) {
	for i, node in a.nodes {
		if node.kind != .decl_assign || node.children_count < 2 {
			continue
		}
		lhs := a.child_node(&node, 0)
		if lhs.kind == .ident && lhs.value == lhs_name {
			a.nodes[i].typ = decl_type
			return
		}
	}
	panic('missing declaration for ${lhs_name}')
}

fn checker_errors_from_source(name string, source string) []string {
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
	return messages
}

fn checker_errors_from_module_sources(root string, module_sources map[string]string, main_source string) []string {
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
	tc.diagnose_unknown_calls = true
	tc.diagnostic_files[main_path] = true
	tc.check_semantics()
	mut messages := []string{}
	for err in tc.errors {
		messages << err.msg
	}
	return messages
}

fn option_local_assigned_from_call(code string, opt_type string, call string) string {
	suffix := ' = ${call};'
	for raw_line in code.split('\n') {
		line := raw_line.trim_space()
		if line.starts_with('${opt_type} ') && line.ends_with(suffix) {
			return line[opt_type.len + 1..line.len - suffix.len]
		}
	}
	return ''
}

fn local_assigned_from_optional_value(code string, opt_tmp string) string {
	suffix := ' = ${opt_tmp}.value;'
	for raw_line in code.split('\n') {
		mut line := raw_line.trim_space()
		if line.starts_with('int ') {
			line = line[4..]
		}
		if line.ends_with(suffix) {
			return line[..line.len - suffix.len]
		}
	}
	return ''
}

fn test_option_if_guard_map_key_uses_unwrapped_value_type() {
	code := checked_transformed_c_from_source('option_if_guard_map_key', '
fn maybe_name(flag bool) ?string {
	if flag {
		return "ok"
	}
	return none
}

fn lookup(flag bool, values map[string]int) int {
	if fname := maybe_name(flag) {
		return values[fname] or { 0 }
	}
	return 0
}
')

	assert code.contains('string fname =')
	assert !code.contains('Optional_string __map_key')
}

fn test_primitive_optional_if_guard_uses_payload_optional_type() {
	code := checked_transformed_c_from_source('primitive_optional_if_guard', '
fn maybe_int(flag bool) ?int {
	if flag {
		return 7
	}
	return none
}

fn use_int(flag bool) int {
	if value := maybe_int(flag) {
		return value
	}
	return 0
}
')

	assert code.contains('typedef struct { bool ok; int value; } Optional_int;')
	assert code.contains('Optional_int maybe_int(')
	assert code.contains('Optional_int __if_guard_')
	assert !code.contains('Optional __if_guard_')
}

fn test_enum_optional_if_guard_uses_payload_optional_type() {
	code := checked_transformed_c_from_source('enum_optional_if_guard', '
enum Color {
	red
	blue
}

fn maybe_color(flag bool) ?Color {
	if flag {
		return Color.blue
	}
	return none
}

fn use_color(flag bool) int {
	if color := maybe_color(flag) {
		return 1
	}
	return 0
}
')

	assert code.contains('typedef struct { bool ok; int value; } Optional_int;')
	assert code.contains('Optional_int maybe_color(')
	assert code.contains('Optional_int __if_guard_')
	assert !code.contains('Optional __if_guard_')
}

fn test_void_optional_keeps_payloadless_optional_type() {
	code := checked_transformed_c_from_source('void_optional_boundary', '
fn maybe_void() ?void {
	return none
}
')

	assert code.contains('Optional maybe_void(')
	assert !code.contains('Optional_void')
}

fn test_result_struct_return_wraps_payload_struct_literal_not_optional() {
	code := checked_transformed_c_from_source('result_struct_return_payload', '
struct Payload {
	left int
	right int
}

fn named_payload() !Payload {
	return Payload{
		left: 1
		right: 2
	}
}

fn positional_payload() !Payload {
	return Payload{3, 4}
}
')

	assert code.contains('return (Optional_Payload){.ok = true, .value = (Payload){.left = 1, .right = 2}};')
	assert code.contains('return (Optional_Payload){.ok = true, .value = (Payload){3, 4}};')
	assert !code.contains('.value = (Optional){.left = 1')
	assert !code.contains('.value = (Optional){3, 4}')
}

fn test_result_identity_return_forwards_same_abi_directly() {
	code := checked_transformed_c_from_source('result_identity_return', '
fn inner_result() !int {
	return 7
}

fn outer_result() !int {
	return inner_result()
}
')

	assert code.contains('return inner_result();')
	assert !code.contains('.value = inner_result()')
}

fn test_option_identity_return_forwards_same_abi_directly() {
	code := checked_transformed_c_from_source('option_identity_return', '
fn inner_option(flag bool) ?int {
	if flag {
		return 7
	}
	return none
}

fn outer_option(flag bool) ?int {
	return inner_option(flag)
}

fn outer_option_local(flag bool) ?int {
	value := inner_option(flag)
	return value
}
')

	assert code.contains('return inner_option(flag);')
	assert code.contains('return value;')
	assert !code.contains('.value = inner_option(flag)')
	assert !code.contains('.value = value')
}

fn test_option_result_payload_return_still_wraps_value() {
	code := checked_transformed_c_from_source('option_result_payload_return', '
fn payload_result() !int {
	return 9
}

fn payload_option() ?int {
	return 11
}
')

	assert code.contains('return (Optional_int){.ok = true, .value = 9};')
	assert code.contains('return (Optional_int){.ok = true, .value = 11};')
}

fn test_local_receiver_option_result_return_forwards_same_abi_directly() {
	code := checked_transformed_c_from_source('local_receiver_option_identity_return', '
struct Box {}

fn (mut b Box) next() ?int {
	return 1
}

fn (mut b Box) value() int {
	return 2
}

fn forward_next(mut b Box) ?int {
	return b.next()
}

fn wrap_value(mut b Box) ?int {
	return b.value()
}
')

	assert code.contains('return Box__next(')
	assert !code.contains('.value = Box__next(')
	assert code.contains('return (Optional_int){.ok = true, .value = Box__value(')
}

fn test_member_selector_does_not_use_short_global_option_type() {
	code := checked_transformed_c_from_source('member_selector_global_shadow_option_return', '
struct Local {
	same_name int
}

__global same_name ?int

fn use_member(local_value Local) ?int {
	return local_value.same_name
}
')

	assert code.contains('return (Optional_int){.ok = true, .value = local_value.same_name};')
	assert !code.contains('return local_value.same_name;')
}

fn test_global_receiver_method_option_result_return_forwards_same_abi_directly() {
	code := checked_transformed_c_from_source('global_receiver_option_identity_return', '
struct PRNG {}

__global default_rng &PRNG

fn (mut rng PRNG) u32n(max u32) !u32 {
	return max
}

fn u32n(max u32) !u32 {
	return default_rng.u32n(max)
}
')

	assert code.contains('return PRNG__u32n(')
	assert !code.contains('.value = PRNG__u32n(')
}

fn test_module_global_receiver_method_uses_exact_resolved_return_type() {
	root := source_dir('module_global_receiver_option_identity_return')
	defer {
		os.rmdir_all(root) or {}
	}
	code := checked_transformed_c_from_module_sources(root, {
		'rng/rng.v': '
module rng

pub struct PRNG {}

__global pub default_rng &PRNG

pub fn (mut rng PRNG) maybe(max int) ?int {
	return max
}

pub fn maybe(max int) ?int {
	return default_rng.maybe(max)
}
'
	}, '
module main

import rng

struct PRNG {}

fn (mut rng PRNG) maybe(max int) ?int {
	return none
}

fn use_rng() ?int {
	return rng.maybe(4)
}

fn use_rng_global() ?int {
	return rng.default_rng.maybe(5)
}
')

	assert code.contains('return rng__PRNG__maybe(')
	assert !code.contains('.value = rng__PRNG__maybe(')
	assert !code.contains('return PRNG__maybe(')
	assert code.contains('return rng__maybe(4);')
	assert !code.contains('.value = rng__maybe(4)')
	assert code.contains('rng__default_rng')
	assert code.contains('return rng__PRNG__maybe(rng__default_rng')
		|| code.contains('return rng__PRNG__maybe(&rng__default_rng')
	assert !code.contains('rng__default_rng__maybe')
}

fn test_import_alias_shadowing_does_not_select_module_receiver() {
	root := source_dir('import_alias_shadow_receiver_option_identity_return')
	defer {
		os.rmdir_all(root) or {}
	}
	code := checked_transformed_c_from_module_sources(root, {
		'rng/rng.v': '
module rng

pub struct PRNG {}

__global pub default_rng &PRNG

pub fn (mut rng PRNG) maybe(max int) ?int {
	return max
}
'
	}, '
module main

import rng

struct Local {}

fn (local Local) maybe(max int) ?int {
	return max
}

fn use_shadow() ?int {
	rng := Local{}
	return rng.maybe(6)
}
')

	assert code.contains('return Local__maybe(') || code.contains('return main__Local__maybe(')
	assert !code.contains('rng__maybe(')
	assert !code.contains('return rng__PRNG__maybe(')
}

fn test_import_like_base_without_checker_fact_is_rejected_before_codegen() {
	root := source_dir('import_like_base_without_resolved_call_fact')
	defer {
		os.rmdir_all(root) or {}
	}
	messages := checker_errors_from_module_sources(root, {
		'rng/rng.v': '
module rng

pub fn maybe(max int) ?int {
	return max
}
'
	}, '
module main

import rng

struct Local {}

fn bad_shadowed_selector() {
	rng := Local{}
	_ := rng.missing(1)
}
')

	assert messages.len > 0
	mut unknown_errors := 0
	for msg in messages {
		if msg.contains('unknown function `rng.missing`') {
			unknown_errors++
		}
	}
	assert unknown_errors > 0
}

fn test_imported_alias_constructor_uses_checker_authority() {
	root := source_dir('imported_alias_constructor')
	defer {
		os.rmdir_all(root) or {}
	}
	code := checked_transformed_c_from_module_sources(root, {
		'flat/flat.v': '
module flat

pub type NodeId = int
'
	}, '
module main

import flat

fn missing_node() flat.NodeId {
	return flat.NodeId(-1)
}
')

	assert code.contains('return (int)(-1);')
	assert !code.contains('unknown__NodeId')
	assert !code.contains('flat__NodeId(')
}

fn test_imported_sumtype_constructor_uses_checker_authority() {
	root := source_dir('imported_sumtype_constructor')
	defer {
		os.rmdir_all(root) or {}
	}
	code := checked_transformed_c_from_module_sources(root, {
		'types/types.v': '
module types

pub struct IntType {}

pub struct StringType {}

pub type Type = IntType | StringType

pub fn int_type() IntType {
	return IntType{}
}
'
	}, '
module main

import types

fn wrap_type() types.Type {
	return types.Type(types.int_type())
}
')

	assert code.contains('return (types__Type){.typ =')
	assert !code.contains('unknown__Type')
	assert !code.contains('types__Type(types')
}

fn test_mismatched_option_result_return_rejected_before_codegen() {
	messages := checker_errors_from_source('mismatched_option_result_return', '
fn maybe_int() ?int {
	return 1
}

fn result_int() !int {
	return 2
}

fn bad_result_from_option() !int {
	return maybe_int()
}

fn bad_option_from_result() ?int {
	return result_int()
}
')

	assert messages.len > 0
	mut return_errors := 0
	for msg in messages {
		if msg.contains('cannot return') {
			return_errors++
		}
	}
	assert return_errors >= 2
}

fn test_receiver_method_option_result_mismatch_rejected_before_codegen() {
	messages := checker_errors_from_source('receiver_method_mismatched_option_result_return', '
struct Box {}

fn (b Box) result_value() !int {
	return 1
}

fn (b Box) option_value() ?int {
	return 2
}

fn bad_option_from_result(b Box) ?int {
	return b.result_value()
}

fn bad_result_from_option(b Box) !int {
	return b.option_value()
}
')

	assert messages.len > 0
	mut return_errors := 0
	for msg in messages {
		if msg.contains('cannot return') {
			return_errors++
		}
	}
	assert return_errors >= 2
}

fn test_or_block_lowering_still_unwraps_value_type() {
	code := checked_transformed_c_from_source('option_or_block_identity_return_canary', '
fn maybe_int(flag bool) ?int {
	if flag {
		return 7
	}
	return none
}

fn use_or(flag bool) int {
	value := maybe_int(flag) or {
		return 0
	}
	return value
}
')

	opt_tmp := option_local_assigned_from_call(code, 'Optional_int', 'maybe_int(flag)')
	assert opt_tmp.len > 0
	value_tmp := local_assigned_from_optional_value(code, opt_tmp)
	assert value_tmp.len > 0
	assert code.contains('int value;')
	assert code.contains('if (${opt_tmp}.ok) {')
	assert code.contains('value = ${value_tmp};')
	assert code.contains('return 0;')
	assert code.contains('return value;')
}

fn test_struct_optional_field_typedef_is_emitted_before_field_use() {
	code := checked_transformed_c_from_source('struct_optional_field_order', '
struct Payload {
	value int
}

struct Holder {
	maybe ?Payload
}

fn make_holder() Holder {
	return Holder{
		maybe: none
	}
}
')

	payload_pos := code.index('struct Payload {') or { -1 }
	typedef_pos := code.index('typedef struct { bool ok; Payload value; } Optional_Payload;') or {
		-1
	}
	holder_pos := code.index('struct Holder {') or { -1 }
	assert payload_pos >= 0
	assert typedef_pos > payload_pos
	assert holder_pos > typedef_pos
	assert code.contains('Optional_Payload maybe;')
	assert code.contains('.maybe = (Optional_Payload){.ok = false}')
}

fn test_map_or_array_append_is_lowered_with_value_types() {
	code := checked_transformed_c_from_source('map_or_array_append', '
fn add_suffix_candidate(mut suffix_map map[string][]string, short string, name string) {
	mut candidates := suffix_map[short] or { []string{} }
	candidates << name
	suffix_map[short] = candidates
}
')

	assert code.contains('Array candidates =')
	assert code.contains('array_push(&candidates')
	assert !code.contains('candidates << name;')
	assert !code.contains('map __map_val')
}

fn test_sumtype_optional_decl_uses_value_type_after_or() {
	code := checked_transformed_c_from_source('sumtype_optional_decl', '
struct StructType {
	name string
}

struct OptionType {
	base_type Type
}

struct FnType {
	return_type Type
}

type Type = StructType | OptionType | FnType

fn type_name(typ Type) ?string {
	if typ is StructType {
		return typ.name
	}
	return none
}

fn inspect_type(typ Type) string {
	name := type_name(typ) or { "" }
	if typ is OptionType {
		base := type_name(typ.base_type) or { "" }
		return base
	}
	if typ is FnType {
		ret := type_name(typ.return_type) or { "" }
		return ret
	}
	return name
}
')

	assert code.contains('string name =')
	assert code.contains('string base =')
	assert code.contains('string ret =')
	assert !code.contains('?type_name')
	assert !code.contains('Optional_string name =')
	assert !code.contains('Optional_string base =')
	assert !code.contains('Optional_string ret =')
}

fn test_explicit_sumtype_or_decl_preserves_declared_sumtype() {
	code := checked_transformed_c_from_source_with_decl_type('explicit_sumtype_or_decl', '
struct Left {
	n int
}

struct Right {
	s string
}

type Value = Left | Right

fn maybe_left(flag bool) ?Left {
	if flag {
		return Left{
			n: 1
		}
	}
	return none
}

fn force_sumtype(flag bool) int {
	value := maybe_left(flag) or {
		Right{
			s: "fallback"
		}
	}
	if value is Right {
		return value.s.len
	}
	if value is Left {
		return value.n
	}
	return 0
}
',
		'value', 'Value')

	assert code.contains('Value value =')
	assert code.contains('Value __or_val_')
	assert !code.contains('Left __or_val_')
	assert !code.contains('Right __or_val_')
	assert !code.contains('Left value = __or_val_')
	assert !code.contains('Right value = __or_val_')
}
