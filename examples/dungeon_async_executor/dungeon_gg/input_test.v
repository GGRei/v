module dungeon_gg

import dungeon_core
import gg

fn test_qwerty_key_mapping_to_core_commands() {
	bindings := input_bindings_for_layout(.qwerty)
	assert gg.KeyCode.w in bindings.move_forward
	assert gg.KeyCode.s in bindings.move_back
	assert gg.KeyCode.q in bindings.strafe_left
	assert gg.KeyCode.e in bindings.strafe_right
	assert gg.KeyCode.a in bindings.turn_left
	assert gg.KeyCode.d in bindings.turn_right
	assert gg.KeyCode.d !in bindings.move_forward
	assert gg.KeyCode.d !in bindings.strafe_left
	assert gg.KeyCode.a !in bindings.strafe_left
	assert gg.KeyCode.q !in bindings.turn_left
	for key in [gg.KeyCode.w, .up] {
		action := action_from_key(bindings, key, false) or { panic('expected move_forward') }
		assert action.kind == .command
		assert action.command == dungeon_core.Command.move_forward
	}
	for key in [gg.KeyCode.s, .down] {
		action := action_from_key(bindings, key, false) or { panic('expected move_back') }
		assert action.kind == .command
		assert action.command == dungeon_core.Command.move_back
	}
	assert (action_from_key(bindings, .q, false) or { panic('expected strafe_left') }).command == .strafe_left
	assert (action_from_key(bindings, .e, false) or { panic('expected strafe_right') }).command == .strafe_right
	assert (action_from_key(bindings, .f, false) or { panic('expected interact') }).command == .interact
	for key in [gg.KeyCode.a, .left] {
		assert (action_from_key(bindings, key, false) or { panic('expected turn_left') }).command == .turn_left
	}
	for key in [gg.KeyCode.d, .right] {
		assert (action_from_key(bindings, key, false) or { panic('expected turn_right') }).command == .turn_right
	}
}

fn test_azerty_key_mapping_to_core_commands_and_aliases() {
	bindings := input_bindings_for_layout(.azerty)
	assert gg.KeyCode.z in bindings.move_forward
	assert gg.KeyCode.w in bindings.move_forward
	assert gg.KeyCode.q in bindings.strafe_left
	assert gg.KeyCode.e in bindings.strafe_right
	assert gg.KeyCode.a in bindings.turn_left
	assert gg.KeyCode.d in bindings.turn_right
	assert gg.KeyCode.a !in bindings.strafe_left
	assert gg.KeyCode.q !in bindings.turn_left
	assert gg.KeyCode.d !in bindings.strafe_right
	for key in [gg.KeyCode.z, .w] {
		action := action_from_key(bindings, key, false) or { panic('expected move_forward') }
		assert action.kind == .command
		assert action.command == dungeon_core.Command.move_forward
	}
	assert (action_from_key(bindings, .s, false) or { panic('expected move_back') }).command == .move_back
	assert (action_from_key(bindings, .q, false) or { panic('expected strafe_left') }).command == .strafe_left
	assert (action_from_key(bindings, .e, false) or { panic('expected strafe_right') }).command == .strafe_right
	assert (action_from_key(bindings, .f, false) or { panic('expected interact') }).command == .interact
	for key in [gg.KeyCode.a, .left] {
		assert (action_from_key(bindings, key, false) or { panic('expected turn_left') }).command == .turn_left
	}
	for key in [gg.KeyCode.d, .right] {
		assert (action_from_key(bindings, key, false) or { panic('expected turn_right') }).command == .turn_right
	}
}

fn test_key_mapping_to_app_actions_and_repeats() {
	bindings := input_bindings_for_layout(.qwerty)
	assert (action_from_key(bindings, .m, false) or { panic('expected generation') }).kind == .generation
	assert (action_from_key(bindings, .escape, false) or { panic('expected shutdown') }).kind == .shutdown
	assert action_from_key(bindings, .w, true) == none
	assert action_from_key(bindings, .space, false) == none
}

fn test_keyboard_layout_override_parser() {
	assert keyboard_layout_from_override('azerty') == .azerty
	assert keyboard_layout_from_override('fr') == .azerty
	assert keyboard_layout_from_override('qwerty') == .qwerty
	assert keyboard_layout_from_override('us') == .qwerty
	assert keyboard_layout_from_override('invalid') == .qwerty
}

fn test_keyboard_layout_signal_parser() {
	assert (keyboard_layout_from_signal('System Locale: LANG=fr_FR.UTF-8') or {
		panic('expected azerty')
	}) == .azerty
	assert (keyboard_layout_from_signal('X11 Layout: fr') or { panic('expected azerty') }) == .azerty
	assert (keyboard_layout_from_signal('layout: us') or { panic('expected qwerty') }) == .qwerty
	assert (keyboard_layout_from_signal('LANG=en_GB.UTF-8') or { panic('expected qwerty') }) == .qwerty
	assert (keyboard_layout_from_signal('040c:0000040c') or { panic('expected azerty') }) == .azerty
	assert (keyboard_layout_from_signal('0409:00000409') or { panic('expected qwerty') }) == .qwerty
	assert (keyboard_layout_from_signal('com.apple.keylayout.French') or {
		panic('expected azerty')
	}) == .azerty
	assert (keyboard_layout_from_signal('com.apple.keylayout.Belgian') or {
		panic('expected azerty')
	}) == .azerty
	assert (keyboard_layout_from_signal('com.apple.keylayout.US') or { panic('expected qwerty') }) == .qwerty
	assert (keyboard_layout_from_signal('com.apple.keylayout.ABC') or { panic('expected qwerty') }) == .qwerty
}

fn test_keyboard_layout_detection_from_injected_values() {
	assert detect_keyboard_layout_from_values(['azerty'], ['LANG=en_US.UTF-8'], [
		'layout: us',
	]) == .azerty
	assert detect_keyboard_layout_from_values(['qwerty'], ['LANG=fr_FR.UTF-8'], [
		'X11 Layout: fr',
	]) == .qwerty
	assert detect_keyboard_layout_from_values(['invalid'], ['LANG=fr_FR.UTF-8'], [
		'X11 Layout: fr',
	]) == .qwerty
	assert detect_keyboard_layout_from_values([], ['LANG=fr_BE.UTF-8'], []) == .azerty
	assert detect_keyboard_layout_from_values([], [], ['X11 Layout: us']) == .qwerty
	assert detect_keyboard_layout_from_values([], ['LANG=fr_FR.UTF-8'], ['layout: us']) == .qwerty
	assert detect_keyboard_layout_from_values([], [], ['']) == .qwerty
	assert detect_keyboard_layout_from_values([], [], ['unknown layout']) == .qwerty
	assert detect_keyboard_layout_from_values([], [], []) == .qwerty
}

fn test_controls_legend_for_keyboard_layouts() {
	assert controls_legend(input_bindings_for_layout(.qwerty)) == 'W/S move  Q/E strafe  A/D turn  F interact  M async gen  Escape quit'
	assert controls_legend(input_bindings_for_layout(.azerty)) == 'Z/S move  A/E strafe  Q/D turn  F interact  M async gen  Escape quit'
	assert controls_legend(InputBindings{
		layout:           .qwerty
		move_label:       'Move'
		strafe_label:     'Strafe'
		turn_label:       'Turn'
		interact_label:   'Use'
		generation_label: 'Generate'
		shutdown_label:   'Quit'
	}) == 'Move  Strafe  Turn  Use  Generate  Quit'
}

fn test_keyboard_layout_probe_commands_are_os_gated() {
	commands := keyboard_layout_probe_commands()
	$if linux {
		assert commands == ['localectl status', 'setxkbmap -query']
	} $else $if windows {
		assert commands.len == 1
		assert commands[0].contains('powershell')
	} $else $if macos {
		assert commands.len == 2
		assert commands[0].contains('defaults read')
		assert commands[1].contains('defaults read')
	} $else {
		assert commands.len == 0
	}
}
