local M = {}

local zio = require("chez.io")

---@param args string[]
---@return string|nil
---@return table|nil
function M.args_to_opts(args)
  ---@type string|nil
  local subcmd = nil
  ---@type table<string, any>
  local opts = {}

  local npos, err = 0, false
  for _, arg in ipairs(args) do
    if string.sub(arg, 1, 2) == "--" then
      -- named flag, e.g., --key=val or --key
      local key, val
      local eq = string.find(arg, "=")
      if eq then -- case: --key=val
        key, val = string.sub(arg, 3, eq - 1), string.sub(arg, eq + 1)
      else       -- case: --key
        key, val = string.sub(arg, 3), true
      end
      if #key == 0 then
        zio.error("could not deserialize argument: '" .. arg .. "'")
        err = true
      else
        opts[key] = val
      end
    elseif string.sub(arg, 1) == "-" then
      -- short flag, e.g., -r (short for --recursive)
      --                or -osome/path (short for --output=some/path)
      opts[arg] = true
    elseif subcmd == nil then
      -- This is the first arg we encountered, so it's the subcmd
      subcmd = arg
    else
      -- positional argument, i.e., anything else
      npos = npos + 1
      opts[npos] = arg
    end
  end

  if err then
    return nil, nil
  else
    return subcmd, opts
  end
end

---@param subcmd string
---@param opts table
---@return string[]|nil
function M.opts_to_args(subcmd, opts)
  opts = opts or {}
  local args, err = { subcmd }, false
  for _, pos_arg in ipairs(opts) do
    table.insert(args, pos_arg)
  end
  for k, v in pairs(opts) do
    if type(k) == "string" and string.sub(k, 1, 1) == "-" then
      table.insert(args, string.sub(k, 1, 2))
      local param = string.sub(k, 3)
      if #param > 0 then table.insert(args, param) end
    elseif type(k) == "string" then
      table.insert(args, "--" .. k)
      if v ~= true then
        table.insert(args, tostring(v))
      end
    elseif type(k) == "number" then
      -- skip positional arguments
    else
      err = true
      zio.error("could not serialize key: " .. tostring(k))
    end
  end
  if err then return nil else return args end
end

--- Default error handler for exec_chezmoi
---@param args string[]  args given to chezmoi
---@param code integer   exit code
---@param out string|nil stdout contents
---@param err string|nil stderr contents
local function cz_err_handler(args, code, out, err)
  local lines = {
    string.format("chezmoi exited with non-zero code: %d", code),
    "args: " .. table.concat(args, " "),
  }
  if out and #out > 0 then
    table.insert(lines, "(stdout)")
    table.insert(lines, out)
  end
  if err and #err > 0 then
    table.insert(lines, "(stderr)")
    table.insert(lines, err)
  end
  zio.buffer(lines)
end

--- Execute chezmoi command with given args and callbacks
---@param args string[]
---@param handler fun(out:string|nil, err:string|nil)|false|nil
---@param err_handler fun(code:integer, out:string|nil, err:string|nil)|false|nil
function M.exec_chezmoi(args, handler, err_handler)
  local stdout, stderr = vim.loop.new_pipe(), vim.loop.new_pipe()
  local out, err = {}, {}
  local handle
  handle = vim.loop.spawn("chezmoi", {
    args = args,
    stdio = { nil, stdout, stderr },
    hide = true,
  }, function(code, signal)
    vim.loop.close(handle)
    vim.loop.shutdown(stdout)
    vim.loop.shutdown(stderr)

    vim.schedule(function()
      ---@type string|nil, string|nil
      local outs, errs
      if #out > 0 then outs = table.concat(out) end
      if #err > 0 then errs = table.concat(err) end

      if signal ~= 0 then
        zio.error("interrupted by signal: " .. tostring(signal))
      elseif code ~= 0 then
        if err_handler then
          err_handler(code, outs, errs)
        elseif err_handler == false then
          -- do nothing
        else
          cz_err_handler(args, code, outs, errs)
        end
      elseif handler then
        handler(outs, errs)
      end
    end)
  end)

  vim.loop.read_start(stdout, function(errs, data)
    if not errs and data then table.insert(out, data) end
  end)
  vim.loop.read_start(stderr, function(errs, data)
    if not errs and data then table.insert(err, data) end
  end)
end

return M
