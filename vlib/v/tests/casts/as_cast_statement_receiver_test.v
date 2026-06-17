type Any = int | string

fn make_map() map[string]Any {
	return {
		'a': Any(7)
	}
}

fn make_result(value string) !Any {
	if value == 'ok' {
		return Any(9)
	}
	return error('missing')
}

fn cast_in_return(m map[string]Any) int {
	return m['a'] or { Any(0) } as int
}

fn test_map_index_or_block_as_cast_receiver() {
	m := make_map()
	x := m['a'] or { Any(0) } as int
	assert x == 7
	y := m['missing'] or { Any('fallback') } as string
	assert y == 'fallback'
}

fn test_result_or_block_as_cast_receiver() {
	x := make_result('ok') or { Any(0) } as int
	assert x == 9
	y := make_result('missing') or { Any('fallback') } as string
	assert y == 'fallback'
}

fn test_or_block_as_cast_receiver_in_return_position() {
	m := make_map()
	assert cast_in_return(m) == 7
	assert cast_in_return(map[string]Any{}) == 0
}

fn test_map_index_or_block_as_cast_receiver_keeps_short_circuit() {
	mut misses := 0
	m := make_map()
	if false && (m['missing'] or {
		misses++
		Any(0)
	} as int) == 0 {
		assert false
	}
	assert misses == 0
	if true || (m['missing'] or {
		misses++
		Any(0)
	} as int) == 0 {
		assert true
	}
	assert misses == 0
}

fn test_map_index_or_block_as_cast_receiver_stays_in_if_branch() {
	mut misses := 0
	m := make_map()
	run_missing_branch := misses > 0
	value := if run_missing_branch {
		m['missing'] or {
			misses++
			Any(0)
		} as int
	} else {
		42
	}
	assert value == 42
	assert misses == 0
}
