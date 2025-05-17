local M = {}

local detect = require("chez.detect")
local commands = require("chez.commands")
local zio = require("chez.io")
local exec = require("chez.exec")

setmetatable(M, {
  __index = commands,
})

local function chez_cmd(tbl)
  local args = tbl.fargs

  if tbl.bang then
    exec.exec_chezmoi(args, function(out, err)
      zio.buffer({ out, "", err })
    end)
    return
  end

  local subcmd, opts = exec.args_to_opts(args)
  if not opts then
    return -- args parse error
  end

  subcmd = subcmd or "status"

  if not commands[subcmd] then
    zio.error("'" .. subcmd .. "' is not a valid :Chez subcommand")
    return
  end

  commands[subcmd](opts)
end

function M.setup(opts)
  if opts.detect ~= false then
    detect.setup()
  end

  vim.api.nvim_create_user_command("Chez", chez_cmd, {
    desc = "Interact with Chez(moi)",
    nargs = "*",
    bang = true,
  })
end

return M
