import os
import time
import v3.gen.c as cgen
import v3.parser
import v3.pref
import v3.types

fn top_comptime_decl_source_path(name string) string {
	return os.join_path(os.vtmp_dir(),
		'v3_top_comptime_decl_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
}

fn top_comptime_decl_count_substr(haystack string, needle string) int {
	if needle.len == 0 {
		return 0
	}
	mut count := 0
	mut rest := haystack
	for {
		idx := rest.index(needle) or { break }
		count++
		rest = rest[idx + needle.len..]
	}
	return count
}

fn top_comptime_decl_gen_c(name string, source string, defines []string) string {
	src := top_comptime_decl_source_path(name)
	defer {
		os.rm(src) or {}
	}
	os.write_file(src, source) or { panic(err) }
	mut prefs := pref.new_preferences()
	prefs.user_defines = defines.clone()
	mut p := parser.Parser.new(prefs)
	a := p.parse_file(src)
	mut tc := types.TypeChecker.new(a)
	tc.collect(a)
	mut g := cgen.FlatGen.new()
	return g.gen_with_used(a, map[string]bool{}, &tc)
}

const conditional_struct_source = '
$if feature_on ? {
	struct ActiveConditional {
		value int
	}
} $else {
	struct ActiveConditional {}
}

struct Holder {
	active ActiveConditional
}
'

fn test_enabled_top_level_comptime_struct_branch_is_emitted() {
	code := top_comptime_decl_gen_c('enabled', conditional_struct_source, [
		'feature_on',
	])

	active_pos := code.index('struct ActiveConditional {') or { -1 }
	holder_pos := code.index('struct Holder {') or { -1 }
	assert top_comptime_decl_count_substr(code, 'struct ActiveConditional {') == 1
	assert active_pos >= 0
	assert holder_pos > active_pos
	assert code.contains('\tint value;')
	assert code.contains('\tActiveConditional active;')
	assert !code.contains('\tint _dummy;')
}

fn test_disabled_top_level_comptime_else_struct_branch_is_emitted() {
	code := top_comptime_decl_gen_c('disabled', conditional_struct_source, [])

	active_pos := code.index('struct ActiveConditional {') or { -1 }
	holder_pos := code.index('struct Holder {') or { -1 }
	assert top_comptime_decl_count_substr(code, 'struct ActiveConditional {') == 1
	assert active_pos >= 0
	assert holder_pos > active_pos
	assert code.contains('\tint _dummy;')
	assert code.contains('\tActiveConditional active;')
	assert !code.contains('\tint value;')
}

const nested_conditional_struct_source = '
$if outer_on ? {
	$if inner_on ? {
		struct NestedSelected {
			value int
		}
	} $else {
		struct NestedInactiveInner {}
	}
} $else {
	struct NestedInactiveOuter {}
}

struct NestedHolder {
	selected NestedSelected
}
'

fn test_nested_top_level_comptime_decl_selects_only_active_branch() {
	code := top_comptime_decl_gen_c('nested', nested_conditional_struct_source, [
		'outer_on',
		'inner_on',
	])

	assert code.contains('struct NestedSelected {')
	assert code.contains('\tint value;')
	assert code.contains('\tNestedSelected selected;')
	assert !code.contains('NestedInactiveInner')
	assert !code.contains('NestedInactiveOuter')
}

const else_if_conditional_struct_source = '
$if first_on ? {
	struct ElseIfInactiveFirst {}
} $else $if second_on ? {
	struct ElseIfSelected {
		value int
	}
} $else {
	struct ElseIfInactiveElse {}
}

struct ElseIfHolder {
	selected ElseIfSelected
}
'

fn test_top_level_comptime_else_if_chain_selects_only_active_branch() {
	code := top_comptime_decl_gen_c('else_if', else_if_conditional_struct_source, [
		'second_on',
	])

	assert code.contains('struct ElseIfSelected {')
	assert code.contains('\tint value;')
	assert code.contains('\tElseIfSelected selected;')
	assert !code.contains('ElseIfInactiveFirst')
	assert !code.contains('ElseIfInactiveElse')
}
