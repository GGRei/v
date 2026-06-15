// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module cleanc

import v2.ast
import v2.types

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
