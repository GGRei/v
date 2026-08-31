module main

import os
import os.cmdline
import v.pref
import v.util.recompilation
import v.util.vflags

const args_ = arguments()
const is_debug = args_.contains('-debug')

const fastc_repeat2_diag_marker_env = 'ISSUE74_FASTC_REPEAT2_DIAG'
const fastc_repeat2_diag_destination_env = 'ISSUE74_FASTC_REPEAT2_C_DEST'
const fastc_repeat2_diag_source_dir = 'issue74-fastc-repeat2-c21-source'
const fastc_repeat2_diag_file = 'repeat1.c'
const fastc_repeat2_diag_max_c_size = u64(8 * 1024 * 1024)

// support a renamed `v` executable too:
const vexe = os.getenv_opt('VEXE') or { @VEXE }

const vroot = os.dir(vexe)

fn main() {
	// make testing `v up` easier, by providing a way to force `v self` to fail,
	// to test the fallback logic:
	if os.getenv('VSELF_SHOULD_FAIL') != '' {
		eprintln('v self failed')
		exit(1)
	}
	vexe_name := os.file_name(vexe)
	short_v_name := vexe_name.all_before('.')

	recompilation.must_be_enabled(vroot,
		'Please install V from source, to use `${vexe_name} self` .')
	os.chdir(vroot)!
	os.setenv('VCOLORS', 'always', true)
	command_index := os.getenv('VSELF_COMMAND_INDEX').int()
	os.unsetenv('VSELF_COMMAND_INDEX')
	repeat_count, mut args := extract_repeat_count(args_[1..], command_index)
	mut effective_args := effective_self_build_args(args)
	fastc_self_build := uses_fastc_backend(effective_args)
	if fastc_self_build && '-prod' in effective_args {
		eprintln('`v self -b fastc` does not support `-prod`; remove `-prod`.')
		exit(1)
	}
	if fastc_self_build {
		args = normalize_fastc_backend_args(args)
		effective_args = effective_self_build_args(args)
	}
	if !fastc_self_build && !has_self_build_configuration_arg(effective_args) {
		// compiling by default, i.e. `v self`:
		uos := os.user_os()
		uname := os.uname()
		if uos == 'macos' {
			// V3 relies on native thread-local preallocation scopes to keep
			// compiler self-builds below the memory limit. TCC does not support
			// that implementation on macOS, so use the system compiler.
			args << ['-cc', os.getenv_opt('CC') or { 'cc' }]
		} else if uos == 'linux' && uname.machine in ['arm64', 'aarch64'] {
			// Bundled TCC can hang while bootstrapping V on Linux ARM64, so
			// prefer the system compiler for self-builds there.
			args << ['-cc', os.getenv_opt('CC') or { 'cc' }]
		}
	}
	if !has_gc_arg(effective_args) {
		args << ['-gc', 'none']
	}
	effective_args = effective_self_build_args(args)
	if !fastc_self_build && os.user_os() in ['linux', 'macos']
		&& self_build_supports_prealloc(effective_args) && !has_prealloc_arg(effective_args) {
		// The embedded V3 compiler uses disposable preallocation scopes. Pass the
		// flag explicitly so the first `v up` built by an older compiler gets
		// the bounded-memory implementation too.
		args << '-prealloc'
	}
	obinary := self_build_output(args)
	if fastc_self_build && repeat_count > 1 && obinary == '' {
		unsupported := unsupported_fastc_repeat_args(args)
		if unsupported.len > 0 {
			eprintln('`v self -b fastc xN` cannot preserve these options across repeated replacement builds: ${unsupported.join(' ')}')
			eprintln('Remove the options, use `x1`, or specify `-o` to keep the original compiler.')
			exit(1)
		}
	}
	mut compile_args := clone_args(args)
	if obinary == '' {
		compile_args << ['-o', 'v2']
	}
	if fastc_self_build {
		compile_args << '-selfhost'
	}
	final_binary := if obinary != '' { obinary } else { 'v2' }
	pgo_cc_kind := if fastc_self_build { '' } else { pgo_compiler_kind(args) }
	compilation_source := if fastc_self_build { 'vlib/v3/v3.v' } else { 'cmd/v' }
	for run_idx in 0 .. repeat_count {
		run_label := if repeat_count > 1 { ' [${run_idx + 1}/${repeat_count}]' } else { '' }
		options := if args.len > 0 { '(${compile_args.join(' ')})' } else { '' }
		println('V self compiling${run_label} ${options}...')
		cmd := compose_v_cmd(vexe, compile_args, compilation_source)
		mut used_pgo := false
		if pgo_cc_kind != '' {
			used_pgo = compile_with_pgo(vroot, vexe, args, final_binary, pgo_cc_kind)
			if !used_pgo {
				eprintln('PGO self-build failed; falling back to a regular self-build.')
			}
		}
		if fastc_self_build {
			run_cmd(cmd) or {
				eprintln('cannot compile to `${vroot}`: \n${err.msg()}')
				exit(1)
			}
			$if linux {
				if run_idx == 0 && repeat_count == 2 && obinary == '' && '-keepc' in compile_args {
					marker := os.getenv(fastc_repeat2_diag_marker_env)
					if marker == '1' {
						runner_temp := os.getenv('RUNNER_TEMP')
						destination := os.getenv(fastc_repeat2_diag_destination_env)
						status := if fastc_repeat2_diag_request_is_exact(fastc_self_build, run_idx, repeat_count, obinary, compile_args, marker, runner_temp, destination) {
							fastc_repeat2_diag_copy_c(vroot, runner_temp, destination)
						} else {
							'request-rejected'
						}
						eprintln('ISSUE74_FASTC_REPEAT2_CAPTURE status=${status}')
					}
				}
			}
		} else if !used_pgo {
			if !try_compile(cmd) {
				bootstrap_self_build(vroot, clone_args(args), final_binary) or {
					eprintln('cannot compile to `${vroot}`: \n${err.msg()}')
					exit(1)
				}
			}
		}
		if obinary == '' {
			backup_old_version_and_rename_newer(short_v_name) or { panic(err.msg()) }
		}
	}
	if obinary != '' {
		return
	}
	println('V built successfully as executable "${vexe_name}".')
}

fn fastc_repeat2_diag_expected_destination(runner_temp string) string {
	if runner_temp == '' {
		return ''
	}
	return os.join_path(runner_temp, fastc_repeat2_diag_source_dir, fastc_repeat2_diag_file)
}

fn fastc_repeat2_diag_source_path(vroot string) string {
	if vroot == '' {
		return ''
	}
	return os.join_path(vroot, 'v2.c')
}

fn fastc_repeat2_diag_request_is_exact(fastc_self_build bool, run_idx int, repeat_count int, obinary string, compile_args []string, marker string, runner_temp string, destination string) bool {
	return fastc_self_build && run_idx == 0 && repeat_count == 2 && obinary == '' && '-keepc' in compile_args && marker == '1' && destination != '' && destination == fastc_repeat2_diag_expected_destination(runner_temp)
}

fn fastc_repeat2_diag_copy_c(vroot string, runner_temp string, destination string) string {
	if vroot == '' || !os.is_abs_path(vroot) {
		return 'vroot-invalid'
	}
	vroot_stat := os.lstat(vroot) or { return 'vroot-lstat' }
	if vroot_stat.get_filetype() != .directory || vroot_stat.uid != u32(os.geteuid()) {
		return 'vroot-validation'
	}
	vroot_real := os.real_path(vroot)
	if vroot_real == '' || vroot_real != vroot {
		return 'vroot-canonical'
	}
	if runner_temp == '' || !os.is_abs_path(runner_temp) {
		return 'runner-temp-invalid'
	}
	runner_stat := os.lstat(runner_temp) or { return 'runner-temp-lstat' }
	if runner_stat.get_filetype() != .directory || runner_stat.uid != u32(os.geteuid()) {
		return 'runner-temp-validation'
	}
	runner_real := os.real_path(runner_temp)
	if runner_real == '' || runner_real != runner_temp {
		return 'runner-temp-canonical'
	}
	expected_destination := fastc_repeat2_diag_expected_destination(runner_temp)
	if destination != expected_destination || os.file_name(destination) != fastc_repeat2_diag_file {
		return 'destination-exact'
	}
	parent := os.dir(destination)
	expected_parent := os.join_path_single(runner_temp, fastc_repeat2_diag_source_dir)
	if parent != expected_parent {
		return 'parent-exact'
	}
	parent_stat := os.lstat(parent) or { return 'parent-lstat' }
	if parent_stat.get_filetype() != .directory || parent_stat.uid != u32(os.geteuid()) || parent_stat.mode & 0o7777 != 0o700 {
		return 'parent-validation'
	}
	parent_real := os.real_path(parent)
	if parent_real != expected_parent || !parent_real.starts_with(runner_real + os.path_separator) {
		return 'parent-confinement'
	}
	if os.exists(destination) || os.is_link(destination) {
		return 'destination-exists'
	}

	source := fastc_repeat2_diag_source_path(vroot)
	if source != os.join_path(vroot, 'v2.c') || os.file_name(source) != 'v2.c' {
		return 'source-exact'
	}
	source_stat := os.lstat(source) or { return 'source-lstat' }
	if source_stat.get_filetype() != .regular || source_stat.nlink != 1 || source_stat.uid != u32(os.geteuid()) || source_stat.size < 1 || source_stat.size >= fastc_repeat2_diag_max_c_size {
		return 'source-validation'
	}
	source_real := os.real_path(source)
	if source_real != source || !source_real.starts_with(vroot_real + os.path_separator) {
		return 'source-confinement'
	}

	temporary := destination + '.tmp.${os.getpid()}'
	if os.exists(temporary) || os.is_link(temporary) {
		return 'temporary-exists'
	}
	mut destination_owned := false
	defer {
		os.rm(temporary) or {}
		if destination_owned {
			os.rm(destination) or {}
		}
	}
	os.cp(source, temporary, fail_if_exists: true) or { return 'copy-failed' }
	temporary_stat := os.lstat(temporary) or { return 'temporary-lstat' }
	if temporary_stat.get_filetype() != .regular || temporary_stat.nlink != 1 || temporary_stat.uid != u32(os.geteuid()) || temporary_stat.size != source_stat.size || os.real_path(temporary) != temporary {
		return 'temporary-validation'
	}
	if os.exists(destination) || os.is_link(destination) {
		return 'destination-raced'
	}
	os.link(temporary, destination) or { return 'publish-failed' }
	destination_owned = true
	os.rm(temporary) or { return 'temporary-remove-failed' }
	destination_stat := os.lstat(destination) or { return 'destination-lstat' }
	if destination_stat.get_filetype() != .regular || destination_stat.nlink != 1 || destination_stat.uid != u32(os.geteuid()) || destination_stat.size != source_stat.size || os.real_path(destination) != destination {
		return 'destination-validation'
	}
	preserved_source_stat := os.lstat(source) or { return 'source-not-preserved' }
	if preserved_source_stat.get_filetype() != .regular || preserved_source_stat.nlink != 1 || preserved_source_stat.uid != u32(os.geteuid()) || preserved_source_stat.dev != source_stat.dev || preserved_source_stat.inode != source_stat.inode || preserved_source_stat.size != source_stat.size {
		return 'source-changed'
	}
	destination_owned = false
	return 'ok'
}

fn self_build_output(args []string) string {
	mut output := ''
	mut i := 0
	for i < args.len {
		arg := args[i]
		if arg in ['-o', '-output'] && i + 1 < args.len {
			output = args[i + 1]
			i += 2
			continue
		}
		if (arg == '-cf' || pref.option_may_consume_value(arg)) && i + 1 < args.len {
			i += 2
		} else {
			i++
		}
	}
	return output
}

fn uses_fastc_backend(args []string) bool {
	mut backend := ''
	mut i := 0
	for i < args.len {
		arg := args[i]
		if arg in ['-b', '-backend'] && i + 1 < args.len {
			backend = args[i + 1]
			i += 2
			continue
		}
		if (arg == '-cf' || pref.option_may_consume_value(arg)) && i + 1 < args.len {
			i += 2
		} else {
			i++
		}
	}
	return backend == 'fastc'
}

fn normalize_fastc_backend_args(args []string) []string {
	mut normalized := []string{cap: args.len}
	mut i := 0
	for i < args.len {
		arg := args[i]
		if arg in ['-b', '-backend'] && i + 1 < args.len {
			i += 2
			continue
		}
		normalized << arg
		if (arg == '-cf' || pref.option_may_consume_value(arg)) && i + 1 < args.len {
			normalized << args[i + 1]
			i += 2
		} else {
			i++
		}
	}
	normalized << ['-b', 'fastc']
	return normalized
}

fn unsupported_fastc_repeat_args(args []string) []string {
	mut unsupported := []string{}
	mut i := 0
	for i < args.len {
		arg := args[i]
		if arg in ['-b', '-gc'] && i + 1 < args.len {
			value := args[i + 1]
			supported := match arg {
				'-b' { value == 'fastc' }
				'-gc' { value == 'none' }
				else { false }
			}
			if !supported {
				unsupported << '${arg} ${value}'
			}
			i += 2
			continue
		}
		if arg in ['-silent', '-keepc'] {
			i++
			continue
		}
		mut option := arg
		if (arg == '-cf' || pref.option_may_consume_value(arg)) && i + 1 < args.len {
			option += ' ${args[i + 1]}'
			i += 2
		} else {
			i++
		}
		unsupported << option
	}
	return unsupported
}

fn effective_self_build_args(args []string) []string {
	mut effective_args := vflags.tokenize_to_args(os.getenv('VFLAGS'))
	effective_args << args
	return effective_args
}

fn has_self_build_configuration_arg(args []string) bool {
	for arg in args {
		if arg in ['-cc', '-prod', '-parallel-cc'] || arg.starts_with('-cc=')
			|| arg.starts_with('-cc ') {
			return true
		}
	}
	return false
}

fn repeat_count_arg(arg string) int {
	if arg.len < 2 || arg[0] != `x` {
		return 0
	}
	for ch in arg[1..].bytes() {
		if !ch.is_digit() {
			return 0
		}
	}
	count := arg[1..].int()
	return if count > 0 { count } else { 0 }
}

fn extract_repeat_count(args []string, protected_prefix_count int) (int, []string) {
	mut repeat_count := 1
	mut filtered := []string{cap: args.len}
	mut should_skip_repeat_check := false
	mut removed_self_command := false
	prefix_count := int_min(int_max(protected_prefix_count, 0), args.len)
	filtered << args[..prefix_count]
	for arg in args[prefix_count..] {
		if should_skip_repeat_check {
			filtered << arg
			should_skip_repeat_check = false
			continue
		}
		if arg == '-cf' || pref.option_may_consume_value(arg) {
			filtered << arg
			should_skip_repeat_check = true
			continue
		}
		if !removed_self_command && arg == 'self' {
			removed_self_command = true
			continue
		}
		if repeat_count == 1 {
			count := repeat_count_arg(arg)
			if count > 0 {
				repeat_count = count
				continue
			}
		}
		filtered << arg
	}
	return repeat_count, filtered
}

fn has_gc_arg(args []string) bool {
	for arg in args {
		if arg == '-gc' {
			return true
		}
		if arg.starts_with('-gc=') {
			return true
		}
	}
	return false
}

fn has_prealloc_arg(args []string) bool {
	return args.any(it in ['-prealloc', '-no-prealloc'])
}

fn self_build_supports_prealloc(args []string) bool {
	mut target_os := os.user_os()
	mut ccompiler := ''
	mut gc := 'none'
	mut i := 0
	for i < args.len {
		arg := args[i]
		if arg == '-os' {
			if i + 1 < args.len {
				target_os = args[i + 1]
				i++
			}
		} else if arg.starts_with('-os=') {
			target_os = arg.all_after('=')
		} else if arg == '-cc' {
			if i + 1 < args.len {
				ccompiler = args[i + 1]
				i++
			}
		} else if arg.starts_with('-cc=') {
			ccompiler = arg.all_after('=')
		} else if arg.starts_with('-cc ') {
			ccompiler = arg.all_after('-cc ')
		} else if arg == '-gc' {
			if i + 1 < args.len {
				gc = args[i + 1]
				i++
			}
		} else if arg.starts_with('-gc=') {
			gc = arg.all_after('=')
		}
		i++
	}
	return target_os in ['linux', 'macos'] && gc == 'none'
		&& self_ccompiler_supports_prealloc(ccompiler)
}

fn self_ccompiler_supports_prealloc(ccompiler string) bool {
	cc := os.file_name(ccompiler.trim_space()).to_lower_ascii()
	return !cc.contains('tcc') && !cc.contains('tinyc') && !cc.contains('tinygcc')
		&& !cc.contains('tiny_gcc') && !cc.contains('tiny-gcc')
}

fn has_profile_cflag(args []string) bool {
	mut skip_next := false
	for i, arg in args {
		if skip_next {
			skip_next = false
			continue
		}
		if arg in ['-cflags', '-cf'] {
			if i + 1 < args.len {
				next_arg := args[i + 1]
				if next_arg.contains('-fprofile') {
					return true
				}
				skip_next = true
			}
			continue
		}
		if (arg.starts_with('-cflags=') || arg.starts_with('-cf=')) && arg.contains('-fprofile') {
			return true
		}
	}
	return false
}

fn pgo_compiler_kind(args []string) string {
	if '-prod' !in args || '-no-prod-options' in args {
		return ''
	}
	if os.user_os() == 'windows' {
		return ''
	}
	if has_profile_cflag(args) {
		return ''
	}
	mut ccompiler := cmdline.option(args, '-cc', '')
	if ccompiler == '' {
		ccompiler = os.getenv_opt('CC') or { 'cc' }
	}
	cc_file_name := os.file_name(ccompiler)
	if cc_file_name.contains('clang') || cc_file_name.contains('gcc')
		|| cc_file_name.contains('g++') || ccompiler == 'cc' {
		cc_ver := os.execute('${os.quoted_path(ccompiler)} --version').output
		if cc_ver.contains('clang') {
			_ := find_llvm_profdata() or { return '' }
			return 'clang'
		}
		if cc_ver.contains('Free Software Foundation') || cc_ver.contains('GCC') {
			return 'gcc'
		}
	}
	if cc_file_name.contains('clang') {
		_ := find_llvm_profdata() or { return '' }
		return 'clang'
	}
	if cc_file_name.contains('gcc') || cc_file_name.contains('g++') {
		return 'gcc'
	}
	return ''
}

fn find_llvm_profdata() !string {
	if profdata := os.find_abs_path_of_executable('llvm-profdata') {
		return profdata
	}
	$if macos {
		xcrun_result := os.execute('xcrun --find llvm-profdata')
		if xcrun_result.exit_code == 0 {
			xcrun_path := xcrun_result.output.trim_space()
			if xcrun_path != '' && os.exists(xcrun_path) {
				return xcrun_path
			}
		}
	}
	return error('can not find llvm-profdata in PATH')
}

fn with_output_arg(args []string, output string) []string {
	mut res := []string{cap: args.len + 2}
	mut skip_next := false
	for i, arg in args {
		if skip_next {
			skip_next = false
			continue
		}
		if arg == '-o' {
			if i + 1 < args.len {
				skip_next = true
			}
			continue
		}
		if arg.starts_with('-o=') {
			continue
		}
		res << arg
	}
	res << ['-o', output]
	return res
}

fn clone_args(args []string) []string {
	mut cloned := []string{cap: args.len}
	for arg in args {
		cloned << arg.clone()
	}
	return cloned
}

fn compose_v_cmd(vexe string, args []string, source string) string {
	mut parts := []string{cap: args.len + 2}
	parts << os.quoted_path(vexe)
	for arg in args {
		parts << os.quoted_path(arg)
	}
	parts << os.quoted_path(source)
	return parts.join(' ')
}

fn run_cmd(cmd string) ! {
	result := os.execute(cmd)
	if result.exit_code != 0 {
		return error(result.output)
	}
	if result.output.len > 0 {
		println(result.output.trim_space())
	}
}

fn try_compile(cmd string) bool {
	result := os.execute(cmd)
	if result.exit_code != 0 {
		return false
	}
	if result.output.len > 0 {
		println(result.output.trim_space())
	}
	return true
}

fn compile_with_pgo(vroot string, vexe string, args []string, out_binary string, cc_kind string) bool {
	pgo_workspace := os.join_path(vroot, '.vself_pgo')
	os.rmdir_all(pgo_workspace) or {}
	os.mkdir_all(pgo_workspace) or {
		eprintln('PGO disabled: can not create ${pgo_workspace}: ${err.msg()}')
		return false
	}
	defer {
		os.rmdir_all(pgo_workspace) or {}
	}
	profile_dir := os.join_path(pgo_workspace, 'profile')
	os.mkdir_all(profile_dir) or {
		eprintln('PGO disabled: can not create ${profile_dir}: ${err.msg()}')
		return false
	}
	pgo_binary := os.join_path(pgo_workspace, 'v_pgo_gen')
	training_output := os.join_path(pgo_workspace, 'cmd_v_training.c')
	mut use_profile_flag := '-fprofile-use=${profile_dir}'
	mut llvm_profdata := ''
	mut profile_data := ''
	if cc_kind == 'clang' {
		llvm_profdata = find_llvm_profdata() or {
			eprintln('PGO disabled: can not find `llvm-profdata`.')
			return false
		}
		profile_data = os.join_path(pgo_workspace, 'code.profdata')
		use_profile_flag = '-fprofile-use=${profile_data}'
	}
	mut generate_args := with_output_arg(args, pgo_binary)
	generate_args << ['-cflags', '-fprofile-generate=${profile_dir}']
	generate_cmd := compose_v_cmd(vexe, generate_args, 'cmd/v')
	run_cmd(generate_cmd) or {
		eprintln('PGO step failed while building the instrumented compiler.')
		eprintln(err.msg())
		return false
	}
	training_cmd := '${os.quoted_path(pgo_binary)} -o ${os.quoted_path(training_output)} ${os.quoted_path('cmd/v')}'
	run_cmd(training_cmd) or {
		eprintln('PGO step failed while generating the profiling data.')
		eprintln(err.msg())
		return false
	}
	if cc_kind == 'clang' {
		merge_cmd := '${os.quoted_path(llvm_profdata)} merge -output=${os.quoted_path(profile_data)} ${os.quoted_path(profile_dir)}'
		run_cmd(merge_cmd) or {
			eprintln('PGO step failed while merging the profiling data.')
			eprintln(err.msg())
			return false
		}
	}
	mut final_args := with_output_arg(args, out_binary)
	final_args << ['-cflags', use_profile_flag]
	if cc_kind == 'gcc' {
		final_args << ['-cflags', '-fprofile-correction']
	}
	final_cmd := compose_v_cmd(vexe, final_args, 'cmd/v')
	run_cmd(final_cmd) or {
		eprintln('PGO step failed while building the final compiler binary.')
		eprintln(err.msg())
		return false
	}
	return true
}

fn bootstrap_self_build(vroot string, args []string, final_binary string) ! {
	bootstrap_prefix := '.vself_bootstrap'
	mut bootstrap_v1 := '${bootstrap_prefix}_v1'
	mut bootstrap_v2 := '${bootstrap_prefix}_v2'
	exe_ext := if os.user_os() == 'windows' { '.exe' } else { '' }
	bootstrap_v1 += exe_ext
	bootstrap_v2 += exe_ext
	os.rm(bootstrap_v1) or {}
	os.rm(bootstrap_v2) or {}
	defer {
		os.rm(bootstrap_v1) or {}
		os.rm(bootstrap_v2) or {}
	}
	vc_source := os.join_path(vroot, 'vc',
		if os.user_os() == 'windows' { 'v_win.c' } else { 'v.c' })
	if !os.exists(vc_source) {
		return error('bootstrap fallback failed: `${vc_source}` is missing')
	}
	cc := os.getenv_opt('CC') or {
		if os.user_os() == 'windows' { 'gcc' } else { 'cc' }
	}
	bootstrap_v1_build_cmd := bootstrap_c_cmd(cc, bootstrap_v1, vc_source)
	run_cmd(bootstrap_v1_build_cmd) or {
		return error('bootstrap fallback failed while building v1.\n${err.msg()}')
	}
	mut bootstrap_args := ['-no-parallel']
	bootstrap_args << with_output_arg(args, bootstrap_v2)
	bootstrap_v1_cmd := os.join_path('.', bootstrap_v1)
	bootstrap_v2_cmd := '${os.quoted_path(bootstrap_v1_cmd)} ${bootstrap_args.join(' ')} ${os.quoted_path('cmd/v')}'
	run_cmd(bootstrap_v2_cmd) or {
		return error('bootstrap fallback failed while building v2.\n${err.msg()}')
	}
	final_args := with_output_arg(args, final_binary)
	bootstrap_v2_cmd_path := os.join_path('.', bootstrap_v2)
	final_cmd := '${os.quoted_path(bootstrap_v2_cmd_path)} ${final_args.join(' ')} ${os.quoted_path('cmd/v')}'
	run_cmd(final_cmd) or {
		return error('bootstrap fallback failed while building the final compiler.\n${err.msg()}')
	}
}

fn bootstrap_c_cmd(cc string, out_binary string, vc_source string) string {
	mut parts := []string{cap: 8}
	parts << os.quoted_path(cc)
	if os.user_os() == 'windows' {
		parts << ['-std=c99', '-municode', '-w', '-o', os.quoted_path(out_binary),
			os.quoted_path(vc_source), '-lws2_32']
	} else {
		parts << ['-std=c99', '-w', '-o', os.quoted_path(out_binary),
			os.quoted_path(vc_source), '-lm', '-lpthread']
	}
	return parts.join(' ')
}

fn list_folder(short_v_name string, bmessage string, message string) {
	if !is_debug {
		return
	}
	if bmessage != '' {
		println(bmessage)
	}
	if os.user_os() == 'windows' {
		os.system('dir ${short_v_name}*.exe')
	} else {
		os.system('ls -lartd ${short_v_name}*')
	}
	println(message)
}

fn backup_old_version_and_rename_newer(short_v_name string) !bool {
	mut errors := []string{}
	short_v_file := if os.user_os() == 'windows' { '${short_v_name}.exe' } else { '${short_v_name}' }
	short_v2_file := if os.user_os() == 'windows' { 'v2.exe' } else { 'v2' }
	short_bak_file := if os.user_os() == 'windows' { 'v_old.exe' } else { 'v_old' }
	v_file := os.real_path(short_v_file)
	v2_file := os.real_path(short_v2_file)
	bak_file := os.real_path(short_bak_file)

	list_folder(short_v_name, 'before:', 'removing ${bak_file} ...')
	if os.exists(bak_file) {
		os.rm(bak_file) or { errors << 'failed removing ${bak_file}: ${err.msg()}' }
	}

	list_folder(short_v_name, '', 'moving ${v_file} to ${bak_file} ...')
	os.mv(v_file, bak_file) or { errors << err.msg() }

	list_folder(short_v_name, '', 'removing ${v_file} ...')
	os.rm(v_file) or {}

	list_folder(short_v_name, '', 'moving ${v2_file} to ${v_file} ...')
	os.mv_by_cp(v2_file, v_file) or { panic(err.msg()) }

	list_folder(short_v_name, 'after:', '')

	if errors.len > 0 {
		eprintln('backup errors:\n  >>  ' + errors.join('\n  >>  '))
	}
	return true
}
