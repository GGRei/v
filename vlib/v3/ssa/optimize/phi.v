module optimize

import v3.ssa

struct PhiEdge {
	pred int
	succ int
}

pub fn prune_phi_operands(mut m ssa.Module) {
	build_cfg(mut m)
	for fi in 0 .. m.funcs.len {
		for blk_id in m.funcs[fi].blocks {
			if blk_id < 0 || blk_id >= m.blocks.len {
				continue
			}
			preds := m.blocks[blk_id].preds.clone()
			for val_id in m.blocks[blk_id].instrs {
				if val_id <= 0 || val_id >= m.values.len || m.values[val_id].kind != .instruction {
					continue
				}
				idx := m.values[val_id].index
				if idx < 0 || idx >= m.instrs.len {
					continue
				}
				instr := m.instrs[idx]
				if instr.op != .phi {
					continue
				}
				mut new_ops := []ssa.ValueID{cap: instr.operands.len}
				mut seen_preds := []int{}
				for oi := 0; oi + 1 < instr.operands.len; oi += 2 {
					value_id := instr.operands[oi]
					pred_id := int(instr.operands[oi + 1])
					if value_id <= 0 || value_id >= m.values.len {
						continue
					}
					if pred_id < 0 || pred_id >= m.blocks.len {
						continue
					}
					if pred_id !in preds || pred_id in seen_preds {
						continue
					}
					new_ops << value_id
					new_ops << ssa.ValueID(pred_id)
					seen_preds << pred_id
				}
				if new_ops.len != instr.operands.len {
					mut phi_instr := m.instrs[idx]
					phi_instr.operands = new_ops
					m.instrs[idx] = phi_instr
				}
			}
		}
	}
	simplify_phi_nodes(mut m)
}

pub fn simplify_phi_nodes(mut m ssa.Module) bool {
	mut any_changed := false
	mut changed := true
	for changed {
		changed = false
		for fi in 0 .. m.funcs.len {
			for blk_id in m.funcs[fi].blocks {
				if blk_id < 0 || blk_id >= m.blocks.len {
					continue
				}
				for val_id in m.blocks[blk_id].instrs {
					if val_id <= 0 || val_id >= m.values.len
						|| m.values[val_id].kind != .instruction {
						continue
					}
					idx := m.values[val_id].index
					if idx < 0 || idx >= m.instrs.len {
						continue
					}
					instr := m.instrs[idx]
					if instr.op != .phi {
						continue
					}
					replacement := trivial_phi_replacement(mut m, val_id, instr)
					if replacement >= 0 {
						m.replace_uses(val_id, replacement)
						mark_instr_dead(mut m, val_id)
						changed = true
						any_changed = true
					} else if m.values[val_id].uses.len == 0 {
						mark_instr_dead(mut m, val_id)
						changed = true
						any_changed = true
					}
				}
			}
		}
	}
	return any_changed
}

fn trivial_phi_replacement(mut m ssa.Module, val_id int, instr ssa.Instruction) int {
	if instr.operands.len == 0 {
		return m.get_or_add_const(m.values[val_id].typ, 'undef')
	}
	mut unique := -1
	for oi := 0; oi + 1 < instr.operands.len; oi += 2 {
		incoming := int(instr.operands[oi])
		if incoming == val_id {
			continue
		}
		if incoming <= 0 || incoming >= m.values.len {
			continue
		}
		if unique == -1 {
			unique = incoming
		} else if unique != incoming {
			return -1
		}
	}
	if unique == -1 {
		return m.get_or_add_const(m.values[val_id].typ, 'undef')
	}
	return unique
}

pub fn eliminate_phi_nodes(mut m ssa.Module) {
	prune_phi_operands(mut m)
	split_phi_edges(mut m)
	build_cfg(mut m)

	mut copy_dests := [][]int{len: m.blocks.len}
	mut copy_srcs := [][]int{len: m.blocks.len}
	mut copy_blocks := []int{}
	mut phi_values := []int{}

	for fi in 0 .. m.funcs.len {
		for blk_id in m.funcs[fi].blocks {
			if blk_id < 0 || blk_id >= m.blocks.len {
				continue
			}
			for val_id in m.blocks[blk_id].instrs {
				if val_id <= 0 || val_id >= m.values.len || m.values[val_id].kind != .instruction {
					continue
				}
				idx := m.values[val_id].index
				if idx < 0 || idx >= m.instrs.len {
					continue
				}
				instr := m.instrs[idx]
				if instr.op != .phi {
					continue
				}
				phi_values << val_id
				for oi := 0; oi + 1 < instr.operands.len; oi += 2 {
					src := int(instr.operands[oi])
					pred := int(instr.operands[oi + 1])
					if src <= 0 || src >= m.values.len || pred < 0 || pred >= m.blocks.len {
						continue
					}
					if copy_dests[pred].len == 0 {
						copy_blocks << pred
					}
					array2d_append_int(mut copy_dests, pred, val_id)
					array2d_append_int(mut copy_srcs, pred, src)
				}
			}
		}
	}

	for blk_id in copy_blocks {
		resolve_parallel_copies(mut m, blk_id, copy_dests[blk_id], copy_srcs[blk_id])
	}

	for val_id in phi_values {
		mark_instr_dead(mut m, val_id)
	}
}

fn split_phi_edges(mut m ssa.Module) {
	build_cfg(mut m)
	mut edges := []PhiEdge{}
	for fi in 0 .. m.funcs.len {
		for blk_id in m.funcs[fi].blocks {
			if blk_id < 0 || blk_id >= m.blocks.len {
				continue
			}
			for val_id in m.blocks[blk_id].instrs {
				if val_id <= 0 || val_id >= m.values.len || m.values[val_id].kind != .instruction {
					continue
				}
				idx := m.values[val_id].index
				if idx < 0 || idx >= m.instrs.len || m.instrs[idx].op != .phi {
					continue
				}
				instr := m.instrs[idx]
				for oi := 1; oi < instr.operands.len; oi += 2 {
					pred := int(instr.operands[oi])
					if pred < 0 || pred >= m.blocks.len {
						continue
					}
					if m.blocks[pred].succs.len <= 1 {
						continue
					}
					if !phi_edge_exists(edges, pred, blk_id) {
						edges << PhiEdge{
							pred: pred
							succ: blk_id
						}
					}
				}
			}
		}
	}
	for edge in edges {
		split_phi_edge(mut m, edge.pred, edge.succ)
	}
	build_cfg(mut m)
}

fn phi_edge_exists(edges []PhiEdge, pred int, succ int) bool {
	for edge in edges {
		if edge.pred == pred && edge.succ == succ {
			return true
		}
	}
	return false
}

fn split_phi_edge(mut m ssa.Module, pred int, succ int) {
	if pred < 0 || pred >= m.blocks.len || succ < 0 || succ >= m.blocks.len {
		return
	}
	if !terminator_targets_block(m, pred, succ) {
		return
	}
	func_id := m.blocks[pred].parent
	if func_id < 0 || func_id >= m.funcs.len {
		return
	}
	split_blk := m.add_block(func_id, 'phi_edge_${pred}_${succ}')
	m.add_instr(.jmp, split_blk, ssa.TypeID(0), [ssa.ValueID(succ)])
	replace_terminator_target(mut m, pred, succ, split_blk)
	replace_phi_predecessor(mut m, succ, pred, split_blk)
}

fn terminator_targets_block(m &ssa.Module, blk_id int, target int) bool {
	if blk_id < 0 || blk_id >= m.blocks.len || m.blocks[blk_id].instrs.len == 0 {
		return false
	}
	term_val := m.blocks[blk_id].instrs.last()
	if term_val <= 0 || term_val >= m.values.len || m.values[term_val].kind != .instruction {
		return false
	}
	instr := m.instrs[m.values[term_val].index]
	match instr.op {
		.jmp {
			return instr.operands.len == 1 && int(instr.operands[0]) == target
		}
		.br {
			return instr.operands.len == 3
				&& (int(instr.operands[1]) == target || int(instr.operands[2]) == target)
		}
		.switch_ {
			if instr.operands.len >= 2 && int(instr.operands[1]) == target {
				return true
			}
			for oi := 3; oi < instr.operands.len; oi += 2 {
				if int(instr.operands[oi]) == target {
					return true
				}
			}
		}
		else {}
	}

	return false
}

fn replace_terminator_target(mut m ssa.Module, blk_id int, old_target int, new_target int) {
	if blk_id < 0 || blk_id >= m.blocks.len || m.blocks[blk_id].instrs.len == 0 {
		return
	}
	term_val := m.blocks[blk_id].instrs.last()
	if term_val <= 0 || term_val >= m.values.len || m.values[term_val].kind != .instruction {
		return
	}
	idx := m.values[term_val].index
	if idx < 0 || idx >= m.instrs.len {
		return
	}
	mut instr := m.instrs[idx]
	match instr.op {
		.jmp {
			if instr.operands.len == 1 && int(instr.operands[0]) == old_target {
				instr.operands[0] = ssa.ValueID(new_target)
			}
		}
		.br {
			if instr.operands.len == 3 {
				if int(instr.operands[1]) == old_target {
					instr.operands[1] = ssa.ValueID(new_target)
				}
				if int(instr.operands[2]) == old_target {
					instr.operands[2] = ssa.ValueID(new_target)
				}
			}
		}
		.switch_ {
			if instr.operands.len >= 2 && int(instr.operands[1]) == old_target {
				instr.operands[1] = ssa.ValueID(new_target)
			}
			for oi := 3; oi < instr.operands.len; oi += 2 {
				if int(instr.operands[oi]) == old_target {
					instr.operands[oi] = ssa.ValueID(new_target)
				}
			}
		}
		else {}
	}

	m.instrs[idx] = instr
}

fn replace_phi_predecessor(mut m ssa.Module, succ int, old_pred int, new_pred int) {
	if succ < 0 || succ >= m.blocks.len {
		return
	}
	for val_id in m.blocks[succ].instrs {
		if val_id <= 0 || val_id >= m.values.len || m.values[val_id].kind != .instruction {
			continue
		}
		idx := m.values[val_id].index
		if idx < 0 || idx >= m.instrs.len || m.instrs[idx].op != .phi {
			continue
		}
		mut instr := m.instrs[idx]
		for oi := 1; oi < instr.operands.len; oi += 2 {
			if int(instr.operands[oi]) == old_pred {
				instr.operands[oi] = ssa.ValueID(new_pred)
			}
		}
		m.instrs[idx] = instr
	}
}

fn resolve_parallel_copies(mut m ssa.Module, blk_id int, dests []int, srcs []int) {
	if blk_id < 0 || blk_id >= m.blocks.len || dests.len != srcs.len {
		return
	}
	mut pending_dests := dests.clone()
	mut pending_srcs := srcs.clone()
	mut alive := []bool{len: pending_dests.len, init: true}
	mut remaining := pending_dests.len

	for remaining > 0 {
		mut progressed := false
		for i in 0 .. pending_dests.len {
			if !alive[i] {
				continue
			}
			dest := pending_dests[i]
			src := pending_srcs[i]
			if dest == src || !alive_source_contains_dest(alive, pending_srcs, dest) {
				if dest != src {
					insert_copy_in_block(mut m, blk_id, dest, src)
				}
				alive[i] = false
				remaining--
				progressed = true
			}
		}
		if progressed {
			continue
		}

		mut cycle_idx := -1
		for i in 0 .. alive.len {
			if alive[i] {
				cycle_idx = i
				break
			}
		}
		if cycle_idx < 0 {
			break
		}
		temp := insert_temp_in_block(mut m, blk_id, pending_srcs[cycle_idx])
		for i in 0 .. pending_srcs.len {
			if alive[i] && pending_srcs[i] == pending_srcs[cycle_idx] {
				pending_srcs[i] = temp
			}
		}
	}
}

fn alive_source_contains_dest(alive []bool, srcs []int, dest int) bool {
	for i in 0 .. srcs.len {
		if alive[i] && srcs[i] == dest {
			return true
		}
	}
	return false
}

fn insert_temp_in_block(mut m ssa.Module, blk_id int, src int) int {
	typ := if src > 0 && src < m.values.len { m.values[src].typ } else { ssa.TypeID(0) }
	instr_idx := m.instrs.len
	m.instrs << ssa.Instruction{
		op:       .bitcast
		block:    blk_id
		typ:      typ
		operands: [ssa.ValueID(src)]
	}
	temp_id := m.add_value(.instruction, typ, 'phi_tmp', instr_idx)
	insert_value_before_terminator(mut m, blk_id, temp_id)
	return temp_id
}

fn insert_copy_in_block(mut m ssa.Module, blk_id int, dest int, src int) {
	typ := if dest > 0 && dest < m.values.len { m.values[dest].typ } else { ssa.TypeID(0) }
	instr_idx := m.instrs.len
	m.instrs << ssa.Instruction{
		op:       .assign
		block:    blk_id
		typ:      typ
		operands: [ssa.ValueID(dest), ssa.ValueID(src)]
	}
	copy_id := m.add_value(.instruction, typ, 'phi_copy', instr_idx)
	insert_value_before_terminator(mut m, blk_id, copy_id)
}

fn insert_value_before_terminator(mut m ssa.Module, blk_id int, val_id int) {
	if blk_id < 0 || blk_id >= m.blocks.len {
		return
	}
	mut blk := m.blocks[blk_id]
	mut insert_at := blk.instrs.len
	if blk.instrs.len > 0 {
		last_val := blk.instrs.last()
		if last_val > 0 && last_val < m.values.len && m.values[last_val].kind == .instruction {
			last_idx := m.values[last_val].index
			if last_idx >= 0 && last_idx < m.instrs.len {
				if m.instrs[last_idx].op in [.ret, .br, .jmp, .switch_, .unreachable] {
					insert_at = blk.instrs.len - 1
				}
			}
		}
	}
	mut instrs := []int{cap: blk.instrs.len + 1}
	for i in 0 .. insert_at {
		instrs << blk.instrs[i]
	}
	instrs << val_id
	for i in insert_at .. blk.instrs.len {
		instrs << blk.instrs[i]
	}
	blk.instrs = instrs
	m.blocks[blk_id] = blk
}

fn mark_instr_dead(mut m ssa.Module, val_id int) {
	if val_id <= 0 || val_id >= m.values.len || m.values[val_id].kind != .instruction {
		return
	}
	idx := m.values[val_id].index
	if idx < 0 || idx >= m.instrs.len {
		return
	}
	mut instr := m.instrs[idx]
	instr.op = .bitcast
	instr.operands = []
	m.instrs[idx] = instr
}

fn array2d_append_int(mut arr [][]int, idx int, val int) {
	mut inner := arr[idx]
	inner << val
	arr[idx] = inner
}
