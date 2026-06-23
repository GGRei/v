module dungeon_gg

import dungeon_core
import gg
import os

pub enum KeyboardLayout {
	qwerty
	azerty
}

pub struct InputBindings {
pub:
	layout           KeyboardLayout
	move_forward     []gg.KeyCode
	move_back        []gg.KeyCode
	strafe_left      []gg.KeyCode
	strafe_right     []gg.KeyCode
	turn_left        []gg.KeyCode
	turn_right       []gg.KeyCode
	interact         []gg.KeyCode
	generation       []gg.KeyCode
	shutdown         []gg.KeyCode
	move_label       string
	strafe_label     string
	turn_label       string
	interact_label   string
	generation_label string
	shutdown_label   string
}

pub enum InputActionKind {
	command
	generation
	shutdown
}

pub struct InputAction {
pub:
	kind    InputActionKind
	command dungeon_core.Command
}

fn (action InputAction) log_label() string {
	match action.kind {
		.command { return 'command:${action.command}' }
		.generation { return 'generation' }
		.shutdown { return 'shutdown' }
	}
}

pub fn input_bindings_for_layout(layout KeyboardLayout) InputBindings {
	match layout {
		.qwerty {
			return InputBindings{
				layout:           layout
				move_forward:     [gg.KeyCode.w, .up]
				move_back:        [gg.KeyCode.s, .down]
				strafe_left:      [gg.KeyCode.q]
				strafe_right:     [gg.KeyCode.e]
				turn_left:        [gg.KeyCode.a, .left]
				turn_right:       [gg.KeyCode.d, .right]
				interact:         [gg.KeyCode.f]
				generation:       [gg.KeyCode.m]
				shutdown:         [gg.KeyCode.escape]
				move_label:       'W/S move'
				strafe_label:     'Q/E strafe'
				turn_label:       'A/D turn'
				interact_label:   'F interact'
				generation_label: 'M async gen'
				shutdown_label:   'Escape quit'
			}
		}
		.azerty {
			return InputBindings{
				layout:           layout
				move_forward:     [gg.KeyCode.z, .w, .up]
				move_back:        [gg.KeyCode.s, .down]
				strafe_left:      [gg.KeyCode.q]
				strafe_right:     [gg.KeyCode.e]
				turn_left:        [gg.KeyCode.a, .left]
				turn_right:       [gg.KeyCode.d, .right]
				interact:         [gg.KeyCode.f]
				generation:       [gg.KeyCode.m]
				shutdown:         [gg.KeyCode.escape]
				move_label:       'Z/S move'
				strafe_label:     'A/E strafe'
				turn_label:       'Q/D turn'
				interact_label:   'F interact'
				generation_label: 'M async gen'
				shutdown_label:   'Escape quit'
			}
		}
	}
}

pub fn detect_input_bindings() InputBindings {
	return input_bindings_for_layout(detect_keyboard_layout())
}

pub fn controls_legend(bindings InputBindings) string {
	return '${bindings.move_label}  ${bindings.strafe_label}  ${bindings.turn_label}  ${bindings.interact_label}  ${bindings.generation_label}  ${bindings.shutdown_label}'
}

pub fn detect_keyboard_layout() KeyboardLayout {
	mut overrides := []string{}
	for name in ['DUNGEON_KEYBOARD_LAYOUT', 'DUNGEON_ASYNC_EXECUTOR_KEYBOARD_LAYOUT'] {
		value := os.getenv(name)
		if value != '' {
			overrides << value
		}
	}
	mut env_values := []string{}
	for name in ['XKB_DEFAULT_LAYOUT', 'LANG', 'LC_ALL', 'LC_CTYPE'] {
		value := os.getenv(name)
		if value != '' {
			env_values << value
		}
	}
	mut probe_outputs := []string{}
	for command in keyboard_layout_probe_commands() {
		result := os.execute(command)
		if result.exit_code == 0 && result.output.trim_space() != '' {
			probe_outputs << result.output
		}
	}
	return detect_keyboard_layout_from_values(overrides, env_values, probe_outputs)
}

fn detect_keyboard_layout_from_values(overrides []string, env_values []string, probe_outputs []string) KeyboardLayout {
	for value in overrides {
		if value.trim_space() != '' {
			return keyboard_layout_from_override(value)
		}
	}
	for output in probe_outputs {
		layout := keyboard_layout_from_signal(output) or { continue }
		return layout
	}
	for value in env_values {
		layout := keyboard_layout_from_signal(value) or { continue }
		return layout
	}
	return .qwerty
}

fn keyboard_layout_from_override(value string) KeyboardLayout {
	return keyboard_layout_from_signal(value) or { KeyboardLayout.qwerty }
}

fn keyboard_layout_from_signal(value string) ?KeyboardLayout {
	lower := value.to_lower()
	if lower.contains('azerty') || lower.contains('0000040c') || lower.contains('0000080c')
		|| lower.contains('00000813') {
		return .azerty
	}
	if lower.contains('qwerty') || lower.contains('00000409') || lower.contains('00000809') {
		return .qwerty
	}
	tokens := keyboard_layout_tokens(lower)
	for token in tokens {
		if token in ['fr', 'be', 'french', 'france', 'belgian', 'belgique'] {
			return .azerty
		}
	}
	for token in tokens {
		if token in ['us', 'usa', 'gb', 'uk', 'abc', 'english', 'british', 'american'] {
			return .qwerty
		}
	}
	return none
}

fn keyboard_layout_tokens(value string) []string {
	mut normalized := value
	for separator in ['\n', '\r', '\t', ',', ';', ':', '=', '.', '-', '_', '/', '\\', '(', ')',
		'[', ']', '{', '}', '"', "'"] {
		normalized = normalized.replace(separator, ' ')
	}
	return normalized.fields()
}

fn keyboard_layout_probe_commands() []string {
	$if linux {
		return [
			'localectl status',
			'setxkbmap -query',
		]
	} $else $if windows {
		return [
			'powershell -NoProfile -Command "(Get-WinUserLanguageList)[0].InputMethodTips -join \',\'"',
		]
	} $else $if macos {
		return [
			'defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID',
			'defaults read com.apple.HIToolbox AppleSelectedInputSources',
		]
	} $else {
		return []
	}
}

// action_from_key maps discrete key-down events to core commands or app actions.
pub fn action_from_key(bindings InputBindings, key gg.KeyCode, repeated bool) ?InputAction {
	if repeated {
		return none
	}

	if key in bindings.move_forward {
		return InputAction{
			kind:    .command
			command: .move_forward
		}
	}
	if key in bindings.move_back {
		return InputAction{
			kind:    .command
			command: .move_back
		}
	}
	if key in bindings.strafe_left {
		return InputAction{
			kind:    .command
			command: .strafe_left
		}
	}
	if key in bindings.strafe_right {
		return InputAction{
			kind:    .command
			command: .strafe_right
		}
	}
	if key in bindings.turn_left {
		return InputAction{
			kind:    .command
			command: .turn_left
		}
	}
	if key in bindings.turn_right {
		return InputAction{
			kind:    .command
			command: .turn_right
		}
	}
	if key in bindings.interact {
		return InputAction{
			kind:    .command
			command: .interact
		}
	}
	if key in bindings.generation {
		return InputAction{
			kind: .generation
		}
	}
	if key in bindings.shutdown {
		return InputAction{
			kind: .shutdown
		}
	}

	return none
}
