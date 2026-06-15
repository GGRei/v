// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module cleanc

import v2.ast
import v2.token
import v2.types

enum AutofreeCleanCStatementLocationStatus {
	unknown
	inert
}

struct AutofreeCleanCStatementLocationFact {
	fn_key               string
	fn_name              string
	name                 string
	location_status      AutofreeCleanCStatementLocationStatus
	fn_node_id           ast.FlatNodeId
	fn_pos_id            int
	target_node_id       ast.FlatNodeId
	target_pos_id        int
	insert_after_node_id ast.FlatNodeId
	insert_after_pos_id  int
	stmt_node_id         ast.FlatNodeId
	stmt_pos_id          int
	stmt_index           int
	lhs_index            int
	reason               string
}

fn autofree_statement_location_facts_from_file_cursor(file_cursor ast.FileCursor, fn_cursor ast.Cursor, anchors []AutofreeCleanCStatementAnchorFact) []AutofreeCleanCStatementLocationFact {
	fn_key := autofree_statement_location_fn_key_from_file_cursor(file_cursor, fn_cursor) or {
		return []AutofreeCleanCStatementLocationFact{}
	}
	fn_key_counts := autofree_statement_location_fn_key_counts(file_cursor.flat)
	if fn_key_counts[fn_key] != 1 {
		return []AutofreeCleanCStatementLocationFact{}
	}
	fn_name := fn_cursor.name()
	if fn_name.len == 0 {
		return []AutofreeCleanCStatementLocationFact{}
	}
	body := autofree_statement_location_child_cursor(fn_cursor, 3, .aux_list) or {
		return []AutofreeCleanCStatementLocationFact{}
	}
	if !autofree_statement_location_cursor_edge_range_is_valid(body) {
		return []AutofreeCleanCStatementLocationFact{}
	}
	duplicate_names := autofree_statement_location_duplicate_names(anchors)
	duplicate_targets := autofree_statement_location_duplicate_target_positions(anchors)
	duplicate_slots := autofree_statement_location_duplicate_slots(anchors)
	mut facts := []AutofreeCleanCStatementLocationFact{}
	for anchor in anchors {
		name_key := autofree_statement_location_name_key(anchor)
		target_key := autofree_statement_location_target_position_key(anchor)
		slot_key := autofree_statement_location_slot_key(anchor)
		if name_key.len == 0 || name_key in duplicate_names || target_key.len == 0
			|| target_key in duplicate_targets || slot_key.len == 0 || slot_key in duplicate_slots {
			continue
		}
		if !autofree_statement_location_anchor_is_valid(anchor) || anchor.fn_key != fn_key {
			continue
		}
		if anchor.fn_name.len == 0 || anchor.fn_name != fn_name {
			continue
		}
		location := autofree_statement_location_fact_from_body(fn_cursor, body, anchor) or {
			continue
		}
		facts << location
	}
	return facts
}

fn autofree_statement_location_fn_key_counts(flat &ast.FlatAst) map[string]int {
	mut counts := map[string]int{}
	for i in 0 .. flat.files.len {
		file_cursor := flat.file_cursor(i)
		if !autofree_statement_location_file_cursor_is_valid(file_cursor) {
			continue
		}
		stmts := file_cursor.stmts()
		if !autofree_statement_location_cursor_list_is_valid(stmts, .aux_list) {
			continue
		}
		for stmt_i in 0 .. stmts.len() {
			fn_cursor := stmts.at(stmt_i)
			fn_key := autofree_statement_location_fn_key_from_file_cursor(file_cursor, fn_cursor) or {
				continue
			}
			counts[fn_key] = counts[fn_key] + 1
		}
	}
	return counts
}

fn autofree_statement_location_fn_key_from_file_cursor(file_cursor ast.FileCursor, fn_cursor ast.Cursor) ?string {
	if !autofree_statement_location_fn_cursor_belongs_to_file(file_cursor, fn_cursor) {
		return none
	}
	if fn_cursor.edge_count() != 4
		|| !autofree_statement_location_cursor_edge_range_is_valid(fn_cursor) {
		return none
	}
	if fn_cursor.flag(ast.flag_is_method) || fn_cursor.flag(ast.flag_is_static) {
		return none
	}
	if unsafe { ast.Language(int(fn_cursor.aux())) } != .v {
		return none
	}
	if fn_cursor.pos().id <= 0 {
		return none
	}
	fn_name := fn_cursor.name()
	if fn_name.len == 0 {
		return none
	}
	typ := autofree_statement_location_child_cursor(fn_cursor, 1, .typ_fn) or { return none }
	body := autofree_statement_location_child_cursor(fn_cursor, 3, .aux_list) or { return none }
	if !typ.is_valid() || !body.is_valid() {
		return none
	}
	return types.autofree_fn_key(file_cursor.mod(), fn_name, '')
}

fn autofree_statement_location_fact_from_body(fn_cursor ast.Cursor, body ast.Cursor, anchor AutofreeCleanCStatementAnchorFact) ?AutofreeCleanCStatementLocationFact {
	mut matches := []AutofreeCleanCStatementLocationFact{}
	for stmt_i in 0 .. body.edge_count() {
		stmt := autofree_statement_location_edge_cursor(body, stmt_i) or { return none }
		if !stmt.is_valid() {
			return none
		}
		if stmt.id != anchor.insert_after_node_id || stmt.pos().id != anchor.insert_after_pos_id {
			continue
		}
		location := autofree_statement_location_fact_from_stmt(fn_cursor, body, stmt, stmt_i,
			anchor) or { continue }
		matches << location
	}
	if matches.len != 1 {
		return none
	}
	return matches[0]
}

fn autofree_statement_location_fact_from_stmt(fn_cursor ast.Cursor, body ast.Cursor, stmt ast.Cursor, stmt_index int, anchor AutofreeCleanCStatementAnchorFact) ?AutofreeCleanCStatementLocationFact {
	if !stmt.is_valid() || stmt.kind() != .stmt_assign {
		return none
	}
	if stmt.id != anchor.insert_after_node_id || stmt.pos().id != anchor.insert_after_pos_id {
		return none
	}
	if autofree_statement_location_stmt_declares_target(stmt, anchor) {
		return autofree_statement_location_fact_from_anchor(fn_cursor, stmt, stmt_index, anchor)
	}
	if !autofree_statement_location_stmt_is_plain_assign(stmt) {
		return none
	}
	if !autofree_statement_location_body_declares_target_before(body, stmt_index, anchor) {
		return none
	}
	return autofree_statement_location_fact_from_anchor(fn_cursor, stmt, stmt_index, anchor)
}

fn autofree_statement_location_stmt_declares_target(stmt ast.Cursor, anchor AutofreeCleanCStatementAnchorFact) bool {
	lhs_ident := autofree_statement_location_decl_lhs_ident(stmt) or { return false }
	return lhs_ident.id == anchor.target_node_id && lhs_ident.pos().id == anchor.target_pos_id
		&& lhs_ident.name() == anchor.name
}

fn autofree_statement_location_stmt_is_plain_assign(stmt ast.Cursor) bool {
	if stmt.extra_int() != 1 || stmt.edge_count() != 2 {
		return false
	}
	if unsafe { token.Token(int(stmt.aux())) } != .assign {
		return false
	}
	if !autofree_statement_location_cursor_edge_range_is_valid(stmt) {
		return false
	}
	lhs := autofree_statement_location_edge_cursor(stmt, 0) or { return false }
	rhs := autofree_statement_location_edge_cursor(stmt, 1) or { return false }
	return lhs.is_valid() && rhs.is_valid()
}

fn autofree_statement_location_body_declares_target_before(body ast.Cursor, stmt_index int, anchor AutofreeCleanCStatementAnchorFact) bool {
	if stmt_index <= 0 {
		return false
	}
	mut matching_names := 0
	mut matching_target := 0
	for i in 0 .. stmt_index {
		stmt := autofree_statement_location_edge_cursor(body, i) or { return false }
		if !stmt.is_valid() {
			return false
		}
		if stmt.kind() != .stmt_assign {
			continue
		}
		lhs_ident := autofree_statement_location_decl_lhs_ident(stmt) or { continue }
		if lhs_ident.name() != anchor.name {
			continue
		}
		matching_names++
		if lhs_ident.id == anchor.target_node_id && lhs_ident.pos().id == anchor.target_pos_id {
			matching_target++
		}
	}
	return matching_names == 1 && matching_target == 1
}

fn autofree_statement_location_fact_from_anchor(fn_cursor ast.Cursor, stmt ast.Cursor, stmt_index int, anchor AutofreeCleanCStatementAnchorFact) AutofreeCleanCStatementLocationFact {
	return AutofreeCleanCStatementLocationFact{
		fn_key:               anchor.fn_key
		fn_name:              fn_cursor.name()
		name:                 anchor.name
		location_status:      .inert
		fn_node_id:           fn_cursor.id
		fn_pos_id:            fn_cursor.pos().id
		target_node_id:       anchor.target_node_id
		target_pos_id:        anchor.target_pos_id
		insert_after_node_id: anchor.insert_after_node_id
		insert_after_pos_id:  anchor.insert_after_pos_id
		stmt_node_id:         stmt.id
		stmt_pos_id:          stmt.pos().id
		stmt_index:           stmt_index
		lhs_index:            0
		reason:               'inert statement location accepted'
	}
}

fn autofree_statement_location_decl_lhs_ident(stmt ast.Cursor) ?ast.Cursor {
	if stmt.extra_int() != 1 || stmt.edge_count() != 2 {
		return none
	}
	if unsafe { token.Token(int(stmt.aux())) } != .decl_assign {
		return none
	}
	if !autofree_statement_location_cursor_edge_range_is_valid(stmt) {
		return none
	}
	lhs := autofree_statement_location_edge_cursor(stmt, 0) or { return none }
	rhs := autofree_statement_location_edge_cursor(stmt, 1) or { return none }
	if !rhs.is_valid() {
		return none
	}
	return autofree_statement_location_direct_lhs_ident(lhs)
}

fn autofree_statement_location_direct_lhs_ident(lhs ast.Cursor) ?ast.Cursor {
	if !lhs.is_valid() {
		return none
	}
	if lhs.kind() == .expr_ident {
		if lhs.edge_count() != 0 {
			return none
		}
		return lhs
	}
	if lhs.kind() != .expr_modifier || unsafe { token.Token(int(lhs.aux())) } != .key_mut
		|| lhs.edge_count() != 1 || !autofree_statement_location_cursor_edge_range_is_valid(lhs) {
		return none
	}
	inner := autofree_statement_location_edge_cursor(lhs, 0) or { return none }
	if !inner.is_valid() || inner.kind() != .expr_ident || inner.edge_count() != 0 {
		return none
	}
	return inner
}

fn autofree_statement_location_anchor_is_valid(anchor AutofreeCleanCStatementAnchorFact) bool {
	if anchor.anchor_status != .inert || anchor.fn_key.len == 0 || anchor.fn_name.len == 0
		|| anchor.name.len == 0 {
		return false
	}
	if anchor.target_node_id < 0 || anchor.target_pos_id <= 0 || anchor.insert_after_node_id < 0
		|| anchor.insert_after_pos_id <= 0 {
		return false
	}
	return anchor.target_node_id != anchor.insert_after_node_id
}

fn autofree_statement_location_file_cursor_is_valid(file_cursor ast.FileCursor) bool {
	if file_cursor.flat == unsafe { nil } || file_cursor.idx < 0
		|| file_cursor.idx >= file_cursor.flat.files.len {
		return false
	}
	root := file_cursor.root()
	return root.is_valid() && root.kind() == .file
}

fn autofree_statement_location_same_flat_ast(left &ast.FlatAst, right &ast.FlatAst) bool {
	if left == unsafe { nil } || right == unsafe { nil } {
		return false
	}
	return unsafe { voidptr(left) == voidptr(right) }
}

fn autofree_statement_location_fn_cursor_belongs_to_file(file_cursor ast.FileCursor, fn_cursor ast.Cursor) bool {
	if !autofree_statement_location_file_cursor_is_valid(file_cursor) {
		return false
	}
	if !fn_cursor.is_valid()
		|| !autofree_statement_location_same_flat_ast(fn_cursor.flat, file_cursor.flat)
		|| fn_cursor.kind() != .stmt_fn_decl {
		return false
	}
	stmts := file_cursor.stmts()
	if !autofree_statement_location_cursor_list_is_valid(stmts, .aux_list) {
		return false
	}
	for i in 0 .. stmts.len() {
		child := stmts.at(i)
		if !child.is_valid() {
			return false
		}
		if child.id == fn_cursor.id {
			return child.kind() == .stmt_fn_decl && child.pos().id == fn_cursor.pos().id
		}
	}
	return false
}

fn autofree_statement_location_cursor_list_is_valid(list ast.CursorList, kind ast.FlatNodeKind) bool {
	if list.flat == unsafe { nil } || list.parent_id < 0 || list.parent_id >= list.flat.nodes.len {
		return false
	}
	if list.offset < 0 {
		return false
	}
	parent := ast.Cursor{
		flat: list.flat
		id:   list.parent_id
	}
	if !parent.is_valid() || parent.kind() != kind || parent.edge_count() < list.offset {
		return false
	}
	return autofree_statement_location_cursor_edge_range_is_valid(parent)
}

fn autofree_statement_location_child_cursor(parent ast.Cursor, edge_i int, kind ast.FlatNodeKind) ?ast.Cursor {
	child := autofree_statement_location_edge_cursor(parent, edge_i) or { return none }
	if !child.is_valid() || child.kind() != kind {
		return none
	}
	return child
}

fn autofree_statement_location_edge_cursor(parent ast.Cursor, edge_i int) ?ast.Cursor {
	if edge_i < 0 || !parent.is_valid()
		|| !autofree_statement_location_cursor_edge_range_is_valid(parent) {
		return none
	}
	if edge_i >= parent.edge_count() {
		return none
	}
	return ast.Cursor{
		flat: parent.flat
		id:   parent.flat.edges[parent.flat.nodes[parent.id].first_edge + edge_i].child_id
	}
}

fn autofree_statement_location_cursor_edge_range_is_valid(cursor ast.Cursor) bool {
	if !cursor.is_valid() {
		return false
	}
	node := cursor.flat.nodes[cursor.id]
	if node.edge_count < 0 {
		return false
	}
	if node.edge_count == 0 {
		return true
	}
	if node.first_edge < 0 || node.first_edge >= cursor.flat.edges.len {
		return false
	}
	return node.edge_count <= cursor.flat.edges.len - node.first_edge
}

fn autofree_statement_location_duplicate_names(anchors []AutofreeCleanCStatementAnchorFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for anchor in anchors {
		name_key := autofree_statement_location_name_key(anchor)
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

fn autofree_statement_location_duplicate_target_positions(anchors []AutofreeCleanCStatementAnchorFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for anchor in anchors {
		target_key := autofree_statement_location_target_position_key(anchor)
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

fn autofree_statement_location_duplicate_slots(anchors []AutofreeCleanCStatementAnchorFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for anchor in anchors {
		slot_key := autofree_statement_location_slot_key(anchor)
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

fn autofree_statement_location_name_key(anchor AutofreeCleanCStatementAnchorFact) string {
	if anchor.fn_key.len == 0 || anchor.name.len == 0 {
		return ''
	}
	return '${anchor.fn_key.len}:${anchor.fn_key}:${anchor.name.len}:${anchor.name}'
}

fn autofree_statement_location_target_position_key(anchor AutofreeCleanCStatementAnchorFact) string {
	if anchor.fn_key.len == 0 || anchor.target_node_id < 0 || anchor.target_pos_id <= 0 {
		return ''
	}
	return '${anchor.fn_key.len}:${anchor.fn_key}:${anchor.target_node_id}:${anchor.target_pos_id}'
}

fn autofree_statement_location_slot_key(anchor AutofreeCleanCStatementAnchorFact) string {
	if anchor.fn_key.len == 0 || anchor.insert_after_node_id < 0 || anchor.insert_after_pos_id <= 0 {
		return ''
	}
	return '${anchor.fn_key.len}:${anchor.fn_key}:${anchor.insert_after_node_id}:${anchor.insert_after_pos_id}'
}
