// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module cleanc

import v2.ast
import v2.token
import v2.types

// autofree_bridge

enum AutofreeCleanCBridgeStatus {
	unknown
	inert
}

struct AutofreeCleanCBridgeFact {
	fn_key               string
	fn_name              string
	name                 string
	bridge_status        AutofreeCleanCBridgeStatus
	target_node_id       ast.FlatNodeId
	target_pos_id        int
	insert_after_node_id ast.FlatNodeId
	insert_after_pos_id  int
	reason               string
}

fn autofree_bridge_facts_from_insertion_points(points []types.AutofreeReleaseInsertionPointFact) []AutofreeCleanCBridgeFact {
	duplicates := autofree_bridge_duplicate_targets(points)
	mut facts := []AutofreeCleanCBridgeFact{}
	for point in points {
		target_key := autofree_bridge_target_key(point)
		if target_key.len == 0 || target_key in duplicates {
			continue
		}
		fact := autofree_bridge_fact_from_insertion_point(point) or { continue }
		facts << fact
	}
	return facts
}

fn autofree_bridge_duplicate_targets(points []types.AutofreeReleaseInsertionPointFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for point in points {
		target_key := autofree_bridge_target_key(point)
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

fn autofree_bridge_target_key(point types.AutofreeReleaseInsertionPointFact) string {
	if point.fn_key.len == 0 || point.name.len == 0 {
		return ''
	}
	return '${point.fn_key.len}:${point.fn_key}:${point.name.len}:${point.name}'
}

fn autofree_bridge_fact_from_insertion_point(point types.AutofreeReleaseInsertionPointFact) ?AutofreeCleanCBridgeFact {
	source := point.source_endpoint
	target := point.endpoint
	if point.fn_key.len == 0 || point.name.len == 0 {
		return none
	}
	if point.insertion_status != .inert || point.insertion_kind != .after_statement {
		return none
	}
	if !autofree_bridge_move_kind_is_supported(point.move_kind) || point.plan_kind != .natural_exit
		|| point.preflight_status != .inert {
		return none
	}
	if point.plan_action != .array_container_cleanup || point.helper_requirement != .none {
		return none
	}
	if point.insert_after_node_id != point.release_after_node_id
		|| point.insert_after_pos_id != point.release_after_pos_id {
		return none
	}
	if point.node_id < 0 || point.pos_id <= 0 || point.proof_node_id < 0 || point.proof_pos_id <= 0
		|| point.release_after_node_id < 0 || point.release_after_pos_id <= 0
		|| point.insert_after_node_id < 0 || point.insert_after_pos_id <= 0 {
		return none
	}
	if point.node_id != point.proof_node_id || point.pos_id != point.proof_pos_id
		|| point.node_id != target.node_id || point.pos_id != target.pos_id {
		return none
	}
	if point.release_after_node_id == target.node_id {
		return none
	}
	if source.node_id == target.node_id || source.node_id == point.proof_node_id {
		return none
	}
	if point.release_after_node_id == source.node_id || point.insert_after_node_id == source.node_id {
		return none
	}
	if target.storage != .local || target.root_storage != .local || target.path.len != 0 {
		return none
	}
	if target.node_id < 0 || target.pos_id <= 0 || target.name != point.name
		|| target.root_name != point.name || target.root_node_id != target.node_id
		|| target.root_pos_id != target.pos_id {
		return none
	}
	if !source.has_type || !target.has_type || !types.type_has_valid_payload(source.typ)
		|| !types.type_has_valid_payload(target.typ) || !types.type_has_valid_payload(point.typ) {
		return none
	}
	canonical_type_name := point.typ.name()
	if canonical_type_name.len == 0 || point.type_name.len == 0 || source.type_name.len == 0
		|| target.type_name.len == 0 || point.type_name != canonical_type_name
		|| source.type_name != canonical_type_name || target.type_name != canonical_type_name
		|| source.typ.name() != canonical_type_name || target.typ.name() != canonical_type_name {
		return none
	}
	if point.state != .owned_unique || target.state != .owned_unique {
		return none
	}
	if point.resource != .array_value || source.resource != .array_value
		|| target.resource != .array_value {
		return none
	}
	shape := point.shape
	if !autofree_bridge_source_endpoint_is_allowed(point.move_kind, shape, source) {
		return none
	}
	if !autofree_bridge_shapes_match(shape, source.shape)
		|| !autofree_bridge_shapes_match(shape, target.shape) {
		return none
	}
	return AutofreeCleanCBridgeFact{
		fn_key:               point.fn_key
		fn_name:              point.fn_name
		name:                 point.name
		bridge_status:        .inert
		target_node_id:       target.node_id
		target_pos_id:        target.pos_id
		insert_after_node_id: point.insert_after_node_id
		insert_after_pos_id:  point.insert_after_pos_id
		reason:               'inert bridge accepted'
	}
}

fn autofree_bridge_move_kind_is_supported(kind types.AutofreeMoveProofKind) bool {
	return kind == .fresh_local_binding || kind == .local_array_clone_binding
}

fn autofree_bridge_source_endpoint_is_allowed(kind types.AutofreeMoveProofKind, shape types.AutofreeResourceShape, source types.AutofreeTransferEndpoint) bool {
	match kind {
		.fresh_local_binding {
			return autofree_bridge_empty_array_container_shape_is_allowed(shape, source)
				|| autofree_bridge_cap_only_array_container_shape_is_allowed(shape, source)
				|| autofree_bridge_len_only_array_container_shape_is_allowed(shape, source)
		}
		.local_array_clone_binding {
			return autofree_bridge_local_array_clone_source_is_allowed(shape, source)
		}
		else {
			return false
		}
	}
}

fn autofree_bridge_empty_array_container_shape_is_allowed(shape types.AutofreeResourceShape, source types.AutofreeTransferEndpoint) bool {
	if shape.kind != .array || shape.fail_closed || !shape.needs_autofree() {
		return false
	}
	if source.storage != .literal || source.root_storage != .literal || source.path.len != 0
		|| source.state != .owned_unique || source.reason != 'empty dynamic array literal' {
		return false
	}
	if source.node_id < 0 || source.pos_id <= 0 || source.root_node_id != source.node_id
		|| source.root_pos_id != source.pos_id || source.name.len == 0
		|| source.root_name != source.name {
		return false
	}
	return shape.target_kind == .no_resource || shape.target_kind == .string_
}

fn autofree_bridge_cap_only_array_container_shape_is_allowed(shape types.AutofreeResourceShape, source types.AutofreeTransferEndpoint) bool {
	if shape.kind != .array || shape.fail_closed || !shape.needs_autofree()
		|| shape.target_kind != .no_resource {
		return false
	}
	if source.storage != .literal || source.root_storage != .literal || source.path.len != 0
		|| source.state != .owned_unique || source.reason != 'cap-only scalar array literal' {
		return false
	}
	if source.node_id < 0 || source.pos_id <= 0 || source.root_node_id != source.node_id
		|| source.root_pos_id != source.pos_id || source.name.len == 0
		|| source.root_name != source.name {
		return false
	}
	return true
}

fn autofree_bridge_len_only_array_container_shape_is_allowed(shape types.AutofreeResourceShape, source types.AutofreeTransferEndpoint) bool {
	if shape.kind != .array || shape.fail_closed || !shape.needs_autofree()
		|| shape.target_kind != .no_resource {
		return false
	}
	if source.storage != .literal || source.root_storage != .literal || source.path.len != 0
		|| source.state != .owned_unique || source.reason != 'len-only scalar array literal' {
		return false
	}
	if source.node_id < 0 || source.pos_id <= 0 || source.root_node_id != source.node_id
		|| source.root_pos_id != source.pos_id || source.name.len == 0
		|| source.root_name != source.name {
		return false
	}
	return true
}

fn autofree_bridge_local_array_clone_source_is_allowed(shape types.AutofreeResourceShape, source types.AutofreeTransferEndpoint) bool {
	if shape.kind != .array || shape.fail_closed || !shape.needs_autofree()
		|| shape.target_kind != .no_resource {
		return false
	}
	if source.storage != .parameter || source.root_storage != .parameter {
		return false
	}
	if source.path.len != 0 || source.state != .ambiguous_no_free {
		return false
	}
	return source.root_node_id >= 0 && source.root_pos_id > 0 && source.node_id >= 0
		&& source.pos_id > 0 && source.name.len > 0 && source.root_name == source.name
}

fn autofree_bridge_shapes_match(a types.AutofreeResourceShape, b types.AutofreeResourceShape) bool {
	return a.kind == b.kind && a.identity == b.identity && a.target_kind == b.target_kind
		&& a.target_identity == b.target_identity && a.map_container_owned == b.map_container_owned
		&& a.map_container_may_need_free == b.map_container_may_need_free
		&& a.map_key_kind == b.map_key_kind && a.map_key_identity == b.map_key_identity
		&& a.map_key_owned == b.map_key_owned && a.map_key_may_need_free == b.map_key_may_need_free
		&& a.map_value_kind == b.map_value_kind && a.map_value_identity == b.map_value_identity
		&& a.map_value_owned == b.map_value_owned
		&& a.map_value_may_need_free == b.map_value_may_need_free
		&& a.has_owned_resource == b.has_owned_resource && a.may_need_free == b.may_need_free
		&& a.fail_closed == b.fail_closed && a.needs_autofree() == b.needs_autofree()
}

// autofree_statement_adapter

enum AutofreeCleanCStatementAnchorStatus {
	unknown
	inert
}

struct AutofreeCleanCStatementAnchorFact {
	fn_key               string
	fn_name              string
	name                 string
	anchor_status        AutofreeCleanCStatementAnchorStatus
	target_node_id       ast.FlatNodeId
	target_pos_id        int
	insert_after_node_id ast.FlatNodeId
	insert_after_pos_id  int
	reason               string
}

fn autofree_statement_anchor_facts_from_bridge_facts(facts []AutofreeCleanCBridgeFact) []AutofreeCleanCStatementAnchorFact {
	duplicate_names := autofree_statement_anchor_duplicate_names(facts)
	duplicate_targets := autofree_statement_anchor_duplicate_target_positions(facts)
	duplicate_positions := autofree_statement_anchor_duplicate_positions(facts)
	mut anchors := []AutofreeCleanCStatementAnchorFact{}
	for fact in facts {
		name_key := autofree_statement_anchor_name_key(fact)
		target_key := autofree_statement_anchor_target_position_key(fact)
		position_key := autofree_statement_anchor_position_key(fact)
		if name_key.len == 0 || name_key in duplicate_names || target_key.len == 0
			|| target_key in duplicate_targets || position_key.len == 0
			|| position_key in duplicate_positions {
			continue
		}
		anchor := autofree_statement_anchor_fact_from_bridge_fact(fact) or { continue }
		anchors << anchor
	}
	return anchors
}

fn autofree_statement_anchor_fact_from_bridge_fact(fact AutofreeCleanCBridgeFact) ?AutofreeCleanCStatementAnchorFact {
	if fact.bridge_status != .inert || fact.fn_key.len == 0 || fact.name.len == 0 {
		return none
	}
	if fact.target_node_id < 0 || fact.target_pos_id <= 0 || fact.insert_after_node_id < 0
		|| fact.insert_after_pos_id <= 0 {
		return none
	}
	if fact.target_node_id == fact.insert_after_node_id {
		return none
	}
	return AutofreeCleanCStatementAnchorFact{
		fn_key:               fact.fn_key
		fn_name:              fact.fn_name
		name:                 fact.name
		anchor_status:        .inert
		target_node_id:       fact.target_node_id
		target_pos_id:        fact.target_pos_id
		insert_after_node_id: fact.insert_after_node_id
		insert_after_pos_id:  fact.insert_after_pos_id
		reason:               'inert statement anchor accepted'
	}
}

fn autofree_statement_anchor_duplicate_names(facts []AutofreeCleanCBridgeFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for fact in facts {
		name_key := autofree_statement_anchor_name_key(fact)
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

fn autofree_statement_anchor_duplicate_target_positions(facts []AutofreeCleanCBridgeFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for fact in facts {
		target_key := autofree_statement_anchor_target_position_key(fact)
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

fn autofree_statement_anchor_duplicate_positions(facts []AutofreeCleanCBridgeFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for fact in facts {
		position_key := autofree_statement_anchor_position_key(fact)
		if position_key.len == 0 {
			continue
		}
		if position_key in seen {
			duplicates[position_key] = true
			continue
		}
		seen[position_key] = true
	}
	return duplicates
}

fn autofree_statement_anchor_name_key(fact AutofreeCleanCBridgeFact) string {
	if fact.fn_key.len == 0 || fact.name.len == 0 {
		return ''
	}
	return '${fact.fn_key.len}:${fact.fn_key}:${fact.name.len}:${fact.name}'
}

fn autofree_statement_anchor_target_position_key(fact AutofreeCleanCBridgeFact) string {
	if fact.fn_key.len == 0 || fact.target_node_id < 0 || fact.target_pos_id <= 0 {
		return ''
	}
	return '${fact.fn_key.len}:${fact.fn_key}:${fact.target_node_id}:${fact.target_pos_id}'
}

fn autofree_statement_anchor_position_key(fact AutofreeCleanCBridgeFact) string {
	if fact.fn_key.len == 0 || fact.insert_after_node_id < 0 || fact.insert_after_pos_id <= 0 {
		return ''
	}
	return '${fact.fn_key.len}:${fact.fn_key}:${fact.insert_after_node_id}:${fact.insert_after_pos_id}'
}

// autofree_statement_locator

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

// autofree_statement_preview

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

// autofree_statement_intent

enum AutofreeCleanCStatementIntentStatus {
	unknown
	inert
}

enum AutofreeCleanCStatementIntentKind {
	unknown
	after_statement
}

struct AutofreeCleanCStatementIntentFact {
	fn_key               string
	fn_name              string
	name                 string
	intent_status        AutofreeCleanCStatementIntentStatus
	intent_kind          AutofreeCleanCStatementIntentKind
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

fn autofree_statement_intent_facts_from_previews(previews []AutofreeCleanCStatementPreviewFact) []AutofreeCleanCStatementIntentFact {
	if previews.len != 1 {
		return []AutofreeCleanCStatementIntentFact{}
	}
	intent := autofree_statement_intent_fact_from_preview(previews[0]) or {
		return []AutofreeCleanCStatementIntentFact{}
	}
	return [intent]
}

fn autofree_statement_intent_fact_from_preview(preview AutofreeCleanCStatementPreviewFact) ?AutofreeCleanCStatementIntentFact {
	if preview.preview_status != .inert || preview.fn_key.len == 0 || preview.fn_name.len == 0
		|| preview.name.len == 0 {
		return none
	}
	if preview.fn_node_id < 0 || preview.fn_pos_id <= 0 || preview.target_node_id < 0
		|| preview.target_pos_id <= 0 || preview.stmt_node_id < 0 || preview.stmt_pos_id <= 0
		|| preview.insert_after_node_id < 0 || preview.insert_after_pos_id <= 0 {
		return none
	}
	if preview.stmt_node_id != preview.insert_after_node_id
		|| preview.stmt_pos_id != preview.insert_after_pos_id {
		return none
	}
	if preview.target_node_id == preview.insert_after_node_id {
		return none
	}
	if preview.stmt_index < 0 || preview.lhs_index != 0 {
		return none
	}
	return AutofreeCleanCStatementIntentFact{
		fn_key:               preview.fn_key
		fn_name:              preview.fn_name
		name:                 preview.name
		intent_status:        .inert
		intent_kind:          .after_statement
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
		reason:               'inert statement intent accepted'
	}
}

// autofree_statement_emission_slot

enum AutofreeCleanCStatementEmissionSlotStatus {
	unknown
	inert
}

enum AutofreeCleanCStatementEmissionSlotKind {
	unknown
	after_statement
}

struct AutofreeCleanCStatementEmissionSlotFact {
	fn_key               string
	fn_name              string
	name                 string
	slot_status          AutofreeCleanCStatementEmissionSlotStatus
	slot_kind            AutofreeCleanCStatementEmissionSlotKind
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

fn autofree_statement_emission_slot_facts_from_intents(intents []AutofreeCleanCStatementIntentFact) []AutofreeCleanCStatementEmissionSlotFact {
	if intents.len != 1 {
		return []AutofreeCleanCStatementEmissionSlotFact{}
	}
	slot := autofree_statement_emission_slot_fact_from_intent(intents[0]) or {
		return []AutofreeCleanCStatementEmissionSlotFact{}
	}
	return [slot]
}

fn autofree_statement_emission_slot_fact_from_intent(intent AutofreeCleanCStatementIntentFact) ?AutofreeCleanCStatementEmissionSlotFact {
	if intent.intent_status != .inert || intent.intent_kind != .after_statement
		|| intent.fn_key.len == 0 || intent.fn_name.len == 0 || intent.name.len == 0 {
		return none
	}
	if intent.fn_node_id < 0 || intent.fn_pos_id <= 0 || intent.target_node_id < 0
		|| intent.target_pos_id <= 0 || intent.stmt_node_id < 0 || intent.stmt_pos_id <= 0
		|| intent.insert_after_node_id < 0 || intent.insert_after_pos_id <= 0 {
		return none
	}
	if intent.stmt_node_id != intent.insert_after_node_id
		|| intent.stmt_pos_id != intent.insert_after_pos_id {
		return none
	}
	if intent.target_node_id == intent.insert_after_node_id {
		return none
	}
	if intent.stmt_index < 0 || intent.lhs_index != 0 {
		return none
	}
	return AutofreeCleanCStatementEmissionSlotFact{
		fn_key:               intent.fn_key
		fn_name:              intent.fn_name
		name:                 intent.name
		slot_status:          .inert
		slot_kind:            .after_statement
		fn_node_id:           intent.fn_node_id
		fn_pos_id:            intent.fn_pos_id
		target_node_id:       intent.target_node_id
		target_pos_id:        intent.target_pos_id
		stmt_node_id:         intent.stmt_node_id
		stmt_pos_id:          intent.stmt_pos_id
		insert_after_node_id: intent.insert_after_node_id
		insert_after_pos_id:  intent.insert_after_pos_id
		stmt_index:           intent.stmt_index
		lhs_index:            intent.lhs_index
		reason:               'inert statement emission slot accepted'
	}
}

// autofree_statement_cleanup_preview

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

// autofree_statement_cleanup_hook_preview

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
	if !autofree_statement_location_cursor_edge_range_is_valid(body) {
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
	if !autofree_statement_cleanup_hook_preview_stmt_matches_preview(body, stmt, preview) {
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

fn autofree_statement_cleanup_hook_preview_stmt_matches_preview(body ast.Cursor, stmt ast.Cursor, preview AutofreeCleanCStatementCleanupPreviewFact) bool {
	if !stmt.is_valid() || stmt.kind() != .stmt_assign {
		return false
	}
	if stmt.id != preview.stmt_node_id || stmt.pos().id != preview.stmt_pos_id
		|| stmt.id != preview.insert_after_node_id || stmt.pos().id != preview.insert_after_pos_id {
		return false
	}
	anchor := AutofreeCleanCStatementAnchorFact{
		fn_key:               preview.fn_key
		fn_name:              preview.fn_name
		name:                 preview.name
		anchor_status:        .inert
		target_node_id:       preview.target_node_id
		target_pos_id:        preview.target_pos_id
		insert_after_node_id: preview.insert_after_node_id
		insert_after_pos_id:  preview.insert_after_pos_id
		reason:               preview.reason
	}
	if autofree_statement_location_stmt_declares_target(stmt, anchor) {
		return true
	}
	return autofree_statement_location_stmt_is_plain_assign(stmt)
		&& autofree_statement_location_body_declares_target_before(body, preview.stmt_index, anchor)
}

// autofree_statement_cleanup_emit_context

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

// autofree_statement_cleanup_emit

fn (mut g Gen) autofree_clear_statement_cleanup_emit_context() {
	g.autofree_cleanup_emit_context = AutofreeCleanCStatementCleanupEmitContextFact{}
	g.has_autofree_cleanup_emit_context = false
	g.autofree_cleanup_emit_context_consumed = false
	g.autofree_cleanup_emit_context_prepared = false
	g.autofree_cleanup_emit_fn_key = ''
	g.autofree_cleanup_emit_fn_node_id = ast.invalid_flat_node_id
	g.autofree_cleanup_emit_fn_pos_id = 0
}

fn (mut g Gen) gen_fn_decl_ptr_with_autofree_cleanup_context(file_cursor ast.FileCursor, fn_cursor ast.Cursor) {
	g.autofree_prepare_statement_cleanup_emit_context(file_cursor, fn_cursor)
	defer {
		g.autofree_clear_statement_cleanup_emit_context()
	}
	fn_decl := fn_cursor.fn_decl()
	g.gen_fn_decl_ptr(&fn_decl)
}

fn (mut g Gen) autofree_prepare_statement_cleanup_emit_context(file_cursor ast.FileCursor, fn_cursor ast.Cursor) {
	g.autofree_clear_statement_cleanup_emit_context()
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(file_cursor, fn_cursor) or {
		return
	}
	contexts := g.autofree_statement_cleanup_emit_contexts_from_file_cursor(file_cursor, fn_cursor)
	if contexts.len != 1 {
		return
	}
	context := contexts[0]
	if !autofree_statement_cleanup_emit_context_is_valid(context) || context.fn_key != fn_key {
		return
	}
	g.autofree_cleanup_emit_context = context
	g.has_autofree_cleanup_emit_context = true
	g.autofree_cleanup_emit_context_prepared = true
	g.autofree_cleanup_emit_fn_key = fn_key
	g.autofree_cleanup_emit_fn_node_id = fn_cursor.id
	g.autofree_cleanup_emit_fn_pos_id = fn_cursor.pos().id
}

fn (g &Gen) autofree_statement_cleanup_emit_contexts_from_file_cursor(file_cursor ast.FileCursor, fn_cursor ast.Cursor) []AutofreeCleanCStatementCleanupEmitContextFact {
	if g.pref == unsafe { nil } || !g.pref.autofree || g.pref.is_freestanding()
		|| g.env == unsafe { nil } {
		return []AutofreeCleanCStatementCleanupEmitContextFact{}
	}
	if g.flat == unsafe { nil } || file_cursor.flat == unsafe { nil } || file_cursor.flat != g.flat
		|| fn_cursor.flat != file_cursor.flat {
		return []AutofreeCleanCStatementCleanupEmitContextFact{}
	}
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(file_cursor, fn_cursor) or {
		return []AutofreeCleanCStatementCleanupEmitContextFact{}
	}
	points := g.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		return []AutofreeCleanCStatementCleanupEmitContextFact{}
	}
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, anchors)
	previews := autofree_statement_preview_facts_from_file_cursor(file_cursor, fn_cursor, locations)
	intents := autofree_statement_intent_facts_from_previews(previews)
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(file_cursor,
		fn_cursor, cleanup_previews)
	return autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
}

fn (g &Gen) autofree_statement_cleanup_emit_fn_key_from_cursor(file_cursor ast.FileCursor, fn_cursor ast.Cursor) ?string {
	if g.flat == unsafe { nil } || file_cursor.flat == unsafe { nil } || file_cursor.flat != g.flat
		|| fn_cursor.flat != file_cursor.flat {
		return none
	}
	return autofree_statement_location_fn_key_from_file_cursor(file_cursor, fn_cursor)
}

fn (mut g Gen) autofree_emit_statement_cleanup_context(fn_name string, node &ast.FnDecl) {
	if g.pref == unsafe { nil } || !g.pref.autofree || g.pref.is_freestanding()
		|| !g.has_autofree_cleanup_emit_context || g.autofree_cleanup_emit_context_consumed
		|| !g.autofree_cleanup_emit_context_prepared {
		return
	}
	context := g.autofree_cleanup_emit_context
	if !g.autofree_statement_cleanup_emit_context_matches_current_fn(context, fn_name, node) {
		return
	}
	g.autofree_cleanup_emit_context_consumed = true
	g.write_indent()
	g.sb.writeln(context.cleanup_text)
}

fn (g &Gen) autofree_statement_cleanup_emit_context_matches_current_fn(context AutofreeCleanCStatementCleanupEmitContextFact, fn_name string, node &ast.FnDecl) bool {
	return autofree_statement_cleanup_emit_context_is_valid(context) && fn_name.len > 0
		&& context.fn_key == g.autofree_cleanup_emit_fn_key && context.fn_key == fn_name
		&& context.fn_name == node.name && context.fn_node_id == g.autofree_cleanup_emit_fn_node_id
		&& context.fn_pos_id == g.autofree_cleanup_emit_fn_pos_id
		&& context.fn_pos_id == node.pos.id
}

fn autofree_statement_cleanup_emit_context_is_valid(context AutofreeCleanCStatementCleanupEmitContextFact) bool {
	if context.context_status != .inert
		|| context.context_kind != .after_body_before_scheduled_drops || context.fn_key.len == 0
		|| context.fn_name.len == 0 || context.name.len == 0 || context.context_key.len == 0 {
		return false
	}
	if context.fn_node_id < 0 || context.fn_pos_id <= 0 || context.target_node_id < 0
		|| context.target_pos_id <= 0 || context.stmt_node_id < 0 || context.stmt_pos_id <= 0
		|| context.insert_after_node_id < 0 || context.insert_after_pos_id <= 0 {
		return false
	}
	if context.stmt_node_id != context.insert_after_node_id
		|| context.stmt_pos_id != context.insert_after_pos_id {
		return false
	}
	if context.target_node_id == context.insert_after_node_id {
		return false
	}
	if context.stmt_index < 0 || context.lhs_index != 0 {
		return false
	}
	target_c_name := c_local_name(context.name)
	expected_key := '${context.fn_key}:${context.fn_node_id}:${context.fn_pos_id}:${context.target_node_id}:${context.target_pos_id}:${context.insert_after_node_id}:${context.insert_after_pos_id}:${context.name}'
	return target_c_name.len > 0 && context.target_c_name == target_c_name
		&& context.cleanup_symbol == 'array__free'
		&& context.cleanup_text == '${context.cleanup_symbol}(&${target_c_name});'
		&& context.context_key == expected_key
}
