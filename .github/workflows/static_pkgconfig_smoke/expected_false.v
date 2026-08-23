module main

$if $d('v:static_pkgconfig', false) {
	$compile_error('v:static_pkgconfig must stay false for CL-compatible compiler drivers')
}

fn main() {}
