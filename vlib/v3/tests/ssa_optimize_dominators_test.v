import v3.ssa
import v3.ssa.optimize

fn contains_block(blocks []ssa.BlockID, needle ssa.BlockID) bool {
	for block in blocks {
		if block == needle {
			return true
		}
	}
	return false
}

fn contains_value(values []ssa.ValueID, needle ssa.ValueID) bool {
	for value in values {
		if value == needle {
			return true
		}
	}
	return false
}

fn add_test_cfg_edge(mut m ssa.Module, from ssa.BlockID, to ssa.BlockID) {
	m.block_add_succ(from, to)
	m.block_add_pred(to, from)
}

fn test_cfg_data_and_dominators_use_raw_block_ids() {
	mut m := ssa.Module.new()
	i64_type := m.type_store.get_int(64)
	func_id := m.new_function('main', i64_type)
	entry := m.add_block(func_id, 'entry')
	then_blk := m.add_block(func_id, 'then')
	else_blk := m.add_block(func_id, 'else')
	join_blk := m.add_block(func_id, 'join')

	cond := m.get_or_add_const(i64_type, '1')
	m.add_instr(.br, entry, ssa.TypeID(0), [cond, ssa.ValueID(then_blk), ssa.ValueID(else_blk)])
	m.add_instr(.jmp, then_blk, ssa.TypeID(0), [ssa.ValueID(join_blk)])
	m.add_instr(.jmp, else_blk, ssa.TypeID(0), [ssa.ValueID(join_blk)])
	ret_val := m.get_or_add_const(i64_type, '7')
	m.add_instr(.ret, join_blk, ssa.TypeID(0), [ret_val])

	cfg := optimize.cfg_data_from_module(m)
	assert cfg.succs[entry] == [then_blk, else_blk]
	assert cfg.succs[then_blk] == [join_blk]
	assert cfg.succs[else_blk] == [join_blk]
	assert cfg.preds[join_blk].len == 2
	assert contains_block(cfg.preds[join_blk], then_blk)
	assert contains_block(cfg.preds[join_blk], else_blk)

	dom := optimize.compute_dominators(mut m, &cfg)
	assert dom.idom[entry] == entry
	assert dom.idom[then_blk] == entry
	assert dom.idom[else_blk] == entry
	assert dom.idom[join_blk] == entry
	assert m.blocks[join_blk].idom == entry
	assert contains_block(m.blocks[entry].dom_tree, then_blk)
	assert contains_block(m.blocks[entry].dom_tree, else_blk)
	assert contains_block(m.blocks[entry].dom_tree, join_blk)
}

fn test_raw_block_slots_are_not_value_uses_or_replacements() {
	mut m := ssa.Module.new()
	i64_type := m.type_store.get_int(64)
	func_id := m.new_function('main', i64_type)
	entry := m.add_block(func_id, 'entry')
	then_blk := m.add_block(func_id, 'then')
	else_blk := m.add_block(func_id, 'else')

	cond := m.get_or_add_const(i64_type, '1')
	block_slot_value := m.get_or_add_const(i64_type, '2')
	br_id := m.add_instr(.br, entry, ssa.TypeID(0),
		[cond, ssa.ValueID(then_blk), ssa.ValueID(else_blk)])
	jmp_id := m.add_instr(.jmp, then_blk, ssa.TypeID(0), [ssa.ValueID(else_blk)])

	assert contains_value(m.values[cond].uses, br_id)
	assert !contains_value(m.values[block_slot_value].uses, br_id)
	assert !contains_value(m.values[block_slot_value].uses, jmp_id)

	replacement := m.get_or_add_const(i64_type, '9')
	mut stale_block_slot_value := m.values[block_slot_value]
	stale_block_slot_value.uses << br_id
	stale_block_slot_value.uses << jmp_id
	m.values[block_slot_value] = stale_block_slot_value
	m.replace_uses(block_slot_value, replacement)

	br_instr := m.instrs[m.values[br_id].index]
	jmp_instr := m.instrs[m.values[jmp_id].index]
	assert br_instr.operands[1] == ssa.ValueID(then_blk)
	assert br_instr.operands[2] == ssa.ValueID(else_blk)
	assert jmp_instr.operands[0] == ssa.ValueID(else_blk)
	assert !contains_value(m.values[replacement].uses, br_id)
	assert !contains_value(m.values[replacement].uses, jmp_id)
}

fn test_phi_raw_predecessor_slots_are_not_value_uses_or_replacements() {
	mut m := ssa.Module.new()
	i64_type := m.type_store.get_int(64)
	func_id := m.new_function('main', i64_type)
	_ := m.add_block(func_id, 'entry')
	_ := m.add_block(func_id, 'filler')
	join_blk := m.add_block(func_id, 'join')
	pred_blk := m.add_block(func_id, 'pred')

	incoming := m.get_or_add_const(i64_type, '1')
	_ := m.get_or_add_const(i64_type, '2')
	block_slot_value := m.get_or_add_const(i64_type, '3')
	phi_id := m.add_instr(.phi, join_blk, i64_type, [incoming, ssa.ValueID(pred_blk)])

	assert contains_value(m.values[incoming].uses, phi_id)
	assert !contains_value(m.values[block_slot_value].uses, phi_id)

	replacement := m.get_or_add_const(i64_type, '12')
	mut stale_block_slot_value := m.values[block_slot_value]
	stale_block_slot_value.uses << phi_id
	m.values[block_slot_value] = stale_block_slot_value
	m.replace_uses(block_slot_value, replacement)

	phi_instr := m.instrs[m.values[phi_id].index]
	assert phi_instr.operands[0] == incoming
	assert phi_instr.operands[1] == ssa.ValueID(pred_blk)
	assert !contains_value(m.values[replacement].uses, phi_id)
}

fn test_switch_raw_block_slots_are_not_value_uses_or_replacements() {
	mut m := ssa.Module.new()
	i64_type := m.type_store.get_int(64)
	func_id := m.new_function('main', i64_type)
	entry := m.add_block(func_id, 'entry')
	default_blk := m.add_block(func_id, 'default')
	_ := m.add_block(func_id, 'unused')
	case_blk := m.add_block(func_id, 'case')

	cond := m.get_or_add_const(i64_type, '1')
	case_value := m.get_or_add_const(i64_type, '2')
	block_slot_value := m.get_or_add_const(i64_type, '3')
	switch_id := m.add_instr(.switch_, entry, ssa.TypeID(0), [cond, ssa.ValueID(default_blk),
		case_value, ssa.ValueID(case_blk)])

	assert contains_value(m.values[cond].uses, switch_id)
	assert contains_value(m.values[case_value].uses, switch_id)
	assert !contains_value(m.values[block_slot_value].uses, switch_id)

	replacement := m.get_or_add_const(i64_type, '11')
	mut stale_block_slot_value := m.values[block_slot_value]
	stale_block_slot_value.uses << switch_id
	m.values[block_slot_value] = stale_block_slot_value
	m.replace_uses(block_slot_value, replacement)

	switch_instr := m.instrs[m.values[switch_id].index]
	assert switch_instr.operands[1] == ssa.ValueID(default_blk)
	assert switch_instr.operands[3] == ssa.ValueID(case_blk)
	assert !contains_value(m.values[replacement].uses, switch_id)
}

fn test_assign_uses_and_replaces_only_source_operand() {
	mut m := ssa.Module.new()
	i64_type := m.type_store.get_int(64)
	func_id := m.new_function('main', i64_type)
	entry := m.add_block(func_id, 'entry')
	dest := m.get_or_add_const(i64_type, '10')
	src := m.get_or_add_const(i64_type, '20')
	assign_id := m.add_instr(.assign, entry, i64_type, [dest, src])

	assert !contains_value(m.values[dest].uses, assign_id)
	assert contains_value(m.values[src].uses, assign_id)

	replacement := m.get_or_add_const(i64_type, '30')
	mut stale_dest := m.values[dest]
	stale_dest.uses << assign_id
	m.values[dest] = stale_dest
	m.replace_uses(dest, replacement)

	mut assign_instr := m.instrs[m.values[assign_id].index]
	assert assign_instr.operands[0] == dest
	assert assign_instr.operands[1] == src
	assert !contains_value(m.values[replacement].uses, assign_id)

	m.replace_uses(src, replacement)
	assign_instr = m.instrs[m.values[assign_id].index]
	assert assign_instr.operands[0] == dest
	assert assign_instr.operands[1] == replacement
	assert !contains_value(m.values[src].uses, assign_id)
	assert contains_value(m.values[replacement].uses, assign_id)
}

fn test_strict_verifier_accepts_phi_with_exact_cfg_predecessors() {
	mut m := ssa.Module.new()
	i64_type := m.type_store.get_int(64)
	func_id := m.new_function('main', i64_type)
	entry := m.add_block(func_id, 'entry')
	then_blk := m.add_block(func_id, 'then')
	else_blk := m.add_block(func_id, 'else')
	join_blk := m.add_block(func_id, 'join')

	cond := m.get_or_add_const(i64_type, '1')
	then_value := m.get_or_add_const(i64_type, '2')
	else_value := m.get_or_add_const(i64_type, '3')
	m.add_instr(.br, entry, ssa.TypeID(0), [cond, ssa.ValueID(then_blk), ssa.ValueID(else_blk)])
	m.add_instr(.jmp, then_blk, ssa.TypeID(0), [ssa.ValueID(join_blk)])
	m.add_instr(.jmp, else_blk, ssa.TypeID(0), [ssa.ValueID(join_blk)])
	phi := m.add_instr(.phi, join_blk, i64_type, [then_value, ssa.ValueID(then_blk), else_value,
		ssa.ValueID(else_blk)])
	m.add_instr(.ret, join_blk, ssa.TypeID(0), [phi])

	add_test_cfg_edge(mut m, entry, then_blk)
	add_test_cfg_edge(mut m, entry, else_blk)
	add_test_cfg_edge(mut m, then_blk, join_blk)
	add_test_cfg_edge(mut m, else_blk, join_blk)

	optimize.verify_and_panic_with_options(m, 'strict phi cfg', optimize.VerifyPanicOptions{})
}

fn test_verify_with_options_allows_rebuildable_use_list_drift() {
	mut m := ssa.Module.new()
	i64_type := m.type_store.get_int(64)
	func_id := m.new_function('main', i64_type)
	entry := m.add_block(func_id, 'entry')
	left := m.get_or_add_const(i64_type, '2')
	right := m.get_or_add_const(i64_type, '3')
	add := m.add_instr(.add, entry, i64_type, [left, right])
	m.add_instr(.ret, entry, ssa.TypeID(0), [add])

	mut left_value := m.values[left]
	left_value.uses = []
	m.values[left] = left_value

	optimize.verify_and_panic_with_options(m, 'lenient use-list check', optimize.VerifyPanicOptions{
		allow_noncritical: true
	})
}
