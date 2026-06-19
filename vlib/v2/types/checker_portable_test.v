module types

import os
import v2.parser
import v2.pref
import v2.token

fn check_files_portable(files_by_path map[string]string) {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_checker_portable_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic('failed to create temp dir') }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	mut paths := []string{}
	for rel_path, code in files_by_path {
		path := os.join_path(tmp_dir, rel_path)
		os.mkdir_all(os.dir(path)) or { panic('failed to create temp source dir') }
		os.write_file(path, code) or { panic('failed to write checker portable source') }
		paths << path
	}
	prefs := &pref.Preferences{}
	mut file_set := token.FileSet.new()
	mut par := parser.Parser.new(prefs)
	files := par.parse_files(paths, mut file_set)
	mut env := Environment.new()
	mut checker := Checker.new(prefs, file_set, env)
	checker.check_files(files)
}

fn check_code_portable(code string) {
	check_files_portable({
		'main.v': code
	})
}

fn check_files_must_fail_portable(files_by_path map[string]string) string {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_checker_portable_fail_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic('failed to create temp dir') }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	driver_file := os.join_path(tmp_dir, 'driver.v')
	mut paths := []string{}
	for rel_path, code in files_by_path {
		path := os.join_path(tmp_dir, rel_path)
		os.mkdir_all(os.dir(path)) or { panic('failed to create temp source dir') }
		os.write_file(path, code) or { panic('failed to write checker portable negative source') }
		paths << path
	}
	mut path_literals := []string{}
	for path in paths {
		path_literals << '"${path}"'
	}
	os.write_file(driver_file, '
module main

import v2.parser
import v2.pref
import v2.token
import v2.types

fn main() {
	prefs := &pref.Preferences{}
	mut file_set := token.FileSet.new()
	mut par := parser.Parser.new(prefs)
	files := par.parse_files([${path_literals.join(', ')}], mut file_set)
	env := types.Environment.new()
	mut checker := types.Checker.new(prefs, file_set, env)
	checker.check_files(files)
}
') or {
		panic('failed to write checker portable negative driver')
	}
	result := os.execute('${os.quoted_path(@VEXE)} run ${os.quoted_path(driver_file)}')
	assert result.exit_code != 0
	return result.output
}

fn check_code_must_fail_portable(code string) string {
	return check_files_must_fail_portable({
		'bad.v': code
	})
}

fn test_checker_portable_function_return_type_does_not_contextualize_local_fixed_array_decl() {
	check_code_portable('
struct Block {
	x int
}

fn parse_values() []Block {
	ten_powers := [1000, 100, 10, 1]!
	_ = ten_powers
	return []Block{}
}
')
}

fn test_checker_portable_function_return_type_still_contextualizes_return_expr() {
	output := check_code_must_fail_portable('
struct Block {
	x int
}

fn broken_values() []Block {
	return [1000, 100, 10, 1]!
}
')
	assert output.contains('expecting element of type') || output.contains('expected return')
}

fn test_checker_portable_return_type_context_is_restored_for_methods_and_fn_literals() {
	check_code_portable('
struct Block {
	x int
}

fn parse_values() []Block {
	ten_powers := [1000, 100, 10, 1]!
	_ = ten_powers
	callback := fn () int {
		return 7
	}
	_ = callback
	return []Block{}
}

fn (b Block) method_values() []Block {
	ten_powers := [1000, 100, 10, 1]!
	_ = ten_powers
	return []Block{}
}

fn scalar_after_array_return() int {
	return 3
}
')
}

fn test_checker_portable_assoc_update_accepts_imported_c_alias_base() {
	check_files_portable({
		'sapp/sapp.v': '
module sapp

pub struct C.sapp_desc {
pub:
	width int
}

pub type Desc = C.sapp_desc
'
		'main.v':      '
module main

import sapp

struct Ctx {
	window sapp.Desc
}

fn update(ctx Ctx) sapp.Desc {
	return sapp.Desc{
		...ctx.window
		width: 2
	}
}
'
	})
}

fn test_checker_portable_assoc_update_rejects_imported_distinct_c_struct_base() {
	output := check_files_must_fail_portable({
		'sapp/sapp.v': '
module sapp

pub struct C.sapp_desc {
pub:
	width int
}

pub type Desc = C.sapp_desc
'
		'main.v':      '
module main

import sapp

struct C.other_desc {
pub:
	width int
}

struct Ctx {
	window C.other_desc
}

fn update(ctx Ctx) sapp.Desc {
	return sapp.Desc{
		...ctx.window
		width: 2
	}
}
'
	})
	assert output.contains('expected base of type')
}

fn test_checker_portable_assoc_update_rejects_same_basename_different_modules() {
	output := check_files_must_fail_portable({
		'left/desc.v':  '
module left

pub struct Desc {
pub:
	width int
}
'
		'right/desc.v': '
module right

pub struct Desc {
pub:
	width int
}
'
		'main.v':       '
module main

import left
import right

struct Ctx {
	window right.Desc
}

fn update(ctx Ctx) left.Desc {
	return left.Desc{
		...ctx.window
		width: 2
	}
}
'
	})
	assert output.contains('expected base of type')
}

fn test_checker_portable_assoc_update_accepts_pointer_to_matching_alias_base() {
	check_files_portable({
		'sapp/sapp.v': '
module sapp

pub struct C.sapp_desc {
pub:
	width int
}

pub type Desc = C.sapp_desc
'
		'main.v':      '
module main

import sapp

struct Ctx {
	window &sapp.Desc
}

fn update(ctx Ctx) sapp.Desc {
	return sapp.Desc{
		...ctx.window
		width: 2
	}
}
'
	})
}

fn test_checker_portable_assoc_update_rejects_pointer_to_distinct_base() {
	output := check_files_must_fail_portable({
		'sapp/sapp.v': '
module sapp

pub struct C.sapp_desc {
pub:
	width int
}

pub type Desc = C.sapp_desc
'
		'main.v':      '
module main

import sapp

struct C.other_desc {
pub:
	width int
}

struct Ctx {
	window &C.other_desc
}

fn update(ctx Ctx) sapp.Desc {
	return sapp.Desc{
		...ctx.window
		width: 2
	}
}
'
	})
	assert output.contains('expected base of type')
}

fn test_checker_portable_assoc_update_rejects_pointer_to_pointer_base() {
	output := check_files_must_fail_portable({
		'sapp/sapp.v': '
module sapp

pub struct C.sapp_desc {
pub:
	width int
}

pub type Desc = C.sapp_desc
'
		'main.v':      '
module main

import sapp

struct Ctx {
	window &&sapp.Desc
}

fn update(ctx Ctx) sapp.Desc {
	return sapp.Desc{
		...ctx.window
		width: 2
	}
}
'
	})
	assert output.contains('expected base of type')
}

fn test_checker_portable_match_expr_infers_string_for_local_mut_value() {
	check_code_portable('
fn format_value(flag bool) string {
	mut res := match flag {
		true {
			"a|b"
		}
		false {
			"c|d"
		}
	}
	del := "-"
	res = res.replace("|", del)
	return res
}
')
}

fn test_checker_portable_match_expr_infers_string_for_local_value() {
	check_code_portable('
fn pick_value(flag bool) int {
	value := match flag {
		true {
			"a"
		}
		false {
			"b"
		}
	}
	return value.len
}
')
}

fn test_checker_portable_match_expr_rejects_mixed_value_branches() {
	output := check_code_must_fail_portable('
fn broken(flag bool) int {
	value := match flag {
		true {
			"a"
		}
		false {
			1
		}
	}
	return value.len
}
')
	assert output.len > 0
}

fn test_checker_portable_match_expr_fail_closed_without_trailing_value() {
	output := check_code_must_fail_portable('
fn broken(flag bool) int {
	value := match flag {
		true {
			"a"
		}
		false {
			mut n := 1
			n++
		}
	}
	return value.len
}
')
	assert output.len > 0
}

fn test_checker_portable_statement_match_without_value_stays_accepted() {
	check_code_portable('
fn update(flag bool) int {
	mut value := 0
	match flag {
		true {
			value = 1
		}
		false {
			value = 2
		}
	}
	return value
}
')
}

fn test_checker_portable_c_union_escaped_keyword_field_resolves() {
	check_code_portable('
pub union C.NativeEvent {
pub mut:
	@type  int
	payload int
}

fn update() int {
	mut event := C.NativeEvent{}
	unsafe {
		event.@type = 1
		event.payload = 2
	}
	return event.payload
}
')
}

fn test_checker_portable_c_struct_escaped_keyword_field_resolves() {
	check_code_portable('
pub struct C.NativeStruct {
pub mut:
	@type  int
	payload int
}

fn update() int {
	mut event := C.NativeStruct{}
	unsafe {
		event.@type = 1
		event.payload = 2
	}
	return event.payload
}
')
}

fn test_checker_portable_c_struct_unknown_escaped_field_stays_rejected() {
	output := check_code_must_fail_portable('
pub struct C.NativeStruct {
pub mut:
	@type  int
	payload int
}

fn update() {
	mut event := C.NativeStruct{}
	unsafe {
		event.@missing = 1
	}
}
')
	assert output.contains('cannot find field or method')
}

fn test_checker_portable_c_struct_normal_field_still_resolves() {
	check_code_portable('
pub struct C.NativeStruct {
pub mut:
	payload int
}

fn update() int {
	mut event := C.NativeStruct{}
	unsafe {
		event.payload = 2
	}
	return event.payload
}
')
}
