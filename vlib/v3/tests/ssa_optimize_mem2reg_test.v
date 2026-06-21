import v3.ssa
import v3.ssa.optimize

fn mem2reg_instr(m &ssa.Module, val_id int) ssa.Instruction {
	assert val_id > 0 && val_id < m.values.len
	idx := m.values[val_id].index
	assert idx >= 0 && idx < m.instrs.len
	return m.instrs[idx]
}

fn mem2reg_run(mut m ssa.Module) {
	cfg := optimize.cfg_data_from_module(m)
	dom := optimize.compute_dominators(mut m, &cfg)
	optimize.promote_memory_to_register(mut m, dom, &cfg)
}

fn test_mem2reg_promotes_scalar_alloca_across_diamond() {
	mut m := ssa.Module.new()
	i1_t := m.type_store.get_int(1)
	i64_t := m.type_store.get_int(64)
	ptr_i64_t := m.type_store.get_ptr(i64_t)
	void_t := ssa.TypeID(0)
	func_id := m.new_function('main', i64_t)
	entry := m.add_block(func_id, 'entry')
	then_blk := m.add_block(func_id, 'then')
	else_blk := m.add_block(func_id, 'else')
	merge := m.add_block(func_id, 'merge')
	cond := m.add_value(.argument, i1_t, 'cond', 0)
	m.func_add_param(func_id, cond)
	one := m.get_or_add_const(i64_t, '1')
	two := m.get_or_add_const(i64_t, '2')

	alloca := m.add_instr(.alloca, entry, ptr_i64_t, [])
	m.add_instr(.br, entry, void_t, [cond, ssa.ValueID(then_blk), ssa.ValueID(else_blk)])
	store_then := m.add_instr(.store, then_blk, void_t, [one, alloca])
	m.add_instr(.jmp, then_blk, void_t, [ssa.ValueID(merge)])
	store_else := m.add_instr(.store, else_blk, void_t, [two, alloca])
	m.add_instr(.jmp, else_blk, void_t, [ssa.ValueID(merge)])
	load := m.add_instr(.load, merge, i64_t, [alloca])
	ret := m.add_instr(.ret, merge, void_t, [load])

	mem2reg_run(mut m)

	assert mem2reg_instr(m, alloca).op != .alloca
	assert mem2reg_instr(m, store_then).op != .store
	assert mem2reg_instr(m, store_else).op != .store
	assert mem2reg_instr(m, load).op != .load
	ret_instr := mem2reg_instr(m, ret)
	result := int(ret_instr.operands[0])
	result_instr := mem2reg_instr(m, result)
	assert result_instr.op == .phi
	assert result_instr.operands.len == 4
	assert int(result_instr.operands[1]) in [then_blk, else_blk]
	assert int(result_instr.operands[3]) in [then_blk, else_blk]
}

fn test_mem2reg_keeps_escaped_aggregate_gep_and_call_allocas() {
	mut m := ssa.Module.new()
	i64_t := m.type_store.get_int(64)
	ptr_i64_t := m.type_store.get_ptr(i64_t)
	ptr_ptr_i64_t := m.type_store.get_ptr(ptr_i64_t)
	struct_t := m.type_store.register(ssa.Type{
		kind:   .struct_t
		fields: [i64_t]
	})
	ptr_struct_t := m.type_store.get_ptr(struct_t)
	void_t := ssa.TypeID(0)
	func_id := m.new_function('main', i64_t)
	entry := m.add_block(func_id, 'entry')
	zero := m.get_or_add_const(i64_t, '0')

	escaped_alloca := m.add_instr(.alloca, entry, ptr_i64_t, [])
	escape_sink := m.add_instr(.alloca, entry, ptr_ptr_i64_t, [])
	m.add_instr(.store, entry, void_t, [escaped_alloca, escape_sink])

	aggregate_alloca := m.add_instr(.alloca, entry, ptr_struct_t, [])
	aggregate_value := m.get_or_add_const(struct_t, 'undef')
	m.add_instr(.store, entry, void_t, [aggregate_value, aggregate_alloca])
	m.add_instr(.load, entry, struct_t, [aggregate_alloca])

	gep_alloca := m.add_instr(.alloca, entry, ptr_i64_t, [])
	gep := m.add_instr(.get_element_ptr, entry, ptr_i64_t, [gep_alloca, zero])
	m.add_instr(.load, entry, i64_t, [gep])

	call_alloca := m.add_instr(.alloca, entry, ptr_i64_t, [])
	callee := m.add_value(.func_ref, ssa.TypeID(0), 'escape', 0)
	m.add_instr(.call, entry, void_t, [callee, call_alloca])
	m.add_instr(.ret, entry, void_t, [zero])

	mem2reg_run(mut m)

	assert mem2reg_instr(m, escaped_alloca).op == .alloca
	assert mem2reg_instr(m, aggregate_alloca).op == .alloca
	assert mem2reg_instr(m, gep_alloca).op == .alloca
	assert mem2reg_instr(m, call_alloca).op == .alloca
}
