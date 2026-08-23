#!/usr/bin/env bash

set -euo pipefail

: "${CC_UNDER_TEST:?CC_UNDER_TEST is required}"
: "${CXX_UNDER_TEST:?CXX_UNDER_TEST is required}"

vexe='./v.exe'
probe='.github/workflows/static_pkgconfig_smoke/linker_cpp_probe.v'
parallel_probe='.github/workflows/static_pkgconfig_smoke/linker_cpp_parallel_probe.v'
artifact_dir=".static_pkgconfig_linker_artifacts/${CC_UNDER_TEST}"
mkdir -p "$artifact_dir"

for fixture in \
	"$probe" \
	"$parallel_probe" \
	.github/workflows/static_pkgconfig_smoke/linker_cpp_c_sentinel.h \
	.github/workflows/static_pkgconfig_smoke/linker_cpp_extra.c \
	.github/workflows/static_pkgconfig_smoke/linker_cpp_runtime.cpp
do
	[[ -s $fixture ]] || {
		echo "linker smoke: missing fixture $fixture" >&2
		exit 1
	}
done

fail() {
	echo "linker smoke: $*" >&2
	exit 1
}

runtime_source='.github/workflows/static_pkgconfig_smoke/linker_cpp_runtime.cpp'
runtime_object='.github/workflows/static_pkgconfig_smoke/linker_cpp_runtime.o'
runtime_log="$artifact_dir/runtime-object.log"
trap 'rm -f "$runtime_object"' EXIT
rm -f "$runtime_object"
{
	echo 'C++ runtime object precompile:'
	printf 'command:'
	printf ' %q' "$CXX_UNDER_TEST" -std=c++17 -c "$runtime_source" -o "$runtime_object"
	printf '\n'
	"$CXX_UNDER_TEST" --version
} >"$runtime_log" 2>&1
set +e
timeout 120s "$CXX_UNDER_TEST" -std=c++17 -c "$runtime_source" -o "$runtime_object" \
	>>"$runtime_log" 2>&1
runtime_rc=$?
set -e
[[ $runtime_rc -eq 0 ]] || {
	cat "$runtime_log"
	fail "C++ runtime object build failed with exit code $runtime_rc"
}
[[ -s $runtime_object ]] || fail "C++ runtime object is missing: $runtime_object"
sha256sum "$runtime_object" >>"$runtime_log"
cp "$runtime_object" "$artifact_dir/linker_cpp_runtime.o"
cat "$runtime_log"

driver_basename() {
	local command=$1
	local token
	if [[ $command == \"* ]]; then
		token=${command#\"}
		token=${token%%\"*}
	elif [[ $command == \'* ]]; then
		token=${command#\'}
		token=${token%%\'*}
	else
		token=${command%% *}
	fi
	token=${token##*\\}
	token=${token##*/}
	token=${token%.exe}
	printf '%s\n' "${token,,}"
}

assert_driver() {
	local command=$1
	local expected=${2,,}
	local actual
	actual=$(driver_basename "$command")
	[[ $actual == "$expected" ]] || fail "expected driver $expected, got $actual in: $command"
}

assert_c_source_sandwich() {
	local content=$1
	local source_pattern=$2
	local normalized=${content//\"/}
	normalized=${normalized//\'/}
	grep -Eq -- "-x[[:space:]]+c[[:space:]]+[^[:space:]]*${source_pattern}[[:space:]]+-x[[:space:]]+none" <<<"$normalized" \
		|| fail "missing '-x c <${source_pattern}> -x none' in: $content"
}

assert_direct_order() {
	local content=$1
	local normalized=${content//\"/}
	normalized=${normalized//\'/}
	local after_marker=${normalized#*.linker.o}
	[[ $after_marker != "$normalized" && $after_marker == *linker_cpp_extra.c* ]] \
		|| fail "marker object is not before the extra C source: $content"
	local after_extra=${after_marker#*linker_cpp_extra.c}
	[[ $after_extra != "$after_marker" && $after_extra == *'.tmp.c'* ]] \
		|| fail "extra C source is not before generated C: $content"
	local after_generated=${after_extra#*.tmp.c}
	grep -Eq -- '(^|[[:space:]])-l[^[:space:]]+' <<<"$after_generated" \
		|| fail "no linker library follows generated C: $content"
}

final_command() {
	local log=$1
	local line
	line=$(grep '^> C compiler cmd: ' "$log" | tail -n 1) \
		|| fail "missing final compiler command in $log"
	printf '%s\n' "${line#> C compiler cmd: }"
}

run_case() {
	local name=$1
	shift
	local log="$artifact_dir/${name}.log"
	local output="$artifact_dir/${name}.exe"
	local rc

	set +e
	timeout 300s "$vexe" \
		-cc "$CC_UNDER_TEST" \
		-c++ "$CXX_UNDER_TEST" \
		-gc none \
		-cflags '-static' \
		-keepc \
		-showcc \
		-show-c-output \
		-no-retry-compilation \
		"$@" \
		-o "$output" \
		"${CASE_PROBE:-$probe}" >"$log" 2>&1
	rc=$?
	set -e
	cat "$log"
	[[ $rc -eq 0 ]] || fail "$name build failed with exit code $rc"
	[[ -s $output ]] || fail "$name did not produce $output"
	timeout 30s "$output" || fail "$name executable failed"
}

check_marker_driver() {
	local log=$1
	local line
	line=$(grep '^> C++ linker marker cmd: ' "$log" | tail -n 1) \
		|| fail "missing C++ linker marker command in $log"
	assert_driver "${line#> C++ linker marker cmd: }" "$CXX_UNDER_TEST"
}

copy_retained_marker() {
	local log=$1
	local final_cmd=$2
	local marker_line marker_source_windows marker_object_windows marker_source marker_object
	marker_line=$(grep '^> C++ linker marker cmd: ' "$log" | tail -n 1)
	marker_line=${marker_line//\"/}
	marker_line=${marker_line//\'/}
	marker_source_windows=$(grep -Eo '[^[:space:]]+\.linker\.cpp' <<<"$marker_line" | tail -n 1)
	marker_object_windows=$(grep -Eo '[^[:space:]]+\.linker\.o' <<<"${final_cmd//\"/}" | head -n 1)
	[[ -n $marker_source_windows && -n $marker_object_windows ]] \
		|| fail "could not resolve retained marker paths"
	marker_source=$(cygpath -u "$marker_source_windows")
	marker_object=$(cygpath -u "$marker_object_windows")
	[[ -s $marker_source ]] || fail "retained marker source is missing: $marker_source_windows"
	[[ -s $marker_object ]] || fail "retained marker object is missing: $marker_object_windows"
	cp "$marker_source" "$artifact_dir/direct.marker.cpp"
	cp "$marker_object" "$artifact_dir/direct.marker.o"
}

run_case direct -no-rsp
direct_log="$artifact_dir/direct.log"
direct_cmd=$(final_command "$direct_log")
assert_driver "$direct_cmd" "$CXX_UNDER_TEST"
[[ $direct_cmd != *'@'*'.rsp'* ]] || fail "direct case unexpectedly used a response file"
assert_c_source_sandwich "$direct_cmd" 'linker_cpp_extra\.c'
assert_c_source_sandwich "$direct_cmd" '[^[:space:]]*\.tmp\.c'
assert_direct_order "$direct_cmd"
check_marker_driver "$direct_log"
copy_retained_marker "$direct_log" "$direct_cmd"

run_case response
response_log="$artifact_dir/response.log"
response_cmd=$(final_command "$response_log")
assert_driver "$response_cmd" "$CXX_UNDER_TEST"
[[ $response_cmd == *'@'*'.rsp'* ]] || fail "response case did not invoke an @response file"
check_marker_driver "$response_log"
rsp_windows=$(sed -n 's/^> C compiler response file "\(.*\)":$/\1/p' "$response_log" | tail -n 1)
[[ -n $rsp_windows ]] || fail "response file path was not printed"
rsp_path=$(cygpath -u "$rsp_windows")
[[ -s $rsp_path ]] || fail "retained response file is missing: $rsp_windows"
cp "$rsp_path" "$artifact_dir/response.rsp"
rsp_content=$(tr '\r\n' '  ' <"$rsp_path")
assert_c_source_sandwich "$rsp_content" 'linker_cpp_extra\.c'
assert_c_source_sandwich "$rsp_content" '[^[:space:]]*\.tmp\.c'
assert_direct_order "$rsp_content"

CASE_PROBE=$parallel_probe run_case parallel -parallel-cc
parallel_log="$artifact_dir/parallel.log"
compile_count=0
while IFS= read -r line; do
	command=${line#*cc_cmd: \`}
	command=${command%\` => *}
	assert_driver "$command" "$CC_UNDER_TEST"
	[[ $command == *' -c '* && $command == *out_*'.c'* ]] \
		|| fail "parallel C command does not compile an out_*.c source: $command"
	compile_count=$((compile_count + 1))
done < <(grep 'cc_cmd: `' "$parallel_log")
((compile_count > 0)) || fail "parallel build printed no C compilation commands"

link_line=$(grep 'link_cmd: `' "$parallel_log" | tail -n 1) \
	|| fail "parallel build printed no link command"
link_command=${link_line#*link_cmd: \`}
link_command=${link_command%\` => *}
assert_driver "$link_command" "$CXX_UNDER_TEST"

printf 'validated #linker c++ with C=%s C++=%s (direct, response, parallel)\n' \
	"$CC_UNDER_TEST" "$CXX_UNDER_TEST"
