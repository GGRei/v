module dungeon_gg

import os

fn test_write_log_line_appends_message() {
	path := os.join_path(os.temp_dir(), 'dungeon_async_executor_demo_log_test_${os.getpid()}.log')
	os.rm(path) or {}
	defer {
		os.rm(path) or {}
	}

	write_log_line(path, 'INFO', 'logger smoke')!
	content := os.read_file(path)!
	assert content.contains('[INFO] logger smoke')
}

fn test_log_info_is_trace_gated_without_using_demo_log() {
	path := os.join_path(os.temp_dir(), 'dungeon_async_executor_demo_trace_test_${os.getpid()}.log')
	os.rm(path) or {}
	old_trace := os.getenv(trace_env_name)
	defer {
		os.rm(path) or {}
		restore_env(trace_env_name, old_trace)
	}

	os.unsetenv(trace_env_name)
	log_info_to_path(path, 'hidden')
	assert !os.exists(path)

	os.setenv(trace_env_name, '1', true)
	log_info_to_path(path, 'visible')
	content := os.read_file(path)!
	assert content.contains('[INFO] visible')
	assert !content.contains('hidden')
}

fn restore_env(name string, value string) {
	if value == '' {
		os.unsetenv(name)
		return
	}
	os.setenv(name, value, true)
}
