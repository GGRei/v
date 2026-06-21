module pref

import os

pub struct Preferences {
pub mut:
	verbose      bool
	output_file  string
	target_os    string = os.user_os()
	user_defines []string
	backend      string = 'c'
	vroot        string = detect_vroot()
}

pub fn new_preferences() &Preferences {
	return &Preferences{}
}

fn detect_vroot() string {
	baked_root := @VMODROOT
	if baked_root.len > 0 {
		return baked_root
	}
	if os.args.len > 0 && os.args[0].len > 0 {
		vroot := detect_vroot_from(os.args[0])
		if vroot.len > 0 {
			return vroot
		}
	}
	return detect_vroot_from(os.getwd())
}

fn detect_vroot_from(start string) string {
	if start.len == 0 {
		return ''
	}
	mut dir := start
	if !os.is_abs_path(dir) {
		cwd := os.getwd()
		if cwd.len > 0 {
			dir = os.join_path_single(cwd, dir)
		}
	}
	if !os.is_dir(dir) {
		dir = os.dir(dir)
	}
	for _ in 0 .. 8 {
		if os.is_dir(os.join_path_single(os.join_path_single(dir, 'vlib'), 'builtin')) {
			return dir
		}
		parent := os.dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return ''
}

pub fn (p &Preferences) get_vlib_module_path(mod string) string {
	mod_path := mod.replace('.', os.path_separator)
	return os.join_path_single(os.join_path_single(p.vroot, 'vlib'), mod_path)
}

pub fn (p &Preferences) get_module_path(mod string, importing_file_path string) string {
	mod_path := mod.replace('.', os.path_separator)
	relative_path := os.join_path_single(os.dir(importing_file_path), mod_path)
	if os.is_dir(relative_path) {
		return relative_path
	}
	vlib_path := os.join_path_single(os.join_path_single(p.vroot, 'vlib'), mod_path)
	if os.is_dir(vlib_path) {
		return vlib_path
	}
	return ''
}

pub fn file_has_incompatible_os_suffix(file string, current_os string) bool {
	os_name := normalized_os(current_os)
	if os_name == 'windows' && file.contains('_nix.') {
		return true
	}
	if os_name != 'windows' && file.contains('_windows.') {
		return true
	}
	if os_name != 'linux' && file.contains('_linux.') {
		return true
	}
	if os_name != 'macos' && (file.contains('_macos.') || file.contains('_darwin.')) {
		return true
	}
	if os_name != 'macos' && os_name != 'freebsd' && os_name != 'openbsd' && os_name != 'netbsd'
		&& os_name != 'dragonfly' && file.contains('_bsd.') {
		return true
	}
	if os_name != 'android' && file.contains('_android') {
		return true
	}
	if os_name != 'ios' && file.contains('_ios.') {
		return true
	}
	if os_name != 'freebsd' && file.contains('_freebsd.') {
		return true
	}
	if os_name != 'openbsd' && file.contains('_openbsd.') {
		return true
	}
	if os_name != 'netbsd' && file.contains('_netbsd.') {
		return true
	}
	if os_name != 'dragonfly' && file.contains('_dragonfly.') {
		return true
	}
	if os_name != 'solaris' && file.contains('_solaris.') {
		return true
	}
	if file.contains('.amd64.') || file.contains('_amd64.') || file.contains('.arm64.')
		|| file.contains('_arm64.') {
		return true
	}
	return false
}

pub fn get_v_files_from_dir(dir string, user_defines []string, target_os string) []string {
	if dir == '' || !os.is_dir(dir) {
		return []string{}
	}
	all_files := os.ls(dir) or { return []string{} }
	mut v_files := []string{}
	for file in all_files {
		if !file.ends_with('.v') || file.ends_with('.js.v') || file.contains('_test.') {
			continue
		}
		if file_has_incompatible_os_suffix(file, target_os) {
			continue
		}
		if file.contains('_notd_') {
			feature := extract_define_feature(file, '_notd_')
			if feature.len > 0 && feature in user_defines {
				continue
			}
		} else if file.contains('_d_') {
			feature := extract_define_feature(file, '_d_')
			if feature.len == 0 || feature !in user_defines {
				continue
			}
		}
		v_files << os.join_path_single(dir, file)
	}
	return v_files
}

fn extract_define_feature(file string, marker string) string {
	idx := file.index(marker) or { return '' }
	rest := file[idx + marker.len..]
	if rest.ends_with('.c.v') {
		return rest[..rest.len - 4]
	}
	if rest.ends_with('.v') {
		return rest[..rest.len - 2]
	}
	return rest
}

pub fn normalized_os(target_os string) string {
	return match target_os {
		'darwin' { 'macos' }
		'mac' { 'macos' }
		else { target_os }
	}
}

pub fn (p &Preferences) normalized_target_os() string {
	return normalized_os(p.target_os)
}

pub fn (p &Preferences) is_cross_target() bool {
	return p.normalized_target_os() != normalized_os(os.user_os())
}

pub fn expand_vroot_marker(text string, vroot string) string {
	if !text.contains('@VEXEROOT') {
		return text
	}
	root := if vroot.len > 0 { vroot } else { detect_vroot() }
	return text.replace('@VEXEROOT', root)
}

pub fn c_flag_from_directive(flag_text string, p &Preferences) ?string {
	text := flag_text.trim_space()
	if text.len == 0 {
		return none
	}
	parts := split_c_flag_tokens(text)
	if parts.len == 0 {
		return none
	}
	first := parts[0]
	mut flag := text
	if is_c_flag_condition_token(first, p) {
		if !comptime_flag_value(p, first) {
			return none
		}
		flag = text[first.len..].trim_space()
	}
	if flag.len == 0 {
		return none
	}
	return expand_vroot_marker_for_c_flag(flag, p.vroot)
}

fn is_c_flag_condition_token(flag_token string, p &Preferences) bool {
	if flag_token.len == 0 {
		return false
	}
	if flag_token[0] == `-` || flag_token[0] == `@` {
		return false
	}
	if flag_token.contains('/') || flag_token.contains('\\') || flag_token.ends_with('.o')
		|| flag_token.ends_with('.a') {
		return false
	}
	if flag_token in p.user_defines {
		return true
	}
	return flag_token in ['linux', 'macos', 'darwin', 'mac', 'windows', 'freebsd', 'openbsd',
		'netbsd', 'dragonfly', 'android', 'ios', 'solaris', 'posix', 'unix', 'bsd', 'x64', 'amd64',
		'arm64', 'aarch64', 'little_endian', 'big_endian', 'debug', 'prod', 'native', 'tinyc',
		'msvc', 'livemain', 'sharedlive', 'wasm32', 'wasm32_emscripten', 'emscripten', 'gcboehm',
		'gcboehm_opt', 'prealloc', 'autofree', 'no_bounds_checking', 'freestanding', 'nofloat',
		'no_sokol_app', 'sokol_wayland', 'darwin_sokol_glcore33']
}

fn expand_vroot_marker_for_c_flag(flag string, vroot string) string {
	if !flag.contains('@VEXEROOT') {
		return flag
	}
	root := if vroot.len > 0 { vroot } else { detect_vroot() }
	mut parts := split_c_flag_tokens(flag)
	for i, part in parts {
		if !part.contains('@VEXEROOT') {
			continue
		}
		unquoted := c_flag_unquote_token(part)
		if unquoted.starts_with('-I@VEXEROOT') || unquoted.starts_with('-L@VEXEROOT') {
			prefix := unquoted[..2]
			path := unquoted[2..].replace('@VEXEROOT', root)
			parts[i] = prefix + os.quoted_path(path)
			continue
		}
		expanded := unquoted.replace('@VEXEROOT', root)
		if unquoted.starts_with('-') {
			parts[i] = expanded
		} else {
			parts[i] = os.quoted_path(expanded)
		}
	}
	return parts.join(' ')
}

pub fn split_c_flag_tokens(text string) []string {
	mut tokens := []string{}
	mut start := -1
	mut quote := u8(0)
	mut escaped := false
	for i in 0 .. text.len {
		ch := text[i]
		if quote != 0 {
			if ch == `\\` && !escaped {
				escaped = true
				continue
			}
			if ch == quote && !escaped {
				quote = 0
			}
			escaped = false
			continue
		}
		if ch == `'` || ch == `"` {
			if start < 0 {
				start = i
			}
			quote = ch
			escaped = false
			continue
		}
		if c_flag_is_space(ch) {
			if start >= 0 {
				tokens << text[start..i]
				start = -1
			}
			continue
		}
		if start < 0 {
			start = i
		}
	}
	if start >= 0 {
		tokens << text[start..]
	}
	return tokens
}

fn c_flag_is_space(ch u8) bool {
	return ch == ` ` || ch == `\t` || ch == `\r` || ch == `\n`
}

pub fn c_flag_unquote_token(flag_token string) string {
	if flag_token.len >= 2 {
		first := flag_token[0]
		last := flag_token[flag_token.len - 1]
		if (first == `'` && last == `'`) || (first == `"` && last == `"`) {
			return flag_token[1..flag_token.len - 1]
		}
	}
	return flag_token
}

pub fn comptime_flag_value(p &Preferences, name string) bool {
	match name {
		'macos', 'darwin', 'mac' {
			return p.normalized_target_os() == 'macos'
		}
		'linux' {
			return p.normalized_target_os() == 'linux'
		}
		'windows' {
			return p.normalized_target_os() == 'windows'
		}
		'freebsd' {
			return p.normalized_target_os() == 'freebsd'
		}
		'openbsd' {
			return p.normalized_target_os() == 'openbsd'
		}
		'netbsd' {
			return p.normalized_target_os() == 'netbsd'
		}
		'dragonfly' {
			return p.normalized_target_os() == 'dragonfly'
		}
		'android' {
			return p.normalized_target_os() == 'android'
		}
		'posix', 'unix' {
			return p.normalized_target_os() != 'windows'
		}
		'bsd' {
			tos := p.normalized_target_os()
			return tos == 'macos' || tos == 'freebsd' || tos == 'openbsd' || tos == 'netbsd'
				|| tos == 'dragonfly'
		}
		'x64', 'amd64' {
			$if amd64 {
				return true
			}
			return false
		}
		'arm64', 'aarch64' {
			$if arm64 {
				return true
			}
			return false
		}
		'little_endian' {
			$if little_endian {
				return true
			}
			return false
		}
		'big_endian' {
			$if big_endian {
				return true
			}
			return false
		}
		'debug' {
			$if debug {
				return true
			}
			return false
		}
		'native' {
			return p.backend == 'arm64'
		}
		'builtin_write_buf_to_fd_should_use_c_write' {
			return p.backend == 'arm64'
		}
		'tinyc' {
			return p.backend == 'arm64'
		}
		'no_backtrace' {
			return p.backend == 'arm64' || name in p.user_defines
		}
		'gcboehm', 'gcboehm_opt', 'prealloc', 'autofree', 'no_bounds_checking', 'freestanding',
		'nofloat' {
			return name in p.user_defines
		}
		else {
			return name in p.user_defines
		}
	}
}

pub fn comptime_optional_flag_value(p &Preferences, name string) bool {
	if name in p.user_defines {
		return true
	}
	return comptime_flag_value(p, name)
}

pub fn comptime_pkgconfig_value(name string) bool {
	result := os.execute('pkg-config --exists ${name}')
	return result.exit_code == 0
}
