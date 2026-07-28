@[translated]
module main

type SignedName = [9]i8
type SignedNameAlias = SignedName
type UnsignedName = [4]u8
type CharName = [4]char

struct FixedNames {
	short_name   SignedNameAlias
	exact_name   UnsignedName
	char_name    CharName
	pointer_name &char
}

const global_fixed_names = FixedNames{c'abc', c'WXYZ', c'char', c'pointer'}

fn test_translated_c_string_initializes_global_fixed_char_array_fields() {
	assert global_fixed_names.short_name[0] == i8(`a`)
	assert global_fixed_names.short_name[3] == 0
	assert global_fixed_names.exact_name[3] == u8(`Z`)
	assert global_fixed_names.char_name[3] == char(`r`)
	assert global_fixed_names.pointer_name[0] == char(`p`)
}

fn test_translated_c_string_initializes_local_fixed_char_array_fields() {
	local := FixedNames{
		short_name:   c'local'
		exact_name:   c'four'
		char_name:    c'char'
		pointer_name: c'pointer'
	}
	assert local.short_name[4] == i8(`l`)
	assert local.short_name[5] == 0
	assert local.exact_name[3] == u8(`r`)
	assert local.char_name[0] == char(`c`)
	assert local.pointer_name[1] == char(`o`)
}

fn test_translated_c_string_initializes_heap_fixed_char_array_fields() {
	heap := &FixedNames{
		short_name:   c'heap'
		exact_name:   c'full'
		char_name:    c'char'
		pointer_name: c'pointer'
	}
	assert heap.short_name[3] == i8(`p`)
	assert heap.short_name[4] == 0
	assert heap.exact_name[3] == u8(`l`)
	assert heap.char_name[2] == char(`a`)
	assert heap.pointer_name[2] == char(`i`)
}
