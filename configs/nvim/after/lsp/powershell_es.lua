local bundle_path = vim.fn.stdpath("data") .. "/mason/packages/powershell-editor-services"
local log_path = vim.fn.stdpath("cache")

local command = ([[
& '%s/PowerShellEditorServices/Start-EditorServices.ps1'
    -BundledModulesPath '%s'
    -LogPath '%s/powershell_es.log'
    -SessionDetailsPath '%s/powershell_es.session.json'
    -FeatureFlags @()
    -AdditionalModules @()
    -HostName nvim
    -HostProfileId 0
    -HostVersion 1.0.0
    -Stdio
    -LogLevel Normal
]]):gsub("\n", " "):format(bundle_path, bundle_path, log_path, log_path)

return {
	cmd = { "pwsh", "-NoLogo", "-Command", command },
	filetypes = { "ps1" },
}
