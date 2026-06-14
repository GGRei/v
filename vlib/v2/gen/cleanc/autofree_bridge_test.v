module cleanc

import v2.ast
import v2.types

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
