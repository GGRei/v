// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module x64

import encoding.binary

pub const macos_tiny_not_eligible_prefix = 'macOS tiny object is not eligible: '

const macos_tiny_builtin_string_plus_symbol = '_builtin__string__+'
const macos_tiny_malloc_symbol = '_malloc'
const macos_tiny_exit_symbol = '_exit'

struct MachOTextRange {
	name  string
	start u64
	end   u64
}

struct MachODataRange {
	section ObjectSection
	start   u64
	end     u64
}

struct MachOTinyReachable {
mut:
	names     []string
	data      []MachODataRange
	undefined map[string]bool
}

struct MachOTinyObjectWriter {
	macho &MachOObject
}

struct MachOTinyRuntimeReloc {
	addr   int
	symbol string
}

pub fn (mut g Gen) write_macos_tiny_object(path string) ! {
	if g.obj_format != .macho {
		return error('macOS tiny object writing requires Mach-O object output')
	}
	if g.abi != .sysv {
		return error('macOS tiny object writing requires SysV x64 code generation')
	}
	mut writer := MachOTinyObjectWriter{
		macho: g.macho
	}
	writer.write(path)!
}

fn (mut w MachOTinyObjectWriter) write(path string) ! {
	mut reachable := w.collect_reachable()!
	mut out := MachOObject.new()
	mut symbol_indices := map[string]int{}
	mut func_offsets := map[string]u64{}
	mut runtime_symbols := []string{}
	mut runtime_relocs := []MachOTinyRuntimeReloc{}

	for name in reachable.names {
		range := w.text_range(name)!
		func_offsets[name] = u64(out.text_data.len)
		out.text_data << w.macho.text_data[int(range.start)..int(range.end)]
	}
	macho_tiny_add_runtime_helpers(mut out, mut reachable, mut func_offsets, mut runtime_symbols, mut
		runtime_relocs)

	mut data_offsets := map[string]u64{}
	w.copy_data_ranges(reachable.data, .rodata, mut out.rodata, mut data_offsets)!
	w.copy_data_ranges(reachable.data, .data, mut out.data_data, mut data_offsets)!

	for name in reachable.names {
		symbol_indices[name] = out.add_symbol(name, func_offsets[name],
			macho_tiny_defined_symbol_is_external(name), ObjectFormat.macho.section_index(.text))
	}
	for name in runtime_symbols {
		symbol_indices[name] = out.add_symbol(name, func_offsets[name],
			macho_tiny_defined_symbol_is_external(name), ObjectFormat.macho.section_index(.text))
	}
	mut data_names := data_offsets.keys()
	data_names.sort()
	for name in data_names {
		orig := w.symbol_by_name(name)!
		section := w.symbol_object_section(orig)!
		symbol_indices[name] = out.add_symbol(name, data_offsets[name],
			macho_tiny_defined_symbol_is_external(name), ObjectFormat.macho.section_index(section))
	}
	mut undefined_names := reachable.undefined.keys()
	undefined_names.sort()
	for name in undefined_names {
		symbol_indices[name] = out.add_undefined(name)
	}
	for name in reachable.names {
		range := w.text_range(name)!
		new_base := func_offsets[name]
		for reloc in w.macho.relocs {
			if reloc.addr < int(range.start) || reloc.addr >= int(range.end) {
				continue
			}
			sym := w.reloc_symbol(reloc)!
			sym_idx := symbol_indices[sym.name] or {
				return macos_tiny_not_eligible('symbol `${sym.name}` is not resolved by the tiny object')
			}
			out.add_reloc(int(new_base + u64(reloc.addr - int(range.start))), sym_idx, reloc.type_,
				reloc.pcrel, reloc.length)
		}
	}
	for reloc in runtime_relocs {
		sym_idx := symbol_indices[reloc.symbol] or {
			return macos_tiny_not_eligible('runtime helper symbol `${reloc.symbol}` is not resolved by the tiny object')
		}
		out.add_reloc(reloc.addr, sym_idx, x86_64_reloc_branch, true, 2)
	}

	out.write(path)
}

fn (mut w MachOTinyObjectWriter) collect_reachable() !MachOTinyReachable {
	_ = w.text_range('_main') or { return macos_tiny_not_eligible('missing _main symbol') }
	mut selected := []string{}
	mut seen := map[string]bool{}
	mut queue := ['_main']
	mut selected_data := []MachODataRange{}
	mut undefined := map[string]bool{}
	for queue.len > 0 {
		name := queue[0]
		queue.delete(0)
		if seen[name] {
			continue
		}
		if macho_tiny_is_module_init_symbol(name) {
			return macos_tiny_not_eligible('module init symbol `${name}` is not supported')
		}
		range := w.text_range(name)!
		seen[name] = true
		selected << name
		for reloc in w.macho.relocs {
			if reloc.addr < int(range.start) || reloc.addr >= int(range.end) {
				continue
			}
			validate_macho_tiny_relocation(reloc)!
			sym := w.reloc_symbol(reloc)!
			if sym.sect == ObjectFormat.macho.section_index(.text) {
				if !seen[sym.name] {
					queue << sym.name
				}
			} else if sym.sect == ObjectFormat.macho.section_index(.rodata) {
				w.add_data_range(mut selected_data, .rodata, sym.value)!
			} else if sym.sect == ObjectFormat.macho.section_index(.data) {
				w.add_data_range(mut selected_data, .data, sym.value)!
			} else if sym.sect == 0 && sym.type_ == 0x01 {
				undefined[sym.name] = true
			} else {
				return macos_tiny_not_eligible('relocation to symbol `${sym.name}` in Mach-O section ${sym.sect} is not supported')
			}
		}
	}
	return MachOTinyReachable{
		names:     selected
		data:      selected_data
		undefined: undefined
	}
}

fn validate_macho_tiny_relocation(reloc MachORelocationInfo) ! {
	if !reloc.pcrel || reloc.length != 2 {
		return macos_tiny_not_eligible('non-pcrel or non-32-bit relocation at __text+${reloc.addr} is not supported')
	}
	if reloc.type_ !in [x86_64_reloc_signed, x86_64_reloc_branch, x86_64_reloc_got_load,
		x86_64_reloc_got] {
		return macos_tiny_not_eligible('Mach-O relocation type ${reloc.type_} is not supported')
	}
}

fn (w MachOTinyObjectWriter) text_range(name string) !MachOTextRange {
	ranges := w.text_symbol_ranges()
	for range in ranges {
		if range.name == name {
			return range
		}
	}
	return error('missing text symbol `${name}`')
}

fn (w MachOTinyObjectWriter) text_symbol_ranges() []MachOTextRange {
	mut syms := []MachOSymbol{}
	for sym in w.macho.symbols {
		if sym.name != '' && sym.sect == ObjectFormat.macho.section_index(.text) {
			syms << sym
		}
	}
	syms.sort(a.value < b.value)
	mut ranges := []MachOTextRange{}
	for i, sym in syms {
		mut end := u64(w.macho.text_data.len)
		for j := i + 1; j < syms.len; j++ {
			if syms[j].value > sym.value {
				end = syms[j].value
				break
			}
		}
		if end > sym.value {
			ranges << MachOTextRange{
				name:  sym.name
				start: sym.value
				end:   end
			}
		}
	}
	return ranges
}

fn (w MachOTinyObjectWriter) reloc_symbol(reloc MachORelocationInfo) !MachOSymbol {
	if reloc.sym_idx < 0 || reloc.sym_idx >= w.macho.symbols.len {
		return error('macOS tiny object relocation references invalid symbol index ${reloc.sym_idx}')
	}
	return w.macho.symbols[reloc.sym_idx]
}

fn (w MachOTinyObjectWriter) symbol_by_name(name string) !MachOSymbol {
	idx := w.macho.sym_by_name[name] or { return error('missing symbol `${name}`') }
	if idx < 0 || idx >= w.macho.symbols.len {
		return error('invalid symbol index ${idx} for `${name}`')
	}
	return w.macho.symbols[idx]
}

fn (w MachOTinyObjectWriter) symbol_object_section(sym MachOSymbol) !ObjectSection {
	if sym.sect == ObjectFormat.macho.section_index(.rodata) {
		return .rodata
	}
	if sym.sect == ObjectFormat.macho.section_index(.data) {
		return .data
	}
	if sym.sect == ObjectFormat.macho.section_index(.text) {
		return .text
	}
	return error('symbol `${sym.name}` is not in a known Mach-O section')
}

fn (mut w MachOTinyObjectWriter) add_data_range(mut ranges []MachODataRange, section ObjectSection, start u64) ! {
	end := w.data_symbol_range_end(section, start)!
	for range in ranges {
		if range.section == section && range.start == start && range.end == end {
			return
		}
	}
	ranges << MachODataRange{
		section: section
		start:   start
		end:     end
	}
}

fn (w MachOTinyObjectWriter) data_symbol_range_end(section ObjectSection, start u64) !u64 {
	section_idx := ObjectFormat.macho.section_index(section)
	section_len := match section {
		.rodata { u64(w.macho.rodata.len) }
		.data { u64(w.macho.data_data.len) }
		else { u64(0) }
	}

	mut end := section_len
	for sym in w.macho.symbols {
		if sym.sect == section_idx && sym.value > start && sym.value < end {
			end = sym.value
		}
	}
	if end < start {
		return error('invalid Mach-O data symbol range')
	}
	return end
}

fn (w MachOTinyObjectWriter) copy_data_ranges(ranges []MachODataRange, section ObjectSection, mut out []u8, mut offsets map[string]u64) ! {
	for dr in ranges {
		if dr.section != section {
			continue
		}
		align := int(w.data_section_alignment(section))
		for align > 1 && out.len % align != int(dr.start % u64(align)) {
			out << u8(0)
		}
		off := u64(out.len)
		section_idx := ObjectFormat.macho.section_index(section)
		for sym in w.macho.symbols {
			if sym.sect == section_idx && sym.value == dr.start {
				offsets[sym.name] = off
			}
		}
		match section {
			.rodata {
				out << w.macho.rodata[int(dr.start)..int(dr.end)]
			}
			.data {
				out << w.macho.data_data[int(dr.start)..int(dr.end)]
			}
			else {
				return error('macOS tiny object cannot copy ${section} as data')
			}
		}
	}
}

fn (w MachOTinyObjectWriter) data_section_alignment(section ObjectSection) u64 {
	return match section {
		.data { u64(8) }
		.rodata { u64(4) }
		else { u64(1) }
	}
}

fn macho_tiny_defined_symbol_is_external(name string) bool {
	return name == '_main' || name == macos_tiny_builtin_string_plus_symbol
}

fn macho_tiny_add_runtime_helpers(mut out MachOObject, mut reachable MachOTinyReachable, mut func_offsets map[string]u64, mut runtime_symbols []string, mut runtime_relocs []MachOTinyRuntimeReloc) {
	if reachable.undefined[macos_tiny_builtin_string_plus_symbol] {
		reachable.undefined.delete(macos_tiny_builtin_string_plus_symbol)
		reachable.undefined[macos_tiny_malloc_symbol] = true
		reachable.undefined[macos_tiny_exit_symbol] = true
		func_offsets[macos_tiny_builtin_string_plus_symbol] = u64(out.text_data.len)
		runtime_symbols << macos_tiny_builtin_string_plus_symbol
		macho_tiny_emit_string_plus(mut out.text_data, mut runtime_relocs)
	}
}

fn macho_tiny_emit_string_plus(mut text []u8, mut runtime_relocs []MachOTinyRuntimeReloc) {
	text << [
		u8(0x57), // push rdi, first string ptr
		0x56, // push rsi, first string len
		0x52, // push rdx, second string ptr
		0x51, // push rcx, second string len
		0x48,
		0x83,
		0xec,
		0x08, // sub rsp, 8, align before libSystem calls
		0x44,
		0x8b,
		0x44,
		0x24,
		0x18, // mov r8d, [rsp+24]
		0x44,
		0x03,
		0x44,
		0x24,
		0x08, // add r8d, [rsp+8]
	]
	len_overflow := macho_tiny_emit_jcc32(mut text, 0x82) // jc fail
	text << [
		u8(0x4d),
		0x89,
		0xc1, // mov r9, r8
		0x49,
		0x83,
		0xc1,
		0x01, // add r9, 1
	]
	alloc_overflow := macho_tiny_emit_jcc32(mut text, 0x82) // jc fail
	text << [
		u8(0x4c),
		0x89,
		0xcf, // mov rdi, r9
	]
	macho_tiny_emit_call_reloc(mut text, mut runtime_relocs, macos_tiny_malloc_symbol)
	text << [
		u8(0x48),
		0x85,
		0xc0, // test rax, rax
	]
	malloc_ok := macho_tiny_emit_jcc32(mut text, 0x85) // jne ok
	fail_start := text.len
	text << [
		u8(0xbf),
		0x01,
		0x00,
		0x00,
		0x00, // mov edi, 1
	]
	macho_tiny_emit_call_reloc(mut text, mut runtime_relocs, macos_tiny_exit_symbol)
	text << [u8(0x0f), 0x0b] // ud2
	ok_start := text.len
	macho_tiny_patch_rel32_local(mut text, len_overflow, fail_start)
	macho_tiny_patch_rel32_local(mut text, alloc_overflow, fail_start)
	macho_tiny_patch_rel32_local(mut text, malloc_ok, ok_start)

	text << [
		u8(0x49),
		0x89,
		0xc2, // mov r10, rax
		0x49,
		0x89,
		0xc0, // mov r8, rax
		0x48,
		0x8b,
		0x74,
		0x24,
		0x20, // mov rsi, [rsp+32]
		0x8b,
		0x4c,
		0x24,
		0x18, // mov ecx, [rsp+24]
		0x48,
		0x85,
		0xc9, // test rcx, rcx
	]
	copy_a_done := macho_tiny_emit_jcc32(mut text, 0x84) // jz done
	copy_a_loop := text.len
	text << [
		u8(0x8a),
		0x16, // mov dl, [rsi]
		0x41,
		0x88,
		0x10, // mov [r8], dl
		0x48,
		0xff,
		0xc6, // inc rsi
		0x49,
		0xff,
		0xc0, // inc r8
		0x48,
		0xff,
		0xc9, // dec rcx
	]
	copy_a_continue := macho_tiny_emit_jcc32(mut text, 0x85) // jne loop
	copy_a_done_target := text.len
	macho_tiny_patch_rel32_local(mut text, copy_a_done, copy_a_done_target)
	macho_tiny_patch_rel32_local(mut text, copy_a_continue, copy_a_loop)

	text << [
		u8(0x48),
		0x8b,
		0x74,
		0x24,
		0x10, // mov rsi, [rsp+16]
		0x8b,
		0x4c,
		0x24,
		0x08, // mov ecx, [rsp+8]
		0x48,
		0x85,
		0xc9, // test rcx, rcx
	]
	copy_b_done := macho_tiny_emit_jcc32(mut text, 0x84) // jz done
	copy_b_loop := text.len
	text << [
		u8(0x8a),
		0x16, // mov dl, [rsi]
		0x41,
		0x88,
		0x10, // mov [r8], dl
		0x48,
		0xff,
		0xc6, // inc rsi
		0x49,
		0xff,
		0xc0, // inc r8
		0x48,
		0xff,
		0xc9, // dec rcx
	]
	copy_b_continue := macho_tiny_emit_jcc32(mut text, 0x85) // jne loop
	copy_b_done_target := text.len
	macho_tiny_patch_rel32_local(mut text, copy_b_done, copy_b_done_target)
	macho_tiny_patch_rel32_local(mut text, copy_b_continue, copy_b_loop)

	text << [
		u8(0x41),
		0xc6,
		0x00,
		0x00, // mov byte ptr [r8], 0
		0x8b,
		0x44,
		0x24,
		0x18, // mov eax, [rsp+24]
		0x03,
		0x44,
		0x24,
		0x08, // add eax, [rsp+8]
		0x48,
		0x89,
		0xc2, // mov rdx, rax
		0x4c,
		0x89,
		0xd0, // mov rax, r10
		0x48,
		0x83,
		0xc4,
		0x28, // add rsp, 40
		0xc3, // ret
	]
}

fn macho_tiny_emit_call_reloc(mut text []u8, mut runtime_relocs []MachOTinyRuntimeReloc, symbol string) {
	text << u8(0xe8)
	field_off := text.len
	text << [u8(0), 0, 0, 0]
	runtime_relocs << MachOTinyRuntimeReloc{
		addr:   field_off
		symbol: symbol
	}
}

fn macho_tiny_emit_jcc32(mut text []u8, opcode u8) int {
	text << [u8(0x0f), opcode]
	field_off := text.len
	text << [u8(0), 0, 0, 0]
	return field_off
}

fn macho_tiny_patch_rel32_local(mut text []u8, field_off int, target_off int) {
	disp := i64(target_off) - i64(field_off + 4)
	binary.little_endian_put_u32(mut text[field_off..field_off + 4], u32(i32(disp)))
}

fn macho_tiny_is_module_init_symbol(name string) bool {
	return name.ends_with('__init') && name != '_main'
}

fn macos_tiny_not_eligible(message string) IError {
	return error(macos_tiny_not_eligible_prefix + message)
}
