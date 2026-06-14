module main

struct Packet {
mut:
	label string
	items []string
}

fn make_packet(label string, first string, second string) Packet {
	mut items := []string{}
	items << first
	items << second
	return Packet{
		label: label
		items: items
	}
}

fn append_item(mut packet Packet, item string) {
	packet.items << item
}

fn packet_score(packet Packet) int {
	return packet.label.len + packet.items.len
}

fn (mut packet Packet) rename(label string) {
	packet.label = label
}

fn (packet Packet) score_with(extra string) int {
	return packet_score(packet) + extra.len
}

fn boundary_total(label string, extra string) int {
	mut packet := make_packet(label, 'a', 'b')
	append_item(mut packet, extra)
	packet.rename('renamed')
	return packet.score_with(extra)
}

fn main() {
	println(boundary_total('root', 'tail'))
}
