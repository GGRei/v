module optimize

import v3.ssa

pub struct DomInfo {
pub mut:
	idom     []ssa.BlockID
	dom_tree [][]ssa.BlockID
}

pub fn compute_dominators(mut m ssa.Module, cfg &CfgData) DomInfo {
	n_blocks := m.blocks.len
	mut idom := []ssa.BlockID{len: n_blocks, init: ssa.BlockID(-1)}
	mut dom_tree := [][]ssa.BlockID{len: n_blocks}

	for bi in 0 .. n_blocks {
		mut blk := m.blocks[bi]
		blk.idom = ssa.BlockID(-1)
		blk.dom_tree = []
		m.blocks[bi] = blk
	}

	for fi in 0 .. m.funcs.len {
		func := m.funcs[fi]
		if func.blocks.len == 0 {
			continue
		}
		entry := func.blocks[0]
		if !valid_block_id(entry, n_blocks) {
			continue
		}

		func_blocks := block_set_for_function(func, n_blocks)
		reachable := reachable_blocks_for_function(cfg, entry, func_blocks, n_blocks)
		if reachable.len == 0 {
			continue
		}
		reachable_map := block_set_from_list(reachable)

		mut dom := new_dominator_matrix(n_blocks)
		for blk_id in reachable {
			if blk_id == entry {
				dom[blk_id][entry] = true
			} else {
				for candidate in reachable {
					dom[blk_id][candidate] = true
				}
			}
		}

		mut changed := true
		for changed {
			changed = false
			for blk_id in reachable {
				if blk_id == entry {
					continue
				}
				mut new_row := []bool{len: n_blocks}
				mut initialized := false
				if blk_id >= 0 && blk_id < cfg.preds.len {
					for pred in cfg.preds[blk_id] {
						if !reachable_map[int(pred)] {
							continue
						}
						if !initialized {
							new_row = dom[pred].clone()
							initialized = true
						} else {
							for candidate in reachable {
								new_row[candidate] = new_row[candidate] && dom[pred][candidate]
							}
						}
					}
				}
				new_row[blk_id] = true
				if !dominance_rows_equal(dom[blk_id], new_row, reachable) {
					dom[blk_id] = new_row
					changed = true
				}
			}
		}

		idom[entry] = entry
		for blk_id in reachable {
			if blk_id == entry {
				continue
			}
			idom[blk_id] = immediate_dominator_from_sets(dom, reachable, blk_id)
		}
		for blk_id in reachable {
			parent := idom[blk_id]
			if parent >= 0 && parent < n_blocks && parent != blk_id {
				if !block_arr_contains(dom_tree[parent], blk_id) {
					dom_tree[parent] << blk_id
				}
			}
		}
	}

	for bi in 0 .. n_blocks {
		mut blk := m.blocks[bi]
		blk.idom = idom[bi]
		blk.dom_tree = dom_tree[bi]
		m.blocks[bi] = blk
	}

	return DomInfo{
		idom:     idom
		dom_tree: dom_tree
	}
}

fn valid_block_id(blk_id ssa.BlockID, n_blocks int) bool {
	return blk_id >= 0 && blk_id < n_blocks
}

fn block_set_for_function(func ssa.Function, n_blocks int) map[int]bool {
	mut blocks := map[int]bool{}
	for blk_id in func.blocks {
		if valid_block_id(blk_id, n_blocks) {
			blocks[int(blk_id)] = true
		}
	}
	return blocks
}

fn block_set_from_list(blocks []ssa.BlockID) map[int]bool {
	mut set := map[int]bool{}
	for blk_id in blocks {
		set[int(blk_id)] = true
	}
	return set
}

fn reachable_blocks_for_function(cfg &CfgData, entry ssa.BlockID, func_blocks map[int]bool, n_blocks int) []ssa.BlockID {
	mut reached := map[int]bool{}
	mut out := []ssa.BlockID{}
	mut stack := []ssa.BlockID{}
	stack << entry
	for stack.len > 0 {
		blk_id := stack.last()
		stack.delete_last()
		if !valid_block_id(blk_id, n_blocks) || !func_blocks[int(blk_id)] || reached[int(blk_id)] {
			continue
		}
		reached[int(blk_id)] = true
		out << blk_id
		if blk_id < 0 || blk_id >= cfg.succs.len {
			continue
		}
		for succ in cfg.succs[blk_id] {
			if valid_block_id(succ, n_blocks) && func_blocks[int(succ)] && !reached[int(succ)] {
				stack << succ
			}
		}
	}
	return out
}

fn new_dominator_matrix(n_blocks int) [][]bool {
	mut dom := [][]bool{cap: n_blocks}
	for _ in 0 .. n_blocks {
		dom << []bool{len: n_blocks}
	}
	return dom
}

fn dominance_rows_equal(lhs []bool, rhs []bool, reachable []ssa.BlockID) bool {
	for blk_id in reachable {
		if lhs[blk_id] != rhs[blk_id] {
			return false
		}
	}
	return true
}

fn immediate_dominator_from_sets(dom [][]bool, reachable []ssa.BlockID, blk_id ssa.BlockID) ssa.BlockID {
	for candidate in reachable {
		if candidate == blk_id || !dom[blk_id][candidate] {
			continue
		}
		mut is_immediate := true
		for other in reachable {
			if other == blk_id || other == candidate || !dom[blk_id][other] {
				continue
			}
			if !dom[candidate][other] {
				is_immediate = false
				break
			}
		}
		if is_immediate {
			return candidate
		}
	}
	return ssa.BlockID(-1)
}
