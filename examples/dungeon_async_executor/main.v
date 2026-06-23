module main

import dungeon_core
import dungeon_gg

fn main() {
	dungeon_gg.run(
		seed:   7
		width:  dungeon_core.min_dungeon_width + 8
		height: dungeon_core.min_dungeon_height + 6
	) or {
		eprintln(err.msg())
		exit(1)
	}
}
