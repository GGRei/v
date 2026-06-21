import os
import time
import v3.gen.c as cgen
import v3.markused
import v3.parser
import v3.pref
import v3.transform
import v3.types

fn top_main_source_path(name string) string {
	return os.join_path(os.vtmp_dir(),
		'v3_top_main_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
}

fn top_main_count_substr(haystack string, needle string) int {
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

fn top_main_errors(name string, source string) []string {
	src := top_main_source_path(name)
	defer {
		os.rm(src) or {}
	}
	os.write_file(src, source) or { panic(err) }
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	mut a := p.parse_file(src)
	return parser.synthesize_top_level_main(mut a, [src])
}

fn top_main_gen_c(name string, source string) string {
	src := top_main_source_path(name)
	defer {
		os.rm(src) or {}
	}
	os.write_file(src, source) or { panic(err) }
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	mut a := p.parse_file(src)
	synth_errors := parser.synthesize_top_level_main(mut a, [src])
	assert synth_errors.len == 0, synth_errors.str()
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
	tc.diagnose_unknown_calls = false
	tc.annotate_types()
	tc.check_semantics()
	messages.clear()
	for err in tc.errors {
		messages << err.msg
	}
	assert messages.len == 0, messages.str()
	used := markused.mark_used(a, tc)
	mut g := cgen.FlatGen.new()
	return g.gen_with_used(a, used, &tc)
}

fn test_top_level_statements_synthesize_single_main() {
	code := top_main_gen_c('reduced_top_level', '
mut total := 0
for n in 1 .. 4 {
	total += n
}
')

	assert top_main_count_substr(code, 'int main(int argc, char** argv)') == 1
	assert code.contains('int total = 0;')
	assert code.contains('for (int n = 1;')
	assert code.contains('total += n;')
}

fn test_top_level_call_keeps_called_function_used() {
	code := top_main_gen_c('top_level_call_markused', '
fn helper() int {
	return 7
}

mut result := helper()
')

	assert top_main_count_substr(code, 'int main(int argc, char** argv)') == 1
	assert code.contains('int helper(void)')
	assert code.contains('int result = helper();')
}

fn test_explicit_main_does_not_duplicate() {
	code := top_main_gen_c('explicit_main_only', '
fn main() {
	mut total := 0
	total += 1
}
')

	assert top_main_count_substr(code, 'int main(int argc, char** argv)') == 1
	assert code.contains('int total = 0;')
	assert code.contains('total += 1;')
}

fn test_top_level_statements_with_explicit_main_are_rejected() {
	errors := top_main_errors('mixed_explicit_main', '
fn main() {}

mut total := 0
')

	assert errors.len == 1
	assert errors[0].contains('top-level statements cannot be mixed with an explicit `fn main()`')
}

fn test_top_level_statements_in_non_main_module_are_rejected() {
	errors := top_main_errors('non_main_module', '
module foo

mut x := 1
')

	assert errors.len == 1
	assert errors[0].contains('top-level statements are only supported in module `main`')
}
