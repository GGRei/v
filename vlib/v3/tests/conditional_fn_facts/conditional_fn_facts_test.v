module conditional_fn_facts

import os
import time
import v3.flat
import v3.parser
import v3.pref
import v3.transform
import v3.types

fn source_path(name string) string {
	return os.join_path(os.vtmp_dir(), 'v3_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
}

fn check_source(name string, source string) (&flat.FlatAst, types.TypeChecker, []string) {
	return check_source_with_defines(name, source, []string{})
}

fn check_source_with_defines(name string, source string, user_defines []string) (&flat.FlatAst, types.TypeChecker, []string) {
	src := source_path(name)
	defer {
		os.rm(src) or {}
	}
	os.write_file(src, source) or { panic(err) }
	mut prefs := pref.new_preferences()
	for user_define in user_defines {
		prefs.user_defines << user_define
	}
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
	return a, tc, messages
}

fn check_transform_recheck_source(name string, source string) (&flat.FlatAst, types.TypeChecker, []string) {
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
	if tc.errors.len == 0 {
		transform.transform(mut a, &tc)
		tc.diagnose_unknown_calls = false
		tc.annotate_types()
		tc.check_semantics()
	}
	mut messages := []string{}
	for err in tc.errors {
		messages << err.msg
	}
	return a, tc, messages
}

fn find_direct_call(a &flat.FlatAst, name string) flat.NodeId {
	for i, node in a.nodes {
		if node.kind != .call || node.children_count == 0 {
			continue
		}
		fn_node := a.child_node(&node, 0)
		if fn_node.kind == .ident && fn_node.value == name {
			return flat.NodeId(i)
		}
	}
	return flat.empty_node
}

fn find_direct_call_in_fn(a &flat.FlatAst, fn_name string, call_name string) flat.NodeId {
	for node in a.nodes {
		if node.kind != .fn_decl || node.value != fn_name {
			continue
		}
		for i in 0 .. node.children_count {
			call_id := find_direct_call_from(a, a.child(&node, i), call_name)
			if int(call_id) >= 0 {
				return call_id
			}
		}
	}
	return flat.empty_node
}

fn find_selector_call_in_fn(a &flat.FlatAst, fn_name string, method_name string) flat.NodeId {
	for node in a.nodes {
		if node.kind != .fn_decl || node.value != fn_name {
			continue
		}
		for i in 0 .. node.children_count {
			call_id := find_selector_call_from(a, a.child(&node, i), method_name)
			if int(call_id) >= 0 {
				return call_id
			}
		}
	}
	return flat.empty_node
}

fn find_direct_call_from(a &flat.FlatAst, id flat.NodeId, name string) flat.NodeId {
	if int(id) < 0 {
		return flat.empty_node
	}
	node := a.nodes[int(id)]
	if node.kind == .call && node.children_count > 0 {
		fn_node := a.child_node(&node, 0)
		if fn_node.kind == .ident && fn_node.value == name {
			return id
		}
	}
	for i in 0 .. node.children_count {
		found := find_direct_call_from(a, a.child(&node, i), name)
		if int(found) >= 0 {
			return found
		}
	}
	return flat.empty_node
}

fn find_selector_call_from(a &flat.FlatAst, id flat.NodeId, method_name string) flat.NodeId {
	if int(id) < 0 {
		return flat.empty_node
	}
	node := a.nodes[int(id)]
	if node.kind == .call && node.children_count > 0 {
		fn_node := a.child_node(&node, 0)
		if fn_node.kind == .selector && fn_node.value == method_name {
			return id
		}
	}
	for i in 0 .. node.children_count {
		found := find_selector_call_from(a, a.child(&node, i), method_name)
		if int(found) >= 0 {
			return found
		}
	}
	return flat.empty_node
}

fn has_error(messages []string, needle string) bool {
	for msg in messages {
		if msg.contains(needle) {
			return true
		}
	}
	return false
}

fn test_disabled_conditional_void_function_is_recorded_and_call_is_marked() {
	a, tc, messages := check_source('disabled_conditional_void', '
@[if missing_feature ?]
fn debug_hook(x int, msg string) {}

fn use_hook() {
	debug_hook(1, "ok")
}
')

	assert messages.len == 0, messages.str()
	assert a.disabled_conditional_fns.len == 1
	fact := a.disabled_conditional_fns[0]
	assert fact.name == 'debug_hook'
	assert fact.cond == 'missing_feature?'
	assert fact.return_type == 'void'
	assert fact.param_types == ['int', 'string']
	call_id := find_direct_call(a, 'debug_hook')
	assert int(call_id) >= 0
	assert tc.disabled_conditional_call(call_id)
	assert (tc.resolved_call_name(call_id) or { '' }) == ''
}

fn test_enabled_conditional_function_is_normal_call_without_disabled_fact() {
	a, tc, messages := check_source_with_defines('enabled_conditional_void', '
@[if present_feature ?]
fn debug_hook(x int) {}

fn use_hook() {
	debug_hook(1)
}
', [
		'present_feature',
	])

	assert messages.len == 0, messages.str()
	assert a.disabled_conditional_fns.len == 0
	call_id := find_direct_call(a, 'debug_hook')
	assert int(call_id) >= 0
	assert !tc.disabled_conditional_call(call_id)
	assert (tc.resolved_call_name(call_id) or { '' }) == 'debug_hook'
}

fn test_unrelated_unknown_call_is_still_reported_with_disabled_fact_present() {
	_, _, messages := check_source('disabled_fact_with_unknown_call', '
@[if missing_feature ?]
fn debug_hook() {}

fn use_hook() {
	missing_fn()
}
')

	assert has_error(messages, 'unknown function `missing_fn`'), messages.str()
}

fn test_disabled_conditional_call_is_remarked_after_transform_rebuilds_call_node() {
	a, tc, messages := check_transform_recheck_source('disabled_conditional_after_transform', '
@[if missing_feature ?]
fn debug_hook(x int) {}

fn main() {
	debug_hook(1 + 2)
}
')

	assert messages.len == 0, messages.str()
	call_id := find_direct_call_in_fn(a, 'main', 'debug_hook')
	assert int(call_id) >= 0
	assert tc.disabled_conditional_call(call_id)
	assert (tc.resolved_call_name(call_id) or { '' }) == ''
}

fn test_disabled_conditional_direct_call_accepts_trailing_params_struct_named_args() {
	a, tc, messages := check_source('disabled_conditional_direct_params_named_args', '
@[params]
struct Opt {
	enabled bool
}

@[if missing_feature ?]
fn probe(opt Opt) {}

fn main() {
	probe(enabled: true)
}
')

	assert messages.len == 0, messages.str()
	call_id := find_direct_call(a, 'probe')
	assert int(call_id) >= 0
	assert tc.disabled_conditional_call(call_id)
	assert (tc.resolved_call_name(call_id) or { '' }) == ''
}

fn test_disabled_conditional_direct_call_rejects_bad_params_named_args() {
	_, _, unknown_messages := check_source('disabled_conditional_direct_params_unknown_field', '
@[params]
struct Opt {
	enabled bool
}

@[if missing_feature ?]
fn probe(opt Opt) {}

fn main() {
	probe(missing: true)
}
')
	assert has_error(unknown_messages, 'unknown named field `missing`'), unknown_messages.str()

	_, _, wrong_type_messages := check_source('disabled_conditional_direct_params_wrong_type', '
@[params]
struct Opt {
	enabled bool
}

@[if missing_feature ?]
fn probe(opt Opt) {}

fn main() {
	probe(enabled: "bad")
}
')
	assert has_error(wrong_type_messages, 'cannot use `string` for named field `enabled`'), wrong_type_messages.str()
}

fn test_disabled_conditional_method_is_marked_after_transform_recheck() {
	a, tc, messages := check_transform_recheck_source('disabled_conditional_method_after_transform', '
struct Game {}

@[if missing_feature ?]
fn (g Game) showfps(x int) {}

fn main() {
	game := Game{}
	game.showfps(1 + 2)
}
')

	assert messages.len == 0, messages.str()
	call_id := find_selector_call_in_fn(a, 'main', 'showfps')
	assert int(call_id) >= 0
	assert tc.disabled_conditional_call(call_id)
	assert (tc.resolved_call_name(call_id) or { '' }) == ''
}

fn test_disabled_conditional_method_accepts_trailing_params_struct_named_args() {
	a, tc, messages := check_source('disabled_conditional_method_params_named_args', '
struct Game {}

@[params]
struct Opt {
	enabled bool
}

@[if missing_feature ?]
fn (g Game) showfps(opt Opt) {}

fn main() {
	game := Game{}
	game.showfps(enabled: true)
}
')

	assert messages.len == 0, messages.str()
	call_id := find_selector_call_in_fn(a, 'main', 'showfps')
	assert int(call_id) >= 0
	assert tc.disabled_conditional_call(call_id)
	assert (tc.resolved_call_name(call_id) or { '' }) == ''
}

fn test_enabled_conditional_method_is_normal_call_without_disabled_fact() {
	a, tc, messages := check_source_with_defines('enabled_conditional_method', '
struct Game {}

@[if present_feature ?]
fn (g Game) showfps(x int) {}

fn main() {
	game := Game{}
	game.showfps(1)
}
', [
		'present_feature',
	])

	assert messages.len == 0, messages.str()
	assert a.disabled_conditional_fns.len == 0
	call_id := find_selector_call_in_fn(a, 'main', 'showfps')
	assert int(call_id) >= 0
	assert !tc.disabled_conditional_call(call_id)
	assert (tc.resolved_call_name(call_id) or { '' }) == 'Game.showfps'
}

fn test_disabled_conditional_method_keeps_argument_checking() {
	_, _, messages := check_source('disabled_conditional_method_args', '
struct Game {}

@[if missing_feature ?]
fn (g Game) showfps(x int) {}

fn main() {
	game := Game{}
	game.showfps("bad")
}
')

	assert has_error(messages, 'cannot use `string` as argument 2 to `game.showfps`'), messages.str()
}

fn test_disabled_conditional_nonvoid_method_call_is_rejected() {
	_, _, messages := check_source('disabled_conditional_nonvoid_method', '
struct Game {}

@[if missing_feature ?]
fn (g Game) fps() int {
	return 60
}

fn main() {
	game := Game{}
	_ := game.fps()
}
')

	assert has_error(messages, 'cannot call disabled conditional non-void function `Game.fps`'), messages.str()
}

fn test_unrelated_unknown_method_is_still_reported_with_disabled_method_fact_present() {
	_, _, messages := check_source('disabled_method_fact_with_unknown_method', '
struct Game {}

@[if missing_feature ?]
fn (g Game) showfps() {}

fn main() {
	game := Game{}
	game.missing_method()
}
')

	assert has_error(messages, 'unknown function `game.missing_method`'), messages.str()
}

fn test_disabled_conditional_void_function_keeps_argument_checking() {
	_, _, messages := check_source('disabled_conditional_void_args', '
@[if missing_feature ?]
fn debug_hook(x int) {}

fn use_hook() {
	debug_hook("bad")
}
')

	assert has_error(messages, 'cannot use `string` as argument 1 to `debug_hook`'), messages.str()
}

fn test_disabled_conditional_nonvoid_function_call_is_rejected() {
	_, _, messages := check_source('disabled_conditional_nonvoid', '
@[if missing_feature ?]
fn debug_value() int {
	return 1
}

fn use_value() {
	_ := debug_value()
}
')

	assert has_error(messages, 'cannot call disabled conditional non-void function `debug_value`'), messages.str()
}
