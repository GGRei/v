// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module cleanc

import v2.ast
import v2.token

enum AutofreeCleanCStatementCleanupHookPreviewStatus {
	unknown
	inert
}

enum AutofreeCleanCStatementCleanupHookPreviewKind {
	unknown
	after_body_before_scheduled_drops
}

struct AutofreeCleanCStatementCleanupHookPreviewFact {
	fn_key               string
	fn_name              string
	name                 string
	hook_status          AutofreeCleanCStatementCleanupHookPreviewStatus
	hook_kind            AutofreeCleanCStatementCleanupHookPreviewKind
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

fn autofree_statement_cleanup_hook_preview_facts_from_file_cursor(file_cursor ast.FileCursor, fn_cursor ast.Cursor, previews []AutofreeCleanCStatementCleanupPreviewFact) []AutofreeCleanCStatementCleanupHookPreviewFact {
	if previews.len != 1 {
		return []AutofreeCleanCStatementCleanupHookPreviewFact{}
	}
	if !autofree_statement_location_fn_cursor_belongs_to_file(file_cursor, fn_cursor) {
		return []AutofreeCleanCStatementCleanupHookPreviewFact{}
	}
	fn_key := autofree_statement_location_fn_key_from_file_cursor(file_cursor, fn_cursor) or {
		return []AutofreeCleanCStatementCleanupHookPreviewFact{}
	}
	fn_name := fn_cursor.name()
	if fn_name.len == 0 {
		return []AutofreeCleanCStatementCleanupHookPreviewFact{}
	}
	body := autofree_statement_location_child_cursor(fn_cursor, 3, .aux_list) or {
		return []AutofreeCleanCStatementCleanupHookPreviewFact{}
	}
	if !autofree_statement_location_cursor_edge_range_is_valid(body)
		|| !autofree_statement_preview_body_is_assign_only(body) {
		return []AutofreeCleanCStatementCleanupHookPreviewFact{}
	}
	hook_preview := autofree_statement_cleanup_hook_preview_fact_from_body(fn_cursor, body,
		previews[0], fn_key, fn_name) or {
		return []AutofreeCleanCStatementCleanupHookPreviewFact{}
	}
	return [hook_preview]
}

fn autofree_statement_cleanup_hook_preview_fact_from_body(fn_cursor ast.Cursor, body ast.Cursor, preview AutofreeCleanCStatementCleanupPreviewFact, fn_key string, fn_name string) ?AutofreeCleanCStatementCleanupHookPreviewFact {
	if !autofree_statement_cleanup_hook_preview_is_valid(preview) {
		return none
	}
	if preview.fn_key != fn_key || preview.fn_name != fn_name || preview.fn_node_id != fn_cursor.id
		|| preview.fn_pos_id != fn_cursor.pos().id {
		return none
	}
	if preview.stmt_index < 0 || preview.stmt_index >= body.edge_count() {
		return none
	}
	if preview.stmt_index != body.edge_count() - 1 {
		return none
	}
	stmt := autofree_statement_location_edge_cursor(body, preview.stmt_index) or { return none }
	if !autofree_statement_cleanup_hook_preview_stmt_matches_preview(stmt, preview) {
		return none
	}
	return AutofreeCleanCStatementCleanupHookPreviewFact{
		fn_key:               preview.fn_key
		fn_name:              preview.fn_name
		name:                 preview.name
		hook_status:          .inert
		hook_kind:            .after_body_before_scheduled_drops
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
		reason:               'inert statement cleanup hook preview accepted'
	}
}

fn autofree_statement_cleanup_hook_preview_is_valid(preview AutofreeCleanCStatementCleanupPreviewFact) bool {
	if preview.cleanup_status != .inert || preview.cleanup_kind != .array_after_statement
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
	return preview.target_c_name == target_c_name && preview.cleanup_symbol == 'array__free'
		&& preview.cleanup_text == '${preview.cleanup_symbol}(&${target_c_name});'
}

fn autofree_statement_cleanup_hook_preview_stmt_matches_preview(stmt ast.Cursor, preview AutofreeCleanCStatementCleanupPreviewFact) bool {
	if !stmt.is_valid() || stmt.kind() != .stmt_assign {
		return false
	}
	if stmt.id != preview.stmt_node_id || stmt.pos().id != preview.stmt_pos_id
		|| stmt.id != preview.insert_after_node_id || stmt.pos().id != preview.insert_after_pos_id {
		return false
	}
	if !autofree_statement_location_cursor_edge_range_is_valid(stmt) || stmt.extra_int() != 1
		|| stmt.edge_count() != 2 || unsafe { token.Token(int(stmt.aux())) } != .decl_assign {
		return false
	}
	lhs := autofree_statement_location_edge_cursor(stmt, preview.lhs_index) or { return false }
	lhs_ident := autofree_statement_location_direct_lhs_ident(lhs) or { return false }
	return lhs_ident.id == preview.target_node_id && lhs_ident.pos().id == preview.target_pos_id
		&& lhs_ident.name() == preview.name
}
