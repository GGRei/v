module main

import os

fn validate(label string, condition bool) int {
	println('CHECK ${label:-38} ${if condition { 'PASS' } else { 'FAIL' }}')
	return if condition { 0 } else { 1 }
}

fn main() {
	root := os.join_path(os.temp_dir(), 'v_windows_lstat_nlink_probe')
	target := os.join_path(root, 'target.tmp')
	link := os.join_path(root, 'link.tmp')
	os.rmdir_all(root) or {}
	os.mkdir_all(root)!
	defer {
		os.rm(link) or {}
		os.rm(target) or {}
		os.rmdir(root) or {}
	}

	os.write_file(target, 'nlink')!
	os.symlink(target, link)!

	ordinary := os.lstat(target)!
	valid_link := os.lstat(link)!
	println('NLINK V phase=ordinary nlink=${ordinary.nlink}')
	println('NLINK V phase=valid_link nlink=${valid_link.nlink}')

	mut failures := 0
	failures += validate('ordinary lstat nlink is positive', ordinary.nlink >= 1)
	failures += validate('valid link follows target nlink', valid_link.nlink == ordinary.nlink)

	os.rm(target)!
	dangling_link := os.lstat(link)!
	println('NLINK V phase=dangling_link nlink=${dangling_link.nlink}')
	failures += validate('dangling fallback nlink is positive', dangling_link.nlink >= 1)

	println('NLINK V SUMMARY failures=${failures}')
	if failures != 0 {
		exit(1)
	}
}
