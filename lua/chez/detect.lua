local M = {}

local exec = require("chez.exec")

function M.run_detect(buf_id)
  buf_id = buf_id or 0
  if buf_id == 0 then
    buf_id = vim.api.nvim_get_current_buf()
  end

  local buf_file = vim.api.nvim_buf_get_name(buf_id)
  if buf_file == "" then return end

  local function exec_enter()
    vim.api.nvim_exec_autocmds("User", {
      pattern = "ChezEnter",
      modeline = false,
      -- TODO: add data here? the information would be redundant but convenient
    })
  end

  exec.exec_chezmoi({ "source-path", buf_file }, function(src_path)
    if not vim.api.nvim_buf_is_valid(buf_id) then return end
    if src_path then
      vim.b[buf_id].chezmoi_source = vim.trim(src_path)
      exec_enter()
    else
      vim.b[buf_id].chezmoi_source = nil
    end
  end, false)

  exec.exec_chezmoi({ "target-path", buf_file }, function(tgt_path)
    if not vim.api.nvim_buf_is_valid(buf_id) then return end
    if tgt_path then
      vim.b[buf_id].chezmoi_target = vim.trim(tgt_path)
      exec_enter()
    else
      vim.b[buf_id].chezmoi_target = nil
    end
  end, false)
end

function M.setup()
  vim.api.nvim_create_autocmd("BufEnter", {
    callback = function(ev)
      M.run_detect(ev.buf)
    end,
  })
end

---@param buf_id integer|nil
function M.unmanage(buf_id)
  buf_id = buf_id or 0
  vim.b[buf_id].chezmoi_source = nil
  vim.b[buf_id].chezmoi_target = nil
end

--- Get the target path of the current file, if it is managed by chezmoi.
---@param buf_id integer|nil
---@return string|nil
function M.get_target(buf_id)
  buf_id = buf_id or 0
  if vim.b[buf_id].chezmoi_target ~= nil then
    return vim.b[buf_id].chezmoi_target
  end
  if vim.b[buf_id].chezmoi_source ~= nil then
    return vim.api.nvim_buf_get_name(buf_id)
  end
  return nil
end

--- Get the source path of the current file, if it is managed by chezmoi.
---@param buf_id integer|nil
---@return string|nil
function M.get_source(buf_id)
  buf_id = buf_id or 0
  if vim.b[buf_id].chezmoi_source ~= nil then
    return vim.b[buf_id].chezmoi_source
  end
  if vim.b[buf_id].chezmoi_target ~= nil then
    return vim.api.nvim_buf_get_name(buf_id)
  end
  return nil
end

--- Whether the current file is a source, a target, or unmanaged.
---@param buf_id integer|nil
---@return "source"|"target"|nil
function M.buf_kind(buf_id)
  buf_id = buf_id or 0
  if vim.b[buf_id].chezmoi_target ~= nil then
    return "source"
  elseif vim.b[buf_id].chezmoi_source ~= nil then
    return "target"
  else
    return nil
  end
end

return M
