import os
import time
import v3.gen.c as cgen
import v3.parser
import v3.pref
import v3.types

fn source_path(name string) string {
	return os.join_path(os.vtmp_dir(), 'v3_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
}

fn check_source_errors(name string, source string) []string {
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

fn checked_gen_c_from_source(name string, source string) string {
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
	assert tc.errors.len == 0, messages.str()
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

fn assert_has_error(name string, source string, needle string) {
	messages := check_source_errors(name, source)
	assert messages.len > 0, messages.str()
	assert has_error(messages, needle), messages.str()
}

fn test_params_struct_arg_can_be_omitted_for_plain_and_method_calls() {
	code := checked_gen_c_from_source('params_struct_omitted_arg', '
@[params]
struct Opt {
	enabled bool = true
}

struct Context {}

fn make_opt(opt Opt) int {
	return 1
}

fn (ctx Context) end(opt Opt) {}

fn use_params() {
	_ := make_opt()
	ctx := Context{}
	ctx.end()
}
')

	assert code.contains('make_opt((Opt){')
	assert code.contains('Context__end(ctx, (Opt){')
	assert code.contains('.enabled = true')
}

fn test_params_struct_omission_is_rejected_for_plain_struct() {
	assert_has_error('params_omission_non_params', '
struct Opt {}

fn make_opt(opt Opt) {}

fn use_params() {
	make_opt()
}
',
		'argument count mismatch')
}

fn test_named_args_are_allowed_for_plain_trailing_struct() {
	code := checked_gen_c_from_source('named_args_plain_struct', '
struct Opt {
	enabled bool
	count int
}

fn make_opt(opt Opt) int {
	return opt.count
}

fn use_params() {
	_ := make_opt(enabled: true, count: 3)
}
')

	assert code.contains('make_opt((Opt){.enabled = true, .count = 3')
}

fn test_plain_trailing_struct_named_args_use_field_value_context() {
	code := checked_gen_c_from_source('named_args_plain_struct_context', '
enum Color {
	red
	blue
}

struct Opt {
	color Color
	maybe ?int
	values []int
}

fn make_opt(opt Opt) {}

fn use_params() {
	make_opt(color: .blue, maybe: none, values: [])
}
')

	assert code.contains('.color = 1')
	assert code.contains('typedef struct { bool ok; int value; } Optional_int;')
	assert code.contains('Optional_int maybe;')
	assert code.contains('.maybe = (Optional_int){.ok = false}')
	assert code.contains('.values = array_new(sizeof(int), 0, 0)')
}

fn test_method_named_args_are_allowed_for_plain_trailing_struct() {
	code := checked_gen_c_from_source('named_args_plain_struct_method', '
struct Opt {
	enabled bool
	count int
}

struct Context {}

fn (ctx Context) apply(opt Opt) {}

fn use_params() {
	ctx := Context{}
	ctx.apply(enabled: true, count: 4)
}
')

	assert code.contains('Context__apply(ctx, (Opt){.enabled = true, .count = 4')
}

fn test_unknown_named_struct_field_is_rejected() {
	assert_has_error('unknown_named_struct_field', '
struct Opt {
	enabled bool
}

fn make_opt(opt Opt) {}

fn use_params() {
	make_opt(missing: true)
}
',
		'unknown named field `missing`')
}

fn test_wrong_named_struct_field_type_is_rejected() {
	assert_has_error('wrong_named_struct_field_type', '
struct Opt {
	enabled bool
}

fn make_opt(opt Opt) {}

fn use_params() {
	make_opt(enabled: 1)
}
',
		'for named field `enabled`')
}

fn test_duplicate_named_struct_field_is_rejected() {
	assert_has_error('duplicate_named_struct_field', '
struct Opt {
	enabled bool
}

fn make_opt(opt Opt) {}

fn use_params() {
	make_opt(enabled: true, enabled: false)
}
',
		'duplicate named field `enabled`')
}

fn test_positional_arg_after_named_struct_arg_is_rejected() {
	assert_has_error('non_trailing_named_struct_arg', '
struct Opt {
	enabled bool
}

fn make_opt(opt Opt) {}

fn use_params() {
	something := true
	make_opt(enabled: true, something)
}
',
		'must be trailing')
}

fn test_misplaced_params_attribute_does_not_mark_next_struct() {
	assert_has_error('misplaced_params_attr', '
@[params]
fn marker() {}

struct Opt {}

fn make_opt(opt Opt) {}

fn use_params() {
	make_opt()
}
',
		'argument count mismatch')
}

fn test_params_attribute_on_skipped_decl_does_not_mark_next_struct() {
	messages := check_source_errors('skipped_params_attr_does_not_leak', '
@[params]
@[if windows]
struct Skipped {}

struct Opt {}

fn takes_skipped(s Skipped) {}

fn make_opt(opt Opt) {}

fn use_params() {
	make_opt()
}
')
	assert has_error(messages, 'unknown type `Skipped`'), messages.str()
	assert has_error(messages, 'argument count mismatch'), messages.str()
}

fn test_empty_array_assignment_uses_lhs_contextual_type() {
	code := checked_gen_c_from_source('empty_array_assignment_context', '
struct Game {
mut:
	field [][]int
}

fn reset(mut g Game) {
	g.field = []
}
')

	assert code.contains('array_new(sizeof(Array), 0, 0)')
	assert !code.contains('array_new(sizeof(void), 0, 0)')
	assert !code.contains('array_new(sizeof(int), 0, 0)')
}

fn test_empty_array_literal_is_not_contextualized_for_non_array_lhs() {
	assert_has_error('empty_array_non_array_lhs', '
fn reset() {
	mut value := 0
	value = []
}
',
		'cannot assign')
}

fn test_empty_array_literal_is_not_contextualized_for_fixed_array_lhs() {
	assert_has_error('empty_array_fixed_array_lhs', '
fn reset() {
	mut fixed := [4]int{}
	fixed = []
}
',
		'cannot assign')
}
