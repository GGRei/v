module dungeon_core

// Command is a core player action. Input adapters translate keys into
// these commands; commands do not depend on gg or any event system.
pub enum Command {
	move_forward
	move_back
	strafe_left
	strafe_right
	turn_left
	turn_right
	interact
}

// CommandStatus describes the semantic outcome of a command.
pub enum CommandStatus {
	moved
	blocked
	turned
	interacted
	no_effect
	reached_stairs
}

// CommandResult captures the post-command state version and outcome.
pub struct CommandResult {
pub:
	command    Command
	status     CommandStatus
	message    string
	version_id u64
	player     Pos
	facing     Direction
}

// apply_command mutates GameState according to a core command.
pub fn (mut state GameState) apply_command(command Command) CommandResult {
	match command {
		.move_forward {
			return state.move_in_direction(command, state.facing)
		}
		.move_back {
			return state.move_in_direction(command, state.facing.opposite())
		}
		.strafe_left {
			return state.move_in_direction(command, state.facing.turn_left())
		}
		.strafe_right {
			return state.move_in_direction(command, state.facing.turn_right())
		}
		.turn_left {
			state.facing = state.facing.turn_left()
			state.refresh_visibility()
			state.version_id++
			return state.command_result(command, .turned, 'Turned left.')
		}
		.turn_right {
			state.facing = state.facing.turn_right()
			state.refresh_visibility()
			state.version_id++
			return state.command_result(command, .turned, 'Turned right.')
		}
		.interact {
			return state.interact_front(command)
		}
	}
}

fn (mut state GameState) move_in_direction(command Command, dir Direction) CommandResult {
	target := state.player.step(dir)
	cell := state.dungeon.cell_at(target) or {
		message := 'The dungeon boundary blocks the way.'
		state.record_change(message)
		return state.command_result(command, .blocked, message)
	}
	if cell.blocks_movement() {
		message := blocked_message(cell)
		state.record_change(message)
		return state.command_result(command, .blocked, message)
	}

	state.player = target
	state.refresh_visibility()
	if cell.kind == .stairs {
		message := 'You stand on the stairs.'
		state.record_change(message)
		return state.command_result(command, .reached_stairs, message)
	}
	message := 'You move.'
	state.record_change(message)
	return state.command_result(command, .moved, message)
}

fn (mut state GameState) interact_front(command Command) CommandResult {
	target := state.player.step(state.facing)
	cell := state.dungeon.cell_at(target) or {
		message := 'There is nothing to interact with.'
		state.record_change(message)
		return state.command_result(command, .no_effect, message)
	}
	match cell.kind {
		.door {
			if cell.door_open {
				message := 'The door is already open.'
				state.record_change(message)
				return state.command_result(command, .no_effect, message)
			}
			state.dungeon.set_cell(target, cell.opened()) or {
				message := 'The door cannot be opened: ${err.msg()}'
				state.record_change(message)
				return state.command_result(command, .no_effect, message)
			}
			state.refresh_visibility()
			message := 'Opened the door.'
			state.record_change(message)
			return state.command_result(command, .interacted, message)
		}
		.stairs {
			message := 'The stairs lead deeper.'
			state.record_change(message)
			return state.command_result(command, .reached_stairs, message)
		}
		else {
			message := 'Nothing happens.'
			state.record_change(message)
			return state.command_result(command, .no_effect, message)
		}
	}
}

fn (state GameState) command_result(command Command, status CommandStatus, message string) CommandResult {
	return CommandResult{
		command:    command
		status:     status
		message:    message
		version_id: state.version_id
		player:     state.player
		facing:     state.facing
	}
}

fn blocked_message(cell Cell) string {
	match cell.kind {
		.wall { return 'A stone wall blocks the way.' }
		.door { return 'The door is closed.' }
		else { return 'The way is blocked.' }
	}
}
