import os
import time
import v3.gen.c as cgen
import v3.markused
import v3.parser
import v3.pref
import v3.transform
import v3.types

fn disabled_call_source_path(name string) string {
	return os.join_path(os.vtmp_dir(),
		'v3_disabled_call_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
}

fn gen_disabled_call_c(name string, source string, defines []string) string {
	src := disabled_call_source_path(name)
	defer {
		os.rm(src) or {}
	}
	os.write_file(src, source) or { panic(err) }
	mut prefs := pref.new_preferences()
	prefs.user_defines = defines.clone()
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
	transform.transform(mut a, &tc)
	tc.diagnose_unknown_calls = false
	tc.annotate_types()
	tc.check_semantics()
	messages.clear()
	for err in tc.errors {
		messages << err.msg
	}
	assert tc.errors.len == 0, messages.str()
	used := markused.mark_used(a, tc)
	mut g := cgen.FlatGen.new()
	return g.gen_with_used(a, used, &tc)
}

fn disabled_call_errors(name string, source string, defines []string) []string {
	src := disabled_call_source_path(name)
	defer {
		os.rm(src) or {}
	}
	os.write_file(src, source) or { panic(err) }
	mut prefs := pref.new_preferences()
	prefs.user_defines = defines.clone()
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

fn has_disabled_call_error(messages []string, needle string) bool {
	for msg in messages {
		if msg.contains(needle) {
			return true
		}
	}
	return false
}

fn test_disabled_conditional_void_call_is_omitted_by_default() {
	code := gen_disabled_call_c('default_disabled', '
@[if conditional_probe ?]
fn probe() {}

fn main() {
	probe()
}
', [])

	assert !code.contains('void probe(')
	assert !code.contains('probe();')
}

fn test_enabled_conditional_void_call_emits_function_and_call() {
	code := gen_disabled_call_c('enabled_probe', '
@[if conditional_probe ?]
fn probe() {}

fn main() {
	probe()
}
', [
		'conditional_probe',
	])

	assert code.contains('void probe(')
	assert code.contains('probe();')
}

fn test_disabled_conditional_call_with_named_struct_args_is_omitted_by_default() {
	code := gen_disabled_call_c('default_disabled_named_struct', '
struct ProbeOpt {
	level int
}

@[if conditional_probe ?]
fn probe(opt ProbeOpt) {}

fn main() {
	probe(level: 7)
}
', [])

	assert !code.contains('void probe(')
	assert !code.contains('probe((ProbeOpt){.level = 7')
}

fn test_enabled_conditional_call_with_named_struct_args_emits_function_and_call() {
	code := gen_disabled_call_c('enabled_disabled_named_struct', '
struct ProbeOpt {
	level int
}

@[if conditional_probe ?]
fn probe(opt ProbeOpt) {}

fn main() {
	probe(level: 7)
}
', [
		'conditional_probe',
	])

	assert code.contains('void probe(ProbeOpt opt)')
	assert code.contains('probe((ProbeOpt){.level = 7')
}

fn test_disabled_conditional_call_rejects_unknown_named_struct_field() {
	messages := disabled_call_errors('disabled_named_unknown', '
struct ProbeOpt {
	level int
}

@[if conditional_probe ?]
fn probe(opt ProbeOpt) {}

fn main() {
	probe(missing: 7)
}
', [])

	assert has_disabled_call_error(messages, 'unknown named field `missing`'), messages.str()
}

fn test_disabled_conditional_call_rejects_wrong_named_struct_field_type() {
	messages := disabled_call_errors('disabled_named_wrong_type', '
struct ProbeOpt {
	active bool
}

@[if conditional_probe ?]
fn probe(opt ProbeOpt) {}

fn main() {
	probe(active: 7)
}
', [])

	assert has_disabled_call_error(messages, 'for named field `active`'), messages.str()
}
