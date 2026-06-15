// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module cleanc

import v2.ast

enum AutofreeCleanCStatementPreviewStatus {
	unknown
	inert
}

struct AutofreeCleanCStatementPreviewFact {
	fn_key               string
	fn_name              string
	name                 string
	preview_status       AutofreeCleanCStatementPreviewStatus
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
	reason               string
}

fn autofree_statement_preview_facts_from_file_cursor(file_cursor ast.FileCursor, fn_cursor ast.Cursor, locations []AutofreeCleanCStatementLocationFact) []AutofreeCleanCStatementPreviewFact {
	if !autofree_statement_location_fn_cursor_belongs_to_file(file_cursor, fn_cursor) {
		return []AutofreeCleanCStatementPreviewFact{}
	}
	fn_key := autofree_statement_location_fn_key_from_file_cursor(file_cursor, fn_cursor) or {
		return []AutofreeCleanCStatementPreviewFact{}
	}
	fn_name := fn_cursor.name()
	if fn_name.len == 0 {
		return []AutofreeCleanCStatementPreviewFact{}
	}
	body := autofree_statement_location_child_cursor(fn_cursor, 3, .aux_list) or {
		return []AutofreeCleanCStatementPreviewFact{}
	}
	if !autofree_statement_location_cursor_edge_range_is_valid(body) {
		return []AutofreeCleanCStatementPreviewFact{}
	}
	duplicate_names := autofree_statement_preview_duplicate_names(locations)
	duplicate_targets := autofree_statement_preview_duplicate_target_positions(locations)
	duplicate_slots := autofree_statement_preview_duplicate_insert_slots(locations)
	duplicate_stmts := autofree_statement_preview_duplicate_statement_positions(locations)
	mut previews := []AutofreeCleanCStatementPreviewFact{}
	for location in locations {
		name_key := autofree_statement_preview_name_key(location)
		target_key := autofree_statement_preview_target_position_key(location)
		slot_key := autofree_statement_preview_insert_slot_key(location)
		stmt_key := autofree_statement_preview_statement_position_key(location)
		if name_key.len == 0 || name_key in duplicate_names || target_key.len == 0
			|| target_key in duplicate_targets || slot_key.len == 0 || slot_key in duplicate_slots
			|| stmt_key.len == 0 || stmt_key in duplicate_stmts {
			continue
		}
		if location.fn_key != fn_key || location.fn_name != fn_name
			|| location.fn_node_id != fn_cursor.id || location.fn_pos_id != fn_cursor.pos().id {
			continue
		}
		preview := autofree_statement_preview_fact_from_location_in_body(body, location) or {
			continue
		}
		previews << preview
	}
	return previews
}

fn autofree_statement_preview_fact_from_location_in_body(body ast.Cursor, location AutofreeCleanCStatementLocationFact) ?AutofreeCleanCStatementPreviewFact {
	if location.stmt_index < 0 || location.stmt_index >= body.edge_count() {
		return none
	}
	if location.stmt_index != body.edge_count() - 1 {
		return none
	}
	stmt := autofree_statement_location_edge_cursor(body, location.stmt_index) or { return none }
	if !stmt.is_valid() || stmt.kind() != .stmt_assign {
		return none
	}
	if stmt.id != location.stmt_node_id || stmt.pos().id != location.stmt_pos_id
		|| stmt.id != location.insert_after_node_id || stmt.pos().id != location.insert_after_pos_id {
		return none
	}
	if autofree_statement_preview_later_assigns_target(body, location.stmt_index, location.name) {
		return none
	}
	return autofree_statement_preview_fact_from_location(location)
}

fn autofree_statement_preview_later_assigns_target(body ast.Cursor, stmt_index int, target_name string) bool {
	if target_name.len == 0 {
		return true
	}
	for i in stmt_index + 1 .. body.edge_count() {
		stmt := autofree_statement_location_edge_cursor(body, i) or { return true }
		if !stmt.is_valid() || stmt.kind() != .stmt_assign
			|| !autofree_statement_location_cursor_edge_range_is_valid(stmt) {
			return true
		}
		lhs_count := stmt.extra_int()
		if lhs_count < 0 || lhs_count > stmt.edge_count() {
			return true
		}
		for lhs_i in 0 .. lhs_count {
			lhs := autofree_statement_location_edge_cursor(stmt, lhs_i) or { return true }
			if !lhs.is_valid() {
				return true
			}
			if lhs.kind() == .expr_ident && lhs.edge_count() == 0 && lhs.name() == target_name {
				return true
			}
		}
	}
	return false
}

fn autofree_statement_preview_fact_from_location(location AutofreeCleanCStatementLocationFact) ?AutofreeCleanCStatementPreviewFact {
	if location.location_status != .inert || location.fn_key.len == 0 || location.fn_name.len == 0
		|| location.name.len == 0 {
		return none
	}
	if location.target_node_id < 0 || location.target_pos_id <= 0 || location.stmt_node_id < 0
		|| location.stmt_pos_id <= 0 || location.insert_after_node_id < 0
		|| location.insert_after_pos_id <= 0 || location.fn_node_id < 0 || location.fn_pos_id <= 0 {
		return none
	}
	if location.stmt_node_id != location.insert_after_node_id
		|| location.stmt_pos_id != location.insert_after_pos_id {
		return none
	}
	if location.target_node_id == location.insert_after_node_id {
		return none
	}
	if location.stmt_index < 0 || location.lhs_index != 0 {
		return none
	}
	return AutofreeCleanCStatementPreviewFact{
		fn_key:               location.fn_key
		fn_name:              location.fn_name
		name:                 location.name
		preview_status:       .inert
		fn_node_id:           location.fn_node_id
		fn_pos_id:            location.fn_pos_id
		target_node_id:       location.target_node_id
		target_pos_id:        location.target_pos_id
		stmt_node_id:         location.stmt_node_id
		stmt_pos_id:          location.stmt_pos_id
		insert_after_node_id: location.insert_after_node_id
		insert_after_pos_id:  location.insert_after_pos_id
		stmt_index:           location.stmt_index
		lhs_index:            location.lhs_index
		reason:               'inert statement preview accepted'
	}
}

fn autofree_statement_preview_duplicate_names(locations []AutofreeCleanCStatementLocationFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for location in locations {
		name_key := autofree_statement_preview_name_key(location)
		if name_key.len == 0 {
			continue
		}
		if name_key in seen {
			duplicates[name_key] = true
			continue
		}
		seen[name_key] = true
	}
	return duplicates
}

fn autofree_statement_preview_duplicate_target_positions(locations []AutofreeCleanCStatementLocationFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for location in locations {
		target_key := autofree_statement_preview_target_position_key(location)
		if target_key.len == 0 {
			continue
		}
		if target_key in seen {
			duplicates[target_key] = true
			continue
		}
		seen[target_key] = true
	}
	return duplicates
}

fn autofree_statement_preview_duplicate_insert_slots(locations []AutofreeCleanCStatementLocationFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for location in locations {
		slot_key := autofree_statement_preview_insert_slot_key(location)
		if slot_key.len == 0 {
			continue
		}
		if slot_key in seen {
			duplicates[slot_key] = true
			continue
		}
		seen[slot_key] = true
	}
	return duplicates
}

fn autofree_statement_preview_duplicate_statement_positions(locations []AutofreeCleanCStatementLocationFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for location in locations {
		stmt_key := autofree_statement_preview_statement_position_key(location)
		if stmt_key.len == 0 {
			continue
		}
		if stmt_key in seen {
			duplicates[stmt_key] = true
			continue
		}
		seen[stmt_key] = true
	}
	return duplicates
}

fn autofree_statement_preview_name_key(location AutofreeCleanCStatementLocationFact) string {
	if location.fn_key.len == 0 || location.name.len == 0 {
		return ''
	}
	return '${location.fn_key.len}:${location.fn_key}:${location.name.len}:${location.name}'
}

fn autofree_statement_preview_target_position_key(location AutofreeCleanCStatementLocationFact) string {
	if location.fn_key.len == 0 || location.target_node_id < 0 || location.target_pos_id <= 0 {
		return ''
	}
	return '${location.fn_key.len}:${location.fn_key}:${location.target_node_id}:${location.target_pos_id}'
}

fn autofree_statement_preview_insert_slot_key(location AutofreeCleanCStatementLocationFact) string {
	if location.fn_key.len == 0 || location.insert_after_node_id < 0
		|| location.insert_after_pos_id <= 0 {
		return ''
	}
	return '${location.fn_key.len}:${location.fn_key}:${location.insert_after_node_id}:${location.insert_after_pos_id}'
}

fn autofree_statement_preview_statement_position_key(location AutofreeCleanCStatementLocationFact) string {
	if location.fn_key.len == 0 || location.stmt_node_id < 0 || location.stmt_pos_id <= 0 {
		return ''
	}
	return '${location.fn_key.len}:${location.fn_key}:${location.stmt_node_id}:${location.stmt_pos_id}'
}
