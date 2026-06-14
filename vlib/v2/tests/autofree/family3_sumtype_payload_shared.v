module main

struct Empty {}

struct Full {
	name   string
	values []string
}

type Payload = Empty | Full

struct Holder {
	payload Payload = Empty{}
}

struct HolderSet {
	left         Holder
	right        Holder
	default_copy Holder
}

fn sample_values() []string {
	mut values := []string{}
	values << 'a'
	values << 'b'
	return values
}

fn payload_len(payload Payload) int {
	match payload {
		Empty {
			return 0
		}
		Full {
			return payload.values.len
		}
	}
}

fn make_source_holder() Holder {
	return Holder{
		payload: Full{
			name:   'full'
			values: sample_values()
		}
	}
}

fn make_default_holder() Holder {
	return Holder{}
}

fn make_pair() HolderSet {
	source_holder := make_source_holder()
	copied := source_holder
	default_holder := make_default_holder()
	default_copy := default_holder
	return HolderSet{
		left:         source_holder
		right:        copied
		default_copy: default_copy
	}
}

fn main() {
	pair := make_pair()
	println(payload_len(pair.left.payload) + payload_len(pair.right.payload) +
		payload_len(pair.default_copy.payload))
}
