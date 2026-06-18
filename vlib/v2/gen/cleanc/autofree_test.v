module cleanc

import os
import strings
import v2.ast
import v2.parser
import v2.pref as vpref
import v2.token
import v2.transformer
import v2.types

// autofree_bridge_test

fn autofree_bridge_test_array_type() types.Type {
	return types.Type(types.Array{
		elem_type: types.Type(types.int_)
	})
}

fn autofree_bridge_test_string_array_type() types.Type {
	return types.Type(types.Array{
		elem_type: types.Type(types.string_)
	})
}

fn autofree_bridge_test_string_type() types.Type {
	return types.Type(types.string_)
}

fn autofree_bridge_test_array_shape() types.AutofreeResourceShape {
	return types.AutofreeResourceShape{
		kind:               .array
		identity:           '[]int'
		target_kind:        .no_resource
		target_identity:    'int'
		has_owned_resource: true
		may_need_free:      true
	}
}

fn autofree_bridge_test_string_array_shape() types.AutofreeResourceShape {
	return types.AutofreeResourceShape{
		kind:               .array
		identity:           '[]string'
		target_kind:        .string_
		target_identity:    'string'
		has_owned_resource: true
		may_need_free:      true
	}
}

fn autofree_bridge_test_no_resource_shape() types.AutofreeResourceShape {
	return types.AutofreeResourceShape{
		kind:            .no_resource
		identity:        'int'
		target_kind:     .no_resource
		target_identity: 'int'
	}
}

fn autofree_bridge_test_string_shape() types.AutofreeResourceShape {
	return types.AutofreeResourceShape{
		kind:               .string_
		identity:           'string'
		target_kind:        .no_resource
		target_identity:    ''
		has_owned_resource: true
		may_need_free:      true
	}
}

fn autofree_bridge_test_fresh_string_clone_push_source_endpoint() types.AutofreeTransferEndpoint {
	string_type := autofree_bridge_test_string_type()
	string_shape := autofree_bridge_test_string_shape()
	string_type_name := string_type.name()
	return types.AutofreeTransferEndpoint{
		storage:      .call_result
		root_storage: .call_result
		root_name:    'string__plus'
		name:         'string__plus'
		root_node_id: 8
		root_pos_id:  130
		node_id:      8
		pos_id:       130
		has_type:     true
		typ:          string_type
		type_name:    string_type_name
		resource:     .string_value
		shape:        string_shape
		state:        .owned_unique
		reason:       'owned string plus call result'
	}
}

fn autofree_bridge_test_fail_closed_shape() types.AutofreeResourceShape {
	return types.AutofreeResourceShape{
		...autofree_bridge_test_array_shape()
		fail_closed: true
	}
}

fn autofree_bridge_test_source_endpoint() types.AutofreeTransferEndpoint {
	array_type := autofree_bridge_test_array_type()
	array_shape := autofree_bridge_test_array_shape()
	array_type_name := array_type.name()
	return types.AutofreeTransferEndpoint{
		storage:      .literal
		root_storage: .literal
		root_name:    'array literal'
		name:         'array literal'
		root_node_id: 2
		root_pos_id:  90
		node_id:      2
		pos_id:       90
		has_type:     true
		typ:          array_type
		type_name:    array_type_name
		resource:     .array_value
		shape:        array_shape
		state:        .owned_unique
		reason:       'empty dynamic array literal'
	}
}

fn autofree_bridge_test_string_array_source_endpoint() types.AutofreeTransferEndpoint {
	array_type := autofree_bridge_test_string_array_type()
	array_shape := autofree_bridge_test_string_array_shape()
	array_type_name := array_type.name()
	return types.AutofreeTransferEndpoint{
		...autofree_bridge_test_source_endpoint()
		typ:       array_type
		type_name: array_type_name
		shape:     array_shape
	}
}

fn autofree_bridge_test_cap_only_source_endpoint() types.AutofreeTransferEndpoint {
	return types.AutofreeTransferEndpoint{
		...autofree_bridge_test_source_endpoint()
		root_name: 'cap array literal'
		name:      'cap array literal'
		reason:    'cap-only scalar array literal'
	}
}

fn autofree_bridge_test_len_only_source_endpoint() types.AutofreeTransferEndpoint {
	return types.AutofreeTransferEndpoint{
		...autofree_bridge_test_source_endpoint()
		root_name: 'len array literal'
		name:      'len array literal'
		reason:    'len-only scalar array literal'
	}
}

fn autofree_bridge_test_string_array_cap_only_source_endpoint() types.AutofreeTransferEndpoint {
	array_type := autofree_bridge_test_string_array_type()
	array_shape := autofree_bridge_test_string_array_shape()
	array_type_name := array_type.name()
	return types.AutofreeTransferEndpoint{
		...autofree_bridge_test_cap_only_source_endpoint()
		typ:       array_type
		type_name: array_type_name
		shape:     array_shape
	}
}

fn autofree_bridge_test_string_array_len_only_source_endpoint() types.AutofreeTransferEndpoint {
	array_type := autofree_bridge_test_string_array_type()
	array_shape := autofree_bridge_test_string_array_shape()
	array_type_name := array_type.name()
	return types.AutofreeTransferEndpoint{
		...autofree_bridge_test_len_only_source_endpoint()
		typ:       array_type
		type_name: array_type_name
		shape:     array_shape
	}
}

fn autofree_bridge_test_target_endpoint() types.AutofreeTransferEndpoint {
	array_type := autofree_bridge_test_array_type()
	array_shape := autofree_bridge_test_array_shape()
	array_type_name := array_type.name()
	return types.AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    'items'
		name:         'items'
		root_node_id: 5
		root_pos_id:  120
		node_id:      5
		pos_id:       120
		has_type:     true
		typ:          array_type
		type_name:    array_type_name
		resource:     .array_value
		shape:        array_shape
		state:        .owned_unique
		reason:       'fresh local'
	}
}

fn autofree_bridge_test_string_array_target_endpoint() types.AutofreeTransferEndpoint {
	array_type := autofree_bridge_test_string_array_type()
	array_shape := autofree_bridge_test_string_array_shape()
	array_type_name := array_type.name()
	return types.AutofreeTransferEndpoint{
		...autofree_bridge_test_target_endpoint()
		typ:       array_type
		type_name: array_type_name
		shape:     array_shape
	}
}

fn autofree_bridge_test_local_array_clone_source_endpoint() types.AutofreeTransferEndpoint {
	array_type := autofree_bridge_test_array_type()
	array_shape := autofree_bridge_test_array_shape()
	array_type_name := array_type.name()
	return types.AutofreeTransferEndpoint{
		storage:      .parameter
		root_storage: .parameter
		root_name:    'gen'
		name:         'gen'
		root_node_id: 3
		root_pos_id:  80
		node_id:      4
		pos_id:       130
		has_type:     true
		typ:          array_type
		type_name:    array_type_name
		resource:     .array_value
		shape:        array_shape
		state:        .ambiguous_no_free
		reason:       'local scalar array clone source'
	}
}

fn autofree_bridge_test_local_array_clone_target_endpoint() types.AutofreeTransferEndpoint {
	return types.AutofreeTransferEndpoint{
		...autofree_bridge_test_target_endpoint()
		root_name: 'arr'
		name:      'arr'
		reason:    'local scalar array clone target'
	}
}

fn autofree_bridge_test_loop_local_clone_push_source_endpoint() types.AutofreeTransferEndpoint {
	return types.AutofreeTransferEndpoint{
		...autofree_bridge_test_len_only_source_endpoint()
		reason: 'len-only scalar array literal'
	}
}

fn autofree_bridge_test_loop_local_clone_push_target_endpoint() types.AutofreeTransferEndpoint {
	return types.AutofreeTransferEndpoint{
		...autofree_bridge_test_target_endpoint()
		root_name: 'row'
		name:      'row'
		reason:    'loop local clone push target'
	}
}

fn autofree_bridge_test_fresh_string_clone_push_target_endpoint() types.AutofreeTransferEndpoint {
	string_type := autofree_bridge_test_string_type()
	string_shape := autofree_bridge_test_string_shape()
	string_type_name := string_type.name()
	return types.AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    'text'
		name:         'text'
		root_node_id: 9
		root_pos_id:  120
		node_id:      9
		pos_id:       120
		has_type:     true
		typ:          string_type
		type_name:    string_type_name
		resource:     .string_value
		shape:        string_shape
		state:        .owned_unique
		reason:       'fresh local string clone push target'
	}
}

fn autofree_bridge_test_valid_insertion_point() types.AutofreeReleaseInsertionPointFact {
	array_type := autofree_bridge_test_array_type()
	array_shape := autofree_bridge_test_array_shape()
	array_type_name := array_type.name()
	return types.AutofreeReleaseInsertionPointFact{
		fn_key:                'make_items'
		fn_name:               'make_items'
		name:                  'items'
		move_kind:             .fresh_local_binding
		plan_kind:             .natural_exit
		plan_action:           .array_container_cleanup
		helper_requirement:    .none
		preflight_status:      .inert
		insertion_kind:        .after_statement
		insertion_status:      .inert
		source_endpoint:       autofree_bridge_test_source_endpoint()
		endpoint:              autofree_bridge_test_target_endpoint()
		state:                 .owned_unique
		resource:              .array_value
		shape:                 array_shape
		typ:                   array_type
		type_name:             array_type_name
		node_id:               5
		pos_id:                120
		proof_node_id:         5
		proof_pos_id:          120
		release_after_node_id: 7
		release_after_pos_id:  210
		insert_after_node_id:  7
		insert_after_pos_id:   210
		reason:                'release insertion point accepted'
	}
}

fn autofree_bridge_test_cap_only_insertion_point() types.AutofreeReleaseInsertionPointFact {
	return types.AutofreeReleaseInsertionPointFact{
		...autofree_bridge_test_valid_insertion_point()
		fn_key:          'build_array_with_cap'
		fn_name:         'build_array_with_cap'
		source_endpoint: autofree_bridge_test_cap_only_source_endpoint()
	}
}

fn autofree_bridge_test_len_only_insertion_point() types.AutofreeReleaseInsertionPointFact {
	return types.AutofreeReleaseInsertionPointFact{
		...autofree_bridge_test_valid_insertion_point()
		fn_key:          'build_array_with_len'
		fn_name:         'build_array_with_len'
		source_endpoint: autofree_bridge_test_len_only_source_endpoint()
	}
}

fn autofree_bridge_test_local_array_clone_insertion_point() types.AutofreeReleaseInsertionPointFact {
	array_type := autofree_bridge_test_array_type()
	array_shape := autofree_bridge_test_array_shape()
	array_type_name := array_type.name()
	target := autofree_bridge_test_local_array_clone_target_endpoint()
	return types.AutofreeReleaseInsertionPointFact{
		fn_key:                'next_generation'
		fn_name:               'next_generation'
		name:                  'arr'
		move_kind:             .local_array_clone_binding
		plan_kind:             .natural_exit
		plan_action:           .array_container_cleanup
		helper_requirement:    .none
		preflight_status:      .inert
		insertion_kind:        .after_statement
		insertion_status:      .inert
		source_endpoint:       autofree_bridge_test_local_array_clone_source_endpoint()
		endpoint:              target
		state:                 .owned_unique
		resource:              .array_value
		shape:                 array_shape
		typ:                   array_type
		type_name:             array_type_name
		node_id:               target.node_id
		pos_id:                target.pos_id
		proof_node_id:         target.node_id
		proof_pos_id:          target.pos_id
		release_after_node_id: 10
		release_after_pos_id:  202
		insert_after_node_id:  10
		insert_after_pos_id:   202
		reason:                'release insertion point accepted'
	}
}

fn autofree_bridge_test_loop_local_clone_push_insertion_point() types.AutofreeReleaseInsertionPointFact {
	array_type := autofree_bridge_test_array_type()
	array_shape := autofree_bridge_test_array_shape()
	array_type_name := array_type.name()
	target := autofree_bridge_test_loop_local_clone_push_target_endpoint()
	return types.AutofreeReleaseInsertionPointFact{
		fn_key:                'Board__fill_rows'
		fn_name:               'fill_rows'
		name:                  'row'
		move_kind:             .loop_local_clone_push_binding
		plan_kind:             .natural_exit
		plan_action:           .array_container_cleanup
		helper_requirement:    .none
		preflight_status:      .inert
		insertion_kind:        .after_statement
		insertion_status:      .inert
		source_endpoint:       autofree_bridge_test_loop_local_clone_push_source_endpoint()
		endpoint:              target
		state:                 .owned_unique
		resource:              .array_value
		shape:                 array_shape
		typ:                   array_type
		type_name:             array_type_name
		node_id:               target.node_id
		pos_id:                target.pos_id
		proof_node_id:         target.node_id
		proof_pos_id:          target.pos_id
		release_after_node_id: 12
		release_after_pos_id:  203
		insert_after_node_id:  12
		insert_after_pos_id:   203
		reason:                'release insertion point accepted'
	}
}

fn autofree_bridge_test_fresh_string_clone_push_insertion_point() types.AutofreeReleaseInsertionPointFact {
	string_type := autofree_bridge_test_string_type()
	string_shape := autofree_bridge_test_string_shape()
	string_type_name := string_type.name()
	target := autofree_bridge_test_fresh_string_clone_push_target_endpoint()
	return types.AutofreeReleaseInsertionPointFact{
		fn_key:                'push_joined'
		fn_name:               'push_joined'
		name:                  'text'
		move_kind:             .fresh_local_string_clone_push_binding
		plan_kind:             .natural_exit
		plan_action:           .string_value_cleanup
		helper_requirement:    .none
		preflight_status:      .inert
		insertion_kind:        .after_statement
		insertion_status:      .inert
		source_endpoint:       autofree_bridge_test_fresh_string_clone_push_source_endpoint()
		endpoint:              target
		state:                 .owned_unique
		resource:              .string_value
		shape:                 string_shape
		typ:                   string_type
		type_name:             string_type_name
		node_id:               target.node_id
		pos_id:                target.pos_id
		proof_node_id:         target.node_id
		proof_pos_id:          target.pos_id
		release_after_node_id: 12
		release_after_pos_id:  203
		insert_after_node_id:  12
		insert_after_pos_id:   203
		reason:                'release insertion point accepted'
	}
}

fn autofree_bridge_test_string_array_insertion_point() types.AutofreeReleaseInsertionPointFact {
	array_type := autofree_bridge_test_string_array_type()
	array_shape := autofree_bridge_test_string_array_shape()
	array_type_name := array_type.name()
	return types.AutofreeReleaseInsertionPointFact{
		...autofree_bridge_test_valid_insertion_point()
		source_endpoint: autofree_bridge_test_string_array_source_endpoint()
		endpoint:        autofree_bridge_test_string_array_target_endpoint()
		shape:           array_shape
		typ:             array_type
		type_name:       array_type_name
	}
}

fn autofree_bridge_test_other_valid_insertion_point() types.AutofreeReleaseInsertionPointFact {
	array_type := autofree_bridge_test_array_type()
	array_shape := autofree_bridge_test_array_shape()
	array_type_name := array_type.name()
	source := types.AutofreeTransferEndpoint{
		...autofree_bridge_test_source_endpoint()
		root_node_id: 8
		root_pos_id:  91
		node_id:      8
		pos_id:       91
	}
	target := types.AutofreeTransferEndpoint{
		...autofree_bridge_test_target_endpoint()
		root_node_id: 9
		root_pos_id:  121
		node_id:      9
		pos_id:       121
	}
	return types.AutofreeReleaseInsertionPointFact{
		fn_key:                'make_items'
		fn_name:               'make_items'
		name:                  'items'
		move_kind:             .fresh_local_binding
		plan_kind:             .natural_exit
		plan_action:           .array_container_cleanup
		helper_requirement:    .none
		preflight_status:      .inert
		insertion_kind:        .after_statement
		insertion_status:      .inert
		source_endpoint:       source
		endpoint:              target
		state:                 .owned_unique
		resource:              .array_value
		shape:                 array_shape
		typ:                   array_type
		type_name:             array_type_name
		node_id:               9
		pos_id:                121
		proof_node_id:         9
		proof_pos_id:          121
		release_after_node_id: 10
		release_after_pos_id:  220
		insert_after_node_id:  10
		insert_after_pos_id:   220
		reason:                'release insertion point accepted'
	}
}

fn autofree_bridge_test_other_named_valid_insertion_point() types.AutofreeReleaseInsertionPointFact {
	point := autofree_bridge_test_other_valid_insertion_point()
	target := types.AutofreeTransferEndpoint{
		...point.endpoint
		root_name: 'more_items'
		name:      'more_items'
	}
	return types.AutofreeReleaseInsertionPointFact{
		...point
		name:     'more_items'
		endpoint: target
	}
}

struct AutofreeBridgeRejectCase {
	name  string
	point types.AutofreeReleaseInsertionPointFact
}

fn autofree_bridge_test_assert_no_bridge(points []types.AutofreeReleaseInsertionPointFact) {
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 0
}

fn test_autofree_bridge_accepts_valid_insertion_point() {
	point := autofree_bridge_test_valid_insertion_point()
	bridge_facts := autofree_bridge_facts_from_insertion_points([point])
	assert bridge_facts.len == 1
	bridge_fact := bridge_facts[0]
	assert bridge_fact.fn_key == point.fn_key
	assert bridge_fact.fn_name == point.fn_name
	assert bridge_fact.name == point.name
	assert bridge_fact.bridge_status == .inert
	assert bridge_fact.target_node_id == point.endpoint.node_id
	assert bridge_fact.target_pos_id == point.endpoint.pos_id
	assert bridge_fact.insert_after_node_id == point.insert_after_node_id
	assert bridge_fact.insert_after_pos_id == point.insert_after_pos_id
	assert bridge_fact.reason.len > 0
}

fn test_autofree_bridge_accepts_builtin_string_array_container_cleanup() {
	point := autofree_bridge_test_string_array_insertion_point()
	bridge_facts := autofree_bridge_facts_from_insertion_points([point])
	assert bridge_facts.len == 1
	bridge_fact := bridge_facts[0]
	assert bridge_fact.fn_key == point.fn_key
	assert bridge_fact.fn_name == point.fn_name
	assert bridge_fact.name == point.name
	assert bridge_fact.bridge_status == .inert
	assert bridge_fact.target_node_id == point.endpoint.node_id
	assert bridge_fact.target_pos_id == point.endpoint.pos_id
	assert bridge_fact.insert_after_node_id == point.insert_after_node_id
	assert bridge_fact.insert_after_pos_id == point.insert_after_pos_id
	assert bridge_fact.reason.len > 0
}

fn test_autofree_bridge_accepts_cap_only_scalar_array_container_cleanup() {
	point := autofree_bridge_test_cap_only_insertion_point()
	bridge_facts := autofree_bridge_facts_from_insertion_points([point])
	assert bridge_facts.len == 1
	bridge_fact := bridge_facts[0]
	assert bridge_fact.fn_key == point.fn_key
	assert bridge_fact.fn_name == point.fn_name
	assert bridge_fact.name == point.name
	assert bridge_fact.bridge_status == .inert
	assert bridge_fact.target_node_id == point.endpoint.node_id
	assert bridge_fact.target_pos_id == point.endpoint.pos_id
	assert bridge_fact.insert_after_node_id == point.insert_after_node_id
	assert bridge_fact.insert_after_pos_id == point.insert_after_pos_id
	assert bridge_fact.reason.len > 0
}

fn test_autofree_bridge_accepts_len_only_scalar_array_container_cleanup() {
	point := autofree_bridge_test_len_only_insertion_point()
	bridge_facts := autofree_bridge_facts_from_insertion_points([point])
	assert bridge_facts.len == 1
	bridge_fact := bridge_facts[0]
	assert bridge_fact.fn_key == point.fn_key
	assert bridge_fact.fn_name == point.fn_name
	assert bridge_fact.name == point.name
	assert bridge_fact.bridge_status == .inert
	assert bridge_fact.target_node_id == point.endpoint.node_id
	assert bridge_fact.target_pos_id == point.endpoint.pos_id
	assert bridge_fact.insert_after_node_id == point.insert_after_node_id
	assert bridge_fact.insert_after_pos_id == point.insert_after_pos_id
	assert bridge_fact.reason.len > 0
}

fn test_autofree_bridge_accepts_local_array_clone_insertion_point() {
	point := autofree_bridge_test_local_array_clone_insertion_point()
	bridge_facts := autofree_bridge_facts_from_insertion_points([point])
	assert bridge_facts.len == 1
	bridge_fact := bridge_facts[0]
	assert bridge_fact.fn_key == point.fn_key
	assert bridge_fact.fn_name == point.fn_name
	assert bridge_fact.name == point.name
	assert bridge_fact.bridge_status == .inert
	assert bridge_fact.target_node_id == point.endpoint.node_id
	assert bridge_fact.target_pos_id == point.endpoint.pos_id
	assert bridge_fact.insert_after_node_id == point.insert_after_node_id
	assert bridge_fact.insert_after_pos_id == point.insert_after_pos_id
	assert bridge_fact.insert_after_node_id == point.release_after_node_id
	assert bridge_fact.reason.len > 0
}

fn test_autofree_bridge_accepts_loop_local_clone_push_insertion_point() {
	point := autofree_bridge_test_loop_local_clone_push_insertion_point()
	bridge_facts := autofree_bridge_facts_from_insertion_points([point])
	assert bridge_facts.len == 1
	bridge_fact := bridge_facts[0]
	assert bridge_fact.fn_key == point.fn_key
	assert bridge_fact.fn_name == point.fn_name
	assert bridge_fact.name == 'row'
	assert bridge_fact.move_kind == .loop_local_clone_push_binding
	assert bridge_fact.bridge_status == .inert
	assert bridge_fact.target_node_id == point.endpoint.node_id
	assert bridge_fact.target_pos_id == point.endpoint.pos_id
	assert bridge_fact.insert_after_node_id == point.insert_after_node_id
	assert bridge_fact.insert_after_pos_id == point.insert_after_pos_id
	assert bridge_fact.insert_after_node_id == point.release_after_node_id
	assert bridge_fact.reason.len > 0
}

fn test_autofree_bridge_accepts_fresh_local_string_clone_push_insertion_point() {
	point := autofree_bridge_test_fresh_string_clone_push_insertion_point()
	bridge_facts := autofree_bridge_facts_from_insertion_points([point])
	assert bridge_facts.len == 1
	bridge_fact := bridge_facts[0]
	assert bridge_fact.fn_key == point.fn_key
	assert bridge_fact.fn_name == point.fn_name
	assert bridge_fact.name == 'text'
	assert bridge_fact.move_kind == .fresh_local_string_clone_push_binding
	assert bridge_fact.bridge_status == .inert
	assert bridge_fact.target_node_id == point.endpoint.node_id
	assert bridge_fact.target_pos_id == point.endpoint.pos_id
	assert bridge_fact.insert_after_node_id == point.insert_after_node_id
	assert bridge_fact.insert_after_pos_id == point.insert_after_pos_id
	assert bridge_fact.insert_after_node_id == point.release_after_node_id
	assert bridge_fact.reason.len > 0
}

fn test_autofree_bridge_rejects_non_builtin_string_array_container_shape() {
	named_string_array_type := types.Type(types.Array{
		elem_type: types.Type(types.NamedType('string'))
	})
	named_string_array_shape := types.AutofreeResourceShape{
		...autofree_bridge_test_string_array_shape()
		fail_closed: true
	}
	named_string_array_type_name := named_string_array_type.name()
	source := types.AutofreeTransferEndpoint{
		...autofree_bridge_test_string_array_source_endpoint()
		typ:       named_string_array_type
		type_name: named_string_array_type_name
		shape:     named_string_array_shape
	}
	target := types.AutofreeTransferEndpoint{
		...autofree_bridge_test_string_array_target_endpoint()
		typ:       named_string_array_type
		type_name: named_string_array_type_name
		shape:     named_string_array_shape
	}
	point := types.AutofreeReleaseInsertionPointFact{
		...autofree_bridge_test_string_array_insertion_point()
		source_endpoint: source
		endpoint:        target
		shape:           named_string_array_shape
		typ:             named_string_array_type
		type_name:       named_string_array_type_name
	}
	autofree_bridge_test_assert_no_bridge([point])
}

fn test_autofree_bridge_rejects_cap_only_bad_source_and_shape_cases() {
	string_array_type := autofree_bridge_test_string_array_type()
	string_array_shape := autofree_bridge_test_string_array_shape()
	string_array_type_name := string_array_type.name()
	string_source := autofree_bridge_test_string_array_cap_only_source_endpoint()
	string_target := types.AutofreeTransferEndpoint{
		...autofree_bridge_test_string_array_target_endpoint()
	}
	string_point := types.AutofreeReleaseInsertionPointFact{
		...autofree_bridge_test_cap_only_insertion_point()
		source_endpoint: string_source
		endpoint:        string_target
		shape:           string_array_shape
		typ:             string_array_type
		type_name:       string_array_type_name
	}
	cases := [
		AutofreeBridgeRejectCase{
			name:  'source_string_array'
			point: string_point
		},
		AutofreeBridgeRejectCase{
			name:  'source_without_cap_only_reason'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_cap_only_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_cap_only_source_endpoint()
					reason: 'array literal'
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_source_state'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_cap_only_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_cap_only_source_endpoint()
					state: .ambiguous_no_free
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_source_storage'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_cap_only_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_cap_only_source_endpoint()
					storage:      .call_result
					root_storage: .call_result
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'source_path'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_cap_only_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_cap_only_source_endpoint()
					path: [
						types.AutofreeEndpointPathSegment{
							storage: .array_element
							name:    'elem'
							node_id: 3
							pos_id:  91
						},
					]
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'local_array_clone_move'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_cap_only_insertion_point()
				move_kind: .local_array_clone_binding
			}
		},
		AutofreeBridgeRejectCase{
			name:  'fail_closed_shape'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_cap_only_insertion_point()
				shape: autofree_bridge_test_fail_closed_shape()
			}
		},
	]
	for entry in cases {
		assert entry.name.len > 0
		autofree_bridge_test_assert_no_bridge([entry.point])
	}
}

fn test_autofree_bridge_rejects_len_only_bad_source_and_shape_cases() {
	string_array_type := autofree_bridge_test_string_array_type()
	string_array_shape := autofree_bridge_test_string_array_shape()
	string_array_type_name := string_array_type.name()
	string_source := autofree_bridge_test_string_array_len_only_source_endpoint()
	string_target := types.AutofreeTransferEndpoint{
		...autofree_bridge_test_string_array_target_endpoint()
	}
	string_point := types.AutofreeReleaseInsertionPointFact{
		...autofree_bridge_test_len_only_insertion_point()
		source_endpoint: string_source
		endpoint:        string_target
		shape:           string_array_shape
		typ:             string_array_type
		type_name:       string_array_type_name
	}
	cases := [
		AutofreeBridgeRejectCase{
			name:  'source_string_array'
			point: string_point
		},
		AutofreeBridgeRejectCase{
			name:  'source_without_len_only_reason'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_len_only_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_len_only_source_endpoint()
					reason: 'array literal'
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_source_state'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_len_only_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_len_only_source_endpoint()
					state: .ambiguous_no_free
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_source_storage'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_len_only_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_len_only_source_endpoint()
					storage:      .call_result
					root_storage: .call_result
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'source_path'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_len_only_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_len_only_source_endpoint()
					path: [
						types.AutofreeEndpointPathSegment{
							storage: .array_element
							name:    'elem'
							node_id: 3
							pos_id:  91
						},
					]
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'local_array_clone_move'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_len_only_insertion_point()
				move_kind: .local_array_clone_binding
			}
		},
		AutofreeBridgeRejectCase{
			name:  'fail_closed_shape'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_len_only_insertion_point()
				shape: autofree_bridge_test_fail_closed_shape()
			}
		},
	]
	for entry in cases {
		assert entry.name.len > 0
		autofree_bridge_test_assert_no_bridge([entry.point])
	}
}

fn test_autofree_bridge_rejects_local_array_clone_bad_source_and_target_cases() {
	string_array_type := autofree_bridge_test_string_array_type()
	string_array_shape := autofree_bridge_test_string_array_shape()
	string_array_type_name := string_array_type.name()
	string_source := types.AutofreeTransferEndpoint{
		...autofree_bridge_test_local_array_clone_source_endpoint()
		typ:       string_array_type
		type_name: string_array_type_name
		shape:     string_array_shape
	}
	string_target := types.AutofreeTransferEndpoint{
		...autofree_bridge_test_local_array_clone_target_endpoint()
		typ:       string_array_type
		type_name: string_array_type_name
		shape:     string_array_shape
	}
	string_point := types.AutofreeReleaseInsertionPointFact{
		...autofree_bridge_test_local_array_clone_insertion_point()
		source_endpoint: string_source
		endpoint:        string_target
		shape:           string_array_shape
		typ:             string_array_type
		type_name:       string_array_type_name
	}
	cases := [
		AutofreeBridgeRejectCase{
			name:  'source_string_array'
			point: string_point
		},
		AutofreeBridgeRejectCase{
			name:  'bad_source_state'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_local_array_clone_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_local_array_clone_source_endpoint()
					state: .owned_unique
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_source_storage'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_local_array_clone_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_local_array_clone_source_endpoint()
					storage:      .call_result
					root_storage: .call_result
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'source_local'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_local_array_clone_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_local_array_clone_source_endpoint()
					storage:      .local
					root_storage: .local
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'source_path'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_local_array_clone_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_local_array_clone_source_endpoint()
					path: [
						types.AutofreeEndpointPathSegment{
							storage: .array_element
							name:    'elem'
							node_id: 4
							pos_id:  131
						},
					]
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'source_resourceful'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_local_array_clone_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_local_array_clone_source_endpoint()
					resource: .string_value
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_target_state'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_local_array_clone_insertion_point()
				endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_local_array_clone_target_endpoint()
					state: .ambiguous_no_free
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_target_storage'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_local_array_clone_insertion_point()
				endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_local_array_clone_target_endpoint()
					storage:      .global
					root_storage: .global
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'unknown_move'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_local_array_clone_insertion_point()
				move_kind: .unknown
			}
		},
	]
	for entry in cases {
		assert entry.name.len > 0
		autofree_bridge_test_assert_no_bridge([entry.point])
	}
}

fn test_autofree_bridge_skips_empty_insertion_points() {
	autofree_bridge_test_assert_no_bridge([]types.AutofreeReleaseInsertionPointFact{})
}

fn test_autofree_bridge_rejects_duplicate_name() {
	point := autofree_bridge_test_valid_insertion_point()
	autofree_bridge_test_assert_no_bridge([point, point])
}

fn test_autofree_bridge_rejects_same_name_with_different_ids() {
	point := autofree_bridge_test_valid_insertion_point()
	other_point := autofree_bridge_test_other_valid_insertion_point()
	autofree_bridge_test_assert_no_bridge([point, other_point])
}

fn test_autofree_bridge_rejects_valid_plus_invalid_group() {
	point := autofree_bridge_test_valid_insertion_point()
	invalid := types.AutofreeReleaseInsertionPointFact{
		...autofree_bridge_test_other_named_valid_insertion_point()
		insertion_status: .unknown
	}
	autofree_bridge_test_assert_no_bridge([point, invalid])
}

fn test_autofree_bridge_rejects_status_kind_and_plan_cases() {
	cases := [
		AutofreeBridgeRejectCase{
			name:  'bad_insertion_status'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				insertion_status: .unknown
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_preflight_status'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				preflight_status: .unknown
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_insertion_kind'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				insertion_kind: .unknown
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_move_kind'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				move_kind: .unknown
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_plan_kind'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				plan_kind: .unknown
			}
		},
		AutofreeBridgeRejectCase{
			name:  'helper_requirement'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				helper_requirement: .unknown
			}
		},
		AutofreeBridgeRejectCase{
			name:  'non_array_container_plan'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				plan_action: .unknown
			}
		},
	]
	for entry in cases {
		assert entry.name.len > 0
		autofree_bridge_test_assert_no_bridge([entry.point])
	}
}

fn test_autofree_bridge_rejects_endpoint_path_and_reason_cases() {
	cases := [
		AutofreeBridgeRejectCase{
			name:  'bad_source'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_source_endpoint()
					storage:      .call_result
					root_storage: .call_result
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'source_without_empty_array_literal_reason'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_source_endpoint()
					reason: 'array literal'
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_target'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_target_endpoint()
					storage:      .global
					root_storage: .global
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'source_path'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_source_endpoint()
					path: [
						types.AutofreeEndpointPathSegment{
							storage: .array_element
							name:    'elem'
							node_id: 3
							pos_id:  91
						},
					]
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'target_path'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_target_endpoint()
					path: [
						types.AutofreeEndpointPathSegment{
							storage: .array_element
							name:    'elem'
							node_id: 6
							pos_id:  121
						},
					]
				}
			}
		},
	]
	for entry in cases {
		assert entry.name.len > 0
		autofree_bridge_test_assert_no_bridge([entry.point])
	}
}

fn test_autofree_bridge_rejects_type_resource_and_shape_cases() {
	cases := [
		AutofreeBridgeRejectCase{
			name:  'missing_type'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_source_endpoint()
					has_type:  false
					type_name: ''
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'divergent_type_name'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				type_name: '[]bool'
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_source_state'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_source_endpoint()
					state: .ambiguous_no_free
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_target_state'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_target_endpoint()
					state: .ambiguous_no_free
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'non_owned_state'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				state: .ambiguous_no_free
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_source_resource'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_source_endpoint()
					resource: .string_value
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'bad_target_resource'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_target_endpoint()
					resource: .string_value
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'non_array_resource'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				resource: .string_value
			}
		},
		AutofreeBridgeRejectCase{
			name:  'source_shape_mismatch'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_source_endpoint()
					shape: autofree_bridge_test_string_shape()
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'target_shape_mismatch'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_target_endpoint()
					shape: autofree_bridge_test_string_shape()
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'fail_closed_shape'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				shape: autofree_bridge_test_fail_closed_shape()
			}
		},
		AutofreeBridgeRejectCase{
			name:  'no_resource_shape'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				shape: autofree_bridge_test_no_resource_shape()
			}
		},
		AutofreeBridgeRejectCase{
			name:  'non_array_shape'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				shape: autofree_bridge_test_string_shape()
			}
		},
	]
	for entry in cases {
		assert entry.name.len > 0
		autofree_bridge_test_assert_no_bridge([entry.point])
	}
}

fn test_autofree_bridge_rejects_identity_and_id_cases() {
	cases := [
		AutofreeBridgeRejectCase{
			name:  'source_root_mismatch'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				source_endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_source_endpoint()
					root_node_id: 12
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'target_root_mismatch'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				endpoint: types.AutofreeTransferEndpoint{
					...autofree_bridge_test_target_endpoint()
					root_pos_id: 130
				}
			}
		},
		AutofreeBridgeRejectCase{
			name:  'invalid_point_ids'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				node_id: ast.FlatNodeId(-1)
				pos_id:  0
			}
		},
		AutofreeBridgeRejectCase{
			name:  'invalid_proof_ids'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				proof_node_id: ast.FlatNodeId(-1)
				proof_pos_id:  0
			}
		},
		AutofreeBridgeRejectCase{
			name:  'invalid_release_after_ids'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				release_after_node_id: ast.FlatNodeId(-1)
				release_after_pos_id:  0
			}
		},
		AutofreeBridgeRejectCase{
			name:  'invalid_insert_after_ids'
			point: types.AutofreeReleaseInsertionPointFact{
				...autofree_bridge_test_valid_insertion_point()
				insert_after_node_id: ast.FlatNodeId(-1)
				insert_after_pos_id:  0
			}
		},
	]
	for entry in cases {
		assert entry.name.len > 0
		autofree_bridge_test_assert_no_bridge([entry.point])
	}
}

fn test_autofree_bridge_rejects_source_equal_target_endpoint() {
	target := autofree_bridge_test_target_endpoint()
	source := types.AutofreeTransferEndpoint{
		...autofree_bridge_test_source_endpoint()
		root_name:    target.name
		name:         target.name
		root_node_id: target.node_id
		root_pos_id:  target.pos_id
		node_id:      target.node_id
		pos_id:       target.pos_id
	}
	point := types.AutofreeReleaseInsertionPointFact{
		...autofree_bridge_test_valid_insertion_point()
		source_endpoint: source
	}
	autofree_bridge_test_assert_no_bridge([point])
}

fn test_autofree_bridge_rejects_release_after_equal_target_endpoint() {
	target := autofree_bridge_test_target_endpoint()
	point := types.AutofreeReleaseInsertionPointFact{
		...autofree_bridge_test_valid_insertion_point()
		release_after_node_id: target.node_id
		release_after_pos_id:  target.pos_id
		insert_after_node_id:  target.node_id
		insert_after_pos_id:   target.pos_id
	}
	autofree_bridge_test_assert_no_bridge([point])
}

fn test_autofree_bridge_rejects_release_after_equal_source_endpoint() {
	source := autofree_bridge_test_source_endpoint()
	point := types.AutofreeReleaseInsertionPointFact{
		...autofree_bridge_test_valid_insertion_point()
		release_after_node_id: source.node_id
		release_after_pos_id:  source.pos_id
		insert_after_node_id:  source.node_id
		insert_after_pos_id:   source.pos_id
	}
	autofree_bridge_test_assert_no_bridge([point])
}

fn test_autofree_bridge_rejects_insert_after_divergence() {
	point := types.AutofreeReleaseInsertionPointFact{
		...autofree_bridge_test_valid_insertion_point()
		insert_after_node_id: 11
		insert_after_pos_id:  300
	}
	autofree_bridge_test_assert_no_bridge([point])
}

// autofree_statement_adapter_test

fn autofree_statement_adapter_test_bridge_fact() AutofreeCleanCBridgeFact {
	return AutofreeCleanCBridgeFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		bridge_status:        .inert
		target_node_id:       5
		target_pos_id:        120
		insert_after_node_id: 7
		insert_after_pos_id:  210
		reason:               'bridge accepted'
	}
}

fn autofree_statement_adapter_test_other_bridge_fact() AutofreeCleanCBridgeFact {
	return AutofreeCleanCBridgeFact{
		fn_key:               'make_more_items'
		fn_name:              'make_more_items'
		name:                 'items'
		bridge_status:        .inert
		target_node_id:       5
		target_pos_id:        120
		insert_after_node_id: 7
		insert_after_pos_id:  210
		reason:               'bridge accepted'
	}
}

fn autofree_statement_adapter_test_bridge_fact_same_fn_other_slot() AutofreeCleanCBridgeFact {
	return AutofreeCleanCBridgeFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'more_items'
		bridge_status:        .inert
		target_node_id:       8
		target_pos_id:        121
		insert_after_node_id: 9
		insert_after_pos_id:  220
		reason:               'bridge accepted'
	}
}

fn autofree_statement_adapter_test_assert_no_anchor(facts []AutofreeCleanCBridgeFact) {
	anchors := autofree_statement_anchor_facts_from_bridge_facts(facts)
	assert anchors.len == 0
}

fn autofree_statement_adapter_test_assert_no_named_anchor(case_name string, facts []AutofreeCleanCBridgeFact) {
	assert case_name.len > 0
	autofree_statement_adapter_test_assert_no_anchor(facts)
}

fn test_autofree_statement_adapter_accepts_valid_bridge_fact() {
	bridge_fact := autofree_statement_adapter_test_bridge_fact()
	anchors := autofree_statement_anchor_facts_from_bridge_facts([bridge_fact])
	assert anchors.len == 1
	anchor := anchors[0]
	assert anchor.fn_key == bridge_fact.fn_key
	assert anchor.fn_name == bridge_fact.fn_name
	assert anchor.name == bridge_fact.name
	assert anchor.anchor_status == .inert
	assert anchor.target_node_id == bridge_fact.target_node_id
	assert anchor.target_pos_id == bridge_fact.target_pos_id
	assert anchor.insert_after_node_id == bridge_fact.insert_after_node_id
	assert anchor.insert_after_pos_id == bridge_fact.insert_after_pos_id
	assert anchor.reason.len > 0
}

fn test_autofree_statement_adapter_skips_empty_bridge_facts() {
	autofree_statement_adapter_test_assert_no_anchor([]AutofreeCleanCBridgeFact{})
}

fn test_autofree_statement_adapter_rejects_target_equal_insert_after() {
	bridge_fact := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		insert_after_node_id: 5
		insert_after_pos_id:  120
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact])
}

fn test_autofree_statement_adapter_rejects_target_node_equal_insert_after_node() {
	bridge_fact := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		insert_after_node_id: 5
		insert_after_pos_id:  121
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact])
}

fn test_autofree_statement_adapter_rejects_invalid_bridge_fields() {
	base := autofree_statement_adapter_test_bridge_fact()
	cases := [
		'bad_bridge_status',
		'empty_fn_key',
		'empty_name',
		'invalid_target_ids',
		'invalid_insert_after_ids',
	]
	bridge_facts := [
		AutofreeCleanCBridgeFact{
			...base
			bridge_status: .unknown
		},
		AutofreeCleanCBridgeFact{
			...base
			fn_key: ''
		},
		AutofreeCleanCBridgeFact{
			...base
			name: ''
		},
		AutofreeCleanCBridgeFact{
			...base
			target_node_id: ast.FlatNodeId(-1)
			target_pos_id:  0
		},
		AutofreeCleanCBridgeFact{
			...base
			insert_after_node_id: ast.FlatNodeId(-1)
			insert_after_pos_id:  0
		},
	]
	assert cases.len == bridge_facts.len
	for index, invalid_case in cases {
		bridge_fact := bridge_facts[index]
		autofree_statement_adapter_test_assert_no_named_anchor(invalid_case, [
			bridge_fact,
		])
	}
}

fn test_autofree_statement_adapter_rejects_duplicate_name() {
	bridge_fact := autofree_statement_adapter_test_bridge_fact()
	duplicate := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		target_node_id:       8
		target_pos_id:        121
		insert_after_node_id: 9
		insert_after_pos_id:  220
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact, duplicate])
}

fn test_autofree_statement_adapter_rejects_duplicate_target() {
	bridge_fact := autofree_statement_adapter_test_bridge_fact()
	duplicate := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		name:                 'more_items'
		insert_after_node_id: 9
		insert_after_pos_id:  220
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact, duplicate])
}

fn test_autofree_statement_adapter_rejects_valid_plus_invalid_group() {
	bridge_fact := autofree_statement_adapter_test_bridge_fact()
	invalid := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact_same_fn_other_slot()
		bridge_status: .unknown
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact, invalid])
}

fn test_autofree_statement_adapter_accepts_distinct_targets_with_shared_slot() {
	bridge_fact := autofree_statement_adapter_test_bridge_fact()
	duplicate := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		name:           'more_items'
		target_node_id: 8
		target_pos_id:  121
	}
	anchors := autofree_statement_anchor_facts_from_bridge_facts([bridge_fact, duplicate])
	assert anchors.len == 2
	assert anchors[0].name == 'items'
	assert anchors[1].name == 'more_items'
	assert anchors[0].insert_after_node_id == anchors[1].insert_after_node_id
	assert anchors[0].insert_after_pos_id == anchors[1].insert_after_pos_id
}

// autofree_statement_locator_test

struct AutofreeStatementLocatorTestFlat {
	flat          ast.FlatAst
	fn_id         ast.FlatNodeId
	first_stmt_id ast.FlatNodeId
	first_lhs_id  ast.FlatNodeId
	first_rhs_id  ast.FlatNodeId
	next_stmt_id  ast.FlatNodeId
	next_lhs_id   ast.FlatNodeId
	next_rhs_id   ast.FlatNodeId
}

struct AutofreeStatementLocatorTwoMethodTestFlat {
	flat           ast.FlatAst
	fn_name        string
	first_fn_id    ast.FlatNodeId
	first_stmt_id  ast.FlatNodeId
	first_lhs_id   ast.FlatNodeId
	second_fn_id   ast.FlatNodeId
	second_stmt_id ast.FlatNodeId
	second_lhs_id  ast.FlatNodeId
}

fn autofree_statement_locator_test_pos(id int) token.Pos {
	return token.Pos{
		offset: id
		id:     id
	}
}

fn autofree_statement_locator_test_array_init(mut b ast.FlatBuilder, pos_id int) ast.FlatNodeId {
	return b.emit_array_init_expr_by_ids(ast.invalid_flat_node_id, ast.invalid_flat_node_id,
		ast.invalid_flat_node_id, ast.invalid_flat_node_id, ast.invalid_flat_node_id,
		[]ast.FlatNodeId{}, autofree_statement_locator_test_pos(pos_id))
}

fn autofree_statement_locator_test_flat_with_assign(fn_name string, module_name string, is_method bool, is_static bool, language ast.Language, lhs_count int) AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(120))
	rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	mut lhs_ids := [lhs_id]
	mut rhs_ids := [rhs_id]
	if lhs_count > 1 {
		lhs_ids << b.emit_ident_by_name('other_items', autofree_statement_locator_test_pos(121))
		rhs_ids << autofree_statement_locator_test_array_init(mut b, 131)
	}
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, lhs_ids, rhs_ids,
		autofree_statement_locator_test_pos(210))
	body_id := b.emit_aux_list_from_ids([stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids(fn_name, false, is_method, is_static, language,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_test.v'
		mod:  module_name
	}, [fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         fn_id
		first_stmt_id: stmt_id
		first_lhs_id:  lhs_id
		first_rhs_id:  rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_method_receiver(fn_name string, module_name string, receiver_type string, receiver_is_mut bool, is_static bool, language ast.Language) AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(120))
	rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [lhs_id], [rhs_id],
		autofree_statement_locator_test_pos(210))
	body_id := b.emit_aux_list_from_ids([stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	mut receiver := ast.Parameter{
		name: 'g'
		typ:  ast.Expr(ast.Type(ast.PointerType{
			base_type: ast.Expr(ast.Ident{
				name: receiver_type
				pos:  autofree_statement_locator_test_pos(91)
			})
		}))
		pos:  autofree_statement_locator_test_pos(90)
	}
	receiver.is_mut = receiver_is_mut
	receiver_id := b.emit_parameter(receiver)
	fn_id := b.emit_fn_decl_by_ids(fn_name, false, true, is_static, language,
		autofree_statement_locator_test_pos(100), receiver_id, fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_method_test.v'
		mod:  module_name
	}, [fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         fn_id
		first_stmt_id: stmt_id
		first_lhs_id:  lhs_id
		first_rhs_id:  rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_two_method_receivers(fn_name string, module_name string, first_receiver_type string, second_receiver_type string) AutofreeStatementLocatorTwoMethodTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(120))
	first_rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_locator_test_pos(210))
	first_body_id := b.emit_aux_list_from_ids([first_stmt_id])
	first_fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	first_attrs_id := b.emit_attribute_list([])
	first_receiver_id := b.emit_parameter(ast.Parameter{
		name: 'g'
		typ:  ast.Expr(ast.Type(ast.PointerType{
			base_type: ast.Expr(ast.Ident{
				name: first_receiver_type
				pos:  autofree_statement_locator_test_pos(91)
			})
		}))
		pos:  autofree_statement_locator_test_pos(90)
	})
	first_fn_id := b.emit_fn_decl_by_ids(fn_name, false, true, false, .v,
		autofree_statement_locator_test_pos(100), first_receiver_id, first_fn_type_id,
		first_attrs_id, first_body_id)
	second_lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(220))
	second_rhs_id := autofree_statement_locator_test_array_init(mut b, 230)
	second_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [second_lhs_id], [
		second_rhs_id,
	], autofree_statement_locator_test_pos(310))
	second_body_id := b.emit_aux_list_from_ids([second_stmt_id])
	second_fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	second_attrs_id := b.emit_attribute_list([])
	second_receiver_id := b.emit_parameter(ast.Parameter{
		name: 'g'
		typ:  ast.Expr(ast.Type(ast.PointerType{
			base_type: ast.Expr(ast.Ident{
				name: second_receiver_type
				pos:  autofree_statement_locator_test_pos(191)
			})
		}))
		pos:  autofree_statement_locator_test_pos(190)
	})
	second_fn_id := b.emit_fn_decl_by_ids(fn_name, false, true, false, .v,
		autofree_statement_locator_test_pos(200), second_receiver_id, second_fn_type_id,
		second_attrs_id, second_body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_two_method_test.v'
		mod:  module_name
	}, [first_fn_id, second_fn_id])
	return AutofreeStatementLocatorTwoMethodTestFlat{
		flat:           b.take_flat()
		fn_name:        fn_name
		first_fn_id:    first_fn_id
		first_stmt_id:  first_stmt_id
		first_lhs_id:   first_lhs_id
		second_fn_id:   second_fn_id
		second_stmt_id: second_stmt_id
		second_lhs_id:  second_lhs_id
	}
}

fn autofree_statement_locator_test_flat_with_modifier_assign(kind token.Token, extra_child bool) AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(120))
	extra_lhs_id := b.emit_ident_by_name('extra_items', autofree_statement_locator_test_pos(121))
	modifier_id := b.emit_modifier_expr_by_id(kind, lhs_id,
		autofree_statement_locator_test_pos(119))
	rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [modifier_id], [rhs_id],
		autofree_statement_locator_test_pos(210))
	body_id := b.emit_aux_list_from_ids([stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_modifier_test.v'
		mod:  'main'
	}, [fn_id])
	mut flat := b.take_flat()
	if extra_child {
		flat.nodes[modifier_id].first_edge = flat.edges.len
		flat.nodes[modifier_id].edge_count = 2
		flat.edges << ast.FlatEdge{
			child_id: lhs_id
		}
		flat.edges << ast.FlatEdge{
			child_id: extra_lhs_id
		}
	}
	return AutofreeStatementLocatorTestFlat{
		flat:          flat
		fn_id:         fn_id
		first_stmt_id: stmt_id
		first_lhs_id:  lhs_id
		first_rhs_id:  rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_two_assigns() AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(120))
	first_rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_locator_test_pos(210))
	next_lhs_id := b.emit_ident_by_name('more_items', autofree_statement_locator_test_pos(220))
	next_rhs_id := autofree_statement_locator_test_array_init(mut b, 230)
	next_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [next_lhs_id], [
		next_rhs_id,
	], autofree_statement_locator_test_pos(310))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, next_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         fn_id
		first_stmt_id: first_stmt_id
		first_lhs_id:  first_lhs_id
		first_rhs_id:  first_rhs_id
		next_stmt_id:  next_stmt_id
		next_lhs_id:   next_lhs_id
		next_rhs_id:   next_rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_prefix_then_items() AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('copy', autofree_statement_locator_test_pos(120))
	first_rhs_id := b.emit_ident_by_name('source', autofree_statement_locator_test_pos(130))
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_locator_test_pos(210))
	next_lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(220))
	next_rhs_id := autofree_statement_locator_test_array_init(mut b, 230)
	next_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [next_lhs_id], [
		next_rhs_id,
	], autofree_statement_locator_test_pos(310))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, next_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_prefix_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         fn_id
		first_stmt_id: first_stmt_id
		first_lhs_id:  first_lhs_id
		first_rhs_id:  first_rhs_id
		next_stmt_id:  next_stmt_id
		next_lhs_id:   next_lhs_id
		next_rhs_id:   next_rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_later_insert_assignment() AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('arr', autofree_statement_locator_test_pos(120))
	first_rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_locator_test_pos(210))
	block_id := b.emit_block_stmt_by_ids([])
	next_lhs_id := b.emit_ident_by_name('gen', autofree_statement_locator_test_pos(320))
	next_rhs_id := b.emit_ident_by_name('arr', autofree_statement_locator_test_pos(330))
	next_stmt_id := b.emit_assign_stmt_by_ids(.assign, [next_lhs_id], [
		next_rhs_id,
	], autofree_statement_locator_test_pos(410))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, block_id, next_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('next_generation', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_later_insert_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         fn_id
		first_stmt_id: first_stmt_id
		first_lhs_id:  first_lhs_id
		first_rhs_id:  first_rhs_id
		next_stmt_id:  next_stmt_id
		next_lhs_id:   next_lhs_id
		next_rhs_id:   next_rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_duplicate_later_insert_assignment() AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('arr', autofree_statement_locator_test_pos(120))
	first_rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_locator_test_pos(210))
	duplicate_lhs_id := b.emit_ident_by_name('arr', autofree_statement_locator_test_pos(220))
	duplicate_rhs_id := autofree_statement_locator_test_array_init(mut b, 230)
	duplicate_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [duplicate_lhs_id], [
		duplicate_rhs_id,
	], autofree_statement_locator_test_pos(310))
	next_lhs_id := b.emit_ident_by_name('gen', autofree_statement_locator_test_pos(320))
	next_rhs_id := b.emit_ident_by_name('arr', autofree_statement_locator_test_pos(330))
	next_stmt_id := b.emit_assign_stmt_by_ids(.assign, [next_lhs_id], [
		next_rhs_id,
	], autofree_statement_locator_test_pos(410))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, duplicate_stmt_id, next_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('next_generation', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_duplicate_later_insert_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         fn_id
		first_stmt_id: first_stmt_id
		first_lhs_id:  first_lhs_id
		first_rhs_id:  first_rhs_id
		next_stmt_id:  next_stmt_id
		next_lhs_id:   next_lhs_id
		next_rhs_id:   next_rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_two_files() AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	first_file_lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(120))
	first_file_rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	first_file_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_file_lhs_id], [
		first_file_rhs_id,
	], autofree_statement_locator_test_pos(210))
	first_file_body_id := b.emit_aux_list_from_ids([first_file_stmt_id])
	first_file_fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	first_file_attrs_id := b.emit_attribute_list([])
	first_file_fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, first_file_fn_type_id,
		first_file_attrs_id, first_file_body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_first.v'
		mod:  'main'
	}, [first_file_fn_id])
	second_file_lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(320))
	second_file_rhs_id := autofree_statement_locator_test_array_init(mut b, 330)
	second_file_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [
		second_file_lhs_id,
	], [second_file_rhs_id], autofree_statement_locator_test_pos(410))
	second_file_body_id := b.emit_aux_list_from_ids([second_file_stmt_id])
	second_file_fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	second_file_attrs_id := b.emit_attribute_list([])
	second_file_fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(300), ast.invalid_flat_node_id, second_file_fn_type_id,
		second_file_attrs_id, second_file_body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_second.v'
		mod:  'main'
	}, [second_file_fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         second_file_fn_id
		first_stmt_id: second_file_stmt_id
		first_lhs_id:  second_file_lhs_id
		first_rhs_id:  second_file_rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_nested_assign() AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(120))
	rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [lhs_id], [rhs_id],
		autofree_statement_locator_test_pos(210))
	block_id := b.emit_block_stmt_by_ids([stmt_id])
	body_id := b.emit_aux_list_from_ids([block_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_nested.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         fn_id
		first_stmt_id: stmt_id
		first_lhs_id:  lhs_id
		first_rhs_id:  rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_receiver_field_nested_final_assign() AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	target_lhs_id := b.emit_ident_by_name('next', autofree_statement_locator_test_pos(120))
	target_rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	target_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [target_lhs_id], [
		target_rhs_id,
	], autofree_statement_locator_test_pos(210))
	final_lhs_id := b.emit_ident_by_name('sink', autofree_statement_locator_test_pos(220))
	final_rhs_id := b.emit_ident_by_name('next', autofree_statement_locator_test_pos(230))
	final_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [final_lhs_id], [
		final_rhs_id,
	], autofree_statement_locator_test_pos(310))
	cond_id := b.emit_ident_by_name('ok', autofree_statement_locator_test_pos(200))
	else_id := b.emit_expr(ast.empty_expr)
	if_id := b.emit_if_expr_by_ids(cond_id, else_id, [target_stmt_id, final_stmt_id],
		autofree_statement_locator_test_pos(205))
	if_stmt_id := b.emit_expr_stmt_by_id(if_id)
	body_id := b.emit_aux_list_from_ids([if_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_receiver_field_nested_assign.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         fn_id
		first_stmt_id: target_stmt_id
		first_lhs_id:  target_lhs_id
		first_rhs_id:  target_rhs_id
		next_stmt_id:  final_stmt_id
		next_lhs_id:   final_lhs_id
		next_rhs_id:   final_rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_invalid_body_edge() AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(120))
	rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [lhs_id], [rhs_id],
		autofree_statement_locator_test_pos(210))
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		stmt_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_invalid_body.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         fn_id
		first_stmt_id: stmt_id
		first_lhs_id:  lhs_id
		first_rhs_id:  rhs_id
	}
}

fn autofree_statement_locator_test_anchor(fixture &AutofreeStatementLocatorTestFlat) AutofreeCleanCStatementAnchorFact {
	return AutofreeCleanCStatementAnchorFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		anchor_status:        .inert
		target_node_id:       fixture.first_lhs_id
		target_pos_id:        120
		insert_after_node_id: fixture.first_stmt_id
		insert_after_pos_id:  210
		reason:               'anchor accepted'
	}
}

fn autofree_statement_locator_test_receiver_field_nested_final_assign_anchor(fixture &AutofreeStatementLocatorTestFlat) AutofreeCleanCStatementAnchorFact {
	return AutofreeCleanCStatementAnchorFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'next'
		move_kind:            .receiver_field_slice_clone_binding
		anchor_status:        .inert
		target_node_id:       fixture.first_lhs_id
		target_pos_id:        120
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
		reason:               'receiver field nested assign anchor'
	}
}

fn autofree_statement_locator_test_second_file_anchor(fixture &AutofreeStatementLocatorTestFlat) AutofreeCleanCStatementAnchorFact {
	return AutofreeCleanCStatementAnchorFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		anchor_status:        .inert
		target_node_id:       fixture.first_lhs_id
		target_pos_id:        320
		insert_after_node_id: fixture.first_stmt_id
		insert_after_pos_id:  410
		reason:               'anchor accepted'
	}
}

fn autofree_statement_locator_test_next_anchor(fixture &AutofreeStatementLocatorTestFlat) AutofreeCleanCStatementAnchorFact {
	return AutofreeCleanCStatementAnchorFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'more_items'
		anchor_status:        .inert
		target_node_id:       fixture.next_lhs_id
		target_pos_id:        220
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
		reason:               'anchor accepted'
	}
}

fn autofree_statement_locator_test_later_insert_anchor(fixture &AutofreeStatementLocatorTestFlat) AutofreeCleanCStatementAnchorFact {
	return AutofreeCleanCStatementAnchorFact{
		fn_key:               'next_generation'
		fn_name:              'next_generation'
		name:                 'arr'
		anchor_status:        .inert
		target_node_id:       fixture.first_lhs_id
		target_pos_id:        120
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  410
		reason:               'anchor accepted'
	}
}

fn autofree_statement_locator_two_method_test_anchor(fixture &AutofreeStatementLocatorTwoMethodTestFlat, receiver_type string, second bool) AutofreeCleanCStatementAnchorFact {
	return AutofreeCleanCStatementAnchorFact{
		fn_key:               types.autofree_fn_key('main', fixture.fn_name, receiver_type)
		fn_name:              fixture.fn_name
		name:                 'items'
		anchor_status:        .inert
		target_node_id:       if second { fixture.second_lhs_id } else { fixture.first_lhs_id }
		target_pos_id:        if second { 220 } else { 120 }
		insert_after_node_id: if second { fixture.second_stmt_id } else { fixture.first_stmt_id }
		insert_after_pos_id:  if second { 310 } else { 210 }
		reason:               'anchor accepted'
	}
}

fn autofree_statement_locator_test_fn_cursor(fixture &AutofreeStatementLocatorTestFlat) ast.Cursor {
	return ast.Cursor{
		flat: &fixture.flat
		id:   fixture.fn_id
	}
}

fn autofree_statement_locator_test_locations(fixture &AutofreeStatementLocatorTestFlat, anchors []AutofreeCleanCStatementAnchorFact) []AutofreeCleanCStatementLocationFact {
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_locator_test_fn_cursor(fixture)
	return autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, anchors)
}

fn autofree_statement_locator_test_assert_no_location(fixture &AutofreeStatementLocatorTestFlat, anchors []AutofreeCleanCStatementAnchorFact) {
	locations := autofree_statement_locator_test_locations(fixture, anchors)
	assert locations.len == 0
}

fn autofree_statement_locator_test_assert_location(location AutofreeCleanCStatementLocationFact, fixture &AutofreeStatementLocatorTestFlat, anchor AutofreeCleanCStatementAnchorFact) {
	assert location.fn_key == anchor.fn_key
	assert location.fn_name == anchor.fn_name
	assert location.name == anchor.name
	assert location.location_status == .inert
	assert location.fn_node_id == fixture.fn_id
	assert location.fn_pos_id == 100
	assert location.stmt_node_id == fixture.first_stmt_id
	assert location.stmt_pos_id == 210
	assert location.stmt_index == 0
	assert location.lhs_index == 0
	assert location.target_node_id == fixture.first_lhs_id
	assert location.target_pos_id == 120
	assert location.insert_after_node_id == fixture.first_stmt_id
	assert location.insert_after_pos_id == 210
	assert location.reason.len > 0
}

fn test_autofree_statement_locator_file_cursor_accepts_direct_array_decl() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 1)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fixture)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, [
		anchor,
	])
	assert locations.len == 1
	autofree_statement_locator_test_assert_location(locations[0], &fixture, anchor)
}

fn test_autofree_statement_locator_file_cursor_accepts_mut_array_decl() {
	fixture := autofree_statement_locator_test_flat_with_modifier_assign(.key_mut, false)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fixture)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, [
		anchor,
	])
	assert locations.len == 1
	autofree_statement_locator_test_assert_location(locations[0], &fixture, anchor)
}

fn test_autofree_statement_locator_accepts_last_statement_after_prefix() {
	fixture := autofree_statement_locator_test_flat_with_prefix_then_items()
	anchor := AutofreeCleanCStatementAnchorFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		anchor_status:        .inert
		target_node_id:       fixture.next_lhs_id
		target_pos_id:        220
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
		reason:               'anchor accepted'
	}
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fixture)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, [
		anchor,
	])
	assert locations.len == 1
	location := locations[0]
	assert location.name == 'items'
	assert location.name != 'copy'
	assert location.name != 'source'
	assert location.stmt_index == 1
	assert location.target_node_id == fixture.next_lhs_id
	assert location.target_pos_id == 220
	assert location.insert_after_node_id == fixture.next_stmt_id
	assert location.insert_after_pos_id == 310
}

fn test_autofree_statement_locator_accepts_later_final_assignment_after_target_decl() {
	fixture := autofree_statement_locator_test_flat_with_later_insert_assignment()
	anchor := autofree_statement_locator_test_later_insert_anchor(&fixture)
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fixture)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, [
		anchor,
	])
	assert locations.len == 1
	location := locations[0]
	assert location.fn_key == 'next_generation'
	assert location.fn_name == 'next_generation'
	assert location.name == 'arr'
	assert location.stmt_index == 2
	assert location.target_node_id == fixture.first_lhs_id
	assert location.target_pos_id == 120
	assert location.stmt_node_id == fixture.next_stmt_id
	assert location.stmt_pos_id == 410
	assert location.insert_after_node_id == fixture.next_stmt_id
	assert location.insert_after_pos_id == 410
	assert location.lhs_index == 0
}

fn test_autofree_statement_locator_rejects_later_final_assignment_wrong_insert_after_node_id() {
	fixture := autofree_statement_locator_test_flat_with_later_insert_assignment()
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_later_insert_anchor(&fixture)
		insert_after_node_id: ast.FlatNodeId(9002)
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_later_final_assignment_wrong_target_node_id() {
	fixture := autofree_statement_locator_test_flat_with_later_insert_assignment()
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_later_insert_anchor(&fixture)
		target_node_id: ast.FlatNodeId(9001)
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_later_final_assignment_duplicate_target_decl() {
	fixture := autofree_statement_locator_test_flat_with_duplicate_later_insert_assignment()
	anchor := autofree_statement_locator_test_later_insert_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_later_insert_assignment_without_target_decl() {
	fixture := autofree_statement_locator_test_flat_with_later_insert_assignment()
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_later_insert_anchor(&fixture)
		target_node_id: fixture.first_rhs_id
		target_pos_id:  130
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_later_decl_insert_for_prior_target() {
	fixture := autofree_statement_locator_test_flat_with_two_assigns()
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_rhs_target() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 1)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		target_node_id: fixture.first_rhs_id
		target_pos_id:  130
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_multi_lhs_assign() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 2)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_non_mut_modifier_lhs() {
	fixture := autofree_statement_locator_test_flat_with_modifier_assign(.key_shared, false)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_modifier_lhs_with_extra_child() {
	fixture := autofree_statement_locator_test_flat_with_modifier_assign(.key_mut, true)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_nested_assign() {
	fixture := autofree_statement_locator_test_flat_with_nested_assign()
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_receiver_field_nested_final_assign_slot() {
	fixture := autofree_statement_locator_test_flat_with_receiver_field_nested_final_assign()
	anchor := autofree_statement_locator_test_receiver_field_nested_final_assign_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_preview_rejects_receiver_field_nested_final_assign_slot() {
	fixture := autofree_statement_locator_test_flat_with_receiver_field_nested_final_assign()
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fixture)
	location := AutofreeCleanCStatementLocationFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'next'
		move_kind:            .receiver_field_slice_clone_binding
		location_status:      .inert
		fn_node_id:           fixture.fn_id
		fn_pos_id:            100
		target_node_id:       fixture.first_lhs_id
		target_pos_id:        120
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          310
		block_path:           '0'
		stmt_index:           1
		lhs_index:            0
		reason:               'receiver field nested assign location'
	}
	previews := autofree_statement_preview_facts_from_file_cursor(fixture.flat.file_cursor(0),
		fn_cursor, [location])
	assert previews.len == 0
}

fn test_autofree_statement_locator_rejects_invalid_body_edge() {
	fixture := autofree_statement_locator_test_flat_with_invalid_body_edge()
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_duplicate_target_position() {
	fixture := autofree_statement_locator_test_flat_with_two_assigns()
	anchor := autofree_statement_locator_test_anchor(&fixture)
	duplicate := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_next_anchor(&fixture)
		target_node_id: fixture.first_lhs_id
		target_pos_id:  120
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor, duplicate])
}

fn test_autofree_statement_locator_rejects_duplicate_insert_slot() {
	fixture := autofree_statement_locator_test_flat_with_two_assigns()
	anchor := autofree_statement_locator_test_anchor(&fixture)
	duplicate := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_next_anchor(&fixture)
		insert_after_node_id: fixture.first_stmt_id
		insert_after_pos_id:  210
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor, duplicate])
}

fn test_autofree_statement_locator_rejects_valid_plus_invalid_group() {
	fixture := autofree_statement_locator_test_flat_with_two_assigns()
	anchor := autofree_statement_locator_test_anchor(&fixture)
	invalid := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_next_anchor(&fixture)
		anchor_status: .unknown
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor, invalid])
}

fn test_autofree_statement_locator_rejects_mixed_function_group() {
	fixture := autofree_statement_locator_test_flat_with_two_assigns()
	anchor := autofree_statement_locator_test_anchor(&fixture)
	mixed := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_next_anchor(&fixture)
		fn_key:  'other_fn'
		fn_name: 'other_fn'
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor, mixed])
}

fn test_autofree_statement_locator_accepts_method_function_receiver_key() {
	fixture := autofree_statement_locator_test_flat_with_method_receiver('make_items', 'main',
		'Game', false, false, .v)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		fn_key: types.autofree_fn_key('main', 'make_items', 'Game')
	}
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fixture)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, [
		anchor,
	])
	assert locations.len == 1
	autofree_statement_locator_test_assert_location(locations[0], &fixture, anchor)
}

fn test_autofree_statement_locator_separates_free_and_method_function_keys() {
	free_fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false,
		false, .v, 1)
	method_fixture := autofree_statement_locator_test_flat_with_method_receiver('make_items',
		'main', 'Game', false, false, .v)
	free_anchor := autofree_statement_locator_test_anchor(&free_fixture)
	method_anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&method_fixture)
		fn_key: types.autofree_fn_key('main', 'make_items', 'Game')
	}
	free_locations := autofree_statement_locator_test_locations(&free_fixture, [
		free_anchor,
	])
	method_locations := autofree_statement_locator_test_locations(&method_fixture, [
		method_anchor,
	])
	assert free_locations.len == 1
	assert method_locations.len == 1
	assert free_locations[0].fn_key != method_locations[0].fn_key
}

fn test_autofree_statement_locator_separates_same_method_name_receiver_keys() {
	fixture := autofree_statement_locator_test_flat_with_two_method_receivers('make_items', 'main',
		'Game', 'OtherGame')
	file_cursor := fixture.flat.file_cursor(0)
	first_cursor := ast.Cursor{
		flat: &fixture.flat
		id:   fixture.first_fn_id
	}
	second_cursor := ast.Cursor{
		flat: &fixture.flat
		id:   fixture.second_fn_id
	}
	first_anchor := autofree_statement_locator_two_method_test_anchor(&fixture, 'Game', false)
	second_anchor := autofree_statement_locator_two_method_test_anchor(&fixture, 'OtherGame', true)
	wrong_first_anchor := autofree_statement_locator_two_method_test_anchor(&fixture, 'OtherGame',
		false)
	wrong_second_anchor := autofree_statement_locator_two_method_test_anchor(&fixture, 'Game', true)
	assert first_anchor.fn_key != second_anchor.fn_key
	first_locations := autofree_statement_location_facts_from_file_cursor(file_cursor,
		first_cursor, [first_anchor])
	second_locations := autofree_statement_location_facts_from_file_cursor(file_cursor,
		second_cursor, [second_anchor])
	wrong_first_locations := autofree_statement_location_facts_from_file_cursor(file_cursor,
		first_cursor, [wrong_first_anchor])
	wrong_second_locations := autofree_statement_location_facts_from_file_cursor(file_cursor,
		second_cursor, [wrong_second_anchor])
	assert first_locations.len == 1
	assert first_locations[0].fn_key == first_anchor.fn_key
	assert first_locations[0].target_node_id == fixture.first_lhs_id
	assert first_locations[0].target_pos_id == 120
	assert second_locations.len == 1
	assert second_locations[0].fn_key == second_anchor.fn_key
	assert second_locations[0].target_node_id == fixture.second_lhs_id
	assert second_locations[0].target_pos_id == 220
	assert wrong_first_locations.len == 0
	assert wrong_second_locations.len == 0
}

fn test_autofree_statement_locator_rejects_method_function_without_supported_receiver() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', true, false,
		.v, 1)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		fn_key: types.autofree_fn_key('main', 'make_items', 'Game')
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_accepts_mut_receiver_method_function() {
	fixture := autofree_statement_locator_test_flat_with_method_receiver('make_items', 'main',
		'Game', true, false, .v)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		fn_key: types.autofree_fn_key('main', 'make_items', 'Game')
	}
	locations := autofree_statement_locator_test_locations(&fixture, [anchor])
	assert locations.len == 1
	autofree_statement_locator_test_assert_location(locations[0], &fixture, anchor)
}

fn test_autofree_statement_locator_rejects_static_function() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, true,
		.v, 1)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_static_method_function() {
	fixture := autofree_statement_locator_test_flat_with_method_receiver('make_items', 'main',
		'Game', false, true, .v)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		fn_key: types.autofree_fn_key('main', 'make_items', 'Game')
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_foreign_method_function() {
	fixture := autofree_statement_locator_test_flat_with_method_receiver('make_items', 'main',
		'Game', false, false, .c)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		fn_key: types.autofree_fn_key('main', 'make_items', 'Game')
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_fn_cursor_rejects_bad_kind() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 1)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	stmt_cursor := ast.Cursor{
		flat: &fixture.flat
		id:   fixture.first_stmt_id
	}
	file_cursor := fixture.flat.file_cursor(0)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, stmt_cursor, [
		anchor,
	])
	assert locations.len == 0
}

fn test_autofree_statement_locator_file_cursor_rejects_different_flat_cursor_context() {
	file_fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false,
		false, .v, 1)
	fn_fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false,
		false, .v, 1)
	anchor := autofree_statement_locator_test_anchor(&fn_fixture)
	file_cursor := file_fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fn_fixture)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, [
		anchor,
	])
	assert locations.len == 0
}

fn test_autofree_statement_locator_file_cursor_rejects_same_flat_different_file_context() {
	fixture := autofree_statement_locator_test_flat_with_two_files()
	anchor := autofree_statement_locator_test_second_file_anchor(&fixture)
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fixture)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, [
		anchor,
	])
	assert locations.len == 0
}

fn test_autofree_statement_locator_rejects_duplicate_fn_key_across_files() {
	fixture := autofree_statement_locator_test_flat_with_two_files()
	anchor := autofree_statement_locator_test_second_file_anchor(&fixture)
	file_cursor := fixture.flat.file_cursor(1)
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fixture)
	file_locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, [
		anchor,
	])
	assert file_locations.len == 0
}

fn test_autofree_statement_locator_rejects_non_v_function() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.c, 1)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_empty_fn_key() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 1)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		fn_key: ''
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_fn_key_mismatch() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 1)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		fn_key: 'other_make_items'
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_fn_name_mismatch() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 1)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		fn_name: 'other_make_items'
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_flat_rejects_module_fn_key_mismatch() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'math', false, false,
		.v, 1)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_flat_rejects_qualified_key_for_root_module() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 1)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		fn_key: 'math__make_items'
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

// autofree_statement_preview_test

struct AutofreeStatementPreviewTestFlat {
	flat         ast.FlatAst
	fn_id        ast.FlatNodeId
	stmt_id      ast.FlatNodeId
	lhs_id       ast.FlatNodeId
	rhs_id       ast.FlatNodeId
	next_stmt_id ast.FlatNodeId
	next_lhs_id  ast.FlatNodeId
	next_rhs_id  ast.FlatNodeId
}

fn autofree_statement_preview_test_pos(id int) token.Pos {
	return token.Pos{
		offset: id
		id:     id
	}
}

fn autofree_statement_preview_test_array_init(mut b ast.FlatBuilder, pos_id int) ast.FlatNodeId {
	return b.emit_array_init_expr_by_ids(ast.invalid_flat_node_id, ast.invalid_flat_node_id,
		ast.invalid_flat_node_id, ast.invalid_flat_node_id, ast.invalid_flat_node_id,
		[]ast.FlatNodeId{}, autofree_statement_preview_test_pos(pos_id))
}

fn autofree_statement_preview_test_fn_cursor(fixture &AutofreeStatementPreviewTestFlat) ast.Cursor {
	return ast.Cursor{
		flat: &fixture.flat
		id:   fixture.fn_id
	}
}

fn autofree_statement_preview_test_flat_with_assigns(names []string, ops []token.Token) AutofreeStatementPreviewTestFlat {
	mut b := ast.new_flat_builder()
	mut stmt_ids := []ast.FlatNodeId{}
	mut lhs_ids := []ast.FlatNodeId{}
	mut rhs_ids := []ast.FlatNodeId{}
	for i, name in names {
		stmt_pos := 210 + i * 100
		lhs_pos := 120 + i * 100
		rhs_pos := 130 + i * 100
		lhs_id := b.emit_ident_by_name(name, autofree_statement_preview_test_pos(lhs_pos))
		rhs_id := autofree_statement_preview_test_array_init(mut b, rhs_pos)
		op := if i < ops.len { ops[i] } else { token.Token.decl_assign }
		stmt_id := b.emit_assign_stmt_by_ids(op, [lhs_id], [rhs_id],
			autofree_statement_preview_test_pos(stmt_pos))
		lhs_ids << lhs_id
		rhs_ids << rhs_id
		stmt_ids << stmt_id
	}
	body_id := b.emit_aux_list_from_ids(stmt_ids)
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_preview_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_preview_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementPreviewTestFlat{
		flat:         b.take_flat()
		fn_id:        fn_id
		stmt_id:      stmt_ids[0]
		lhs_id:       lhs_ids[0]
		rhs_id:       rhs_ids[0]
		next_stmt_id: if stmt_ids.len > 1 { stmt_ids[1] } else { ast.invalid_flat_node_id }
		next_lhs_id:  if lhs_ids.len > 1 { lhs_ids[1] } else { ast.invalid_flat_node_id }
		next_rhs_id:  if rhs_ids.len > 1 { rhs_ids[1] } else { ast.invalid_flat_node_id }
	}
}

fn autofree_statement_preview_test_flat_with_source_prefix_then_items() AutofreeStatementPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('copy', autofree_statement_preview_test_pos(120))
	first_rhs_id := b.emit_ident_by_name('source', autofree_statement_preview_test_pos(130))
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_preview_test_pos(210))
	next_lhs_id := b.emit_ident_by_name('items', autofree_statement_preview_test_pos(220))
	next_rhs_id := autofree_statement_preview_test_array_init(mut b, 230)
	next_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [next_lhs_id], [
		next_rhs_id,
	], autofree_statement_preview_test_pos(310))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, next_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_preview_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_preview_prefix_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementPreviewTestFlat{
		flat:         b.take_flat()
		fn_id:        fn_id
		stmt_id:      first_stmt_id
		lhs_id:       first_lhs_id
		rhs_id:       first_rhs_id
		next_stmt_id: next_stmt_id
		next_lhs_id:  next_lhs_id
		next_rhs_id:  next_rhs_id
	}
}

fn autofree_statement_preview_test_flat_with_later_insert_assignment() AutofreeStatementPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('arr', autofree_statement_preview_test_pos(120))
	first_rhs_id := autofree_statement_preview_test_array_init(mut b, 130)
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_preview_test_pos(210))
	block_id := b.emit_block_stmt_by_ids([])
	next_lhs_id := b.emit_ident_by_name('gen', autofree_statement_preview_test_pos(320))
	next_rhs_id := b.emit_ident_by_name('arr', autofree_statement_preview_test_pos(330))
	next_stmt_id := b.emit_assign_stmt_by_ids(.assign, [next_lhs_id], [
		next_rhs_id,
	], autofree_statement_preview_test_pos(410))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, block_id, next_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('next_generation', false, false, false, .v,
		autofree_statement_preview_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_preview_later_insert_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementPreviewTestFlat{
		flat:         b.take_flat()
		fn_id:        fn_id
		stmt_id:      first_stmt_id
		lhs_id:       first_lhs_id
		rhs_id:       first_rhs_id
		next_stmt_id: next_stmt_id
		next_lhs_id:  next_lhs_id
		next_rhs_id:  next_rhs_id
	}
}

fn autofree_statement_preview_test_flat_with_return() AutofreeStatementPreviewTestFlat {
	mut b := ast.new_flat_builder()
	rhs_id := autofree_statement_preview_test_array_init(mut b, 130)
	stmt_id := b.emit_return_stmt_by_ids([rhs_id])
	body_id := b.emit_aux_list_from_ids([stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_preview_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_preview_return.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementPreviewTestFlat{
		flat:    b.take_flat()
		fn_id:   fn_id
		stmt_id: stmt_id
		lhs_id:  rhs_id
		rhs_id:  rhs_id
	}
}

fn autofree_statement_preview_test_flat_with_nested_assign() AutofreeStatementPreviewTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_preview_test_pos(120))
	rhs_id := autofree_statement_preview_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [lhs_id], [rhs_id],
		autofree_statement_preview_test_pos(210))
	block_id := b.emit_block_stmt_by_ids([stmt_id])
	body_id := b.emit_aux_list_from_ids([block_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_preview_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_preview_nested.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementPreviewTestFlat{
		flat:    b.take_flat()
		fn_id:   fn_id
		stmt_id: stmt_id
		lhs_id:  lhs_id
		rhs_id:  rhs_id
	}
}

fn autofree_statement_preview_test_flat_with_two_files() AutofreeStatementPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('items', autofree_statement_preview_test_pos(120))
	first_rhs_id := autofree_statement_preview_test_array_init(mut b, 130)
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_preview_test_pos(210))
	first_body_id := b.emit_aux_list_from_ids([first_stmt_id])
	first_fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	first_attrs_id := b.emit_attribute_list([])
	first_fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_preview_test_pos(100), ast.invalid_flat_node_id, first_fn_type_id,
		first_attrs_id, first_body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_preview_first.v'
		mod:  'main'
	}, [first_fn_id])
	second_lhs_id := b.emit_ident_by_name('items', autofree_statement_preview_test_pos(320))
	second_rhs_id := autofree_statement_preview_test_array_init(mut b, 330)
	second_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [second_lhs_id], [
		second_rhs_id,
	], autofree_statement_preview_test_pos(410))
	second_body_id := b.emit_aux_list_from_ids([second_stmt_id])
	second_fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	second_attrs_id := b.emit_attribute_list([])
	second_fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_preview_test_pos(300), ast.invalid_flat_node_id, second_fn_type_id,
		second_attrs_id, second_body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_preview_second.v'
		mod:  'main'
	}, [second_fn_id])
	return AutofreeStatementPreviewTestFlat{
		flat:    b.take_flat()
		fn_id:   second_fn_id
		stmt_id: second_stmt_id
		lhs_id:  second_lhs_id
		rhs_id:  second_rhs_id
	}
}

fn autofree_statement_preview_test_location(fixture AutofreeStatementPreviewTestFlat) AutofreeCleanCStatementLocationFact {
	return AutofreeCleanCStatementLocationFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		location_status:      .inert
		fn_node_id:           fixture.fn_id
		fn_pos_id:            100
		stmt_node_id:         fixture.stmt_id
		stmt_pos_id:          210
		stmt_index:           0
		lhs_index:            0
		target_node_id:       fixture.lhs_id
		target_pos_id:        120
		insert_after_node_id: fixture.stmt_id
		insert_after_pos_id:  210
		reason:               'statement location accepted'
	}
}

fn autofree_statement_preview_test_next_location(fixture AutofreeStatementPreviewTestFlat) AutofreeCleanCStatementLocationFact {
	return AutofreeCleanCStatementLocationFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'more_items'
		location_status:      .inert
		fn_node_id:           fixture.fn_id
		fn_pos_id:            100
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          310
		stmt_index:           1
		lhs_index:            0
		target_node_id:       fixture.next_lhs_id
		target_pos_id:        220
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
		reason:               'statement location accepted'
	}
}

fn autofree_statement_preview_test_next_items_location(fixture AutofreeStatementPreviewTestFlat) AutofreeCleanCStatementLocationFact {
	return AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_next_location(fixture)
		name: 'items'
	}
}

fn autofree_statement_preview_test_later_insert_location(fixture AutofreeStatementPreviewTestFlat) AutofreeCleanCStatementLocationFact {
	return AutofreeCleanCStatementLocationFact{
		fn_key:               'next_generation'
		fn_name:              'next_generation'
		name:                 'arr'
		location_status:      .inert
		fn_node_id:           fixture.fn_id
		fn_pos_id:            100
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          410
		stmt_index:           2
		lhs_index:            0
		target_node_id:       fixture.lhs_id
		target_pos_id:        120
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  410
		reason:               'statement location accepted'
	}
}

fn autofree_statement_preview_test_second_file_location(fixture AutofreeStatementPreviewTestFlat) AutofreeCleanCStatementLocationFact {
	return AutofreeCleanCStatementLocationFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		location_status:      .inert
		fn_node_id:           fixture.fn_id
		fn_pos_id:            300
		stmt_node_id:         fixture.stmt_id
		stmt_pos_id:          410
		stmt_index:           0
		lhs_index:            0
		target_node_id:       fixture.lhs_id
		target_pos_id:        320
		insert_after_node_id: fixture.stmt_id
		insert_after_pos_id:  410
		reason:               'statement location accepted'
	}
}

fn autofree_statement_preview_test_previews(fixture &AutofreeStatementPreviewTestFlat,
	locations []AutofreeCleanCStatementLocationFact) []AutofreeCleanCStatementPreviewFact {
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_preview_test_fn_cursor(fixture)
	return autofree_statement_preview_facts_from_file_cursor(file_cursor, fn_cursor, locations)
}

fn autofree_statement_preview_test_assert_no_preview(fixture &AutofreeStatementPreviewTestFlat,
	locations []AutofreeCleanCStatementLocationFact) {
	previews := autofree_statement_preview_test_previews(fixture, locations)
	assert previews.len == 0
}

fn test_autofree_statement_preview_accepts_valid_location() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	previews := autofree_statement_preview_test_previews(&fixture, [location])
	assert previews.len == 1
	preview := previews[0]
	assert preview.fn_key == location.fn_key
	assert preview.fn_name == location.fn_name
	assert preview.name == location.name
	assert preview.preview_status == .inert
	assert preview.fn_node_id == location.fn_node_id
	assert preview.fn_pos_id == location.fn_pos_id
	assert preview.stmt_node_id == location.stmt_node_id
	assert preview.stmt_pos_id == location.stmt_pos_id
	assert preview.stmt_index == location.stmt_index
	assert preview.lhs_index == location.lhs_index
	assert preview.target_node_id == location.target_node_id
	assert preview.target_pos_id == location.target_pos_id
	assert preview.insert_after_node_id == location.insert_after_node_id
	assert preview.insert_after_pos_id == location.insert_after_pos_id
	assert preview.reason.len > 0
}

fn test_autofree_statement_preview_accepts_last_statement_after_prefix() {
	fixture := autofree_statement_preview_test_flat_with_source_prefix_then_items()
	location := autofree_statement_preview_test_next_items_location(fixture)
	previews := autofree_statement_preview_test_previews(&fixture, [location])
	assert previews.len == 1
	preview := previews[0]
	assert preview.name == 'items'
	assert preview.name != 'copy'
	assert preview.name != 'source'
	assert preview.stmt_index == 1
	assert preview.target_node_id == fixture.next_lhs_id
	assert preview.target_pos_id == 220
	assert preview.insert_after_node_id == fixture.next_stmt_id
	assert preview.insert_after_pos_id == 310
}

fn test_autofree_statement_preview_accepts_later_final_assignment_after_target_decl() {
	fixture := autofree_statement_preview_test_flat_with_later_insert_assignment()
	location := autofree_statement_preview_test_later_insert_location(fixture)
	previews := autofree_statement_preview_test_previews(&fixture, [location])
	assert previews.len == 1
	preview := previews[0]
	assert preview.fn_key == 'next_generation'
	assert preview.fn_name == 'next_generation'
	assert preview.name == 'arr'
	assert preview.stmt_index == 2
	assert preview.target_node_id == fixture.lhs_id
	assert preview.target_pos_id == 120
	assert preview.stmt_node_id == fixture.next_stmt_id
	assert preview.stmt_pos_id == 410
	assert preview.insert_after_node_id == fixture.next_stmt_id
	assert preview.insert_after_pos_id == 410
	assert preview.lhs_index == 0
}

fn test_autofree_statement_preview_rejects_return_statement() {
	fixture := autofree_statement_preview_test_flat_with_return()
	location := autofree_statement_preview_test_location(fixture)
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_nested_assign() {
	fixture := autofree_statement_preview_test_flat_with_nested_assign()
	location := autofree_statement_preview_test_location(fixture)
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_cross_file_context() {
	fixture := autofree_statement_preview_test_flat_with_two_files()
	location := autofree_statement_preview_test_second_file_location(fixture)
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_preview_test_fn_cursor(&fixture)
	previews := autofree_statement_preview_facts_from_file_cursor(file_cursor, fn_cursor, [
		location,
	])
	assert previews.len == 0
}

fn test_autofree_statement_preview_rejects_later_assign_to_same_name() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items', 'items'], [
		.decl_assign,
		.assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_non_last_statement() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items', 'more_items'], [
		.decl_assign,
		.decl_assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_prefix_target_as_non_last_statement() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['copy', 'items'], [
		.decl_assign,
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		name: 'copy'
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_bad_status() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		location_status: .unknown
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_empty_fn_key() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		fn_key: ''
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_empty_fn_name() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		fn_name: ''
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_empty_name() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		name: ''
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_invalid_fn_ids() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		fn_node_id: ast.FlatNodeId(-1)
		fn_pos_id:  0
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_invalid_stmt_ids() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		stmt_node_id: ast.FlatNodeId(-1)
		stmt_pos_id:  0
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_invalid_target_ids() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		target_node_id: ast.FlatNodeId(-1)
		target_pos_id:  0
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_invalid_insert_after_ids() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		insert_after_node_id: ast.FlatNodeId(-1)
		insert_after_pos_id:  0
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_target_equal_insert_after() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		insert_after_node_id: fixture.lhs_id
		insert_after_pos_id:  120
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_stmt_mismatch() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		stmt_node_id: ast.FlatNodeId(int(fixture.stmt_id) + 1)
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_stmt_pos_mismatch() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		stmt_pos_id: 211
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_negative_stmt_index() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		stmt_index: -1
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_nonzero_lhs_index() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		lhs_index: 1
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_duplicate_name() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items', 'more_items'], [
		.decl_assign,
		.decl_assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	duplicate := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_next_location(fixture)
		name: 'items'
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location, duplicate])
}

fn test_autofree_statement_preview_rejects_duplicate_target_position() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items', 'more_items'], [
		.decl_assign,
		.decl_assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	duplicate := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_next_location(fixture)
		target_node_id: fixture.lhs_id
		target_pos_id:  120
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location, duplicate])
}

fn test_autofree_statement_preview_rejects_duplicate_insertion_slot() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	duplicate := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		name:                 'more_items'
		target_node_id:       fixture.rhs_id
		target_pos_id:        130
		stmt_node_id:         fixture.rhs_id
		stmt_pos_id:          130
		insert_after_node_id: fixture.stmt_id
		insert_after_pos_id:  210
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location, duplicate])
}

fn test_autofree_statement_preview_rejects_duplicate_statement_position() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	duplicate := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		name:                 'more_items'
		target_node_id:       fixture.fn_id
		target_pos_id:        100
		insert_after_node_id: fixture.rhs_id
		insert_after_pos_id:  130
		stmt_node_id:         fixture.stmt_id
		stmt_pos_id:          210
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location, duplicate])
}

fn test_autofree_statement_preview_rejects_valid_plus_invalid_group() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items', 'more_items'], [
		.decl_assign,
		.decl_assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	invalid := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_next_location(fixture)
		location_status: .unknown
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location, invalid])
}

fn test_autofree_statement_preview_rejects_mixed_function_group() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items', 'more_items'], [
		.decl_assign,
		.decl_assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	mixed := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_next_location(fixture)
		fn_key:  'other_fn'
		fn_name: 'other_fn'
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location, mixed])
}

// autofree_statement_intent_test

fn autofree_statement_intent_test_preview() AutofreeCleanCStatementPreviewFact {
	return AutofreeCleanCStatementPreviewFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		preview_status:       .inert
		fn_node_id:           ast.FlatNodeId(10)
		fn_pos_id:            100
		target_node_id:       ast.FlatNodeId(20)
		target_pos_id:        120
		stmt_node_id:         ast.FlatNodeId(30)
		stmt_pos_id:          210
		insert_after_node_id: ast.FlatNodeId(30)
		insert_after_pos_id:  210
		stmt_index:           0
		lhs_index:            0
		reason:               'statement preview accepted'
	}
}

fn autofree_statement_intent_test_assert_no_intent(previews []AutofreeCleanCStatementPreviewFact) {
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 0
}

fn autofree_statement_intent_test_assert_no_named_intent(case_name string, previews []AutofreeCleanCStatementPreviewFact) {
	assert case_name.len > 0
	autofree_statement_intent_test_assert_no_intent(previews)
}

fn test_autofree_statement_intent_accepts_single_preview() {
	preview := autofree_statement_intent_test_preview()
	intents := autofree_statement_intent_facts_from_previews([preview])
	assert intents.len == 1
	intent := intents[0]
	assert intent.fn_key == preview.fn_key
	assert intent.fn_name == preview.fn_name
	assert intent.name == preview.name
	assert intent.intent_status == .inert
	assert intent.intent_kind == .after_statement
	assert intent.fn_node_id == preview.fn_node_id
	assert intent.fn_pos_id == preview.fn_pos_id
	assert intent.target_node_id == preview.target_node_id
	assert intent.target_pos_id == preview.target_pos_id
	assert intent.stmt_node_id == preview.stmt_node_id
	assert intent.stmt_pos_id == preview.stmt_pos_id
	assert intent.insert_after_node_id == preview.insert_after_node_id
	assert intent.insert_after_pos_id == preview.insert_after_pos_id
	assert intent.stmt_index == preview.stmt_index
	assert intent.lhs_index == preview.lhs_index
	assert intent.reason.len > 0
}

fn test_autofree_statement_intent_accepts_distinct_preview_list() {
	first := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		name: 'first'
	}
	second := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		name:           'second'
		target_node_id: ast.FlatNodeId(40)
		target_pos_id:  220
	}
	intents := autofree_statement_intent_facts_from_previews([first, second])
	assert intents.len == 2
	assert intents[0].name == 'first'
	assert intents[1].name == 'second'
}

fn test_autofree_statement_intent_rejects_empty_preview_list() {
	autofree_statement_intent_test_assert_no_intent([]AutofreeCleanCStatementPreviewFact{})
}

fn test_autofree_statement_intent_rejects_two_previews() {
	preview := autofree_statement_intent_test_preview()
	autofree_statement_intent_test_assert_no_intent([preview, preview])
}

fn test_autofree_statement_intent_rejects_target_equal_insert_after() {
	preview := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		target_node_id: ast.FlatNodeId(30)
	}
	autofree_statement_intent_test_assert_no_intent([preview])
}

fn test_autofree_statement_intent_rejects_invalid_preview_fields() {
	base := autofree_statement_intent_test_preview()
	cases := [
		'unknown_status',
		'empty_fn_key',
		'empty_fn_name',
		'empty_name',
		'invalid_fn_ids',
		'invalid_target_ids',
		'invalid_stmt_ids',
		'invalid_insert_after_ids',
		'negative_stmt_index',
		'nonzero_lhs_index',
	]
	previews := [
		AutofreeCleanCStatementPreviewFact{
			...base
			preview_status: .unknown
		},
		AutofreeCleanCStatementPreviewFact{
			...base
			fn_key: ''
		},
		AutofreeCleanCStatementPreviewFact{
			...base
			fn_name: ''
		},
		AutofreeCleanCStatementPreviewFact{
			...base
			name: ''
		},
		AutofreeCleanCStatementPreviewFact{
			...base
			fn_node_id: ast.FlatNodeId(-1)
			fn_pos_id:  0
		},
		AutofreeCleanCStatementPreviewFact{
			...base
			target_node_id: ast.FlatNodeId(-1)
			target_pos_id:  0
		},
		AutofreeCleanCStatementPreviewFact{
			...base
			stmt_node_id: ast.FlatNodeId(-1)
			stmt_pos_id:  0
		},
		AutofreeCleanCStatementPreviewFact{
			...base
			insert_after_node_id: ast.FlatNodeId(-1)
			insert_after_pos_id:  0
		},
		AutofreeCleanCStatementPreviewFact{
			...base
			stmt_index: -1
		},
		AutofreeCleanCStatementPreviewFact{
			...base
			lhs_index: 1
		},
	]
	assert cases.len == previews.len
	for index, invalid_case in cases {
		preview := previews[index]
		autofree_statement_intent_test_assert_no_named_intent(invalid_case, [preview])
	}
}

fn test_autofree_statement_intent_rejects_cursor_slot_mismatch() {
	base := autofree_statement_intent_test_preview()
	cases := [
		'stmt_node_mismatch',
		'stmt_pos_mismatch',
	]
	previews := [
		AutofreeCleanCStatementPreviewFact{
			...base
			insert_after_node_id: ast.FlatNodeId(31)
		},
		AutofreeCleanCStatementPreviewFact{
			...base
			insert_after_pos_id: 211
		},
	]
	assert cases.len == previews.len
	for index, invalid_case in cases {
		preview := previews[index]
		autofree_statement_intent_test_assert_no_named_intent(invalid_case, [preview])
	}
}

// autofree_statement_emission_slot_test

fn autofree_statement_emission_slot_test_intent() AutofreeCleanCStatementIntentFact {
	return AutofreeCleanCStatementIntentFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		intent_status:        .inert
		intent_kind:          .after_statement
		fn_node_id:           ast.FlatNodeId(10)
		fn_pos_id:            100
		target_node_id:       ast.FlatNodeId(20)
		target_pos_id:        120
		stmt_node_id:         ast.FlatNodeId(30)
		stmt_pos_id:          210
		insert_after_node_id: ast.FlatNodeId(30)
		insert_after_pos_id:  210
		stmt_index:           0
		lhs_index:            0
		reason:               'statement intent accepted'
	}
}

fn autofree_statement_emission_slot_test_assert_no_slot(intents []AutofreeCleanCStatementIntentFact) {
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 0
}

fn autofree_statement_emission_slot_test_assert_no_named_slot(case_name string, intents []AutofreeCleanCStatementIntentFact) {
	assert case_name.len > 0
	autofree_statement_emission_slot_test_assert_no_slot(intents)
}

fn test_autofree_statement_emission_slot_accepts_single_intent() {
	intent := autofree_statement_emission_slot_test_intent()
	slots := autofree_statement_emission_slot_facts_from_intents([intent])
	assert slots.len == 1
	slot := slots[0]
	assert slot.fn_key == intent.fn_key
	assert slot.fn_name == intent.fn_name
	assert slot.name == intent.name
	assert slot.slot_status == .inert
	assert slot.slot_kind == .after_statement
	assert slot.fn_node_id == intent.fn_node_id
	assert slot.fn_pos_id == intent.fn_pos_id
	assert slot.target_node_id == intent.target_node_id
	assert slot.target_pos_id == intent.target_pos_id
	assert slot.stmt_node_id == intent.stmt_node_id
	assert slot.stmt_pos_id == intent.stmt_pos_id
	assert slot.insert_after_node_id == intent.insert_after_node_id
	assert slot.insert_after_pos_id == intent.insert_after_pos_id
	assert slot.stmt_index == intent.stmt_index
	assert slot.lhs_index == intent.lhs_index
	assert slot.reason.len > 0
}

fn test_autofree_statement_emission_slot_accepts_distinct_intent_list() {
	first := AutofreeCleanCStatementIntentFact{
		...autofree_statement_emission_slot_test_intent()
		name: 'first'
	}
	second := AutofreeCleanCStatementIntentFact{
		...autofree_statement_emission_slot_test_intent()
		name:           'second'
		target_node_id: ast.FlatNodeId(40)
		target_pos_id:  220
	}
	slots := autofree_statement_emission_slot_facts_from_intents([first, second])
	assert slots.len == 2
	assert slots[0].name == 'first'
	assert slots[1].name == 'second'
}

fn test_autofree_statement_emission_slot_rejects_empty_intent_list() {
	autofree_statement_emission_slot_test_assert_no_slot([]AutofreeCleanCStatementIntentFact{})
}

fn test_autofree_statement_emission_slot_rejects_two_intents() {
	intent := autofree_statement_emission_slot_test_intent()
	autofree_statement_emission_slot_test_assert_no_slot([intent, intent])
}

fn test_autofree_statement_emission_slot_rejects_target_equal_insert_after() {
	intent := AutofreeCleanCStatementIntentFact{
		...autofree_statement_emission_slot_test_intent()
		target_node_id: ast.FlatNodeId(30)
	}
	autofree_statement_emission_slot_test_assert_no_slot([intent])
}

fn test_autofree_statement_emission_slot_rejects_invalid_intent_fields() {
	base := autofree_statement_emission_slot_test_intent()
	cases := [
		'unknown_status',
		'unknown_kind',
		'empty_fn_key',
		'empty_fn_name',
		'empty_name',
		'invalid_fn_ids',
		'invalid_target_ids',
		'invalid_stmt_ids',
		'invalid_insert_after_ids',
		'negative_stmt_index',
		'nonzero_lhs_index',
	]
	intents := [
		AutofreeCleanCStatementIntentFact{
			...base
			intent_status: .unknown
		},
		AutofreeCleanCStatementIntentFact{
			...base
			intent_kind: .unknown
		},
		AutofreeCleanCStatementIntentFact{
			...base
			fn_key: ''
		},
		AutofreeCleanCStatementIntentFact{
			...base
			fn_name: ''
		},
		AutofreeCleanCStatementIntentFact{
			...base
			name: ''
		},
		AutofreeCleanCStatementIntentFact{
			...base
			fn_node_id: ast.FlatNodeId(-1)
			fn_pos_id:  0
		},
		AutofreeCleanCStatementIntentFact{
			...base
			target_node_id: ast.FlatNodeId(-1)
			target_pos_id:  0
		},
		AutofreeCleanCStatementIntentFact{
			...base
			stmt_node_id: ast.FlatNodeId(-1)
			stmt_pos_id:  0
		},
		AutofreeCleanCStatementIntentFact{
			...base
			insert_after_node_id: ast.FlatNodeId(-1)
			insert_after_pos_id:  0
		},
		AutofreeCleanCStatementIntentFact{
			...base
			stmt_index: -1
		},
		AutofreeCleanCStatementIntentFact{
			...base
			lhs_index: 1
		},
	]
	assert cases.len == intents.len
	for index, invalid_case in cases {
		intent := intents[index]
		autofree_statement_emission_slot_test_assert_no_named_slot(invalid_case, [
			intent,
		])
	}
}

fn test_autofree_statement_emission_slot_rejects_cursor_slot_mismatch() {
	base := autofree_statement_emission_slot_test_intent()
	cases := [
		'stmt_node_mismatch',
		'stmt_pos_mismatch',
	]
	intents := [
		AutofreeCleanCStatementIntentFact{
			...base
			insert_after_node_id: ast.FlatNodeId(31)
		},
		AutofreeCleanCStatementIntentFact{
			...base
			insert_after_pos_id: 211
		},
	]
	assert cases.len == intents.len
	for index, invalid_case in cases {
		intent := intents[index]
		autofree_statement_emission_slot_test_assert_no_named_slot(invalid_case, [
			intent,
		])
	}
}

// autofree_statement_cleanup_preview_test

fn autofree_statement_cleanup_preview_test_slot() AutofreeCleanCStatementEmissionSlotFact {
	return AutofreeCleanCStatementEmissionSlotFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		move_kind:            .fresh_local_binding
		slot_status:          .inert
		slot_kind:            .after_statement
		fn_node_id:           ast.FlatNodeId(10)
		fn_pos_id:            100
		target_node_id:       ast.FlatNodeId(20)
		target_pos_id:        120
		stmt_node_id:         ast.FlatNodeId(30)
		stmt_pos_id:          210
		insert_after_node_id: ast.FlatNodeId(30)
		insert_after_pos_id:  210
		stmt_index:           0
		lhs_index:            0
		reason:               'statement emission slot accepted'
	}
}

fn autofree_statement_cleanup_preview_test_assert_no_preview(slots []AutofreeCleanCStatementEmissionSlotFact) {
	previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert previews.len == 0
}

fn autofree_statement_cleanup_preview_test_assert_no_named_preview(case_name string, slots []AutofreeCleanCStatementEmissionSlotFact) {
	assert case_name.len > 0
	autofree_statement_cleanup_preview_test_assert_no_preview(slots)
}

fn test_autofree_statement_cleanup_preview_accepts_normal_name() {
	slot := autofree_statement_cleanup_preview_test_slot()
	previews := autofree_statement_cleanup_preview_facts_from_slots([slot])
	assert previews.len == 1
	preview := previews[0]
	assert preview.fn_key == slot.fn_key
	assert preview.fn_name == slot.fn_name
	assert preview.name == slot.name
	assert preview.cleanup_status == .inert
	assert preview.cleanup_kind == .array_after_statement
	assert preview.fn_node_id == slot.fn_node_id
	assert preview.fn_pos_id == slot.fn_pos_id
	assert preview.target_node_id == slot.target_node_id
	assert preview.target_pos_id == slot.target_pos_id
	assert preview.stmt_node_id == slot.stmt_node_id
	assert preview.stmt_pos_id == slot.stmt_pos_id
	assert preview.insert_after_node_id == slot.insert_after_node_id
	assert preview.insert_after_pos_id == slot.insert_after_pos_id
	assert preview.stmt_index == slot.stmt_index
	assert preview.lhs_index == slot.lhs_index
	assert preview.target_c_name == 'items'
	assert preview.cleanup_symbol == 'array__free'
	assert preview.cleanup_text == 'array__free(&items);'
	assert preview.reason.len > 0
}

fn test_autofree_statement_cleanup_preview_accepts_fresh_local_string_clone_push_name() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		fn_key:    'push_joined'
		fn_name:   'push_joined'
		name:      'text'
		move_kind: .fresh_local_string_clone_push_binding
	}
	previews := autofree_statement_cleanup_preview_facts_from_slots([slot])
	assert previews.len == 1
	preview := previews[0]
	assert preview.fn_key == slot.fn_key
	assert preview.fn_name == slot.fn_name
	assert preview.name == 'text'
	assert preview.move_kind == .fresh_local_string_clone_push_binding
	assert preview.cleanup_status == .inert
	assert preview.cleanup_kind == .string_after_statement
	assert preview.target_c_name == 'text'
	assert preview.cleanup_symbol == 'string__free'
	assert preview.cleanup_text == 'string__free(&text);'
	assert preview.reason.len > 0
}

fn test_autofree_statement_cleanup_preview_escapes_c_keyword_name() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		name: '@return'
	}
	previews := autofree_statement_cleanup_preview_facts_from_slots([slot])
	assert previews.len == 1
	assert previews[0].target_c_name == '_return'
	assert previews[0].cleanup_text == 'array__free(&_return);'
}

fn test_autofree_statement_cleanup_preview_escapes_array_name() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		name: 'array'
	}
	previews := autofree_statement_cleanup_preview_facts_from_slots([slot])
	assert previews.len == 1
	assert previews[0].target_c_name == '_v_array'
	assert previews[0].cleanup_text == 'array__free(&_v_array);'
}

fn test_autofree_statement_cleanup_preview_accepts_distinct_slot_list() {
	first := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		name: 'first'
	}
	second := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		name:           'second'
		target_node_id: ast.FlatNodeId(40)
		target_pos_id:  220
	}
	previews := autofree_statement_cleanup_preview_facts_from_slots([first, second])
	assert previews.len == 2
	assert previews[0].cleanup_text == 'array__free(&first);'
	assert previews[1].cleanup_text == 'array__free(&second);'
}

fn test_autofree_statement_cleanup_preview_rejects_empty_slot_list() {
	autofree_statement_cleanup_preview_test_assert_no_preview([]AutofreeCleanCStatementEmissionSlotFact{})
}

fn test_autofree_statement_cleanup_preview_rejects_two_slots() {
	slot := autofree_statement_cleanup_preview_test_slot()
	autofree_statement_cleanup_preview_test_assert_no_preview([slot, slot])
}

fn test_autofree_statement_cleanup_preview_rejects_invalid_slot_fields() {
	base := autofree_statement_cleanup_preview_test_slot()
	cases := [
		'unknown_status',
		'unknown_kind',
		'empty_fn_key',
		'empty_fn_name',
		'empty_name',
		'invalid_fn_ids',
		'invalid_target_ids',
		'invalid_stmt_ids',
		'invalid_insert_after_ids',
		'stmt_node_mismatch',
		'stmt_pos_mismatch',
		'target_equal_insert_after',
		'negative_stmt_index',
		'nonzero_lhs_index',
	]
	slots := [
		AutofreeCleanCStatementEmissionSlotFact{
			...base
			slot_status: .unknown
		},
		AutofreeCleanCStatementEmissionSlotFact{
			...base
			slot_kind: .unknown
		},
		AutofreeCleanCStatementEmissionSlotFact{
			...base
			fn_key: ''
		},
		AutofreeCleanCStatementEmissionSlotFact{
			...base
			fn_name: ''
		},
		AutofreeCleanCStatementEmissionSlotFact{
			...base
			name: ''
		},
		AutofreeCleanCStatementEmissionSlotFact{
			...base
			fn_node_id: ast.FlatNodeId(-1)
			fn_pos_id:  0
		},
		AutofreeCleanCStatementEmissionSlotFact{
			...base
			target_node_id: ast.FlatNodeId(-1)
			target_pos_id:  0
		},
		AutofreeCleanCStatementEmissionSlotFact{
			...base
			stmt_node_id: ast.FlatNodeId(-1)
			stmt_pos_id:  0
		},
		AutofreeCleanCStatementEmissionSlotFact{
			...base
			insert_after_node_id: ast.FlatNodeId(-1)
			insert_after_pos_id:  0
		},
		AutofreeCleanCStatementEmissionSlotFact{
			...base
			insert_after_node_id: ast.FlatNodeId(31)
		},
		AutofreeCleanCStatementEmissionSlotFact{
			...base
			insert_after_pos_id: 211
		},
		AutofreeCleanCStatementEmissionSlotFact{
			...base
			target_node_id: ast.FlatNodeId(30)
		},
		AutofreeCleanCStatementEmissionSlotFact{
			...base
			stmt_index: -1
		},
		AutofreeCleanCStatementEmissionSlotFact{
			...base
			lhs_index: 1
		},
	]
	assert cases.len == slots.len
	for index, invalid_case in cases {
		slot := slots[index]
		autofree_statement_cleanup_preview_test_assert_no_named_preview(invalid_case, [
			slot,
		])
	}
}

// autofree_statement_cleanup_hook_preview_test

struct AutofreeStatementCleanupHookPreviewTestFlat {
	flat         ast.FlatAst
	fn_id        ast.FlatNodeId
	stmt_id      ast.FlatNodeId
	lhs_id       ast.FlatNodeId
	rhs_id       ast.FlatNodeId
	next_stmt_id ast.FlatNodeId
	next_lhs_id  ast.FlatNodeId
	next_rhs_id  ast.FlatNodeId
}

fn autofree_statement_cleanup_hook_preview_test_pos(id int) token.Pos {
	return token.Pos{
		offset: id
		id:     id
	}
}

fn autofree_statement_cleanup_hook_preview_test_array_init(mut b ast.FlatBuilder, pos_id int) ast.FlatNodeId {
	return b.emit_array_init_expr_by_ids(ast.invalid_flat_node_id, ast.invalid_flat_node_id,
		ast.invalid_flat_node_id, ast.invalid_flat_node_id, ast.invalid_flat_node_id,
		[]ast.FlatNodeId{}, autofree_statement_cleanup_hook_preview_test_pos(pos_id))
}

fn autofree_statement_cleanup_hook_preview_test_fn_cursor(fixture &AutofreeStatementCleanupHookPreviewTestFlat) ast.Cursor {
	return ast.Cursor{
		flat: &fixture.flat
		id:   fixture.fn_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_assigns(names []string, ops []token.Token) AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	mut stmt_ids := []ast.FlatNodeId{}
	mut lhs_ids := []ast.FlatNodeId{}
	mut rhs_ids := []ast.FlatNodeId{}
	for i, name in names {
		stmt_pos := 210 + i * 100
		lhs_pos := 120 + i * 100
		rhs_pos := 130 + i * 100
		lhs_id := b.emit_ident_by_name(name,
			autofree_statement_cleanup_hook_preview_test_pos(lhs_pos))
		rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, rhs_pos)
		op := if i < ops.len { ops[i] } else { token.Token.decl_assign }
		stmt_id := b.emit_assign_stmt_by_ids(op, [lhs_id], [rhs_id],
			autofree_statement_cleanup_hook_preview_test_pos(stmt_pos))
		lhs_ids << lhs_id
		rhs_ids << rhs_id
		stmt_ids << stmt_id
	}
	body_id := b.emit_aux_list_from_ids(stmt_ids)
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:         b.take_flat()
		fn_id:        fn_id
		stmt_id:      stmt_ids[0]
		lhs_id:       lhs_ids[0]
		rhs_id:       rhs_ids[0]
		next_stmt_id: if stmt_ids.len > 1 { stmt_ids[1] } else { ast.invalid_flat_node_id }
		next_lhs_id:  if lhs_ids.len > 1 { lhs_ids[1] } else { ast.invalid_flat_node_id }
		next_rhs_id:  if rhs_ids.len > 1 { rhs_ids[1] } else { ast.invalid_flat_node_id }
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_source_prefix_then_items() AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('copy',
		autofree_statement_cleanup_hook_preview_test_pos(120))
	first_rhs_id := b.emit_ident_by_name('source',
		autofree_statement_cleanup_hook_preview_test_pos(130))
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(210))
	next_lhs_id := b.emit_ident_by_name('items',
		autofree_statement_cleanup_hook_preview_test_pos(220))
	next_rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 230)
	next_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [next_lhs_id], [
		next_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(310))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, next_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_prefix_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:         b.take_flat()
		fn_id:        fn_id
		stmt_id:      first_stmt_id
		lhs_id:       first_lhs_id
		rhs_id:       first_rhs_id
		next_stmt_id: next_stmt_id
		next_lhs_id:  next_lhs_id
		next_rhs_id:  next_rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_later_insert_assignment() AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('arr',
		autofree_statement_cleanup_hook_preview_test_pos(120))
	first_rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 130)
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(210))
	block_id := b.emit_block_stmt_by_ids([])
	next_lhs_id := b.emit_ident_by_name('gen',
		autofree_statement_cleanup_hook_preview_test_pos(320))
	next_rhs_id := b.emit_ident_by_name('arr',
		autofree_statement_cleanup_hook_preview_test_pos(330))
	next_stmt_id := b.emit_assign_stmt_by_ids(.assign, [next_lhs_id], [
		next_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(410))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, block_id, next_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('next_generation', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_later_insert_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:         b.take_flat()
		fn_id:        fn_id
		stmt_id:      first_stmt_id
		lhs_id:       first_lhs_id
		rhs_id:       first_rhs_id
		next_stmt_id: next_stmt_id
		next_lhs_id:  next_lhs_id
		next_rhs_id:  next_rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_two_targets_and_literal_final() AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('first',
		autofree_statement_cleanup_hook_preview_test_pos(120))
	first_rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 130)
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(210))
	second_lhs_id := b.emit_ident_by_name('second',
		autofree_statement_cleanup_hook_preview_test_pos(220))
	second_rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 230)
	second_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [second_lhs_id], [
		second_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(310))
	final_lhs_id := b.emit_ident_by_name('sink',
		autofree_statement_cleanup_hook_preview_test_pos(320))
	final_rhs_id := b.emit_basic_literal_by_value(.number, '1',
		autofree_statement_cleanup_hook_preview_test_pos(330))
	final_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [final_lhs_id], [
		final_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(410))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, second_stmt_id, final_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_literal_final_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:         b.take_flat()
		fn_id:        fn_id
		stmt_id:      first_stmt_id
		lhs_id:       first_lhs_id
		rhs_id:       first_rhs_id
		next_stmt_id: final_stmt_id
		next_lhs_id:  second_lhs_id
		next_rhs_id:  second_rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_modifier_assign(kind token.Token, extra_child bool) AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_cleanup_hook_preview_test_pos(120))
	extra_lhs_id := b.emit_ident_by_name('extra_items',
		autofree_statement_cleanup_hook_preview_test_pos(121))
	modifier_id := b.emit_modifier_expr_by_id(kind, lhs_id,
		autofree_statement_cleanup_hook_preview_test_pos(119))
	rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [modifier_id], [rhs_id],
		autofree_statement_cleanup_hook_preview_test_pos(210))
	body_id := b.emit_aux_list_from_ids([stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_modifier.v'
		mod:  'main'
	}, [fn_id])
	mut flat := b.take_flat()
	if extra_child {
		flat.nodes[modifier_id].first_edge = flat.edges.len
		flat.nodes[modifier_id].edge_count = 2
		flat.edges << ast.FlatEdge{
			child_id: lhs_id
		}
		flat.edges << ast.FlatEdge{
			child_id: extra_lhs_id
		}
	}
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:    flat
		fn_id:   fn_id
		stmt_id: stmt_id
		lhs_id:  lhs_id
		rhs_id:  rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_multi_lhs() AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('items',
		autofree_statement_cleanup_hook_preview_test_pos(120))
	second_lhs_id := b.emit_ident_by_name('other',
		autofree_statement_cleanup_hook_preview_test_pos(125))
	rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id, second_lhs_id], [
		rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(210))
	body_id := b.emit_aux_list_from_ids([stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_multi.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:    b.take_flat()
		fn_id:   fn_id
		stmt_id: stmt_id
		lhs_id:  first_lhs_id
		rhs_id:  rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_return() AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 130)
	stmt_id := b.emit_return_stmt_by_ids([rhs_id])
	body_id := b.emit_aux_list_from_ids([stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_return.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:    b.take_flat()
		fn_id:   fn_id
		stmt_id: stmt_id
		lhs_id:  rhs_id
		rhs_id:  rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_nested_assign() AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_cleanup_hook_preview_test_pos(120))
	rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [lhs_id], [rhs_id],
		autofree_statement_cleanup_hook_preview_test_pos(210))
	block_id := b.emit_block_stmt_by_ids([stmt_id])
	body_id := b.emit_aux_list_from_ids([block_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_nested.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:    b.take_flat()
		fn_id:   fn_id
		stmt_id: stmt_id
		lhs_id:  lhs_id
		rhs_id:  rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_two_files() AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('items',
		autofree_statement_cleanup_hook_preview_test_pos(120))
	first_rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 130)
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(210))
	first_body_id := b.emit_aux_list_from_ids([first_stmt_id])
	first_fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	first_attrs_id := b.emit_attribute_list([])
	first_fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		first_fn_type_id, first_attrs_id, first_body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_first.v'
		mod:  'main'
	}, [first_fn_id])
	second_lhs_id := b.emit_ident_by_name('items',
		autofree_statement_cleanup_hook_preview_test_pos(320))
	second_rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 330)
	second_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [second_lhs_id], [
		second_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(410))
	second_body_id := b.emit_aux_list_from_ids([second_stmt_id])
	second_fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	second_attrs_id := b.emit_attribute_list([])
	second_fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(300), ast.invalid_flat_node_id,
		second_fn_type_id, second_attrs_id, second_body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_second.v'
		mod:  'main'
	}, [second_fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:    b.take_flat()
		fn_id:   second_fn_id
		stmt_id: second_stmt_id
		lhs_id:  second_lhs_id
		rhs_id:  second_rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_preview(fixture AutofreeStatementCleanupHookPreviewTestFlat) AutofreeCleanCStatementCleanupPreviewFact {
	return autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, 'items',
		c_local_name('items'))
}

fn autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture AutofreeStatementCleanupHookPreviewTestFlat, name string, target_c_name string) AutofreeCleanCStatementCleanupPreviewFact {
	return AutofreeCleanCStatementCleanupPreviewFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 name
		move_kind:            .fresh_local_binding
		cleanup_status:       .inert
		cleanup_kind:         .array_after_statement
		fn_node_id:           fixture.fn_id
		fn_pos_id:            100
		target_node_id:       fixture.lhs_id
		target_pos_id:        120
		stmt_node_id:         fixture.stmt_id
		stmt_pos_id:          210
		insert_after_node_id: fixture.stmt_id
		insert_after_pos_id:  210
		stmt_index:           0
		lhs_index:            0
		target_c_name:        target_c_name
		cleanup_symbol:       'array__free'
		cleanup_text:         'array__free(&${target_c_name});'
		reason:               'statement cleanup preview accepted'
	}
}

fn autofree_statement_cleanup_hook_preview_test_next_items_preview(fixture AutofreeStatementCleanupHookPreviewTestFlat) AutofreeCleanCStatementCleanupPreviewFact {
	return AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, 'items',
			c_local_name('items'))
		target_node_id:       fixture.next_lhs_id
		target_pos_id:        220
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          310
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
		stmt_index:           1
	}
}

fn autofree_statement_cleanup_hook_preview_test_later_insert_preview(fixture AutofreeStatementCleanupHookPreviewTestFlat) AutofreeCleanCStatementCleanupPreviewFact {
	return AutofreeCleanCStatementCleanupPreviewFact{
		fn_key:               'next_generation'
		fn_name:              'next_generation'
		name:                 'arr'
		move_kind:            .fresh_local_binding
		cleanup_status:       .inert
		cleanup_kind:         .array_after_statement
		fn_node_id:           fixture.fn_id
		fn_pos_id:            100
		target_node_id:       fixture.lhs_id
		target_pos_id:        120
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          410
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  410
		stmt_index:           2
		lhs_index:            0
		target_c_name:        c_local_name('arr')
		cleanup_symbol:       'array__free'
		cleanup_text:         'array__free(&arr);'
		reason:               'statement cleanup preview accepted'
	}
}

fn autofree_statement_cleanup_hook_preview_test_previews(fixture &AutofreeStatementCleanupHookPreviewTestFlat,
	previews []AutofreeCleanCStatementCleanupPreviewFact) []AutofreeCleanCStatementCleanupHookPreviewFact {
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_cleanup_hook_preview_test_fn_cursor(fixture)
	return autofree_statement_cleanup_hook_preview_facts_from_file_cursor(file_cursor, fn_cursor,
		previews)
}

fn autofree_statement_cleanup_hook_preview_test_assert_no_hook(fixture &AutofreeStatementCleanupHookPreviewTestFlat,
	previews []AutofreeCleanCStatementCleanupPreviewFact) {
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(fixture, previews)
	assert hook_previews.len == 0
}

fn test_autofree_statement_cleanup_hook_preview_accepts_valid_preview() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(&fixture, [
		preview,
	])
	assert hook_previews.len == 1
	hook_preview := hook_previews[0]
	assert hook_preview.fn_key == preview.fn_key
	assert hook_preview.fn_name == preview.fn_name
	assert hook_preview.name == preview.name
	assert hook_preview.hook_status == .inert
	assert hook_preview.hook_kind == .after_body_before_scheduled_drops
	assert hook_preview.fn_node_id == preview.fn_node_id
	assert hook_preview.fn_pos_id == preview.fn_pos_id
	assert hook_preview.target_node_id == preview.target_node_id
	assert hook_preview.target_pos_id == preview.target_pos_id
	assert hook_preview.stmt_node_id == preview.stmt_node_id
	assert hook_preview.stmt_pos_id == preview.stmt_pos_id
	assert hook_preview.insert_after_node_id == preview.insert_after_node_id
	assert hook_preview.insert_after_pos_id == preview.insert_after_pos_id
	assert hook_preview.stmt_index == preview.stmt_index
	assert hook_preview.lhs_index == preview.lhs_index
	assert hook_preview.target_c_name == preview.target_c_name
	assert hook_preview.cleanup_symbol == preview.cleanup_symbol
	assert hook_preview.cleanup_text == preview.cleanup_text
	assert hook_preview.reason.len > 0
}

fn test_autofree_statement_cleanup_hook_preview_accepts_distinct_same_slot_previews() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'first',
		'second',
	], [
		.decl_assign,
		.decl_assign,
	])
	first := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, 'first', 'first')
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          310
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
		stmt_index:           1
	}
	second := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, 'second',
			'second')
		target_node_id:       fixture.next_lhs_id
		target_pos_id:        220
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          310
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
		stmt_index:           1
	}
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(&fixture, [
		first,
		second,
	])
	assert hook_previews.len == 2
	assert hook_previews[0].cleanup_text == 'array__free(&first);'
	assert hook_previews[1].cleanup_text == 'array__free(&second);'
}

fn test_autofree_statement_cleanup_hook_preview_rejects_valid_plus_invalid_group() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'first',
		'second',
	], [
		.decl_assign,
		.decl_assign,
	])
	valid := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, 'second',
			'second')
		target_node_id:       fixture.next_lhs_id
		target_pos_id:        220
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          310
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
		stmt_index:           1
	}
	invalid := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		name:          'first'
		target_c_name: 'first'
		cleanup_text:  'array__free(&first);'
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [valid, invalid])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_mixed_function_group() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'first',
		'second',
	], [
		.decl_assign,
		.decl_assign,
	])
	valid := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, 'second',
			'second')
		target_node_id:       fixture.next_lhs_id
		target_pos_id:        220
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          310
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
		stmt_index:           1
	}
	mixed := AutofreeCleanCStatementCleanupPreviewFact{
		...valid
		name:           'second'
		fn_key:         'other_fn'
		fn_name:        'other_fn'
		target_node_id: fixture.next_lhs_id
		target_pos_id:  220
		target_c_name:  'second'
		cleanup_text:   'array__free(&second);'
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [valid, mixed])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_group_literal_final_assignment() {
	fixture :=
		autofree_statement_cleanup_hook_preview_test_flat_with_two_targets_and_literal_final()
	first := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, 'first', 'first')
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          410
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  410
		stmt_index:           2
	}
	second := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, 'second',
			'second')
		target_node_id:       fixture.next_lhs_id
		target_pos_id:        220
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          410
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  410
		stmt_index:           2
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [first, second])
}

fn test_autofree_statement_cleanup_hook_preview_accepts_last_statement_after_prefix() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_source_prefix_then_items()
	preview := autofree_statement_cleanup_hook_preview_test_next_items_preview(fixture)
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(&fixture, [
		preview,
	])
	assert hook_previews.len == 1
	hook_preview := hook_previews[0]
	assert hook_preview.name == 'items'
	assert hook_preview.name != 'copy'
	assert hook_preview.name != 'source'
	assert hook_preview.stmt_index == 1
	assert hook_preview.target_node_id == fixture.next_lhs_id
	assert hook_preview.target_pos_id == 220
	assert hook_preview.insert_after_node_id == fixture.next_stmt_id
	assert hook_preview.insert_after_pos_id == 310
	assert hook_preview.cleanup_symbol == 'array__free'
	assert hook_preview.cleanup_text == 'array__free(&items);'
	assert !hook_preview.cleanup_text.contains('copy')
	assert !hook_preview.cleanup_text.contains('source')
	assert !hook_preview.cleanup_text.contains('string__free')
}

fn test_autofree_statement_cleanup_hook_preview_accepts_later_final_assignment_after_target_decl() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_later_insert_assignment()
	preview := autofree_statement_cleanup_hook_preview_test_later_insert_preview(fixture)
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(&fixture, [
		preview,
	])
	assert hook_previews.len == 1
	hook_preview := hook_previews[0]
	assert hook_preview.fn_key == 'next_generation'
	assert hook_preview.fn_name == 'next_generation'
	assert hook_preview.name == 'arr'
	assert hook_preview.stmt_index == 2
	assert hook_preview.target_node_id == fixture.lhs_id
	assert hook_preview.target_pos_id == 120
	assert hook_preview.stmt_node_id == fixture.next_stmt_id
	assert hook_preview.stmt_pos_id == 410
	assert hook_preview.insert_after_node_id == fixture.next_stmt_id
	assert hook_preview.insert_after_pos_id == 410
	assert hook_preview.cleanup_symbol == 'array__free'
	assert hook_preview.cleanup_text == 'array__free(&arr);'
	assert !hook_preview.cleanup_text.contains('gen')
}

fn test_autofree_statement_cleanup_hook_preview_rejects_later_insert_without_target_decl() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_later_insert_assignment()
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_later_insert_preview(fixture)
		target_node_id: fixture.rhs_id
		target_pos_id:  130
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_accepts_mut_ident_lhs() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_modifier_assign(.key_mut,
		false)
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(&fixture, [
		preview,
	])
	assert hook_previews.len == 1
	assert hook_previews[0].target_node_id == preview.target_node_id
	assert hook_previews[0].target_pos_id == preview.target_pos_id
	assert hook_previews[0].cleanup_text == 'array__free(&items);'
}

fn test_autofree_statement_cleanup_hook_preview_accepts_c_keyword_name() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'@return',
	], [
		.decl_assign,
	])
	preview := autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, '@return',
		'_return')
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(&fixture, [
		preview,
	])
	assert hook_previews.len == 1
	assert hook_previews[0].target_c_name == '_return'
	assert hook_previews[0].cleanup_text == 'array__free(&_return);'
}

fn test_autofree_statement_cleanup_hook_preview_accepts_array_name() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'array',
	], [
		.decl_assign,
	])
	preview := autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, 'array',
		'_v_array')
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(&fixture, [
		preview,
	])
	assert hook_previews.len == 1
	assert hook_previews[0].target_c_name == '_v_array'
	assert hook_previews[0].cleanup_text == 'array__free(&_v_array);'
}

fn test_autofree_statement_cleanup_hook_preview_rejects_empty_preview_list() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture,
		[]AutofreeCleanCStatementCleanupPreviewFact{})
}

fn test_autofree_statement_cleanup_hook_preview_rejects_two_previews() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview, preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_status() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		cleanup_status: .unknown
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_kind() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		cleanup_kind: .unknown
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_symbol() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		cleanup_symbol: 'array__clear'
		cleanup_text:   'array__clear(&items);'
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_text() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		cleanup_text: 'array__free(items);'
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_empty_identity() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	for preview in [
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_key: ''
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_name: ''
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			name: ''
		},
	] {
		autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [
			preview,
		])
	}
}

fn test_autofree_statement_cleanup_hook_preview_rejects_invalid_ids() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	for preview in [
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_node_id: ast.FlatNodeId(-1)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_pos_id: 0
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			target_node_id: ast.FlatNodeId(-1)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			target_pos_id: 0
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			stmt_node_id: ast.FlatNodeId(-1)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			stmt_pos_id: 0
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			insert_after_node_id: ast.FlatNodeId(-1)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			insert_after_pos_id: 0
		},
	] {
		autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [
			preview,
		])
	}
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_file() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_two_files()
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		fn_pos_id:           300
		target_pos_id:       320
		stmt_pos_id:         410
		insert_after_pos_id: 410
		cleanup_text:        'array__free(&items);'
	}
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_cleanup_hook_preview_test_fn_cursor(&fixture)
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(file_cursor,
		fn_cursor, [preview])
	assert hook_previews.len == 0
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_function_identity() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	for preview in [
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_key: 'other'
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_name: 'other'
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_node_id: ast.FlatNodeId(999)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_pos_id: 999
		},
	] {
		autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [
			preview,
		])
	}
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_statement_identity() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	for preview in [
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			stmt_node_id: ast.FlatNodeId(999)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			stmt_pos_id: 999
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			insert_after_node_id: ast.FlatNodeId(999)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			insert_after_pos_id: 999
		},
	] {
		autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [
			preview,
		])
	}
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_statement_index() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		stmt_index: 1
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_non_last_statement() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
		'more_items',
	], [
		.decl_assign,
		.decl_assign,
	])
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_prefix_target() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_source_prefix_then_items()
	preview := autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, 'copy',
		c_local_name('copy'))
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_source_target() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_source_prefix_then_items()
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_next_items_preview(fixture)
		name:          'source'
		target_c_name: 'source'
		cleanup_text:  'array__free(&source);'
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_return_body() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_return()
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_nested_body() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_nested_assign()
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_non_mut_modifier_lhs() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_modifier_assign(.key_shared,
		false)
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_modifier_lhs_with_extra_child() {
	fixture :=
		autofree_statement_cleanup_hook_preview_test_flat_with_modifier_assign(.key_mut, true)
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_multi_lhs() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_multi_lhs()
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_nonzero_lhs_index() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		lhs_index: 1
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_target_mismatch() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	for preview in [
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			target_node_id: ast.FlatNodeId(999)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			target_pos_id: 999
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			name:          'other'
			target_c_name: 'other'
			cleanup_text:  'array__free(&other);'
		},
	] {
		autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [
			preview,
		])
	}
}

fn test_autofree_statement_cleanup_hook_preview_rejects_target_equal_insert() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		target_node_id: fixture.stmt_id
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

// autofree_statement_cleanup_emit_context_test

struct AutofreeStatementCleanupEmitContextTestHookPreviewFields {
mut:
	fn_key               string
	fn_name              string
	name                 string
	move_kind            types.AutofreeMoveProofKind
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
	block_path           string
	stmt_index           int
	lhs_index            int
	target_c_name        string
	cleanup_symbol       string
	cleanup_text         string
	reason               string
}

fn autofree_statement_cleanup_emit_context_test_hook_preview_fields() AutofreeStatementCleanupEmitContextTestHookPreviewFields {
	return AutofreeStatementCleanupEmitContextTestHookPreviewFields{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		move_kind:            .fresh_local_binding
		hook_status:          .inert
		hook_kind:            .after_body_before_scheduled_drops
		fn_node_id:           ast.FlatNodeId(10)
		fn_pos_id:            100
		target_node_id:       ast.FlatNodeId(20)
		target_pos_id:        120
		stmt_node_id:         ast.FlatNodeId(30)
		stmt_pos_id:          210
		insert_after_node_id: ast.FlatNodeId(30)
		insert_after_pos_id:  210
		block_path:           ''
		stmt_index:           0
		lhs_index:            0
		target_c_name:        'items'
		cleanup_symbol:       'array__free'
		cleanup_text:         'array__free(&items);'
		reason:               'statement cleanup hook preview accepted'
	}
}

fn autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields AutofreeStatementCleanupEmitContextTestHookPreviewFields) AutofreeCleanCStatementCleanupHookPreviewFact {
	return AutofreeCleanCStatementCleanupHookPreviewFact{
		fn_key:               fields.fn_key
		fn_name:              fields.fn_name
		name:                 fields.name
		move_kind:            fields.move_kind
		hook_status:          fields.hook_status
		hook_kind:            fields.hook_kind
		fn_node_id:           fields.fn_node_id
		fn_pos_id:            fields.fn_pos_id
		target_node_id:       fields.target_node_id
		target_pos_id:        fields.target_pos_id
		stmt_node_id:         fields.stmt_node_id
		stmt_pos_id:          fields.stmt_pos_id
		insert_after_node_id: fields.insert_after_node_id
		insert_after_pos_id:  fields.insert_after_pos_id
		block_path:           fields.block_path
		stmt_index:           fields.stmt_index
		lhs_index:            fields.lhs_index
		target_c_name:        fields.target_c_name
		cleanup_symbol:       fields.cleanup_symbol
		cleanup_text:         fields.cleanup_text
		reason:               fields.reason
	}
}

fn autofree_statement_cleanup_emit_context_test_hook_preview() AutofreeCleanCStatementCleanupHookPreviewFact {
	return autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(autofree_statement_cleanup_emit_context_test_hook_preview_fields())
}

fn autofree_statement_cleanup_emit_context_test_assert_no_context(previews []AutofreeCleanCStatementCleanupHookPreviewFact) {
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(previews)
	assert contexts.len == 0
}

fn test_autofree_statement_cleanup_emit_context_accepts_single_hook_preview() {
	preview := autofree_statement_cleanup_emit_context_test_hook_preview()
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews([
		preview,
	])
	assert contexts.len == 1
	context := contexts[0]
	assert context.fn_key == preview.fn_key
	assert context.fn_name == preview.fn_name
	assert context.name == preview.name
	assert context.context_status == .inert
	assert context.context_kind == .after_body_before_scheduled_drops
	assert context.fn_node_id == preview.fn_node_id
	assert context.fn_pos_id == preview.fn_pos_id
	assert context.target_node_id == preview.target_node_id
	assert context.target_pos_id == preview.target_pos_id
	assert context.stmt_node_id == preview.stmt_node_id
	assert context.stmt_pos_id == preview.stmt_pos_id
	assert context.insert_after_node_id == preview.insert_after_node_id
	assert context.insert_after_pos_id == preview.insert_after_pos_id
	assert context.stmt_index == preview.stmt_index
	assert context.lhs_index == preview.lhs_index
	assert context.target_c_name == preview.target_c_name
	assert context.cleanup_symbol == preview.cleanup_symbol
	assert context.cleanup_text == preview.cleanup_text
	assert context.context_key.len > 0
}

fn test_autofree_statement_cleanup_emit_context_accepts_last_statement_items_context() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.target_node_id = ast.FlatNodeId(40)
	fields.target_pos_id = 220
	fields.stmt_node_id = ast.FlatNodeId(50)
	fields.stmt_pos_id = 310
	fields.insert_after_node_id = ast.FlatNodeId(50)
	fields.insert_after_pos_id = 310
	fields.stmt_index = 1
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews([
		preview,
	])
	assert contexts.len == 1
	context := contexts[0]
	assert context.name == 'items'
	assert context.name != 'copy'
	assert context.name != 'source'
	assert context.target_c_name == 'items'
	assert context.stmt_index == 1
	assert context.target_node_id == ast.FlatNodeId(40)
	assert context.target_pos_id == 220
	assert context.insert_after_node_id == ast.FlatNodeId(50)
	assert context.insert_after_pos_id == 310
	assert context.cleanup_symbol == 'array__free'
	assert context.cleanup_text == 'array__free(&items);'
	assert context.context_key == 'make_items:10:100:0::40:220:50:310:items'
	assert !context.cleanup_text.contains('copy')
	assert !context.cleanup_text.contains('source')
	assert !context.cleanup_text.contains('string__free')
}

fn test_autofree_statement_cleanup_emit_context_key_is_stable() {
	preview := autofree_statement_cleanup_emit_context_test_hook_preview()
	first := autofree_statement_cleanup_emit_context_facts_from_hook_previews([
		preview,
	])
	second := autofree_statement_cleanup_emit_context_facts_from_hook_previews([
		preview,
	])
	assert first.len == 1
	assert second.len == 1
	assert first[0].context_key == second[0].context_key
	assert first[0].context_key.len > 0
}

fn test_autofree_statement_cleanup_emit_context_accepts_distinct_same_slot_previews_in_reverse_order() {
	mut first_fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	first_fields.name = 'first'
	first_fields.target_c_name = 'first'
	first_fields.cleanup_text = 'array__free(&first);'
	mut second_fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	second_fields.name = 'second'
	second_fields.target_node_id = ast.FlatNodeId(40)
	second_fields.target_pos_id = 220
	second_fields.target_c_name = 'second'
	second_fields.cleanup_text = 'array__free(&second);'
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews([
		autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(first_fields),
		autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(second_fields),
	])
	assert contexts.len == 2
	assert contexts[0].name == 'second'
	assert contexts[0].cleanup_text == 'array__free(&second);'
	assert contexts[1].name == 'first'
	assert contexts[1].cleanup_text == 'array__free(&first);'
}

fn test_autofree_statement_cleanup_emit_context_rejects_valid_plus_invalid_group() {
	valid := autofree_statement_cleanup_emit_context_test_hook_preview()
	mut invalid_fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	invalid_fields.name = 'second'
	invalid_fields.target_node_id = ast.FlatNodeId(40)
	invalid_fields.target_pos_id = 220
	invalid_fields.target_c_name = 'second'
	invalid_fields.cleanup_text = 'array__free(&second);'
	invalid_fields.hook_status = .unknown
	invalid := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(invalid_fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([valid, invalid])
}

fn test_autofree_statement_cleanup_emit_context_rejects_mixed_function_group() {
	valid := autofree_statement_cleanup_emit_context_test_hook_preview()
	mut mixed_fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	mixed_fields.fn_key = 'other_fn'
	mixed_fields.fn_name = 'other_fn'
	mixed_fields.name = 'second'
	mixed_fields.target_node_id = ast.FlatNodeId(40)
	mixed_fields.target_pos_id = 220
	mixed_fields.target_c_name = 'second'
	mixed_fields.cleanup_text = 'array__free(&second);'
	mixed := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(mixed_fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([valid, mixed])
}

fn test_autofree_statement_cleanup_emit_context_rejects_mixed_slot_group() {
	valid := autofree_statement_cleanup_emit_context_test_hook_preview()
	mut mixed_fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	mixed_fields.name = 'second'
	mixed_fields.target_node_id = ast.FlatNodeId(40)
	mixed_fields.target_pos_id = 220
	mixed_fields.stmt_node_id = ast.FlatNodeId(50)
	mixed_fields.stmt_pos_id = 310
	mixed_fields.insert_after_node_id = ast.FlatNodeId(50)
	mixed_fields.insert_after_pos_id = 310
	mixed_fields.target_c_name = 'second'
	mixed_fields.cleanup_text = 'array__free(&second);'
	mixed := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(mixed_fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([valid, mixed])
}

fn test_autofree_statement_cleanup_emit_context_rejects_duplicate_cleanup_text_group() {
	mut first_fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	first_fields.name = '@return'
	first_fields.target_c_name = '_return'
	first_fields.cleanup_text = 'array__free(&_return);'
	mut second_fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	second_fields.name = '_return'
	second_fields.target_node_id = ast.FlatNodeId(40)
	second_fields.target_pos_id = 220
	second_fields.target_c_name = '_return'
	second_fields.cleanup_text = 'array__free(&_return);'
	autofree_statement_cleanup_emit_context_test_assert_no_context([
		autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(first_fields),
		autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(second_fields),
	])
}

fn test_autofree_statement_cleanup_emit_context_rejects_empty_input() {
	autofree_statement_cleanup_emit_context_test_assert_no_context([])
}

fn test_autofree_statement_cleanup_emit_context_rejects_two_previews() {
	preview := autofree_statement_cleanup_emit_context_test_hook_preview()
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview, preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_unknown_status() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.hook_status = .unknown
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_unknown_kind() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.hook_kind = .unknown
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_bad_symbol() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.cleanup_symbol = 'string__free'
	fields.cleanup_text = 'string__free(&items);'
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_bad_text() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.cleanup_text = 'array__free(items);'
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_empty_fn_key() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.fn_key = ''
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_empty_fn_name() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.fn_name = ''
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_empty_name() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.name = ''
	fields.target_c_name = ''
	fields.cleanup_text = 'array__free(&);'
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_bad_target_name() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.name = 'array'
	fields.target_c_name = 'array'
	fields.cleanup_text = 'array__free(&array);'
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_fn_ids() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.fn_node_id = ast.FlatNodeId(-1)
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_fn_pos() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.fn_pos_id = 0
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_target_ids() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.target_node_id = ast.FlatNodeId(-1)
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_target_pos() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.target_pos_id = 0
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_stmt_ids() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.stmt_node_id = ast.FlatNodeId(-1)
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_stmt_pos() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.stmt_pos_id = 0
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_insert_ids() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.insert_after_node_id = ast.FlatNodeId(-1)
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_insert_pos() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.insert_after_pos_id = 0
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_stmt_node_mismatch() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.stmt_node_id = ast.FlatNodeId(31)
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_stmt_pos_mismatch() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.stmt_pos_id = 211
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_target_equal_insert() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.target_node_id = fields.insert_after_node_id
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_negative_stmt_index() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.stmt_index = -1
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_nonzero_lhs_index() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.lhs_index = 1
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

// autofree_statement_cleanup_emit_test

struct AutofreeStatementCleanupEmitTestContextFields {
mut:
	fn_key               string
	fn_name              string
	name                 string
	move_kind            types.AutofreeMoveProofKind
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
	block_path           string
	stmt_index           int
	lhs_index            int
	target_c_name        string
	cleanup_symbol       string
	cleanup_text         string
	context_key          string
	reason               string
}

fn autofree_statement_cleanup_emit_test_context_fields() AutofreeStatementCleanupEmitTestContextFields {
	return AutofreeStatementCleanupEmitTestContextFields{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		move_kind:            .fresh_local_binding
		context_status:       .inert
		context_kind:         .after_body_before_scheduled_drops
		fn_node_id:           ast.FlatNodeId(10)
		fn_pos_id:            100
		target_node_id:       ast.FlatNodeId(20)
		target_pos_id:        120
		stmt_node_id:         ast.FlatNodeId(30)
		stmt_pos_id:          210
		insert_after_node_id: ast.FlatNodeId(30)
		insert_after_pos_id:  210
		block_path:           ''
		stmt_index:           0
		lhs_index:            0
		target_c_name:        'items'
		cleanup_symbol:       'array__free'
		cleanup_text:         'array__free(&items);'
		context_key:          'make_items:10:100:0::20:120:30:210:items'
		reason:               'statement cleanup emit context accepted'
	}
}

fn autofree_statement_cleanup_emit_test_context_from_fields(fields AutofreeStatementCleanupEmitTestContextFields) AutofreeCleanCStatementCleanupEmitContextFact {
	return AutofreeCleanCStatementCleanupEmitContextFact{
		fn_key:               fields.fn_key
		fn_name:              fields.fn_name
		name:                 fields.name
		move_kind:            fields.move_kind
		context_status:       fields.context_status
		context_kind:         fields.context_kind
		fn_node_id:           fields.fn_node_id
		fn_pos_id:            fields.fn_pos_id
		target_node_id:       fields.target_node_id
		target_pos_id:        fields.target_pos_id
		stmt_node_id:         fields.stmt_node_id
		stmt_pos_id:          fields.stmt_pos_id
		insert_after_node_id: fields.insert_after_node_id
		insert_after_pos_id:  fields.insert_after_pos_id
		block_path:           fields.block_path
		stmt_index:           fields.stmt_index
		lhs_index:            fields.lhs_index
		target_c_name:        fields.target_c_name
		cleanup_symbol:       fields.cleanup_symbol
		cleanup_text:         fields.cleanup_text
		context_key:          fields.context_key
		reason:               fields.reason
	}
}

fn autofree_statement_cleanup_emit_test_context() AutofreeCleanCStatementCleanupEmitContextFact {
	return autofree_statement_cleanup_emit_test_context_from_fields(autofree_statement_cleanup_emit_test_context_fields())
}

fn autofree_statement_cleanup_emit_test_fn_decl() ast.FnDecl {
	return ast.FnDecl{
		name: 'make_items'
		pos:  token.Pos{
			id: 100
		}
	}
}

fn autofree_statement_cleanup_emit_test_gen(autofree bool) Gen {
	prefs := &vpref.Preferences{
		autofree: autofree
	}
	return Gen{
		pref: prefs
		sb:   strings.new_builder(64)
	}
}

fn autofree_statement_cleanup_emit_test_freestanding_gen(hooks []string) Gen {
	prefs := &vpref.Preferences{
		autofree:           true
		freestanding:       true
		freestanding_hooks: hooks
	}
	return Gen{
		pref: prefs
		sb:   strings.new_builder(64)
	}
}

fn autofree_statement_cleanup_emit_test_cross_gen() Gen {
	prefs := &vpref.Preferences{
		autofree:       true
		target_os:      'cross'
		output_cross_c: true
	}
	return Gen{
		pref: prefs
		sb:   strings.new_builder(64)
	}
}

fn autofree_statement_cleanup_emit_test_install_context(mut g Gen, context AutofreeCleanCStatementCleanupEmitContextFact,
	prepared bool) {
	g.autofree_cleanup_emit_contexts = [context]
	g.has_autofree_cleanup_emit_context = true
	g.autofree_cleanup_emit_context_consumed = false
	g.autofree_cleanup_emit_context_prepared = prepared
	if prepared {
		g.autofree_cleanup_emit_fn_key = context.fn_key
		g.autofree_cleanup_emit_fn_node_id = context.fn_node_id
		g.autofree_cleanup_emit_fn_pos_id = context.fn_pos_id
	}
}

fn autofree_statement_cleanup_emit_test_install_contexts(mut g Gen, contexts []AutofreeCleanCStatementCleanupEmitContextFact,
	prepared bool) {
	g.autofree_cleanup_emit_contexts = contexts
	g.has_autofree_cleanup_emit_context = contexts.len > 0
	g.autofree_cleanup_emit_context_consumed = false
	g.autofree_cleanup_emit_context_prepared = prepared
	if prepared && contexts.len > 0 {
		g.autofree_cleanup_emit_fn_key = contexts[0].fn_key
		g.autofree_cleanup_emit_fn_node_id = contexts[0].fn_node_id
		g.autofree_cleanup_emit_fn_pos_id = contexts[0].fn_pos_id
	}
}

fn test_autofree_statement_cleanup_emit_writes_valid_context_once() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == 'array__free(&items);\n'
	assert g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_writes_context_list_in_reverse_order_once() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut first_fields := autofree_statement_cleanup_emit_test_context_fields()
	first_fields.name = 'first'
	first_fields.target_c_name = 'first'
	first_fields.cleanup_text = 'array__free(&first);'
	first_fields.context_key = 'make_items:10:100:0::20:120:30:210:first'
	mut second_fields := autofree_statement_cleanup_emit_test_context_fields()
	second_fields.name = 'second'
	second_fields.target_node_id = ast.FlatNodeId(40)
	second_fields.target_pos_id = 220
	second_fields.target_c_name = 'second'
	second_fields.cleanup_text = 'array__free(&second);'
	second_fields.context_key = 'make_items:10:100:0::40:220:30:210:second'
	contexts := autofree_statement_cleanup_emit_contexts_reverse_lexical([
		autofree_statement_cleanup_emit_test_context_from_fields(first_fields),
		autofree_statement_cleanup_emit_test_context_from_fields(second_fields),
	])
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_contexts(mut g, contexts, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == 'array__free(&second);\narray__free(&first);\n'
	assert g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_rejects_invalid_context_group_without_singleton_emit() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	first := autofree_statement_cleanup_emit_test_context()
	mut second_fields := autofree_statement_cleanup_emit_test_context_fields()
	second_fields.name = 'second'
	second_fields.target_node_id = ast.FlatNodeId(40)
	second_fields.target_pos_id = 220
	second_fields.stmt_node_id = ast.FlatNodeId(50)
	second_fields.stmt_pos_id = 310
	second_fields.insert_after_node_id = ast.FlatNodeId(50)
	second_fields.insert_after_pos_id = 310
	second_fields.target_c_name = 'second'
	second_fields.cleanup_text = 'array__free(&second);'
	second_fields.context_key = 'make_items:10:100:0::40:220:50:310:second'
	second := autofree_statement_cleanup_emit_test_context_from_fields(second_fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_contexts(mut g, [first, second], true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_writes_last_statement_items_context_once() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.target_node_id = ast.FlatNodeId(40)
	fields.target_pos_id = 220
	fields.stmt_node_id = ast.FlatNodeId(50)
	fields.stmt_pos_id = 310
	fields.insert_after_node_id = ast.FlatNodeId(50)
	fields.insert_after_pos_id = 310
	fields.stmt_index = 1
	fields.context_key = 'make_items:10:100:0::40:220:50:310:items'
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	output := g.sb.str()
	assert output == 'array__free(&items);\n'
	assert !output.contains('copy')
	assert !output.contains('source')
	assert !output.contains('string__free')
	assert g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_disabled_context() {
	mut g := autofree_statement_cleanup_emit_test_gen(false)
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_keeps_cross_context() {
	mut g := autofree_statement_cleanup_emit_test_cross_gen()
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == 'array__free(&items);\n'
	assert g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_freestanding_context() {
	mut g := autofree_statement_cleanup_emit_test_freestanding_gen([]string{})
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_freestanding_alloc_hook_context() {
	mut g := autofree_statement_cleanup_emit_test_freestanding_gen(['alloc'])
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_missing_context() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_skips_consumed_context() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_cleanup_emit_context_consumed = true
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_skips_bad_status() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.context_status = .unknown
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_skips_bad_kind() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.context_kind = .unknown
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_skips_bad_symbol() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.cleanup_symbol = 'string__free'
	fields.cleanup_text = 'string__free(&items);'
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_skips_bad_text() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.cleanup_text = 'array__free(items);'
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_skips_bad_ids() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.target_node_id = ast.FlatNodeId(-1)
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_skips_fn_mismatch() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('other_fn', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_wrong_fn_does_not_consume_context() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('other_fn', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == 'array__free(&items);\n'
	assert g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_unprepared_context() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, false)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_wrong_prepared_fn_node_id() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.fn_node_id = ast.FlatNodeId(11)
	fields.context_key = 'make_items:11:100:0::20:120:30:210:items'
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_cleanup_emit_fn_node_id = ast.FlatNodeId(10)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_wrong_prepared_fn_key() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_cleanup_emit_fn_key = 'other_key'
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_clean_c_name_mismatch() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.fn_key = 'main__make_items'
	fields.context_key = 'main__make_items:10:100:0::20:120:30:210:items'
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_clear_resets_cursor_state() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	context := autofree_statement_cleanup_emit_test_context()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_cleanup_emit_context_consumed = true
	g.autofree_clear_statement_cleanup_emit_context()
	assert !g.has_autofree_cleanup_emit_context
	assert g.autofree_cleanup_emit_contexts.len == 0
	assert !g.autofree_cleanup_emit_context_consumed
	assert !g.autofree_cleanup_emit_context_prepared
	assert g.autofree_cleanup_emit_fn_key == ''
	assert g.autofree_cleanup_emit_fn_node_id == ast.invalid_flat_node_id
	assert g.autofree_cleanup_emit_fn_pos_id == 0
}

struct AutofreeStatementCleanupEmitPipelineFixture {
mut:
	flat  ast.FlatAst
	env   &types.Environment = unsafe { nil }
	prefs &vpref.Preferences = unsafe { nil }
}

struct AutofreeEprintlnStringInterpolationGenResult {
	c_source        string
	called_fn_names map[string]bool
}

struct AutofreeStatementCleanupEmitPipelineCursor {
	file_cursor ast.FileCursor
	fn_cursor   ast.Cursor
}

fn autofree_statement_cleanup_emit_test_rule110_style_source() string {
	return 'module main

fn next_generation(mut gen []int) {
	mut arr := gen.clone()
	for i in 0 .. gen.len {
		arr[i] = gen[i]
	}
	gen = arr.clone()
}
'
}

fn autofree_statement_cleanup_emit_test_fresh_local_final_clone_source() string {
	return 'module main

fn fill_array_from_fresh_local(mut dst []int) {
	mut arr := []int{}
	dst = arr.clone()
}
'
}

fn autofree_statement_cleanup_emit_test_prefixed_fresh_local_final_clone_source() string {
	return 'module main

fn fill_array_from_prefixed_fresh_local(mut dst []int) {
	seed := 1
	mut arr := []int{}
	dst = arr.clone()
}
'
}

fn autofree_statement_cleanup_emit_test_cap_only_natural_release_source() string {
	return 'module main

fn build_array_with_cap(n int) {
	mut items := []int{cap: n}
}
'
}

fn autofree_statement_cleanup_emit_test_len_only_natural_release_source() string {
	return 'module main

fn build_array_with_len(n int) {
	mut items := []int{len: n}
}
'
}

fn autofree_statement_cleanup_emit_test_single_final_len_source() string {
	return 'module main

fn build_empty_array_final_len() {
	mut items := []int{}
	sink := items.len
}

fn build_cap_array_final_len(n int) {
	mut items := []int{cap: n}
	sink := items.len
}

fn build_len_array_final_len(n int) {
	mut items := []int{len: n}
	sink := items.len
}
'
}

fn autofree_statement_cleanup_emit_test_local_array_push_literal_sink_source() string {
	return 'module main

fn build_local_array_push_literal_return() int {
	mut items := []int{}
	items << 1
	items << 2
	n := items.len
	return n
}
'
}

fn autofree_statement_cleanup_emit_test_two_array_natural_release_source() string {
	return 'module main

fn build_two_empty_arrays() {
	mut first := []int{}
	mut second := []int{}
	sink := first.len + second.len
}

fn build_two_cap_arrays(n int) {
	mut first := []int{cap: n}
	mut second := []int{cap: n}
	sink := first.len + second.len + n
}

fn build_two_len_arrays(n int) {
	mut first := []int{len: n}
	mut second := []int{len: n}
	sink := first.len + second.len + n
}
'
}

fn autofree_statement_cleanup_emit_test_mixed_two_array_source() string {
	return 'module main

fn build_mixed_empty_cap_arrays(n int) {
	mut first := []int{}
	mut second := []int{cap: n}
	sink := first.len + second.len + n
}

fn build_mixed_cap_empty_arrays(n int) {
	mut first := []int{cap: n}
	mut second := []int{}
	sink := first.len + second.len + n
}

fn build_mixed_empty_len_arrays(n int) {
	mut first := []int{}
	mut second := []int{len: n}
	sink := first.len + second.len + n
}

fn build_mixed_len_empty_arrays(n int) {
	mut first := []int{len: n}
	mut second := []int{}
	sink := first.len + second.len + n
}

fn build_mixed_cap_len_arrays(n int) {
	mut first := []int{cap: n}
	mut second := []int{len: n}
	sink := first.len + second.len + n
}

fn build_mixed_len_cap_arrays(n int) {
	mut first := []int{len: n}
	mut second := []int{cap: n}
	sink := first.len + second.len + n
}
'
}

fn autofree_statement_cleanup_emit_test_two_array_literal_final_source() string {
	return 'module main

fn build_two_empty_arrays() {
	mut first := []int{}
	mut second := []int{}
	sink := 1
}
'
}

fn autofree_statement_cleanup_emit_test_len_only_final_clone_source() string {
	return 'module main

fn fill_array_from_len_only(n int, mut dst []int) {
	mut arr := []int{len: n}
	dst = arr.clone()
}
'
}

fn autofree_statement_cleanup_emit_test_cap_only_final_clone_source() string {
	return 'module main

fn fill_array_from_cap_only(n int, mut dst []int) {
	mut arr := []int{cap: n}
	dst = arr.clone()
}
'
}

fn autofree_statement_cleanup_emit_test_multi_param_fresh_local_final_clone_source() string {
	return 'module main

fn fill_array_from_fresh_local_with_extra(x int, mut dst []int) {
	mut arr := []int{}
	dst = arr.clone()
}
'
}

fn autofree_statement_cleanup_emit_test_receiver_field_slice_clone_source() string {
	return 'module main

struct Game {
	items []int
}

fn (g &Game) fill_array_from_field_slice(idx int, n int, mut dst []int) {
	next := g.items[idx..idx + n].clone()
	dst = next.clone()
}

fn main() {
	g := Game{
		items: [1, 2, 3, 4]
	}
	mut dst := []int{}
	g.fill_array_from_field_slice(0, 2, mut dst)
}
'
}

fn autofree_statement_cleanup_emit_test_receiver_field_slice_clone_nested_then_source() string {
	return 'module main

struct Game {
	items []int
}

fn (g &Game) fill_array_from_field_slice_then_loop(idx int, n int, mut dst []int) {
	if idx >= 0 {
		next := g.items[idx..idx + n].clone()
		for i := 0; i < n; i++ {
			value := next[i]
			dst << value
		}
	}
}

fn main() {
	g := Game{
		items: [1, 2, 3, 4]
	}
	mut dst := []int{}
	g.fill_array_from_field_slice_then_loop(0, 2, mut dst)
}
'
}

fn autofree_statement_cleanup_emit_test_loop_local_clone_push_source() string {
	return 'module main

struct Board {
mut:
	rows [][]int
}

fn (mut b Board) fill_rows(height int, width int) {
	start := 0
	limit := height + start
	right := width - 1
	adjusted_width := width + start
	for _ in 0 .. limit {
		mut row := []int{len: adjusted_width}
		row[0] = -1
		row[right] = -1
		b.rows << row.clone()
	}
}

fn main() {
	mut b := Board{}
	b.fill_rows(2, 4)
}
'
}

fn autofree_statement_cleanup_emit_test_fresh_local_string_clone_push_source() string {
	return 'module main

fn push_joined(left string, right string, mut items []string) int {
	text := left + right
	items << text
	return items.len
}

fn main() {
	mut items := []string{}
	_ := push_joined("a", "b", mut items)
}
'
}

fn autofree_statement_cleanup_emit_test_pipeline_fixture(name string, source string) AutofreeStatementCleanupEmitPipelineFixture {
	tmp_file := os.join_path(os.vtmp_dir(), 'v2_cleanc_autofree_${name}_${os.getpid()}.v')
	os.write_file(tmp_file, source) or { panic('failed to write temp file') }
	defer {
		os.rm(tmp_file) or {}
	}
	prefs := &vpref.Preferences{
		backend:               .cleanc
		autofree:              true
		no_parallel:           true
		no_parallel_transform: true
	}
	mut file_set := token.FileSet.new()
	mut par := parser.Parser.new(prefs)
	files := par.parse_files([tmp_file], mut file_set)
	mut env := types.Environment.new()
	mut checker := types.Checker.new(prefs, file_set, env)
	checker.check_files(files)
	flat := ast.flatten_files(files)
	mut trans := transformer.Transformer.new_with_pref(env, prefs)
	trans.set_file_set(file_set)
	transformed_flat := trans.transform_flat_to_flat_direct(&flat, []ast.File{})
	env.collect_autofree_facts_from_flat(&transformed_flat)
	return AutofreeStatementCleanupEmitPipelineFixture{
		flat:  transformed_flat
		env:   env
		prefs: prefs
	}
}

fn autofree_eprintln_string_interpolation_expr() string {
	dollar := '$'
	return '"AI ${dollar}{n}"'
}

fn autofree_eprintln_string_interpolation_source(body string) string {
	return 'module main

struct Gg {
}

fn println(text string) {
	_ := text
}

fn (g Gg) draw_text(text string) {
	_ := text
}

fn some_fn(text string) {
	_ := text
}

fn print_value(n int) string {
	${body}
}

fn main() {
	_ := print_value(7)
}
'
}

fn autofree_builtin_eprintln_string_interpolation_source(body string) string {
	return 'module builtin

fn eprintln(text string) {
	_ := text
}

fn print_value(n int) string {
	${body}
}
'
}

fn autofree_eprintln_string_interpolation_generated_result(name string, source string, autofree bool, freestanding bool, target_os string) AutofreeEprintlnStringInterpolationGenResult {
	tmp_file := os.join_path(os.vtmp_dir(), 'v2_cleanc_autofree_${name}_${os.getpid()}.v')
	os.write_file(tmp_file, source) or { panic('failed to write temp file') }
	defer {
		os.rm(tmp_file) or {}
	}
	prefs := &vpref.Preferences{
		backend:               .cleanc
		autofree:              autofree
		freestanding:          freestanding
		target_os:             target_os
		no_parallel:           true
		no_parallel_transform: true
	}
	mut file_set := token.FileSet.new()
	mut par := parser.Parser.new(prefs)
	files := par.parse_files([tmp_file], mut file_set)
	mut env := types.Environment.new()
	mut checker := types.Checker.new(prefs, file_set, env)
	checker.check_files(files)
	flat := ast.flatten_files(files)
	mut trans := transformer.Transformer.new_with_pref(env, prefs)
	trans.set_file_set(file_set)
	transformed_flat := trans.transform_flat_to_flat_direct(&flat, []ast.File{})
	if prefs.autofree {
		env.collect_autofree_facts_from_flat(&transformed_flat)
	}
	mut gen := Gen.new_with_env_pref_and_flat(&transformed_flat, env, prefs)
	c_source := gen.gen()
	return AutofreeEprintlnStringInterpolationGenResult{
		c_source:        c_source
		called_fn_names: gen.called_fn_names.clone()
	}
}

fn autofree_eprintln_string_interpolation_generated_c(name string, source string, autofree bool, freestanding bool, target_os string) string {
	return autofree_eprintln_string_interpolation_generated_result(name, source, autofree,
		freestanding, target_os).c_source
}

fn autofree_eprintln_string_interpolation_generated_c_from_files(name string, sources map[string]string) string {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v2_cleanc_autofree_${name}_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic('failed to create temp dir') }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	mut paths := []string{cap: sources.len}
	for rel_path, source in sources {
		path := os.join_path(tmp_dir, rel_path)
		parent := os.dir(path)
		os.mkdir_all(parent) or { panic('failed to create temp source dir') }
		os.write_file(path, source) or { panic('failed to write temp source file') }
		paths << path
	}
	paths.sort()
	prefs := &vpref.Preferences{
		backend:               .cleanc
		autofree:              true
		target_os:             'linux'
		no_parallel:           true
		no_parallel_transform: true
	}
	mut file_set := token.FileSet.new()
	mut par := parser.Parser.new(prefs)
	files := par.parse_files(paths, mut file_set)
	mut env := types.Environment.new()
	mut checker := types.Checker.new(prefs, file_set, env)
	checker.check_files(files)
	flat := ast.flatten_files(files)
	mut trans := transformer.Transformer.new_with_pref(env, prefs)
	trans.set_file_set(file_set)
	transformed_flat := trans.transform_flat_to_flat_direct(&flat, []ast.File{})
	env.collect_autofree_facts_from_flat(&transformed_flat)
	mut gen := Gen.new_with_env_pref_and_flat(&transformed_flat, env, prefs)
	return gen.gen()
}

fn autofree_assert_eprintln_string_interpolation_cleanup_present(c_source string) {
	decl_idx := c_source.index('string _eprintln_inter_tmp_') or {
		assert false, c_source
		return
	}
	call_idx := c_source.index_after('eprintln(_eprintln_inter_tmp_', decl_idx) or {
		assert false, c_source
		return
	}
	free_idx := c_source.index_after('string__free(&_eprintln_inter_tmp_', call_idx) or {
		assert false, c_source
		return
	}
	assert decl_idx < call_idx, c_source
	assert call_idx < free_idx, c_source
	assert c_source.count('string _eprintln_inter_tmp_') == 1, c_source
	assert c_source.count('eprintln(_eprintln_inter_tmp_') == 1, c_source
	assert c_source.count('string__free(&_eprintln_inter_tmp_') == 1, c_source
	assert !c_source.contains('array__free(&_eprintln_inter_tmp_'), c_source
}

fn autofree_assert_no_eprintln_string_interpolation_cleanup(c_source string) {
	assert !c_source.contains('string _eprintln_inter_tmp_'), c_source
	assert !c_source.contains('eprintln(_eprintln_inter_tmp_'), c_source
	assert !c_source.contains('string__free(&_eprintln_inter_tmp_'), c_source
}

fn test_autofree_eprintln_string_interpolation_codegen_materializes_and_frees_temp() {
	expr := autofree_eprintln_string_interpolation_expr()
	source := autofree_builtin_eprintln_string_interpolation_source('eprintln(${expr})
	return "ok"')
	result := autofree_eprintln_string_interpolation_generated_result('eprintln_interpolation_positive',
		source, true, false, 'linux')
	autofree_assert_eprintln_string_interpolation_cleanup_present(result.c_source)
	assert 'eprintln' in result.called_fn_names
}

fn test_autofree_eprintln_string_interpolation_codegen_respects_target_modes() {
	expr := autofree_eprintln_string_interpolation_expr()
	source := autofree_builtin_eprintln_string_interpolation_source('eprintln(${expr})
	return "ok"')
	disabled := autofree_eprintln_string_interpolation_generated_c('eprintln_interpolation_disabled',
		source, false, false, 'linux')
	freestanding := autofree_eprintln_string_interpolation_generated_c('eprintln_interpolation_freestanding',
		source, true, true, 'linux')
	none_target := autofree_eprintln_string_interpolation_generated_c('eprintln_interpolation_none',
		source, true, true, 'none')
	autofree_assert_no_eprintln_string_interpolation_cleanup(disabled)
	autofree_assert_no_eprintln_string_interpolation_cleanup(freestanding)
	autofree_assert_no_eprintln_string_interpolation_cleanup(none_target)
}

fn test_autofree_eprintln_string_interpolation_codegen_rejects_other_call_and_value_shapes() {
	expr := autofree_eprintln_string_interpolation_expr()
	cases := {
		'println':       'println(${expr})
	return "ok"'
		'function_call': 'some_fn(${expr})
	return "ok"'
		'method_call':   'g := Gg{}
	g.draw_text(${expr})
	return "ok"'
		'assignment':    'x := ${expr}
	return x'
		'return_value':  'return ${expr}'
	}
	for name, body in cases {
		source := autofree_eprintln_string_interpolation_source(body)
		c_source := autofree_eprintln_string_interpolation_generated_c('eprintln_interpolation_reject_${name}',
			source, true, false, 'linux')
		autofree_assert_no_eprintln_string_interpolation_cleanup(c_source)
	}
}

fn test_autofree_eprintln_string_interpolation_codegen_rejects_non_exact_eprintln_shapes() {
	expr := autofree_eprintln_string_interpolation_expr()
	cases := {
		'existing_local':     'text := "AI"
	eprintln(text)
	return "ok"'
		'literal':            'eprintln("AI")
	return "ok"'
		'parenthesized_arg':  'eprintln((${expr}))
	return "ok"'
		'parenthesized_call': '(eprintln(${expr}))
	return "ok"'
	}
	for name, body in cases {
		source := autofree_builtin_eprintln_string_interpolation_source(body)
		c_source := autofree_eprintln_string_interpolation_generated_c('eprintln_interpolation_reject_${name}',
			source, true, false, 'linux')
		autofree_assert_no_eprintln_string_interpolation_cleanup(c_source)
	}
}

fn test_autofree_eprintln_string_interpolation_codegen_rejects_shadowed_eprintln() {
	expr := autofree_eprintln_string_interpolation_expr()
	source := 'module main

fn eprintln(text string) {
	_ := text
}

fn main() {
	n := 7
	eprintln(${expr})
}
'
	c_source := autofree_eprintln_string_interpolation_generated_c('eprintln_interpolation_shadowed',
		source, true, false, 'linux')
	autofree_assert_no_eprintln_string_interpolation_cleanup(c_source)
}

fn test_autofree_eprintln_string_interpolation_codegen_rejects_local_callable_shadow() {
	expr := autofree_eprintln_string_interpolation_expr()
	source := autofree_eprintln_string_interpolation_source('eprintln := fn (text string) {
	_ := text
}
	eprintln(${expr})
	return "ok"')
	c_source := autofree_eprintln_string_interpolation_generated_c('eprintln_interpolation_local_shadow',
		source, true, false, 'linux')
	autofree_assert_no_eprintln_string_interpolation_cleanup(c_source)
}

fn test_autofree_eprintln_string_interpolation_codegen_rejects_selective_import_shadow() {
	expr := autofree_eprintln_string_interpolation_expr()
	c_source := autofree_eprintln_string_interpolation_generated_c_from_files('eprintln_interpolation_selective_import_shadow', {
		'mymod/mymod.v': 'module mymod

pub fn eprintln(text string) {
	_ := text
}
'
		'main.v':        'module main

import mymod { eprintln }

fn print_value(n int) string {
	eprintln(${expr})
	return "ok"
}
'
	})
	autofree_assert_no_eprintln_string_interpolation_cleanup(c_source)
}

fn autofree_statement_cleanup_emit_test_rule110_style_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('rule110_style',
		autofree_statement_cleanup_emit_test_rule110_style_source())
}

fn autofree_statement_cleanup_emit_test_fresh_local_final_clone_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('fresh_local_final_clone',
		autofree_statement_cleanup_emit_test_fresh_local_final_clone_source())
}

fn autofree_statement_cleanup_emit_test_prefixed_fresh_local_final_clone_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('prefixed_fresh_local_final_clone',
		autofree_statement_cleanup_emit_test_prefixed_fresh_local_final_clone_source())
}

fn autofree_statement_cleanup_emit_test_cap_only_natural_release_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('cap_only_natural_release',
		autofree_statement_cleanup_emit_test_cap_only_natural_release_source())
}

fn autofree_statement_cleanup_emit_test_len_only_natural_release_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('len_only_natural_release',
		autofree_statement_cleanup_emit_test_len_only_natural_release_source())
}

fn autofree_statement_cleanup_emit_test_single_final_len_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('single_final_len',
		autofree_statement_cleanup_emit_test_single_final_len_source())
}

fn autofree_statement_cleanup_emit_test_local_array_push_literal_sink_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('local_array_push_literal_return',
		autofree_statement_cleanup_emit_test_local_array_push_literal_sink_source())
}

struct AutofreeStatementSingletonFinalLenMatcherFixture {
	flat    ast.FlatAst
	stmt_id ast.FlatNodeId
	anchor  AutofreeCleanCStatementAnchorFact
}

fn autofree_statement_singleton_final_len_matcher_fixture(rhs_kind string, final_lhs_name string, op token.Token) AutofreeStatementSingletonFinalLenMatcherFixture {
	mut b := ast.new_flat_builder()
	target_lhs_id := b.emit_ident_by_name('items',
		autofree_statement_cleanup_hook_preview_test_pos(120))
	target_rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 130)
	target_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [target_lhs_id], [
		target_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(210))
	final_lhs_id := b.emit_ident_by_name(final_lhs_name,
		autofree_statement_cleanup_hook_preview_test_pos(220))
	final_rhs_id := autofree_statement_singleton_final_len_matcher_rhs(mut b, rhs_kind)
	final_stmt_id := b.emit_assign_stmt_by_ids(op, [final_lhs_id], [final_rhs_id],
		autofree_statement_cleanup_hook_preview_test_pos(310))
	body_id := b.emit_aux_list_from_ids([target_stmt_id, final_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('build_array_final_len', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_singleton_final_len_matcher_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementSingletonFinalLenMatcherFixture{
		flat:    b.take_flat()
		stmt_id: final_stmt_id
		anchor:  AutofreeCleanCStatementAnchorFact{
			fn_key:               'build_array_final_len'
			fn_name:              'build_array_final_len'
			name:                 'items'
			anchor_status:        .inert
			target_node_id:       target_lhs_id
			target_pos_id:        120
			insert_after_node_id: final_stmt_id
			insert_after_pos_id:  310
			reason:               'singleton final len matcher test'
		}
	}
}

fn autofree_statement_singleton_final_len_matcher_rhs(mut b ast.FlatBuilder, rhs_kind string) ast.FlatNodeId {
	items_id := b.emit_ident_by_name('items', autofree_statement_cleanup_hook_preview_test_pos(320))
	len_id := b.emit_ident_by_name('len', autofree_statement_cleanup_hook_preview_test_pos(321))
	match rhs_kind {
		'len_selector' {
			return b.emit_selector_expr_by_ids(items_id, len_id,
				autofree_statement_cleanup_hook_preview_test_pos(330))
		}
		'cap_selector' {
			cap_id := b.emit_ident_by_name('cap',
				autofree_statement_cleanup_hook_preview_test_pos(321))
			return b.emit_selector_expr_by_ids(items_id, cap_id,
				autofree_statement_cleanup_hook_preview_test_pos(330))
		}
		'foreign_len_selector' {
			other_id := b.emit_ident_by_name('other',
				autofree_statement_cleanup_hook_preview_test_pos(320))
			return b.emit_selector_expr_by_ids(other_id, len_id,
				autofree_statement_cleanup_hook_preview_test_pos(330))
		}
		'infix' {
			len_selector_id := b.emit_selector_expr_by_ids(items_id, len_id,
				autofree_statement_cleanup_hook_preview_test_pos(330))
			literal_id := b.emit_basic_literal_by_value(.number, '1',
				autofree_statement_cleanup_hook_preview_test_pos(331))
			return b.emit_infix_expr_by_ids(.plus, len_selector_id, literal_id,
				autofree_statement_cleanup_hook_preview_test_pos(332))
		}
		'call' {
			callee_id := b.emit_ident_by_name('len_value',
				autofree_statement_cleanup_hook_preview_test_pos(330))
			return b.emit_call_expr_by_ids(callee_id, [],
				autofree_statement_cleanup_hook_preview_test_pos(331))
		}
		'index' {
			index_id := b.emit_basic_literal_by_value(.number, '0',
				autofree_statement_cleanup_hook_preview_test_pos(331))
			return b.emit_index_expr_by_ids(items_id, index_id, false,
				autofree_statement_cleanup_hook_preview_test_pos(332))
		}
		'nested_selector' {
			child_id := b.emit_ident_by_name('child',
				autofree_statement_cleanup_hook_preview_test_pos(321))
			nested_root_id := b.emit_selector_expr_by_ids(items_id, child_id,
				autofree_statement_cleanup_hook_preview_test_pos(330))
			return b.emit_selector_expr_by_ids(nested_root_id, len_id,
				autofree_statement_cleanup_hook_preview_test_pos(331))
		}
		else {
			return b.emit_basic_literal_by_value(.number, '1',
				autofree_statement_cleanup_hook_preview_test_pos(330))
		}
	}
}

fn autofree_statement_singleton_final_len_matcher_stmt(fixture &AutofreeStatementSingletonFinalLenMatcherFixture) ast.Cursor {
	return ast.Cursor{
		flat: &fixture.flat
		id:   fixture.stmt_id
	}
}

fn test_autofree_statement_location_singleton_final_len_matcher_accepts_direct_len_selector() {
	fixture := autofree_statement_singleton_final_len_matcher_fixture('len_selector', 'sink',
		.decl_assign)
	stmt := autofree_statement_singleton_final_len_matcher_stmt(&fixture)
	assert autofree_statement_location_stmt_is_singleton_final_len_slot(stmt, fixture.anchor, [
		fixture.anchor,
	])
}

fn test_autofree_statement_location_singleton_final_len_matcher_rejects_invalid_shapes() {
	cases := [
		'cap_selector',
		'foreign_len_selector',
		'infix',
		'call',
		'index',
		'nested_selector',
		'literal',
	]
	for item in cases {
		fixture := autofree_statement_singleton_final_len_matcher_fixture(item, 'sink',
			.decl_assign)
		stmt := autofree_statement_singleton_final_len_matcher_stmt(&fixture)
		assert !autofree_statement_location_stmt_is_singleton_final_len_slot(stmt, fixture.anchor, [
			fixture.anchor,
		])
	}
	target_lhs := autofree_statement_singleton_final_len_matcher_fixture('len_selector', 'items',
		.decl_assign)
	target_lhs_stmt := autofree_statement_singleton_final_len_matcher_stmt(&target_lhs)
	assert !autofree_statement_location_stmt_is_singleton_final_len_slot(target_lhs_stmt,
		target_lhs.anchor, [target_lhs.anchor])
	assign_op := autofree_statement_singleton_final_len_matcher_fixture('len_selector', 'sink',
		.assign)
	assign_op_stmt := autofree_statement_singleton_final_len_matcher_stmt(&assign_op)
	assert !autofree_statement_location_stmt_is_singleton_final_len_slot(assign_op_stmt,
		assign_op.anchor, [assign_op.anchor])
	multi_anchor := autofree_statement_singleton_final_len_matcher_fixture('len_selector', 'sink',
		.decl_assign)
	multi_anchor_stmt := autofree_statement_singleton_final_len_matcher_stmt(&multi_anchor)
	second_anchor := AutofreeCleanCStatementAnchorFact{
		...multi_anchor.anchor
		name:           'other_items'
		target_node_id: ast.FlatNodeId(9001)
		target_pos_id:  9002
	}
	assert !autofree_statement_location_stmt_is_singleton_final_len_slot(multi_anchor_stmt,
		multi_anchor.anchor, [multi_anchor.anchor, second_anchor])
}

fn autofree_statement_cleanup_emit_test_two_array_natural_release_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('two_array_natural_release',
		autofree_statement_cleanup_emit_test_two_array_natural_release_source())
}

fn autofree_statement_cleanup_emit_test_mixed_two_array_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('mixed_two_array',
		autofree_statement_cleanup_emit_test_mixed_two_array_source())
}

fn autofree_statement_cleanup_emit_test_two_array_literal_final_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('two_array_literal_final',
		autofree_statement_cleanup_emit_test_two_array_literal_final_source())
}

fn autofree_statement_cleanup_emit_test_len_only_final_clone_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('len_only_final_clone',
		autofree_statement_cleanup_emit_test_len_only_final_clone_source())
}

fn autofree_statement_cleanup_emit_test_cap_only_final_clone_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('cap_only_final_clone',
		autofree_statement_cleanup_emit_test_cap_only_final_clone_source())
}

fn autofree_statement_cleanup_emit_test_multi_param_fresh_local_final_clone_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('multi_param_fresh_local_final_clone',
		autofree_statement_cleanup_emit_test_multi_param_fresh_local_final_clone_source())
}

fn autofree_statement_cleanup_emit_test_receiver_field_slice_clone_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('receiver_field_slice_clone',
		autofree_statement_cleanup_emit_test_receiver_field_slice_clone_source())
}

fn autofree_statement_cleanup_emit_test_receiver_field_slice_clone_nested_then_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('receiver_field_slice_clone_nested_then',
		autofree_statement_cleanup_emit_test_receiver_field_slice_clone_nested_then_source())
}

fn autofree_statement_cleanup_emit_test_loop_local_clone_push_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('loop_local_clone_push',
		autofree_statement_cleanup_emit_test_loop_local_clone_push_source())
}

fn autofree_statement_cleanup_emit_test_fresh_local_string_clone_push_fixture() AutofreeStatementCleanupEmitPipelineFixture {
	return autofree_statement_cleanup_emit_test_pipeline_fixture('fresh_local_string_clone_push',
		autofree_statement_cleanup_emit_test_fresh_local_string_clone_push_source())
}

fn autofree_statement_cleanup_emit_test_find_fn_cursor(flat &ast.FlatAst, fn_name string) ?AutofreeStatementCleanupEmitPipelineCursor {
	for file_i in 0 .. flat.files.len {
		file_cursor := flat.file_cursor(file_i)
		stmts := file_cursor.stmts()
		for stmt_i in 0 .. stmts.len() {
			fn_cursor := stmts.at(stmt_i)
			if fn_cursor.is_valid() && fn_cursor.kind() == .stmt_fn_decl
				&& fn_cursor.name() == fn_name {
				return AutofreeStatementCleanupEmitPipelineCursor{
					file_cursor: file_cursor
					fn_cursor:   fn_cursor
				}
			}
		}
	}
	return none
}

fn test_autofree_statement_cleanup_emit_rule110_style_clone_cleanup_pipeline_reaches_context() {
	mut fixture := autofree_statement_cleanup_emit_test_rule110_style_fixture()
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat, 'next_generation') or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == 'next_generation'
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 1
	assert points[0].name == 'arr'
	assert points[0].move_kind == .local_array_clone_binding
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 1
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 1
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 1
	previews := autofree_statement_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, locations)
	assert previews.len == 1
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 1
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 1
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert cleanup_previews.len == 1
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, cleanup_previews)
	assert hook_previews.len == 1
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
	assert contexts.len == 1
	assert contexts[0].name == 'arr'
	assert contexts[0].cleanup_text == 'array__free(&arr);'
}

fn test_autofree_statement_cleanup_emit_multi_param_fresh_local_final_clone_pipeline_reaches_context() {
	mut fixture :=
		autofree_statement_cleanup_emit_test_multi_param_fresh_local_final_clone_fixture()
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat,
		'fill_array_from_fresh_local_with_extra') or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == 'fill_array_from_fresh_local_with_extra'
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 1
	assert points[0].name == 'arr'
	assert points[0].move_kind == .fresh_local_binding
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 1
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 1
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 1
	previews := autofree_statement_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, locations)
	assert previews.len == 1
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 1
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 1
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert cleanup_previews.len == 1
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, cleanup_previews)
	assert hook_previews.len == 1
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
	assert contexts.len == 1
	assert contexts[0].name == 'arr'
	assert contexts[0].cleanup_text == 'array__free(&arr);'
}

fn test_autofree_statement_cleanup_emit_receiver_field_slice_clone_real_pipeline_reaches_context() {
	mut fixture := autofree_statement_cleanup_emit_test_receiver_field_slice_clone_fixture()
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat,
		'fill_array_from_field_slice') or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == 'Game__fill_array_from_field_slice'
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 1
	assert points[0].name == 'next'
	assert points[0].move_kind == .receiver_field_slice_clone_binding
	assert points[0].source_endpoint.name == 'g.items[..]'
	assert points[0].source_endpoint.root_name == 'g'
	assert points[0].source_endpoint.path.len == 2
	assert points[0].source_endpoint.path[0].name == 'items'
	assert points[0].source_endpoint.path[1].name == '[..]'
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 1
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 1
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 1
	previews := autofree_statement_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, locations)
	assert previews.len == 1
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 1
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 1
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert cleanup_previews.len == 1
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, cleanup_previews)
	assert hook_previews.len == 1
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
	assert contexts.len == 1
	assert contexts[0].fn_key == fn_key
	assert contexts[0].fn_name == 'fill_array_from_field_slice'
	assert contexts[0].name == 'next'
	assert contexts[0].cleanup_text == 'array__free(&next);'
}

fn test_autofree_statement_cleanup_emit_receiver_field_slice_clone_nested_then_real_pipeline_reaches_context() {
	mut fixture :=
		autofree_statement_cleanup_emit_test_receiver_field_slice_clone_nested_then_fixture()
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat,
		'fill_array_from_field_slice_then_loop') or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == 'Game__fill_array_from_field_slice_then_loop'
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 1
	assert points[0].name == 'next'
	assert points[0].move_kind == .receiver_field_slice_clone_binding
	assert points[0].source_endpoint.name == 'g.items[..]'
	assert points[0].source_endpoint.root_name == 'g'
	assert points[0].source_endpoint.path.len == 2
	assert points[0].source_endpoint.path[0].name == 'items'
	assert points[0].source_endpoint.path[1].name == '[..]'
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 1
	assert bridge_facts[0].move_kind == .receiver_field_slice_clone_binding
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 1
	assert anchors[0].move_kind == .receiver_field_slice_clone_binding
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 1
	assert locations[0].block_path == '0'
	assert locations[0].stmt_index == 1
	assert locations[0].stmt_node_id == points[0].insert_after_node_id
	previews := autofree_statement_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, locations)
	assert previews.len == 1
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 1
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 1
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert cleanup_previews.len == 1
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, cleanup_previews)
	assert hook_previews.len == 1
	assert hook_previews[0].block_path == '0'
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
	assert contexts.len == 1
	assert contexts[0].fn_key == fn_key
	assert contexts[0].fn_name == 'fill_array_from_field_slice_then_loop'
	assert contexts[0].name == 'next'
	assert contexts[0].block_path == '0'
	assert contexts[0].cleanup_text == 'array__free(&next);'
}

fn test_autofree_statement_cleanup_emit_loop_local_clone_push_pipeline_reaches_loop_body_context() {
	mut fixture := autofree_statement_cleanup_emit_test_loop_local_clone_push_fixture()
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat, 'fill_rows') or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == 'Board__fill_rows'
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 1
	assert points[0].name == 'row'
	assert points[0].move_kind == .loop_local_clone_push_binding
	contexts := g.autofree_statement_cleanup_emit_contexts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor)
	assert contexts.len == 1
	assert contexts[0].context_kind == .after_statement
	assert contexts[0].move_kind == .loop_local_clone_push_binding
	assert contexts[0].fn_key == fn_key
	assert contexts[0].fn_name == 'fill_rows'
	assert contexts[0].name == 'row'
	assert contexts[0].block_path == '4'
	assert contexts[0].cleanup_text == 'array__free(&row);'
}

fn test_autofree_statement_cleanup_emit_fresh_local_string_clone_push_pipeline_reaches_context() {
	mut fixture := autofree_statement_cleanup_emit_test_fresh_local_string_clone_push_fixture()
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat, 'push_joined') or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == 'push_joined'
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 1
	assert points[0].name == 'text'
	assert points[0].move_kind == .fresh_local_string_clone_push_binding
	assert points[0].plan_action == .string_value_cleanup
	assert points[0].resource == .string_value
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 1
	assert bridge_facts[0].move_kind == .fresh_local_string_clone_push_binding
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 1
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 1
	previews := autofree_statement_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, locations)
	assert previews.len == 1
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 1
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 1
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert cleanup_previews.len == 1
	assert cleanup_previews[0].cleanup_kind == .string_after_statement
	assert cleanup_previews[0].cleanup_symbol == 'string__free'
	assert cleanup_previews[0].cleanup_text == 'string__free(&text);'
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, cleanup_previews)
	assert hook_previews.len == 1
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
	assert contexts.len == 1
	assert contexts[0].context_kind == .after_statement
	assert contexts[0].move_kind == .fresh_local_string_clone_push_binding
	assert contexts[0].fn_key == fn_key
	assert contexts[0].fn_name == 'push_joined'
	assert contexts[0].name == 'text'
	assert contexts[0].cleanup_symbol == 'string__free'
	assert contexts[0].cleanup_text == 'string__free(&text);'
	assert !contexts[0].cleanup_text.contains('array__free')
	assert !contexts[0].cleanup_text.contains('items')
}

fn test_autofree_statement_cleanup_emit_cap_only_natural_release_pipeline_reaches_context() {
	mut fixture := autofree_statement_cleanup_emit_test_cap_only_natural_release_fixture()
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat,
		'build_array_with_cap') or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == 'build_array_with_cap'
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 1
	assert points[0].name == 'items'
	assert points[0].move_kind == .fresh_local_binding
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 1
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 1
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 1
	previews := autofree_statement_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, locations)
	assert previews.len == 1
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 1
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 1
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert cleanup_previews.len == 1
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, cleanup_previews)
	assert hook_previews.len == 1
	assert hook_previews[0].hook_kind == .after_body_before_scheduled_drops
	assert hook_previews[0].block_path == ''
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
	assert contexts.len == 1
	assert contexts[0].context_kind == .after_body_before_scheduled_drops
	assert contexts[0].block_path == ''
	assert contexts[0].name == 'items'
	assert contexts[0].cleanup_text == 'array__free(&items);'
}

fn test_autofree_statement_cleanup_emit_len_only_natural_release_pipeline_reaches_context() {
	mut fixture := autofree_statement_cleanup_emit_test_len_only_natural_release_fixture()
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat,
		'build_array_with_len') or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == 'build_array_with_len'
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 1
	assert points[0].name == 'items'
	assert points[0].move_kind == .fresh_local_binding
	assert points[0].source_endpoint.reason == 'len-only scalar array literal'
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 1
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 1
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 1
	previews := autofree_statement_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, locations)
	assert previews.len == 1
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 1
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 1
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert cleanup_previews.len == 1
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, cleanup_previews)
	assert hook_previews.len == 1
	assert hook_previews[0].hook_kind == .after_body_before_scheduled_drops
	assert hook_previews[0].block_path == ''
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
	assert contexts.len == 1
	assert contexts[0].context_kind == .after_body_before_scheduled_drops
	assert contexts[0].block_path == ''
	assert contexts[0].name == 'items'
	assert contexts[0].cleanup_text == 'array__free(&items);'
}

fn autofree_statement_cleanup_emit_test_assert_single_final_len_pipeline_reaches_context(fixture &AutofreeStatementCleanupEmitPipelineFixture, fn_name string, reason string) {
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat, fn_name) or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == fn_name
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 1
	assert points[0].name == 'items'
	assert points[0].move_kind == .fresh_local_binding
	assert points[0].source_endpoint.reason == reason
	assert points[0].release_after_node_id != points[0].node_id
	assert points[0].release_after_pos_id > points[0].pos_id
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 1
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 1
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 1
	assert locations[0].stmt_node_id == points[0].release_after_node_id
	assert locations[0].stmt_pos_id == points[0].release_after_pos_id
	previews := autofree_statement_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, locations)
	assert previews.len == 1
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 1
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 1
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert cleanup_previews.len == 1
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, cleanup_previews)
	assert hook_previews.len == 1
	assert hook_previews[0].hook_kind == .after_body_before_scheduled_drops
	assert hook_previews[0].block_path == ''
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
	assert contexts.len == 1
	assert contexts[0].context_kind == .after_body_before_scheduled_drops
	assert contexts[0].block_path == ''
	assert contexts[0].name == 'items'
	assert contexts[0].cleanup_text == 'array__free(&items);'
}

fn test_autofree_statement_cleanup_emit_single_final_len_pipeline_reaches_context() {
	fixture := autofree_statement_cleanup_emit_test_single_final_len_fixture()
	autofree_statement_cleanup_emit_test_assert_single_final_len_pipeline_reaches_context(&fixture,
		'build_empty_array_final_len', 'empty dynamic array literal')
	autofree_statement_cleanup_emit_test_assert_single_final_len_pipeline_reaches_context(&fixture,
		'build_cap_array_final_len', 'cap-only scalar array literal')
	autofree_statement_cleanup_emit_test_assert_single_final_len_pipeline_reaches_context(&fixture,
		'build_len_array_final_len', 'len-only scalar array literal')
}

fn test_autofree_statement_cleanup_emit_local_array_push_literal_sink_pipeline_reaches_context() {
	fixture := autofree_statement_cleanup_emit_test_local_array_push_literal_sink_fixture()
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat,
		'build_local_array_push_literal_return') or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == 'build_local_array_push_literal_return'
	transfers := fixture.env.autofree_transfers_by_fn_key[fn_key] or {
		[]types.AutofreeTransferFact{}
	}
	assert transfers.len == 0
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 1
	assert points[0].name == 'items'
	assert points[0].move_kind == .fresh_local_binding
	assert points[0].source_endpoint.reason == 'empty dynamic array literal'
	assert points[0].release_after_node_id != points[0].node_id
	assert points[0].release_after_pos_id > points[0].pos_id
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 1
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 1
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 1
	assert locations[0].stmt_node_id == points[0].release_after_node_id
	assert locations[0].stmt_pos_id == points[0].release_after_pos_id
	previews := autofree_statement_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, locations)
	assert previews.len == 1
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 1
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 1
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert cleanup_previews.len == 1
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, cleanup_previews)
	assert hook_previews.len == 1
	assert hook_previews[0].hook_kind == .after_statement
	assert hook_previews[0].block_path == ''
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
	assert contexts.len == 1
	assert contexts[0].context_kind == .after_statement
	assert contexts[0].block_path == ''
	assert contexts[0].name == 'items'
	assert contexts[0].cleanup_text == 'array__free(&items);'
}

fn autofree_statement_cleanup_emit_test_assert_two_array_pipeline_reaches_context(fixture &AutofreeStatementCleanupEmitPipelineFixture, fn_name string, reason string) {
	autofree_statement_cleanup_emit_test_assert_two_array_pipeline_reaches_context_with_reasons(fixture,
		fn_name, reason, reason)
}

fn autofree_statement_cleanup_emit_test_assert_two_array_pipeline_reaches_context_with_reasons(fixture &AutofreeStatementCleanupEmitPipelineFixture, fn_name string, first_reason string, second_reason string) {
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat, fn_name) or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == fn_name
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 2
	assert points[0].name == 'first'
	assert points[1].name == 'second'
	assert points[0].source_endpoint.reason == first_reason
	assert points[1].source_endpoint.reason == second_reason
	assert points[0].insert_after_node_id == points[1].insert_after_node_id
	assert points[0].insert_after_pos_id == points[1].insert_after_pos_id
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 2
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 2
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 2
	previews := autofree_statement_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, locations)
	assert previews.len == 2
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 2
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 2
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert cleanup_previews.len == 2
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, cleanup_previews)
	assert hook_previews.len == 2
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
	assert contexts.len == 2
	assert contexts[0].name == 'second'
	assert contexts[0].cleanup_text == 'array__free(&second);'
	assert contexts[1].name == 'first'
	assert contexts[1].cleanup_text == 'array__free(&first);'
}

fn test_autofree_statement_cleanup_emit_mixed_two_array_pipeline_reaches_context() {
	fixture := autofree_statement_cleanup_emit_test_mixed_two_array_fixture()
	autofree_statement_cleanup_emit_test_assert_two_array_pipeline_reaches_context_with_reasons(&fixture,
		'build_mixed_empty_cap_arrays', 'empty dynamic array literal',
		'cap-only scalar array literal')
	autofree_statement_cleanup_emit_test_assert_two_array_pipeline_reaches_context_with_reasons(&fixture,
		'build_mixed_cap_empty_arrays', 'cap-only scalar array literal',
		'empty dynamic array literal')
	autofree_statement_cleanup_emit_test_assert_two_array_pipeline_reaches_context_with_reasons(&fixture,
		'build_mixed_empty_len_arrays', 'empty dynamic array literal',
		'len-only scalar array literal')
	autofree_statement_cleanup_emit_test_assert_two_array_pipeline_reaches_context_with_reasons(&fixture,
		'build_mixed_len_empty_arrays', 'len-only scalar array literal',
		'empty dynamic array literal')
	autofree_statement_cleanup_emit_test_assert_two_array_pipeline_reaches_context_with_reasons(&fixture,
		'build_mixed_cap_len_arrays', 'cap-only scalar array literal',
		'len-only scalar array literal')
	autofree_statement_cleanup_emit_test_assert_two_array_pipeline_reaches_context_with_reasons(&fixture,
		'build_mixed_len_cap_arrays', 'len-only scalar array literal',
		'cap-only scalar array literal')
}

fn test_autofree_statement_cleanup_emit_two_array_natural_release_pipeline_reaches_context() {
	fixture := autofree_statement_cleanup_emit_test_two_array_natural_release_fixture()
	autofree_statement_cleanup_emit_test_assert_two_array_pipeline_reaches_context(&fixture,
		'build_two_empty_arrays', 'empty dynamic array literal')
	autofree_statement_cleanup_emit_test_assert_two_array_pipeline_reaches_context(&fixture,
		'build_two_cap_arrays', 'cap-only scalar array literal')
	autofree_statement_cleanup_emit_test_assert_two_array_pipeline_reaches_context(&fixture,
		'build_two_len_arrays', 'len-only scalar array literal')
}

fn test_autofree_statement_cleanup_emit_two_array_literal_final_pipeline_rejects_group_location() {
	fixture := autofree_statement_cleanup_emit_test_two_array_literal_final_fixture()
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat,
		'build_two_empty_arrays') or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == 'build_two_empty_arrays'
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 2
	assert points[0].name == 'first'
	assert points[1].name == 'second'
	assert points[0].insert_after_node_id == points[1].insert_after_node_id
	assert points[0].insert_after_pos_id == points[1].insert_after_pos_id
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 2
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 2
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 0
}

fn test_autofree_statement_cleanup_emit_len_only_final_clone_pipeline_reaches_context() {
	mut fixture := autofree_statement_cleanup_emit_test_len_only_final_clone_fixture()
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat,
		'fill_array_from_len_only') or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == 'fill_array_from_len_only'
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 1
	assert points[0].name == 'arr'
	assert points[0].move_kind == .fresh_local_binding
	assert points[0].source_endpoint.reason == 'len-only scalar array literal'
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 1
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 1
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 1
	previews := autofree_statement_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, locations)
	assert previews.len == 1
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 1
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 1
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert cleanup_previews.len == 1
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, cleanup_previews)
	assert hook_previews.len == 1
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
	assert contexts.len == 1
	assert contexts[0].name == 'arr'
	assert contexts[0].cleanup_text == 'array__free(&arr);'
}

fn test_autofree_statement_cleanup_emit_cap_only_final_clone_pipeline_reaches_context() {
	mut fixture := autofree_statement_cleanup_emit_test_cap_only_final_clone_fixture()
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat,
		'fill_array_from_cap_only') or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == 'fill_array_from_cap_only'
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 1
	assert points[0].name == 'arr'
	assert points[0].move_kind == .fresh_local_binding
	assert points[0].source_endpoint.reason == 'cap-only scalar array literal'
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 1
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 1
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 1
	previews := autofree_statement_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, locations)
	assert previews.len == 1
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 1
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 1
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert cleanup_previews.len == 1
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, cleanup_previews)
	assert hook_previews.len == 1
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
	assert contexts.len == 1
	assert contexts[0].name == 'arr'
	assert contexts[0].cleanup_text == 'array__free(&arr);'
}

fn test_autofree_statement_cleanup_emit_fresh_local_final_clone_pipeline_reaches_context() {
	mut fixture := autofree_statement_cleanup_emit_test_fresh_local_final_clone_fixture()
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat,
		'fill_array_from_fresh_local') or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == 'fill_array_from_fresh_local'
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 1
	assert points[0].name == 'arr'
	assert points[0].move_kind == .fresh_local_binding
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 1
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 1
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 1
	previews := autofree_statement_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, locations)
	assert previews.len == 1
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 1
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 1
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert cleanup_previews.len == 1
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, cleanup_previews)
	assert hook_previews.len == 1
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
	assert contexts.len == 1
	assert contexts[0].name == 'arr'
	assert contexts[0].cleanup_text == 'array__free(&arr);'
}

fn test_autofree_statement_cleanup_emit_prefixed_fresh_local_final_clone_pipeline_reaches_context() {
	mut fixture := autofree_statement_cleanup_emit_test_prefixed_fresh_local_final_clone_fixture()
	cursor := autofree_statement_cleanup_emit_test_find_fn_cursor(&fixture.flat,
		'fill_array_from_prefixed_fresh_local') or {
		assert false
		return
	}
	mut g := Gen.new_with_env_pref_and_flat(&fixture.flat, fixture.env, fixture.prefs)
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(cursor.file_cursor,
		cursor.fn_cursor) or {
		assert false
		return
	}
	assert fn_key == 'fill_array_from_prefixed_fresh_local'
	points := fixture.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		[]types.AutofreeReleaseInsertionPointFact{}
	}
	assert points.len == 1
	assert points[0].name == 'arr'
	assert points[0].move_kind == .fresh_local_binding
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	assert bridge_facts.len == 1
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	assert anchors.len == 1
	locations := autofree_statement_location_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, anchors)
	assert locations.len == 1
	previews := autofree_statement_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, locations)
	assert previews.len == 1
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 1
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 1
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert cleanup_previews.len == 1
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(cursor.file_cursor,
		cursor.fn_cursor, cleanup_previews)
	assert hook_previews.len == 1
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
	assert contexts.len == 1
	assert contexts[0].name == 'arr'
	assert contexts[0].cleanup_text == 'array__free(&arr);'
}
