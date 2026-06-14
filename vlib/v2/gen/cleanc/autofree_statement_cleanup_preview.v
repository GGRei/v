// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module cleanc

import v2.ast

enum AutofreeCleanCStatementCleanupPreviewStatus {
	unknown
	inert
}

enum AutofreeCleanCStatementCleanupPreviewKind {
	unknown
	array_after_statement
}

struct AutofreeCleanCStatementCleanupPreviewFact {
	fn_key               string
	fn_name              string
	name                 string
	cleanup_status       AutofreeCleanCStatementCleanupPreviewStatus
	cleanup_kind         AutofreeCleanCStatementCleanupPreviewKind
	fn_node_id           ast.FlatNodeId
	fn_pos_id            int
	target_node_id       ast.FlatNodeId
	target_pos_id        int
	stmt_node_id         ast.FlatNodeId
	stmt_pos_id          int
	insert_after_node_id ast.FlatNodeId
	insert_after_pos_id  int
	stmt_index           int
	lhs_index            int
	target_c_name        string
	cleanup_symbol       string
	cleanup_text         string
	reason               string
}

fn autofree_statement_cleanup_preview_facts_from_slots(slots []AutofreeCleanCStatementEmissionSlotFact) []AutofreeCleanCStatementCleanupPreviewFact {
	if slots.len != 1 {
		return []AutofreeCleanCStatementCleanupPreviewFact{}
	}
	preview := autofree_statement_cleanup_preview_fact_from_slot(slots[0]) or {
		return []AutofreeCleanCStatementCleanupPreviewFact{}
	}
	return [preview]
}

fn autofree_statement_cleanup_preview_fact_from_slot(slot AutofreeCleanCStatementEmissionSlotFact) ?AutofreeCleanCStatementCleanupPreviewFact {
	if slot.slot_status != .inert || slot.slot_kind != .after_statement || slot.fn_key.len == 0
		|| slot.fn_name.len == 0 || slot.name.len == 0 {
		return none
	}
	if slot.fn_node_id < 0 || slot.fn_pos_id <= 0 || slot.target_node_id < 0
		|| slot.target_pos_id <= 0 || slot.stmt_node_id < 0 || slot.stmt_pos_id <= 0
		|| slot.insert_after_node_id < 0 || slot.insert_after_pos_id <= 0 {
		return none
	}
	if slot.stmt_node_id != slot.insert_after_node_id
		|| slot.stmt_pos_id != slot.insert_after_pos_id {
		return none
	}
	if slot.target_node_id == slot.insert_after_node_id {
		return none
	}
	if slot.stmt_index < 0 || slot.lhs_index != 0 {
		return none
	}
	target_c_name := c_local_name(slot.name)
	if target_c_name.len == 0 {
		return none
	}
	cleanup_symbol := 'array__free'
	return AutofreeCleanCStatementCleanupPreviewFact{
		fn_key:               slot.fn_key
		fn_name:              slot.fn_name
		name:                 slot.name
		cleanup_status:       .inert
		cleanup_kind:         .array_after_statement
		fn_node_id:           slot.fn_node_id
		fn_pos_id:            slot.fn_pos_id
		target_node_id:       slot.target_node_id
		target_pos_id:        slot.target_pos_id
		stmt_node_id:         slot.stmt_node_id
		stmt_pos_id:          slot.stmt_pos_id
		insert_after_node_id: slot.insert_after_node_id
		insert_after_pos_id:  slot.insert_after_pos_id
		stmt_index:           slot.stmt_index
		lhs_index:            slot.lhs_index
		target_c_name:        target_c_name
		cleanup_symbol:       cleanup_symbol
		cleanup_text:         '${cleanup_symbol}(&${target_c_name});'
		reason:               'inert statement cleanup preview accepted'
	}
}
