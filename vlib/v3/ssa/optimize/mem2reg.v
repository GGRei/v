module optimize

import v3.ssa

struct Mem2RegState {
mut:
	is_promotable []bool
	phi_allocs    [][]int
	phi_values    [][]int
	stacks        [][]int
}

pub fn promote_memory_to_register(mut m ssa.Module, dom DomInfo, cfg &CfgData) {
	n_values := m.values.len
	n_blocks := m.blocks.len
	mut state := Mem2RegState{
		is_promotable: []bool{len: n_values}
		phi_allocs:    [][]int{len: n_blocks}
		phi_values:    [][]int{len: n_blocks}
		stacks:        [][]int{len: n_values}
	}

	for fi in 0 .. m.funcs.len {
		mut promotable := []int{}
		for blk_id in m.funcs[fi].blocks {
			if blk_id < 0 || blk_id >= m.blocks.len {
				continue
			}
			for val_id in m.blocks[blk_id].instrs {
				if val_id <= 0 || val_id >= n_values || m.values[val_id].kind != .instruction {
					continue
				}
				idx := m.values[val_id].index
				if idx < 0 || idx >= m.instrs.len {
					continue
				}
				if m.instrs[idx].op == .alloca && is_promotable_alloca(m, val_id) {
					promotable << val_id
					state.is_promotable[val_id] = true
				}
			}
		}
		if promotable.len == 0 {
			continue
		}

		mut defs := [][]int{len: n_values}
		collect_alloca_defs(m, promotable, mut defs)
		df := dominance_frontier_for_func(m, fi, &dom, cfg)
		insert_mem2reg_phis(mut m, promotable, defs, df, mut state)

		if m.funcs[fi].blocks.len > 0 {
			entry := m.funcs[fi].blocks[0]
			mut visited := []bool{len: m.blocks.len}
			rename_mem2reg_block(mut m, entry, mut state, &dom, cfg, mut visited)
		}
	}
}

fn is_promotable_alloca(m &ssa.Module, alloca_id int) bool {
	if alloca_id <= 0 || alloca_id >= m.values.len || m.values[alloca_id].kind != .instruction {
		return false
	}
	idx := m.values[alloca_id].index
	if idx < 0 || idx >= m.instrs.len {
		return false
	}
	instr := m.instrs[idx]
	if instr.op != .alloca || instr.operands.len != 0 {
		return false
	}
	if !is_scalar_alloca_type(m, alloca_id) {
		return false
	}
	for user_id in m.values[alloca_id].uses {
		if user_id <= 0 || user_id >= m.values.len || m.values[user_id].kind != .instruction {
			return false
		}
		user_idx := m.values[user_id].index
		if user_idx < 0 || user_idx >= m.instrs.len {
			return false
		}
		user := m.instrs[user_idx]
		match user.op {
			.load {
				if user.operands.len != 1 || int(user.operands[0]) != alloca_id {
					return false
				}
			}
			.store {
				if user.operands.len != 2 || int(user.operands[1]) != alloca_id
					|| int(user.operands[0]) == alloca_id {
					return false
				}
			}
			else {
				return false
			}
		}
	}
	return true
}

fn is_scalar_alloca_type(m &ssa.Module, alloca_id int) bool {
	ptr_typ_id := m.values[alloca_id].typ
	if ptr_typ_id <= 0 || ptr_typ_id >= m.type_store.types.len {
		return false
	}
	ptr_typ := m.type_store.types[ptr_typ_id]
	if ptr_typ.kind != .ptr_t {
		return false
	}
	elem_typ_id := ptr_typ.elem_type
	if elem_typ_id <= 0 || elem_typ_id >= m.type_store.types.len {
		return false
	}
	elem_typ := m.type_store.types[elem_typ_id]
	return elem_typ.kind in [.int_t, .float_t, .ptr_t]
}

fn alloca_elem_type(m &ssa.Module, alloca_id int) ssa.TypeID {
	if alloca_id <= 0 || alloca_id >= m.values.len {
		return ssa.TypeID(0)
	}
	ptr_typ_id := m.values[alloca_id].typ
	if ptr_typ_id <= 0 || ptr_typ_id >= m.type_store.types.len {
		return ssa.TypeID(0)
	}
	ptr_typ := m.type_store.types[ptr_typ_id]
	if ptr_typ.kind != .ptr_t {
		return ssa.TypeID(0)
	}
	return ptr_typ.elem_type
}

fn collect_alloca_defs(m &ssa.Module, promotable []int, mut defs [][]int) {
	for alloca_id in promotable {
		for user_id in m.values[alloca_id].uses {
			if user_id <= 0 || user_id >= m.values.len || m.values[user_id].kind != .instruction {
				continue
			}
			user_idx := m.values[user_id].index
			if user_idx < 0 || user_idx >= m.instrs.len {
				continue
			}
			user := m.instrs[user_idx]
			if user.op == .store && user.operands.len == 2 && int(user.operands[1]) == alloca_id {
				append_unique_block(mut defs, alloca_id, user.block)
			}
		}
	}
}

fn dominance_frontier_for_func(m &ssa.Module, func_idx int, dom &DomInfo, cfg &CfgData) [][]int {
	mut df := [][]int{len: m.blocks.len}
	if func_idx < 0 || func_idx >= m.funcs.len {
		return df
	}
	for blk_id in m.funcs[func_idx].blocks {
		if blk_id < 0 || blk_id >= m.blocks.len || blk_id >= cfg.preds.len {
			continue
		}
		if cfg.preds[blk_id].len < 2 {
			continue
		}
		if blk_id >= dom.idom.len {
			continue
		}
		idom := dom.idom[blk_id]
		for pred in cfg.preds[blk_id] {
			mut runner := pred
			for runner >= 0 && runner < m.blocks.len && runner != idom {
				append_unique_block(mut df, runner, blk_id)
				if runner >= dom.idom.len || dom.idom[runner] == runner {
					break
				}
				runner = dom.idom[runner]
			}
		}
	}
	return df
}

fn insert_mem2reg_phis(mut m ssa.Module, promotable []int, defs [][]int, df [][]int, mut state Mem2RegState) {
	for alloca_id in promotable {
		if alloca_id <= 0 || alloca_id >= defs.len {
			continue
		}
		mut worklist := defs[alloca_id].clone()
		mut queued := []bool{len: m.blocks.len}
		mut has_phi := []bool{len: m.blocks.len}
		for blk_id in worklist {
			if blk_id >= 0 && blk_id < queued.len {
				queued[blk_id] = true
			}
		}
		for worklist.len > 0 {
			blk_id := worklist.pop()
			if blk_id < 0 || blk_id >= df.len {
				continue
			}
			for frontier_blk in df[blk_id] {
				if frontier_blk < 0 || frontier_blk >= m.blocks.len || has_phi[frontier_blk] {
					continue
				}
				phi_type := alloca_elem_type(m, alloca_id)
				phi_val := m.add_instr_front(.phi, frontier_blk, phi_type, []ssa.ValueID{})
				array2d_append_int(mut state.phi_allocs, frontier_blk, alloca_id)
				array2d_append_int(mut state.phi_values, frontier_blk, phi_val)
				has_phi[frontier_blk] = true
				if !queued[frontier_blk] {
					queued[frontier_blk] = true
					worklist << frontier_blk
				}
			}
		}
	}
}

fn rename_mem2reg_block(mut m ssa.Module, blk_id int, mut state Mem2RegState, dom &DomInfo, cfg &CfgData, mut visited []bool) {
	if blk_id < 0 || blk_id >= m.blocks.len || blk_id >= visited.len || visited[blk_id] {
		return
	}
	visited[blk_id] = true
	mut pushed_allocs := []int{}

	if blk_id < state.phi_allocs.len {
		for i in 0 .. state.phi_allocs[blk_id].len {
			alloca_id := state.phi_allocs[blk_id][i]
			if i < state.phi_values[blk_id].len {
				push_mem2reg_value(mut state, alloca_id, state.phi_values[blk_id][i])
				pushed_allocs << alloca_id
			}
		}
	}

	instrs := m.blocks[blk_id].instrs.clone()
	for val_id in instrs {
		if val_id <= 0 || val_id >= m.values.len || m.values[val_id].kind != .instruction {
			continue
		}
		idx := m.values[val_id].index
		if idx < 0 || idx >= m.instrs.len {
			continue
		}
		instr := m.instrs[idx]
		match instr.op {
			.alloca {
				if val_id < state.is_promotable.len && state.is_promotable[val_id] {
					mark_instr_dead(mut m, val_id)
				}
			}
			.store {
				if instr.operands.len == 2 {
					ptr := int(instr.operands[1])
					src := int(instr.operands[0])
					if ptr > 0 && ptr < state.is_promotable.len && state.is_promotable[ptr]
						&& src > 0 && src < m.values.len {
						push_mem2reg_value(mut state, ptr, src)
						pushed_allocs << ptr
						mark_instr_dead(mut m, val_id)
					}
				}
			}
			.load {
				if instr.operands.len == 1 {
					ptr := int(instr.operands[0])
					if ptr > 0 && ptr < state.is_promotable.len && state.is_promotable[ptr] {
						replacement := current_mem2reg_value(mut m, ptr, state)
						m.replace_uses(val_id, replacement)
						mark_instr_dead(mut m, val_id)
					}
				}
			}
			else {}
		}
	}

	if blk_id < cfg.succs.len {
		for succ in cfg.succs[blk_id] {
			if succ < 0 || succ >= state.phi_allocs.len {
				continue
			}
			for i in 0 .. state.phi_allocs[succ].len {
				alloca_id := state.phi_allocs[succ][i]
				if i >= state.phi_values[succ].len {
					continue
				}
				incoming := current_mem2reg_value(mut m, alloca_id, state)
				append_phi_operand_raw(mut m, state.phi_values[succ][i], incoming, blk_id)
			}
		}
	}

	if blk_id < dom.dom_tree.len {
		for child in dom.dom_tree[blk_id] {
			rename_mem2reg_block(mut m, child, mut state, dom, cfg, mut visited)
		}
	}

	for i := pushed_allocs.len - 1; i >= 0; i-- {
		pop_mem2reg_value(mut state, pushed_allocs[i])
	}
}

fn push_mem2reg_value(mut state Mem2RegState, alloca_id int, value_id int) {
	if alloca_id <= 0 || alloca_id >= state.stacks.len {
		return
	}
	mut stack := state.stacks[alloca_id]
	stack << value_id
	state.stacks[alloca_id] = stack
}

fn pop_mem2reg_value(mut state Mem2RegState, alloca_id int) {
	if alloca_id <= 0 || alloca_id >= state.stacks.len {
		return
	}
	mut stack := state.stacks[alloca_id]
	if stack.len > 0 {
		stack.pop()
	}
	state.stacks[alloca_id] = stack
}

fn current_mem2reg_value(mut m ssa.Module, alloca_id int, state Mem2RegState) int {
	if alloca_id > 0 && alloca_id < state.stacks.len {
		stack := state.stacks[alloca_id]
		if stack.len > 0 {
			return stack.last()
		}
	}
	return m.get_or_add_const(alloca_elem_type(m, alloca_id), 'undef')
}

fn append_phi_operand_raw(mut m ssa.Module, phi_val int, incoming int, pred_blk int) {
	if phi_val <= 0 || phi_val >= m.values.len || m.values[phi_val].kind != .instruction {
		return
	}
	idx := m.values[phi_val].index
	if idx < 0 || idx >= m.instrs.len || m.instrs[idx].op != .phi {
		return
	}
	mut instr := m.instrs[idx]
	for oi := 1; oi < instr.operands.len; oi += 2 {
		if int(instr.operands[oi]) == pred_blk {
			return
		}
	}
	instr.operands << ssa.ValueID(incoming)
	instr.operands << ssa.ValueID(pred_blk)
	m.instrs[idx] = instr
}

fn append_unique_block(mut arr [][]int, idx int, val int) {
	if idx < 0 || idx >= arr.len {
		return
	}
	if val in arr[idx] {
		return
	}
	array2d_append_int(mut arr, idx, val)
}
