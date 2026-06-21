import os
import time
import v3.gen.c as cgen
import v3.markused
import v3.parser
import v3.pref
import v3.transform
import v3.types

fn exit_codegen_source_path(name string) string {
	return os.join_path(os.vtmp_dir(),
		'v3_exit_codegen_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
}

fn gen_exit_c_with_builtins(name string, source string) string {
	src := exit_codegen_source_path(name)
	defer {
		os.rm(src) or {}
	}
	os.write_file(src, source) or { panic(err) }
	mut prefs := pref.new_preferences()
	prefs.vroot = @VMODROOT
	builtin_dir := os.join_path(prefs.vroot, 'vlib', 'builtin')
	mut p := parser.Parser.new(prefs)
	p.parse_files(pref.get_v_files_from_dir(builtin_dir, prefs.user_defines, prefs.target_os))
	mut a := p.a
	a.user_code_start = a.nodes.len
	p.parse_into(src)
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

fn test_builtin_exit_is_not_emitted_as_recursive_c_wrapper() {
	code := gen_exit_c_with_builtins('main_calls_exit', '
fn main() {
	exit(7)
}
')

	assert code.contains('exit(7);')
	assert !code.contains('void exit(int code) {')
	assert !code.contains('exit(code);')
}
