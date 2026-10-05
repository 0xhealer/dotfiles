return {
	cmd = {
		"clangd",
		"--background-index",
		"--clang-tidy",
		"--completion-style=detailed",
		"--header-insertion=iwyu",
		"--all-scopes-completion",
		"--cross-file-rename",
		"--offset-encoding=utf-16",

		"--enable-config",

		"--query-driver=**/gcc.exe,**/g++.exe,**/gcc,**/g++",
	},
}
