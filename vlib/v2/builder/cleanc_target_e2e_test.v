module builder

import os

const target_linux_marker = '<target_marker_linux.h>'
const target_macos_marker = '<target_marker_macos.h>'
const target_windows_marker = '<target_marker_windows.h>'
const target_cross_marker = '<target_marker_cross.h>'
const target_freestanding_marker = '<target_marker_freestanding.h>'
const inactive_windows_marker = '<inactive_windows_marker.h>'
const inactive_freestanding_marker = '<inactive_freestanding_marker.h>'
const active_comptime_marker = '<active_comptime_marker.h>'
const e2e_freestanding_missing_alloc_hook_message = 'v2: freestanding target requires freestanding_alloc hook for heap allocation'
const e2e_freestanding_missing_format_hook_message = 'v2: freestanding target cannot print non-string values without formatting support'
const e2e_freestanding_missing_heap_runtime_message = 'v2: freestanding target cannot use V runtime heap helpers with --skip-builtin'
const e2e_freestanding_missing_output_hook_message = 'v2: freestanding target requires freestanding_output hook for output'
const e2e_freestanding_missing_panic_hook_message = 'v2: freestanding target requires freestanding_panic hook for panic'

struct CleancCliResult {
	exit_code int
	output    string
	c_source  string
	out_path  string
	c_path    string
}

fn e2e_repo_root() string {
	mut dir := os.dir(@FILE)
	for _ in 0 .. 10 {
		if os.exists(os.join_path(dir, 'cmd', 'v2', 'v2.v'))
			&& os.exists(os.join_path(dir, 'vlib', 'builtin')) {
			return dir
		}
		dir = os.dir(dir)
	}
	panic('could not locate repo root for cleanc target e2e')
}

fn normalize_e2e_os_name(target_os string) string {
	return match target_os.to_lower() {
		'darwin', 'mac' { 'macos' }
		else { target_os.to_lower() }
	}
}

fn e2e_v2_binary_name() string {
	mut name := 'cleanc_target_e2e'
	$if windows {
		name += '.exe'
	}
	return name
}

fn build_v2_for_target_e2e(tmp_dir string) string {
	vroot := e2e_repo_root()
	v2_source := os.join_path(vroot, 'cmd', 'v2', 'v2.v')
	v2_binary := os.join_path(tmp_dir, e2e_v2_binary_name())
	res :=
		os.execute('"${@VEXE}" -path "${os.join_path(vroot, 'vlib')}|@vlib|@vmodules" -gc none -nocache "${v2_source}" -o "${v2_binary}"')
	if res.exit_code != 0 {
		panic('failed to build cmd/v2 for cleanc target e2e:\n${res.output}')
	}
	return v2_binary
}

fn build_v1_for_target_e2e(tmp_dir string) string {
	vroot := e2e_repo_root()
	v1_source := os.join_path(vroot, 'cmd', 'v')
	v1_binary := os.join_path(tmp_dir, 'v1_public_wrapper')
	res :=
		os.execute('"${@VEXE}" -path "${os.join_path(vroot, 'vlib')}|@vlib|@vmodules" -gc none -nocache "${v1_source}" -o "${v1_binary}"')
	if res.exit_code != 0 {
		panic('failed to build cmd/v for cleanc target e2e:\n${res.output}')
	}
	return v1_binary
}

fn run_v2_to_c(v2_binary string, tmp_dir string, name string, args []string, source string) CleancCliResult {
	return run_v2_to_c_with_env(v2_binary, tmp_dir, name, args, source, '')
}

fn run_v2_to_c_with_env(v2_binary string, tmp_dir string, name string, args []string, source string, env_prefix string) CleancCliResult {
	source_path := os.join_path(tmp_dir, '${name}.v')
	out_path := os.join_path(tmp_dir, '${name}.c')
	os.write_file(source_path, source) or { panic(err) }
	cmd := 'cd "${e2e_repo_root()}" && ${env_prefix}"${v2_binary}" -gc none -nocache --no-parallel ${args.join(' ')} -o "${out_path}" "${source_path}"'
	res := os.execute(cmd)
	c_source := if os.exists(out_path) { os.read_file(out_path) or { '' } } else { '' }
	return CleancCliResult{
		exit_code: res.exit_code
		output:    res.output
		c_source:  c_source
		out_path:  out_path
		c_path:    out_path
	}
}

fn run_v2_to_c_files(v2_binary string, tmp_dir string, name string, args []string, sources map[string]string) CleancCliResult {
	case_dir := os.join_path(tmp_dir, name)
	out_path := os.join_path(tmp_dir, '${name}.c')
	os.mkdir_all(case_dir) or { panic(err) }
	mut source_paths := []string{}
	mut source_names := sources.keys()
	source_names.sort()
	for source_name in source_names {
		source_path := os.join_path(case_dir, source_name)
		os.mkdir_all(os.dir(source_path)) or { panic(err) }
		os.write_file(source_path, sources[source_name]) or { panic(err) }
		source_paths << source_path
	}
	cmd := 'cd "${e2e_repo_root()}" && "${v2_binary}" -gc none -nocache --no-parallel ${args.join(' ')} -o "${out_path}" ${source_paths.map('"${it}"').join(' ')}'
	res := os.execute(cmd)
	c_source := if os.exists(out_path) { os.read_file(out_path) or { '' } } else { '' }
	return CleancCliResult{
		exit_code: res.exit_code
		output:    res.output
		c_source:  c_source
		out_path:  out_path
		c_path:    out_path
	}
}

fn run_v2_to_c_project_files(v2_binary string, tmp_dir string, name string, args []string, sources map[string]string, entry string) CleancCliResult {
	case_dir := os.join_path(tmp_dir, name)
	out_path := os.join_path(tmp_dir, '${name}.c')
	os.mkdir_all(case_dir) or { panic(err) }
	for source_name, source in sources {
		source_path := os.join_path(case_dir, source_name)
		os.mkdir_all(os.dir(source_path)) or { panic(err) }
		os.write_file(source_path, source) or { panic(err) }
	}
	entry_path := os.join_path(case_dir, entry)
	cmd := 'cd "${e2e_repo_root()}" && "${v2_binary}" -gc none -nocache --no-parallel ${args.join(' ')} -o "${out_path}" "${entry_path}"'
	res := os.execute(cmd)
	c_source := if os.exists(out_path) { os.read_file(out_path) or { '' } } else { '' }
	return CleancCliResult{
		exit_code: res.exit_code
		output:    res.output
		c_source:  c_source
		out_path:  out_path
		c_path:    out_path
	}
}

fn generated_c_output_path(output_path string) string {
	if output_path.ends_with('.c') {
		return output_path
	}
	return output_path + '.c'
}

fn e2e_binary_output_path(tmp_dir string, name string) string {
	mut path := os.join_path(tmp_dir, name)
	$if windows {
		path += '.exe'
	}
	return path
}

fn run_v2_to_binary(v2_binary string, tmp_dir string, name string, args []string, source string) CleancCliResult {
	source_path := os.join_path(tmp_dir, '${name}.v')
	out_path := e2e_binary_output_path(tmp_dir, name)
	os.write_file(source_path, source) or { panic(err) }
	env_prefix := if host_c_e2e_flags().len > 0 { 'V2CFLAGS="${host_c_e2e_flags()}" ' } else { '' }
	cmd := 'cd "${e2e_repo_root()}" && ${env_prefix}"${v2_binary}" -gc none -nocache --no-parallel ${args.join(' ')} -o "${out_path}" "${source_path}"'
	res := os.execute(cmd)
	return CleancCliResult{
		exit_code: res.exit_code
		output:    res.output
		out_path:  out_path
		c_path:    generated_c_output_path(out_path)
	}
}

fn run_v2_to_output(v2_binary string, tmp_dir string, name string, args []string, source string, output_path string) CleancCliResult {
	source_path := os.join_path(tmp_dir, '${name}.v')
	os.write_file(source_path, source) or { panic(err) }
	cmd := 'cd "${e2e_repo_root()}" && "${v2_binary}" -gc none -nocache --no-parallel ${args.join(' ')} -o "${output_path}" "${source_path}"'
	res := os.execute(cmd)
	c_path := generated_c_output_path(output_path)
	c_source := if os.exists(c_path) { os.read_file(c_path) or { '' } } else { '' }
	return CleancCliResult{
		exit_code: res.exit_code
		output:    res.output
		c_source:  c_source
		out_path:  output_path
		c_path:    c_path
	}
}

fn run_v2_without_output_in_dir(v2_binary string, tmp_dir string, name string, args []string, source string, work_dir string) CleancCliResult {
	source_path := os.join_path(tmp_dir, '${name}.v')
	os.write_file(source_path, source) or { panic(err) }
	os.mkdir_all(work_dir) or { panic(err) }
	env_prefix := if host_c_e2e_flags().len > 0 { 'V2CFLAGS="${host_c_e2e_flags()}" ' } else { '' }
	cmd := 'cd "${work_dir}" && ${env_prefix}"${v2_binary}" -gc none -nocache --no-parallel ${args.join(' ')} "${source_path}"'
	res := os.execute(cmd)
	c_path := os.join_path(work_dir, '${name}.c')
	c_source := if os.exists(c_path) { os.read_file(c_path) or { '' } } else { '' }
	return CleancCliResult{
		exit_code: res.exit_code
		output:    res.output
		c_source:  c_source
		out_path:  e2e_binary_output_path(work_dir, name)
		c_path:    c_path
	}
}

fn run_v2_without_output(v2_binary string, tmp_dir string, name string, args []string, source string) CleancCliResult {
	return run_v2_without_output_in_dir(v2_binary, tmp_dir, name, args, source, tmp_dir)
}

fn run_v1_v2_without_output_in_dir(v1_binary string, v2_binary string, tmp_dir string, name string, args []string, source string, work_dir string) CleancCliResult {
	source_path := os.join_path(tmp_dir, '${name}.v')
	os.write_file(source_path, source) or { panic(err) }
	os.mkdir_all(work_dir) or { panic(err) }
	repo_vexe := os.join_path(e2e_repo_root(), 'v')
	env_prefix := if host_c_e2e_flags().len > 0 { 'V2CFLAGS="${host_c_e2e_flags()}" ' } else { '' }
	cmd := 'cd "${work_dir}" && ${env_prefix}VEXE="${repo_vexe}" V_V2_EXE="${v2_binary}" "${v1_binary}" -v2 -gc none -nocache --no-parallel ${args.join(' ')} "${source_path}"'
	res := os.execute(cmd)
	c_path := os.join_path(work_dir, '${name}.c')
	c_source := if os.exists(c_path) { os.read_file(c_path) or { '' } } else { '' }
	return CleancCliResult{
		exit_code: res.exit_code
		output:    res.output
		c_source:  c_source
		out_path:  e2e_binary_output_path(work_dir, name)
		c_path:    c_path
	}
}

fn run_v1_v2_to_output(v1_binary string, v2_binary string, tmp_dir string, name string, args []string, source string, output_path string) CleancCliResult {
	source_path := os.join_path(tmp_dir, '${name}.v')
	os.write_file(source_path, source) or { panic(err) }
	repo_vexe := os.join_path(e2e_repo_root(), 'v')
	cmd := 'cd "${e2e_repo_root()}" && VEXE="${repo_vexe}" V_V2_EXE="${v2_binary}" "${v1_binary}" -v2 -gc none -nocache --no-parallel ${args.join(' ')} -o "${output_path}" "${source_path}"'
	res := os.execute(cmd)
	c_source := if os.exists(output_path) { os.read_file(output_path) or { '' } } else { '' }
	return CleancCliResult{
		exit_code: res.exit_code
		output:    res.output
		c_source:  c_source
		out_path:  output_path
		c_path:    output_path
	}
}

fn run_v2_to_output_with_cache(v2_binary string, tmp_dir string, name string, args []string, source string, output_path string) CleancCliResult {
	source_path := os.join_path(tmp_dir, '${name}.v')
	os.write_file(source_path, source) or { panic(err) }
	cmd := 'cd "${e2e_repo_root()}" && "${v2_binary}" -gc none --no-parallel ${args.join(' ')} -o "${output_path}" "${source_path}"'
	res := os.execute(cmd)
	c_path := generated_c_output_path(output_path)
	c_source := if os.exists(c_path) { os.read_file(c_path) or { '' } } else { '' }
	return CleancCliResult{
		exit_code: res.exit_code
		output:    res.output
		c_source:  c_source
		out_path:  output_path
		c_path:    c_path
	}
}

fn assert_cli_success(res CleancCliResult) {
	assert res.exit_code == 0, res.output
	assert os.exists(res.out_path), res.output
	assert res.c_source.len > 0, res.output
}

fn assert_generated_c_static_assert_contains(res CleancCliResult, expected string) {
	assert_cli_success(res)
	assert res.c_source.contains('_Static_assert(0, "${expected}'), res.c_source
}

fn assert_generated_c_heap_runtime_static_assert_contains(res CleancCliResult, helper string) {
	assert_generated_c_static_assert_contains(res,
		'${e2e_freestanding_missing_heap_runtime_message}: ${helper}')
}

fn assert_binary_success(res CleancCliResult) {
	assert res.exit_code == 0, res.output
	assert os.exists(res.out_path), res.output
}

fn assert_generated_c_only(res CleancCliResult) {
	assert res.exit_code == 0, res.output
	assert os.exists(res.c_path), res.output
	assert res.c_source.len > 0, res.output
	assert !os.exists(res.out_path), 'unexpected local executable ${res.out_path}\n${res.output}'
	assert res.output.contains('local C compilation disabled for this target'), res.output
}

fn assert_cli_failure_contains(res CleancCliResult, expected string) {
	assert res.exit_code != 0, res.output
	assert res.output.contains(expected), res.output
	assert !os.exists(res.out_path), 'failed command wrote unexpected output ${res.out_path}\n${res.output}'
	if res.c_path != res.out_path {
		assert !os.exists(res.c_path), 'failed command wrote unexpected C output ${res.c_path}\n${res.output}'
	}
}

fn autofree_array_cleanup_source() string {
	return 'module main

fn build_empty_array() {
	items := []int{}
}

fn main() {
	build_empty_array()
}
'
}

fn autofree_mut_array_cleanup_source() string {
	return 'module main

fn build_mut_empty_array() {
	mut items := []int{}
}

fn main() {
	build_mut_empty_array()
}
'
}

fn autofree_string_array_cleanup_source() string {
	return 'module main

fn build_empty_string_array() {
	items := []string{}
}

fn main() {
	build_empty_string_array()
}
'
}

fn autofree_mut_string_array_cleanup_source() string {
	return 'module main

fn build_mut_empty_string_array() {
	mut items := []string{}
}

fn main() {
	build_mut_empty_string_array()
}
'
}

fn autofree_prefixed_array_cleanup_source() string {
	return 'module main

fn build_empty_array_after_scalar() {
	_n := 1
	items := []int{}
}

fn build_empty_string_array_after_scalar() {
	_n := 1
	items := []string{}
}

fn main() {
	build_empty_array_after_scalar()
	build_empty_string_array_after_scalar()
}
'
}

fn autofree_transfer_prefixed_array_cleanup_source() string {
	return 'module main

fn build_empty_array_after_transfer(source []int) {
	copy := source
	items := []int{}
}

fn build_empty_string_array_after_transfer(source []string) {
	copy := source
	items := []string{}
}

fn main() {
	build_empty_array_after_transfer([]int{})
	build_empty_string_array_after_transfer([]string{})
}
'
}

fn autofree_rule110_style_clone_cleanup_source() string {
	return 'module main

fn next_generation(mut gen []int) {
	mut arr := gen.clone()
	for i in 0 .. gen.len {
		arr[i] = gen[i]
	}
	gen = arr.clone()
}

fn main() {
	mut gen := []int{}
	next_generation(mut gen)
}
'
}

fn autofree_fresh_local_final_clone_cleanup_source() string {
	return 'module main

fn fill_array_from_fresh_local(mut dst []int) {
	mut arr := []int{}
	dst = arr.clone()
}

fn main() {
	mut dst := []int{}
	fill_array_from_fresh_local(mut dst)
}
'
}

fn autofree_prefixed_fresh_local_final_clone_cleanup_source() string {
	return 'module main

fn fill_array_from_prefixed_fresh_local(mut dst []int) {
	seed := 1
	mut arr := []int{}
	dst = arr.clone()
}

fn main() {
	mut dst := []int{}
	fill_array_from_prefixed_fresh_local(mut dst)
}
'
}

fn autofree_cap_only_array_cleanup_source() string {
	return 'module main

fn build_array_with_cap(n int) {
	mut items := []int{cap: n}
}

fn main() {
	build_array_with_cap(4)
}
'
}

fn autofree_len_only_array_cleanup_source() string {
	return 'module main

fn build_array_with_len(n int) {
	mut items := []int{len: n}
}

fn main() {
	build_array_with_len(4)
}
'
}

fn autofree_single_final_len_array_cleanup_source() string {
	return 'module main

fn build_empty_array_final_len() {
	mut items := []int{}
	sink := items.len
}

fn build_cap_array_final_len(n int) {
	mut items := []int{cap: n}
	sink := items.len
}

fn build_len_array_final_len(n int) {
	mut items := []int{len: n}
	sink := items.len
}

fn main() {
	build_empty_array_final_len()
	build_cap_array_final_len(4)
	build_len_array_final_len(4)
}
'
}

fn autofree_local_array_push_literal_sink_cleanup_source() string {
	return 'module main

fn build_local_array_push_literal_return() int {
	mut items := []int{}
	items << 1
	items << 2
	n := items.len
	return n
}

fn main() {
	build_local_array_push_literal_return()
}
'
}

fn autofree_two_array_cleanup_source() string {
	return 'module main

fn build_two_empty_arrays() {
	mut first := []int{}
	mut second := []int{}
	sink := first.len + second.len
}

fn build_two_cap_arrays(n int) {
	mut first := []int{cap: n}
	mut second := []int{cap: n}
	sink := first.len + second.len + n
}

fn build_two_len_arrays(n int) {
	mut first := []int{len: n}
	mut second := []int{len: n}
	sink := first.len + second.len + n
}

fn main() {
	build_two_empty_arrays()
	build_two_cap_arrays(4)
	build_two_len_arrays(4)
}
'
}

fn autofree_mixed_two_array_cleanup_source() string {
	return 'module main

fn build_mixed_empty_cap_arrays(n int) {
	mut first := []int{}
	mut second := []int{cap: n}
	sink := first.len + second.len + n
}

fn build_mixed_cap_empty_arrays(n int) {
	mut first := []int{cap: n}
	mut second := []int{}
	sink := first.len + second.len + n
}

fn build_mixed_empty_len_arrays(n int) {
	mut first := []int{}
	mut second := []int{len: n}
	sink := first.len + second.len + n
}

fn build_mixed_len_empty_arrays(n int) {
	mut first := []int{len: n}
	mut second := []int{}
	sink := first.len + second.len + n
}

fn build_mixed_cap_len_arrays(n int) {
	mut first := []int{cap: n}
	mut second := []int{len: n}
	sink := first.len + second.len + n
}

fn build_mixed_len_cap_arrays(n int) {
	mut first := []int{len: n}
	mut second := []int{cap: n}
	sink := first.len + second.len + n
}

fn main() {
	build_mixed_empty_cap_arrays(4)
	build_mixed_cap_empty_arrays(4)
	build_mixed_empty_len_arrays(4)
	build_mixed_len_empty_arrays(4)
	build_mixed_cap_len_arrays(4)
	build_mixed_len_cap_arrays(4)
}
'
}

fn autofree_prefixed_cap_len_array_cleanup_source() string {
	return 'module main

fn build_array_with_cap_after_transfer(n int, source []int) {
	copy := source
	mut items := []int{cap: n}
}

fn build_array_with_len_after_transfer(n int, source []int) {
	copy := source
	mut items := []int{len: n}
}

fn main() {
	build_array_with_cap_after_transfer(4, []int{})
	build_array_with_len_after_transfer(4, []int{})
}
'
}

fn autofree_len_only_final_clone_cleanup_source() string {
	return 'module main

fn fill_array_from_len_only(n int, mut dst []int) {
	mut arr := []int{len: n}
	dst = arr.clone()
}

fn main() {
	mut dst := []int{}
	fill_array_from_len_only(4, mut dst)
}
'
}

fn autofree_cap_only_final_clone_cleanup_source() string {
	return 'module main

fn fill_array_from_cap_only(n int, mut dst []int) {
	mut arr := []int{cap: n}
	dst = arr.clone()
}

fn main() {
	mut dst := []int{}
	fill_array_from_cap_only(4, mut dst)
}
'
}

fn autofree_multi_param_fresh_local_final_clone_cleanup_source() string {
	return 'module main

fn fill_array_from_fresh_local_with_extra(x int, mut dst []int) {
	mut arr := []int{}
	dst = arr.clone()
}

fn main() {
	mut dst := []int{}
	fill_array_from_fresh_local_with_extra(1, mut dst)
}
'
}

fn autofree_receiver_fresh_local_final_clone_cleanup_source() string {
	return 'module main

struct Game {}

fn (g &Game) fill_array_from_fresh_local(mut dst []int) {
	mut arr := []int{}
	dst = arr.clone()
}

fn main() {
	g := Game{}
	mut dst := []int{}
	g.fill_array_from_fresh_local(mut dst)
}
'
}

fn autofree_receiver_field_slice_clone_cleanup_source() string {
	return 'module main

struct Game {
	items []int
}

fn (g &Game) fill_array_from_field_slice(idx int, n int, mut dst []int) {
	next := g.items[idx..idx + n].clone()
	dst = next.clone()
}

fn main() {
	g := Game{
		items: [1, 2, 3, 4]
	}
	mut dst := []int{}
	g.fill_array_from_field_slice(0, 2, mut dst)
}
'
}

fn autofree_receiver_field_slice_clone_nested_then_cleanup_source() string {
	return 'module main

struct Game {
	items []int
}

fn (g &Game) fill_array_from_field_slice_then_loop(idx int, n int, mut dst []int) {
	if idx >= 0 {
		next := g.items[idx..idx + n].clone()
		for i := 0; i < n; i++ {
			value := next[i]
			dst << value
		}
	}
}

fn main() {
	g := Game{
		items: [1, 2, 3, 4]
	}
	mut dst := []int{}
	g.fill_array_from_field_slice_then_loop(0, 2, mut dst)
}
'
}

fn autofree_loop_local_clone_push_cleanup_source() string {
	return 'module main

struct Board {
mut:
	rows [][]int
}

fn (mut b Board) fill_rows(height int, width int) {
	for _ in 0 .. height {
		mut row := []int{len: width}
		row[0] = -1
		row[width - 1] = -1
		b.rows << row.clone()
	}
}

fn main() {
	mut b := Board{}
	b.fill_rows(2, 4)
}
'
}

fn autofree_loop_local_clone_push_preamble_cleanup_source() string {
	return 'module main

struct Board {
mut:
	rows [][]int
}

fn (mut b Board) fill_rows_after_setup(height int, width int) {
	start := 0
	limit := height + start
	right := width - 1
	adjusted_width := width + start
	mut scratch := []int{}
	for _ in 0 .. limit {
		first := start
		second := first + 1
		third := second + 1
		scratch << third
	}
	for _ in 0 .. limit {
		mut row := []int{len: adjusted_width}
		row[0] = -1
		row[right] = -1
		b.rows << row.clone()
	}
}

fn main() {
	mut b := Board{}
	b.fill_rows_after_setup(2, 4)
}
'
}

fn autofree_fresh_local_string_clone_push_cleanup_source() string {
	return 'module main

fn push_joined(left string, right string, mut items []string) int {
	text := left + right
	items << text
	return items.len
}

fn main() {
	mut items := []string{}
	_ := push_joined("a", "b", mut items)
}
'
}

fn autofree_fresh_local_string_clone_push_local_destination_cleanup_source() string {
	return 'module main

fn build(left string, right string) int {
	mut items := []string{}
	text := left + right
	items << text
	return items.len
}

fn main() {
	_ := build("a", "b")
}
'
}

fn autofree_eprintln_string_interpolation_cleanup_source() string {
	dollar := '$'
	return 'module main

fn log_ai(n int) {
	eprintln("AI ${dollar}{n}")
}

fn main() {
	log_ai(7)
}
'
}

fn e2e_example_source(path string) string {
	source_path := os.join_path(e2e_repo_root(), path)
	return os.read_file(source_path) or { panic('failed to read ${path}: ${err}') }
}

fn generated_c_function_body(c_source string, fn_name string) ?string {
	for signature in ['void ${fn_name}(', 'int ${fn_name}('] {
		mut search_from := 0
		for {
			fn_idx := c_source_find_line_prefix_after(c_source, signature, search_from) or { break }
			body_start := c_source.index_after('{', fn_idx) or { return none }
			prototype_end := c_source.index_after(';', fn_idx) or { c_source.len }
			if body_start < prototype_end {
				body_end := c_source.index_after('\n}', body_start) or { return none }
				return c_source[body_start + 1..body_end]
			}
			search_from = fn_idx + signature.len
		}
	}
	return none
}

fn generated_c_function_body_or_fail(res CleancCliResult, fn_name string) string {
	body := generated_c_function_body(res.c_source, fn_name) or {
		assert false, res.c_source
		return ''
	}
	return body
}

fn generated_c_matching_brace_idx(source string, open_idx int) ?int {
	if open_idx < 0 || open_idx >= source.len || source[open_idx] != `{` {
		return none
	}
	mut depth := 0
	for i in open_idx .. source.len {
		if source[i] == `{` {
			depth++
		}
		if source[i] == `}` {
			depth--
			if depth == 0 {
				return i
			}
		}
	}
	return none
}

fn assert_autofree_array_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_cli_success(res)
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 1, res.c_source
	assert body.contains('array__free(&items);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_array_cleanup_absent_in_fn(res CleancCliResult, fn_name string) {
	assert res.exit_code == 0, res.output
	assert res.c_source.len > 0, res.output
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 0, res.c_source
	assert !body.contains('array__free(&items);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_transfer_prefix_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_cli_success(res)
	body := generated_c_function_body_or_fail(res, fn_name)
	assert body.contains('array__free(&items);'), res.c_source
	assert !body.contains('array__free(&copy);'), res.c_source
	assert !body.contains('array__free(&source);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_transfer_prefix_cleanup_absent_in_fn(res CleancCliResult, fn_name string) {
	assert res.exit_code == 0, res.output
	assert res.c_source.len > 0, res.output
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 0, res.c_source
	assert !body.contains('array__free(&items);'), res.c_source
	assert !body.contains('array__free(&copy);'), res.c_source
	assert !body.contains('array__free(&source);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_rule110_clone_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_cli_success(res)
	body := generated_c_function_body_or_fail(res, fn_name)
	final_clone_idx := body.index_after('gen = array__clone', 0) or {
		assert false, res.c_source
		return
	}
	cleanup_idx := body.index_after('array__free(&arr);', 0) or {
		assert false, res.c_source
		return
	}
	assert final_clone_idx < cleanup_idx, res.c_source
	assert !body[..final_clone_idx].contains('array__free(&arr);'), res.c_source
	assert !body.contains('array__free(&gen);'), res.c_source
	assert !body.contains('array__free(gen);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_rule110_clone_cleanup_absent_in_fn(res CleancCliResult, fn_name string) {
	assert res.exit_code == 0, res.output
	assert res.c_source.len > 0, res.output
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 0, res.c_source
	assert !body.contains('array__free(&arr);'), res.c_source
	assert !body.contains('array__free(&gen);'), res.c_source
	assert !body.contains('array__free(gen);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_cap_only_array_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_cli_success(res)
	body := generated_c_function_body_or_fail(res, fn_name)
	allocation_idx := body.index_after('items = __new_array', 0) or {
		assert false, res.c_source
		return
	}
	cleanup_idx := body.index_after('array__free(&items);', 0) or {
		assert false, res.c_source
		return
	}
	assert allocation_idx < cleanup_idx, res.c_source
	assert !body[..allocation_idx].contains('array__free(&items);'), res.c_source
	assert !body.contains('array__clone'), res.c_source
	assert !body.contains('array__free(&dst);'), res.c_source
	assert !body.contains('array__free(dst);'), res.c_source
	assert !body.contains('dst'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_len_only_array_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_cli_success(res)
	body := generated_c_function_body_or_fail(res, fn_name)
	allocation_idx := body.index_after('items = __new_array', 0) or {
		assert false, res.c_source
		return
	}
	cleanup_idx := body.index_after('array__free(&items);', 0) or {
		assert false, res.c_source
		return
	}
	assert allocation_idx < cleanup_idx, res.c_source
	assert !body[..allocation_idx].contains('array__free(&items);'), res.c_source
	assert !body.contains('array__clone'), res.c_source
	assert !body.contains('array__free(&dst);'), res.c_source
	assert !body.contains('array__free(dst);'), res.c_source
	assert !body.contains('dst'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_single_final_len_array_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_cli_success(res)
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 1, res.c_source
	allocation_idx := body.index_after('items = __new_array', 0) or {
		assert false, res.c_source
		return
	}
	final_len_idx := body.index_after('items.len', allocation_idx) or {
		assert false, res.c_source
		return
	}
	cleanup_idx := body.index_after('array__free(&items);', 0) or {
		assert false, res.c_source
		return
	}
	assert allocation_idx < final_len_idx, res.c_source
	assert final_len_idx < cleanup_idx, res.c_source
	assert !body[..final_len_idx].contains('array__free(&items);'), res.c_source
	assert !body.contains('array__clone'), res.c_source
	assert !body.contains('array__free(&sink);'), res.c_source
	assert !body.contains('array__free(&n);'), res.c_source
	assert !body.contains('array__free(n);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_single_final_len_array_cleanup_absent_in_fn(res CleancCliResult, fn_name string) {
	assert res.exit_code == 0, res.output
	assert res.c_source.len > 0, res.output
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 0, res.c_source
	assert !body.contains('array__free(&items);'), res.c_source
	assert !body.contains('array__free(&sink);'), res.c_source
	assert !body.contains('array__free(&n);'), res.c_source
	assert !body.contains('array__free(n);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_local_array_push_literal_sink_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_cli_success(res)
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 1, res.c_source
	allocation_idx := body.index_after('items = __new_array', 0) or {
		assert false, res.c_source
		return
	}
	first_push_idx := body.index_after('array__push', allocation_idx) or {
		assert false, res.c_source
		return
	}
	second_push_idx := body.index_after('array__push', first_push_idx + 'array__push'.len) or {
		assert false, res.c_source
		return
	}
	final_len_idx := body.index_after('items.len', second_push_idx) or {
		assert false, res.c_source
		return
	}
	cleanup_idx := body.index_after('array__free(&items);', 0) or {
		assert false, res.c_source
		return
	}
	return_idx := body.index_after('return n;', cleanup_idx) or {
		assert false, res.c_source
		return
	}
	assert allocation_idx < first_push_idx, res.c_source
	assert first_push_idx < second_push_idx, res.c_source
	assert second_push_idx < final_len_idx, res.c_source
	assert final_len_idx < cleanup_idx, res.c_source
	assert cleanup_idx < return_idx, res.c_source
	assert !body[..final_len_idx].contains('array__free(&items);'), res.c_source
	assert !body.contains('array__clone'), res.c_source
	assert !body.contains('array__free(&n);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_local_array_push_literal_sink_cleanup_absent_in_fn(res CleancCliResult, fn_name string) {
	assert res.exit_code == 0, res.output
	assert res.c_source.len > 0, res.output
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 0, res.c_source
	assert !body.contains('array__free(&items);'), res.c_source
	assert !body.contains('array__free(&n);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_prefixed_cap_len_array_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_cli_success(res)
	body := generated_c_function_body_or_fail(res, fn_name)
	allocation_idx := body.index_after('items = __new_array', 0) or {
		assert false, res.c_source
		return
	}
	cleanup_idx := body.index_after('array__free(&items);', 0) or {
		assert false, res.c_source
		return
	}
	assert allocation_idx < cleanup_idx, res.c_source
	assert !body[..allocation_idx].contains('array__free(&items);'), res.c_source
	assert !body.contains('array__clone'), res.c_source
	assert !body.contains('array__free(&copy);'), res.c_source
	assert !body.contains('array__free(&source);'), res.c_source
	assert !body.contains('array__free(&n);'), res.c_source
	assert !body.contains('array__free(n);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_prefixed_cap_len_array_cleanup_absent_in_fn(res CleancCliResult, fn_name string) {
	assert res.exit_code == 0, res.output
	assert res.c_source.len > 0, res.output
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 0, res.c_source
	assert !body.contains('array__free(&items);'), res.c_source
	assert !body.contains('array__free(&copy);'), res.c_source
	assert !body.contains('array__free(&source);'), res.c_source
	assert !body.contains('array__free(&n);'), res.c_source
	assert !body.contains('array__free(n);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_two_array_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_cli_success(res)
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 2, res.c_source
	first_decl_idx := body.index_after('first = __new_array', 0) or {
		assert false, res.c_source
		return
	}
	second_decl_idx := body.index_after('second = __new_array', 0) or {
		assert false, res.c_source
		return
	}
	second_cleanup_idx := body.index_after('array__free(&second);', 0) or {
		assert false, res.c_source
		return
	}
	first_cleanup_idx := body.index_after('array__free(&first);', 0) or {
		assert false, res.c_source
		return
	}
	assert first_decl_idx < second_decl_idx, res.c_source
	assert second_decl_idx < second_cleanup_idx, res.c_source
	assert second_cleanup_idx < first_cleanup_idx, res.c_source
	assert !body[..second_decl_idx].contains('array__free(&second);'), res.c_source
	assert !body[..first_decl_idx].contains('array__free(&first);'), res.c_source
	assert !body.contains('array__free(&n);'), res.c_source
	assert !body.contains('array__free(n);'), res.c_source
	assert !body.contains('array__clone'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn generated_c_body_substring_count(body string, needle string) int {
	if needle.len == 0 {
		return 0
	}
	mut count := 0
	mut search_from := 0
	for search_from < body.len {
		idx := body.index_after(needle, search_from) or { break }
		count++
		search_from = idx + needle.len
	}
	return count
}

fn assert_autofree_two_array_cleanup_absent_in_fn(res CleancCliResult, fn_name string) {
	assert res.exit_code == 0, res.output
	assert res.c_source.len > 0, res.output
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 0, res.c_source
	assert !body.contains('array__free(&first);'), res.c_source
	assert !body.contains('array__free(&second);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_fresh_local_final_clone_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_cli_success(res)
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 1, res.c_source
	final_clone_idx := body.index_after('dst = array__clone', 0) or {
		assert false, res.c_source
		return
	}
	cleanup_idx := body.index_after('array__free(&arr);', 0) or {
		assert false, res.c_source
		return
	}
	assert final_clone_idx < cleanup_idx, res.c_source
	assert !body[..final_clone_idx].contains('array__free(&arr);'), res.c_source
	assert !body.contains('array__free(&seed);'), res.c_source
	assert !body.contains('array__free(&dst);'), res.c_source
	assert !body.contains('array__free(dst);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_fresh_local_final_clone_cleanup_absent_in_fn(res CleancCliResult, fn_name string) {
	assert res.exit_code == 0, res.output
	assert res.c_source.len > 0, res.output
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 0, res.c_source
	assert !body.contains('array__free(&arr);'), res.c_source
	assert !body.contains('array__free(&seed);'), res.c_source
	assert !body.contains('array__free(&dst);'), res.c_source
	assert !body.contains('array__free(dst);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_len_only_final_clone_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_autofree_fresh_local_final_clone_cleanup_present_in_fn(res, fn_name)
	body := generated_c_function_body_or_fail(res, fn_name)
	assert !body.contains('array__free(&n);'), res.c_source
	assert !body.contains('array__free(n);'), res.c_source
}

fn assert_autofree_receiver_fresh_local_final_clone_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_autofree_fresh_local_final_clone_cleanup_present_in_fn(res, fn_name)
	body := generated_c_function_body_or_fail(res, fn_name)
	assert !body.contains('array__free(&g'), res.c_source
	assert !body.contains('array__free(g'), res.c_source
}

fn assert_autofree_receiver_fresh_local_final_clone_cleanup_absent_in_fn(res CleancCliResult, fn_name string) {
	assert_autofree_fresh_local_final_clone_cleanup_absent_in_fn(res, fn_name)
	body := generated_c_function_body_or_fail(res, fn_name)
	assert !body.contains('array__free(&g'), res.c_source
	assert !body.contains('array__free(g'), res.c_source
}

fn assert_autofree_receiver_field_slice_clone_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_cli_success(res)
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 1, res.c_source
	final_clone_idx := body.index_after('dst = array__clone', 0) or {
		assert false, res.c_source
		return
	}
	cleanup_idx := body.index_after('array__free(&next);', 0) or {
		assert false, res.c_source
		return
	}
	assert final_clone_idx < cleanup_idx, res.c_source
	assert !body[..final_clone_idx].contains('array__free(&next);'), res.c_source
	assert !body.contains('array__free(&g'), res.c_source
	assert !body.contains('array__free(g'), res.c_source
	assert !body.contains('array__free(&g->items'), res.c_source
	assert !body.contains('array__free(&(g->items'), res.c_source
	assert !body.contains('array__free(&dst);'), res.c_source
	assert !body.contains('array__free(dst);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_receiver_field_slice_clone_nested_then_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_cli_success(res)
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 1, res.c_source
	if_idx := body.index_after('if (', 0) or {
		assert false, res.c_source
		return
	}
	if_open_idx := body.index_after('{', if_idx) or {
		assert false, res.c_source
		return
	}
	if_close_idx := generated_c_matching_brace_idx(body, if_open_idx) or {
		assert false, res.c_source
		return
	}
	for_idx := body.index_after('for (', if_idx) or {
		assert false, res.c_source
		return
	}
	cleanup_idx := body.index_after('array__free(&next);', for_idx) or {
		assert false, res.c_source
		return
	}
	assert if_idx < for_idx, res.c_source
	assert for_idx < cleanup_idx, res.c_source
	assert cleanup_idx < if_close_idx, res.c_source
	assert !body[..for_idx].contains('array__free(&next);'), res.c_source
	assert !body.contains('array__free(&g'), res.c_source
	assert !body.contains('array__free(g'), res.c_source
	assert !body.contains('array__free(&g->items'), res.c_source
	assert !body.contains('array__free(&(g->items'), res.c_source
	assert !body.contains('array__free(&idx);'), res.c_source
	assert !body.contains('array__free(&n);'), res.c_source
	assert !body.contains('array__free(&dst);'), res.c_source
	assert !body.contains('array__free(dst);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_receiver_field_slice_clone_cleanup_absent_in_fn(res CleancCliResult, fn_name string) {
	assert res.exit_code == 0, res.output
	assert res.c_source.len > 0, res.output
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 0, res.c_source
	assert !body.contains('array__free(&next);'), res.c_source
	assert !body.contains('array__free(&g'), res.c_source
	assert !body.contains('array__free(g'), res.c_source
	assert !body.contains('array__free(&g->items'), res.c_source
	assert !body.contains('array__free(&(g->items'), res.c_source
	assert !body.contains('array__free(&dst);'), res.c_source
	assert !body.contains('array__free(dst);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_loop_local_clone_push_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_cli_success(res)
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 1, res.c_source
	allocation_idx := body.index_after('row = __new_array', 0) or {
		assert false, res.c_source
		return
	}
	mut for_idx := -1
	mut for_open_idx := -1
	mut for_close_idx := -1
	mut search_from := 0
	for {
		next_for_idx := body.index_after('for (', search_from) or { break }
		next_for_open_idx := body.index_after('{', next_for_idx) or {
			assert false, res.c_source
			return
		}
		next_for_close_idx := generated_c_matching_brace_idx(body, next_for_open_idx) or {
			assert false, res.c_source
			return
		}
		if next_for_idx < allocation_idx && allocation_idx < next_for_close_idx {
			for_idx = next_for_idx
			for_open_idx = next_for_open_idx
			for_close_idx = next_for_close_idx
			break
		}
		search_from = next_for_idx + 1
	}
	if for_idx < 0 || for_open_idx < 0 || for_close_idx < 0 {
		assert false, res.c_source
		return
	}
	push_idx := body.index_after('array__push', allocation_idx) or {
		assert false, res.c_source
		return
	}
	row_clone_idx := body.index_after('array__clone(row)', allocation_idx) or {
		body.index_after('array__clone_to_depth(&row, 0)', allocation_idx) or {
			assert false, res.c_source
			return
		}
	}
	cleanup_idx := body.index_after('array__free(&row);', push_idx) or {
		assert false, res.c_source
		return
	}
	assert for_idx < allocation_idx, res.c_source
	assert allocation_idx < push_idx, res.c_source
	assert for_open_idx < allocation_idx, res.c_source
	assert push_idx < cleanup_idx, res.c_source
	assert row_clone_idx < cleanup_idx, res.c_source
	assert cleanup_idx < for_close_idx, res.c_source
	assert !body[..push_idx].contains('array__free(&row);'), res.c_source
	assert !body.contains('array__free(&b'), res.c_source
	assert !body.contains('array__free(b'), res.c_source
	assert !body.contains('array__free(&b->rows'), res.c_source
	assert !body.contains('array__free(&(b->rows'), res.c_source
	assert !body.contains('array__free(&height);'), res.c_source
	assert !body.contains('array__free(&width);'), res.c_source
	assert !body.contains('array__free(&start);'), res.c_source
	assert !body.contains('array__free(&limit);'), res.c_source
	assert !body.contains('array__free(&right);'), res.c_source
	assert !body.contains('array__free(&adjusted_width);'), res.c_source
	assert !body.contains('array__free(&scratch);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_loop_local_clone_push_cleanup_absent_in_fn(res CleancCliResult, fn_name string) {
	assert res.exit_code == 0, res.output
	assert res.c_source.len > 0, res.output
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'array__free(')
	assert free_count == 0, res.c_source
	assert !body.contains('array__free(&row);'), res.c_source
	assert !body.contains('array__free(&b'), res.c_source
	assert !body.contains('array__free(b'), res.c_source
	assert !body.contains('array__free(&b->rows'), res.c_source
	assert !body.contains('array__free(&(b->rows'), res.c_source
	assert !body.contains('array__free(&start);'), res.c_source
	assert !body.contains('array__free(&limit);'), res.c_source
	assert !body.contains('array__free(&right);'), res.c_source
	assert !body.contains('array__free(&adjusted_width);'), res.c_source
	assert !body.contains('array__free(&scratch);'), res.c_source
	assert !body.contains('string__free'), res.c_source
}

fn assert_autofree_fresh_local_string_clone_push_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert_cli_success(res)
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'string__free(&text);')
	assert free_count == 1, res.c_source
	assert generated_c_body_substring_count(body, 'string__free(') == 1, res.c_source
	plus_idx := body.index_after('string__plus', 0) or {
		assert false, res.c_source
		return
	}
	push_idx := body.index_after('array__push', plus_idx) or {
		assert false, res.c_source
		return
	}
	clone_idx := body.index_after('string__clone(text)', plus_idx) or {
		assert false, res.c_source
		return
	}
	cleanup_idx := body.index_after('string__free(&text);', push_idx) or {
		assert false, res.c_source
		return
	}
	return_idx := body.index_after('return ', cleanup_idx) or {
		assert false, res.c_source
		return
	}
	assert plus_idx < push_idx, res.c_source
	assert push_idx < clone_idx, res.c_source
	assert clone_idx < cleanup_idx, res.c_source
	assert cleanup_idx < return_idx, res.c_source
	assert !body[..push_idx].contains('string__free(&text);'), res.c_source
	assert generated_c_body_substring_count(body, 'array__push') == 1, res.c_source
	assert generated_c_body_substring_count(body, 'string__clone(text)') == 1, res.c_source
	assert generated_c_body_substring_count(body, 'array__free(') == 0, res.c_source
	assert !body.contains('array__free(&items);'), res.c_source
	assert !body.contains('string__free(&items);'), res.c_source
	assert !body.contains('string__free(&left);'), res.c_source
	assert !body.contains('string__free(&right);'), res.c_source
	assert !body.contains('string__free(&_ap'), res.c_source
	assert !body.contains('string__free(&g'), res.c_source
}

fn assert_autofree_fresh_local_string_clone_push_cleanup_absent_in_fn(res CleancCliResult, fn_name string) {
	assert res.exit_code == 0, res.output
	assert res.c_source.len > 0, res.output
	body := generated_c_function_body_or_fail(res, fn_name)
	assert generated_c_body_substring_count(body, 'string__free(&text);') == 0, res.c_source
	assert generated_c_body_substring_count(body, 'string__free(') == 0, res.c_source
	assert generated_c_body_substring_count(body, 'array__free(') == 0, res.c_source
	assert body.contains('string__plus'), res.c_source
	assert body.contains('array__push'), res.c_source
	assert body.contains('string__clone(text)'), res.c_source
	assert !body.contains('array__free(&items);'), res.c_source
	assert !body.contains('string__free(&items);'), res.c_source
	assert !body.contains('string__free(&left);'), res.c_source
	assert !body.contains('string__free(&right);'), res.c_source
	assert !body.contains('string__free(&_ap'), res.c_source
	assert !body.contains('string__free(&g'), res.c_source
}

fn assert_autofree_eprintln_string_interpolation_cleanup_present_in_fn(res CleancCliResult, fn_name string) {
	assert res.exit_code == 0, res.output
	assert res.c_source.len > 0, res.output
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'string__free(&_eprintln_inter_tmp_')
	assert free_count == 1, res.c_source
	decl_idx := body.index_after('string _eprintln_inter_tmp_', 0) or {
		assert false, res.c_source
		return
	}
	call_idx := body.index_after('eprintln(_eprintln_inter_tmp_', decl_idx) or {
		assert false, res.c_source
		return
	}
	cleanup_idx := body.index_after('string__free(&_eprintln_inter_tmp_', call_idx) or {
		assert false, res.c_source
		return
	}
	assert decl_idx < call_idx, res.c_source
	assert call_idx < cleanup_idx, res.c_source
	assert generated_c_body_substring_count(body, 'eprintln(_eprintln_inter_tmp_') == 1, res.c_source
	assert generated_c_body_substring_count(body, 'array__free(') == 0, res.c_source
	assert !body.contains('string__free(&n)'), res.c_source
}

fn assert_autofree_eprintln_string_interpolation_cleanup_absent_in_fn(res CleancCliResult, fn_name string) {
	assert res.exit_code == 0, res.output
	assert res.c_source.len > 0, res.output
	body := generated_c_function_body_or_fail(res, fn_name)
	free_count := generated_c_body_substring_count(body, 'string__free(&_eprintln_inter_tmp_')
	assert free_count == 0, res.c_source
	assert !body.contains('string _eprintln_inter_tmp_'), res.c_source
	assert !body.contains('eprintln(_eprintln_inter_tmp_'), res.c_source
}

fn assert_autofree_array_cleanup_present(res CleancCliResult) {
	assert_autofree_array_cleanup_present_in_fn(res, 'build_empty_array')
}

fn assert_autofree_array_cleanup_absent(res CleancCliResult) {
	assert_autofree_array_cleanup_absent_in_fn(res, 'build_empty_array')
}

struct CleancAutofreeCleanupCase {
	name            string
	args            []string
	source          string
	fn_names        []string
	expect_cleanup  bool
	transfer_prefix bool
}

fn cleanc_autofree_hosted_args() []string {
	return ['-autofree', '-backend', 'cleanc']
}

fn cleanc_autofree_cross_args() []string {
	return ['-autofree', '-backend', 'cleanc', '-os', 'cross']
}

fn cleanc_autofree_disabled_args() []string {
	return ['-backend', 'cleanc']
}

fn cleanc_autofree_freestanding_linux_args() []string {
	return ['-autofree', '-backend', 'cleanc', '-freestanding', '-os', 'linux']
}

fn cleanc_autofree_none_args() []string {
	return ['-autofree', '-backend', 'cleanc', '-freestanding', '-os', 'none']
}

fn cleanc_autofree_freestanding_linux_output_hook_args() []string {
	return [
		'-autofree',
		'-backend',
		'cleanc',
		'-freestanding',
		'-fhooks',
		'output',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	]
}

fn cleanc_autofree_none_output_hook_args() []string {
	return [
		'-autofree',
		'-backend',
		'cleanc',
		'-freestanding',
		'-fhooks',
		'output',
		'-os',
		'none',
		'--skip-builtin',
		'--skip-type-check',
	]
}

fn run_cleanc_autofree_cleanup_case(v2_binary string, tmp_dir string, cleanup_case CleancAutofreeCleanupCase) {
	assert cleanup_case.name.len > 0
	assert cleanup_case.fn_names.len > 0
	res := run_v2_to_output(v2_binary, tmp_dir, cleanup_case.name, cleanup_case.args,
		cleanup_case.source, os.join_path(tmp_dir, '${cleanup_case.name}.c'))
	for fn_name in cleanup_case.fn_names {
		if cleanup_case.transfer_prefix {
			if cleanup_case.expect_cleanup {
				assert_autofree_transfer_prefix_cleanup_present_in_fn(res, fn_name)
			} else {
				assert_autofree_transfer_prefix_cleanup_absent_in_fn(res, fn_name)
			}
		} else if cleanup_case.expect_cleanup {
			assert_autofree_array_cleanup_present_in_fn(res, fn_name)
		} else {
			assert_autofree_array_cleanup_absent_in_fn(res, fn_name)
		}
	}
}

fn run_cleanc_autofree_cleanup_cases(v2_binary string, tmp_dir string, cleanup_cases []CleancAutofreeCleanupCase) {
	for cleanup_case in cleanup_cases {
		run_cleanc_autofree_cleanup_case(v2_binary, tmp_dir, cleanup_case)
	}
}

fn run_cleanc_autofree_absent_target_results(v2_binary string, tmp_dir string, name string, source string) []CleancCliResult {
	return [
		run_v2_to_output(v2_binary, tmp_dir, '${name}_disabled', cleanc_autofree_disabled_args(),
			source, os.join_path(tmp_dir, '${name}_disabled.c')),
		run_v2_to_output(v2_binary, tmp_dir, '${name}_freestanding_linux',
			cleanc_autofree_freestanding_linux_args(), source, os.join_path(tmp_dir,
			'${name}_freestanding_linux.c')),
		run_v2_to_output(v2_binary, tmp_dir, '${name}_none', cleanc_autofree_none_args(), source, os.join_path(tmp_dir,
			'${name}_none.c')),
	]
}

fn run_cleanc_autofree_eprintln_absent_target_results(v2_binary string, tmp_dir string, name string, source string) []CleancCliResult {
	return [
		run_v2_to_output(v2_binary, tmp_dir, '${name}_disabled', cleanc_autofree_disabled_args(),
			source, os.join_path(tmp_dir, '${name}_disabled.c')),
		run_v2_to_output(v2_binary, tmp_dir, '${name}_freestanding_linux',
			cleanc_autofree_freestanding_linux_output_hook_args(), source, os.join_path(tmp_dir,
			'${name}_freestanding_linux.c')),
		run_v2_to_output(v2_binary, tmp_dir, '${name}_none',
			cleanc_autofree_none_output_hook_args(), source,
			os.join_path(tmp_dir, '${name}_none.c')),
	]
}

fn test_generated_c_function_body_skips_prototype() {
	c_source := 'void build_empty_array();
void unrelated_block() {
	ignored();
}
void build_empty_array() {
	Array_int items = __new_array(0, 0, sizeof(int));
	array__free(&items);
}
'
	body := generated_c_function_body(c_source, 'build_empty_array') or {
		assert false, c_source
		return
	}
	assert body.contains('array__free(&items);'), body
	assert !body.contains('ignored();'), body
}

fn host_cc_available() bool {
	$if windows {
		return false
	}
	return os.execute('cc --version').exit_code == 0
}

fn host_c_e2e_flags() string {
	return '-D_GNU_SOURCE -Wno-error=incompatible-pointer-types -Wno-error=implicit-function-declaration'
}

fn concrete_non_host_e2e_os() string {
	host_os := normalize_e2e_os_name(os.user_os())
	return match host_os {
		'windows' { 'linux' }
		else { 'windows' }
	}
}

fn target_fixture_source(name string) string {
	path := os.join_path(e2e_repo_root(), 'vlib', 'v2', 'tests', 'target_codegen_example', name)
	return os.read_file(path) or { panic('cannot read ${path}: ${err}') }
}

fn target_directive_source() string {
	return target_fixture_source('target_directives.vv2')
}

fn cross_directive_source() string {
	return target_fixture_source('cross_directives.vv2')
}

fn freestanding_directive_source() string {
	return target_fixture_source('freestanding_directives.vv2')
}

fn freestanding_none_source() string {
	return target_fixture_source('freestanding_none.vv2')
}

fn assert_concrete_target_markers(c_source string, target string) {
	assert c_source.contains(match target {
		'linux' { target_linux_marker }
		'macos' { target_macos_marker }
		'windows' { target_windows_marker }
		else { '' }
	})
	if target != 'linux' {
		assert !c_source.contains(target_linux_marker)
	}
	if target != 'macos' {
		assert !c_source.contains(target_macos_marker)
	}
	if target != 'windows' {
		assert !c_source.contains(target_windows_marker)
	}
	assert !c_source.contains(target_cross_marker)
	assert !c_source.contains(target_freestanding_marker)
}

fn assert_no_os_runtime_headers(c_source string) {
	for header in ['#include <unistd.h>', '#include <pthread.h>', '#include <dirent.h>',
		'#include <windows.h>', '#include <mach/mach.h>', '#include <termios.h>',
		'#include <sys/wait.h>'] {
		assert !c_source.contains(header)
	}
}

fn assert_no_obvious_hosted_headers(c_source string) {
	for header in ['#include <stdio.h>', '#include <stdlib.h>', '#include <unistd.h>'] {
		assert !c_source.contains(header)
	}
}

fn c_source_line_matches(c_source string, idx int, line string) bool {
	end_idx := idx + line.len
	return (idx == 0 || c_source[idx - 1] == `\n`)
		&& (end_idx == c_source.len || c_source[end_idx] == `\n`)
}

fn c_source_find_complete_line(c_source string, line string) ?int {
	mut search_from := 0
	for {
		idx := c_source.index_after(line, search_from) or { return none }
		if c_source_line_matches(c_source, idx, line) {
			return idx
		}
		search_from = idx + 1
	}
	return none
}

fn c_source_count_complete_lines(c_source string, line string) int {
	mut count := 0
	mut search_from := 0
	for {
		idx := c_source.index_after(line, search_from) or { break }
		if c_source_line_matches(c_source, idx, line) {
			count++
		}
		search_from = idx + 1
	}
	return count
}

fn c_source_find_line_prefix(c_source string, prefix string) ?int {
	mut search_from := 0
	for {
		idx := c_source.index_after(prefix, search_from) or { return none }
		if idx == 0 || c_source[idx - 1] == `\n` {
			return idx
		}
		search_from = idx + 1
	}
	return none
}

fn c_source_find_line_prefix_after(c_source string, prefix string, start int) ?int {
	mut search_from := start
	for {
		idx := c_source.index_after(prefix, search_from) or { return none }
		if idx == 0 || c_source[idx - 1] == `\n` {
			return idx
		}
		search_from = idx + 1
	}
	return none
}

fn assert_array_contains_fallback_decl_order(c_source string, fn_name string, prototype string) {
	prototype_count := c_source_count_complete_lines(c_source, prototype)
	assert prototype_count == 1, 'expected exactly one complete-line fallback prototype `${prototype}`, found ${prototype_count}'
	proto_idx := c_source_find_complete_line(c_source, prototype) or {
		assert false, 'missing array contains fallback prototype `${prototype}`'
		return
	}
	symbol := '${fn_name}('
	first_symbol_idx := c_source.index(symbol) or {
		assert false, 'missing array contains fallback symbol `${symbol}`'
		return
	}
	assert first_symbol_idx == proto_idx + 'bool '.len, '`${fn_name}` appears before its fallback prototype'

	first_use_idx := c_source.index_after(symbol, proto_idx + prototype.len) or {
		assert false, 'missing array contains fallback use `${symbol}` after prototype'
		return
	}
	assert proto_idx < first_use_idx, '`${fn_name}` fallback prototype must precede first use'
	body_prefix := 'bool ${fn_name}('
	if body_idx := c_source_find_line_prefix_after(c_source, body_prefix, proto_idx + prototype.len) {
		assert first_use_idx < body_idx, '`${fn_name}` first use should occur before generated body'
	}
	weak_body := '__attribute__((weak)) bool ${fn_name}('
	if weak_idx := c_source_find_line_prefix(c_source, weak_body) {
		assert first_use_idx < weak_idx, '`${fn_name}` first use should occur before fallback weak body'
		assert proto_idx < weak_idx, '`${fn_name}` fallback prototype must precede weak body'
	}
}

fn test_cleanc_cli_array_contains_fallback_decls_precede_pass5_uses() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_array_contains_fallback_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	res := run_v2_to_c_project_files(v2_binary, tmp_dir, 'array_contains_fallback', [], {
		'ssa/ids.v':     'module ssa

pub type ValueID = int
pub type BlockID = int
'
		'types/types.v': 'module types

pub type Type = int
'
		'main.v':        'module main

import ssa
import types

fn main() {
	values := [ssa.ValueID(1)]
	blocks := [ssa.BlockID(2)]
	type_ids := [types.Type(3)]
	assert values.contains(ssa.ValueID(1))
	assert blocks.contains(ssa.BlockID(2))
	assert type_ids.contains(types.Type(3))
}
'
	}, 'main.v')
	assert_cli_success(res)
	assert_array_contains_fallback_decl_order(res.c_source, 'Array_ssa__ValueID_contains',
		'bool Array_ssa__ValueID_contains(Array_ssa__ValueID a, ssa__ValueID v);')
	assert_array_contains_fallback_decl_order(res.c_source, 'Array_ssa__BlockID_contains',
		'bool Array_ssa__BlockID_contains(Array_ssa__BlockID a, ssa__BlockID v);')
	assert_array_contains_fallback_decl_order(res.c_source, 'Array_types__Type_contains',
		'bool Array_types__Type_contains(Array_types__Type a, types__Type v);')
}

fn test_cleanc_cli_generated_c_target_matrix() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_target_e2e_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	source := target_directive_source()

	default_res := run_v2_to_c(v2_binary, tmp_dir, 'default_host', [], source)
	assert_cli_success(default_res)
	assert !default_res.c_source.contains(target_cross_marker)
	assert !default_res.c_source.contains(target_freestanding_marker)
	host_os := normalize_e2e_os_name(os.user_os())
	if host_os in ['linux', 'macos', 'windows'] {
		assert_concrete_target_markers(default_res.c_source, host_os)
	}

	for target in ['linux', 'macos', 'windows'] {
		res := run_v2_to_c(v2_binary, tmp_dir, 'target_${target}', ['-os', target], source)
		assert_cli_success(res)
		assert_concrete_target_markers(res.c_source, target)
	}

	cross_res := run_v2_to_c(v2_binary, tmp_dir, 'target_cross', ['-os', 'cross'],
		cross_directive_source())
	assert_cli_success(cross_res)
	assert cross_res.c_source.contains(target_linux_marker)
	assert cross_res.c_source.contains(target_macos_marker)
	assert cross_res.c_source.contains(target_windows_marker)
	assert cross_res.c_source.contains(target_cross_marker)
	assert cross_res.c_source.contains('defined(__linux__)')
	assert cross_res.c_source.contains('defined(_WIN32)')
	assert cross_res.c_source.contains('defined(__APPLE__)')

	free_res := run_v2_to_c(v2_binary, tmp_dir, 'target_freestanding', [
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
	], freestanding_directive_source())
	assert_cli_success(free_res)
	assert free_res.c_source.contains(target_linux_marker)
	assert free_res.c_source.contains(target_freestanding_marker)
	assert !free_res.c_source.contains(target_windows_marker)
	assert_no_os_runtime_headers(free_res.c_source)
}

fn test_cleanc_cli_comptime_if_directives_follow_active_branch() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_comptime_directives_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)

	linux_res := run_v2_to_c(v2_binary, tmp_dir, 'linux_inactive_windows_directive', [
		'-os',
		'linux',
	], 'module main

\$if windows {
	#include <inactive_windows_marker.h>
}

#include <active_comptime_marker.h>

fn main() {}
')
	assert_cli_success(linux_res)
	assert !linux_res.c_source.contains(inactive_windows_marker)
	assert linux_res.c_source.contains(active_comptime_marker)

	freestanding_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_inactive_directive', [
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
	], 'module main

\$if !freestanding {
	#include <inactive_freestanding_marker.h>
}

#include freestanding <active_comptime_marker.h>

fn main() {}
')
	assert_cli_success(freestanding_res)
	assert !freestanding_res.c_source.contains(inactive_freestanding_marker)
	assert freestanding_res.c_source.contains(active_comptime_marker)
}

fn test_cleanc_cli_freestanding_diagnostics_and_user_directives() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_target_diag_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)

	help_res := os.execute('"${v2_binary}" --definitely-unknown-freestanding-flag')
	assert help_res.exit_code != 0, help_res.output
	assert help_res.output.contains('-fhooks <values>'), help_res.output
	assert help_res.output.contains('Advanced freestanding hooks for --skip-builtin --skip-type-check stubs'), help_res.output
	assert help_res.output.contains('-b <name>'), help_res.output
	assert help_res.output.contains('omit for cleanc'), help_res.output

	assert help_res.output.contains('Override target OS (default: host OS)'), help_res.output

	fixture_empty := target_fixture_source('freestanding_empty.vv2')
	fixture_output := target_fixture_source('freestanding_output.vv2')
	fixture_panic := target_fixture_source('freestanding_panic.vv2')
	fixture_alloc := target_fixture_source('freestanding_alloc.vv2')
	none_without_freestanding_res := run_v2_to_c(v2_binary, tmp_dir, 'none_without_freestanding', [
		'-os',
		'none',
	], fixture_empty)
	assert_cli_failure_contains(none_without_freestanding_res, '-os none requires -freestanding')

	freestanding_cross_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_cross', [
		'-freestanding',
		'-os',
		'cross',
		'--skip-builtin',
	], fixture_empty)
	assert_cli_failure_contains(freestanding_cross_res, '-freestanding -os cross is not supported')

	os_import_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_os_import', [
		'-freestanding',
		'-os',
		'linux',
	], 'module main

import os

fn main() {
	_ := os.args.len
}
	')
	assert_cli_failure_contains(os_import_res, 'freestanding target cannot use module os')

	flat_os_import_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_flat_os_import', [
		'-freestanding',
		'-os',
		'none',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

import os

fn main() {}
	')
	assert_cli_failure_contains(flat_os_import_res, 'freestanding target cannot use module os')

	for import_name in ['time', 'term', 'net', 'net.http', 'sync'] {
		import_res := run_v2_to_c(v2_binary, tmp_dir,
			'freestanding_${import_name.replace('.', '_')}_import', [
			'-freestanding',
			'-os',
			'linux',
			'--skip-builtin',
		], 'module main

import ${import_name}

fn main() {}
')
		assert_cli_failure_contains(import_res,
			'freestanding target cannot use module ${import_name.all_before('.')}')
	}

	print_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_print', [
		'-freestanding',
		'-os',
		'linux',
	], fixture_output)
	assert_cli_failure_contains(print_res, 'freestanding target cannot use builtin println')

	minimal_runtime_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_minimal_runtime', [
		'-freestanding',
		'-os',
		'linux',
	], fixture_empty)
	assert_cli_success(minimal_runtime_res)
	assert_no_os_runtime_headers(minimal_runtime_res.c_source)

	output_hook_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_output_hook', [
		'-freestanding',
		'-fhooks',
		'output',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], fixture_output)
	assert_cli_success(output_hook_res)
	assert output_hook_res.c_source.contains('isize v_platform_write(int stream, const u8* buf, isize len);')
	assert output_hook_res.c_source.contains('v_platform_write(fd, ptr, remaining_bytes)')
	assert !output_hook_res.c_source.contains('v_platform_panic'), output_hook_res.c_source
	assert !output_hook_res.c_source.contains('v_platform_malloc'), output_hook_res.c_source
	assert !output_hook_res.c_source.contains('v_platform_realloc'), output_hook_res.c_source
	assert !output_hook_res.c_source.contains('v_platform_free'), output_hook_res.c_source

	define_prealloc_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_define_prealloc', [
		'-freestanding',
		'-d',
		'prealloc',
		'-fhooks',
		'output',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], fixture_output)
	assert_cli_success(define_prealloc_res)
	assert !define_prealloc_res.output.contains('freestanding target cannot use -prealloc')

	output_hook_builtin_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_output_hook_builtin_runtime', [
		'-freestanding',
		'-fhooks',
		'output',
		'-os',
		'linux',
	], fixture_output)
	assert_cli_failure_contains(output_hook_builtin_res,
		'freestanding target platform hooks currently require --skip-builtin and --skip-type-check')
	assert !output_hook_builtin_res.output.contains('__malloc'), output_hook_builtin_res.output

	output_hook_skip_builtin_typecheck_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_output_hook_skip_builtin_typecheck_gate', [
		'-freestanding',
		'-fhooks',
		'output',
		'-os',
		'linux',
		'--skip-builtin',
	], fixture_output)
	assert_cli_failure_contains(output_hook_skip_builtin_typecheck_res,
		'freestanding target platform hooks currently require --skip-builtin and --skip-type-check')
	assert !output_hook_skip_builtin_typecheck_res.output.contains('unknown ident'), output_hook_skip_builtin_typecheck_res.output

	for hook_name in ['output', 'panic', 'alloc', 'minimal'] {
		hook_runtime_res := run_v2_to_c(v2_binary, tmp_dir,
			'freestanding_${hook_name}_builtin_runtime_gate', [
			'-freestanding',
			'-fhooks',
			hook_name,
			'-os',
			'linux',
		], fixture_empty)
		assert_cli_failure_contains(hook_runtime_res,
			'freestanding target platform hooks currently require --skip-builtin and --skip-type-check')
		assert !hook_runtime_res.output.contains('__malloc'), hook_runtime_res.output
	}

	output_missing_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_output_missing', [
		'-freestanding',
		'-fhooks',
		'panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], fixture_output)
	assert_cli_failure_contains(output_missing_res,
		'freestanding target cannot use builtin println without output platform hook')

	spoofed_output_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_spoofed_output_define', [
		'-freestanding',
		'-d',
		'freestanding_output',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], fixture_output)
	assert_cli_failure_contains(spoofed_output_res,
		'freestanding target cannot use builtin println without output platform hook')

	for helper_call in ['_write_buf_to_fd(1, 0, 0)', "_writeln_to_fd(1, '')", 'flush_stdout()',
		'flush_stderr()'] {
		helper_res := run_v2_to_c(v2_binary, tmp_dir,
			'freestanding_output_helper_${helper_call.all_before('(')}', [
			'-freestanding',
			'-os',
			'linux',
			'--skip-builtin',
			'--skip-type-check',
		], 'module main

fn main() {
	${helper_call}
}
')
		assert_generated_c_static_assert_contains(helper_res,
			e2e_freestanding_missing_output_hook_message)
	}

	for print_call in ['println(123)', 'print(true)'] {
		print_conversion_res := run_v2_to_c(v2_binary, tmp_dir,
			'freestanding_output_only_${print_call.all_before('(')}_conversion', [
			'-freestanding',
			'-fhooks',
			'output',
			'-os',
			'linux',
			'--skip-builtin',
			'--skip-type-check',
		], 'module main

fn main() {
	${print_call}
}
')
		assert_generated_c_static_assert_contains(print_conversion_res,
			e2e_freestanding_missing_format_hook_message)
	}

	output_hook_string_literal_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_output_hook_string_literal', [
		'-freestanding',
		'-fhooks',
		'output',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], "module main

fn main() {
	println('ok')
}
	")
	assert_cli_success(output_hook_string_literal_res)
	assert output_hook_string_literal_res.c_source.contains('v_platform_write')
	assert !output_hook_string_literal_res.c_source.contains(e2e_freestanding_missing_format_hook_message), output_hook_string_literal_res.c_source

	output_hook_unknown_print_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_output_hook_unknown_print_arg', [
		'-freestanding',
		'-fhooks',
		'output',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn C.platform_value() int

fn main() {
	x := C.platform_value()
	println(x)
}
	')
	assert_generated_c_static_assert_contains(output_hook_unknown_print_res,
		e2e_freestanding_missing_format_hook_message)

	panic_hook_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_panic_hook', [
		'-freestanding',
		'-fhooks',
		'panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], fixture_panic)
	assert_cli_success(panic_hook_res)
	assert panic_hook_res.c_source.contains('void v_platform_panic(const u8* msg, isize len);')
	assert !panic_hook_res.c_source.contains('v_platform_write'), panic_hook_res.c_source
	assert !panic_hook_res.c_source.contains('v_platform_malloc'), panic_hook_res.c_source

	panic_missing_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_panic_missing', [
		'-freestanding',
		'-fhooks',
		'output',
		'-os',
		'linux',
	], fixture_panic)
	assert_cli_failure_contains(panic_missing_res,
		'freestanding target cannot use builtin panic without panic platform hook')

	bang_missing_panic_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_bang_missing_panic', [
		'-freestanding',
		'-fhooks',
		'output,alloc',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], "module main

fn fallible() !int {
	return error('x')
}

fn main() {
	_ := fallible()!
}
	")
	assert_generated_c_static_assert_contains(bang_missing_panic_res,
		e2e_freestanding_missing_panic_hook_message)

	bang_panic_hook_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_bang_panic_hook', [
		'-freestanding',
		'-fhooks',
		'panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], "module main

fn fallible() !int {
	return error('x')
}

fn main() {
	_ := fallible()!
}
	")
	assert_generated_c_heap_runtime_static_assert_contains(bang_panic_hook_res, 'IError__str')

	panic_ierror_hook_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_panic_ierror_hook', [
		'-freestanding',
		'-fhooks',
		'output,panic,alloc',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], "module main

fn main() {
	err := error('x')
	panic(err)
}
	")
	assert_generated_c_heap_runtime_static_assert_contains(panic_ierror_hook_res, 'IError__str')

	bang_result_propagation_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_bang_result_propagation', [
		'-freestanding',
		'-fhooks',
		'output,alloc',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], "module main

fn fallible() !int {
	return error('x')
}

fn wrapper() !int {
	return fallible()!
}

fn main() {}
	")
	assert_cli_success(bang_result_propagation_res)

	assert_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_assert', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	assert true
}
	')
	assert_cli_failure_contains(assert_res,
		'freestanding target cannot use assert because failed assertions need hosted output/exit support')

	spoofed_panic_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_spoofed_panic_define', [
		'-freestanding',
		'-d',
		'freestanding_panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], fixture_panic)
	assert_cli_failure_contains(spoofed_panic_res,
		'freestanding target cannot use builtin panic without panic platform hook')

	alloc_missing_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_alloc_missing', [
		'-freestanding',
		'-fhooks',
		'output',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], fixture_alloc)
	assert_generated_c_static_assert_contains(alloc_missing_res,
		e2e_freestanding_missing_alloc_hook_message)

	spoofed_alloc_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_spoofed_alloc_define', [
		'-freestanding',
		'-d',
		'freestanding_alloc',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], fixture_alloc)
	assert_generated_c_static_assert_contains(spoofed_alloc_res,
		e2e_freestanding_missing_alloc_hook_message)

	arguments_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_arguments', [
		'-freestanding',
		'-fhooks',
		'alloc',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	_ := arguments()
}
')
	assert_generated_c_static_assert_contains(arguments_res,
		e2e_freestanding_missing_alloc_hook_message)

	alloc_hook_string_interpolation_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_alloc_string_interpolation', [
		'-freestanding',
		'-fhooks',
		'alloc',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], "module main

fn main() {
	_ := '\${1}'
}
	")
	assert_generated_c_static_assert_contains(alloc_hook_string_interpolation_res,
		e2e_freestanding_missing_format_hook_message)

	string_concat_missing_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_string_concat_missing_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], "module main

fn main() {
	s := 'left'
	_ := s + 'right'
}
	")
	assert_generated_c_heap_runtime_static_assert_contains(string_concat_missing_alloc_res,
		'string__plus')

	ambiguous_string_concat_missing_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_ambiguous_string_concat_missing_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn C.platform_string() string

fn main() {
	a := C.platform_string()
	b := C.platform_string()
	_ := a + b
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(ambiguous_string_concat_missing_alloc_res,
		'string__plus')

	string_plus_assign_missing_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_string_plus_assign_missing_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], "module main

fn main() {
	mut s := 'left'
	s += 'right'
}
	")
	assert_generated_c_heap_runtime_static_assert_contains(string_plus_assign_missing_alloc_res,
		'string__plus')

	ambiguous_string_plus_assign_missing_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_ambiguous_string_plus_assign_missing_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn C.platform_string() string

fn main() {
	mut s := C.platform_string()
	s += C.platform_string()
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(ambiguous_string_plus_assign_missing_alloc_res,
		'string__plus')

	numeric_plus_without_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_numeric_plus_without_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	_ := 1 + 2
	mut n := 1
	n += 2
}
	')
	assert_cli_success(numeric_plus_without_alloc_res)

	fixed_array_index_without_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_fixed_array_index_without_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	mut xs := [3]int{init: 0}
	xs[0] = 7
}
	')
	assert_cli_success(fixed_array_index_without_alloc_res)

	dynamic_array_literal_alloc_hook_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_dynamic_array_literal_alloc_hook', [
		'-freestanding',
		'-fhooks',
		'output,panic,alloc',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	_ := [1, 2, 3]
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(dynamic_array_literal_alloc_hook_res,
		'new_array_from_c_array')

	map_literal_alloc_hook_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_map_literal_alloc_hook', [
		'-freestanding',
		'-fhooks',
		'output,panic,alloc',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	_ := {
		1: 2
	}
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(map_literal_alloc_hook_res, 'new_map')

	numeric_shift_without_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_numeric_shift_without_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	mut flags := 1
	_ := flags << 1
	flags <<= 1
}
	')
	assert_cli_success(numeric_shift_without_alloc_res)

	user_map_method_without_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_user_map_method_without_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

struct Device {}

fn (d Device) map() int {
	return 7
}

fn main() {
	d := Device{}
	_ := d.map()
}
	')
	assert_cli_success(user_map_method_without_alloc_res)

	user_clone_substr_methods_without_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_user_clone_substr_methods_without_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

struct Device {}

fn (d Device) clone() Device {
	return d
}

fn (d Device) substr(start int, end int) Device {
	return d
}

fn main() {
	d := Device{}
	_ := d.clone()
	_ := d.substr(0, 1)
}
	')
	assert_cli_success(user_clone_substr_methods_without_alloc_res)

	array_append_missing_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_array_append_missing_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn C.platform_array() []int

fn main() {
	mut nums := C.platform_array()
	nums << 2
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(array_append_missing_alloc_res,
		'array__push')

	map_assign_missing_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_map_assign_missing_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn C.platform_map() map[int]int

fn main() {
	mut m := C.platform_map()
	m[1] = 1
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(map_assign_missing_alloc_res, 'map__set')

	nested_map_assign_missing_runtime_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_nested_map_assign_missing_runtime', [
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
	], "module main

fn main() {
	mut res := map[string]map[string]string{}
	lang := 'en'
	key := 'msg'
	res[lang][key] = 'Hello'
}
	")
	assert_generated_c_heap_runtime_static_assert_contains(nested_map_assign_missing_runtime_res,
		'map__get_and_set')

	map_value_array_append_missing_runtime_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_map_value_array_append_missing_runtime', [
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
	], 'module main

fn C.platform_map() map[int][]int

fn main() {
	mut m := C.platform_map()
	m[1] << 2
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(map_value_array_append_missing_runtime_res,
		'map__get_and_set')
	assert map_value_array_append_missing_runtime_res.c_source.contains('__new_array_with_default_noscan(0, 0, sizeof(int), NULL)'), map_value_array_append_missing_runtime_res.c_source
	assert !map_value_array_append_missing_runtime_res.c_source.contains('map__get(&m'), map_value_array_append_missing_runtime_res.c_source
	assert !map_value_array_append_missing_runtime_res.c_source.contains('map__get(&(m)'), map_value_array_append_missing_runtime_res.c_source

	array_clone_missing_runtime_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_array_clone_missing_runtime', [
		'-freestanding',
		'-fhooks',
		'output,panic,alloc',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn C.platform_array() []int

fn main() {
	nums := C.platform_array()
	_ := nums.clone()
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(array_clone_missing_runtime_res,
		'array__clone_to_depth')

	string_clone_missing_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_string_clone_missing_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn C.platform_string() string

fn main() {
	s := C.platform_string()
	_ := s.clone()
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(string_clone_missing_alloc_res,
		'string__clone')

	map_clone_missing_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_map_clone_missing_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn C.platform_map() map[int]int

fn main() {
	m := C.platform_map()
	_ := m.clone()
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(map_clone_missing_alloc_res,
		'map__clone')

	range_slice_missing_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_range_slice_missing_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn C.platform_string() string

fn main() {
	s := C.platform_string()
	_ := s[0..1]
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(range_slice_missing_alloc_res,
		'string__substr')

	string_substr_missing_alloc_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_string_substr_missing_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn C.platform_string() string

fn main() {
	s := C.platform_string()
	_ := s.substr(0, 1)
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(string_substr_missing_alloc_res,
		'string__substr')

	split_map_assign_missing_alloc_res := run_v2_to_c_files(v2_binary, tmp_dir,
		'freestanding_split_map_assign_missing_alloc', [
		'-freestanding',
		'-fhooks',
		'output,panic',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], {
		'main.v':     'module main

fn main() {
	mut m := C.platform_map()
	m[1] = 1
}
'
		'platform.v': 'module main

fn C.platform_map() map[int]int
'
	})
	assert_generated_c_heap_runtime_static_assert_contains(split_map_assign_missing_alloc_res,
		'map__set')

	alloc_hook_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_alloc_hook', [
		'-freestanding',
		'-fhooks',
		'alloc',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], fixture_alloc)
	assert_cli_success(alloc_hook_res)
	assert alloc_hook_res.c_source.contains('void* v_platform_malloc(isize n);')
	assert alloc_hook_res.c_source.contains('void* v_platform_realloc(void* ptr, isize n);')
	assert alloc_hook_res.c_source.contains('void v_platform_free(void* ptr);')
	assert !alloc_hook_res.c_source.contains('v_platform_write'), alloc_hook_res.c_source
	assert !alloc_hook_res.c_source.contains('v_platform_panic'), alloc_hook_res.c_source

	explicit_array_runtime_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_explicit_array_runtime_helper', [
		'-freestanding',
		'-fhooks',
		'alloc',
		'-os',
		'none',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	_ := new_array_from_c_array(0, 0, 0, 0)
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(explicit_array_runtime_res,
		'new_array_from_c_array')

	explicit_array_noscan_runtime_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_explicit_array_noscan_runtime_helper', [
		'-freestanding',
		'-fhooks',
		'alloc',
		'-os',
		'none',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	_ := new_array_from_c_array_noscan(0, 0, 0, 0)
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(explicit_array_noscan_runtime_res,
		'new_array_from_c_array_noscan')

	explicit_array_no_alloc_runtime_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_explicit_array_no_alloc_runtime_helper', [
		'-freestanding',
		'-fhooks',
		'output,panic,alloc',
		'-os',
		'none',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	_ := new_array_from_c_array_no_alloc(0, 0, 0, 0)
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(explicit_array_no_alloc_runtime_res,
		'new_array_from_c_array_no_alloc')

	explicit_array_default_runtime_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_explicit_array_default_runtime_helper', [
		'-freestanding',
		'-fhooks',
		'alloc',
		'-os',
		'none',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	_ := __new_array_with_default_noscan(0, 0, 0, 0)
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(explicit_array_default_runtime_res,
		'__new_array_with_default_noscan')

	explicit_array_repeat_runtime_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_explicit_array_repeat_runtime_helper', [
		'-freestanding',
		'-fhooks',
		'alloc',
		'-os',
		'none',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	_ := array__repeat()
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(explicit_array_repeat_runtime_res,
		'array__repeat')

	explicit_map_runtime_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_explicit_map_runtime_helper', [
		'-freestanding',
		'-fhooks',
		'alloc',
		'-os',
		'none',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	_ := new_map()
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(explicit_map_runtime_res, 'new_map')

	explicit_array_spread_runtime_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_explicit_array_spread_runtime_helper', [
		'-freestanding',
		'-fhooks',
		'alloc',
		'-os',
		'none',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	_ := new_array_from_array_and_c_array()
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(explicit_array_spread_runtime_res,
		'new_array_from_array_and_c_array')

	explicit_builtin_array_spread_runtime_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_explicit_builtin_array_spread_runtime_helper', [
		'-freestanding',
		'-fhooks',
		'alloc',
		'-os',
		'none',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn main() {
	_ := builtin__new_array_from_array_and_c_array()
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(explicit_builtin_array_spread_runtime_res,
		'builtin__new_array_from_array_and_c_array')

	tracked_heap_ops_alloc_hook_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_tracked_heap_ops_alloc_hook', [
		'-freestanding',
		'-fhooks',
		'output,panic,alloc',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn C.platform_array() []int
fn C.platform_map() map[int]int
fn C.platform_string() string

fn main() {
	mut nums := C.platform_array()
	nums << 2
	mut m := C.platform_map()
	m[1] = 1
	_ := m.clone()
	s := C.platform_string()
	_ := s[0..1]
	_ := s.clone()
	_ := s.substr(0, 1)
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(tracked_heap_ops_alloc_hook_res,
		'array__push')
	assert_generated_c_heap_runtime_static_assert_contains(tracked_heap_ops_alloc_hook_res,
		'map__set')
	assert_generated_c_heap_runtime_static_assert_contains(tracked_heap_ops_alloc_hook_res,
		'map__clone')
	assert_generated_c_heap_runtime_static_assert_contains(tracked_heap_ops_alloc_hook_res,
		'string__clone')
	assert_generated_c_heap_runtime_static_assert_contains(tracked_heap_ops_alloc_hook_res,
		'string__substr')

	string_concat_alloc_hook_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_string_concat_alloc_hook', [
		'-freestanding',
		'-fhooks',
		'alloc',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], "module main

fn main() {
	s := 'left'
	_ := s + 'right'
}
	")
	assert_generated_c_heap_runtime_static_assert_contains(string_concat_alloc_hook_res,
		'string__plus')

	ambiguous_string_concat_alloc_hook_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_ambiguous_string_concat_alloc_hook', [
		'-freestanding',
		'-fhooks',
		'alloc',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

fn C.platform_string() string

fn main() {
	a := C.platform_string()
	b := C.platform_string()
	_ := a + b
}
	')
	assert_generated_c_heap_runtime_static_assert_contains(ambiguous_string_concat_alloc_hook_res,
		'string__plus')

	prealloc_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_prealloc', [
		'-freestanding',
		'-prealloc',
		'-os',
		'linux',
		'--skip-builtin',
	], fixture_empty)
	assert_cli_failure_contains(prealloc_res, 'freestanding target cannot use -prealloc')

	shared_lib_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_shared_lib', [
		'-freestanding',
		'-shared',
		'-os',
		'linux',
		'--skip-builtin',
	], 'module main

fn main() {}
')
	assert_cli_failure_contains(shared_lib_res, 'freestanding target cannot use -shared')

	hot_fn_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_hot_fn', [
		'-freestanding',
		'-hot-fn',
		'main',
		'-os',
		'linux',
		'--skip-builtin',
	], 'module main

fn main() {}
')
	assert_cli_failure_contains(hot_fn_res, 'freestanding target cannot use -hot-fn')

	for call_name in ['eprint', 'eprintln', 'panic'] {
		call_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_${call_name}', [
			'-freestanding',
			'-os',
			'linux',
			'--skip-builtin',
		], "module main

fn main() {
	${call_name}('x')
}
")
		assert_cli_failure_contains(call_res, 'freestanding target cannot use builtin ${call_name}')
	}

	spawn_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_spawn', [
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
	], 'module main

fn work() {}

fn main() {
	spawn work()
}
')
	assert_cli_failure_contains(spawn_res, 'freestanding target cannot use spawn')

	lock_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_lock', [
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
	], 'module main

fn main() {
	lock {}
}
')
	assert_cli_failure_contains(lock_res, 'freestanding target cannot use lock/rlock')

	shared_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_shared', [
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
	], 'module main

struct State {
	value shared int
}

fn main() {}
')
	assert_cli_failure_contains(shared_res, 'freestanding target cannot use shared data')

	live_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_live', [
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
	], 'module main

@[live]
fn step() {}

fn main() {}
')
	assert_cli_failure_contains(live_res, 'freestanding target cannot use @[live]')

	inactive_branch_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_inactive_branches', [
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], "module main

fn main() {
	\$if !freestanding {
		println('inactive')
	}
	\$if windows {
		eprintln('inactive')
	}
}
	")
	assert_cli_success(inactive_branch_res)

	inactive_fn_attr_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_inactive_fn_attributes', [
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], "module main

	@[if !freestanding]
	fn hosted_only() {
		println('inactive')
	}

	@[if windows]
	fn windows_only() {
		eprintln('inactive')
	}

	fn main() {}
	")
	assert_cli_success(inactive_fn_attr_res)

	fixed_array_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_fixed_array_no_alloc', [
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], 'module main

	fn main() {
		_ := [3]int{init: 0}
		_ := [1, 2, 3]!
	}
	')
	assert_cli_success(fixed_array_res)

	inactive_import_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_inactive_import', [
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
	], 'module main

\$if !freestanding {
	import os
}

fn main() {}
')
	assert_cli_success(inactive_import_res)

	active_branch_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_active_branch', [
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], "module main

fn main() {
	\$if freestanding {
		eprint('active')
	}
}
	")
	assert_cli_failure_contains(active_branch_res, 'freestanding target cannot use builtin eprint')

	hook_inactive_branch_res := run_v2_to_c(v2_binary, tmp_dir,
		'freestanding_hook_inactive_branch', [
		'-freestanding',
		'-fhooks',
		'output',
		'-os',
		'linux',
		'--skip-builtin',
		'--skip-type-check',
	], "module main

fn main() {
	\$if !freestanding_output {
		println('inactive')
	}
}
	")
	assert_cli_success(hook_inactive_branch_res)

	user_directive_res := run_v2_to_c(v2_binary, tmp_dir, 'freestanding_user_directives', [
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
	], 'module main

#include <platform_user_header.h>
#flag -DPLATFORM_USER_FLAG
fn C.platform_external() int

fn main() {
	_ := C.platform_external()
}
	')
	assert_cli_success(user_directive_res)
	assert user_directive_res.c_source.contains('#include <platform_user_header.h>')
	assert user_directive_res.c_source.contains('platform_external'), user_directive_res.c_source
}

fn test_cleanc_cli_compiles_generated_c_on_host_when_cc_available() {
	if !host_cc_available() {
		eprintln('skip: cc is not available for cleanc host compile e2e')
		return
	}
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_host_cc_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	v1_binary := build_v1_for_target_e2e(tmp_dir)
	minimal_source := 'module main

fn main() {}
'

	minimal_res := run_v2_to_binary(v2_binary, tmp_dir, 'host_minimal', [
		'-cc',
		'cc',
	], minimal_source)
	assert_binary_success(minimal_res)
	minimal_run := os.execute('"${minimal_res.out_path}"')
	assert minimal_run.exit_code == 0, minimal_run.output
	assert !os.exists(minimal_res.c_path), minimal_res.output

	default_no_output_res := run_v2_without_output(v2_binary, tmp_dir, 'host_default_no_output', [
		'-cc',
		'cc',
	], minimal_source)
	assert_binary_success(default_no_output_res)
	default_no_output_run := os.execute('"${default_no_output_res.out_path}"')
	assert default_no_output_run.exit_code == 0, default_no_output_run.output
	assert !os.exists(default_no_output_res.c_path), default_no_output_res.output

	public_default_cwd := os.join_path(tmp_dir, 'public_default_cwd')
	public_default_no_output_res := run_v1_v2_without_output_in_dir(v1_binary, v2_binary, tmp_dir,
		'public_host_default_no_output', [
		'-cc',
		'cc',
	], minimal_source, public_default_cwd)
	assert_binary_success(public_default_no_output_res)
	public_default_no_output_run := os.execute('"${public_default_no_output_res.out_path}"')
	assert public_default_no_output_run.exit_code == 0, public_default_no_output_run.output
	assert !os.exists(public_default_no_output_res.c_path), public_default_no_output_res.output

	host_os := normalize_e2e_os_name(os.user_os())
	if host_os in ['linux', 'macos', 'windows'] {
		explicit_host_default_res := run_v2_without_output(v2_binary, tmp_dir,
			'host_explicit_default_no_output', [
			'-cc',
			'cc',
			'-os',
			host_os,
		], minimal_source)
		assert_binary_success(explicit_host_default_res)
		explicit_host_default_run := os.execute('"${explicit_host_default_res.out_path}"')
		assert explicit_host_default_run.exit_code == 0, explicit_host_default_run.output
		assert !os.exists(explicit_host_default_res.c_path), explicit_host_default_res.output

		explicit_host_res := run_v2_to_binary(v2_binary, tmp_dir, 'host_explicit_${host_os}', [
			'-cc',
			'cc',
			'-os',
			host_os,
		], minimal_source)
		assert_binary_success(explicit_host_res)
		explicit_host_run := os.execute('"${explicit_host_res.out_path}"')
		assert explicit_host_run.exit_code == 0, explicit_host_run.output
		assert !os.exists(explicit_host_res.c_path), explicit_host_res.output

		public_explicit_host_res := run_v1_v2_without_output_in_dir(v1_binary, v2_binary, tmp_dir,
			'public_host_explicit_default_no_output', [
			'-cc',
			'cc',
			'-os',
			host_os,
		], minimal_source, public_default_cwd)
		assert_binary_success(public_explicit_host_res)
		public_explicit_host_run := os.execute('"${public_explicit_host_res.out_path}"')
		assert public_explicit_host_run.exit_code == 0, public_explicit_host_run.output
		assert !os.exists(public_explicit_host_res.c_path), public_explicit_host_res.output
	}

	cross_res := run_v2_to_binary(v2_binary, tmp_dir, 'host_cross', [
		'-cc',
		'cc',
		'-os',
		'cross',
	], minimal_source)
	assert_binary_success(cross_res)
	cross_run := os.execute('"${cross_res.out_path}"')
	assert cross_run.exit_code == 0, cross_run.output
	assert !os.exists(cross_res.c_path), cross_res.output

	cross_default_res := run_v2_without_output(v2_binary, tmp_dir, 'host_cross_default_no_output', [
		'-cc',
		'cc',
		'-os',
		'cross',
	], minimal_source)
	assert_binary_success(cross_default_res)
	cross_default_run := os.execute('"${cross_default_res.out_path}"')
	assert cross_default_run.exit_code == 0, cross_default_run.output
	assert !os.exists(cross_default_res.c_path), cross_default_res.output

	public_cross_default_res := run_v1_v2_without_output_in_dir(v1_binary, v2_binary, tmp_dir,
		'public_host_cross_default_no_output', [
		'-cc',
		'cc',
		'-os',
		'cross',
	], minimal_source, public_default_cwd)
	assert_binary_success(public_cross_default_res)
	public_cross_default_run := os.execute('"${public_cross_default_res.out_path}"')
	assert public_cross_default_run.exit_code == 0, public_cross_default_run.output
	assert !os.exists(public_cross_default_res.c_path), public_cross_default_res.output

	cross_impl_path := os.join_path(tmp_dir, 'cross_flag_impl.c')
	os.write_file(cross_impl_path, '#ifndef CROSS_FLAG_FROM_V2
#error CROSS_FLAG_FROM_V2 missing
#endif

int cross_platform_external(void) {
	return 9;
}
') or {
		panic(err)
	}
	cross_flag_res := run_v2_to_binary(v2_binary, tmp_dir, 'host_cross_flag_observable', [
		'-cc',
		'cc',
		'-os',
		'cross',
	], 'module main

#flag cross -DCROSS_FLAG_FROM_V2
#flag ${cross_impl_path}

fn C.exit(code int)
fn C.cross_platform_external() int

fn main() {
	if C.cross_platform_external() != 9 {
		C.exit(18)
	}
}
')
	assert_binary_success(cross_flag_res)
	cross_flag_run := os.execute('"${cross_flag_res.out_path}"')
	assert cross_flag_run.exit_code == 0, cross_flag_run.output
	assert !os.exists(cross_flag_res.c_path), cross_flag_res.output

	c_impl_path := os.join_path(tmp_dir, 'platform_flag_impl.c')
	os.write_file(c_impl_path, '#ifndef PLATFORM_FLAG_FROM_V2
#error PLATFORM_FLAG_FROM_V2 missing
#endif

int platform_external(void) {
	return 7;
}
') or {
		panic(err)
	}
	flag_res := run_v2_to_binary(v2_binary, tmp_dir, 'host_flag_observable', [
		'-cc',
		'cc',
	], 'module main

#flag -DPLATFORM_FLAG_FROM_V2
#flag ${c_impl_path}

fn C.exit(code int)
fn C.platform_external() int

fn main() {
	if C.platform_external() != 7 {
		C.exit(17)
	}
}
')
	assert_binary_success(flag_res)
	flag_run := os.execute('"${flag_res.out_path}"')
	assert flag_run.exit_code == 0, flag_run.output
	assert !os.exists(flag_res.c_path), flag_res.output
}

fn test_cleanc_cli_writes_c_only_for_freestanding_and_concrete_non_host_targets() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_c_only_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	v1_binary := build_v1_for_target_e2e(tmp_dir)
	missing_cc := os.join_path(tmp_dir, 'cc_must_not_run')
	minimal_source := 'module main

fn main() {}
'

	default_cwd := os.join_path(tmp_dir, 'default_output_cwd')
	freestanding_default_res := run_v2_without_output_in_dir(v2_binary, tmp_dir,
		'freestanding_default_generation_only', [
		'-cc',
		missing_cc,
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
	], minimal_source, default_cwd)
	assert_generated_c_only(freestanding_default_res)
	assert freestanding_default_res.c_path == os.join_path(default_cwd,
		'freestanding_default_generation_only.c')
	assert !os.exists(os.join_path(tmp_dir, 'freestanding_default_generation_only.c')), freestanding_default_res.output

	host_target := normalize_e2e_os_name(os.user_os())
	public_freestanding_host_res := run_v1_v2_without_output_in_dir(v1_binary, v2_binary, tmp_dir,
		'public_freestanding_host_default_generation_only', [
		'-cc',
		missing_cc,
		'-freestanding',
		'-os',
		host_target,
	], minimal_source, default_cwd)
	assert_generated_c_only(public_freestanding_host_res)
	assert public_freestanding_host_res.c_path == os.join_path(default_cwd,
		'public_freestanding_host_default_generation_only.c')
	assert !os.exists(os.join_path(tmp_dir, 'public_freestanding_host_default_generation_only.c')), public_freestanding_host_res.output

	freestanding_none_default_res := run_v2_without_output_in_dir(v2_binary, tmp_dir,
		'freestanding_none_default_generation_only', [
		'-cc',
		missing_cc,
		'-freestanding',
		'-os',
		'none',
	], freestanding_none_source(), default_cwd)
	assert_generated_c_only(freestanding_none_default_res)
	assert freestanding_none_default_res.c_path == os.join_path(default_cwd,
		'freestanding_none_default_generation_only.c')
	assert freestanding_none_default_res.c_source.contains('#include <platform_none.h>')
	assert_no_os_runtime_headers(freestanding_none_default_res.c_source)

	public_freestanding_none_minimal_res := run_v1_v2_without_output_in_dir(v1_binary, v2_binary,
		tmp_dir, 'app', [
		'-cc',
		missing_cc,
		'-freestanding',
		'-os',
		'none',
	], minimal_source, default_cwd)
	assert_generated_c_only(public_freestanding_none_minimal_res)
	assert public_freestanding_none_minimal_res.c_path == os.join_path(default_cwd, 'app.c')
	assert_no_os_runtime_headers(public_freestanding_none_minimal_res.c_source)

	public_freestanding_none_default_res := run_v1_v2_without_output_in_dir(v1_binary, v2_binary,
		tmp_dir, 'public_freestanding_none_default_generation_only', [
		'-cc',
		missing_cc,
		'-freestanding',
		'-os',
		'none',
	], freestanding_none_source(), default_cwd)
	assert_generated_c_only(public_freestanding_none_default_res)
	assert public_freestanding_none_default_res.c_path == os.join_path(default_cwd,
		'public_freestanding_none_default_generation_only.c')
	assert public_freestanding_none_default_res.c_source.contains('#include <platform_none.h>')
	assert_no_os_runtime_headers(public_freestanding_none_default_res.c_source)

	freestanding_out := os.join_path(tmp_dir, 'freestanding_app')
	freestanding_res := run_v2_to_output(v2_binary, tmp_dir, 'freestanding_generation_only', [
		'-cc',
		missing_cc,
		'-freestanding',
		'-os',
		'linux',
		'--skip-builtin',
	], minimal_source, freestanding_out)
	assert_generated_c_only(freestanding_res)
	assert freestanding_res.c_path == freestanding_out + '.c'

	freestanding_none_out := os.join_path(tmp_dir, 'freestanding_none_app')
	freestanding_none_res := run_v2_to_output(v2_binary, tmp_dir,
		'freestanding_none_generation_only', [
		'-cc',
		missing_cc,
		'-freestanding',
		'-os',
		'none',
		'--skip-builtin',
	], freestanding_none_source(), freestanding_none_out)
	assert_generated_c_only(freestanding_none_res)
	assert freestanding_none_res.c_path == freestanding_none_out + '.c'
	assert freestanding_none_res.c_source.contains('#include <platform_none.h>')
	assert freestanding_none_res.c_source.contains('platform_none_tick')
	assert_no_os_runtime_headers(freestanding_none_res.c_source)

	public_wrapper_out := os.join_path(tmp_dir, 'public_wrapper_freestanding_none.c')
	public_wrapper_res := run_v1_v2_to_output(v1_binary, v2_binary, tmp_dir,
		'public_wrapper_freestanding_none', [
		'-cc',
		missing_cc,
		'-freestanding',
		'-os',
		'none',
		'--skip-builtin',
	], freestanding_none_source(), public_wrapper_out)
	assert_cli_success(public_wrapper_res)
	assert public_wrapper_res.c_path == public_wrapper_out
	assert public_wrapper_res.c_source.contains('#include <platform_none.h>')
	assert public_wrapper_res.c_source.contains('platform_none_tick')
	assert_no_os_runtime_headers(public_wrapper_res.c_source)

	freestanding_none_hooks_out := os.join_path(tmp_dir, 'freestanding_none_hooks_app')
	freestanding_none_hooks_res := run_v2_to_output(v2_binary, tmp_dir,
		'freestanding_none_hooks_generation_only', [
		'-cc',
		missing_cc,
		'-freestanding',
		'-os',
		'none',
		'-fhooks',
		'output,panic,alloc',
		'--skip-builtin',
		'--skip-type-check',
	], "module main

struct HeapBox {
	value int
}

fn main() {
	println('hooked')
	_ := &HeapBox{
		value: 1
	}
	panic('hooked')
}
	",
		freestanding_none_hooks_out)
	assert_generated_c_only(freestanding_none_hooks_res)
	assert freestanding_none_hooks_res.c_source.contains('isize v_platform_write(int stream, const u8* buf, isize len);')
	assert freestanding_none_hooks_res.c_source.contains('void v_platform_panic(const u8* msg, isize len);')
	assert freestanding_none_hooks_res.c_source.contains('void* v_platform_malloc(isize n);')
	assert freestanding_none_hooks_res.c_source.contains('void* v_platform_realloc(void* ptr, isize n);')
	assert freestanding_none_hooks_res.c_source.contains('void v_platform_free(void* ptr);')
	assert_no_os_runtime_headers(freestanding_none_hooks_res.c_source)
	assert_no_obvious_hosted_headers(freestanding_none_hooks_res.c_source)

	non_host_target := concrete_non_host_e2e_os()
	non_host_default_res := run_v2_without_output_in_dir(v2_binary, tmp_dir,
		'concrete_non_host_default_generation_only', [
		'-cc',
		missing_cc,
		'-os',
		non_host_target,
	], minimal_source, default_cwd)
	assert_generated_c_only(non_host_default_res)
	assert non_host_default_res.c_path == os.join_path(default_cwd,
		'concrete_non_host_default_generation_only.c')
	assert !os.exists(os.join_path(tmp_dir, 'concrete_non_host_default_generation_only.c')), non_host_default_res.output

	public_non_host_default_res := run_v1_v2_without_output_in_dir(v1_binary, v2_binary, tmp_dir,
		'public_concrete_non_host_default_generation_only', [
		'-cc',
		missing_cc,
		'-os',
		non_host_target,
	], minimal_source, default_cwd)
	assert_generated_c_only(public_non_host_default_res)
	assert public_non_host_default_res.c_path == os.join_path(default_cwd,
		'public_concrete_non_host_default_generation_only.c')
	assert !os.exists(os.join_path(tmp_dir, 'public_concrete_non_host_default_generation_only.c')), public_non_host_default_res.output

	non_host_out := os.join_path(tmp_dir, 'target_${non_host_target}_app')
	non_host_res := run_v2_to_output(v2_binary, tmp_dir, 'concrete_non_host_generation_only', [
		'-cc',
		missing_cc,
		'-os',
		non_host_target,
	], minimal_source, non_host_out)
	assert_generated_c_only(non_host_res)
	assert non_host_res.c_path == non_host_out + '.c'

	non_host_cached_out := os.join_path(tmp_dir, 'target_${non_host_target}_cached_app')
	non_host_cached_res := run_v2_to_output_with_cache(v2_binary, tmp_dir,
		'concrete_non_host_generation_only_cached', [
		'-cc',
		missing_cc,
		'-os',
		non_host_target,
	], 'module main

fn main() {
	println(123)
}
', non_host_cached_out)
	assert_generated_c_only(non_host_cached_res)
	assert non_host_cached_res.c_path == non_host_cached_out + '.c'
	assert non_host_cached_res.c_source.contains('void println(string s) {'), non_host_cached_res.c_source

	flag_obj := os.join_path(tmp_dir, 'generation_only_probe.o')
	flag_c := os.join_path(tmp_dir, 'generation_only_probe.c')
	os.write_file(flag_c, 'int generation_only_probe(void) { return 0; }\n') or { panic(err) }
	explicit_c_out := os.join_path(tmp_dir, 'explicit_generation_only.c')
	explicit_c_res := run_v2_to_output(v2_binary, tmp_dir, 'explicit_c_generation_only', [], 'module main

#flag ${flag_obj}

fn main() {}
',
		explicit_c_out)
	assert_cli_success(explicit_c_res)
	assert !os.exists(flag_obj), 'generation-only .c output compiled unexpected object ${flag_obj}\n${explicit_c_res.output}'

	rejected_none_res := run_v2_without_output_in_dir(v2_binary, tmp_dir,
		'rejected_none_without_freestanding', [
		'-cc',
		missing_cc,
		'-os',
		'none',
	], minimal_source, default_cwd)
	assert_cli_failure_contains(rejected_none_res, '-os none requires -freestanding')
	assert !os.exists(rejected_none_res.c_path), rejected_none_res.output
	assert !os.exists(rejected_none_res.out_path), rejected_none_res.output

	rejected_freestanding_cross_res := run_v2_without_output_in_dir(v2_binary, tmp_dir,
		'rejected_freestanding_cross', [
		'-cc',
		missing_cc,
		'-freestanding',
		'-os',
		'cross',
		'--skip-builtin',
	], minimal_source, default_cwd)
	assert_cli_failure_contains(rejected_freestanding_cross_res,
		'-freestanding -os cross is not supported')
	assert !os.exists(rejected_freestanding_cross_res.c_path), rejected_freestanding_cross_res.output
	assert !os.exists(rejected_freestanding_cross_res.out_path), rejected_freestanding_cross_res.output
}

fn test_cleanc_autofree_array_cleanup_respects_target_runtime_contract() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_autofree_target_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	source := autofree_array_cleanup_source()
	mut_source := autofree_mut_array_cleanup_source()
	string_source := autofree_string_array_cleanup_source()
	mut_string_source := autofree_mut_string_array_cleanup_source()
	prefixed_source := autofree_prefixed_array_cleanup_source()
	transfer_prefixed_source := autofree_transfer_prefixed_array_cleanup_source()
	rule110_style_source := autofree_rule110_style_clone_cleanup_source()
	fresh_local_final_clone_source := autofree_fresh_local_final_clone_cleanup_source()
	prefixed_fresh_local_final_clone_source :=
		autofree_prefixed_fresh_local_final_clone_cleanup_source()
	cap_only_source := autofree_cap_only_array_cleanup_source()
	len_only_source := autofree_len_only_array_cleanup_source()
	single_final_len_source := autofree_single_final_len_array_cleanup_source()
	local_array_push_literal_sink_source := autofree_local_array_push_literal_sink_cleanup_source()
	two_array_source := autofree_two_array_cleanup_source()
	mixed_two_array_source := autofree_mixed_two_array_cleanup_source()
	prefixed_cap_len_source := autofree_prefixed_cap_len_array_cleanup_source()
	len_only_final_clone_source := autofree_len_only_final_clone_cleanup_source()
	cap_only_final_clone_source := autofree_cap_only_final_clone_cleanup_source()
	multi_param_fresh_local_final_clone_source :=
		autofree_multi_param_fresh_local_final_clone_cleanup_source()
	receiver_fresh_local_final_clone_source :=
		autofree_receiver_fresh_local_final_clone_cleanup_source()
	receiver_field_slice_clone_source := autofree_receiver_field_slice_clone_cleanup_source()
	loop_local_clone_push_source := autofree_loop_local_clone_push_cleanup_source()

	run_cleanc_autofree_cleanup_cases(v2_binary, tmp_dir, [
		CleancAutofreeCleanupCase{
			name:           'autofree_cleanup_hosted'
			args:           cleanc_autofree_hosted_args()
			source:         source
			fn_names:       ['build_empty_array']
			expect_cleanup: true
		},
		CleancAutofreeCleanupCase{
			name:           'autofree_cleanup_cross'
			args:           cleanc_autofree_cross_args()
			source:         source
			fn_names:       ['build_empty_array']
			expect_cleanup: true
		},
		CleancAutofreeCleanupCase{
			name:           'autofree_mut_cleanup_hosted'
			args:           cleanc_autofree_hosted_args()
			source:         mut_source
			fn_names:       ['build_mut_empty_array']
			expect_cleanup: true
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_cleanup_disabled'
			args:     cleanc_autofree_disabled_args()
			source:   source
			fn_names: ['build_empty_array']
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_mut_cleanup_disabled'
			args:     cleanc_autofree_disabled_args()
			source:   mut_source
			fn_names: ['build_mut_empty_array']
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_mut_cleanup_freestanding_linux'
			args:     cleanc_autofree_freestanding_linux_args()
			source:   mut_source
			fn_names: ['build_mut_empty_array']
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_mut_cleanup_none'
			args:     cleanc_autofree_none_args()
			source:   mut_source
			fn_names: ['build_mut_empty_array']
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_cleanup_freestanding_linux'
			args:     cleanc_autofree_freestanding_linux_args()
			source:   source
			fn_names: ['build_empty_array']
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_cleanup_none'
			args:     cleanc_autofree_none_args()
			source:   source
			fn_names: ['build_empty_array']
		},
	])

	run_cleanc_autofree_cleanup_cases(v2_binary, tmp_dir, [
		CleancAutofreeCleanupCase{
			name:           'autofree_string_cleanup_hosted'
			args:           cleanc_autofree_hosted_args()
			source:         string_source
			fn_names:       ['build_empty_string_array']
			expect_cleanup: true
		},
		CleancAutofreeCleanupCase{
			name:           'autofree_string_cleanup_cross'
			args:           cleanc_autofree_cross_args()
			source:         string_source
			fn_names:       ['build_empty_string_array']
			expect_cleanup: true
		},
		CleancAutofreeCleanupCase{
			name:           'autofree_mut_string_cleanup_hosted'
			args:           cleanc_autofree_hosted_args()
			source:         mut_string_source
			fn_names:       ['build_mut_empty_string_array']
			expect_cleanup: true
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_mut_string_cleanup_disabled'
			args:     cleanc_autofree_disabled_args()
			source:   mut_string_source
			fn_names: ['build_mut_empty_string_array']
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_mut_string_cleanup_freestanding_linux'
			args:     cleanc_autofree_freestanding_linux_args()
			source:   mut_string_source
			fn_names: ['build_mut_empty_string_array']
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_mut_string_cleanup_none'
			args:     cleanc_autofree_none_args()
			source:   mut_string_source
			fn_names: ['build_mut_empty_string_array']
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_string_cleanup_disabled'
			args:     cleanc_autofree_disabled_args()
			source:   string_source
			fn_names: ['build_empty_string_array']
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_string_cleanup_freestanding_linux'
			args:     cleanc_autofree_freestanding_linux_args()
			source:   string_source
			fn_names: ['build_empty_string_array']
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_string_cleanup_none'
			args:     cleanc_autofree_none_args()
			source:   string_source
			fn_names: ['build_empty_string_array']
		},
	])

	run_cleanc_autofree_cleanup_cases(v2_binary, tmp_dir, [
		CleancAutofreeCleanupCase{
			name:           'autofree_prefixed_cleanup_hosted'
			args:           cleanc_autofree_hosted_args()
			source:         prefixed_source
			fn_names:       ['build_empty_array_after_scalar',
				'build_empty_string_array_after_scalar']
			expect_cleanup: true
		},
		CleancAutofreeCleanupCase{
			name:           'autofree_prefixed_cleanup_cross'
			args:           cleanc_autofree_cross_args()
			source:         prefixed_source
			fn_names:       ['build_empty_array_after_scalar',
				'build_empty_string_array_after_scalar']
			expect_cleanup: true
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_prefixed_cleanup_disabled'
			args:     cleanc_autofree_disabled_args()
			source:   prefixed_source
			fn_names: ['build_empty_array_after_scalar', 'build_empty_string_array_after_scalar']
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_prefixed_cleanup_freestanding_linux'
			args:     cleanc_autofree_freestanding_linux_args()
			source:   prefixed_source
			fn_names: ['build_empty_array_after_scalar', 'build_empty_string_array_after_scalar']
		},
		CleancAutofreeCleanupCase{
			name:     'autofree_prefixed_cleanup_none'
			args:     cleanc_autofree_none_args()
			source:   prefixed_source
			fn_names: ['build_empty_array_after_scalar', 'build_empty_string_array_after_scalar']
		},
	])

	run_cleanc_autofree_cleanup_cases(v2_binary, tmp_dir, [
		CleancAutofreeCleanupCase{
			name:            'autofree_transfer_prefixed_cleanup_hosted'
			args:            cleanc_autofree_hosted_args()
			source:          transfer_prefixed_source
			fn_names:        ['build_empty_array_after_transfer',
				'build_empty_string_array_after_transfer']
			expect_cleanup:  true
			transfer_prefix: true
		},
		CleancAutofreeCleanupCase{
			name:            'autofree_transfer_prefixed_cleanup_cross'
			args:            cleanc_autofree_cross_args()
			source:          transfer_prefixed_source
			fn_names:        ['build_empty_array_after_transfer',
				'build_empty_string_array_after_transfer']
			expect_cleanup:  true
			transfer_prefix: true
		},
		CleancAutofreeCleanupCase{
			name:            'autofree_transfer_prefixed_cleanup_disabled'
			args:            cleanc_autofree_disabled_args()
			source:          transfer_prefixed_source
			fn_names:        ['build_empty_array_after_transfer',
				'build_empty_string_array_after_transfer']
			transfer_prefix: true
		},
		CleancAutofreeCleanupCase{
			name:            'autofree_transfer_prefixed_cleanup_freestanding_linux'
			args:            cleanc_autofree_freestanding_linux_args()
			source:          transfer_prefixed_source
			fn_names:        ['build_empty_array_after_transfer',
				'build_empty_string_array_after_transfer']
			transfer_prefix: true
		},
		CleancAutofreeCleanupCase{
			name:            'autofree_transfer_prefixed_cleanup_none'
			args:            cleanc_autofree_none_args()
			source:          transfer_prefixed_source
			fn_names:        ['build_empty_array_after_transfer',
				'build_empty_string_array_after_transfer']
			transfer_prefix: true
		},
	])

	prefixed_cap_len_hosted_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_prefixed_cap_len_cleanup_hosted', cleanc_autofree_hosted_args(),
		prefixed_cap_len_source,
		os.join_path(tmp_dir, 'autofree_prefixed_cap_len_cleanup_hosted.c'))
	for fn_name in ['build_array_with_cap_after_transfer', 'build_array_with_len_after_transfer'] {
		assert_autofree_prefixed_cap_len_array_cleanup_present_in_fn(prefixed_cap_len_hosted_res,
			fn_name)
	}

	prefixed_cap_len_disabled_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_prefixed_cap_len_cleanup_disabled', cleanc_autofree_disabled_args(),
		prefixed_cap_len_source, os.join_path(tmp_dir,
		'autofree_prefixed_cap_len_cleanup_disabled.c'))
	prefixed_cap_len_freestanding_linux_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_prefixed_cap_len_cleanup_freestanding_linux',
		cleanc_autofree_freestanding_linux_args(), prefixed_cap_len_source, os.join_path(tmp_dir,
		'autofree_prefixed_cap_len_cleanup_freestanding_linux.c'))
	prefixed_cap_len_none_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_prefixed_cap_len_cleanup_none', cleanc_autofree_none_args(),
		prefixed_cap_len_source, os.join_path(tmp_dir, 'autofree_prefixed_cap_len_cleanup_none.c'))
	for fn_name in ['build_array_with_cap_after_transfer', 'build_array_with_len_after_transfer'] {
		assert_autofree_prefixed_cap_len_array_cleanup_absent_in_fn(prefixed_cap_len_disabled_res,
			fn_name)
		assert_autofree_prefixed_cap_len_array_cleanup_absent_in_fn(prefixed_cap_len_freestanding_linux_res,
			fn_name)
		assert_autofree_prefixed_cap_len_array_cleanup_absent_in_fn(prefixed_cap_len_none_res,
			fn_name)
	}

	rule110_style_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_rule110_style_clone_cleanup_hosted', cleanc_autofree_hosted_args(),
		rule110_style_source,
		os.join_path(tmp_dir, 'autofree_rule110_style_clone_cleanup_hosted.c'))
	assert_autofree_rule110_clone_cleanup_present_in_fn(rule110_style_res, 'next_generation')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_rule110_style_clone_cleanup', rule110_style_source) {
		assert_autofree_rule110_clone_cleanup_absent_in_fn(res, 'next_generation')
	}

	cap_only_res := run_v2_to_output(v2_binary, tmp_dir, 'autofree_cap_only_cleanup_hosted',
		cleanc_autofree_hosted_args(), cap_only_source, os.join_path(tmp_dir,
		'autofree_cap_only_cleanup_hosted.c'))
	assert_autofree_cap_only_array_cleanup_present_in_fn(cap_only_res, 'build_array_with_cap')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_cap_only_cleanup', cap_only_source) {
		assert_autofree_array_cleanup_absent_in_fn(res, 'build_array_with_cap')
	}

	len_only_res := run_v2_to_output(v2_binary, tmp_dir, 'autofree_len_only_cleanup_hosted',
		cleanc_autofree_hosted_args(), len_only_source, os.join_path(tmp_dir,
		'autofree_len_only_cleanup_hosted.c'))
	assert_autofree_len_only_array_cleanup_present_in_fn(len_only_res, 'build_array_with_len')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_len_only_cleanup', len_only_source) {
		assert_autofree_array_cleanup_absent_in_fn(res, 'build_array_with_len')
	}

	single_final_len_hosted_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_single_final_len_cleanup_hosted', cleanc_autofree_hosted_args(),
		single_final_len_source,
		os.join_path(tmp_dir, 'autofree_single_final_len_cleanup_hosted.c'))
	for fn_name in ['build_empty_array_final_len', 'build_cap_array_final_len',
		'build_len_array_final_len'] {
		assert_autofree_single_final_len_array_cleanup_present_in_fn(single_final_len_hosted_res,
			fn_name)
	}

	single_final_len_disabled_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_single_final_len_cleanup_disabled', cleanc_autofree_disabled_args(),
		single_final_len_source, os.join_path(tmp_dir,
		'autofree_single_final_len_cleanup_disabled.c'))
	single_final_len_freestanding_linux_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_single_final_len_cleanup_freestanding_linux',
		cleanc_autofree_freestanding_linux_args(), single_final_len_source, os.join_path(tmp_dir,
		'autofree_single_final_len_cleanup_freestanding_linux.c'))
	single_final_len_none_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_single_final_len_cleanup_none', cleanc_autofree_none_args(),
		single_final_len_source, os.join_path(tmp_dir, 'autofree_single_final_len_cleanup_none.c'))
	for fn_name in ['build_empty_array_final_len', 'build_cap_array_final_len',
		'build_len_array_final_len'] {
		assert_autofree_single_final_len_array_cleanup_absent_in_fn(single_final_len_disabled_res,
			fn_name)
		assert_autofree_single_final_len_array_cleanup_absent_in_fn(single_final_len_freestanding_linux_res,
			fn_name)
		assert_autofree_single_final_len_array_cleanup_absent_in_fn(single_final_len_none_res,
			fn_name)
	}

	local_array_push_literal_sink_hosted_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_local_array_push_literal_sink_cleanup_hosted', cleanc_autofree_hosted_args(),
		local_array_push_literal_sink_source, os.join_path(tmp_dir,
		'autofree_local_array_push_literal_sink_cleanup_hosted.c'))
	assert_autofree_local_array_push_literal_sink_cleanup_present_in_fn(local_array_push_literal_sink_hosted_res,
		'build_local_array_push_literal_return')

	local_array_push_literal_sink_disabled_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_local_array_push_literal_sink_cleanup_disabled', cleanc_autofree_disabled_args(),
		local_array_push_literal_sink_source, os.join_path(tmp_dir,
		'autofree_local_array_push_literal_sink_cleanup_disabled.c'))
	local_array_push_literal_sink_freestanding_linux_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_local_array_push_literal_sink_cleanup_freestanding_linux',
		cleanc_autofree_freestanding_linux_args(), local_array_push_literal_sink_source, os.join_path(tmp_dir,
		'autofree_local_array_push_literal_sink_cleanup_freestanding_linux.c'))
	local_array_push_literal_sink_none_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_local_array_push_literal_sink_cleanup_none', cleanc_autofree_none_args(),
		local_array_push_literal_sink_source, os.join_path(tmp_dir,
		'autofree_local_array_push_literal_sink_cleanup_none.c'))
	assert_autofree_local_array_push_literal_sink_cleanup_absent_in_fn(local_array_push_literal_sink_disabled_res,
		'build_local_array_push_literal_return')
	assert_autofree_local_array_push_literal_sink_cleanup_absent_in_fn(local_array_push_literal_sink_freestanding_linux_res,
		'build_local_array_push_literal_return')
	assert_autofree_local_array_push_literal_sink_cleanup_absent_in_fn(local_array_push_literal_sink_none_res,
		'build_local_array_push_literal_return')

	two_array_hosted_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_two_array_cleanup_hosted', cleanc_autofree_hosted_args(), two_array_source, os.join_path(tmp_dir,
		'autofree_two_array_cleanup_hosted.c'))
	for fn_name in ['build_two_empty_arrays', 'build_two_cap_arrays', 'build_two_len_arrays'] {
		assert_autofree_two_array_cleanup_present_in_fn(two_array_hosted_res, fn_name)
	}

	two_array_disabled_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_two_array_cleanup_disabled', cleanc_autofree_disabled_args(), two_array_source, os.join_path(tmp_dir,
		'autofree_two_array_cleanup_disabled.c'))
	two_array_freestanding_linux_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_two_array_cleanup_freestanding_linux', cleanc_autofree_freestanding_linux_args(),
		two_array_source, os.join_path(tmp_dir, 'autofree_two_array_cleanup_freestanding_linux.c'))
	two_array_none_res := run_v2_to_output(v2_binary, tmp_dir, 'autofree_two_array_cleanup_none',
		cleanc_autofree_none_args(), two_array_source, os.join_path(tmp_dir,
		'autofree_two_array_cleanup_none.c'))
	for fn_name in ['build_two_empty_arrays', 'build_two_cap_arrays', 'build_two_len_arrays'] {
		assert_autofree_two_array_cleanup_absent_in_fn(two_array_disabled_res, fn_name)
		assert_autofree_two_array_cleanup_absent_in_fn(two_array_freestanding_linux_res, fn_name)
		assert_autofree_two_array_cleanup_absent_in_fn(two_array_none_res, fn_name)
	}

	mixed_two_array_hosted_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_mixed_two_array_cleanup_hosted', cleanc_autofree_hosted_args(),
		mixed_two_array_source, os.join_path(tmp_dir, 'autofree_mixed_two_array_cleanup_hosted.c'))
	mixed_two_array_fns := [
		'build_mixed_empty_cap_arrays',
		'build_mixed_cap_empty_arrays',
		'build_mixed_empty_len_arrays',
		'build_mixed_len_empty_arrays',
		'build_mixed_cap_len_arrays',
		'build_mixed_len_cap_arrays',
	]
	for fn_name in mixed_two_array_fns {
		assert_autofree_two_array_cleanup_present_in_fn(mixed_two_array_hosted_res, fn_name)
	}

	mixed_two_array_disabled_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_mixed_two_array_cleanup_disabled', cleanc_autofree_disabled_args(),
		mixed_two_array_source,
		os.join_path(tmp_dir, 'autofree_mixed_two_array_cleanup_disabled.c'))
	mixed_two_array_freestanding_linux_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_mixed_two_array_cleanup_freestanding_linux',
		cleanc_autofree_freestanding_linux_args(), mixed_two_array_source, os.join_path(tmp_dir,
		'autofree_mixed_two_array_cleanup_freestanding_linux.c'))
	mixed_two_array_none_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_mixed_two_array_cleanup_none', cleanc_autofree_none_args(),
		mixed_two_array_source, os.join_path(tmp_dir, 'autofree_mixed_two_array_cleanup_none.c'))
	for fn_name in mixed_two_array_fns {
		assert_autofree_two_array_cleanup_absent_in_fn(mixed_two_array_disabled_res, fn_name)
		assert_autofree_two_array_cleanup_absent_in_fn(mixed_two_array_freestanding_linux_res,
			fn_name)
		assert_autofree_two_array_cleanup_absent_in_fn(mixed_two_array_none_res, fn_name)
	}

	len_only_final_clone_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_len_only_final_clone_cleanup_hosted', cleanc_autofree_hosted_args(),
		len_only_final_clone_source, os.join_path(tmp_dir,
		'autofree_len_only_final_clone_cleanup_hosted.c'))
	assert_autofree_len_only_final_clone_cleanup_present_in_fn(len_only_final_clone_res,
		'fill_array_from_len_only')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_len_only_final_clone_cleanup', len_only_final_clone_source) {
		assert_autofree_fresh_local_final_clone_cleanup_absent_in_fn(res,
			'fill_array_from_len_only')
	}

	cap_only_final_clone_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_cap_only_final_clone_cleanup_hosted', cleanc_autofree_hosted_args(),
		cap_only_final_clone_source, os.join_path(tmp_dir,
		'autofree_cap_only_final_clone_cleanup_hosted.c'))
	assert_autofree_fresh_local_final_clone_cleanup_present_in_fn(cap_only_final_clone_res,
		'fill_array_from_cap_only')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_cap_only_final_clone_cleanup', cap_only_final_clone_source) {
		assert_autofree_fresh_local_final_clone_cleanup_absent_in_fn(res,
			'fill_array_from_cap_only')
	}

	fresh_local_final_clone_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_fresh_local_final_clone_cleanup_hosted', cleanc_autofree_hosted_args(),
		fresh_local_final_clone_source, os.join_path(tmp_dir,
		'autofree_fresh_local_final_clone_cleanup_hosted.c'))
	assert_autofree_fresh_local_final_clone_cleanup_present_in_fn(fresh_local_final_clone_res,
		'fill_array_from_fresh_local')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_fresh_local_final_clone_cleanup', fresh_local_final_clone_source) {
		assert_autofree_fresh_local_final_clone_cleanup_absent_in_fn(res,
			'fill_array_from_fresh_local')
	}

	prefixed_fresh_local_final_clone_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_prefixed_fresh_local_final_clone_cleanup_hosted', cleanc_autofree_hosted_args(),
		prefixed_fresh_local_final_clone_source, os.join_path(tmp_dir,
		'autofree_prefixed_fresh_local_final_clone_cleanup_hosted.c'))
	assert_autofree_fresh_local_final_clone_cleanup_present_in_fn(prefixed_fresh_local_final_clone_res,
		'fill_array_from_prefixed_fresh_local')

	prefixed_fresh_local_final_clone_disabled_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_prefixed_fresh_local_final_clone_cleanup_disabled',
		cleanc_autofree_disabled_args(), prefixed_fresh_local_final_clone_source, os.join_path(tmp_dir,
		'autofree_prefixed_fresh_local_final_clone_cleanup_disabled.c'))
	prefixed_fresh_local_final_clone_freestanding_linux_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_prefixed_fresh_local_final_clone_cleanup_freestanding_linux',
		cleanc_autofree_freestanding_linux_args(), prefixed_fresh_local_final_clone_source, os.join_path(tmp_dir,
		'autofree_prefixed_fresh_local_final_clone_cleanup_freestanding_linux.c'))
	prefixed_fresh_local_final_clone_none_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_prefixed_fresh_local_final_clone_cleanup_none', cleanc_autofree_none_args(),
		prefixed_fresh_local_final_clone_source, os.join_path(tmp_dir,
		'autofree_prefixed_fresh_local_final_clone_cleanup_none.c'))
	assert_autofree_fresh_local_final_clone_cleanup_absent_in_fn(prefixed_fresh_local_final_clone_disabled_res,
		'fill_array_from_prefixed_fresh_local')
	assert_autofree_fresh_local_final_clone_cleanup_absent_in_fn(prefixed_fresh_local_final_clone_freestanding_linux_res,
		'fill_array_from_prefixed_fresh_local')
	assert_autofree_fresh_local_final_clone_cleanup_absent_in_fn(prefixed_fresh_local_final_clone_none_res,
		'fill_array_from_prefixed_fresh_local')

	multi_param_fresh_local_final_clone_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_multi_param_fresh_local_final_clone_cleanup_hosted',
		cleanc_autofree_hosted_args(), multi_param_fresh_local_final_clone_source, os.join_path(tmp_dir,
		'autofree_multi_param_fresh_local_final_clone_cleanup_hosted.c'))
	assert_autofree_fresh_local_final_clone_cleanup_present_in_fn(multi_param_fresh_local_final_clone_res,
		'fill_array_from_fresh_local_with_extra')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_multi_param_fresh_local_final_clone_cleanup',
		multi_param_fresh_local_final_clone_source) {
		assert_autofree_fresh_local_final_clone_cleanup_absent_in_fn(res,
			'fill_array_from_fresh_local_with_extra')
	}

	receiver_fresh_local_final_clone_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_receiver_fresh_local_final_clone_cleanup_hosted', cleanc_autofree_hosted_args(),
		receiver_fresh_local_final_clone_source, os.join_path(tmp_dir,
		'autofree_receiver_fresh_local_final_clone_cleanup_hosted.c'))
	assert_autofree_receiver_fresh_local_final_clone_cleanup_present_in_fn(receiver_fresh_local_final_clone_res,
		'Game__fill_array_from_fresh_local')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_receiver_fresh_local_final_clone_cleanup',
		receiver_fresh_local_final_clone_source) {
		assert_autofree_receiver_fresh_local_final_clone_cleanup_absent_in_fn(res,
			'Game__fill_array_from_fresh_local')
	}

	receiver_field_slice_clone_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_receiver_field_slice_clone_cleanup_hosted', cleanc_autofree_hosted_args(),
		receiver_field_slice_clone_source, os.join_path(tmp_dir,
		'autofree_receiver_field_slice_clone_cleanup_hosted.c'))
	assert_autofree_receiver_field_slice_clone_cleanup_present_in_fn(receiver_field_slice_clone_res,
		'Game__fill_array_from_field_slice')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_receiver_field_slice_clone_cleanup', receiver_field_slice_clone_source) {
		assert_autofree_receiver_field_slice_clone_cleanup_absent_in_fn(res,
			'Game__fill_array_from_field_slice')
	}

	loop_local_clone_push_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_loop_local_clone_push_cleanup_hosted', cleanc_autofree_hosted_args(),
		loop_local_clone_push_source, os.join_path(tmp_dir,
		'autofree_loop_local_clone_push_cleanup_hosted.c'))
	assert_autofree_loop_local_clone_push_cleanup_present_in_fn(loop_local_clone_push_res,
		'Board__fill_rows')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_loop_local_clone_push_cleanup', loop_local_clone_push_source) {
		assert_autofree_loop_local_clone_push_cleanup_absent_in_fn(res, 'Board__fill_rows')
	}
}

fn test_cleanc_autofree_receiver_field_slice_clone_cleanup_generates_local_only_free() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_receiver_field_slice_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	source := autofree_receiver_field_slice_clone_cleanup_source()
	hosted_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_receiver_field_slice_clone_cleanup_hosted', cleanc_autofree_hosted_args(),
		source, os.join_path(tmp_dir, 'autofree_receiver_field_slice_clone_cleanup_hosted.c'))
	assert_autofree_receiver_field_slice_clone_cleanup_present_in_fn(hosted_res,
		'Game__fill_array_from_field_slice')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_receiver_field_slice_clone_cleanup', source) {
		assert_autofree_receiver_field_slice_clone_cleanup_absent_in_fn(res,
			'Game__fill_array_from_field_slice')
	}
}

fn test_cleanc_autofree_receiver_field_slice_clone_nested_then_cleanup_generates_local_only_free() {
	tmp_dir := os.join_path(os.vtmp_dir(),
		'v2_cleanc_receiver_field_slice_nested_then_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	source := autofree_receiver_field_slice_clone_nested_then_cleanup_source()
	hosted_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_receiver_field_slice_clone_nested_then_cleanup_hosted',
		cleanc_autofree_hosted_args(), source, os.join_path(tmp_dir,
		'autofree_receiver_field_slice_clone_nested_then_cleanup_hosted.c'))
	assert_autofree_receiver_field_slice_clone_nested_then_cleanup_present_in_fn(hosted_res,
		'Game__fill_array_from_field_slice_then_loop')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_receiver_field_slice_clone_nested_then_cleanup', source) {
		assert_autofree_receiver_field_slice_clone_cleanup_absent_in_fn(res,
			'Game__fill_array_from_field_slice_then_loop')
	}
}

fn test_cleanc_autofree_loop_local_clone_push_cleanup_generates_local_only_free() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_loop_local_clone_push_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	source := autofree_loop_local_clone_push_cleanup_source()
	hosted_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_loop_local_clone_push_cleanup_hosted', cleanc_autofree_hosted_args(), source, os.join_path(tmp_dir,
		'autofree_loop_local_clone_push_cleanup_hosted.c'))
	assert_autofree_loop_local_clone_push_cleanup_present_in_fn(hosted_res, 'Board__fill_rows')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_loop_local_clone_push_cleanup', source) {
		assert_autofree_loop_local_clone_push_cleanup_absent_in_fn(res, 'Board__fill_rows')
	}
}

fn test_cleanc_autofree_loop_local_clone_push_cleanup_handles_preamble_before_loop() {
	tmp_dir := os.join_path(os.vtmp_dir(),
		'v2_cleanc_loop_local_clone_push_preamble_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	source := autofree_loop_local_clone_push_preamble_cleanup_source()
	hosted_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_loop_local_clone_push_preamble_cleanup_hosted', cleanc_autofree_hosted_args(),
		source, os.join_path(tmp_dir, 'autofree_loop_local_clone_push_preamble_cleanup_hosted.c'))
	assert_autofree_loop_local_clone_push_cleanup_present_in_fn(hosted_res,
		'Board__fill_rows_after_setup')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_loop_local_clone_push_preamble_cleanup', source) {
		assert_autofree_loop_local_clone_push_cleanup_absent_in_fn(res,
			'Board__fill_rows_after_setup')
	}
}

fn test_cleanc_autofree_fresh_local_string_clone_push_cleanup_generates_local_only_free() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_fresh_local_string_clone_push_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	source := autofree_fresh_local_string_clone_push_cleanup_source()
	hosted_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_fresh_local_string_clone_push_cleanup_hosted', cleanc_autofree_hosted_args(),
		source, os.join_path(tmp_dir, 'autofree_fresh_local_string_clone_push_cleanup_hosted.c'))
	assert_autofree_fresh_local_string_clone_push_cleanup_present_in_fn(hosted_res, 'push_joined')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_fresh_local_string_clone_push_cleanup', source) {
		assert_autofree_fresh_local_string_clone_push_cleanup_absent_in_fn(res, 'push_joined')
	}
}

fn test_cleanc_autofree_fresh_local_string_clone_push_local_destination_cleanup_generates_local_only_free() {
	tmp_dir := os.join_path(os.vtmp_dir(),
		'v2_cleanc_fresh_local_string_clone_push_local_destination_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	source := autofree_fresh_local_string_clone_push_local_destination_cleanup_source()
	hosted_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_fresh_local_string_clone_push_local_destination_cleanup_hosted',
		cleanc_autofree_hosted_args(), source, os.join_path(tmp_dir,
		'autofree_fresh_local_string_clone_push_local_destination_cleanup_hosted.c'))
	assert_autofree_fresh_local_string_clone_push_cleanup_present_in_fn(hosted_res, 'build')
	for res in run_cleanc_autofree_absent_target_results(v2_binary, tmp_dir,
		'autofree_fresh_local_string_clone_push_local_destination_cleanup', source) {
		assert_autofree_fresh_local_string_clone_push_cleanup_absent_in_fn(res, 'build')
	}
}

fn test_cleanc_autofree_eprintln_string_interpolation_cleanup_respects_target_runtime_contract() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_eprintln_interpolation_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	source := autofree_eprintln_string_interpolation_cleanup_source()
	hosted_res := run_v2_to_output(v2_binary, tmp_dir,
		'autofree_eprintln_interpolation_cleanup_hosted', cleanc_autofree_hosted_args(), source, os.join_path(tmp_dir,
		'autofree_eprintln_interpolation_cleanup_hosted.c'))
	assert_autofree_eprintln_string_interpolation_cleanup_present_in_fn(hosted_res, 'log_ai')
	for res in run_cleanc_autofree_eprintln_absent_target_results(v2_binary, tmp_dir,
		'autofree_eprintln_interpolation_cleanup', source) {
		assert_autofree_eprintln_string_interpolation_cleanup_absent_in_fn(res, 'log_ai')
	}
}

fn test_cleanc_examples_rule110_generates_c_with_autofree_delta() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_rule110_example_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	source := e2e_example_source('examples/rule110.v')
	normal_res := run_v2_to_output(v2_binary, tmp_dir, 'rule110_normal',
		cleanc_autofree_disabled_args(), source, os.join_path(tmp_dir, 'rule110_normal.c'))
	autofree_res := run_v2_to_output(v2_binary, tmp_dir, 'rule110_autofree',
		cleanc_autofree_hosted_args(), source, os.join_path(tmp_dir, 'rule110_autofree.c'))
	assert_cli_success(normal_res)
	assert_cli_success(autofree_res)

	normal_body := generated_c_function_body_or_fail(normal_res, 'next_generation')
	autofree_body := generated_c_function_body_or_fail(autofree_res, 'next_generation')
	normal_free_count := generated_c_body_substring_count(normal_body, 'array__free(')
	autofree_free_count := generated_c_body_substring_count(autofree_body, 'array__free(')
	assert normal_free_count == 0, normal_res.c_source
	assert autofree_free_count > normal_free_count, autofree_res.c_source
	final_clone_idx := autofree_body.index_after('gen = array__clone', 0) or {
		assert false, autofree_res.c_source
		return
	}
	cleanup_idx := autofree_body.index_after('array__free(&arr);', 0) or {
		assert false, autofree_res.c_source
		return
	}
	assert final_clone_idx < cleanup_idx, autofree_res.c_source
	assert !autofree_body[..final_clone_idx].contains('array__free(&arr);'), autofree_res.c_source
	assert !autofree_body.contains('array__free(&gen);'), autofree_res.c_source
	assert !autofree_body.contains('array__free(gen);'), autofree_res.c_source
}

fn test_cleanc_cli_does_not_auto_run_stale_test_binary_for_generation_only_target() {
	$if windows {
		eprintln('skip: stale executable auto-run guard uses a POSIX shell script')
		return
	}
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_no_stale_autorun_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	source_path := os.join_path(tmp_dir, 'stale_autorun_test.v')
	stale_path := os.join_path(tmp_dir, 'stale_autorun_test')
	os.write_file(source_path, 'module main

fn main() {}
') or { panic(err) }
	os.write_file(stale_path, '#!/bin/sh
echo STALE_AUTORUN_EXECUTED
exit 73
') or { panic(err) }
	os.chmod(stale_path, 0o755) or { panic(err) }

	res :=
		os.execute('cd "${tmp_dir}" && "${v2_binary}" -gc none -nocache --no-parallel -freestanding -os none --skip-builtin "${source_path}"')
	assert res.exit_code == 0, res.output
	assert !res.output.contains('STALE_AUTORUN_EXECUTED'), res.output
	assert os.exists(os.join_path(tmp_dir, 'stale_autorun_test.c')), res.output
	assert os.exists(stale_path), res.output

	non_host_target := concrete_non_host_e2e_os()
	cleanc_source_path := os.join_path(tmp_dir, 'cleanc_non_host_stale.v')
	cleanc_stale_path := os.join_path(tmp_dir, 'cleanc_non_host_stale')
	os.write_file(cleanc_source_path, 'module main

fn main() {}
') or { panic(err) }
	os.write_file(cleanc_stale_path, '#!/bin/sh
echo CLEANC_NON_HOST_STALE_EXECUTED
exit 75
') or {
		panic(err)
	}
	os.chmod(cleanc_stale_path, 0o755) or { panic(err) }
	cleanc_res :=
		os.execute('cd "${tmp_dir}" && "${v2_binary}" -gc none -nocache --no-parallel -os ${non_host_target} "${cleanc_source_path}"')
	assert cleanc_res.exit_code == 0, cleanc_res.output
	assert !cleanc_res.output.contains('CLEANC_NON_HOST_STALE_EXECUTED'), cleanc_res.output
	assert os.exists(os.join_path(tmp_dir, 'cleanc_non_host_stale.c')), cleanc_res.output
	assert os.exists(cleanc_stale_path), cleanc_res.output

	native_source_path := os.join_path(tmp_dir, 'native_cross_autorun_test.v')
	native_stale_path := os.join_path(tmp_dir, 'native_cross_autorun_test')
	os.write_file(native_source_path, 'module main

fn main() {}
') or { panic(err) }
	os.write_file(native_stale_path, '#!/bin/sh
echo NATIVE_STALE_AUTORUN_EXECUTED
exit 74
') or {
		panic(err)
	}
	os.chmod(native_stale_path, 0o755) or { panic(err) }
	native_res :=
		os.execute('cd "${tmp_dir}" && "${v2_binary}" -gc none -nocache --no-parallel -b x64 -os ${non_host_target} --skip-builtin "${native_source_path}"')
	assert native_res.exit_code == 0, native_res.output
	assert !native_res.output.contains('NATIVE_STALE_AUTORUN_EXECUTED'), native_res.output
	assert os.exists(native_stale_path), native_res.output
}

fn test_cleanc_cli_auto_runs_cross_test_binary_when_compiled_for_host() {
	if !host_cc_available() {
		eprintln('skip: cc is not available for cleanc cross auto-run e2e')
		return
	}
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_cross_autorun_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	v2_binary := build_v2_for_target_e2e(tmp_dir)
	source_path := os.join_path(tmp_dir, 'cross_autorun_test.v')
	os.write_file(source_path, 'module main

fn main() {
	println("CROSS_AUTORUN_OK")
}
') or {
		panic(err)
	}
	env_prefix := if host_c_e2e_flags().len > 0 { 'V2CFLAGS="${host_c_e2e_flags()}" ' } else { '' }
	res :=
		os.execute('cd "${tmp_dir}" && ${env_prefix}"${v2_binary}" -gc none -nocache --no-parallel -cc cc -os cross "${source_path}"')
	assert res.exit_code == 0, res.output
	assert res.output.contains('CROSS_AUTORUN_OK'), res.output
	assert !os.exists(os.join_path(tmp_dir, 'cross_autorun_test')), res.output
}
