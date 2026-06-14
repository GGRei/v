// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module cleanc

import v2.ast

enum AutofreeCleanCStatementCleanupEmitContextStatus {
	unknown
	inert
}

enum AutofreeCleanCStatementCleanupEmitContextKind {
	unknown
	after_body_before_scheduled_drops
}

struct AutofreeCleanCStatementCleanupEmitContextFact {
	fn_key               string
	fn_name              string
	name                 string
	context_status       AutofreeCleanCStatementCleanupEmitContextStatus
	context_kind         AutofreeCleanCStatementCleanupEmitContextKind
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
	context_key          string
	reason               string
}

fn autofree_statement_cleanup_emit_context_facts_from_hook_previews(previews []AutofreeCleanCStatementCleanupHookPreviewFact) []AutofreeCleanCStatementCleanupEmitContextFact {
	if previews.len != 1 {
		return []AutofreeCleanCStatementCleanupEmitContextFact{}
	}
	context := autofree_statement_cleanup_emit_context_fact_from_hook_preview(previews[0]) or {
		return []AutofreeCleanCStatementCleanupEmitContextFact{}
	}
	return [context]
}

fn autofree_statement_cleanup_emit_context_fact_from_hook_preview(preview AutofreeCleanCStatementCleanupHookPreviewFact) ?AutofreeCleanCStatementCleanupEmitContextFact {
	if !autofree_statement_cleanup_emit_context_hook_preview_is_valid(preview) {
		return none
	}
	context_key := autofree_statement_cleanup_emit_context_key(preview)
	if context_key.len == 0 {
		return none
	}
	return AutofreeCleanCStatementCleanupEmitContextFact{
		fn_key:               preview.fn_key
		fn_name:              preview.fn_name
		name:                 preview.name
		context_status:       .inert
		context_kind:         .after_body_before_scheduled_drops
		fn_node_id:           preview.fn_node_id
		fn_pos_id:            preview.fn_pos_id
		target_node_id:       preview.target_node_id
		target_pos_id:        preview.target_pos_id
		stmt_node_id:         preview.stmt_node_id
		stmt_pos_id:          preview.stmt_pos_id
		insert_after_node_id: preview.insert_after_node_id
		insert_after_pos_id:  preview.insert_after_pos_id
		stmt_index:           preview.stmt_index
		lhs_index:            preview.lhs_index
		target_c_name:        preview.target_c_name
		cleanup_symbol:       preview.cleanup_symbol
		cleanup_text:         preview.cleanup_text
		context_key:          context_key
		reason:               'inert statement cleanup emit context accepted'
	}
}

fn autofree_statement_cleanup_emit_context_hook_preview_is_valid(preview AutofreeCleanCStatementCleanupHookPreviewFact) bool {
	if preview.hook_status != .inert || preview.hook_kind != .after_body_before_scheduled_drops
		|| preview.fn_key.len == 0 || preview.fn_name.len == 0 || preview.name.len == 0 {
		return false
	}
	if preview.fn_node_id < 0 || preview.fn_pos_id <= 0 || preview.target_node_id < 0
		|| preview.target_pos_id <= 0 || preview.stmt_node_id < 0 || preview.stmt_pos_id <= 0
		|| preview.insert_after_node_id < 0 || preview.insert_after_pos_id <= 0 {
		return false
	}
	if preview.stmt_node_id != preview.insert_after_node_id
		|| preview.stmt_pos_id != preview.insert_after_pos_id {
		return false
	}
	if preview.target_node_id == preview.insert_after_node_id {
		return false
	}
	if preview.stmt_index < 0 || preview.lhs_index != 0 {
		return false
	}
	target_c_name := c_local_name(preview.name)
	return target_c_name.len > 0 && preview.target_c_name == target_c_name
		&& preview.cleanup_symbol == 'array__free'
		&& preview.cleanup_text == '${preview.cleanup_symbol}(&${target_c_name});'
}

fn autofree_statement_cleanup_emit_context_key(preview AutofreeCleanCStatementCleanupHookPreviewFact) string {
	return '${preview.fn_key}:${preview.fn_node_id}:${preview.fn_pos_id}:${preview.target_node_id}:${preview.target_pos_id}:${preview.insert_after_node_id}:${preview.insert_after_pos_id}:${preview.name}'
}
