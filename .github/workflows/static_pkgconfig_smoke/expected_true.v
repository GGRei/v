module main

$if !$d('v:static_pkgconfig', false) {
	$compile_error('v:static_pkgconfig must be true for GNU-compatible static linking')
}

fn main() {}
