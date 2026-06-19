// Copyright (c) 2020-2024 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module pref

import os

fn (p &Preferences) effective_vroot() string {
	if p.vroot.len > 0 {
		return p.vroot
	}
	return os.getwd()
}

pub fn (p &Preferences) get_vlib_module_path(mod string) string {
	mod_path := mod.replace('.', os.path_separator)
	return module_path_join(module_path_join(p.effective_vroot(), 'vlib'), mod_path)
}

fn module_path_join(base string, name string) string {
	if base.len == 0 {
		return name
	}
	if name.len == 0 {
		return base
	}
	last := base[base.len - 1]
	if last == `/` || last == `\\` {
		return base + name
	}
	return base + os.path_separator + name
}

fn module_root_for_file(path string) string {
	mut dir := os.dir(path)
	for dir.len > 0 {
		if os.exists(module_path_join(dir, 'v.mod')) {
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

fn module_name_matches_import(declared string, mod string) bool {
	return declared == mod || declared == mod.all_after_last('.')
}

fn is_module_source_space(ch u8) bool {
	return ch == ` ` || ch == `\t` || ch == `\v` || ch == `\f` || ch == `\n` || ch == `\r`
}

fn is_module_line_space(ch u8) bool {
	return ch == ` ` || ch == `\t` || ch == `\v` || ch == `\f`
}

fn module_manifest_name_from_field(line string) ?string {
	if !line.starts_with('name') {
		return none
	}
	mut rest := line[4..].trim_space()
	if rest.len == 0 || rest[0] != `:` {
		return none
	}
	rest = rest[1..].trim_space()
	if rest.len < 2 || (rest[0] != `'` && rest[0] != `"`) {
		return none
	}
	quote := rest[0]
	mut name_end := 1
	for name_end < rest.len && rest[name_end] != quote {
		name_end++
	}
	if name_end <= 1 {
		return none
	}
	return rest[1..name_end]
}

fn module_manifest_strip_block_comments(line string, in_block_comment bool) (string, bool) {
	mut rest := line
	mut out := ''
	mut inside := in_block_comment
	for rest.len > 0 {
		if inside {
			end := rest.index('*/') or { return out, true }
			rest = rest[end + 2..]
			inside = false
			continue
		}
		start := rest.index('/*') or { return out + rest, false }
		out += rest[..start]
		rest = rest[start + 2..]
		end := rest.index('*/') or { return out, true }
		rest = rest[end + 2..]
	}
	return out, inside
}

fn module_manifest_name(dir string) ?string {
	content := os.read_file(module_path_join(dir, 'v.mod')) or { return none }
	mut in_module := false
	mut in_block_comment := false
	for raw_line in content.split_into_lines() {
		line_without_block, still_in_block := module_manifest_strip_block_comments(raw_line,
			in_block_comment)
		in_block_comment = still_in_block
		mut line := line_without_block.all_before('//').trim_space()
		if line.len == 0 {
			continue
		}
		if !in_module {
			if !line.starts_with('Module') {
				continue
			}
			line = line[6..].trim_space()
			if !line.starts_with('{') {
				continue
			}
			in_module = true
			line = line[1..].trim_space()
		}
		close_idx := line.index('}') or { -1 }
		if close_idx >= 0 {
			line = line[..close_idx].trim_space()
		}
		if name := module_manifest_name_from_field(line) {
			return name
		}
		if close_idx >= 0 {
			break
		}
	}
	return none
}

fn module_manifest_matches_import(dir string, mod string) bool {
	name := module_manifest_name(dir) or { return false }
	return module_name_matches_import(name, mod)
}

fn source_file_module_name(path string) ?string {
	content := os.read_file(path) or { return none }
	mut start := 0
	for start < content.len {
		if is_module_source_space(content[start]) {
			start++
			continue
		}
		if start + 1 < content.len && content[start] == `/` && content[start + 1] == `/` {
			start += 2
			for start < content.len && content[start] != `\n` && content[start] != `\r` {
				start++
			}
			continue
		}
		if start + 1 < content.len && content[start] == `/` && content[start + 1] == `*` {
			start += 2
			for start + 1 < content.len {
				if content[start] == `*` && content[start + 1] == `/` {
					start += 2
					break
				}
				start++
			}
			continue
		}
		break
	}
	if content.len - start < 7 || content[start..start + 6] != 'module'
		|| !is_module_line_space(content[start + 6]) {
		return none
	}
	mut name_start := start + 7
	for name_start < content.len && is_module_line_space(content[name_start]) {
		name_start++
	}
	mut name_end := name_start
	for name_end < content.len && !is_module_source_space(content[name_end]) {
		name_end++
	}
	if name_start < name_end {
		return content[name_start..name_end]
	}
	return none
}

fn module_source_file_candidate(name string) bool {
	return name.ends_with('.v') && !name.ends_with('.js.v') && !name.contains('_test.')
}

fn module_dir_matches_import(dir string, mod string) bool {
	if module_manifest_matches_import(dir, mod) {
		return true
	}
	entries := os.ls(dir) or { []string{} }
	for entry in entries {
		if !module_source_file_candidate(entry) {
			continue
		}
		declared := source_file_module_name(module_path_join(dir, entry)) or { continue }
		if module_name_matches_import(declared, mod) {
			return true
		}
	}
	return false
}

fn matching_module_path(path string, mod string) ?string {
	if dir_exists(path) && module_dir_matches_import(path, mod) {
		return path
	}
	return none
}

fn find_module_path_in_parent_dirs(mod_path string, importing_file_path string) ?string {
	mod := mod_path.replace(os.path_separator, '.')
	mut dir := os.dir(importing_file_path)
	for dir.len > 0 {
		parent_relative_path := module_path_join(dir, mod_path)
		if matching_path := matching_module_path(parent_relative_path, mod) {
			return matching_path
		}
		parent := os.dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return none
}

// check for relative and then vlib
pub fn (p &Preferences) get_module_path(mod string, importing_file_path string) string {
	mod_path := mod.replace('.', os.path_separator)
	vroot := p.effective_vroot()
	// relative to file importing it
	relative_path := module_path_join(os.dir(importing_file_path), mod_path)
	if matching_path := matching_module_path(relative_path, mod) {
		return matching_path
	}
	module_root := module_root_for_file(importing_file_path)
	if module_root != '' {
		root_relative_path := module_path_join(module_root, mod_path)
		if matching_path := matching_module_path(root_relative_path, mod) {
			return matching_path
		}
	}
	if parent_relative_path := find_module_path_in_parent_dirs(mod_path, importing_file_path) {
		return parent_relative_path
	}
	cwd_relative_path := module_path_join(os.getwd(), mod_path)
	if matching_path := matching_module_path(cwd_relative_path, mod) {
		return matching_path
	}
	// TODO: is this the best order?
	// vlib
	vlib_path := module_path_join(module_path_join(vroot, 'vlib'), mod_path)
	if dir_exists(vlib_path) {
		return vlib_path
	}
	// V1 compiler modules under vlib/v use legacy bare sibling imports
	// (`import token` from vlib/v/checker, with sources in vlib/v/token).
	vlib_v_path := module_path_join(module_path_join(vroot, 'vlib'), 'v')
	normalized_importer := importing_file_path.replace('\\', '/')
	normalized_vlib_v := vlib_v_path.replace('\\', '/')
	if normalized_importer.starts_with(normalized_vlib_v + '/')
		|| normalized_importer.starts_with('vlib/v/') {
		legacy_v_path := module_path_join(vlib_v_path, mod_path)
		if dir_exists(legacy_v_path) {
			return legacy_v_path
		}
	}
	// ~/.vmodules
	vmodules_path := module_path_join(p.vmodules_path, mod_path)
	if dir_exists(vmodules_path) {
		// V convention: if a module dir has a src/ subdirectory, use that
		src_path := module_path_join(vmodules_path, 'src')
		if dir_exists(src_path) {
			return src_path
		}
		return vmodules_path
	}
	panic('Preferences.get_module_path: cannot find module path for `${mod}`')
}
