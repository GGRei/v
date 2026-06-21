module c

import v3.types

fn (mut g FlatGen) optional_type_name(t types.Type) string {
	mut base_type := types.Type(types.void_)
	if t is types.OptionType {
		base_type = t.base_type
	} else if t is types.ResultType {
		base_type = t.base_type
	} else {
		return g.tc.c_type(t)
	}

	if base_type is types.Void {
		return 'Optional'
	}
	inner_ct := g.tc.c_type(base_type)
	safe_name := inner_ct.replace('*', 'ptr').replace(' ', '_')
	opt_name := 'Optional_${safe_name}'
	g.needed_optional_types[opt_name] = inner_ct
	return opt_name
}

fn (mut g FlatGen) optional_value_ct(t types.Type) (string, types.Type) {
	if t is types.OptionType {
		if t.base_type is types.Void {
			return 'int', types.Type(types.int_)
		}
		return g.tc.c_type(t.base_type), t.base_type
	} else if t is types.ResultType {
		if t.base_type is types.Void {
			return 'int', types.Type(types.int_)
		}
		return g.tc.c_type(t.base_type), t.base_type
	}
	return 'int', types.Type(types.int_)
}

fn (mut g FlatGen) c_type_for_decl(t types.Type) string {
	if t is types.OptionType || t is types.ResultType {
		return g.optional_type_name(t)
	}
	return g.tc.c_type(t)
}

fn (g &FlatGen) optional_payload_type(t types.Type) ?types.Type {
	if t is types.OptionType {
		return t.base_type
	}
	if t is types.ResultType {
		return t.base_type
	}
	return none
}

fn (g &FlatGen) can_emit_optional_typedef_before_structs(t types.Type) bool {
	if t is types.Void {
		return false
	}
	if t is types.Pointer {
		return true
	}
	clean0 := types.unwrap_pointer(t)
	mut clean := clean0
	if clean0 is types.Alias {
		clean = clean0.base_type
	}
	return !(clean is types.Struct || clean is types.SumType || clean is types.Interface
		|| clean is types.ArrayFixed)
}

fn (mut g FlatGen) preseed_early_optional_typedefs() {
	mut early_names := []string{}
	for _, fields in g.tc.structs {
		for f in fields {
			payload := g.optional_payload_type(f.typ) or { continue }
			if g.can_emit_optional_typedef_before_structs(payload) {
				early_names << g.optional_type_name(f.typ)
			}
		}
	}
	g.optional_typedefs_for_names(early_names)
}

fn (mut g FlatGen) preseed_fn_ptr_optional_typedefs() {
	mut names := []string{}
	for encoded, _ in g.fn_ptr_types {
		for opt_name in fn_ptr_optional_type_names(encoded) {
			val_type := g.needed_optional_types[opt_name] or { continue }
			if optional_value_c_type_can_emit_before_fn_ptr(val_type) {
				names << opt_name
			}
		}
	}
	g.optional_typedefs_for_names(names)
}

fn fn_ptr_optional_type_names(encoded string) []string {
	mut names := []string{}
	body := if encoded.starts_with('fn_ptr:') { encoded['fn_ptr:'.len..] } else { encoded }
	clean := body.replace('|', ' ').replace(',', ' ').replace('(', ' ').replace(')', ' ')
	for raw in clean.split(' ') {
		mut name := raw.trim_space()
		for name.ends_with('*') {
			name = name[..name.len - 1]
		}
		if name.starts_with('Optional_') && name !in names {
			names << name
		}
	}
	return names
}

fn optional_value_c_type_can_emit_before_fn_ptr(val_type string) bool {
	clean := val_type.trim_space()
	if clean.len == 0 {
		return false
	}
	if clean.ends_with('*') {
		return true
	}
	return clean in ['int', 'i8', 'i16', 'i32', 'i64', 'u8', 'u16', 'u32', 'u64', 'f32', 'f64',
		'bool', 'char', 'string', 'Array', 'map', 'void*', 'size_t', 'ptrdiff_t']
}

fn (mut g FlatGen) optional_typedefs_for_names(names []string) {
	mut emitted := false
	for opt_name in names {
		if opt_name in g.emitted_optional_types {
			continue
		}
		val_type := g.needed_optional_types[opt_name] or { continue }
		g.writeln('typedef struct { bool ok; ${val_type} value; } ${opt_name};')
		g.emitted_optional_types[opt_name] = true
		emitted = true
	}
	if emitted {
		g.writeln('')
	}
}

fn (mut g FlatGen) optional_typedefs() {
	mut emitted := false
	for opt_name, val_type in g.needed_optional_types {
		if opt_name in g.emitted_optional_types {
			continue
		}
		g.writeln('typedef struct { bool ok; ${val_type} value; } ${opt_name};')
		g.emitted_optional_types[opt_name] = true
		emitted = true
	}
	if emitted {
		g.writeln('')
	}
}

fn (mut g FlatGen) enum_decls() {
	mut cur_module := ''
	for node in g.a.nodes {
		match node.kind {
			.file {
				cur_module = ''
			}
			.module_decl {
				cur_module = node.value
			}
			.enum_decl {
				name := if cur_module.len > 0 && cur_module != 'main' && cur_module != 'builtin' {
					'${cur_module}.${node.value}'
				} else {
					node.value
				}
				cn := c_name(name)
				g.writeln('typedef enum {')
				is_flag := node.typ == 'flag'
				mut val := 0
				for i in 0 .. node.children_count {
					f := g.a.child_node(&node, i)
					if f.children_count > 0 {
						ev := g.a.child_node(f, 0)
						if ev.kind == .int_literal {
							val = ev.value.int()
						}
					}
					if is_flag {
						g.writeln('\t${cn}__${f.value} = ${1 << val},')
						val++
					} else {
						g.writeln('\t${cn}__${f.value} = ${val},')
						val++
					}
				}
				g.writeln('} ${cn};')
				g.writeln('')
			}
			else {}
		}
	}
}

fn (mut g FlatGen) type_alias_decls() {
	mut emitted := false
	for name, target in g.tc.type_aliases {
		if target.starts_with('fn_ptr:') || target.starts_with('C.') {
			continue
		}
		if g.has_builtins {
			continue
		}
		alias_type := g.tc.parse_type(target)
		if alias_fn := fn_type_from(alias_type) {
			g.resolve_fn_ptr_type(g.fn_ptr_type_key(alias_fn, []bool{}))
			continue
		}
		ct := g.tc.c_type(alias_type)
		if ct == 'void' || ct == name {
			continue
		}
		g.writeln('typedef ${ct} ${c_name(name)};')
		emitted = true
	}
	if emitted {
		g.writeln('')
	}
}
