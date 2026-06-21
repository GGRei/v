module optimize

import v3.ssa

pub struct CfgData {
pub mut:
	succs [][]ssa.BlockID
	preds [][]ssa.BlockID
}

fn arr_contains(arr []int, val int) bool {
	for v in arr {
		if v == val {
			return true
		}
	}
	return false
}

fn block_arr_contains(arr []ssa.BlockID, val ssa.BlockID) bool {
	for v in arr {
		if v == val {
			return true
		}
	}
	return false
}

fn add_cfg_edge(mut cfg CfgData, from ssa.BlockID, to ssa.BlockID, n_blocks int) {
	if from < 0 || from >= n_blocks || to < 0 || to >= n_blocks {
		return
	}
	if !block_arr_contains(cfg.succs[from], to) {
		cfg.succs[from] << to
	}
	if !block_arr_contains(cfg.preds[to], from) {
		cfg.preds[to] << from
	}
}

pub fn cfg_data_from_module(m &ssa.Module) CfgData {
	n_blocks := m.blocks.len
	n_values := m.values.len
	n_instrs := m.instrs.len

	mut cfg := CfgData{
		succs: [][]ssa.BlockID{len: n_blocks}
		preds: [][]ssa.BlockID{len: n_blocks}
	}

	for fi in 0 .. m.funcs.len {
		for blk_id in m.funcs[fi].blocks {
			if blk_id < 0 || blk_id >= n_blocks {
				continue
			}
			blk := m.blocks[blk_id]
			if blk.instrs.len == 0 {
				continue
			}
			term_val_id := blk.instrs.last()
			if term_val_id < 0 || term_val_id >= n_values {
				continue
			}
			term_val := m.values[term_val_id]
			if term_val.kind != .instruction {
				continue
			}
			if term_val.index < 0 || term_val.index >= n_instrs {
				continue
			}
			term := m.instrs[term_val.index]

			match term.op {
				.br {
					if term.operands.len >= 3 {
						add_cfg_edge(mut cfg, blk_id, ssa.BlockID(term.operands[1]), n_blocks)
						add_cfg_edge(mut cfg, blk_id, ssa.BlockID(term.operands[2]), n_blocks)
					}
				}
				.jmp {
					if term.operands.len >= 1 {
						add_cfg_edge(mut cfg, blk_id, ssa.BlockID(term.operands[0]), n_blocks)
					}
				}
				.switch_ {
					// switch_ cond, default_blk, [case_val, blk]...
					if term.operands.len >= 2 {
						add_cfg_edge(mut cfg, blk_id, ssa.BlockID(term.operands[1]), n_blocks)
						for oi := 3; oi < term.operands.len; oi += 2 {
							add_cfg_edge(mut cfg, blk_id, ssa.BlockID(term.operands[oi]), n_blocks)
						}
					}
				}
				else {}
			}
		}
	}
	return cfg
}

fn build_cfg(mut m ssa.Module) CfgData {
	cfg := cfg_data_from_module(m)
	for bi in 0 .. m.blocks.len {
		mut blk := m.blocks[bi]
		blk.succs = cfg.succs[bi]
		blk.preds = cfg.preds[bi]
		m.blocks[bi] = blk
	}
	return cfg
}
