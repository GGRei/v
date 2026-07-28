import os
import rand

const makefile_path = os.join_path(@VEXEROOT, 'GNUmakefile')
const selector_path = os.join_path(@VEXEROOT, 'cmd', 'tools', 'select_linux_tcc.sh')

struct TccHistoryFixture {
	root             string
	remote           string
	source           string
	tmp_dir          string
	tcc_dir          string
	fresh_cmd        string
	latest_cmd       string
	compatible_sha   string
	incompatible_sha string
}

fn run_checked(command string) string {
	result := os.execute(command)
	assert result.exit_code == 0, 'command failed (${result.exit_code}):\n${command}\n${result.output}'
	return result.output
}

fn write_executable(path string, contents string) {
	os.write_file(path, contents) or { panic(err) }
	os.chmod(path, 0o755) or { panic(err) }
}

fn compatible_tcc_script(version string) string {
	return '#!/bin/sh
if [ "\${1:-}" = "--version" ]; then
	echo "${version}"
	exit 0
fi
out=
has_gc_include=0
has_gc_threads=0
has_thread_local_alloc=0
has_builtin_atomic=0
has_libgc=0
while [ "\$#" -gt 0 ]; do
	case "\$1" in
		-I*/thirdparty/libgc/include) has_gc_include=1 ;;
		-DGC_THREADS=1) has_gc_threads=1 ;;
		-DTHREAD_LOCAL_ALLOC=1) has_thread_local_alloc=1 ;;
		-DGC_BUILTIN_ATOMIC=1) has_builtin_atomic=1 ;;
		*/lib/libgc.a) has_libgc=1 ;;
		-o)
			if [ "\$#" -gt 1 ]; then
				out="\$2"
				shift 2
				continue
			fi
			;;
	esac
	shift
done
if [ -z "\$out" ] || [ "\$has_gc_include" != 1 ] || [ "\$has_gc_threads" != 1 ] || [ "\$has_thread_local_alloc" != 1 ] || [ "\$has_builtin_atomic" != 1 ] || [ "\$has_libgc" != 1 ]; then
	exit 2
fi
{
	echo "#!/bin/sh"
	echo "echo v-tcc-host-boehm-probe"
} > "\$out"
chmod +x "\$out"
'
}

fn incompatible_tcc_script(version string) string {
	return '#!/bin/sh
if [ "\${1:-}" = "--version" ]; then
	echo "${version}"
	exit 0
fi
out=
while [ "\$#" -gt 0 ]; do
	if [ "\$1" = "-o" ] && [ "\$#" -gt 1 ]; then
		out="\$2"
		shift 2
		continue
	fi
	shift
done
if [ -z "\$out" ]; then
	exit 2
fi
{
	echo "#!/bin/sh"
	echo "echo incompatible-host-probe"
	echo "exit 43"
} > "\$out"
chmod +x "\$out"
'
}

fn configure_source_repo(path string) {
	run_checked('git init --quiet ${os.quoted_path(path)}')
	run_checked('git -C ${os.quoted_path(path)} config user.name "V Test"')
	run_checked('git -C ${os.quoted_path(path)} config user.email "v-test@example.invalid"')
}

fn commit_bundle_state(source string, message string, tcc_script string, libgc string) string {
	os.mkdir_all(os.join_path(source, 'lib')) or { panic(err) }
	write_executable(os.join_path(source, 'tcc.exe'), tcc_script)
	os.write_file(os.join_path(source, 'lib', 'libgc.a'), libgc) or { panic(err) }
	os.write_file(os.join_path(source, 'lib', 'bundle-state.txt'), '${message}\n') or { panic(err) }
	run_checked('git -C ${os.quoted_path(source)} add .')
	run_checked('git -C ${os.quoted_path(source)} commit --quiet -m ${os.quoted_path(message)}')
	return run_checked('git -C ${os.quoted_path(source)} rev-parse HEAD').trim_space()
}

fn create_unknown_branch(root string, remote string) {
	source := os.join_path(root, 'unknown')
	configure_source_repo(source)
	run_checked('git -C ${os.quoted_path(source)} checkout --quiet -b thirdparty-unknown-unknown')
	write_executable(os.join_path(source, 'tcc.exe'),
		'#!/bin/sh\necho "no bundled tcc" >&2\nexit 1\n')
	run_checked('git -C ${os.quoted_path(source)} add tcc.exe')
	run_checked('git -C ${os.quoted_path(source)} commit --quiet -m unknown')
	run_checked('git -C ${os.quoted_path(source)} push --quiet ${os.quoted_path(remote)} HEAD:refs/heads/thirdparty-unknown-unknown')
}

fn create_musl_branch(root string, remote string) {
	source := os.join_path(root, 'musl')
	configure_source_repo(source)
	run_checked('git -C ${os.quoted_path(source)} checkout --quiet -b thirdparty-linuxmusl-amd64')
	commit_bundle_state(source, 'musl-bundle', compatible_tcc_script('musl-tcc'), 'musl-libgc\n')
	run_checked('git -C ${os.quoted_path(source)} push --quiet ${os.quoted_path(remote)} HEAD:refs/heads/thirdparty-linuxmusl-amd64')
}

fn new_tcc_history_fixture(with_compatible_ancestor bool) TccHistoryFixture {
	root := os.join_path(os.vtmp_dir(), 'v_make_tcc_history_${rand.ulid()}')
	remote := os.join_path(root, 'tccbin.git')
	source := os.join_path(root, 'linux-source')
	vroot := os.join_path(root, 'vroot')
	tmp_dir := os.join_path(root, 'tmp')
	tcc_dir := os.join_path(vroot, 'thirdparty', 'tcc')
	os.mkdir_all(os.join_path(vroot, 'thirdparty')) or { panic(err) }
	os.mkdir_all(os.join_path(vroot, 'thirdparty', 'libgc', 'include')) or { panic(err) }
	os.mkdir_all(os.join_path(vroot, 'cmd', 'tools')) or { panic(err) }
	os.mkdir_all(tmp_dir) or { panic(err) }
	os.write_file(os.join_path(vroot, 'thirdparty', 'libgc', 'include', 'gc.h'),
		'void GC_INIT(void);\nvoid *GC_MALLOC(unsigned long);\n') or { panic(err) }
	os.symlink(makefile_path, os.join_path(vroot, 'GNUmakefile')) or { panic(err) }
	os.symlink(selector_path, os.join_path(vroot, 'cmd', 'tools', 'select_linux_tcc.sh')) or {
		panic(err)
	}
	run_checked('git init --quiet --bare ${os.quoted_path(remote)}')
	configure_source_repo(source)
	run_checked('git -C ${os.quoted_path(source)} checkout --quiet -b thirdparty-linux-amd64')
	mut compatible_sha := ''
	if with_compatible_ancestor {
		commit_bundle_state(source, 'compatible-v0', compatible_tcc_script('compatible-tcc-v0'),
			'compatible-libgc-v0\n')
		compatible_sha = commit_bundle_state(source, 'compatible-v1',
			compatible_tcc_script('compatible-tcc-v1'), 'compatible-libgc-v1\n')
	}
	incompatible_sha := commit_bundle_state(source, 'incompatible-head',
		incompatible_tcc_script('incompatible-head-tcc'), 'incompatible-head-libgc\n')
	run_checked('git -C ${os.quoted_path(source)} push --quiet ${os.quoted_path(remote)} HEAD:refs/heads/thirdparty-linux-amd64')
	create_unknown_branch(root, remote)
	create_musl_branch(root, remote)

	make_args := 'VROOT=${os.quoted_path(vroot)} TCCREPO=${os.quoted_path('file://${remote}')} TMPDIR=${os.quoted_path(tmp_dir)} TCCOS=linux TCCARCH=amd64'
	fresh_cmd := 'cd ${os.quoted_path(vroot)} && make --no-print-directory fresh_tcc ${make_args}'
	latest_cmd := 'cd ${os.quoted_path(vroot)} && make --no-print-directory latest_tcc ${make_args}'
	return TccHistoryFixture{
		root:             root
		remote:           remote
		source:           source
		tmp_dir:          tmp_dir
		tcc_dir:          tcc_dir
		fresh_cmd:        fresh_cmd
		latest_cmd:       latest_cmd
		compatible_sha:   compatible_sha
		incompatible_sha: incompatible_sha
	}
}

fn compatible_marker_dir(fixture TccHistoryFixture) string {
	return os.join_path(fixture.tcc_dir, '.git', 'vlang-compatible-tcc')
}

fn assert_clean_checkout(tcc_dir string) {
	status := run_checked('git -C ${os.quoted_path(tcc_dir)} status --short')
	assert status.trim_space() == '', status
}

fn assert_historical_fallback(fixture TccHistoryFixture) {
	assert run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} branch --show-current').trim_space() == ''
	assert run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} rev-parse HEAD').trim_space() == fixture.compatible_sha
	libgc := os.read_file(os.join_path(fixture.tcc_dir, 'lib', 'libgc.a')) or { panic(err) }
	metadata := os.read_file(os.join_path(compatible_marker_dir(fixture), 'metadata')) or {
		panic(err)
	}
	tmp_entries := os.ls(fixture.tmp_dir) or { panic(err) }
	assert libgc == 'compatible-libgc-v1\n'
	expected_metadata := 'tccos=linux\n' + 'tccarch=amd64\n' + 'abi=glibc\n' +
		'branch=thirdparty-linux-amd64\n' + 'remote_head_sha=${fixture.incompatible_sha}\n' +
		'compatible_sha=${fixture.compatible_sha}\n'
	assert metadata == expected_metadata, metadata
	assert_clean_checkout(fixture.tcc_dir)
	assert tmp_entries == []
}

fn push_compatible_head(mut fixture TccHistoryFixture) string {
	compatible_head_sha := commit_bundle_state(fixture.source, 'compatible-v2',
		compatible_tcc_script('compatible-tcc-v2'), 'compatible-libgc-v2\n')
	run_checked('git -C ${os.quoted_path(fixture.source)} push --quiet ${os.quoted_path(fixture.remote)} HEAD:refs/heads/thirdparty-linux-amd64')
	return compatible_head_sha
}

fn test_linux_tcc_uses_newest_compatible_commit_and_returns_to_a_fixed_head() {
	if os.user_os() != 'linux' {
		return
	}
	mut fixture := new_tcc_history_fixture(true)
	defer {
		os.rmdir_all(fixture.root) or {}
	}

	fresh_result := os.execute('${fixture.fresh_cmd} 2>&1')
	assert fresh_result.exit_code == 0, fresh_result.output
	assert fresh_result.output.contains('is not host-compatible'), fresh_result.output
	assert fresh_result.output.contains('Using newest host-compatible TCC commit ${fixture.compatible_sha}'), fresh_result.output

	assert_historical_fallback(fixture)

	still_broken_result := os.execute('${fixture.latest_cmd} 2>&1')
	assert still_broken_result.exit_code == 0, still_broken_result.output
	assert still_broken_result.output.contains('is not host-compatible'), still_broken_result.output
	assert_historical_fallback(fixture)

	compatible_head_sha := push_compatible_head(mut fixture)
	fixed_result := os.execute('${fixture.latest_cmd} 2>&1')
	assert fixed_result.exit_code == 0, fixed_result.output
	assert run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} branch --show-current').trim_space() == 'thirdparty-linux-amd64'
	assert run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} rev-parse HEAD').trim_space() == compatible_head_sha
	assert os.read_file(os.join_path(fixture.tcc_dir, 'lib', 'libgc.a'))! == 'compatible-libgc-v2\n'
	assert os.execute('${os.quoted_path(os.join_path(fixture.tcc_dir, 'tcc.exe'))} --version').output.trim_space() == 'compatible-tcc-v2'
	assert !os.exists(compatible_marker_dir(fixture))
	assert_clean_checkout(fixture.tcc_dir)
	assert os.ls(fixture.tmp_dir)! == []

	run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} config user.name "V Test"')
	run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} config user.email "v-test@example.invalid"')
	local_file := os.join_path(fixture.tcc_dir, 'user-local.txt')
	os.write_file(local_file, 'preserve this branch commit\n') or { panic(err) }
	run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} add user-local.txt')
	run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} commit --quiet -m user-local')
	local_sha :=
		run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} rev-parse HEAD').trim_space()
	local_result := os.execute('${fixture.latest_cmd} 2>&1')
	assert local_result.exit_code != 0, local_result.output
	assert local_result.output.contains('Refusing to overwrite local TCC commits'), local_result.output

	assert run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} rev-parse HEAD').trim_space() == local_sha
	assert os.read_file(local_file)! == 'preserve this branch commit\n'
	assert_clean_checkout(fixture.tcc_dir)
}

fn test_linux_tcc_explicit_request_does_not_hide_missing_compatible_history() {
	if os.user_os() != 'linux' {
		return
	}
	fixture := new_tcc_history_fixture(false)
	defer {
		os.rmdir_all(fixture.root) or {}
	}

	result := os.execute('${fixture.fresh_cmd} VFLAGS="-cc tcc" 2>&1')
	assert result.exit_code != 0, result.output
	assert result.output.contains('No host-compatible TCC commit was found'), result.output
	assert result.output.contains("explicit '-cc tcc' cannot continue"), result.output
	assert !result.output.contains('using the system compiler'), result.output
	assert os.ls(fixture.tmp_dir)! == []
}

fn test_linux_tcc_without_explicit_request_uses_system_fallback() {
	if os.user_os() != 'linux' {
		return
	}
	mut fixture := new_tcc_history_fixture(false)
	defer {
		os.rmdir_all(fixture.root) or {}
	}

	result := os.execute('${fixture.fresh_cmd} 2>&1')
	assert result.exit_code == 0, result.output
	assert result.output.contains('using the system compiler'), result.output
	assert run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} branch --show-current').trim_space() == 'thirdparty-unknown-unknown'
	metadata := os.read_file(os.join_path(compatible_marker_dir(fixture), 'metadata'))!
	assert metadata == 'tccos=linux\ntccarch=amd64\nabi=glibc\nbranch=thirdparty-linux-amd64\nremote_head_sha=${fixture.incompatible_sha}\nmode=system\n', metadata

	assert_clean_checkout(fixture.tcc_dir)
	assert os.ls(fixture.tmp_dir)! == []

	compatible_head_sha := push_compatible_head(mut fixture)
	refresh_result := os.execute('${fixture.latest_cmd} 2>&1')
	assert refresh_result.exit_code == 0, refresh_result.output
	assert run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} branch --show-current').trim_space() == 'thirdparty-linux-amd64'
	assert run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} rev-parse HEAD').trim_space() == compatible_head_sha
	assert !os.exists(compatible_marker_dir(fixture))
	assert_clean_checkout(fixture.tcc_dir)
}

fn test_linux_tcc_retries_an_initially_missing_native_branch() {
	if os.user_os() != 'linux' {
		return
	}
	mut fixture := new_tcc_history_fixture(true)
	defer {
		os.rmdir_all(fixture.root) or {}
	}
	run_checked('git -C ${os.quoted_path(fixture.source)} push --quiet ${os.quoted_path(fixture.remote)} :refs/heads/thirdparty-linux-amd64')

	fresh_result := os.execute('${fixture.fresh_cmd} 2>&1')
	assert fresh_result.exit_code == 0, fresh_result.output
	assert fresh_result.output.contains('using the system compiler'), fresh_result.output
	metadata_path := os.join_path(compatible_marker_dir(fixture), 'metadata')
	assert os.read_file(metadata_path)! == 'tccos=linux\ntccarch=amd64\nabi=glibc\nbranch=thirdparty-linux-amd64\nremote_head_sha=unavailable\nmode=system\n'

	still_missing_result := os.execute('${fixture.latest_cmd} 2>&1')
	assert still_missing_result.exit_code == 0, still_missing_result.output
	assert still_missing_result.output.contains('continuing with the system compiler'), still_missing_result.output

	assert os.read_file(metadata_path)!.contains('remote_head_sha=unavailable\n')
	assert_clean_checkout(fixture.tcc_dir)

	compatible_head_sha := push_compatible_head(mut fixture)
	repaired_result := os.execute('${fixture.latest_cmd} 2>&1')
	assert repaired_result.exit_code == 0, repaired_result.output
	assert run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} branch --show-current').trim_space() == 'thirdparty-linux-amd64'
	assert run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} rev-parse HEAD').trim_space() == compatible_head_sha
	assert !os.exists(compatible_marker_dir(fixture))
	assert_clean_checkout(fixture.tcc_dir)
}

fn test_latest_tcc_refuses_local_commits_in_system_fallback() {
	if os.user_os() != 'linux' {
		return
	}
	fixture := new_tcc_history_fixture(false)
	defer {
		os.rmdir_all(fixture.root) or {}
	}
	run_checked('${fixture.fresh_cmd} 2>&1')
	run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} config user.name "V Test"')
	run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} config user.email "v-test@example.invalid"')
	local_file := os.join_path(fixture.tcc_dir, 'user-local.txt')
	os.write_file(local_file, 'preserve this commit\n') or { panic(err) }
	run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} add user-local.txt')
	run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} commit --quiet -m user-local')
	local_sha :=
		run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} rev-parse HEAD').trim_space()

	result := os.execute('${fixture.latest_cmd} 2>&1')
	assert result.exit_code != 0, result.output
	assert result.output.contains('while it contains local commits'), result.output
	assert run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} rev-parse HEAD').trim_space() == local_sha
	assert os.read_file(local_file)! == 'preserve this commit\n'
	assert_clean_checkout(fixture.tcc_dir)
}

fn test_latest_tcc_refuses_dirty_or_mismatched_detached_checkout() {
	if os.user_os() != 'linux' {
		return
	}
	fixture := new_tcc_history_fixture(true)
	defer {
		os.rmdir_all(fixture.root) or {}
	}
	run_checked('${fixture.fresh_cmd} 2>&1')
	assert_historical_fallback(fixture)

	local_file := os.join_path(fixture.tcc_dir, 'user-local.txt')
	os.write_file(local_file, 'preserve me\n') or { panic(err) }
	dirty_result := os.execute('${fixture.latest_cmd} 2>&1')
	assert dirty_result.exit_code != 0, dirty_result.output
	assert dirty_result.output.contains('Refusing to refresh a dirty TCC checkout'), dirty_result.output
	assert os.read_file(local_file)! == 'preserve me\n'
	os.rm(local_file)!

	mismatch_result := os.execute('${fixture.latest_cmd} TCCARCH=arm64 2>&1')
	assert mismatch_result.exit_code != 0, mismatch_result.output
	assert mismatch_result.output.contains('Refusing to refresh detached TCC without an exact'), mismatch_result.output

	assert_historical_fallback(fixture)
	run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} checkout --quiet -b user-preserved-branch')
	wrong_branch_result := os.execute('${fixture.latest_cmd} 2>&1')
	assert wrong_branch_result.exit_code != 0, wrong_branch_result.output
	assert wrong_branch_result.output.contains('Refusing to refresh TCC branch user-preserved-branch'), wrong_branch_result.output

	assert run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} branch --show-current').trim_space() == 'user-preserved-branch'
	assert run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} rev-parse HEAD').trim_space() == fixture.compatible_sha
}

fn test_linuxmusl_native_bundle_stays_on_its_own_clean_branch() {
	if os.user_os() != 'linux' {
		return
	}
	fixture := new_tcc_history_fixture(true)
	defer {
		os.rmdir_all(fixture.root) or {}
	}

	result := os.execute('${fixture.fresh_cmd} TCCOS=linuxmusl TCCARCH=amd64 2>&1')
	assert result.exit_code == 0, result.output
	assert run_checked('git -C ${os.quoted_path(fixture.tcc_dir)} branch --show-current').trim_space() == 'thirdparty-linuxmusl-amd64'
	assert os.read_file(os.join_path(fixture.tcc_dir, 'lib', 'libgc.a'))! == 'musl-libgc\n'
	assert !os.exists(compatible_marker_dir(fixture))
	assert_clean_checkout(fixture.tcc_dir)
	assert os.ls(fixture.tmp_dir)! == []
}

fn execute_tcc_gc_probe_without_vflags(command string) os.Result {
	old_vflags := os.getenv_opt('VFLAGS')
	os.unsetenv('VFLAGS')
	result := os.execute(command)
	if vflags := old_vflags {
		os.setenv('VFLAGS', vflags, true)
	} else {
		os.unsetenv('VFLAGS')
	}
	return result
}

fn test_linux_glibc_bundled_tcc_links_and_runs_boehm_gc() {
	$if !linux {
		return
	}
	$if !amd64 {
		return
	}
	if os.execute('ldd --version 2>&1').output.to_lower().contains('musl') {
		return
	}
	tcc_dir := os.join_path(@VEXEROOT, 'thirdparty', 'tcc')
	tcc_path := os.join_path(tcc_dir, 'tcc.exe')
	if !os.is_executable(tcc_path)
		|| os.execute('${os.quoted_path(tcc_path)} --version').exit_code != 0 {
		return
	}
	// The hermetic repositories prove history selection with executable fixtures.
	// A native historical-fallback lane sets this gate before running the real
	// compiler+libgc consumer below.
	if os.getenv('V_CI_TCC_HISTORICAL_FALLBACK_REAL') == '1' {
		assert run_checked('git -C ${os.quoted_path(tcc_dir)} branch --show-current').trim_space() == ''
		metadata_path := os.join_path(tcc_dir, '.git', 'vlang-compatible-tcc', 'metadata')
		metadata := os.read_file(metadata_path)!
		head_sha := run_checked('git -C ${os.quoted_path(tcc_dir)} rev-parse HEAD').trim_space()
		assert metadata.contains('abi=glibc\n'), metadata
		assert metadata.contains('branch=thirdparty-linux-amd64\n'), metadata
		assert metadata.contains('compatible_sha=${head_sha}\n'), metadata
	}
	probe_dir := os.join_path(os.vtmp_dir(), 'v_make_tcc_gc_probe_${rand.ulid()}')
	os.mkdir_all(probe_dir) or { panic(err) }
	defer {
		os.rmdir_all(probe_dir) or {}
	}
	source_path := os.join_path(probe_dir, 'main.v')
	executable_path := os.join_path(probe_dir, 'probe')
	os.write_file(source_path,
		"fn main() {\n\tmut values := []string{}\n\tvalues << 'historical-tcc-gc-ok'\n\tprintln(values[0])\n}\n") or {
		panic(err)
	}
	build_command := '${os.quoted_path(@VEXE)} -showcc -cc ${os.quoted_path(tcc_path)} -gc boehm -no-retry-compilation -o ${os.quoted_path(executable_path)} ${os.quoted_path(source_path)}'
	build_result := execute_tcc_gc_probe_without_vflags(build_command)
	assert build_result.exit_code == 0, build_result.output
	assert build_result.output.contains('thirdparty/tcc/lib/libgc.a'), build_result.output
	assert !build_result.output.contains('sigsetjmp'), build_result.output
	run_result := os.execute(os.quoted_path(executable_path))
	assert run_result.exit_code == 0, run_result.output
	assert run_result.output.trim_space() == 'historical-tcc-gc-ok'
}
