import json
import os
import time
import v3.cmdexec
import v3.pref

const driver_cli_vlib_dir = os.dir(os.dir(os.dir(@FILE)))
const driver_cli_v3_dir = os.dir(os.dir(@FILE))
const driver_cli_v3_src = os.join_path(driver_cli_v3_dir, 'v3.v')

fn build_driver_cli_v3(root string) string {
	return build_driver_cli_v3_with_flags(root, [])
}

fn build_driver_cli_v3_with_flags(root string, flags []string) string {
	mut bin := os.join_path(root, 'v3_driver_cli')
	$if windows {
		bin += '.exe'
	}
	mut args := ['-gc', 'none']
	args << flags
	args << ['-path', '${driver_cli_vlib_dir}|@vlib|@vmodules', '-o', bin, driver_cli_v3_src]
	mut result := os.Result{}
	$if macos {
		mut environment := os.environ()
		environment['V_MACOS_V3_BOOTSTRAP'] = '1'
		result = run_driver_with_environment(@VEXE, args, environment)
	} $else {
		result = cmdexec.run(@VEXE, args)
	}
	assert result.exit_code == 0, result.output
	return bin
}

fn assert_driver_cli_failure(v3_bin string, args []string, message string) {
	result := cmdexec.run(v3_bin, args)
	label := cmdexec.display(v3_bin, args)
	assert result.exit_code != 0, label
	assert result.output.contains(message), '${label}\n${result.output}'
}

fn v3_profile_counter(profile_output string, fn_name string) int {
	for line in profile_output.split_into_lines() {
		fields := line.fields()
		if fields.len > 0 && fields.last() == fn_name {
			return fields[0].int()
		}
	}
	return -1
}

fn test_driver_v1_compatible_profile_options() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_profile_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)

	api_source := os.join_path(root, 'profile_api.v')
	os.write_file(api_source, '@[has_globals]
module main

import v.profile

__global v__profile_enabled = false

fn abc() {
	println("abc")
}

fn main() {
	profile.on(false)
	abc()
	profile.on(true)
	abc()
}
')!
	api_binary := os.join_path(root, 'profile_api')
	api_profile := os.join_path(root, 'profile_api.txt')
	api_compile := cmdexec.run(v3_bin, ['-silent', '-profile', api_profile, '-o', api_binary,
		api_source])
	assert api_compile.exit_code == 0, api_compile.output
	api_run := cmdexec.run(api_binary, [])
	assert api_run.exit_code == 0, api_run.output
	api_output := os.read_file(api_profile)!
	assert v3_profile_counter(api_output, 'builtin__builtin_init') == 1, api_output
	assert v3_profile_counter(api_output, 'main__main') == 1, api_output
	assert v3_profile_counter(api_output, 'main__abc') == 1, api_output
	assert v3_profile_counter(api_output, 'v__profile__on') == -1, api_output

	missing_profile := os.join_path(root, 'missing', 'profile.txt')
	missing_profile_binary := os.join_path(root, 'missing_profile')
	missing_profile_compile := cmdexec.run(v3_bin, ['-silent', '-profile', missing_profile, '-o',
		missing_profile_binary, api_source])
	assert missing_profile_compile.exit_code == 0, missing_profile_compile.output
	missing_profile_run := cmdexec.run(missing_profile_binary, [])
	assert missing_profile_run.exit_code == 0, missing_profile_run.output
	assert !os.exists(missing_profile)

	user_profile_module := os.join_path(root, 'profile')
	os.mkdir_all(user_profile_module)!
	os.write_file(os.join_path(user_profile_module, 'profile.v'), 'module profile

pub fn answer() int {
	return 42
}
')!
	user_profile_source := os.join_path(root, 'user_profile.v')
	os.write_file(user_profile_source, 'module main

import profile

fn main() {
	println(profile.answer())
}
')!
	user_profile_binary := os.join_path(root, 'user_profile')
	user_profile_output_path := os.join_path(root, 'user_profile.txt')
	user_profile_compile := cmdexec.run(v3_bin, ['-silent', '-profile', user_profile_output_path,
		'-o', user_profile_binary, user_profile_source])
	assert user_profile_compile.exit_code == 0, user_profile_compile.output
	user_profile_run := cmdexec.run(user_profile_binary, [])
	assert user_profile_run.exit_code == 0, user_profile_run.output
	assert user_profile_run.output.trim_space() == '42', user_profile_run.output
	user_profile_output := os.read_file(user_profile_output_path)!
	assert v3_profile_counter(user_profile_output, 'profile__answer') == 1, user_profile_output

	operator_profile_source := os.join_path(root, 'operator_profile.v')
	os.write_file(operator_profile_source, 'module main

struct Number {
	value int
}

fn (left Number) plus(right Number) Number {
	return Number{
		value: left.value + right.value + 1
	}
}

fn (left Number) + (right Number) Number {
	return Number{
		value: left.value + right.value
	}
}

fn main() {
	left := Number{
		value: 20
	}
	right := Number{
		value: 22
	}
	println(left.plus(right).value)
	println((left + right).value)
}
')!
	operator_profile_binary := os.join_path(root, 'operator_profile')
	operator_profile_output_path := os.join_path(root, 'operator_profile.txt')
	operator_profile_compile := cmdexec.run(v3_bin, ['-silent', '-profile-fns',
		'main__Number__plus__operator', '-profile', operator_profile_output_path, '-o',
		operator_profile_binary, operator_profile_source])
	assert operator_profile_compile.exit_code == 0, operator_profile_compile.output
	operator_profile_run := cmdexec.run(operator_profile_binary, [])
	assert operator_profile_run.exit_code == 0, operator_profile_run.output
	assert operator_profile_run.output.trim_space() == '43\n42', operator_profile_run.output
	operator_profile_output := os.read_file(operator_profile_output_path)!
	assert v3_profile_counter(operator_profile_output, 'main__Number__plus__operator') == 1, operator_profile_output

	assert v3_profile_counter(operator_profile_output, 'main__Number__plus') == -1, operator_profile_output

	// With no output path, the following source remains the compiler input and
	// the V1 `-prof` alias writes its report to stdout.
	stdout_binary := os.join_path(root, 'profile_stdout')
	stdout_compile := cmdexec.run(v3_bin, ['-silent', '-prof', '-o', stdout_binary, api_source])
	assert stdout_compile.exit_code == 0, stdout_compile.output
	stdout_run := cmdexec.run(stdout_binary, [])
	assert stdout_run.exit_code == 0, stdout_run.output
	assert v3_profile_counter(stdout_run.output, 'main__main') == 1, stdout_run.output
	assert v3_profile_counter(stdout_run.output, 'main__abc') == 1, stdout_run.output

	reset_binary := os.join_path(root, 'profile_reset')
	reset_profile := os.join_path(root, 'profile_reset.txt')
	reset_compile := cmdexec.run(v3_bin, ['-silent', '-d', 'no_profile_startup', '-profile',
		reset_profile, '-o', reset_binary, api_source])
	assert reset_compile.exit_code == 0, reset_compile.output
	reset_run := cmdexec.run(reset_binary, [])
	assert reset_run.exit_code == 0, reset_run.output
	reset_output := os.read_file(reset_profile)!
	assert v3_profile_counter(reset_output, 'builtin__builtin_init') == -1, reset_output
	assert v3_profile_counter(reset_output, 'main__main') == 1, reset_output
	assert v3_profile_counter(reset_output, 'main__abc') == 1, reset_output

	reset_c := os.join_path(root, 'profile_reset.c')
	reset_c_compile := cmdexec.run(v3_bin, ['-silent', '-d', 'no_profile_startup', '-profile',
		reset_profile, '-o', reset_c, api_source])
	assert reset_c_compile.exit_code == 0, reset_c_compile.output
	reset_c_source := os.read_file(reset_c)!
	reset_body := reset_c_source.all_after('void vreset_profile_stats(void) {').all_before('\n}')
	assert reset_body.contains('_only_current = 0.0;'), reset_body

	no_main_source := os.join_path(root, 'profile_no_main.v')
	os.write_file(no_main_source, "@[export: 'profiled_answer']
pub fn profiled_answer() int {
	return 42
}
")!
	no_main_c := os.join_path(root, 'profile_no_main.c')
	no_main_profile := os.join_path(root, 'profile_no_main.txt')
	no_main_compile := cmdexec.run(v3_bin, ['-silent', '-d', 'no_main', '-profile', no_main_profile,
		'-o', no_main_c, no_main_source])
	assert no_main_compile.exit_code == 0, no_main_compile.output
	no_main_c_source := os.read_file(no_main_c)!
	no_main_init_body :=
		no_main_c_source.all_after('static void _vno_main_init_caller(void) {').all_before('\n}')
	assert no_main_init_body.contains('atexit(vprint_profile_stats);'), no_main_init_body
	$if !windows {
		no_main_host_source := os.join_path(root, 'profile_no_main_host.c')
		os.write_file(no_main_host_source, 'extern int profiled_answer(void);
int main(void) {
	return profiled_answer() == 42 ? 0 : 1;
}
')!
		no_main_host := os.join_path(root, 'profile_no_main_host')
		cc := os.getenv_opt('CC') or { 'cc' }
		no_main_host_compile := cmdexec.run(cc, ['-std=gnu11', '-w', no_main_c, no_main_host_source,
			'-lpthread', '-lm', '-o', no_main_host])
		assert no_main_host_compile.exit_code == 0, no_main_host_compile.output
		no_main_host_run := cmdexec.run(no_main_host, [])
		assert no_main_host_run.exit_code == 0, no_main_host_run.output
		no_main_output := os.read_file(no_main_profile)!
		assert v3_profile_counter(no_main_output, 'main__profiled_answer') == 1, no_main_output
	}
	shared_c := os.join_path(root, 'profile_shared.c')
	shared_profile := os.join_path(root, 'profile_shared.txt')
	shared_compile := cmdexec.run(v3_bin, ['-silent', '-shared', '-profile', shared_profile, '-o',
		shared_c, no_main_source])
	assert shared_compile.exit_code == 0, shared_compile.output
	shared_c_source := os.read_file(shared_c)!
	shared_init_body :=
		shared_c_source.all_after('static void _vno_main_init_caller(void) {').all_before('\n}')
	assert shared_init_body.contains('atexit(vprint_profile_stats);'), shared_init_body

	synthetic_main_c := os.join_path(root, 'profile_synthetic_main.c')
	synthetic_main_compile := cmdexec.run(v3_bin, ['-silent', '-profile', no_main_profile, '-o',
		synthetic_main_c, no_main_source])
	assert synthetic_main_compile.exit_code == 0, synthetic_main_compile.output
	synthetic_main_c_source := os.read_file(synthetic_main_c)!
	assert synthetic_main_c_source.count('atexit(vprint_profile_stats);') == 1, synthetic_main_c_source

	selective_source := os.join_path(root, 'profile_selective.v')
	os.write_file(selective_source, 'module main

@[inline]
fn inline_fn() {
	println("inline")
}

fn leaf() {
	println("leaf")
}

fn selected() {
	leaf()
	leaf()
	inline_fn()
}

fn ignored() {
	leaf()
}

fn main() {
	ignored()
	selected()
}
')!
	selective_binary := os.join_path(root, 'profile_selective')
	selective_profile := os.join_path(root, 'profile_selective.txt')
	selective_compile := cmdexec.run(v3_bin, ['-silent', '-profile-fns', 'main__selected',
		'-profile-no-inline', '-profile', selective_profile, '-o', selective_binary, selective_source])
	assert selective_compile.exit_code == 0, selective_compile.output
	selective_run := cmdexec.run(selective_binary, [])
	assert selective_run.exit_code == 0, selective_run.output
	selective_output := os.read_file(selective_profile)!
	assert v3_profile_counter(selective_output, 'main__main') == -1, selective_output
	assert v3_profile_counter(selective_output, 'main__ignored') == -1, selective_output
	assert v3_profile_counter(selective_output, 'main__selected') == 1, selective_output
	assert v3_profile_counter(selective_output, 'main__leaf') == 2, selective_output
	assert v3_profile_counter(selective_output, 'main__inline_fn') == -1, selective_output
	assert v3_profile_counter(selective_output, 'builtin__println') == 3, selective_output
}

fn test_driver_only_monomorphizes_when_generics_are_used() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_generics_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	hello_source := os.join_path(root, 'hello.v')
	os.write_file(hello_source, "fn main() { println('ok') }\n") or { panic(err) }
	hello_output := os.join_path(root, 'hello.c')
	hello_compile := cmdexec.run(v3_bin, ['-nocache', '-v', '-o', hello_output, hello_source])
	assert hello_compile.exit_code == 0, hello_compile.output
	assert hello_compile.output.contains('finalize'), hello_compile.output
	assert !hello_compile.output.contains('monomorphize'), hello_compile.output
	hello_c := os.read_file(hello_output)!
	assert !hello_c.contains('struct stdatomic__AtomicVal')
	assert !hello_c.contains('struct sync__ThreadLocalStorage')
	assert !hello_c.contains('struct sync__Channel {')
	assert !hello_c.contains('v3_chan_str')
	assert !hello_c.contains('ChanState__autostr')

	generic_source := os.join_path(root, 'generic.v')
	os.write_file(generic_source, 'fn identity[T](value T) T {
	return value
}

fn main() {
	println(identity(1))
}
') or {
		panic(err)
	}
	generic_output := os.join_path(root, 'generic.c')
	generic_compile := cmdexec.run(v3_bin, ['-nocache', '-v', '-o', generic_output, generic_source])
	assert generic_compile.exit_code == 0, generic_compile.output
	assert generic_compile.output.contains('monomorphize'), generic_compile.output

	channel_dir := os.join_path(root, 'channel_project')
	channel_module_dir := os.join_path(channel_dir, 'worker')
	os.mkdir_all(channel_module_dir)!
	os.write_file(os.join_path(channel_module_dir, 'worker.v'), 'module worker

pub fn value() int {
	ch := chan int{cap: 1}
	ch <- 71
	return <-ch
}
')!
	channel_source := os.join_path(channel_dir, 'main.v')
	os.write_file(channel_source, 'module main

import worker

fn main() {
	println(worker.value())
}
')!
	channel_output := os.join_path(root, 'channel_program')
	channel_compile := cmdexec.run(v3_bin, ['-nocache', '-o', channel_output, channel_source])
	assert channel_compile.exit_code == 0, channel_compile.output
	channel_run := cmdexec.run(channel_output, [])
	assert channel_run.exit_code == 0, channel_run.output
	assert channel_run.output == '71\n'
}

fn test_v3_build_rejects_garbage_collectors() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_gc_build_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	for mode in ['boehm', 'boehm_full', 'boehm_incr', 'boehm_full_opt', 'boehm_incr_opt',
		'boehm_leak', 'vgc'] {
		output := os.join_path(root, 'v3_${mode}')
		result := cmdexec.run(@VEXE, ['-old-compiler', '-gc', mode, '-path',
			'${driver_cli_vlib_dir}|@vlib|@vmodules', '-o', output, driver_cli_v3_src])
		assert result.exit_code != 0
		assert result.output.contains('v3 must be built without a garbage collector'), result.output
		assert !os.is_file(output)
	}
}

fn test_standard_v3_excludes_ownership_checker() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_no_ownership_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	source := os.join_path(root, 'main.v')
	os.write_file(source, "fn main() {
	println('no ownership')
}
")!
	output := os.join_path(root, 'no_ownership')
	compile := cmdexec.run(v3_bin, ['-o', output, source])
	assert compile.exit_code == 0, compile.output
	run := cmdexec.run(output, [])
	assert run.exit_code == 0, run.output
	assert run.output == 'no ownership\n'
	c_stat_source := os.join_path(root, 'c_stat.v')
	os.write_file(c_stat_source, 'fn main() {\n\t_ := C.stat{}\n}\n')!
	c_stat_output := os.join_path(root, 'c_stat')
	c_stat_compile := cmdexec.run(v3_bin, ['-o', c_stat_output, c_stat_source])
	assert c_stat_compile.exit_code == 0, c_stat_compile.output
	assert_driver_cli_failure(v3_bin, ['-ownership', source],
		'ownership support is not compiled into this v3 executable')
	assert_driver_cli_failure(v3_bin, ['-d', 'ownership', source],
		'ownership support is not compiled into this v3 executable')
	assert_driver_cli_failure(v3_bin, ['-downership', source],
		'ownership support is not compiled into this v3 executable')
}

fn test_explicit_arm64_import_unskips_ssa_dependencies() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_arm64_import_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	source := os.join_path(root, 'main.v')
	os.write_file(source, 'module main

import v3.gen.arm64

fn main() {}
	')!
	output := os.join_path(root, 'arm64_import')
	compile := cmdexec.run(v3_bin, ['-no-memory-limit', '-o', output, source])
	assert compile.exit_code == 0, compile.output
}

fn test_driver_cflags_include_dir_is_visible_to_header_inliner() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_cflags_include_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	include_dir := os.join_path(root, 'headers with spaces')
	os.mkdir_all(include_dir) or { panic(err) }
	os.write_file(os.join_path(include_dir, 'cli_header.h'), 'typedef struct CliHeaderValue {
	int value;
} CliHeaderValue;

static inline int cli_header_value(CliHeaderValue* item) {
	return item->value;
}
') or {
		panic(err)
	}
	source := os.join_path(root, 'main.v')
	os.write_file(source, 'module main

#include "cli_header.h"

@[typedef]
struct C.CliHeaderValue {
	value int
}

fn C.cli_header_value(item &C.CliHeaderValue) int

fn main() {
	mut item := C.CliHeaderValue{
		value: 73
	}
	println(C.cli_header_value(&item))
}
') or {
		panic(err)
	}
	output := os.join_path(root, 'cli_header_program')
	keep_c_dir := os.join_path(root, 'kept_c')
	os.mkdir(keep_c_dir)!
	mut environment := os.environ()
	environment['VTMP'] = keep_c_dir
	compile := run_driver_with_environment(v3_bin, ['-nocache', '-keepc', '-cflags',
		'-I "${include_dir}"', '-o', output, source], environment)
	assert compile.exit_code == 0, compile.output
	assert !os.exists(output + '.c')
	kept_files := kept_c_files(keep_c_dir)
	assert kept_files.len == 1, kept_files.str()
	generated_c := os.read_file(kept_files[0])!
	assert !generated_c.contains('#include "cli_header.h"'), generated_c
	assert generated_c.contains('static inline int cli_header_value(CliHeaderValue* item)')
	run := cmdexec.run(output, [])
	assert run.exit_code == 0, run.output
	assert run.output.trim_space() == '73'
}

fn run_driver_with_stdin_file(v3_bin string, args []string, stdin_path string) os.Result {
	mut process := os.new_process(v3_bin)
	process.set_args(args)
	process.set_stdin_path(stdin_path)
	return collect_driver_process_result(mut process)
}

fn collect_driver_process_result(mut process os.Process) os.Result {
	process.set_redirect_stdio()
	process.run()
	process.wait()
	mut output := process.stdout_slurp()
	output += process.stderr_slurp()
	if process.err.len > 0 {
		output += process.err
	}
	exit_code := if process.code >= 0 { process.code } else { 1 }
	process.close()
	return os.Result{
		exit_code: exit_code
		output:    output
	}
}

fn run_driver_with_environment(v3_bin string, args []string, environment map[string]string) os.Result {
	mut process := os.new_process(v3_bin)
	process.set_args(args)
	process.set_environment(environment)
	return collect_driver_process_result(mut process)
}

fn run_driver_in_work_folder(v3_bin string, args []string, work_folder string) os.Result {
	mut process := os.new_process(v3_bin)
	process.set_args(args)
	process.set_work_folder(work_folder)
	return collect_driver_process_result(mut process)
}

fn test_driver_persistent_macos_output_survives_cache_removal() {
	$if !macos {
		return
	}
	root := os.join_path(os.vtmp_dir(), 'v3_driver_persistent_output_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3_with_flags(root, ['-prealloc'])
	source := os.join_path(root, 'persistent.v')
	os.write_file(source, "fn main() {
	println('persistent-output-ok')
}
")!
	output := source.all_before_last('.v')
	cache_dir := os.join_path(root, 'cache')
	os.mkdir_all(cache_dir) or { panic(err) }
	mut environment := os.environ()
	environment['V3CACHE'] = cache_dir
	compile := run_driver_with_environment(v3_bin, ['-silent', '-no-parallel', '-no-memory-limit',
		source], environment)
	assert compile.exit_code == 0, compile.output
	assert os.is_file(output)
	os.rmdir_all(cache_dir) or { panic(err) }
	run := cmdexec.run(output, [])
	assert run.exit_code == 0, run.output
	assert run.output == 'persistent-output-ok\n', run.output
}

fn kept_c_files(dir string) []string {
	mut files := (os.ls(dir) or { return []string{} }).filter(it.ends_with('.tmp.c'))
	files.sort()
	return files.map(os.join_path_single(dir, it))
}

fn test_driver_macos_wrapv_and_cg_link_flags() {
	$if !macos {
		return
	}
	root := os.join_path(os.vtmp_dir(), 'v3_driver_macos_c_flags_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3_with_flags(root, ['-prealloc'])
	source := os.join_path(root, 'signed_overflow.v')
	os.write_file(source, '#flag -O2

fn increment_is_greater(value int) bool {
	return value + 1 > value
}

fn main() {
	println(increment_is_greater(int(2147483647)))
}
')!
	output := os.join_path(root, 'signed_overflow')
	compile := cmdexec.run(v3_bin, ['-nocache', '-no-memory-limit', '-prod', '-showcc', '-o', output,
		source])
	assert compile.exit_code == 0, compile.output
	assert compile.output.contains('-fwrapv'), compile.output
	run := cmdexec.run(output, [])
	assert run.exit_code == 0, run.output
	assert run.output == 'false\n', run.output

	tcc_output := os.join_path(root, 'signed_overflow_tcc')
	tcc_compile := cmdexec.run(v3_bin, ['-nocache', '-no-memory-limit', '-showcc', '-o', tcc_output,
		source])
	assert tcc_compile.exit_code == 0, tcc_compile.output
	assert tcc_compile.output.contains('tcc.exe'), tcc_compile.output
	assert tcc_compile.output.contains('-fwrapv'), tcc_compile.output

	cg_output := os.join_path(root, 'signed_overflow_cg')
	cg_compile := cmdexec.run(v3_bin, ['-nocache', '-no-memory-limit', '-prod', '-showcc', '-cg',
		'-o', cg_output, source])
	assert cg_compile.exit_code == 0, cg_compile.output
	assert cg_compile.output.contains('-Wl,-export_dynamic'), cg_compile.output

	g_output := os.join_path(root, 'signed_overflow_g')
	g_compile := cmdexec.run(v3_bin, ['-nocache', '-no-memory-limit', '-prod', '-showcc', '-g',
		'-o', g_output, source])
	assert g_compile.exit_code == 0, g_compile.output
	assert !g_compile.output.contains('-Wl,-export_dynamic'), g_compile.output

	c99_c_source := os.join_path(root, 'compat_c99.c')
	os.write_file(c99_c_source, '#if !defined(__STDC_VERSION__) || __STDC_VERSION__ != 199901L
#error expected strict C99
#endif

int v3_compat_c99_probe(void) {
	return 99;
}
')!
	c99_source := os.join_path(root, 'compat_c99.v')
	os.write_file(c99_source, "#flag @DIR/compat_c99.c

fn C.v3_compat_c99_probe() int

fn main() {
	\$if c99 ? {
		println('defined')
	} \$else {
		println(C.v3_compat_c99_probe())
	}
}
")!
	c99_output := os.join_path(root, 'compat_c99')
	c99_compile := cmdexec.run(v3_bin, ['-nocache', '-no-memory-limit', '-prod', '-showcc',
		'-macos-v3-compat-c99', '-o', c99_output, c99_source])
	assert c99_compile.exit_code == 0, c99_compile.output
	assert c99_compile.output.contains('-std=c99'), c99_compile.output
	assert !c99_compile.output.contains('-std=gnu11'), c99_compile.output
	c99_run := cmdexec.run(c99_output, [])
	assert c99_run.exit_code == 0, c99_run.output
	assert c99_run.output == '99\n', c99_run.output

	native_object := os.join_path(root, 'compat_c99.o')
	native_object_compile := cmdexec.run('cc',
		['-std=c99', '-c', c99_c_source, '-o', native_object])
	assert native_object_compile.exit_code == 0, native_object_compile.output
	object_source := os.join_path(root, 'compat_object.v')
	os.write_file(object_source, '#flag @DIR/compat_c99.o

fn C.v3_compat_c99_probe() int

fn main() {
	println(C.v3_compat_c99_probe())
}
')!
	object_output := os.join_path(root, 'compat_object')
	object_compile := cmdexec.run(v3_bin, ['-nocache', '-no-memory-limit', '-showcc', '-o',
		object_output, object_source])
	assert object_compile.exit_code == 0, object_compile.output
	assert !object_compile.output.contains('tcc.exe'), object_compile.output
	object_run := cmdexec.run(object_output, [])
	assert object_run.exit_code == 0, object_run.output
	assert object_run.output == '99\n', object_run.output
}

fn test_driver_c_project_and_dump_include_effective_dependency_flags() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_effective_c_flags_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	native_source := os.join_path(root, 'native_dependency.c')
	os.write_file(native_source, '#ifndef V3_REVIEW_DEPENDENCY_FLAG
#error missing generated dependency flag
#endif

int v3_review_dependency_value(void) {
	return 42;
}
')!
	resolved_native_source := os.real_path(native_source)
	source := os.join_path(root, 'effective_flags.v')
	os.write_file(source, '#flag -DV3_REVIEW_DEPENDENCY_FLAG=1
#flag @DIR/native_dependency.o

fn C.v3_review_dependency_value() int

fn main() {
	println(C.v3_review_dependency_value())
}
')!
	project_dir := os.join_path(root, r'project $with spaces')
	project_dump := os.join_path(root, 'project_flags.txt')
	generate := cmdexec.run(v3_bin, ['-silent', '-prod', '-dump-c-flags', project_dump,
		'-generate-c-project', project_dir, source])
	assert generate.exit_code == 0, generate.output
	build_command := os.read_file(os.join_path(project_dir, 'build_command.txt'))!
	project_flags := os.read_lines(project_dump)!
	for expected in ['-std=gnu11', '-O3', '-flto', '-DV3_REVIEW_DEPENDENCY_FLAG=1',
		resolved_native_source] {
		assert build_command.contains(expected), build_command
		assert expected in project_flags, project_flags.str()
	}
	assert !build_command.contains(resolved_native_source.all_before_last('.c') + '.o'), build_command
	batch_command := os.read_file(os.join_path(project_dir, 'build.bat'))!
	assert batch_command.contains('"${project_dir}'), batch_command
	assert !batch_command.contains("'${project_dir}"), batch_command
	makefile := os.read_file(os.join_path(project_dir, 'Makefile'))!
	assert makefile.contains(r'project $$with spaces'), makefile
	make_build := cmdexec.run('make', ['-C', project_dir])
	assert make_build.exit_code == 0, make_build.output
	project_build := cmdexec.run('sh', [os.join_path(project_dir, 'build.sh')])
	assert project_build.exit_code == 0, project_build.output
	project_run := cmdexec.run(os.join_path(project_dir, 'effective_flags'), [])
	assert project_run.exit_code == 0, project_run.output
	assert project_run.output == '42\n', project_run.output

	backslash_project_dir := os.join_path(root, r'project\backslash')
	backslash_generate := cmdexec.run(v3_bin, ['-silent', '-generate-c-project',
		backslash_project_dir, source])
	assert backslash_generate.exit_code == 0, backslash_generate.output
	backslash_build := cmdexec.run('sh', [
		os.join_path(backslash_project_dir, 'build.sh'),
	])
	assert backslash_build.exit_code == 0, backslash_build.output
	backslash_make := cmdexec.run('make', ['-C', backslash_project_dir])
	assert backslash_make.exit_code == 0, backslash_make.output

	bin_output := os.join_path(root, 'effective_flags')
	bin_dump := os.join_path(root, 'binary_flags.txt')
	compile := cmdexec.run(v3_bin, ['-silent', '-prod', '-showcc', '-dump-c-flags', bin_dump, '-o',
		bin_output, source])
	assert compile.exit_code == 0, compile.output
	bin_flags := os.read_lines(bin_dump)!
	for expected in ['-std=gnu11', '-O3', '-flto', '-w', '-Wno-int-conversion',
		'-DV3_REVIEW_DEPENDENCY_FLAG=1', '-lm'] {
		assert expected in bin_flags, bin_flags.str()
		assert compile.output.contains(expected), compile.output
	}
	assert bin_flags.any(it.ends_with('.o')), bin_flags.str()
	bin_run := cmdexec.run(bin_output, [])
	assert bin_run.exit_code == 0, bin_run.output
	assert bin_run.output == '42\n', bin_run.output
}

fn test_driver_doc_detection_skips_all_option_values() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_doc_option_values_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	source := os.join_path(root, 'app.v')
	os.write_file(source, "fn main() { println('option-value-doc') }\n")!
	for define_option in ['-d', '-define'] {
		define_case := os.join_path(root, define_option.trim_left('-'))
		os.mkdir_all(define_case)!
		define := run_driver_in_work_folder(v3_bin,
			['-silent', define_option, 'doc', 'run', source], define_case)
		assert define.exit_code == 0, '${define_option}: ${define.output}'
		assert define.output == 'option-value-doc\n', define.output
	}

	project_case := os.join_path(root, 'project_case')
	os.mkdir_all(project_case)!
	project := run_driver_in_work_folder(v3_bin, ['-silent', '-generate-c-project', 'doc', source],
		project_case)
	assert project.exit_code == 0, project.output
	assert os.is_file(os.join_path(project_case, 'doc', 'app.c'))

	for coverage_option in ['-cov', '-coverage'] {
		coverage_case := os.join_path(root, coverage_option.trim_left('-'))
		os.mkdir_all(coverage_case)!
		coverage := run_driver_in_work_folder(v3_bin, ['-silent', coverage_option, 'doc', 'run',
			source], coverage_case)
		assert coverage.exit_code == 0, '${coverage_option}: ${coverage.output}'
		assert coverage.output == 'option-value-doc\n', coverage.output
	}

	file_list_case := os.join_path(root, 'file_list_case')
	os.mkdir_all(os.join_path(file_list_case, 'doc'))!
	os.write_file(os.join_path(file_list_case, 'doc', 'extra.v'),
		"module main\n\nfn doc_option_value() string { return 'option-value-doc' }\n")!
	file_list_main := os.join_path(file_list_case, 'main.v')
	os.write_file(file_list_main, 'module main\n\nfn main() { println(doc_option_value()) }\n')!
	file_list := run_driver_in_work_folder(v3_bin, ['-silent', '-file-list', 'doc', '-o', 'out',
		file_list_main], file_list_case)
	assert file_list.exit_code == 0, file_list.output
	file_list_run := cmdexec.run(os.join_path(file_list_case, 'out'), [])
	assert file_list_run.exit_code == 0, file_list_run.output
	assert file_list_run.output == 'option-value-doc\n', file_list_run.output

	for option in ['-message-limit', '-dump-c-flags'] {
		option_case := os.join_path(root, option.trim_left('-'))
		os.mkdir_all(option_case)!
		output := os.join_path(option_case, 'out')
		result := run_driver_in_work_folder(v3_bin,
			['-silent', option, 'doc', '-o', output, source], option_case)
		assert result.exit_code == 0, '${option}: ${result.output}'
		assert os.is_file(output), option
		assert option != '-dump-c-flags' || os.is_file(os.join_path(option_case, 'doc'))
	}
}

fn test_driver_no_skip_unused_bypasses_warm_cgen_cache() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_no_skip_unused_cache_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	source := os.join_path(root, 'main.v')
	os.write_file(source, "fn unused_value() int { return 42 }\n\nfn main() { println('ok') }\n")!
	mut environment := os.environ()
	environment['VTMP'] = os.join_path(root, 'vtmp')
	environment['V3CACHE'] = os.join_path(root, 'cache')

	cold_output := os.join_path(root, 'cold')
	cold := run_driver_with_environment(v3_bin, ['-no-parallel', '-o', cold_output, source],
		environment)
	assert cold.exit_code == 0, cold.output
	assert !cold.output.contains('(cached)'), cold.output

	warm_output := os.join_path(root, 'warm')
	warm := run_driver_with_environment(v3_bin, ['-no-parallel', '-o', warm_output, source],
		environment)
	assert warm.exit_code == 0, warm.output
	assert warm.output.contains('cgen (cached)'), warm.output

	no_skip_output := os.join_path(root, 'no_skip')
	no_skip := run_driver_with_environment(v3_bin, ['-no-parallel', '-no-skip-unused', '-o',
		no_skip_output, source], environment)
	assert no_skip.exit_code == 0, no_skip.output
	assert !no_skip.output.contains('(cached)'), no_skip.output
	no_skip_run := cmdexec.run(no_skip_output, [])
	assert no_skip_run.exit_code == 0, no_skip_run.output
	assert no_skip_run.output == 'ok\n', no_skip_run.output
}

fn test_driver_valued_define_activates_optional_flag_and_source_suffix() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_valued_define_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	project := os.join_path(root, 'project')
	os.mkdir_all(project)!
	os.write_file(os.join_path(project, 'main.v'), "module main

fn main() {
	\$if feature ? {
		println('optional:on')
	} \$else {
		println('optional:off')
	}
	println(feature_source())
	println(\$d('feature', 'missing'))
}
")!
	os.write_file(os.join_path(project, 'source_d_feature.v'), "module main

fn feature_source() string {
	return 'source:on'
}
")!
	os.write_file(os.join_path(project, 'source_notd_feature.v'), "module main

fn feature_source() string {
	return 'source:off'
}
")!
	for define_option in ['-d', '-define'] {
		output := os.join_path(root, 'app_${define_option.trim_left('-')}')
		compile := cmdexec.run(v3_bin, ['-nocache', define_option, 'feature=enabled', '-o', output,
			project])
		assert compile.exit_code == 0, '${define_option}: ${compile.output}'
		run := cmdexec.run(output, [])
		assert run.exit_code == 0, '${define_option}: ${run.output}'
		assert run.output == 'optional:on\nsource:on\nenabled\n', '${define_option}: ${run.output}'
	}
}

fn test_driver_explicit_silent_define_is_distinct_from_internal_quiet_mode() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_silent_define_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	source := os.join_path(root, 'main.v')
	os.write_file(source,
		"@[if silent ?]\nfn print_silent_attribute() {\n\tprintln('attribute silent')\n}\n\nfn main() {\n\t\$if silent ? {\n\t\tprintln('silent')\n\t} \$else {\n\t\tprintln('not silent')\n\t}\n\tprint_silent_attribute()\n}\n")!

	for option, expected in {
		'-silent':                  'silent\nattribute silent\n'
		'-macos-v3-internal-quiet': 'not silent\n'
	} {
		output := os.join_path(root, option.trim_left('-'))
		compile := cmdexec.run(v3_bin, [option, '-o', output, source])
		assert compile.exit_code == 0, '${option}: ${compile.output}'
		run := cmdexec.run(output, [])
		assert run.exit_code == 0, '${option}: ${run.output}'
		assert run.output == expected, '${option}: ${run.output}'
	}
}

fn test_driver_compiles_inline_assembly_without_compatibility() {
	$if amd64 || arm64 {
		root := os.join_path(os.vtmp_dir(), 'v3_driver_inline_asm_fallback_${os.getpid()}')
		os.rmdir_all(root) or {}
		os.mkdir_all(root) or { panic(err) }
		defer {
			os.rmdir_all(root) or {}
		}
		v3_bin := build_driver_cli_v3(root)
		source := os.join_path(root, 'inline_asm.v')
		arch := pref.host_arch()
		os.write_file(source, 'fn main() {
	asm ${arch} {
		nop
	}
}
')!
		fallback_file := os.join_path(root, 'fallback')
		mut environment := os.environ()
		// Keep the marker available to prove that supported assembly does not request
		// a compatibility retry.
		environment.delete('V_MACOS_V3_NO_FALLBACK')
		environment['V_MACOS_V3_FALLBACK_FILE'] = fallback_file
		output := os.join_path(root, 'inline_asm_program')
		result := run_driver_with_environment(v3_bin, ['-silent', '-no-parallel', '-o', output,
			source], environment)
		assert result.exit_code == 0, result.output
		assert !os.exists(fallback_file)
		run := cmdexec.run(output, [])
		assert run.exit_code == 0, run.output
		environment['V_MACOS_V3_FALLBACK_FILE'] = fallback_file
		environment_source := os.join_path(root, 'fallback_environment.v')
		os.write_file(environment_source, "import os

const compile_fallback = \$env('V_MACOS_V3_FALLBACK_FILE')

fn main() {
	println(compile_fallback + '|' + os.getenv('V_MACOS_V3_FALLBACK_FILE'))
}
")!
		environment_run := run_driver_with_environment(v3_bin, ['-silent', '-no-parallel',
			'-no-memory-limit', 'run', environment_source], environment)
		assert environment_run.exit_code == 0, environment_run.output
		assert environment_run.output == '|\n', environment_run.output
		assert !os.exists(fallback_file)
	}
}

fn test_linux_pool_limit_stays_out_of_run_environment() {
	$if linux {
		root := os.join_path(os.vtmp_dir(), 'v3_driver_pool_environment_${os.getpid()}')
		os.rmdir_all(root) or {}
		os.mkdir_all(root) or { panic(err) }
		defer {
			os.rmdir_all(root) or {}
		}
		v3_bin := build_driver_cli_v3_with_flags(root, ['-prealloc', '-parallel-cc'])
		source := os.join_path(root, 'pool_environment.v')
		os.write_file(source, "import os

const compile_pool_limit = \$env('V3_INTERNAL_POOL_SIZE_LIMIT')

fn main() {
	println(compile_pool_limit + '|' + os.getenv('V3_INTERNAL_POOL_SIZE_LIMIT'))
}
")!
		mut environment := os.environ()
		environment.delete('V3_INTERNAL_POOL_SIZE_LIMIT')
		environment['VJOBS'] = '8'
		run := run_driver_with_environment(v3_bin, ['-nocache', '-no-memory-limit', '-v', 'run',
			source], environment)
		assert run.exit_code == 0, run.output
		assert run.output.split_into_lines().any(it == '|'), run.output
		assert run.output.contains('persistent worker threads    3 threads'), run.output
	}
}

fn test_driver_compiles_chained_generic_calls_without_compatibility() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_language_fallback_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	source := os.join_path(root, 'generic_fn_call.v')
	os.write_file(source, 'struct Opt[T] {
	val T
	some bool
}

fn some[T](val T) Opt[T] {
	return Opt[T]{
		val: val
		some: true
	}
}

fn (f Opt[T]) map[U](op fn (T) U) Opt[U] {
	if f.some {
		return some[U](op(f.val))
	}
	return Opt[U]{}
}

fn main() {
	result := some("hello").map(|s| s.len)
	assert result.some && result.val == 5
}
')!
	fallback_file := os.join_path(root, 'fallback')
	mut environment := os.environ()
	// Keep the marker available to prove that the valid generic chain does not
	// request a compatibility retry.
	environment.delete('V_MACOS_V3_NO_FALLBACK')
	environment['V_MACOS_V3_FALLBACK_FILE'] = fallback_file
	output := os.join_path(root, 'generic_fn_call')
	result := run_driver_with_environment(v3_bin, ['-silent', '-no-parallel', '-nocache',
		'-no-memory-limit', '-o', output, source], environment)
	assert result.exit_code == 0, result.output
	assert !os.exists(fallback_file)
	run := cmdexec.run(output, [])
	assert run.exit_code == 0, run.output

	nonzero_source := os.join_path(root, 'nonzero_run.v')
	os.write_file(nonzero_source, 'fn main() {
	exit(23)
}
')!
	nonzero_run := run_driver_with_environment(v3_bin, ['-silent', '-no-parallel', '-nocache',
		'-no-memory-limit', 'run', nonzero_source], environment)
	assert nonzero_run.exit_code == 23, nonzero_run.output
	assert !os.exists(fallback_file)
}

fn test_driver_requests_macos_compatibility_for_c_compilation_errors() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_c_error_fallback_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	source := os.join_path(root, 'missing_symbol.c.v')
	os.write_file(source, 'fn C.v3_missing_symbol()

fn main() {
	C.v3_missing_symbol()
}
')!
	fallback_file := os.join_path(root, 'fallback')
	report_dir := os.join_path(root, 'c_error')
	mut environment := os.environ()
	// Exercises the fallback transport, so clear CI's job-level no-fallback guard.
	environment.delete('V_MACOS_V3_NO_FALLBACK')
	environment['V_MACOS_V3_FALLBACK_FILE'] = fallback_file
	environment['V_MACOS_V3_C_ERROR_DIR'] = report_dir
	result := run_driver_with_environment(v3_bin, ['-silent', '-no-parallel', '-nocache',
		'-no-memory-limit', source], environment)
	assert result.exit_code != 0
	assert result.output == '', result.output
	assert os.read_file(fallback_file)! == 'c_compilation_error'
	assert os.read_file(os.join_path(report_dir, 'compiler'))!.trim_space() != ''
	assert os.read_file(os.join_path(report_dir, 'output'))!.to_lower().contains('v3_missing_symbol')
	source_name := os.read_file(os.join_path(report_dir, 'source_name'))!.trim_space()
	assert source_name == 'src.c'
	assert os.is_file(os.join_path(report_dir, source_name))
	v_sources := os.read_file(os.join_path(report_dir, 'v_sources'))!.split('\x00')
	assert os.real_path(source) in v_sources
}

fn test_driver_cg_selects_debug_module_files() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_cg_debug_files_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	project := os.join_path(root, 'project')
	variant_dir := os.join_path(project, 'variant')
	os.mkdir_all(variant_dir) or { panic(err) }
	os.write_file(os.join_path(project, 'v.mod'), "Module {
	name: 'debug_file_selection'
}
")!
	os.write_file(os.join_path(project, 'main.v'), 'module main

import variant

fn main() {
	println(variant.selected())
}
')!
	os.write_file(os.join_path(variant_dir, 'variant_d_debug.v'), "module variant

pub fn selected() string {
	return 'debug'
}
")!
	os.write_file(os.join_path(variant_dir, 'variant_notd_debug.v'), "module variant

pub fn selected() string {
	return 'release'
}
")!
	output := os.join_path(root, 'debug_file_selection')
	compile := cmdexec.run(v3_bin, ['-silent', '-no-parallel', '-no-memory-limit', '-cg', '-o',
		output, project])
	assert compile.exit_code == 0, compile.output
	run := cmdexec.run(output, [])
	assert run.exit_code == 0, run.output
	assert run.output == 'debug\n', run.output
}

fn test_driver_propagates_default_compiler_and_hash_pseudos() {
	$if macos {
		root := os.join_path(os.vtmp_dir(), 'v3_driver_compiler_hashes_${os.getpid()}')
		os.rmdir_all(root) or {}
		os.mkdir_all(root) or { panic(err) }
		defer {
			os.rmdir_all(root) or {}
		}
		v3_bin := build_driver_cli_v3(root)
		project := os.join_path(root, 'project')
		module_dir := os.join_path(project, 'compilerinfo')
		os.mkdir_all(module_dir) or { panic(err) }
		os.write_file(os.join_path(project, 'v.mod'), "Module {
	name: 'compiler_hash_selection'
}
")!
		os.write_file(os.join_path(project, 'main.v'), 'module main

import compilerinfo
import os

fn main() {
	println(compilerinfo.values().join("|"))
	println(os.getenv("V_MACOS_V3_VHASH") + "|" + os.getenv("V_MACOS_V3_VCURRENT_HASH"))
}
')!
		os.write_file(os.join_path(module_dir, 'compilerinfo.v'), 'module compilerinfo

pub fn values() []string {
	mut rows := []string{}
	$if clang {
		rows << "clang"
	} $else $if gcc {
		rows << "gcc"
	} $else {
		rows << "other"
	}
	rows << @CCOMPILER
	rows << @VHASH
	rows << @VCURRENTHASH
	$if @VHASH == "delegated-build-hash" && @VCURRENTHASH == "delegated-current-hash" {
		rows << "hash-condition"
	}
	return rows
}
')!
		output := os.join_path(root, 'compiler_hash_selection')
		mut environment := os.environ()
		environment['V_MACOS_V3_VHASH'] = 'delegated-build-hash'
		environment['V_MACOS_V3_VCURRENT_HASH'] = 'delegated-current-hash'
		environment['V3CACHE'] = os.join_path(root, 'cache')
		compile := run_driver_with_environment(v3_bin, ['-silent', '-no-parallel', '-no-memory-limit',
			'-o', output, 'run', project], environment)
		assert compile.exit_code == 0, compile.output
		assert compile.output == 'clang|clang|delegated-build-hash|delegated-current-hash|hash-condition\n|\n', compile.output

		run := cmdexec.run(output, [])
		assert run.exit_code == 0, run.output
		assert run.output == 'clang|clang|delegated-build-hash|delegated-current-hash|hash-condition\n|\n', run.output

		environment['V_MACOS_V3_VHASH'] = 'second-build-hash'
		environment['V_MACOS_V3_VCURRENT_HASH'] = 'second-current-hash'
		second_output := os.join_path(root, 'compiler_hash_selection_second')
		second_compile := run_driver_with_environment(v3_bin, ['-silent', '-no-parallel',
			'-no-memory-limit', '-o', second_output, project], environment)
		assert second_compile.exit_code == 0, second_compile.output
		second_run := cmdexec.run(second_output, [])
		assert second_run.exit_code == 0, second_run.output
		assert second_run.output == 'clang|clang|second-build-hash|second-current-hash\n|\n', second_run.output
	}
}

fn test_driver_preserves_macos_launcher_caller_environment() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_caller_environment_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	source := os.join_path(root, 'caller_environment.v')
	os.write_file(source, "import os

const compile_vexe = \$env('VEXE')
const compile_vchild = \$env('VCHILD')
const compile_no_fallback = \$env('V_MACOS_V3_NO_FALLBACK')
const compile_private = \$env('V_MACOS_V3_CALLER_VEXE')
const compile_c_error_dir = \$env('V_MACOS_V3_C_ERROR_DIR')
const compile_crun_identity = \$env('V3_CRUN_BUILD_IDENTITY')
const compile_internal_restart = \$env('V3_INTERNAL_RESTART')

fn env_value(name string) string {
	return os.getenv_opt(name) or { '<unset>' }
}

fn main() {
	println('compile:' + compile_vexe + '|' + compile_vchild)
	println('no-fallback:' + compile_no_fallback + '|' + env_value('V_MACOS_V3_NO_FALLBACK'))
	println('runtime:' + env_value('VEXE') + '|' + env_value('VCHILD'))
	println('private:' + compile_private + '|' + env_value('V_MACOS_V3_CALLER_VEXE') + '|' +
		env_value('V_MACOS_V3_CALLER_VCHILD'))
	println('c-error-dir:' + compile_c_error_dir + '|' + env_value('V_MACOS_V3_C_ERROR_DIR'))
	println('crun-private:' + compile_crun_identity + '|' + compile_internal_restart + '|' +
		env_value('V3_CRUN_BUILD_IDENTITY') + '|' + env_value('V3_INTERNAL_RESTART'))
}
")!
	cache_dir := os.join_path(root, 'cache')
	mut unset_environment := os.environ()
	unset_environment['VEXE'] = @VEXE
	unset_environment['VCHILD'] = 'true'
	unset_environment['V_MACOS_V3_CALLER_VEXE'] = ''
	unset_environment['V_MACOS_V3_CALLER_VEXE_PRESENT'] = '0'
	unset_environment['V_MACOS_V3_CALLER_VCHILD'] = ''
	unset_environment['V_MACOS_V3_CALLER_VCHILD_PRESENT'] = '0'
	unset_environment['V_MACOS_V3_NO_FALLBACK'] = '1'
	unset_environment['V_MACOS_V3_CALLER_NO_FALLBACK'] = ''
	unset_environment['V_MACOS_V3_CALLER_NO_FALLBACK_PRESENT'] = '0'
	unset_environment['V_MACOS_V3_C_ERROR_DIR'] = os.join_path(root, 'private-c-error')
	unset_environment['V3_CRUN_BUILD_IDENTITY'] = 'private-crun-identity'
	unset_environment['V3_INTERNAL_RESTART'] = '1'
	unset_environment['V3CACHE'] = cache_dir
	unset_output := os.join_path(root, 'caller_unset')
	unset_run := run_driver_with_environment(v3_bin, ['-silent', '-no-parallel', '-no-memory-limit',
		'-o', unset_output, 'run', source], unset_environment)
	assert unset_run.exit_code == 0, unset_run.output
	assert unset_run.output == 'compile:|\nno-fallback:|<unset>\nruntime:<unset>|<unset>\nprivate:|<unset>|<unset>\nc-error-dir:|<unset>\ncrun-private:||<unset>|<unset>\n', unset_run.output

	mut set_environment := unset_environment.clone()
	set_environment['V_MACOS_V3_CALLER_VEXE'] = 'caller-vexe'
	set_environment['V_MACOS_V3_CALLER_VEXE_PRESENT'] = '1'
	set_environment['V_MACOS_V3_CALLER_VCHILD'] = 'caller-vchild'
	set_environment['V_MACOS_V3_CALLER_VCHILD_PRESENT'] = '1'
	set_environment['V_MACOS_V3_CALLER_NO_FALLBACK'] = 'caller-no-fallback'
	set_environment['V_MACOS_V3_CALLER_NO_FALLBACK_PRESENT'] = '1'
	set_output := os.join_path(root, 'caller_set')
	set_run := run_driver_with_environment(v3_bin, ['-silent', '-no-parallel', '-no-memory-limit',
		'-o', set_output, 'run', source], set_environment)
	assert set_run.exit_code == 0, set_run.output
	assert set_run.output == 'compile:caller-vexe|caller-vchild\nno-fallback:caller-no-fallback|caller-no-fallback\nruntime:caller-vexe|caller-vchild\nprivate:|<unset>|<unset>\nc-error-dir:|<unset>\ncrun-private:||<unset>|<unset>\n', set_run.output
}

fn test_driver_resolves_boolean_d_and_documented_pseudos() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_comptime_values_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	project := os.join_path(root, 'project')
	git_refs := os.join_path(project, '.git', 'refs', 'heads')
	os.mkdir_all(git_refs) or { panic(err) }
	os.write_file(os.join_path(project, 'v.mod'), "Module { name: 'driver_comptime_values' }\n")!
	os.write_file(os.join_path(project, '.git', 'HEAD'), 'ref: refs/heads/main\n')!
	os.write_file(os.join_path(git_refs, 'main'), '0123456789abcdef0123456789abcdef01234567\n')!
	source := os.join_path(project, 'main.v')
	os.write_file(source, "module main

const enabled = \$d('feature', false)
const column = @COLUMN
const project_hash = @VMODHASH
const legacy_root_matches = @VROOT == @VEXEROOT
const column_condition = \$if @COLUMN != '' { true } \$else { false }
const hash_condition = \$if @VMODHASH == '0123456' { true } \$else { false }
const legacy_root_condition = \$if @VROOT == @VEXEROOT { true } \$else { false }

fn main() {
	println(enabled)
	println(column)
	println(project_hash)
	println(legacy_root_matches)
	println(column_condition)
	println(hash_condition)
	println(legacy_root_condition)
}
")!
	for i, define_args in [
		['-d', 'feature'],
		['-dfeature'],
	] {
		output := os.join_path(root, 'comptime_values_${i}')
		mut args := define_args.clone()
		args << ['-silent', '-no-parallel', '-o', output, source]
		compile := cmdexec.run(v3_bin, args)
		assert compile.exit_code == 0, compile.output
		run := cmdexec.run(output, [])
		assert run.exit_code == 0, run.output
		assert run.output == 'true\n16\n0123456\ntrue\ntrue\ntrue\ntrue\n', run.output
	}
	os.write_file(os.join_path(git_refs, 'main'), 'abcdef0123456789abcdef0123456789abcdef01\n')!
	updated_output := os.join_path(root, 'comptime_values_updated_hash')
	updated_compile := cmdexec.run(v3_bin, ['-d', 'feature', '-silent', '-no-parallel', '-o',
		updated_output, source])
	assert updated_compile.exit_code == 0, updated_compile.output
	updated_run := cmdexec.run(updated_output, [])
	assert updated_run.exit_code == 0, updated_run.output
	assert updated_run.output == 'true\n16\nabcdef0\ntrue\ntrue\nfalse\ntrue\n', updated_run.output

	invalid_source := os.join_path(project, 'invalid_define.v')
	os.write_file(invalid_source, "module main

const value = \$d('feature', 1)

fn main() {
	println(value)
}
")!
	assert_driver_cli_failure(v3_bin, ['-d', 'feature', '-silent', '-no-parallel', invalid_source],
		'i64 literal expected, found "true"')
}

fn test_delegated_driver_preserves_invoking_vroot() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_invoking_vroot_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	other_checkout := os.join_path(root, 'other_checkout')
	os.mkdir_all(os.join_path(other_checkout, 'vlib', 'builtin')) or { panic(err) }
	source := os.join_path(other_checkout, 'main.v')
	os.write_file(source, 'module main

fn main() {
	println(@VEXEROOT)
	println(@VROOT)
	println(\$if @VROOT == @VEXEROOT { true } \$else { false })
}
')!
	output := os.join_path(root, 'invoking_vroot')
	mut environment := os.environ()
	environment['VEXE'] = @VEXE
	environment['V_MACOS_V3_CALLER_VEXE'] = ''
	environment['V_MACOS_V3_CALLER_VEXE_PRESENT'] = '0'
	environment['V_MACOS_V3_CALLER_VCHILD'] = ''
	environment['V_MACOS_V3_CALLER_VCHILD_PRESENT'] = '0'
	compile := run_driver_with_environment(v3_bin, ['-nocache', '-silent', '-no-parallel', '-o',
		output, source], environment)
	assert compile.exit_code == 0, compile.output
	run := cmdexec.run(output, [])
	assert run.exit_code == 0, run.output
	invoking_root := os.real_path(os.dir(@VEXE))
	assert run.output == '${invoking_root}\n${invoking_root}\ntrue\n', run.output
}

fn test_driver_run_preserves_stdin() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_stdin_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	source := os.join_path(root, 'stdin_program.v')
	output := os.join_path(root, 'stdin_program')
	input_file := os.join_path(root, 'input.txt')
	os.write_file(source, "import os\n\nfn main() { println('read:' + os.input('')) }\n")!
	os.write_file(input_file, 'from-stdin\n')!
	result := run_driver_with_stdin_file(v3_bin, ['-o', output, 'run', source], input_file)
	assert result.exit_code == 0, result.output
	assert result.output.contains('read:from-stdin'), result.output
}

fn test_explicit_c_backend_retains_complete_cached_translation_unit() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_retained_c_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	module_dir := os.join_path(root, 'retainedmod')
	os.mkdir_all(module_dir) or { panic(err) }
	os.write_file(os.join_path(module_dir, 'retainedmod.v'),
		"module retainedmod\n\npub fn message() string {\n\treturn 'complete cached translation unit'\n}\n")!
	source := os.join_path(root, 'main.v')
	os.write_file(source,
		'module main\n\nimport retainedmod\n\nfn main() {\n\tprintln(retainedmod.message())\n}\n')!
	mut environment := os.environ()
	environment['V3CACHE'] = os.join_path(root, 'cache')
	mut retained_c := ''
	for build_name in ['cold', 'warm'] {
		output := os.join_path(root, build_name)
		compile := run_driver_with_environment(v3_bin, ['-silent', '-no-parallel', '-b', 'c', '-o',
			output, source], environment)
		assert compile.exit_code == 0, compile.output
		retained_c = output + '.c'
		assert os.is_file(retained_c)
	}
	retained_source := os.read_file(retained_c)!
	assert retained_source.contains('retainedmod__message'), retained_source
	assert retained_source.contains('complete cached translation unit'), retained_source
	$if !windows {
		rebuilt := os.join_path(root, 'rebuilt_from_retained_c')
		rebuild := cmdexec.run('cc', ['-std=gnu11', '-w', '-o', rebuilt, retained_c, '-lm'])
		assert rebuild.exit_code == 0, rebuild.output
		run := cmdexec.run(rebuilt, [])
		assert run.exit_code == 0, run.output
		assert run.output == 'complete cached translation unit\n', run.output
	}
}

fn test_driver_accepts_dispatcher_arguments_and_runs_vsh_files() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_vsh_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3_with_flags(root, ['-prealloc'])
	program := os.join_path(root, 'dispatcher_build.v')
	binary := os.join_path(root, 'dispatcher_build')
	os.write_file(program, "println('built')")!
	build := cmdexec.run(v3_bin, ['-silent', '-no-parallel', '-cstrict', '-skip-running', '-usecache',
		'build', '-o', binary, program])
	assert build.exit_code == 0, build.output
	assert !os.exists(binary + '.c')
	built := cmdexec.run(binary, [])
	assert built.exit_code == 0, built.output
	assert built.output == 'built\n', built.output
	implicit_program := os.join_path(root, 'implicit_build.v')
	implicit_binary := os.join_path(root, 'implicit_build')
	implicit_c := implicit_binary + '.c'
	os.write_file(implicit_program, "println('implicit')")!
	os.write_file(implicit_c, 'existing C source')!
	implicit_build := cmdexec.run(v3_bin, ['-silent', '-no-parallel', implicit_program])
	assert implicit_build.exit_code == 0, implicit_build.output
	assert os.is_file(implicit_binary)
	assert os.read_file(implicit_c)! == 'existing C source'
	showcc_binary := os.join_path(root, 'showcc_build')
	showcc_build := cmdexec.run(v3_bin, ['-silent', '-showcc', '-no-parallel', '-o', showcc_binary,
		implicit_program])
	assert showcc_build.exit_code == 0, showcc_build.output
	assert showcc_build.output.contains('  > '), showcc_build.output
	assert !showcc_build.output.contains('=== v3 benchmark ==='), showcc_build.output
	assert !showcc_build.output.contains('MB RSS'), showcc_build.output
	keep_c_dir := os.join_path(root, 'kept_c')
	os.mkdir(keep_c_dir)!
	mut keep_c_environment := os.environ()
	keep_c_environment['VTMP'] = keep_c_dir
	keep_c_build := run_driver_with_environment(v3_bin, ['-silent', '-no-parallel', '-keepc',
		implicit_program], keep_c_environment)
	assert keep_c_build.exit_code == 0, keep_c_build.output
	assert os.read_file(implicit_c)! == 'existing C source'
	kept_files := kept_c_files(keep_c_dir)
	assert kept_files.len == 1, kept_files.str()
	assert os.file_size(kept_files[0]) > 0
	assert os.file_name(kept_files[0]).starts_with('implicit_build.')
	keep_c_module_dir := os.join_path(root, 'keepcmod')
	os.mkdir_all(keep_c_module_dir)!
	os.write_file(os.join_path(keep_c_module_dir, 'keepcmod.v'), "module keepcmod

pub fn message() string {
	return 'cached module code retained'
}
")!
	keep_c_module_program := os.join_path(root, 'keepc_modules.v')
	keep_c_module_binary := keep_c_module_program.all_before_last('.v')
	os.write_file(keep_c_module_program, 'import keepcmod

fn main() {
	println(keepcmod.message())
}
')!
	keep_c_environment['V3CACHE'] = os.join_path(root, 'keepc_cache')
	keep_c_module_build := run_driver_with_environment(v3_bin, ['-silent', '-no-parallel', '-keepc',
		keep_c_module_program], keep_c_environment)
	assert keep_c_module_build.exit_code == 0, keep_c_module_build.output
	keep_c_module_run := cmdexec.run(keep_c_module_binary, [])
	assert keep_c_module_run.exit_code == 0, keep_c_module_run.output
	assert keep_c_module_run.output == 'cached module code retained\n', keep_c_module_run.output
	kept_module_files :=
		kept_c_files(keep_c_dir).filter(os.file_name(it).starts_with('keepc_modules.'))
	assert kept_module_files.len == 1, kept_module_files.str()
	kept_module_source := os.read_file(kept_module_files[0])!
	assert kept_module_source.contains('keepcmod__message'), kept_module_source
	assert kept_module_source.contains('cached module code retained'), kept_module_source
	run_program := os.join_path(root, 'implicit_run.v')
	run_binary := run_program.all_before_last('.v')
	os.write_file(run_program, "println('ran once')")!
	implicit_run := cmdexec.run(v3_bin, ['-silent', '-no-parallel', 'run', run_program])
	assert implicit_run.exit_code == 0, implicit_run.output
	assert implicit_run.output == 'ran once\n', implicit_run.output
	assert !os.exists(run_binary)
	assert !os.exists(run_binary + '.c')
	$if !windows {
		interrupted_program := os.join_path(root, 'interrupted_run.v')
		interrupted_binary := interrupted_program.all_before_last('.v')
		interrupted_marker := os.join_path(root, 'interrupted_run_started')
		os.write_file(interrupted_program, "import os

fn main() {
	os.write_file('${interrupted_marker}', 'started') or { exit(2) }
	for {}
}
")!
		mut interrupted_run := os.new_process(v3_bin)
		interrupted_run.use_pgroup = true
		interrupted_run.set_args(['-silent', '-no-parallel', 'run', interrupted_program])
		interrupted_run.run()
		mut interrupted_started := false
		for _ in 0 .. 600 {
			if os.exists(interrupted_marker) {
				interrupted_started = true
				break
			}
			if !interrupted_run.is_alive() {
				break
			}
			time.sleep(100 * time.millisecond)
		}
		if !interrupted_started {
			if interrupted_run.is_alive() {
				interrupted_run.signal_pgkill()
			}
			interrupted_run.wait()
			run_error := interrupted_run.err
			interrupted_run.close()
			assert false, 'interrupted run did not start: ${run_error}'
		}
		interrupt := os.execute('kill -INT -${interrupted_run.pid}')
		if interrupt.exit_code != 0 {
			interrupted_run.signal_pgkill()
			interrupted_run.wait()
			interrupted_run.close()
			assert false, interrupt.output
		}
		interrupted_run.wait()
		interrupted_exit_code := interrupted_run.code
		interrupted_run.close()
		assert interrupted_exit_code != 0
		assert !os.exists(interrupted_binary)
	}
	debug_define_program := os.join_path(root, 'debug_define.v')
	os.write_file(debug_define_program, '@[if debug]
fn enabled_by_define() {
	println("attribute debug")
}

fn main() {
	$if debug {
		println("comptime debug")
	}
	enabled_by_define()
}
')!
	debug_define_run := cmdexec.run(v3_bin, ['-silent', '-no-parallel', '-d', 'debug', 'run',
		debug_define_program])
	assert debug_define_run.exit_code == 0, debug_define_run.output
	assert debug_define_run.output == 'attribute debug\n', debug_define_run.output
	crun_module_dir := os.join_path(root, 'crunmod')
	crun_module_file := os.join_path(crun_module_dir, 'crunmod.v')
	os.mkdir_all(crun_module_dir)!
	os.write_file(crun_module_file, "module crunmod

pub fn message() string {
	return 'cached module'
}
")!
	source := os.join_path(root, 'implicit_script.vsh')
	os.write_file(source, "import crunmod
import os

println(os.executable().ends_with('.vsh'))
println(crunmod.message())
println(os.args[1..].join('|'))
")!
	run := cmdexec.run(v3_bin, ['-silent', '-no-parallel', source, 'one', '--two'])
	assert run.exit_code == 0, run.output
	assert run.output == 'false\ncached module\none|--two\n', run.output
	script_binary := source.all_before_last('.vsh')
	assert os.is_file(script_binary)
	assert !os.exists(source.all_before_last('.vsh') + '.c')
	warm_cache_run := cmdexec.run(v3_bin, ['-silent', '-no-parallel', source, 'warm'])
	assert warm_cache_run.exit_code == 0, warm_cache_run.output
	assert warm_cache_run.output == 'false\ncached module\nwarm\n', warm_cache_run.output
	compat_source := os.join_path(root, 'compat_script_binary.v')
	os.write_file(compat_source, "fn main() {
	println('compatibility binary')
}
")!
	compat_build := cmdexec.run(@VEXE, ['-old-compiler', '-o', script_binary, compat_source])
	assert compat_build.exit_code == 0, compat_build.output
	compat_run := cmdexec.run(script_binary, [])
	assert compat_run.exit_code == 0, compat_run.output
	assert compat_run.output == 'compatibility binary\n', compat_run.output
	rebound_v3_run := cmdexec.run(v3_bin,
		['-silent', '-no-parallel', source, 'after-compatibility'])
	assert rebound_v3_run.exit_code == 0, rebound_v3_run.output
	assert rebound_v3_run.output == 'false\ncached module\nafter-compatibility\n', rebound_v3_run.output
	cache_stamp := os.file_last_mod_unix(script_binary) + 3600
	os.utime(script_binary, cache_stamp, cache_stamp)!
	cached_run := cmdexec.run(v3_bin, ['-silent', '-no-parallel', source, 'cached'])
	assert cached_run.exit_code == 0, cached_run.output
	assert cached_run.output == 'false\ncached module\ncached\n', cached_run.output
	assert os.file_last_mod_unix(script_binary) == cache_stamp
	os.write_file(crun_module_file, "module crunmod

pub fn message() string {
	return 'rebuilt module'
}
")!
	rebuilt_run := cmdexec.run(v3_bin, ['-silent', '-no-parallel', source, 'new'])
	assert rebuilt_run.exit_code == 0, rebuilt_run.output
	assert rebuilt_run.output == 'false\nrebuilt module\nnew\n', rebuilt_run.output
	assert os.file_last_mod_unix(script_binary) != cache_stamp
	explicit_run_source := os.join_path(root, 'explicit_run_script.vsh')
	explicit_run_binary := explicit_run_source.all_before_last('.vsh')
	os.write_file(explicit_run_source, "println('explicit run')")!
	explicit_run := cmdexec.run(v3_bin, ['-silent', '-no-parallel', 'run', explicit_run_source])
	assert explicit_run.exit_code == 0, explicit_run.output
	assert explicit_run.output == 'explicit run\n', explicit_run.output
	assert !os.exists(explicit_run_binary)
	compile_only_source := os.join_path(root, 'compile_only.vsh')
	compile_only_binary := compile_only_source.all_before_last('.vsh')
	run_marker := os.join_path(root, 'compile_only_ran')
	os.write_file(compile_only_source, "import os

os.write_file('${run_marker}', 'ran')!
")!
	skip_run := cmdexec.run(v3_bin,
		['-silent', '-no-parallel', '-skip-running', compile_only_source])
	assert skip_run.exit_code == 0, skip_run.output
	assert os.is_file(compile_only_binary)
	assert !os.exists(run_marker)
	os.rm(compile_only_binary)!
	build_script := cmdexec.run(v3_bin, ['-silent', '-no-parallel', 'build', compile_only_source])
	assert build_script.exit_code == 0, build_script.output
	assert os.is_file(compile_only_binary)
	assert !os.exists(run_marker)
}

fn assert_driver_wasm_output(path string) {
	bytes := os.read_bytes(path) or { panic(err) }
	assert bytes.len > 8
	assert bytes[..4] == [u8(0), 0x61, 0x73, 0x6d]
}

fn test_driver_platform_pseudo_uses_selected_target_arch() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_platform_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	source := os.join_path(root, 'platform.v')
	os.write_file(source, "fn main() {
	println(@PLATFORM)
	\$if @PLATFORM == 'amd64' {
		println('selected-amd64')
	} \$else \$if @PLATFORM == 'arm64' {
		println('selected-arm64')
	}
}
")!
	for target_arch, platform in {
		'x86_64': 'amd64'
		'arm64':  'arm64'
	} {
		output := os.join_path(root, 'platform_${platform}.c')
		compile := cmdexec.run(v3_bin, ['-nocache', '-no-parallel', '-os', 'macos', '-arch',
			target_arch, '-o', output, source])
		assert compile.exit_code == 0, compile.output
		generated_c := os.read_file(output)!
		assert generated_c.contains('{"${platform}", ${platform.len}'), generated_c
		assert generated_c.contains('selected-${platform}'), generated_c
		other_platform := if platform == 'amd64' { 'arm64' } else { 'amd64' }
		assert !generated_c.contains('selected-${other_platform}'), generated_c
	}
}

fn test_wasm_backend_defaults_target_unless_explicit() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_wasm_target_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)

	default_dir := os.join_path(root, 'default_target')
	os.mkdir_all(default_dir) or { panic(err) }
	os.write_file(os.join_path(default_dir, 'main.v'), 'module main

\$if wasm32 {
fn wasm_arch_selected() {}
}

fn main() {
	wasm_os_selected()
	wasm_arch_selected()
}
') or {
		panic(err)
	}
	os.write_file(os.join_path(default_dir, 'target_wasm32_emscripten.v'),
		'module main\n\nfn wasm_os_selected() {}\n') or { panic(err) }
	default_output := os.join_path(root, 'default_target.wasm')
	default_compile := cmdexec.run(v3_bin, ['-b', 'wasm', '-o', default_output, default_dir])
	assert default_compile.exit_code == 0, default_compile.output
	assert_driver_wasm_output(default_output)

	host := pref.host_target()
	explicit_dir := os.join_path(root, 'explicit_target')
	os.mkdir_all(explicit_dir) or { panic(err) }
	os.write_file(os.join_path(explicit_dir, 'main.v'),
		'module main\n\nfn main() { host_os_selected() }\n') or { panic(err) }
	os.write_file(os.join_path(explicit_dir, 'target_${host.os}.v'),
		'module main\n\nfn host_os_selected() {}\n') or { panic(err) }
	explicit_output := os.join_path(root, 'explicit_target.wasm')
	explicit_compile := cmdexec.run(v3_bin, ['-b', 'wasm', '-os', host.os, '-arch', host.arch,
		'-o', explicit_output, explicit_dir])
	assert explicit_compile.exit_code == 0, explicit_compile.output
	assert_driver_wasm_output(explicit_output)
}

fn test_driver_rejects_invalid_cli_and_parses_vmod_subdirs() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_cli_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	source := os.join_path(root, 'hello.v')
	os.write_file(source, "fn main() { println('ok') }\n") or { panic(err) }

	path_output := os.join_path(root, 'hello_path')
	path_compile := cmdexec.run(v3_bin, ['-path', '${driver_cli_vlib_dir}|@vlib|@vmodules', '-o',
		path_output, source])
	assert path_compile.exit_code == 0, path_compile.output
	assert os.is_file(path_output)

	help := cmdexec.run(v3_bin, ['--help'])
	assert help.exit_code == 0
	assert help.output.contains('-cc <compiler>')
	assert help.output.contains('-no-memory-limit             disable the 3840 MiB memory safety limit')
	c_output := os.join_path(root, 'hello.c')
	c_compile := cmdexec.run(v3_bin, ['-no-memory-limit', '-o', c_output, source])
	assert c_compile.exit_code == 0, c_compile.output
	assert !c_compile.output.contains('[ttime]'), c_compile.output
	$if macos {
		rss_index := c_compile.output.index('MB RSS') or { -1 }
		footprint_index := c_compile.output.index('MB physical footprint') or { -1 }
		assert rss_index >= 0, c_compile.output
		assert footprint_index > rss_index, c_compile.output
	}
	c_source := os.read_file(c_output)!
	assert c_source.len > 100
	assert c_source.contains('typedef signed char i8;')
	verbose_output := os.join_path(root, 'hello_verbose.c')
	verbose_compile := cmdexec.run(v3_bin, ['-nocache', '-v', '-o', verbose_output, source])
	assert verbose_compile.exit_code == 0, verbose_compile.output
	assert verbose_compile.output.contains('[ttime]'), verbose_compile.output
	compat_output := os.join_path(root, 'hello_compat')
	kept_before := kept_c_files(os.vtmp_dir())
	compat_compile := cmdexec.run(v3_bin, ['-stats', '-show-timings', '-showcc', '-keepc', '-w',
		'-g', '-cflags', '-w', '-enable-globals', '-o', compat_output, source])
	assert compat_compile.exit_code == 0, compat_compile.output
	assert os.is_file(compat_output)
	assert !os.exists(compat_output + '.c')
	new_kept_files := kept_c_files(os.vtmp_dir()).filter(it !in kept_before
		&& os.file_name(it).starts_with('hello_compat.'))
	assert new_kept_files.len == 1, new_kept_files.str()
	os.rm(new_kept_files[0])!
	debug_source := os.join_path(root, 'debug_comptime.v')
	os.write_file(debug_source,
		"fn main() {\n\t\$if debug {\n\t\tprintln('debug')\n\t} \$else {\n\t\tprintln('release')\n\t}\n}\n") or {
		panic(err)
	}
	release_output := os.join_path(root, 'debug_comptime_release')
	release_compile := cmdexec.run(v3_bin, ['-o', release_output, debug_source])
	assert release_compile.exit_code == 0, release_compile.output
	release_run := cmdexec.run(release_output, [])
	assert release_run.exit_code == 0, release_run.output
	assert release_run.output.trim_space() == 'release'
	debug_output := os.join_path(root, 'debug_comptime_debug')
	debug_compile := cmdexec.run(v3_bin, ['-g', '-o', debug_output, debug_source])
	assert debug_compile.exit_code == 0, debug_compile.output
	debug_run := cmdexec.run(debug_output, [])
	assert debug_run.exit_code == 0, debug_run.output
	assert debug_run.output.trim_space() == 'debug'
	wasm_c_output := os.join_path(root, 'hello_emscripten.c')
	wasm_compile := cmdexec.run(v3_bin, ['-os', 'wasm32_emscripten', '-o', wasm_c_output, source])
	assert wasm_compile.exit_code == 0, wasm_compile.output
	assert os.is_file(wasm_c_output)
	assert_driver_cli_failure(v3_bin, ['-os', 'wasm32_emscripten', '-arch', 'arm64', '-o',
		wasm_c_output, source], 'target OS `wasm32_emscripten` requires architecture `wasm32`')
	bits_source := os.join_path(root, 'bits_fallback.v')
	os.write_file(bits_source, 'import math.bits

fn main() {
	hi, lo := bits.mul_64(u64(0xffffffffffffffff), u64(2))
	println(hi.str() + ":" + lo.str())
}
') or {
		panic(err)
	}
	bits_output := os.join_path(root, 'bits_fallback')
	bits_compile := cmdexec.run(v3_bin, ['-prod', '-o', bits_output, bits_source])
	assert bits_compile.exit_code == 0, bits_compile.output
	bits_run := cmdexec.run(bits_output, [])
	assert bits_run.exit_code == 0, bits_run.output
	assert bits_run.output.trim_space() == '1:18446744073709551614'

	file_list_dir := os.join_path(root, 'file_list_sources')
	file_list_nested_dir := os.join_path(file_list_dir, 'parts', 'nested')
	os.mkdir_all(file_list_nested_dir) or { panic(err) }
	os.write_file(os.join_path(file_list_dir, 'v.mod'),
		"Module {\n\tname: 'file_list_sources'\n\tsubdirs: ['parts']\n}\n") or { panic(err) }
	os.write_file(os.join_path(file_list_dir, 'root.v'),
		'module main\n\nfn file_list_root_value() int { return 20 }\n') or { panic(err) }
	os.write_file(os.join_path(file_list_nested_dir, 'nested.v'),
		'module main\n\nfn file_list_nested_value() int { return 22 }\n') or { panic(err) }
	file_list_main := os.join_path(root, 'file_list_main.v')
	os.write_file(file_list_main,
		'module main\n\nfn main() { println(file_list_root_value() + file_list_nested_value()) }\n') or {
		panic(err)
	}
	file_list_output := os.join_path(root, 'file_list_output')
	file_list_compile := cmdexec.run(v3_bin, ['-nocache', '-o', file_list_output, file_list_main,
		'-file-list', file_list_dir])
	assert file_list_compile.exit_code == 0, file_list_compile.output
	file_list_run := cmdexec.run(file_list_output, [])
	assert file_list_run.exit_code == 0, file_list_run.output
	assert file_list_run.output.trim_space() == '42'

	assert_driver_cli_failure(v3_bin, ['--bogus'], 'unknown option `--bogus`')
	assert_driver_cli_failure(v3_bin, ['-o'], 'option `-o` requires a value')
	assert_driver_cli_failure(v3_bin, ['-ldflags'], 'option `-ldflags` requires a value')
	assert_driver_cli_failure(v3_bin, ['-b', 'bogus', source], 'unknown backend `bogus`')
	assert_driver_cli_failure(v3_bin, ['-gc', 'boehm', source],
		'currently supports only `-gc none`')
	assert_driver_cli_failure(v3_bin, ['-d', 'gcboehm', source],
		'v3 programs must not use a garbage collector')
	assert_driver_cli_failure(v3_bin, ['-dvgc', source],
		'v3 programs must not use a garbage collector')
	assert_driver_cli_failure(v3_bin, [source, source], 'multiple input paths are not supported')
	assert_driver_cli_failure(v3_bin, ['-compile-backend', 'bogus', source],
		'unknown compile backend `bogus`')

	if false_exe := os.find_abs_path_of_executable('false') {
		cc_result := cmdexec.run(v3_bin, ['-prod', '-showcc', '-cc', false_exe, source, '-o',
			os.join_path(root, 'false_cc')])
		assert cc_result.exit_code != 0
		assert cc_result.output.contains(cmdexec.display(false_exe, ['-std=gnu11'])), cc_result.output
		assert cc_result.output.contains('-O3'), cc_result.output
		assert cc_result.output.contains('-flto'), cc_result.output
		assert !cc_result.output.contains('-O2'), cc_result.output
		custom_prod_result := cmdexec.run(v3_bin, ['-prod', '-no-prod-options', '-showcc', '-cc',
			false_exe, source, '-o', os.join_path(root, 'false_cc_custom_prod')])
		assert custom_prod_result.exit_code != 0
		assert !custom_prod_result.output.contains('-O3'), custom_prod_result.output
		assert !custom_prod_result.output.contains('-flto'), custom_prod_result.output
	}

	work_dir := os.join_path(root, 'work')
	project := os.join_path(root, 'project.with.dots')
	os.mkdir_all(os.join_path(project, 'one')) or { panic(err) }
	os.mkdir_all(os.join_path(project, 'two')) or { panic(err) }
	os.mkdir_all(work_dir) or { panic(err) }
	os.write_file(os.join_path(project, 'v.mod'), 'Module {\n' + "  name: 'driver_cli'\n" +
		"  description: 'subdirs: [wrong, value]'\n" + "  subdirs: ['one', 'two']\n" + '}\n') or {
		panic(err)
	}
	os.write_file(os.join_path(project, 'main.v'), 'module main

import collision

struct App {
	value int
	other string
}

fn main() {
	app := App{value: one()}
	println(app.value + collision.value())
}
') or {
		panic(err)
	}
	os.write_file(os.join_path(project, 'one', 'one.v'),
		'module main\n\nfn one() int { return 40 }\n') or { panic(err) }
	os.write_file(os.join_path(project, 'two', 'two.v'),
		'module main\n\nfn two() int { return 2 }\n') or { panic(err) }
	collision_dir := os.join_path(project, 'collision')
	os.mkdir_all(collision_dir) or { panic(err) }
	os.write_file(os.join_path(collision_dir, 'collision.v'), 'module collision

pub struct App {
pub:
	value int
}

pub fn value() int {
	return App{value: 2}.value
}
') or {
		panic(err)
	}

	compile := cmdexec.run_in(v3_bin, [project], work_dir)
	assert compile.exit_code == 0, compile.output
	output := os.join_path(project, 'project.with.dots')
	assert os.exists(output)
	assert !os.exists(os.join_path(work_dir, 'project.with.dots'))
	assert !os.exists(os.join_path(work_dir, 'project'))
	run := cmdexec.run(output, [])
	assert run.exit_code == 0
	assert run.output.trim_space() == '42'
}

fn test_driver_static_pkgconfig_fact_ldflags_and_dynamic_c_invariance() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_static_pkgconfig_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	source := os.join_path(root, 'main.v')
	os.write_file(source,
		"fn main() {\n\t\$if \$d('v:static_pkgconfig', false) {\n\t\tprintln('issue74-static-mode')\n\t} \$else {\n\t\tprintln('issue74-dynamic-mode')\n\t}\n}\n")!
	output_c := os.join_path(root, 'main.c')

	dynamic_first := cmdexec.run(v3_bin, ['-nocache', '-o', output_c, source])
	assert dynamic_first.exit_code == 0, dynamic_first.output
	dynamic_c := os.read_file(output_c)!
	assert dynamic_c.contains('issue74-dynamic-mode')
	assert !dynamic_c.contains('issue74-static-mode')

	dynamic_ldflags := cmdexec.run(v3_bin, ['-nocache', '-ldflags', '-Wl,--as-needed', '-o', output_c,
		source])
	assert dynamic_ldflags.exit_code == 0, dynamic_ldflags.output
	assert os.read_file(output_c)! == dynamic_c

	pairs := v3_cpp_linker_driver_pairs()
	mut static_args := ['-nocache', '-no-retry-compilation']
	if pairs.len > 0 {
		static_args << ['-cc', pairs[0].c, '-ldflags', '-static']
	} else {
		static_args << ['-cc', 'tcc']
	}
	static_args << ['-o', output_c, source]
	static_ldflags := cmdexec.run(v3_bin, static_args)
	assert static_ldflags.exit_code == 0, static_ldflags.output
	assert os.is_file(output_c)
	static_c := os.read_file(output_c)!
	if pairs.len > 0 {
		assert static_c.contains('issue74-static-mode')
		assert !static_c.contains('issue74-dynamic-mode')
	} else {
		assert static_c == dynamic_c
		assert static_c.contains('issue74-dynamic-mode')
		assert !static_c.contains('issue74-static-mode')
	}

	dynamic_again := cmdexec.run(v3_bin, ['-nocache', '-o', output_c, source])
	assert dynamic_again.exit_code == 0, dynamic_again.output
	assert os.read_file(output_c)! == dynamic_c

	for define in ['v:static_pkgconfig', 'v:static_pkgconfig=true', 'v_static_pkgconfig',
		'v_static_pkgconfig=true'] {
		assert_driver_cli_failure(v3_bin, ['-d', define, '-check', source],
			'is a read-only compiler value')
	}
}

struct V3CppDriverRecorderInvocation {
	driver string
	cwd    string
	args   []string
}

fn v3_cpp_driver_recorder_invocations(path string) []V3CppDriverRecorderInvocation {
	if !os.is_file(path) {
		return []
	}
	mut invocations := []V3CppDriverRecorderInvocation{}
	for line in os.read_lines(path) or { panic(err) } {
		if line.len == 0 {
			continue
		}
		invocations << json.decode(V3CppDriverRecorderInvocation, line) or { panic(err) }
	}
	return invocations
}

fn v3_cpp_driver_recorder_path(invocation V3CppDriverRecorderInvocation, path string) string {
	if os.is_abs_path(path) {
		return os.norm_path(path)
	}
	return os.norm_path(os.join_path(invocation.cwd, path))
}

fn v3_cpp_driver_recorder_output(invocation V3CppDriverRecorderInvocation) string {
	mut output := ''
	mut output_count := 0
	for index, arg in invocation.args {
		if arg != '-o' {
			continue
		}
		output_count++
		assert index + 1 < invocation.args.len, invocation.args.str()
		output = invocation.args[index + 1]
	}
	assert output_count == 1, invocation.args.str()
	assert output.len > 0, invocation.args.str()
	return v3_cpp_driver_recorder_path(invocation, output)
}

fn test_driver_cpp_linker_directive_is_exact_and_non_link_outputs_stay_c() {
	root := os.join_path(os.vtmp_dir(), 'v3_driver_cpp_linker_modes_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	old_cflags := os.getenv_opt('CFLAGS')
	old_ldflags := os.getenv_opt('LDFLAGS')
	old_vflags := os.getenv_opt('VFLAGS')
	old_recorder_log := os.getenv_opt('V3_CPP_LINKER_RECORDER_LOG')
	defer {
		if value := old_cflags {
			os.setenv('CFLAGS', value, true)
		} else {
			os.unsetenv('CFLAGS')
		}
		if value := old_ldflags {
			os.setenv('LDFLAGS', value, true)
		} else {
			os.unsetenv('LDFLAGS')
		}
		if value := old_vflags {
			os.setenv('VFLAGS', value, true)
		} else {
			os.unsetenv('VFLAGS')
		}
		if value := old_recorder_log {
			os.setenv('V3_CPP_LINKER_RECORDER_LOG', value, true)
		} else {
			os.unsetenv('V3_CPP_LINKER_RECORDER_LOG')
		}
		os.rmdir_all(root) or {}
	}
	os.unsetenv('CFLAGS')
	os.unsetenv('LDFLAGS')
	os.unsetenv('VFLAGS')
	os.unsetenv('V3_CPP_LINKER_RECORDER_LOG')
	v3_bin := build_driver_cli_v3(root)
	active := os.join_path(root, 'active.v')
	inactive := os.join_path(root, 'inactive.v')
	plain := os.join_path(root, 'plain.v')
	invalid := os.join_path(root, 'invalid.v')
	os.write_file(active, 'module main\n#linker c++\n#linker c++\nfn main() {}\n')!
	os.write_file(inactive,
		'module main\n\$if false {\n\t#linker c++\n}\nfn main() { println(42) }\n')!
	os.write_file(invalid, 'module main\n#linker cpp\nfn main() {}\n')!
	os.write_file(plain, 'module main\nfn main() { println(7) }\n')!
	executable_suffix := if os.user_os() == 'windows' { '.exe' } else { '' }
	recorder_source := os.join_path(root, 'driver_recorder.v')
	recorder_binary := os.join_path(root, 'driver_recorder${executable_suffix}')
	recorder_log := os.join_path(root, 'driver_recorder.jsonl')
	os.write_file(recorder_source, 'module main

import json
import os

struct DriverInvocation {
	driver string
	cwd    string
	args   []string
}

fn main() {
	log_path := os.getenv("V3_CPP_LINKER_RECORDER_LOG")
	if log_path.len == 0 {
		exit(2)
	}
	mut driver := os.file_name(os.args[0]).to_lower_ascii()
	if driver.ends_with(".exe") {
		driver = driver[..driver.len - 4]
	}
	args := os.args[1..]
	record := json.encode(DriverInvocation{
		driver: driver
		cwd: os.getwd()
		args: args
	}) + "\\n"
	mut log := os.open_append(log_path) or { exit(3) }
	log.write_string(record) or { exit(3) }
	log.close()
	if args == ["--version"] {
		match driver {
			"gcc", "g++" { println("gcc (GCC) 13.2.0") }
			"clang", "clang++" { println("clang version 17.0.0") }
			else { exit(4) }
		}
		return
	}
	if args.len == 5 && args[..4] == ["-dM", "-E", "-x", "c"] {
		println("#define V3_CPP_RECORDER_CACHE_PROBE 1")
		return
	}
	mut output := ""
	mut output_count := 0
	for index, arg in args {
		if arg.starts_with("@") {
			exit(5)
		}
		if arg == "-o" {
			output_count++
			if index + 1 >= args.len {
				exit(6)
			}
			output = args[index + 1]
		}
	}
	if output_count != 1 || output.len == 0 {
		exit(7)
	}
	os.mkdir_all(os.dir(output)) or { exit(8) }
	os.write_file(output, "") or { exit(8) }
}
')!
	recorder_build := cmdexec.run(@VEXE, ['-gc', 'none', '-no-retry-compilation', '-o',
		recorder_binary, recorder_source])
	assert recorder_build.exit_code == 0, recorder_build.output
	fake_gcc := os.join_path(root, 'gcc${executable_suffix}')
	fake_gpp := os.join_path(root, 'g++${executable_suffix}')
	fake_clang := os.join_path(root, 'clang${executable_suffix}')
	fake_clangpp := os.join_path(root, 'clang++${executable_suffix}')
	fake_tcc := os.join_path(root, 'tcc${executable_suffix}')
	fake_clang_cl := os.join_path(root, 'clang-cl${executable_suffix}')
	fake_msvc := os.join_path(root, 'msvc${executable_suffix}')
	fake_emcc := os.join_path(root, 'emcc${executable_suffix}')
	fake_unknown := os.join_path(root, 'v3_unknown_native_driver_issue74${executable_suffix}')
	for fake_driver in [fake_gcc, fake_gpp, fake_clang, fake_clangpp, fake_tcc, fake_clang_cl,
		fake_msvc, fake_emcc, fake_unknown] {
		os.cp(recorder_binary, fake_driver)!
	}
	os.write_file(recorder_log, '')!
	os.setenv('V3_CPP_LINKER_RECORDER_LOG', recorder_log, true)
	assert_driver_cli_failure(v3_bin, ['-check', invalid], '`#linker` expects exactly `c++`')

	missing_cpp := os.join_path(root, 'v3_missing_cpp_driver_issue74${executable_suffix}')
	assert !os.exists(missing_cpp)
	check := cmdexec.run(v3_bin, ['-c++', missing_cpp, '-check', active])
	assert check.exit_code == 0, check.output
	c_output := os.join_path(root, 'active.c')
	c_only := cmdexec.run(v3_bin, ['-c++', missing_cpp, '-o', c_output, active])
	assert c_only.exit_code == 0, c_only.output
	assert os.is_file(c_output)

	os.write_file(recorder_log, '')!
	assert_driver_cli_failure(v3_bin, ['-nocache', '-cc', fake_gcc, '-c++', missing_cpp, '-shared',
		'-o', os.join_path(root, 'active.o'), active],
		'`#linker c++` cannot combine `-shared` with object output (`-o file.o` or `-is_o`)')
	assert v3_cpp_driver_recorder_invocations(recorder_log).len == 0

	os.write_file(recorder_log, '')!
	duplicate_output := os.join_path(root, 'duplicate${executable_suffix}')
	duplicate := cmdexec.run(v3_bin, ['-nocache', '-cc', fake_gcc, '-c++', fake_gpp, '-o',
		duplicate_output, active])
	assert duplicate.exit_code == 0, duplicate.output
	assert os.is_file(duplicate_output)
	duplicate_invocations := v3_cpp_driver_recorder_invocations(recorder_log)
	duplicate_versions := duplicate_invocations.filter(it.args == ['--version'])
	duplicate_probes := duplicate_invocations.filter('-dM' in it.args && '-E' in it.args)
	duplicate_targets := duplicate_invocations.filter(it.args != ['--version'] && !('-dM' in it.args
		&& '-E' in it.args))
	assert duplicate_invocations.len == 5, duplicate_invocations.str()
	assert duplicate_versions.map(it.driver) == ['gcc', 'g++'], duplicate_invocations.str()
	assert duplicate_probes.len == 1, duplicate_invocations.str()
	assert duplicate_probes[0].driver == 'gcc', duplicate_invocations.str()
	assert duplicate_probes[0].args.len == 5, duplicate_probes[0].args.str()
	assert duplicate_probes[0].args[..4] == ['-dM', '-E', '-x', 'c'], duplicate_probes[0].args.str()
	assert duplicate_probes[0].args[4].ends_with('.c'), duplicate_probes[0].args.str()
	assert '-o' !in duplicate_probes[0].args, duplicate_probes[0].args.str()
	assert duplicate_invocations[2] == duplicate_probes[0], duplicate_invocations.str()
	assert duplicate_invocations[3..] == duplicate_targets, duplicate_invocations.str()
	assert duplicate_targets.len == 2, duplicate_invocations.str()
	c_compile_invocations := duplicate_targets.filter(it.driver == 'gcc' && '-c' in it.args)
	link_invocations := duplicate_targets.filter(it.driver == 'g++' && '-c' !in it.args)
	assert c_compile_invocations.len == 1, duplicate_invocations.str()
	assert link_invocations.len == 1, duplicate_invocations.str()
	assert c_compile_invocations[0].args.any(it.ends_with('.c')), c_compile_invocations[0].args.str()
	assert c_compile_invocations[0].args.filter(it.ends_with('.c')).len == 1, c_compile_invocations[0].args.str()

	assert os.base(v3_cpp_driver_recorder_output(c_compile_invocations[0])).starts_with('v3_c_source_'), c_compile_invocations[0].args.str()

	assert os.base(v3_cpp_driver_recorder_output(link_invocations[0])) == 'out', link_invocations[0].args.str()
	assert !link_invocations[0].args.any(it.ends_with('.c')), link_invocations[0].args.str()
	assert link_invocations[0].args.filter(it.contains('v3_c_source_')).len == 1, link_invocations[0].args.str()

	assert duplicate_targets.map(it.driver) == ['gcc', 'g++'], duplicate_invocations.str()

	os.write_file(recorder_log, '')!
	object_output := os.join_path(root, 'active.o')
	object_build := cmdexec.run(v3_bin, ['-nocache', '-cc', fake_gcc, '-c++', missing_cpp, '-o',
		object_output, active])
	assert object_build.exit_code == 0, object_build.output
	assert os.is_file(object_output)
	assert !object_build.output.contains(missing_cpp), object_build.output
	assert !os.exists(missing_cpp)
	object_invocations := v3_cpp_driver_recorder_invocations(recorder_log)
	object_probes := object_invocations.filter('-dM' in it.args && '-E' in it.args)
	object_targets := object_invocations.filter(it.args != ['--version'] && !('-dM' in it.args
		&& '-E' in it.args))
	assert object_invocations.len == 2, object_invocations.str()
	assert object_probes.len == 1, object_invocations.str()
	assert object_probes[0].driver == 'gcc', object_invocations.str()
	assert object_probes[0].args.len == 5, object_probes[0].args.str()
	assert object_probes[0].args[..4] == ['-dM', '-E', '-x', 'c'], object_probes[0].args.str()
	assert object_probes[0].args[4].ends_with('.c'), object_probes[0].args.str()
	assert '-o' !in object_probes[0].args, object_probes[0].args.str()
	assert object_invocations[0] == object_probes[0], object_invocations.str()
	assert object_invocations[1..] == object_targets, object_invocations.str()
	assert object_targets.len == 1, object_invocations.str()
	assert object_targets[0].driver == 'gcc', object_invocations.str()
	assert '-c' in object_targets[0].args, object_targets[0].args.str()
	assert object_targets[0].args.filter(it.ends_with('.c')).len == 1, object_targets[0].args.str()

	assert os.base(v3_cpp_driver_recorder_output(object_targets[0])) == 'out', object_targets[0].args.str()

	assert !object_targets.any(it.driver == 'g++'), object_invocations.str()
	assert missing_cpp !in object_targets[0].args, object_invocations.str()

	real_pairs := v3_cpp_linker_driver_pairs()
	if real_pairs.len > 0 {
		pair := real_pairs[0]
		inactive_output := os.join_path(root, 'inactive${if os.user_os() == 'windows' {
			'.exe'
		} else {
			''
		}}')
		inactive_build := cmdexec.run(v3_bin, ['-no-retry-compilation', '-cc', pair.c, '-c++',
			pair.cpp, '-o', inactive_output, inactive])
		assert inactive_build.exit_code == 0, inactive_build.output
		assert cmdexec.run(inactive_output, []string{}).output.trim_space() == '42'
	} else {
		inactive_plain_c := os.join_path(root, 'inactive_plain.c')
		inactive_missing_c := os.join_path(root, 'inactive_missing.c')
		inactive_plain := cmdexec.run(v3_bin, ['-no-retry-compilation', '-o', inactive_plain_c,
			inactive])
		assert inactive_plain.exit_code == 0, inactive_plain.output
		inactive_missing := cmdexec.run(v3_bin, ['-no-retry-compilation', '-c++', missing_cpp,
			'-o', inactive_missing_c, inactive])
		assert inactive_missing.exit_code == 0, inactive_missing.output
		assert os.read_file(inactive_missing_c)! == os.read_file(inactive_plain_c)!
	}
	plain_environment := os.environ()
	mut first_plain_c := ''
	plain_output := if real_pairs.len > 0 {
		os.join_path(root, 'plain${if os.user_os() == 'windows' { '.exe' } else { '' }}')
	} else {
		os.join_path(root, 'plain.c')
	}
	plain_baseline_output := os.join_path(root, 'plain_baseline.c')
	for iteration in 0 .. 2 {
		mut plain_args := ['-showcc']
		if real_pairs.len > 0 {
			plain_args << ['-no-retry-compilation', '-cc', real_pairs[0].c, '-c++', real_pairs[0].cpp]
		} else {
			plain_args << ['-no-retry-compilation', '-c++', missing_cpp]
		}
		plain_args << ['-o', plain_output, plain]
		plain_build := run_driver_with_environment(v3_bin, plain_args, plain_environment)
		assert plain_build.exit_code == 0, plain_build.output
		assert !plain_build.output.contains(missing_cpp), plain_build.output
		if real_pairs.len > 0 {
			assert cmdexec.run(plain_output, []string{}).output.trim_space() == '7'
		} else {
			plain_baseline := run_driver_with_environment(v3_bin, ['-no-retry-compilation', '-o',
				plain_baseline_output, plain], plain_environment)
			assert plain_baseline.exit_code == 0, plain_baseline.output
			plain_c := os.read_file(plain_output)!
			assert plain_c == os.read_file(plain_baseline_output)!
			if iteration == 0 {
				first_plain_c = plain_c
			} else {
				assert plain_c == first_plain_c
			}
		}
	}

	project_dir := os.join_path(root, 'generated-project')
	assert_driver_cli_failure(v3_bin, ['-generate-c-project', project_dir, active],
		'does not support `-generate-c-project`')
	for compiler in [fake_tcc, fake_clang_cl, fake_msvc, fake_emcc, fake_unknown] {
		os.write_file(recorder_log, '')!
		assert_driver_cli_failure(v3_bin, ['-cc', compiler, '-c++', missing_cpp, active],
			'requires a GNU-compatible GCC or Clang C driver')
		invocations := v3_cpp_driver_recorder_invocations(recorder_log)
		expected_invocations := if compiler in [fake_emcc, fake_unknown] { 2 } else { 1 }
		assert invocations.len == expected_invocations, invocations.str()
		assert invocations.all(it.args == ['--version']), invocations.str()
	}

	os.write_file(recorder_log, '')!
	cl_like := cmdexec.run(v3_bin, ['-nocache', '-cc', fake_clang, '-c++', missing_cpp, '-cflags',
		'--driver-mode=cl-like', active])
	assert cl_like.exit_code != 0
	assert cl_like.output.contains('requires the C++ driver `${missing_cpp}`'), cl_like.output
	cl_like_invocations := v3_cpp_driver_recorder_invocations(recorder_log)
	assert cl_like_invocations.len == 1, cl_like_invocations.str()
	assert cl_like_invocations[0].driver == 'clang', cl_like_invocations.str()
	assert cl_like_invocations[0].args == ['--version'], cl_like_invocations.str()

	os.write_file(recorder_log, '')!
	cl_mode := cmdexec.run(v3_bin, ['-nocache', '-cc', fake_clang, '-c++', missing_cpp, '-cflags',
		'--driver-mode=cl', active])
	assert cl_mode.exit_code != 0
	assert cl_mode.output.contains('requires a GNU-compatible GCC or Clang C driver'), cl_mode.output
	assert !cl_mode.output.contains('requires the C++ driver `${missing_cpp}`'), cl_mode.output
	cl_mode_invocations := v3_cpp_driver_recorder_invocations(recorder_log)
	assert cl_mode_invocations.len == 1, cl_mode_invocations.str()
	assert cl_mode_invocations[0].driver == 'clang', cl_mode_invocations.str()
	assert cl_mode_invocations[0].args == ['--version'], cl_mode_invocations.str()

	assert_driver_cli_failure(v3_bin, ['-cc', fake_gcc, '-c++', missing_cpp, active],
		'requires the C++ driver')
	$if !windows {
		invalid_driver_dir := os.join_path(root, 'invalid-driver')
		os.mkdir_all(invalid_driver_dir)!
		invalid_fake_gcc := os.join_path(invalid_driver_dir, 'gcc')
		os.write_file(invalid_fake_gcc, '#!/bin/sh\necho "not a compiler"\n')!
		os.chmod(invalid_fake_gcc, 0o700)!
		assert_driver_cli_failure(v3_bin, ['-cc', invalid_fake_gcc, '-c++', missing_cpp, active],
			'requires a GNU-compatible GCC or Clang C driver')
	}
	os.write_file(recorder_log, '')!
	assert_driver_cli_failure(v3_bin, ['-cc', fake_gcc, '-c++', fake_clangpp, active],
		'requires matching C and C++ driver families')
	mismatch_invocations := v3_cpp_driver_recorder_invocations(recorder_log)
	assert mismatch_invocations.len == 2, mismatch_invocations.str()
	assert mismatch_invocations.map(it.driver) == ['gcc', 'clang++'], mismatch_invocations.str()
	assert mismatch_invocations.all(it.args == ['--version']), mismatch_invocations.str()

	host := pref.host_target()
	cross_arch := if host.arch == 'arm64' { 'amd64' } else { 'arm64' }
	assert_driver_cli_failure(v3_bin, ['-arch', cross_arch, '-c++', missing_cpp, active],
		'does not support cross-target linking yet')
}

struct V3CppLinkerDriverPair {
	c   string
	cpp string
}

fn v3_cpp_test_compiler_version_suffix_is_supported(suffix string) bool {
	if suffix == '' {
		return true
	}
	if !suffix.starts_with('-') || suffix.len == 1 {
		return false
	}
	return suffix[1..].bytes().all(it.is_digit() || it == `.`)
}

fn v3_cpp_test_driver_name_family(raw_name string) string {
	mut name := raw_name.to_lower_ascii()
	if name.ends_with('.exe') {
		name = name[..name.len - 4]
	}
	for token, family in {
		'clang++': 'clang'
		'clang':   'clang'
		'g++':     'gcc'
		'gcc':     'gcc'
		'c++':     'any'
		'cc':      'any'
	} {
		if index := name.last_index(token) {
			suffix := name[index + token.len..]
			if (index == 0 || name[index - 1] == `-`)
				&& v3_cpp_test_compiler_version_suffix_is_supported(suffix) {
				return family
			}
		}
	}
	return ''
}

fn v3_cpp_test_gnu_driver_family(command string) string {
	name := os.file_name(command).to_lower_ascii()
	expected_family := v3_cpp_test_driver_name_family(name)
	if expected_family == '' {
		return ''
	}
	version := cmdexec.run(command, ['--version'])
	if version.exit_code != 0 {
		return ''
	}
	text := version.output.to_lower_ascii()
	mut actual_family := ''
	if text.contains('clang') && !text.contains('clang-cl') {
		actual_family = 'clang'
	} else if text.contains('gcc') || text.contains('free software foundation')
		|| text.contains('mingw') {
		actual_family = 'gcc'
	}
	if actual_family == '' || (expected_family != 'any' && expected_family != actual_family) {
		return ''
	}
	return actual_family
}

fn v3_cpp_spy_args(line string) []string {
	tab := line.index_u8(`\t`)
	if tab < 0 {
		return []
	}
	return line[tab + 1..].split(' ').filter(it.len > 0)
}

fn v3_cpp_response_file_args(showcc_output string) []string {
	mut result := []string{}
	mut reading_response_file := false
	for line in showcc_output.split_into_lines() {
		if line.contains('C++ linker response file') {
			reading_response_file = true
			continue
		}
		if !reading_response_file {
			continue
		}
		clean := line.trim_space()
		if !clean.starts_with('"') {
			if result.len > 0 {
				break
			}
			continue
		}
		result << clean
	}
	return result
}

fn v3_cpp_response_arg_index(args []string, fragment string) int {
	for index, arg in args {
		if arg.contains(fragment) {
			return index
		}
	}
	return -1
}

fn v3_cpp_temporary_link_files(root string) []string {
	mut result := []string{}
	for extension in ['.cpp', '.o', '.rsp'] {
		for path in os.walk_ext(root, extension) {
			base := os.base(path)
			if base.starts_with('v3_c_source_') || base.starts_with('v3_cpp_source_')
				|| base == 'v3_linker.rsp' {
				result << path
			}
		}
	}
	return result
}

fn v3_cpp_linker_driver_pairs() []V3CppLinkerDriverPair {
	mut pairs := []V3CppLinkerDriverPair{}
	for names in [['gcc', 'g++'], ['clang', 'clang++']] {
		c := os.find_abs_path_of_executable(names[0]) or { continue }
		cpp := os.find_abs_path_of_executable(names[1]) or { continue }
		c_family := v3_cpp_test_gnu_driver_family(c)
		cpp_family := v3_cpp_test_gnu_driver_family(cpp)
		if c_family == '' || cpp_family == '' || c_family != cpp_family {
			continue
		}
		pairs << V3CppLinkerDriverPair{
			c:   c
			cpp: cpp
		}
	}
	return pairs
}

fn test_driver_cpp_linker_uses_final_cpp_driver_and_keeps_sources_c() {
	pairs := v3_cpp_linker_driver_pairs()
	if pairs.len == 0 {
		return
	}
	root := os.join_path(os.vtmp_dir(), 'v3_driver_cpp_linker_real_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	v3_bin := build_driver_cli_v3(root)
	os.write_file(os.join_path(root, 'sentinel.c'),
		'#ifdef __cplusplus\n#error V3_C_SOURCE_WAS_COMPILED_AS_CXX\n#endif\nint v3_c_value(void) { return 7; }\n')!
	os.write_file(os.join_path(root, 'runtime.cpp'),
		'extern "C" int v3_cpp_value(void) { int* p = new int(7); int value = *p; delete p; return value; }\n')!
	os.write_file(os.join_path(root, 'native.C'),
		'extern "C" int v3_upper_cpp_value(void) { return 3; }\n')!
	os.write_file(os.join_path(root, 'native.cpp'),
		'extern "C" int v3_native_cpp_value(void) { return 4; }\n')!
	mut main_source := 'module main\n#linker c++\n#flag @DIR/sentinel.c\n#flag @DIR/native.C\n#flag @DIR/native.cpp\n#flag @DIR/runtime.o\nfn C.v3_c_value() int\nfn C.v3_upper_cpp_value() int\nfn C.v3_native_cpp_value() int\nfn C.v3_cpp_value() int\nfn main() { println(C.v3_c_value() + C.v3_upper_cpp_value() + C.v3_native_cpp_value() + C.v3_cpp_value()) }\n'
	mut expected_output := '21'
	$if macos {
		os.write_file(os.join_path(root, 'native.m'),
			'int v3_objective_c_value(void) { return 5; }\n')!
		os.write_file(os.join_path(root, 'native.mm'),
			'extern "C" int v3_objective_cpp_value(void) { return 6; }\n')!
		main_source = 'module main\n#linker c++\n#flag @DIR/sentinel.c\n#flag @DIR/native.C\n#flag @DIR/native.cpp\n#flag @DIR/native.m\n#flag @DIR/native.mm\n#flag @DIR/runtime.o\nfn C.v3_c_value() int\nfn C.v3_upper_cpp_value() int\nfn C.v3_native_cpp_value() int\nfn C.v3_objective_c_value() int\nfn C.v3_objective_cpp_value() int\nfn C.v3_cpp_value() int\nfn main() { println(C.v3_c_value() + C.v3_upper_cpp_value() + C.v3_native_cpp_value() + C.v3_objective_c_value() + C.v3_objective_cpp_value() + C.v3_cpp_value()) }\n'
		expected_output = '32'
	}
	os.write_file(os.join_path(root, 'main.v'), main_source)!
	for index, pair in pairs {
		runtime_object := os.join_path(root, 'runtime.o')
		cpp_compile := cmdexec.run(pair.cpp, ['-std=c++14', '-c', os.join_path(root, 'runtime.cpp'),
			'-o', runtime_object])
		assert cpp_compile.exit_code == 0, cpp_compile.output
		for mode, mode_args in {
			'direct':   []string{}
			'prod':     ['-prod']
			'parallel': ['-parallel-cc']
		} {
			output := os.join_path(root, '${index}_${mode}${if os.user_os() == 'windows' {
				'.exe'
			} else {
				''
			}}')
			mut active_c := pair.c
			mut active_cpp := pair.cpp
			mut spy_log := ''
			mut environment := os.environ()
			mut args := ['-gc', 'none', '-showcc']
			$if !windows {
				if mode == 'parallel' {
					spy_dir := os.join_path(root, 'spy_${index}')
					os.mkdir_all(spy_dir) or { panic(err) }
					spy_log = os.join_path(spy_dir, 'commands.log')
					active_c = 'cc'
					active_cpp = 'c++'
					c_spy := os.join_path(spy_dir, active_c)
					cpp_spy := os.join_path(spy_dir, active_cpp)
					os.write_file(c_spy,
						'#!/bin/sh\nprintf "C\\t%s\\n" "\$*" >> ${os.quoted_path(spy_log)}\nexec ${os.quoted_path(pair.c)} "\$@"\n')!
					os.write_file(cpp_spy,
						'#!/bin/sh\nprintf "CPP\\t%s\\n" "\$*" >> ${os.quoted_path(spy_log)}\nexec ${os.quoted_path(pair.cpp)} "\$@"\n')!
					os.chmod(c_spy, 0o700)!
					os.chmod(cpp_spy, 0o700)!
					current_path := environment['PATH'] or { '' }
					environment['PATH'] = '${spy_dir}${os.path_delimiter}${current_path}'
				} else {
					args << ['-cc', active_c, '-c++', active_cpp]
				}
			}
			$if windows {
				args << ['-cc', active_c, '-c++', active_cpp]
			}
			if mode != 'parallel' {
				args << '-nocache'
			}
			args << mode_args
			args << ['-o', output, os.join_path(root, 'main.v')]
			environment['V3CACHE'] = os.join_path(root, 'cache_${index}_${mode}')
			build := run_driver_with_environment(v3_bin, args, environment)
			assert build.exit_code == 0, '${pair.c}/${pair.cpp} ${mode}: ${build.output}'
			assert build.output.contains(active_cpp), build.output
			command_lines := build.output.split_into_lines().filter(it.contains('  > '))
			c_compile_lines := command_lines.filter(it.starts_with('  > ${active_c} ')
				&& it.contains(' -c '))
			cpp_compile_lines := command_lines.filter(it.starts_with('  > ${active_cpp} ')
				&& it.contains(' -c '))
			cpp_link_lines := command_lines.filter(it.starts_with('  > ${active_cpp} ')
				&& !it.contains(' -c ') && !it.contains('--version'))
			assert cpp_link_lines.len == 1, command_lines.str()
			assert c_compile_lines.any(it.contains('sentinel.c')), command_lines.str()
			generated_src_lines := c_compile_lines.filter(it.contains('src.c'))
			assert generated_src_lines.len <= 1, command_lines.str()
			program_main_count := cpp_link_lines[0].count('program_main')
			assert program_main_count <= 1, cpp_link_lines[0]
			if mode == 'parallel' {
				assert generated_src_lines.len + program_main_count == 1, command_lines.str()
			} else {
				assert generated_src_lines.len == 1, command_lines.str()
				assert program_main_count == 0, cpp_link_lines[0]
			}
			if generated_src_lines.len == 1 {
				assert generated_src_lines[0].contains('-std=gnu11'), generated_src_lines.str()
			}

			assert cpp_compile_lines.any(it.contains('native.C')), command_lines.str()
			assert cpp_compile_lines.any(it.contains('native.cpp')), command_lines.str()
			$if macos {
				assert c_compile_lines.any(it.contains('native.m')), command_lines.str()
			}
			assert !cpp_link_lines[0].contains('sentinel.c'), cpp_link_lines[0]
			assert !cpp_link_lines[0].contains('native.C'), cpp_link_lines[0]
			assert !cpp_link_lines[0].contains('native.cpp'), cpp_link_lines[0]
			assert !cpp_link_lines[0].contains('native.m'), cpp_link_lines[0]
			assert !cpp_link_lines[0].contains('native.mm'), cpp_link_lines[0]
			expected_c_objects := 1 + generated_src_lines.len +
				(if os.user_os() == 'macos' { 1 } else { 0 })
			assert cpp_link_lines[0].count('v3_c_source_') == expected_c_objects, cpp_link_lines[0]

			assert cpp_link_lines[0].count('v3_cpp_source_') == 2, cpp_link_lines[0]
			$if macos {
				assert cpp_link_lines[0].count('native_mm_o_') == 1, cpp_link_lines[0]
				objective_c_index := cpp_link_lines[0].index('v3_c_source_${1 + generated_src_lines.len}.o') or {
					-1
				}
				objective_cpp_index := cpp_link_lines[0].index('native_mm_o_') or { -1 }
				runtime_index := cpp_link_lines[0].index('runtime.o') or { -1 }
				assert objective_c_index >= 0 && objective_c_index < objective_cpp_index
				assert objective_cpp_index < runtime_index
			}

			assert cpp_link_lines[0].count('runtime.o') == 1, cpp_link_lines[0]
			assert cpp_link_lines[0].count('src.c') == 0, cpp_link_lines[0]
			if mode == 'direct' {
				assert !build.output.contains('C++ linker response file'), build.output
			}
			assert !build.output.contains('-lstdc++'), build.output
			assert !build.output.contains('-lc++'), build.output
			assert cmdexec.run(output, []string{}).output.trim_space() == expected_output
			$if macos {
				assert build.output.contains('-x objective-c'), build.output
			}
			$if !windows {
				if mode == 'parallel' {
					assert '-cc' !in args
					spy_lines := os.read_lines(spy_log)!
					mut last_compile_index := -1
					mut cpp_link_candidates := []int{}
					for spy_index, spy_line in spy_lines {
						if spy_line.starts_with('C\t') || spy_line.starts_with('CPP\t') {
							spy_args := v3_cpp_spy_args(spy_line)
							if '-c' in spy_args {
								last_compile_index = spy_index
							}
						}
						if spy_line.starts_with('CPP\t') {
							spy_args := v3_cpp_spy_args(spy_line)
							if '-c' !in spy_args && '-M' !in spy_args && '-MM' !in spy_args
								&& '-o' in spy_args
								&& spy_args.filter(it.ends_with('runtime.o')).len == 1 {
								cpp_link_candidates << spy_index
							}
						}
					}
					assert last_compile_index >= 0, spy_lines.str()
					assert cpp_link_candidates.len == 1, spy_lines.str()
					assert cpp_link_candidates[0] > last_compile_index, spy_lines.str()
				}
			}
		}
		{
			rsp_payload_minimum := 18 * 1024
			rsp_payload_maximum := 24 * 1024
			long_flag := '-L${os.quoted_path(root)}'
			missing_library_flag := '-lv3_issue74_missing'
			mut long_flags := []string{}
			mut long_flags_length := 0
			for long_flags_length < rsp_payload_minimum {
				separator_length := if long_flags.len == 0 { 0 } else { 1 }
				next_length := long_flags_length + separator_length + long_flag.len
				assert next_length + 1 + missing_library_flag.len < rsp_payload_maximum
				long_flags << long_flag
				long_flags_length = next_length
			}
			long_flags_text := long_flags.join(' ')
			failed_long_flags_text := '${long_flags_text} ${missing_library_flag}'
			assert long_flags_text.len == long_flags_length
			assert long_flags_text.len >= rsp_payload_minimum
			assert long_flags_text.len < rsp_payload_maximum
			assert failed_long_flags_text.len < rsp_payload_maximum
			output := os.join_path(root, 'rsp_${index}${if os.user_os() == 'windows' {
				'.exe'
			} else {
				''
			}}')
			rsp_build := cmdexec.run(v3_bin, ['-nocache', '-gc', 'none', '-cc', pair.c, '-c++',
				pair.cpp, '-showcc', '-ldflags', long_flags_text, '-o', output,
				os.join_path(root,
					'main.v')])
			assert rsp_build.exit_code == 0, rsp_build.output
			assert rsp_build.output.contains('C++ linker response file'), rsp_build.output
			assert rsp_build.output.split_into_lines().any(it.contains(pair.cpp) && it.contains('@')
				&& !it.contains('response file')), rsp_build.output
			rsp_command_lines := rsp_build.output.split_into_lines().filter(it.contains('  > '))
			rsp_c_compile_lines := rsp_command_lines.filter(it.starts_with('  > ${pair.c} ')
				&& it.contains(' -c '))
			rsp_cpp_compile_lines := rsp_command_lines.filter(it.starts_with('  > ${pair.cpp} ')
				&& it.contains(' -c '))
			assert rsp_c_compile_lines.len == if os.user_os() == 'macos' {
				3
			} else {
				2
			}, rsp_command_lines.str()

			assert rsp_cpp_compile_lines.len == 2, rsp_command_lines.str()

			assert rsp_c_compile_lines.any(it.contains('src.c')
				&& it.contains(' -o v3_c_source_0.o')), rsp_c_compile_lines.str()
			assert rsp_c_compile_lines.any(it.contains('sentinel.c')
				&& it.contains(' -o v3_c_source_1.o')), rsp_c_compile_lines.str()
			assert rsp_cpp_compile_lines.any(it.contains('native.C')
				&& it.contains(' -o v3_cpp_source_0.o')), rsp_cpp_compile_lines.str()
			assert rsp_cpp_compile_lines.any(it.contains('native.cpp')
				&& it.contains(' -o v3_cpp_source_1.o')), rsp_cpp_compile_lines.str()
			if os.user_os() == 'macos' {
				assert rsp_c_compile_lines.any(it.contains('native.m')
					&& it.contains(' -o v3_c_source_2.o')), rsp_c_compile_lines.str()
			}
			response_args := v3_cpp_response_file_args(rsp_build.output)
			assert response_args.len > 0, rsp_build.output
			response_content := response_args.join('\n')
			generated_c_index := v3_cpp_response_arg_index(response_args, 'v3_c_source_0.o')
			c_source_index := v3_cpp_response_arg_index(response_args, 'v3_c_source_1.o')
			cpp_source_index := v3_cpp_response_arg_index(response_args, 'v3_cpp_source_0.o')
			cpp_source_second_index := v3_cpp_response_arg_index(response_args, 'v3_cpp_source_1.o')
			runtime_index := v3_cpp_response_arg_index(response_args, 'runtime.o')
			library_index := response_args.index('"-lm"')
			assert generated_c_index >= 0 && generated_c_index < c_source_index
			assert c_source_index < cpp_source_index
			assert cpp_source_index < cpp_source_second_index
			assert cpp_source_second_index < runtime_index
			assert runtime_index < library_index
			if os.user_os() == 'macos' {
				objective_c_index := v3_cpp_response_arg_index(response_args, 'v3_c_source_2.o')
				objective_cpp_index := v3_cpp_response_arg_index(response_args, 'native_mm_o_')
				assert cpp_source_second_index < objective_c_index
				assert objective_c_index < objective_cpp_index
				assert objective_cpp_index < runtime_index
				assert response_args.filter(it.contains('native_mm_o_')).len == 1
			}
			assert !response_content.contains('sentinel.c')
			assert !response_content.contains('native.C')
			assert !response_content.contains('native.cpp')
			assert !response_content.contains('native.m')
			assert !response_content.contains('native.mm')
			assert response_args.filter(it.contains('v3_c_source_')).len == if os.user_os() == 'macos' {
				3
			} else {
				2
			}
			assert response_args.filter(it.contains('v3_cpp_source_')).len == 2
			assert response_args.filter(it.contains('runtime.o')).len == 1
			assert response_args.filter(it.contains('src.c')).len == 0
			assert v3_cpp_temporary_link_files(root).len == 0
			assert cmdexec.run(output, []string{}).output.trim_space() == expected_output

			failed_output := os.join_path(root, 'rsp_failure_${index}')
			failed_rsp := cmdexec.run(v3_bin, ['-nocache', '-gc', 'none', '-cc', pair.c, '-c++',
				pair.cpp, '-showcc', '-ldflags', failed_long_flags_text, '-o', failed_output,
				os.join_path(root, 'main.v')])
			assert failed_rsp.exit_code != 0
			assert failed_rsp.output.contains('C++ linker response file'), failed_rsp.output
			assert failed_rsp.output.split_into_lines().any(it.contains(pair.cpp)
				&& it.contains('@') && !it.contains('response file')), failed_rsp.output
			assert v3_cpp_temporary_link_files(root).len == 0
		}
	}
}
