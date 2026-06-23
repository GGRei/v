module dungeon_gg

import os
import time

const demo_log_file_name = 'dungeon_async_executor_demo.log'
const trace_env_name = 'DUNGEON_ASYNC_EXECUTOR_TRACE'

pub fn demo_log_path() string {
	return os.join_path(os.temp_dir(), demo_log_file_name)
}

fn log_info(message string) {
	log_info_to_path(demo_log_path(), message)
}

fn log_info_to_path(path string, message string) {
	if !trace_enabled() {
		return
	}
	write_log_line(path, 'INFO', message) or {}
}

fn trace_enabled() bool {
	return os.getenv(trace_env_name) == '1'
}

fn log_error(message string) {
	line := '[ERROR] ${message}'
	write_log_line(demo_log_path(), 'ERROR', message) or {
		eprintln('${line}; log write failed: ${err.msg()}')
		return
	}
	eprintln(line)
}

fn log_critical(message string) {
	line := '[CRITICAL] ${message}'
	write_log_line(demo_log_path(), 'CRITICAL', message) or {
		eprintln('${line}; log write failed: ${err.msg()}')
		return
	}
	eprintln(line)
}

fn write_log_line(path string, level string, message string) ! {
	mut file := os.open_append(path)!
	defer {
		file.close()
	}
	file.writeln('${time.now().format_ss_milli()} [${level}] ${message}')!
}
