module c

import v3.flat
import v3.types

fn (mut g FlatGen) gen_struct_init(id flat.NodeId, node flat.Node) {
	name := g.struct_init_c_type_name_for_node(id, node)
	if node.children_count == 0 && g.is_scalar_zero_init_type(node.value, name) {
		g.write(g.scalar_zero_init(name))
		return
	}
	g.write('(${name}){')
	mut set_fields := map[string]bool{}
	mut has_field := false
	sname := g.struct_init_struct_name_for_node(id, node)
	for i in 0 .. node.children_count {
		field := g.a.child_node(&node, i)
		if has_field {
			g.write(', ')
		}
		g.gen_struct_init_field(field, sname, i, mut set_fields)
		has_field = true
	}
	if sname in g.tc.structs {
		has_field = g.gen_struct_default_fields(sname, mut set_fields, has_field)
		for f in g.tc.structs[sname] {
			if f.name in set_fields {
				continue
			}
			if f.typ is types.Map {
				if has_field {
					g.write(', ')
				}
				g.write('.${c_name(f.name)} = ')
				g.write_new_map(f.typ.key_type, f.typ.value_type)
				has_field = true
			} else if f.typ is types.Array {
				c_elem := g.tc.c_type(f.typ.elem_type)
				if has_field {
					g.write(', ')
				}
				g.write('.${c_name(f.name)} = array_new(sizeof(${c_elem}), 0, 0)')
				has_field = true
			}
		}
	}
	g.write('}')
}

fn (mut g FlatGen) gen_heap_struct_init(id flat.NodeId, node flat.Node) {
	name := g.struct_init_c_type_name_for_node(id, node)
	g.write('(${name}*)memdup(&(${name}){')
	mut set_fields := map[string]bool{}
	mut has_field := false
	sname := g.struct_init_struct_name_for_node(id, node)
	for i in 0 .. node.children_count {
		field := g.a.child_node(&node, i)
		if has_field {
			g.write(', ')
		}
		g.gen_struct_init_field(field, sname, i, mut set_fields)
		has_field = true
	}
	if sname in g.tc.structs {
		has_field = g.gen_struct_default_fields(sname, mut set_fields, has_field)
		for f in g.tc.structs[sname] {
			if f.name in set_fields {
				continue
			}
			if f.typ is types.Map {
				if has_field {
					g.write(', ')
				}
				g.write('.${c_name(f.name)} = ')
				g.write_new_map(f.typ.key_type, f.typ.value_type)
				has_field = true
			} else if f.typ is types.Array {
				c_elem := g.tc.c_type(f.typ.elem_type)
				if has_field {
					g.write(', ')
				}
				g.write('.${c_name(f.name)} = array_new(sizeof(${c_elem}), 0, 0)')
				has_field = true
			}
		}
	}
	g.write('}, sizeof(${name}))')
}

fn (mut g FlatGen) gen_struct_init_field(field flat.Node, struct_name string, index int, mut set_fields map[string]bool) {
	if field.value.len > 0 {
		g.write('.${c_name(field.value)} = ')
		if field_type := g.named_struct_field_type(struct_name, field.value) {
			g.gen_struct_init_field_expr(g.a.child(field, 0), field_type)
		} else {
			g.gen_expr(g.a.child(field, 0))
		}
		set_fields[field.value] = true
		return
	}
	field_type, field_name := g.positional_struct_field(struct_name, index)
	g.gen_struct_init_field_expr(g.a.child(field, 0), field_type)
	if field_name.len > 0 {
		set_fields[field_name] = true
	}
}

fn (mut g FlatGen) gen_struct_init_field_expr(id flat.NodeId, field_type types.Type) {
	old_expected_enum := g.expected_enum
	if enum_name := expected_enum_name(field_type) {
		g.expected_enum = enum_name
	}
	node := g.a.nodes[int(id)]
	if node.kind == .array_literal {
		if fixed := array_fixed_type(field_type) {
			g.gen_fixed_array_literal_value(node, fixed)
			g.expected_enum = old_expected_enum
			return
		}
	}
	g.gen_expr_with_expected_type(id, field_type)
	g.expected_enum = old_expected_enum
}

fn (mut g FlatGen) gen_struct_default_fields(type_name string, mut set_fields map[string]bool, has_field bool) bool {
	mut has := has_field
	info := g.find_struct_decl(type_name) or { return has }
	old_module := g.tc.cur_module
	g.tc.cur_module = info.module
	for i in 0 .. info.node.children_count {
		field := g.a.child_node(&info.node, i)
		if field.kind != .field_decl || field.children_count == 0 || field.value in set_fields {
			continue
		}
		if has {
			g.write(', ')
		}
		g.write('.${c_name(field.value)} = ')
		g.gen_expr(g.a.child(field, 0))
		set_fields[field.value] = true
		has = true
	}
	g.tc.cur_module = old_module
	return has
}

fn (mut g FlatGen) gen_default_value_for_type(typ types.Type) {
	raw_typ := typ
	if typ is types.Struct && !typ.name.starts_with('C.') {
		ct := g.tc.c_type(raw_typ)
		g.write('(${ct}){')
		mut set_fields := map[string]bool{}
		mut has_field := g.gen_struct_default_fields(typ.name, mut set_fields, false)
		mut sname := g.tc.qualify_name(typ.name)
		if typ.name in g.tc.structs {
			sname = typ.name
		}
		if sname in g.tc.structs {
			for f in g.tc.structs[sname] {
				if f.name in set_fields {
					continue
				}
				if f.typ is types.Map {
					if has_field {
						g.write(', ')
					}
					g.write('.${c_name(f.name)} = ')
					g.write_new_map(f.typ.key_type, f.typ.value_type)
					has_field = true
				} else if f.typ is types.Array {
					c_elem := g.tc.c_type(f.typ.elem_type)
					if has_field {
						g.write(', ')
					}
					g.write('.${c_name(f.name)} = array_new(sizeof(${c_elem}), 0, 0)')
					has_field = true
				}
			}
		}
		g.write('}')
		return
	}
	ct := g.tc.c_type(typ)
	if g.is_scalar_c_type(ct) {
		g.write(g.scalar_zero_init(ct))
		return
	}
	g.write('(${ct}){0}')
}

// gen_named_struct_arg emits a struct literal for a trailing struct argument
// passed as `key: value` call args (e.g. `draw_text(x, color: red)`).
// `node` is the call node; field_init children are read from `field_start` onward.
fn (mut g FlatGen) gen_named_struct_arg(typ types.Type, node flat.Node, field_start int) bool {
	if typ is types.Alias {
		return g.gen_named_struct_arg(typ.base_type, node, field_start)
	}
	raw_typ := typ
	if typ is types.Struct {
		mut sname := g.tc.qualify_name(typ.name)
		if typ.name in g.tc.structs {
			sname = typ.name
		}
		for i in field_start .. node.children_count {
			field := g.a.child_node(&node, i)
			if field.kind != .field_init || field.children_count == 0 {
				return false
			}
			if _ := g.named_struct_field_type(sname, field.value) {
				// checked below while emitting
			} else {
				return false
			}
		}
		ct := g.tc.c_type(raw_typ)
		g.write('(${ct}){')
		mut set_fields := map[string]bool{}
		mut has_field := false
		for i in field_start .. node.children_count {
			field := g.a.child_node(&node, i)
			if has_field {
				g.write(', ')
			}
			g.write('.${c_name(field.value)} = ')
			field_type := g.named_struct_field_type(sname, field.value) or { return false }
			g.gen_struct_init_field_expr(g.a.child(field, 0), field_type)
			set_fields[field.value] = true
			has_field = true
		}
		has_field = g.gen_struct_default_fields(typ.name, mut set_fields, has_field)
		if sname in g.tc.structs {
			for f in g.tc.structs[sname] {
				if f.name in set_fields {
					continue
				}
				if f.typ is types.Map {
					if has_field {
						g.write(', ')
					}
					g.write('.${c_name(f.name)} = ')
					g.write_new_map(f.typ.key_type, f.typ.value_type)
					has_field = true
				} else if f.typ is types.Array {
					c_elem := g.tc.c_type(f.typ.elem_type)
					if has_field {
						g.write(', ')
					}
					g.write('.${c_name(f.name)} = array_new(sizeof(${c_elem}), 0, 0)')
					has_field = true
				}
			}
		}
		g.write('}')
		return true
	}
	return false
}

fn (g &FlatGen) named_struct_field_type(struct_name string, field_name string) ?types.Type {
	for f in g.tc.structs[struct_name] or { []types.StructField{} } {
		if f.name == field_name {
			return f.typ
		}
	}
	return none
}

fn (g &FlatGen) positional_struct_field(struct_name string, index int) (types.Type, string) {
	fields := g.tc.structs[struct_name] or { return types.Type(types.void_), '' }
	if index < 0 || index >= fields.len {
		return types.Type(types.void_), ''
	}
	field := fields[index]
	return field.typ, field.name
}

fn (g &FlatGen) struct_init_c_type_name_for_node(id flat.NodeId, node flat.Node) string {
	typ := g.struct_init_effective_type(id)
	if typ is types.Void || typ is types.Unknown {
		return g.struct_init_c_type_name(node.value)
	}
	return g.tc.c_type(typ)
}

fn (g &FlatGen) struct_init_struct_name_for_node(id flat.NodeId, node flat.Node) string {
	typ := g.struct_init_effective_type(id)
	if name := struct_name_from_type(typ) {
		return name
	}
	qname := g.tc.qualify_name(node.value)
	if qname in g.tc.structs {
		return qname
	}
	if node.value in g.tc.structs {
		return node.value
	}
	return ''
}

fn (g &FlatGen) struct_init_effective_type(id flat.NodeId) types.Type {
	if _ := struct_name_from_type(g.expected_expr_type) {
		return g.expected_expr_type
	}
	resolved := g.tc.resolve_type(id)
	if _ := struct_name_from_type(resolved) {
		return resolved
	}
	node := g.a.nodes[int(id)]
	if node.kind == .struct_init && node.value.len > 0 {
		return g.tc.parse_type(node.value)
	}
	return resolved
}

fn struct_name_from_type(typ types.Type) ?string {
	if typ is types.Alias {
		return struct_name_from_type(typ.base_type)
	}
	if typ is types.Struct {
		return typ.name
	}
	return none
}

fn expected_enum_name(typ types.Type) ?string {
	if typ is types.Enum {
		return typ.name
	}
	if typ is types.Alias {
		return expected_enum_name(typ.base_type)
	}
	return none
}

fn (g &FlatGen) is_scalar_zero_init_type(type_name string, c_type string) bool {
	if type_name in g.tc.structs || g.tc.qualify_name(type_name) in g.tc.structs {
		return false
	}
	if _ := g.find_struct_decl(type_name) {
		return false
	}
	return g.is_scalar_c_type(c_type)
}

fn (g &FlatGen) is_scalar_c_type(c_type string) bool {
	if c_type.ends_with('*') {
		return true
	}
	return c_type in ['bool', 'char', 'byte', 'u8', 'i8', 'u16', 'i16', 'u32', 'i32', 'u64', 'i64',
		'int', 'isize', 'usize', 'size_t', 'ptrdiff_t', 'float', 'double', 'voidptr']
}

fn (g &FlatGen) scalar_zero_init(c_type string) string {
	if c_type in ['float', 'double'] {
		return '0.0'
	}
	return '0'
}

struct StructDeclInfo {
	node      flat.Node
	module    string
	full_name string
}

fn (g &FlatGen) struct_init_c_type_name(type_name string) string {
	info := g.find_struct_decl(type_name) or { return g.tc.c_type(g.tc.parse_type(type_name)) }
	if info.full_name.starts_with('C.') {
		return g.tc.c_type(g.tc.parse_type(info.full_name))
	}
	return c_name(info.full_name)
}

fn (g &FlatGen) find_struct_decl(type_name string) ?StructDeclInfo {
	short_name := if type_name.contains('.') { type_name.all_after_last('.') } else { type_name }
	preferred_name := if !type_name.contains('.') && g.tc.cur_module.len > 0
		&& g.tc.cur_module != 'main' && g.tc.cur_module != 'builtin' {
		'${g.tc.cur_module}.${type_name}'
	} else {
		type_name
	}
	if info := g.struct_decl_infos[preferred_name] {
		if info.node.value == short_name {
			return info
		}
	}
	if type_name.contains('.') {
		if info := g.struct_decl_infos[type_name] {
			return info
		}
	} else {
		if info := g.struct_decl_short_infos[type_name] {
			return info
		}
	}
	return none
}

fn (mut g FlatGen) gen_return_assoc(node flat.Node) {
	ct := g.tc.c_type(g.tc.parse_type(node.value))
	tmp := g.tmp_name()
	g.write('${ct} ${tmp} = ')
	g.gen_expr(g.a.child(&node, 0))
	g.writeln(';')
	for i in 1 .. node.children_count {
		field := g.a.child_node(&node, i)
		if field.kind == .field_init && field.children_count > 0 {
			g.write('${tmp}.${c_name(field.value)} = ')
			g.gen_expr(g.a.child(field, 0))
			g.writeln(';')
		}
	}
	g.writeln('return ${tmp};')
}

fn (mut g FlatGen) gen_assoc_expr(node flat.Node) {
	ct := g.tc.c_type(g.tc.parse_type(node.value))
	tmp := g.tmp_name()
	g.write('({${ct} ${tmp} = ')
	g.gen_expr(g.a.child(&node, 0))
	g.write(';')
	for i in 1 .. node.children_count {
		field := g.a.child_node(&node, i)
		if field.kind == .field_init && field.children_count > 0 {
			g.write(' ${tmp}.${c_name(field.value)} = ')
			g.gen_expr(g.a.child(field, 0))
			g.write(';')
		}
	}
	g.write(' ${tmp};})')
}

fn (mut g FlatGen) gen_map_init(node flat.Node) {
	map_type := g.tc.parse_type(node.value)
	if map_type is types.Map {
		g.write_new_map(map_type.key_type, map_type.value_type)
	} else {
		g.write('new_map(sizeof(int), sizeof(int), 0, 0, 0, 0)')
	}
}

fn (mut g FlatGen) write_new_map(key_type types.Type, value_type types.Type) {
	c_key := g.tc.c_type(key_type)
	c_val := g.tc.c_type(value_type)
	hash_fn, eq_fn, clone_fn, free_fn := g.map_callback_names(key_type)
	g.write('new_map(sizeof(${c_key}), sizeof(${c_val}), ${hash_fn}, ${eq_fn}, ${clone_fn}, ${free_fn})')
}

fn (g &FlatGen) map_callback_names(key_type types.Type) (string, string, string, string) {
	if key_type is types.String {
		return 'v3_map_hash_string', 'v3_map_eq_string', 'v3_map_clone_string', 'v3_map_free_string'
	}
	c_key := g.tc.c_type(key_type)
	size_suffix := match c_key {
		'u8', 'i8', 'bool', 'char' { '1' }
		'u16', 'i16' { '2' }
		'i64', 'u64', 'isize', 'usize', 'voidptr' { '8' }
		else { '4' }
	}

	return 'v3_map_hash_int_${size_suffix}', 'v3_map_eq_int_${size_suffix}', 'v3_map_clone_int_${size_suffix}', 'v3_map_free_nop'
}

fn (g &FlatGen) skip_builtin_struct(name string) bool {
	_ = g
	if name.starts_with('C.') {
		return true
	}
	return false
}

fn (mut g FlatGen) skip_struct_decl(name string) bool {
	if g.skip_builtin_struct(name) {
		return true
	}
	return g.struct_decl_has_unresolved_generic_types(name)
}

fn (mut g FlatGen) struct_decl_has_unresolved_generic_types(name string) bool {
	info := g.find_struct_decl(name) or { return false }
	old_module := g.tc.cur_module
	g.tc.cur_module = info.module
	has_generics := g.tc.decl_has_unresolved_generic_types(info.node)
	g.tc.cur_module = old_module
	return has_generics
}

fn (mut g FlatGen) struct_decls() {
	for name, _ in g.tc.structs {
		if g.skip_struct_decl(name) {
			continue
		}
		tag := if name in g.tc.unions { 'union' } else { 'struct' }
		g.writeln('typedef ${tag} ${c_name(name)} ${c_name(name)};')
	}
	for name, variants in g.tc.sum_types {
		g.writeln('typedef struct ${c_name(name)} ${c_name(name)};')
		_ = variants
	}
	for name, _ in g.interfaces {
		g.writeln('typedef struct ${c_name(name)} ${c_name(name)};')
	}
	if g.has_builtins {
		g.writeln('typedef array Array;')
	}
	g.writeln('typedef struct Optional { bool ok; int value; } Optional;')
	g.writeln('')
	mut emitted := map[string]bool{}
	mut remaining := map[string]bool{}
	mut remaining_cnames := map[string]bool{}
	mut iface_remaining := map[string]bool{}
	for name, _ in g.interfaces {
		iface_remaining[name] = true
		remaining_cnames[c_name(name)] = true
	}
	for name, _ in g.tc.structs {
		if g.skip_struct_decl(name) {
			continue
		}
		remaining[name] = true
		remaining_cnames[c_name(name)] = true
	}
	mut sum_remaining := map[string]bool{}
	for name, _ in g.tc.sum_types {
		sum_remaining[name] = true
		remaining_cnames[c_name(name)] = true
	}
	for _ in 0 .. 30 {
		if remaining.len == 0 && iface_remaining.len == 0 && sum_remaining.len == 0 {
			break
		}
		mut progress := false
		for name, _ in iface_remaining {
			cn := c_name(name)
			mut can_emit := true
			if cn == 'IError' {
				if 'string' !in emitted && 'string' in remaining_cnames {
					can_emit = false
				}
			}
			if can_emit {
				g.writeln('struct ${cn} {')
				g.writeln('\tint _typ;')
				if cn == 'IError' {
					g.writeln('\tvoid* _object;')
					g.writeln('\tstring message;')
					g.writeln('\tint code;')
				}
				g.writeln('};')
				g.writeln('')
				emitted[cn] = true
				iface_remaining.delete(name)
				remaining_cnames.delete(cn)
				progress = true
			}
		}
		for name, _ in remaining {
			cn := c_name(name)
			if cn in emitted {
				remaining.delete(name)
				remaining_cnames.delete(cn)
				progress = true
				continue
			}
			mut can_emit := true
			if name in g.tc.structs {
				for f in g.tc.structs[name] {
					if f.typ is types.Pointer {
						continue
					}
					if dep := g.optional_payload_dependency_c_name(f.typ) {
						if dep != cn && dep in remaining_cnames {
							can_emit = false
							break
						}
						continue
					}
					mut ct := ''
					if f.typ is types.ArrayFixed {
						struct_module := g.struct_decl_module(name)
						for len_dep in g.fixed_array_len_struct_dependencies_in_module(f.typ,
							struct_module) {
							if len_dep != cn && len_dep in remaining_cnames {
								can_emit = false
								break
							}
						}
						if !can_emit {
							break
						}
						ct = g.tc.c_type(f.typ.elem_type)
					} else {
						ct = g.tc.c_type(f.typ)
					}
					if ct !in emitted && ct != cn && ct in remaining_cnames {
						can_emit = false
						break
					}
				}
			}
			if can_emit {
				g.preseed_optional_typedefs_for_struct(name)
				g.emit_struct(name)
				emitted[cn] = true
				remaining.delete(name)
				remaining_cnames.delete(cn)
				progress = true
			}
		}
		for name, _ in sum_remaining {
			cn := c_name(name)
			mut can_emit_sum := true
			if name in g.tc.sum_types {
				for v in g.tc.sum_types[name] {
					if g.variant_references_sum(v, name) {
						continue
					}
					vt := g.tc.parse_type(v)
					if vt is types.SumType {
						if vt.name in sum_remaining {
							can_emit_sum = false
							break
						}
					}
					vct := g.tc.c_type(vt)
					if vct !in emitted && vct in remaining_cnames {
						can_emit_sum = false
						break
					}
				}
			}
			if can_emit_sum {
				g.emit_sum_type(name)
				emitted[cn] = true
				sum_remaining.delete(name)
				remaining_cnames.delete(cn)
				progress = true
			}
		}
		if !progress {
			break
		}
	}
	for name, _ in iface_remaining {
		cn := c_name(name)
		g.writeln('struct ${cn} {')
		g.writeln('\tint _typ;')
		if cn == 'IError' {
			g.writeln('\tvoid* _object;')
			g.writeln('\tstring message;')
			g.writeln('\tint code;')
		}
		g.writeln('};')
		g.writeln('')
	}
	for name, _ in sum_remaining {
		g.emit_sum_type(name)
	}
	for name, _ in remaining {
		if g.skip_struct_decl(name) {
			continue
		}
		g.preseed_optional_typedefs_for_struct(name)
		g.emit_struct(name)
	}
}

fn (g &FlatGen) struct_decl_module(name string) string {
	if info := g.struct_decl_infos[name] {
		return info.module
	}
	if name.contains('.') {
		return name.all_before_last('.')
	}
	return g.tc.cur_module
}

fn (mut g FlatGen) fixed_array_len_struct_dependencies_in_module(arr types.ArrayFixed, module_name string) []string {
	old_module := g.tc.cur_module
	g.tc.cur_module = module_name
	defer {
		g.tc.cur_module = old_module
	}
	return g.fixed_array_len_struct_dependencies(arr)
}

fn (mut g FlatGen) fixed_array_len_struct_dependencies(arr types.ArrayFixed) []string {
	const_name := g.const_ref_name(arr.len_expr)
	if const_name.len == 0 {
		return []string{}
	}
	val_id := g.const_vals[const_name] or { return []string{} }
	mut deps := []string{}
	g.collect_sizeof_struct_dependencies_in_const_module(const_name, val_id, mut deps, []string{})
	return deps
}

fn (mut g FlatGen) collect_sizeof_struct_dependencies_in_const_module(const_name string, id flat.NodeId, mut deps []string, seen []string) {
	old_module := g.tc.cur_module
	if const_name in g.const_modules {
		g.tc.cur_module = g.const_modules[const_name]
	}
	defer {
		g.tc.cur_module = old_module
	}
	g.collect_sizeof_struct_dependencies(id, mut deps, seen)
}

fn (mut g FlatGen) collect_sizeof_struct_dependencies(id flat.NodeId, mut deps []string, seen []string) {
	if int(id) < 0 || int(id) >= g.a.nodes.len {
		return
	}
	node := g.a.nodes[int(id)]
	if node.kind == .sizeof_expr {
		if dep := g.sizeof_struct_dependency_c_name(g.tc.parse_type(node.value)) {
			if dep !in deps {
				deps << dep
			}
		}
		return
	}
	if node.kind == .ident || node.kind == .selector {
		const_name := g.const_ref_name_from_node(node)
		if const_name.len > 0 && const_name !in seen {
			if dep_id := g.const_vals[const_name] {
				mut next_seen := seen.clone()
				next_seen << const_name
				g.collect_sizeof_struct_dependencies_in_const_module(const_name, dep_id, mut deps,
					next_seen)
			}
		}
	}
	for i in 0 .. node.children_count {
		g.collect_sizeof_struct_dependencies(g.a.child(&node, i), mut deps, seen)
	}
}

fn (g &FlatGen) sizeof_struct_dependency_c_name(t types.Type) ?string {
	if t is types.Alias {
		return g.sizeof_struct_dependency_c_name(t.base_type)
	}
	if t is types.Struct {
		if t.name.starts_with('C.') {
			return none
		}
		return c_name(t.name)
	}
	if t is types.SumType {
		return c_name(t.name)
	}
	if t is types.Interface {
		return c_name(t.name)
	}
	return none
}

fn (mut g FlatGen) type_forward_decls() {
	for name, _ in g.tc.structs {
		if g.skip_struct_decl(name) {
			continue
		}
		tag := if name in g.tc.unions { 'union' } else { 'struct' }
		g.writeln('typedef ${tag} ${c_name(name)} ${c_name(name)};')
	}
	for name, _ in g.tc.sum_types {
		g.writeln('typedef struct ${c_name(name)} ${c_name(name)};')
	}
	for name, _ in g.interfaces {
		g.writeln('typedef struct ${c_name(name)} ${c_name(name)};')
	}
	if g.has_builtins {
		g.writeln('typedef array Array;')
	}
	g.writeln('')
}

fn (mut g FlatGen) emit_struct(name string) {
	if g.skip_struct_decl(name) {
		return
	}
	if name in g.tc.structs {
		fields := g.tc.structs[name]
		tag := if name in g.tc.unions { 'union' } else { 'struct' }
		g.writeln('${tag} ${c_name(name)} {')
		if fields.len == 0 {
			g.writeln('\tint _dummy;')
		}
		for f in fields {
			g.write_struct_field(name, f)
		}
		g.writeln('};')
		g.writeln('')
	}
}

fn (g &FlatGen) optional_payload_dependency_c_name(t types.Type) ?string {
	payload0 := g.optional_payload_type(t) or { return none }
	mut payload := payload0
	if payload0 is types.Alias {
		payload = payload0.base_type
	}
	if payload is types.Pointer || payload is types.Void {
		return none
	}
	if payload is types.Struct {
		return c_name(payload.name)
	}
	if payload is types.SumType {
		return c_name(payload.name)
	}
	if payload is types.Interface {
		return c_name(payload.name)
	}
	return none
}

fn (mut g FlatGen) preseed_optional_typedefs_for_struct(name string) {
	fields := g.tc.structs[name] or { return }
	mut names := []string{}
	for f in fields {
		payload := g.optional_payload_type(f.typ) or { continue }
		if payload is types.Void {
			continue
		}
		names << g.optional_type_name(f.typ)
	}
	g.optional_typedefs_for_names(names)
}

fn (mut g FlatGen) write_struct_field(struct_name string, f types.StructField) {
	mut field_type := f.typ
	if f.typ is types.Alias {
		field_type = f.typ.base_type
	}
	if field_type is types.FnType {
		mask := g.tc.struct_field_fn_const_ptr_param_mask(struct_name, f.name)
		ct := g.resolve_fn_ptr_type(g.fn_ptr_type_key(field_type, mask))
		g.writeln('\t${ct} ${c_name(f.name)};')
	} else if f.typ is types.ArrayFixed {
		c_elem := g.tc.c_type(f.typ.elem_type)
		old_module := g.tc.cur_module
		g.tc.cur_module = g.struct_decl_module(struct_name)
		len_expr := g.fixed_array_len_value(f.typ)
		g.tc.cur_module = old_module
		g.writeln('\t${c_elem} ${c_name(f.name)}[${len_expr}];')
	} else {
		mut ct := g.c_type_for_decl(f.typ)
		if ct.starts_with('fn_ptr:') {
			ct = g.resolve_fn_ptr_type(ct)
		}
		g.writeln('\t${ct} ${c_name(f.name)};')
	}
}

fn (mut g FlatGen) preseed_struct_fn_ptr_types() {
	for struct_name, fields in g.tc.structs {
		for f in fields {
			mut field_type := f.typ
			if f.typ is types.Alias {
				field_type = f.typ.base_type
			}
			if field_type is types.FnType {
				mask := g.tc.struct_field_fn_const_ptr_param_mask(struct_name, f.name)
				g.resolve_fn_ptr_type(g.fn_ptr_type_key(field_type, mask))
			}
		}
	}
}
