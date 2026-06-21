import os
import time
import v3.flat
import v3.gen.c as cgen
import v3.parser
import v3.pref
import v3.transform
import v3.types

fn const_codegen_source_path(name string) string {
	return os.join_path(os.vtmp_dir(),
		'v3_const_codegen_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
}

fn const_codegen_source_dir(name string) string {
	return os.join_path(os.vtmp_dir(),
		'v3_const_codegen_${name}_${os.getpid()}_${time.now().unix_micro()}')
}

fn write_const_codegen_source(path string, source string) {
	os.write_file(path, source) or { panic(err) }
}

fn checked_const_codegen_c_from_source(name string, source string) string {
	src := const_codegen_source_path(name)
	defer {
		os.rm(src) or {}
	}
	write_const_codegen_source(src, source)
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	mut a := p.parse_file(src)
	return checked_const_codegen_c(mut a, src)
}

fn checked_const_codegen_c_from_module_sources(root string, module_sources map[string]string, main_source string) string {
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	for rel_path, source in module_sources {
		path := os.join_path(root, rel_path)
		os.mkdir_all(os.dir(path)) or { panic(err) }
		write_const_codegen_source(path, source)
		p.parse_into(path)
	}
	main_path := os.join_path(root, 'main.v')
	write_const_codegen_source(main_path, main_source)
	mut a := p.parse_file(main_path)
	return checked_const_codegen_c(mut a, main_path)
}

fn checked_const_codegen_c(mut a flat.FlatAst, diagnostic_file string) string {
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

fn test_main_const_c_symbol_does_not_corrupt_struct_field_access() {
	code := checked_const_codegen_c_from_source('field_collision', '
const block_size = 20
const field_width = 10
const win_width = block_size * field_width

struct Game {
mut:
	block_size int = block_size
}

fn new_game() &Game {
	mut game := &Game{
		block_size: block_size
	}
	game.block_size = block_size
	return game
}

fn width() int {
	return win_width
}
')

	assert !code.contains('#define block_size')
	assert code.contains('#define main__block_size (20)')
	assert code.contains('#define main__field_width (10)')
	assert code.contains('#define main__win_width ((main__block_size) * (main__field_width))')
	block_pos := code.index('#define main__block_size (20)') or { -1 }
	field_pos := code.index('#define main__field_width (10)') or { -1 }
	win_pos := code.index('#define main__win_width ((main__block_size) * (main__field_width))') or {
		-1
	}
	assert block_pos >= 0
	assert field_pos >= 0
	assert win_pos > block_pos
	assert win_pos > field_pos
	assert code.contains('.block_size = main__block_size')
	assert code.contains('game->block_size = main__block_size')
	assert !code.contains('.main__block_size')
	assert !code.contains('->main__block_size')
}

fn test_fixed_array_const_length_uses_canonical_const_symbol() {
	code := checked_const_codegen_c_from_source('fixed_array_len', '
const buf_len = 4

fn use_buf() int {
	mut buf := [buf_len]int{}
	return buf[0]
}
')

	assert code.contains('#define main__buf_len (4)')
	assert code.contains('[main__buf_len]')
	assert !code.contains('[buf_len]')
}

fn test_early_const_precedes_struct_fixed_array_field() {
	code := checked_const_codegen_c_from_source('struct_fixed_array_len', '
const field_len = 3

struct Holder {
	items [field_len]int
}

fn make_holder() Holder {
	return Holder{}
}
')

	macro_pos := code.index('#define main__field_len (3)') or { -1 }
	struct_pos := code.index('struct Holder {') or { -1 }
	assert macro_pos >= 0
	assert struct_pos > macro_pos
	assert code.contains('int items[main__field_len];')
}

fn test_early_const_precedes_global_fixed_array_decl() {
	code := checked_const_codegen_c_from_source('global_fixed_array_len', '
const global_len = 5

__global global_items = [global_len]int{}

fn read_global() int {
	return global_items[0]
}
')

	macro_pos := code.index('#define main__global_len (5)') or { -1 }
	global_pos := code.index('int global_items[main__global_len];') or { -1 }
	assert macro_pos >= 0
	assert global_pos > macro_pos
}

fn test_sizeof_int_const_can_emit_early_before_struct_field() {
	code := checked_const_codegen_c_from_source('sizeof_int_early', '
const int_size = sizeof(int)

struct Holder {
	data [int_size]u8
}

fn make_holder() Holder {
	return Holder{}
}
')

	macro_pos := code.index('#define main__int_size (sizeof(int))') or { -1 }
	struct_pos := code.index('struct Holder {') or { -1 }
	assert macro_pos >= 0
	assert struct_pos > macro_pos
	assert code.contains('u8 data[main__int_size];')
}

fn test_sizeof_struct_const_is_not_emitted_early_before_structs() {
	code := checked_const_codegen_c_from_source('sizeof_struct_late', '
struct Payload {
	value int
}

const payload_size = sizeof(Payload)

struct Holder {
	data [payload_size]u8
}

fn make_holder() Holder {
	return Holder{}
}
')

	payload_pos := code.index('struct Payload {') or { -1 }
	holder_pos := code.index('struct Holder {') or { -1 }
	macro_pos := code.index('#define main__payload_size') or { -1 }
	assert payload_pos >= 0
	assert holder_pos > payload_pos
	assert code.contains('u8 data[sizeof(Payload)];')
	if macro_pos >= 0 {
		assert macro_pos > holder_pos
	}
}

fn test_sizeof_struct_len_dependency_orders_payload_before_holder() {
	code := checked_const_codegen_c_from_source('sizeof_struct_dependency_order', '
const payload_size = sizeof(Payload)

struct Holder {
	data [payload_size]u8
}

struct Payload {
	value int
}

fn make_holder() Holder {
	return Holder{}
}
')

	payload_pos := code.index('struct Payload {') or { -1 }
	holder_pos := code.index('struct Holder {') or { -1 }
	macro_pos := code.index('#define main__payload_size') or { -1 }
	assert payload_pos >= 0
	assert holder_pos > payload_pos
	assert code.contains('u8 data[sizeof(Payload)];')
	if macro_pos >= 0 {
		assert macro_pos > holder_pos
	}
}

fn test_module_sizeof_struct_len_dependency_orders_payload_before_holder() {
	root := const_codegen_source_dir('module_sizeof_struct_dependency_order')
	defer {
		os.rmdir_all(root) or {}
	}
	code := checked_const_codegen_c_from_module_sources(root, {
		'alpha/alpha.v': '
module alpha

const payload_size = sizeof(Payload)

pub struct Holder {
	data [payload_size]u8
}

pub struct Payload {
	value int
}
'
	}, '
module main

import alpha

fn make_holder() alpha.Holder {
	return alpha.Holder{}
}
')

	payload_pos := code.index('struct alpha__Payload {') or { -1 }
	holder_pos := code.index('struct alpha__Holder {') or { -1 }
	macro_pos := code.index('#define alpha__payload_size') or { -1 }
	assert payload_pos >= 0
	assert holder_pos > payload_pos
	assert code.contains('u8 data[sizeof(alpha__Payload)];')
	assert !code.contains('u8 data[sizeof(Payload)];')
	if macro_pos >= 0 {
		assert macro_pos > holder_pos
	}
}

fn test_module_qualified_const_fixed_array_length_uses_canonical_symbol() {
	root := const_codegen_source_dir('module_fixed_array_len')
	defer {
		os.rmdir_all(root) or {}
	}
	code := checked_const_codegen_c_from_module_sources(root, {
		'alpha/alpha.v': '
module alpha

pub const (
	item_count = 3
)
'
	}, '
module main

import alpha

fn use_alpha_len() int {
	mut values := [alpha.item_count]int{}
	return values[0]
}
')

	assert code.contains('#define alpha__item_count (3)')
	assert code.contains('[alpha__item_count]')
	assert !code.contains('[alpha.item_count]')
}

fn test_cross_module_same_short_const_refs_are_qualified() {
	root := const_codegen_source_dir('same_short_const')
	defer {
		os.rmdir_all(root) or {}
	}
	code := checked_const_codegen_c_from_module_sources(root, {
		'alpha/alpha.v': '
module alpha

pub const (
	same_size = 11
)

pub fn value() int {
	return same_size
}
'
		'beta/beta.v':   '
module beta

pub const (
	same_size = 22
)

pub fn value() int {
	return same_size
}
'
	}, '
module main

import alpha
import beta

fn use_consts() int {
	return alpha.same_size + beta.same_size + alpha.value() + beta.value()
}
')

	assert code.contains('#define alpha__same_size (11)')
	assert code.contains('#define beta__same_size (22)')
	assert !code.contains('#define same_size')
	assert code.contains('alpha__same_size')
	assert code.contains('beta__same_size')
}

fn test_local_shadowing_import_keeps_selector_member_access() {
	root := const_codegen_source_dir('shadowing_import_const')
	defer {
		os.rmdir_all(root) or {}
	}
	code := checked_const_codegen_c_from_module_sources(root, {
		'alpha/alpha.v': '
module alpha

pub const (
	same_size = 11
)
'
	}, '
module main

import alpha

struct Box {
	same_size int
}

fn module_const_ref() int {
	return alpha.same_size
}

fn local_shadow_member_ref() int {
	alpha := Box{
		same_size: 1
	}
	return alpha.same_size
}
')

	assert code.contains('#define alpha__same_size (11)')
	assert code.contains('return alpha__same_size;')
	assert code.contains('return alpha.same_size;')
}

fn test_local_and_field_can_share_const_name_without_macro_corruption() {
	code := checked_const_codegen_c_from_source('local_field_collision', '
const size = 3

struct Box {
mut:
	size int = size
}

fn use_local() int {
	mut box := Box{
		size: size
	}
	size := 9
	box.size = size
	return box.size
}
')

	assert !code.contains('#define size')
	assert code.contains('#define main__size (3)')
	assert code.contains('.size = main__size')
	assert code.contains('box.size = size')
	assert !code.contains('.main__size')
	assert !code.contains('box.main__size')
}

fn test_builtin_min_max_int_aliases_use_canonical_symbols() {
	code := checked_const_codegen_c_from_source('builtin_aliases', '
fn noop() {}
')

	assert code.contains('#define builtin__max_int builtin__max_i32')
	assert code.contains('#define builtin__min_int builtin__min_i32')
	assert !code.contains('#define max_int')
	assert !code.contains('#define min_int')
}

fn test_no_bare_min_max_macros_corrupt_fields_or_params() {
	code := checked_const_codegen_c_from_source('min_max_field_collision', '
struct Limits {
mut:
	max_int int
	min_int int
}

fn use_limits(max_int int) int {
	mut limits := Limits{
		max_int: 1
		min_int: 2
	}
	limits.max_int = max_int
	mut p := &limits
	p.min_int = limits.max_int
	return p.min_int
}
')

	assert !code.contains('#define max_int')
	assert !code.contains('#define min_int')
	assert code.contains('.max_int = 1')
	assert code.contains('.min_int = 2')
	assert code.contains('limits.max_int = max_int;')
	assert code.contains('p->min_int = limits.max_int;')
	assert code.contains('return p->min_int;')
	assert !code.contains('.builtin__max_int')
	assert !code.contains('->builtin__min_int')
}

fn test_const_backend_avoids_map_keys_suffix_scan() {
	source := os.read_file(os.join_path(os.dir(@FILE), '..', 'cleanc.v')) or { panic(err) }

	assert !source.contains('const_vals.keys()')
	assert !source.contains('for const_name in g.const_vals.keys()')
}
