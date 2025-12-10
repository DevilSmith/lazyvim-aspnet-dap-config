return {
	{
		"mfussenegger/nvim-dap",
		ft = { "cs", "vb", "fs" }, -- for C#, VB, F#
		config = function()
			local dap = require("dap")

			local function get_cwd_path()
				return vim.fn.input("Workspace folder: ", vim.fn.getcwd() .. "/", "file")
			end

			local global_cwd = get_cwd_path()

			-- Set netcoredbg
			dap.adapters.coreclr = {
				type = "executable",
				command = vim.fn.exepath("netcoredbg"), -- try find in PATH
				args = { "--interpreter=vscode" },
				options = { detached = false },
			}

			-- Automatic find dll for debug
			local function find_dll()
				local cwd = global_cwd
				local pattern = cwd .. "/**/bin/Debug/*/*.dll"
				local dlls = vim.fn.glob(pattern, 1, 1)
				if not dlls or #dlls == 0 then
					vim.notify("No DLL found — run `dotnet build` first", vim.log.levels.ERROR)
					return nil
				elseif #dlls == 1 then
					return dlls[1]
				else
					return coroutine.create(function(co)
						vim.ui.select(dlls, { prompt = "Select DLL to debug:" }, function(choice)
							coroutine.resume(co, choice)
						end)
					end)
				end
			end

			local function load_launch_settings()
				-- try find launchSettings.json
				local cwd = global_cwd
				local launch = vim.fn.glob(cwd .. "/**/Properties/launchSettings.json", 1, 1)

				if not launch or #launch == 0 then
					vim.notify("launchSettings.json not found")
					return nil
				end

				vim.notify("launchSettings.json is found")

				local path = launch[1]

				-- read launchSettings.json
				local ok, content = pcall(vim.fn.readfile, path)
				if not ok then
					return nil
				end

				local json = table.concat(content, "\n")

				local ok2, data = pcall(vim.json.decode, json)
				if not ok2 then
					return nil
				end

				return data
			end

			local function get_dotnet_profile()
				local data = load_launch_settings()
				if not data or not data.profiles then
					return nil
				end

				-- take first launch profile
				for name, profile in pairs(data.profiles) do
					return profile
				end

				return nil
			end

			dap.configurations.cs = {
				{
					type = "coreclr",
					name = "Launch .NET (auto DLL)",
					request = "launch",
					program = find_dll,
					cwd = global_cwd,
					-- read env + url
					env = function()
						local profile = get_dotnet_profile()
						if not profile or not profile.environmentVariables then
							return {}
						end
						return profile.environmentVariables
					end,

					args = function()
						local profile = get_dotnet_profile()
						if profile and profile.applicationUrl then
							-- send application url in ASP.NET Core
							return { "--urls", profile.applicationUrl }
						end
						return {}
					end,
				},
			}
		end,
	},
}
