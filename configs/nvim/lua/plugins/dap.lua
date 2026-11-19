-- Debugger (nvim-dap) and tests (neotest). Keys: <leader>D = debug, <leader>T = tests, plus the VSCode F-keys.
-- Adapters (codelldb, debugpy, delve, js-debug-adapter) are installed by Mason, see plugins/lsp.lua.
vim.pack.add({
	{ src = "https://github.com/mfussenegger/nvim-dap" },
	{ src = "https://github.com/nvim-neotest/nvim-nio" },
	{ src = "https://github.com/rcarriga/nvim-dap-ui" },
	{ src = "https://github.com/theHamsta/nvim-dap-virtual-text" },
	{ src = "https://github.com/mfussenegger/nvim-dap-python" },
	{ src = "https://github.com/nvim-neotest/neotest" },
	{ src = "https://github.com/nvim-neotest/neotest-python" },
	{ src = "https://github.com/fredrikaverpil/neotest-golang" },
	{ src = "https://github.com/rouge8/neotest-rust" },
})

local is_win = vim.fn.has("win32") == 1
local map = function(mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

local dap = require("dap")
local dapui = require("dapui")
dapui.setup()
require("nvim-dap-virtual-text").setup()

for name, spec in pairs({
	DapBreakpoint = { 0xf111, "DiagnosticError" },
	DapBreakpointCondition = { 0xf059, "DiagnosticWarn" },
	DapLogPoint = { 0xf075, "DiagnosticInfo" },
	DapBreakpointRejected = { 0xf057, "DiagnosticError" },
	DapStopped = { 0xf061, "DiagnosticOk" },
}) do
	vim.fn.sign_define(name, { text = vim.fn.nr2char(spec[1]), texthl = spec[2], linehl = "", numhl = "" })
end

dap.listeners.after.event_initialized["dapui"] = function()
	dapui.open()
end
dap.listeners.before.event_terminated["dapui"] = function()
	dapui.close()
end
dap.listeners.before.event_exited["dapui"] = function()
	dapui.close()
end

-- C, C++, Rust: codelldb
dap.adapters.codelldb = {
	type = "server",
	port = "${port}",
	executable = { command = "codelldb", args = { "--port", "${port}" }, detached = not is_win },
}
local function ask_exe()
	return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/", "file")
end
dap.configurations.c = {
	{ name = "Launch executable", type = "codelldb", request = "launch", program = ask_exe, cwd = "${workspaceFolder}" },
}
dap.configurations.cpp = dap.configurations.c
dap.configurations.rust = {
	{
		name = "Launch (cargo build first)",
		type = "codelldb",
		request = "launch",
		cwd = "${workspaceFolder}",
		program = function()
			vim.notify("cargo build ...")
			local r = vim.system({ "cargo", "build" }, { text = true }):wait()
			if r.code ~= 0 then
				vim.notify(r.stderr or "cargo build failed", vim.log.levels.ERROR)
				return dap.ABORT
			end
			local exe = vim.fn.getcwd() .. "/target/debug/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t") .. (is_win and ".exe" or "")
			return vim.fn.input("Executable: ", exe, "file")
		end,
	},
}

-- Python: debugpy from Mason
local debugpy = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/" .. (is_win and "Scripts/python.exe" or "bin/python")
require("dap-python").setup(vim.fn.executable(debugpy) == 1 and debugpy or (is_win and "python" or "python3"))

-- Go: delve
dap.adapters.delve = {
	type = "server",
	port = "${port}",
	executable = { command = "dlv", args = { "dap", "-l", "127.0.0.1:${port}" }, detached = not is_win },
}
dap.configurations.go = {
	{ type = "delve", name = "Debug file", request = "launch", program = "${file}" },
	{ type = "delve", name = "Debug package", request = "launch", program = "${fileDirname}" },
	{ type = "delve", name = "Debug test (file)", request = "launch", mode = "test", program = "${file}" },
}

-- JavaScript / TypeScript: js-debug-adapter
dap.adapters["pwa-node"] = {
	type = "server",
	host = "localhost",
	port = "${port}",
	executable = { command = "js-debug-adapter", args = { "${port}" } },
}
for _, ft in ipairs({ "javascript", "typescript" }) do
	dap.configurations[ft] = {
		{ type = "pwa-node", request = "launch", name = "Launch file", program = "${file}", cwd = "${workspaceFolder}" },
		{ type = "pwa-node", request = "attach", name = "Attach to process", processId = require("dap.utils").pick_process, cwd = "${workspaceFolder}" },
	}
end

map("n", "<leader>Db", dap.toggle_breakpoint, "Toggle breakpoint")
map("n", "<leader>DB", function()
	dap.set_breakpoint(vim.fn.input("Condition: "))
end, "Conditional breakpoint")
map("n", "<leader>Dl", function()
	dap.set_breakpoint(nil, nil, vim.fn.input("Log message: "))
end, "Log point")
map("n", "<leader>DX", dap.clear_breakpoints, "Clear all breakpoints")
map("n", "<leader>Dc", dap.continue, "Start / continue")
map("n", "<leader>DC", dap.run_to_cursor, "Run to cursor")
map("n", "<leader>Di", dap.step_into, "Step into")
map("n", "<leader>Do", dap.step_over, "Step over")
map("n", "<leader>DO", dap.step_out, "Step out")
map("n", "<leader>Dp", dap.pause, "Pause")
map("n", "<leader>Dj", dap.down, "Stack frame down")
map("n", "<leader>Dk", dap.up, "Stack frame up")
map("n", "<leader>Dr", dap.repl.toggle, "REPL")
map("n", "<leader>DR", dap.restart, "Restart")
map("n", "<leader>DL", dap.run_last, "Run last")
map("n", "<leader>Dt", dap.terminate, "Terminate")
map("n", "<leader>Du", dapui.toggle, "Debug UI")
map({ "n", "v" }, "<leader>De", dapui.eval, "Evaluate")
map("n", "<F5>", dap.continue, "Debug: start / continue")
map("n", "<S-F5>", dap.terminate, "Debug: terminate")
map("n", "<F9>", dap.toggle_breakpoint, "Debug: toggle breakpoint")
map("n", "<F10>", dap.step_over, "Debug: step over")
map("n", "<F11>", dap.step_into, "Debug: step into")
map("n", "<S-F11>", dap.step_out, "Debug: step out")

-- tests
local adapters = {}
for _, mod in ipairs({ "neotest-python", "neotest-golang", "neotest-rust" }) do
	local ok, a = pcall(require, mod)
	if ok then
		table.insert(adapters, mod == "neotest-python" and a({ dap = { justMyCode = false } }) or a)
	end
end
local nt = require("neotest")
nt.setup({ adapters = adapters })
map("n", "<leader>Tt", function() nt.run.run() end, "Run nearest test")
map("n", "<leader>Tf", function() nt.run.run(vim.fn.expand("%")) end, "Run file tests")
map("n", "<leader>Ta", function() nt.run.run(vim.fn.getcwd()) end, "Run all tests")
map("n", "<leader>Tl", function() nt.run.run_last() end, "Run last test")
map("n", "<leader>Td", function() nt.run.run({ strategy = "dap" }) end, "Debug nearest test")
map("n", "<leader>Tx", function() nt.run.stop() end, "Stop test")
map("n", "<leader>Ts", function() nt.summary.toggle() end, "Test summary")
map("n", "<leader>To", function() nt.output.open({ enter = true }) end, "Test output")
map("n", "<leader>TO", function() nt.output_panel.toggle() end, "Test output panel")
