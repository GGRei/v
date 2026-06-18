module main

__global (
	cached_lines = map[string][]string{}
)

struct Holder {
mut:
	items []string
}

fn make_lines(a string, b string) []string {
	mut lines := []string{}
	lines << a
	lines << b
	return lines
}

fn store_global() {
	lines := make_lines('global-a', 'global-b')
	cached_lines['global'] = lines
}

fn store_field(mut holder Holder) {
	lines := make_lines('field-a', 'field-b')
	holder.items = lines
}

fn store_map(mut target map[string][]string) {
	lines := make_lines('map-a', 'map-b')
	target['map'] = lines
}

fn make_holder() Holder {
	lines := make_lines('return-a', 'return-b')
	return Holder{
		items: lines
	}
}

fn main() {
	store_global()
	mut holder := Holder{
		items: []string{}
	}
	store_field(mut holder)
	mut target := map[string][]string{}
	store_map(mut target)
	returned := make_holder()
	println(cached_lines['global'].len + holder.items.len + target['map'].len + returned.items.len)
}
