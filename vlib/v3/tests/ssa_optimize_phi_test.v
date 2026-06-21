import v3.ssa
import v3.ssa.optimize

fn phi_instr(m &ssa.Module, val_id int) ssa.Instruction {
	assert val_id > 0 && val_id < m.values.len
	idx := m.values[val_id].index
	assert idx >= 0 && idx < m.instrs.len
	return m.instrs[idx]
}

fn phi_last_instr(m &ssa.Module, blk_id int) ssa.Instruction {
	assert blk_id >= 0 && blk_id < m.blocks.len
	assert m.blocks[blk_id].instrs.len > 0
	return phi_instr(m, m.blocks[blk_id].instrs.last())
}

fn phi_has_live_phi(m &ssa.Module) bool {
	for val in m.values {
		if val.kind == .instruction && val.index >= 0 && val.index < m.instrs.len {
			if m.instrs[val.index].op == .phi {
				return true
			}
		}
	}
	return false
}

fn phi_block_has_op(m &ssa.Module, blk_id int, op ssa.OpCode) bool {
	for val_id in m.blocks[blk_id].instrs {
		if val_id > 0 && val_id < m.values.len && m.values[val_id].kind == .instruction {
			if m.instrs[m.values[val_id].index].op == op {
				return true
			}
		}
	}
	return false
}

fn phi_block_count_op(m &ssa.Module, blk_id int, op ssa.OpCode) int {
	mut count := 0
	for val_id in m.blocks[blk_id].instrs {
		if val_id > 0 && val_id < m.values.len && m.values[val_id].kind == .instruction {
			if m.instrs[m.values[val_id].index].op == op {
				count++
			}
		}
	}
	return count
}

fn phi_block_has_assign_dest(m &ssa.Module, blk_id int, dest int) bool {
	for val_id in m.blocks[blk_id].instrs {
		if val_id <= 0 || val_id >= m.values.len || m.values[val_id].kind != .instruction {
			continue
		}
		instr := m.instrs[m.values[val_id].index]
		if instr.op == .assign && instr.operands.len == 2 && int(instr.operands[0]) == dest {
			return true
		}
	}
	return false
}

fn test_phi_prune_removes_operand_for_non_predecessor() {
	mut m := ssa.Module.new()
	i1_t := m.type_store.get_int(1)
	i64_t := m.type_store.get_int(64)
	void_t := ssa.TypeID(0)
	func_id := m.new_function('main', i64_t)
	entry := m.add_block(func_id, 'entry')
	left := m.add_block(func_id, 'left')
	right := m.add_block(func_id, 'right')
	merge := m.add_block(func_id, 'merge')
	stale := m.add_block(func_id, 'stale')
	cond := m.add_value(.argument, i1_t, 'cond', 0)
	m.func_add_param(func_id, cond)
	one := m.get_or_add_const(i64_t, '1')
	two := m.get_or_add_const(i64_t, '2')
	three := m.get_or_add_const(i64_t, '3')

	m.add_instr(.br, entry, void_t, [cond, ssa.ValueID(left), ssa.ValueID(right)])
	m.add_instr(.jmp, left, void_t, [ssa.ValueID(merge)])
	m.add_instr(.jmp, right, void_t, [ssa.ValueID(merge)])
	m.add_instr(.ret, stale, void_t, [])
	phi := m.add_instr(.phi, merge, i64_t, [one, ssa.ValueID(left), two, ssa.ValueID(right), three,
		ssa.ValueID(stale)])
	m.add_instr(.ret, merge, void_t, [phi])

	optimize.prune_phi_operands(mut m)

	phi_after := phi_instr(m, phi)
	assert phi_after.op == .phi
	assert phi_after.operands.len == 4
	assert int(phi_after.operands[1]) != stale
	assert int(phi_after.operands[3]) != stale
}

fn test_phi_elimination_splits_branch_phi_edge_and_removes_phis() {
	mut m := ssa.Module.new()
	i1_t := m.type_store.get_int(1)
	i64_t := m.type_store.get_int(64)
	void_t := ssa.TypeID(0)
	func_id := m.new_function('main', i64_t)
	entry := m.add_block(func_id, 'entry')
	alt := m.add_block(func_id, 'alt')
	other := m.add_block(func_id, 'other')
	merge := m.add_block(func_id, 'merge')
	cond := m.add_value(.argument, i1_t, 'cond', 0)
	m.func_add_param(func_id, cond)
	one := m.get_or_add_const(i64_t, '1')
	two := m.get_or_add_const(i64_t, '2')

	m.add_instr(.br, entry, void_t, [cond, ssa.ValueID(merge), ssa.ValueID(alt)])
	m.add_instr(.ret, alt, void_t, [one])
	m.add_instr(.jmp, other, void_t, [ssa.ValueID(merge)])
	phi := m.add_instr(.phi, merge, i64_t, [one, ssa.ValueID(entry), two, ssa.ValueID(other)])
	m.add_instr(.ret, merge, void_t, [phi])

	optimize.eliminate_phi_nodes(mut m)

	entry_term := phi_last_instr(m, entry)
	assert entry_term.op == .br
	split_blk := int(entry_term.operands[1])
	assert split_blk != merge
	assert phi_last_instr(m, split_blk).op == .jmp
	assert int(phi_last_instr(m, split_blk).operands[0]) == merge
	assert phi_block_has_assign_dest(m, split_blk, phi)
	assert !phi_block_has_op(m, entry, .assign)
	assert !phi_has_live_phi(m)
}

fn test_phi_elimination_splits_switch_phi_edge() {
	mut m := ssa.Module.new()
	i64_t := m.type_store.get_int(64)
	void_t := ssa.TypeID(0)
	func_id := m.new_function('main', i64_t)
	entry := m.add_block(func_id, 'entry')
	alt := m.add_block(func_id, 'alt')
	other := m.add_block(func_id, 'other')
	merge := m.add_block(func_id, 'merge')
	subject := m.add_value(.argument, i64_t, 'subject', 0)
	m.func_add_param(func_id, subject)
	one := m.get_or_add_const(i64_t, '1')
	two := m.get_or_add_const(i64_t, '2')
	case_val := m.get_or_add_const(i64_t, '7')

	m.add_instr(.switch_, entry, void_t, [subject, ssa.ValueID(merge), case_val, ssa.ValueID(alt)])
	m.add_instr(.ret, alt, void_t, [one])
	m.add_instr(.jmp, other, void_t, [ssa.ValueID(merge)])
	phi := m.add_instr(.phi, merge, i64_t, [one, ssa.ValueID(entry), two, ssa.ValueID(other)])
	m.add_instr(.ret, merge, void_t, [phi])

	optimize.eliminate_phi_nodes(mut m)

	entry_term := phi_last_instr(m, entry)
	assert entry_term.op == .switch_
	split_blk := int(entry_term.operands[1])
	assert split_blk != merge
	assert phi_last_instr(m, split_blk).op == .jmp
	assert int(phi_last_instr(m, split_blk).operands[0]) == merge
	assert phi_block_has_assign_dest(m, split_blk, phi)
	assert !phi_has_live_phi(m)
}

fn test_phi_elimination_resolves_parallel_copy_cycle() {
	mut m := ssa.Module.new()
	i64_t := m.type_store.get_int(64)
	void_t := ssa.TypeID(0)
	func_id := m.new_function('main', i64_t)
	pred1 := m.add_block(func_id, 'pred1')
	pred2 := m.add_block(func_id, 'pred2')
	merge := m.add_block(func_id, 'merge')
	one := m.get_or_add_const(i64_t, '1')
	two := m.get_or_add_const(i64_t, '2')

	m.add_instr(.jmp, pred1, void_t, [ssa.ValueID(merge)])
	m.add_instr(.jmp, pred2, void_t, [ssa.ValueID(merge)])
	phi_a := m.add_instr(.phi, merge, i64_t, []ssa.ValueID{})
	phi_b := m.add_instr(.phi, merge, i64_t, [phi_a, ssa.ValueID(pred1), two, ssa.ValueID(pred2)])
	m.append_phi_operands(m.values[phi_a].index, phi_b, pred1)
	m.append_phi_operands(m.values[phi_a].index, one, pred2)
	m.add_instr(.ret, merge, void_t, [phi_a])

	optimize.eliminate_phi_nodes(mut m)

	assert phi_block_count_op(m, pred1, .bitcast) >= 1
	assert phi_block_count_op(m, pred1, .assign) == 2
	assert !phi_has_live_phi(m)
}

fn test_constant_fold_ignores_raw_block_slots_in_switch_and_phi() {
	mut m := ssa.Module.new()
	i64_t := m.type_store.get_int(64)
	void_t := ssa.TypeID(0)
	func_id := m.new_function('main', i64_t)
	entry := m.add_block(func_id, 'entry')
	unused_a := m.add_block(func_id, 'unused_a')
	unused_b := m.add_block(func_id, 'unused_b')
	switch_default := m.add_block(func_id, 'switch_default')
	case_block := m.add_block(func_id, 'case_block')
	merge := m.add_block(func_id, 'merge')
	one := m.get_or_add_const(i64_t, '1')
	zero := m.get_or_add_const(i64_t, '0')
	cond := m.add_instr(.add, entry, i64_t, [one, zero])
	case_val := m.get_or_add_const(i64_t, '7')

	assert int(cond) == switch_default

	m.add_instr(.switch_, entry, void_t, [cond, ssa.ValueID(switch_default), case_val,
		ssa.ValueID(case_block)])
	m.add_instr(.ret, unused_a, void_t, [one])
	m.add_instr(.ret, unused_b, void_t, [zero])
	m.add_instr(.jmp, switch_default, void_t, [ssa.ValueID(merge)])
	m.add_instr(.ret, case_block, void_t, [case_val])
	phi := m.add_instr(.phi, merge, i64_t, [cond, ssa.ValueID(switch_default)])
	m.add_instr(.ret, merge, void_t, [phi])

	optimize.optimize(mut m)

	switch_instr := phi_last_instr(m, entry)
	assert switch_instr.op == .switch_
	assert int(switch_instr.operands[1]) == switch_default
	assert int(switch_instr.operands[0]) == one
	phi_instr_after := phi_instr(m, phi)
	assert phi_instr_after.op == .phi || phi_instr_after.op == .bitcast
}
