return {
  {
    "mfussenegger/nvim-dap",
    ft = { "cs", "vb", "fs" }, -- for C#, VB, F#
    config = function()
      local dap = require("dap")

      -- Set netcoredbg
      dap.adapters.coreclr = {
        type = "executable",
        command = vim.fn.exepath("netcoredbg"), -- try find in PATH
        args = { "--interpreter=vscode" },
        options = { detached = false },
      }

      -- Automatic find dll for debug
      local function find_dll()
        local cwd = vim.loop.cwd()
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

      dap.configurations.cs = {
        {
          type = "coreclr",
          name = "Launch .NET (auto DLL)",
          request = "launch",
          program = find_dll,
          cwd = vim.loop.cwd(),
          env = {
            ASPNETCORE_ENVIRONMENT = "Development", -- use env's for dubugging process
            DOTNET_ENVIRONMENT = "Development",
          },
        },
      }
    end,
  },
}
