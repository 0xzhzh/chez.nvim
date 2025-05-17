local M = {}

local exec = require("chez.exec")
local detect = require("chez.detect")
local zio = require("chez.io")

--- Close any windows and buffers associated with filename.
---
---@param filename string
local function close_buf_and_wins(filename)
  local buf_id = nil
  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    local win_buf_id = vim.api.nvim_win_get_buf(win_id)
    local win_buf_name = vim.api.nvim_buf_get_name(win_buf_id)
    if win_buf_name == filename then
      -- This window holds the buffer that we want to delete.
      -- First, set the window to display any other buffer so it doesn't get
      -- closed when we unload the buffer
      buf_id = win_buf_id

      local next_buf = vim.api.nvim_create_buf(false, false)
      if next_buf ~= 0 then
        vim.api.nvim_win_set_buf(win_id, next_buf)
      end
    end
  end

  if not buf_id then
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if filename == vim.api.nvim_buf_get_name(buf) then
        buf_id = buf
        break
      end
    end
  end

  if buf_id then
    vim.api.nvim_buf_delete(buf_id, { force = true })
  end
end

---@param alias_name string name of alias
---@param alias_target string target of alias
local function make_alias(alias_name, alias_target)
  M[alias_name] = M[alias_target]
end

function M.status(opts, name)
  exec.exec_chezmoi({ "status" }, function(output)
    -- TODO: make this better. Aspire to fugitive status.
    zio.buffer({ output })
  end)
end

make_alias("st", "status")

function M.help(opts, name)
  if opts[1] then
    if M[opts[1]] then
      vim.cmd(":help :Chez-" .. opts[1])
    else
      error(":Chez subcommand does not exist: " .. tostring(opts[1]))
    end
  else
    vim.cmd(":help chez")
  end
end

make_alias(":h", "help")
make_alias(":help", "help")

--- Edit the source buffer of the current buffer.
--- Returns the kind of the current (now previous) buffer, or nil if unmanaged.
---@return "source"|"target"|nil previous_buffer_kind
function M.source(opts, name)
  local kind = detect.buf_kind()
  if kind == "source" then
    if not opts.silent then
      zio.warn("already editing source")
    end
  elseif kind == "target" then
    vim.cmd(":edit " .. detect.get_source())
    if not opts.silent then
      zio.info("editing source")
    end
  else
    if not opts.silent then
      zio.error("current buffer is unmanaged")
    end
  end
  return kind
end

make_alias("src", "source")

--- Edit the target buffer of the current buffer.
--- Returns the kind of the current (now previous) buffer, or nil if unmanaged.
---@return "source"|"target"|nil previous_buffer_kind
function M.target(opts, name)
  local kind = detect.buf_kind()
  if kind == "source" then
    vim.cmd(":edit " .. detect.get_target())
    if not opts.silent then
      zio.info("editing target")
    end
  elseif kind == "target" then
    if not opts.silent then
      zio.warn("already editing target")
    end
  else
    if not opts.silent then
      zio.error("current buffer is unmanaged")
    end
  end
  return kind
end

make_alias("tgt", "target")

function M.alternate(opts, name)
  local kind = detect.buf_kind()
  if kind == "source" then
    M.target(opts, name)
  elseif kind == "target" then
    M.source(opts, name)
  else
    if not opts.silent then
      zio.error("current buffer is unmanaged")
    end
  end
end

make_alias("alt", "alternate")

function M.add(opts, name)
  -- TODO: confirmation
  -- TODO: save
  local cmd_opts = {
    force = true,
    follow = opts.follow,
  }

  local new_add = false
  local buf_id = 0
  local target = detect.get_target()
  if not target then
    target, new_add = vim.api.nvim_buf_get_name(buf_id), true
  end
  if target == "" then
    zio.error("current buffer is unsaved and cannot be added")
    return
  end
  cmd_opts[1] = target

  local args = exec.opts_to_args("add", cmd_opts)
  if not args then return end
  exec.exec_chezmoi(args, function()
    if new_add then
      detect.run_detect(buf_id)
      zio.info("added new target: " .. target)
    else
      zio.info("added target: " .. target)
    end
  end)
end

make_alias("manage", "add")

function M.re_add(opts, name)
  -- TODO: confirmation
  -- TODO: save
  local cmd_opts = {
    force = true,
  }

  local target = detect.get_target()
  if not target or target == "" then
    zio.error("current buffer is unmanaged and cannot be re-added")
    return
  end
  cmd_opts[1] = target

  local args = exec.opts_to_args("re-add", cmd_opts)
  if not args then return end
  exec.exec_chezmoi(args, function()
    zio.info("re-added target: " .. target)
  end)
end

make_alias("re-add", "re_add")

function M.apply(opts, name)
  -- TODO: confirmation
  -- TODO: save
  local cmd_opts = {
    force = true,
  }

  local target = detect.get_target()
  if not target or target == "" then
    zio.error("current buffer is unmanaged and cannot be applied")
    return
  end
  cmd_opts[1] = target

  local args = exec.opts_to_args("apply", cmd_opts)
  if args then
    exec.exec_chezmoi(args, function()
      for _, file in ipairs(cmd_opts) do
        zio.info("applied to target: " .. file)
      end
    end)
  end
end

function M.pull(opts, name)
  local kind = detect.buf_kind()
  if kind == "source" then
    M.re_add(opts, name)
  elseif kind == "target" then
    M.apply(opts, name)
  else
    zio.error("current buffer is unmanaged and cannot be pulled")
  end
end

function M.push(opts, name)
  local kind = detect.buf_kind()
  if kind == "source" then
    M.apply(opts, name)
  elseif kind == "target" then
    M.re_add(opts, name)
  else
    zio.error("current buffer is unmanaged and cannot be pushed")
  end
end

function M.forget(opts, name)
  local target, source = detect.get_target(), detect.get_source()
  if not target or not source then
    zio.error("current buffer is unmanaged and cannot be forgotten")
    return
  end


  local function do_forget()
    M.target({ silent = true }, name)
    detect.unmanage()
    close_buf_and_wins(source)
    local args = exec.opts_to_args("forget", { target, force = true })
    if not args then return end
    exec.exec_chezmoi(args, function()
      zio.info("forgotten: " .. target)
    end)
  end

  if opts.force then
    do_forget()
  else
    zio.with_confirm("chezmoi: are you sure you want to forget '" .. target .. "'?", do_forget)
  end
end

make_alias("unmanage", "forget")
make_alias("forgor", "forget")

function M.destroy(opts, name)
  local target, source = detect.get_target(), detect.get_source()
  if not target or not source then
    zio.error("current buffer is unmanaged and cannot be destroyed")
    return
  end

  local function do_destroy()
    close_buf_and_wins(target)
    close_buf_and_wins(source)
    local args = exec.opts_to_args("destroy", { target, force = true })
    if not args then return end
    exec.exec_chezmoi(args, function()
      zio.info("destroyed: " .. target)
    end)
  end

  if opts.force then
    do_destroy()
  else
    zio.with_confirm("chezmoi: are you sure you want to destroy '" .. target .. "'?", do_destroy)
  end
end

function M.diff(opts, name)
  -- TODO: open this in a new tab

  local target = detect.get_target()
  if target == nil then
    zio.error("cannot diff unmanaged buffer")
    return
  end

  local win_id, cursor = vim.api.nvim_get_current_win(), vim.api.nvim_win_get_cursor(0)
  local old_kind = M.source({ silent = true }, name)

  vim.cmd("vert diffsplit " .. target)
  -- cursor now in the new window, the target
  if old_kind == "source" then
    -- restore cursor to original position, the source buffer
    vim.api.nvim_win_set_cursor(win_id, cursor)
  else
    -- cursor originally in target buffer (now the new window), needn't restore
  end
end

-- patch all APIs to make them accept nil as options
local M_opts = {}
for k, v in pairs(M) do
  if type(k) == "string" and type(v) == "function" then
    M_opts[k] = function(opts, name) v(opts or {}, name or k) end
  else
    M_opts[k] = v
  end
end

return M_opts
