import os

const vexe = @VEXE
const vroot = os.dir(vexe)

struct VselfFastCRepeat2DiagResult {
	exit_code   int
	output      string
	destination string
}

fn run_vself_fastc_repeat2_diag_case(tool string, case_root string, args []string, marker string, destination_mode string) VselfFastCRepeat2DiagResult {
	os.mkdir_all(case_root) or { panic(err) }
	fake_vroot := os.join_path(case_root, 'fake-vroot')
	runner_temp := os.join_path(case_root, 'runner-temp')
	source_dir := os.join_path(runner_temp, 'issue74-fastc-repeat2-c21-source')
	os.mkdir_all(fake_vroot) or { panic(err) }
	os.mkdir_all(runner_temp) or { panic(err) }
	os.mkdir(source_dir) or { panic(err) }
	os.chmod(source_dir, 0o700) or { panic(err) }
	fake_vexe := os.join_path(fake_vroot, 'v')
	fake_source := [
		r'#!/bin/sh',
		r'set -eu',
		r'state="$PWD/.calls"',
		r'count=0',
		r'[ ! -f "$state" ] || count="$(cat "$state")"',
		r'count=$((count + 1))',
		r'printf "%s\n" "$count" > "$state"',
		r'[ "$count" -eq 1 ] || exit 23',
		r'out=',
		r'while [ "$#" -gt 0 ]; do',
		r'  if [ "$1" = -o ] && [ "$#" -ge 2 ]; then out="$2"; shift 2; continue; fi',
		r'  shift',
		r'done',
		r'[ -n "$out" ] || exit 24',
		r'cp -- "$0" "$out"',
		r'chmod 700 "$out"',
		r'printf "round-one-c\n" > "${out}.c"',
	].join('\n') + '\n'
	os.write_file(fake_vexe, fake_source) or { panic(err) }
	os.chmod(fake_vexe, 0o700) or { panic(err) }
	destination := os.join_path(source_dir, 'repeat1.c')
	mut environment := os.environ()
	environment['VEXE'] = fake_vexe
	environment['RUNNER_TEMP'] = runner_temp
	environment.delete('ISSUE74_FASTC_REPEAT2_DIAG')
	environment.delete('ISSUE74_FASTC_REPEAT2_C_DEST')
	if marker != '' {
		environment['ISSUE74_FASTC_REPEAT2_DIAG'] = marker
	}
	if destination_mode == 'exact' {
		environment['ISSUE74_FASTC_REPEAT2_C_DEST'] = destination
	} else if destination_mode == 'existing' {
		environment['ISSUE74_FASTC_REPEAT2_C_DEST'] = destination
		os.write_file(destination, 'preexisting\n') or { panic(err) }
	} else if destination_mode == 'wrong' {
		environment['ISSUE74_FASTC_REPEAT2_C_DEST'] = destination + '.wrong'
	}
	mut process := os.new_process(tool)
	process.set_args(args)
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	exit_code := process.code
	process.close()
	return VselfFastCRepeat2DiagResult{
		exit_code: exit_code
		output: output
		destination: destination
	}
}

fn test_fastc_repeat2_diag_copies_round_one_before_round_two_failure() {
	$if !linux {
		return
	}
	root := os.join_path(os.real_path(os.vtmp_dir()), 'vself_fastc_repeat2_diag_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	tool := os.join_path(root, 'vself-tool')
	build := os.execute('${os.quoted_path(vexe)} -o ${os.quoted_path(tool)} ${os.quoted_path(os.join_path(vroot, 'cmd', 'tools', 'vself.v'))}')
	assert build.exit_code == 0, build.output
	repeat2_args := ['self', '-silent', '-b', 'fastc', '-keepc', 'x2']
	positive := run_vself_fastc_repeat2_diag_case(tool, os.join_path(root, 'positive'), repeat2_args, '1', 'exact')
	assert positive.exit_code != 0, positive.output
	assert positive.output.contains('ISSUE74_FASTC_REPEAT2_CAPTURE status=ok'), positive.output
	assert os.read_file(positive.destination) or { '' } == 'round-one-c\n'
	positive_entries := os.ls(os.dir(positive.destination)) or { []string{} }
	assert positive_entries.filter(it.contains('.tmp.')).len == 0

	missing_marker := run_vself_fastc_repeat2_diag_case(tool, os.join_path(root, 'missing-marker'), repeat2_args, '', 'exact')
	assert !os.exists(missing_marker.destination)
	assert !missing_marker.output.contains('ISSUE74_FASTC_REPEAT2_CAPTURE')
	wrong_marker := run_vself_fastc_repeat2_diag_case(tool, os.join_path(root, 'wrong-marker'), repeat2_args, '01', 'exact')
	assert !os.exists(wrong_marker.destination)
	assert !wrong_marker.output.contains('ISSUE74_FASTC_REPEAT2_CAPTURE')
	wrong_destination := run_vself_fastc_repeat2_diag_case(tool, os.join_path(root, 'wrong-destination'), repeat2_args, '1', 'wrong')
	assert !os.exists(wrong_destination.destination)
	assert wrong_destination.output.contains('ISSUE74_FASTC_REPEAT2_CAPTURE status=request-rejected')
	existing_destination := run_vself_fastc_repeat2_diag_case(tool, os.join_path(root, 'existing-destination'), repeat2_args, '1', 'existing')
	assert os.read_file(existing_destination.destination) or { '' } == 'preexisting\n'
	assert existing_destination.output.contains('ISSUE74_FASTC_REPEAT2_CAPTURE status=destination-exists')
	existing_entries := os.ls(os.dir(existing_destination.destination)) or { []string{} }
	assert existing_entries.filter(it.contains('.tmp.')).len == 0
	without_keepc_args := ['self', '-silent', '-b', 'fastc', 'x2']
	without_keepc := run_vself_fastc_repeat2_diag_case(tool, os.join_path(root, 'without-keepc'), without_keepc_args, '1', 'exact')
	assert !os.exists(without_keepc.destination)
	assert !without_keepc.output.contains('ISSUE74_FASTC_REPEAT2_CAPTURE')
	single_repeat_args := ['self', '-silent', '-b', 'fastc', '-keepc', 'x1']
	single_repeat := run_vself_fastc_repeat2_diag_case(tool, os.join_path(root, 'single-repeat'), single_repeat_args, '1', 'exact')
	assert !os.exists(single_repeat.destination)
	assert !single_repeat.output.contains('ISSUE74_FASTC_REPEAT2_CAPTURE')
	explicit_root := os.join_path(root, 'explicit-output')
	explicit_output := os.join_path(explicit_root, 'out')
	with_output_args := ['self', '-silent', '-b', 'fastc', '-keepc', 'x2', '-o', explicit_output]
	with_output := run_vself_fastc_repeat2_diag_case(tool, explicit_root, with_output_args, '1', 'exact')
	assert !os.exists(with_output.destination)
	assert !with_output.output.contains('ISSUE74_FASTC_REPEAT2_CAPTURE')
}

fn test_linux_tinyc_self_build_does_not_enable_prealloc() {
	$if !linux {
		return
	}
	noop := os.find_abs_path_of_executable('true') or { return }
	tool := os.join_path(os.vtmp_dir(), 'vself_prealloc_test')
	defer {
		os.rm(tool) or {}
	}
	build := os.execute('${os.quoted_path(vexe)} -o ${os.quoted_path(tool)} ${os.quoted_path(os.join_path(vroot,
		'cmd', 'tools', 'vself.v'))}')
	assert build.exit_code == 0, build.output
	for compiler in ['tcc', 'tinyc'] {
		result :=
			os.execute('VEXE=${os.quoted_path(noop)} ${os.quoted_path(tool)} self -cc ${compiler} -o /tmp/vself_${compiler}_test')
		assert result.exit_code == 0, result.output
		assert !result.output.contains('-prealloc'), result.output
	}
	for compiler in ['tcc', 'tinyc'] {
		result :=
			os.execute('VEXE=${os.quoted_path(noop)} VFLAGS="-cc ${compiler} -no-retry-compilation" ${os.quoted_path(tool)} self -o /tmp/vself_vflags_${compiler}_test')
		assert result.exit_code == 0, result.output
		assert !result.output.contains('-prealloc'), result.output
		assert !result.output.contains('-cc'), result.output
	}
	clang_result :=
		os.execute('VEXE=${os.quoted_path(noop)} ${os.quoted_path(tool)} self -cc clang -o /tmp/vself_clang_test')
	assert clang_result.exit_code == 0, clang_result.output
	assert clang_result.output.contains('-prealloc'), clang_result.output
	clang_override_result :=
		os.execute('VEXE=${os.quoted_path(noop)} VFLAGS="-cc tcc" ${os.quoted_path(tool)} self -cc clang -o /tmp/vself_vflags_clang_test')
	assert clang_override_result.exit_code == 0, clang_override_result.output
	assert clang_override_result.output.contains('-prealloc'), clang_override_result.output
}

fn test_macos_default_self_build_uses_prealloc_capable_compiler() {
	$if !macos {
		return
	}
	noop := os.find_abs_path_of_executable('true') or { return }
	tool := os.join_path(os.vtmp_dir(), 'vself_macos_prealloc_test')
	defer {
		os.rm(tool) or {}
	}
	build := os.execute('${os.quoted_path(vexe)} -o ${os.quoted_path(tool)} ${os.quoted_path(os.join_path(vroot,
		'cmd', 'tools', 'vself.v'))}')
	assert build.exit_code == 0, build.output
	result :=
		os.execute('CC=cc VEXE=${os.quoted_path(noop)} ${os.quoted_path(tool)} self -o /tmp/vself_macos_prealloc_test')
	assert result.exit_code == 0, result.output
	assert result.output.contains('-cc cc'), result.output
	assert result.output.contains('-prealloc'), result.output
}
