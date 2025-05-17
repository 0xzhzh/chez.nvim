local M = {}

local group = "chez.nvim"
local title = "chez.nvim"

local initialized = false
local function init_notify()
  if initialized then
    return
  end
  initialized = true

  pcall(function()
    local fidget = require("fidget")
    fidget.notification.set_config(group, {
      name = title,
      icon = "~",
    }, false)
  end)
end

---@type integer|nil
local buf_id
---@type integer|nil
local win_id

---@param opts table
---@return integer buf_id
---@return integer win_id
local function init_buf(opts)
  local footer = opts.footer or "chez.nvim"
  if not buf_id or not vim.api.nvim_buf_is_valid(buf_id) then
    buf_id = vim.api.nvim_create_buf(false, true) -- unlisted scratch buffer
    vim.api.nvim_set_option_value("filetype", "chez.nvim", { scope = "local", buf = buf_id })
    vim.keymap.set({ "n", "x" }, "q", "<cmd>quit<CR>", {
      desc = "Close chez.nvim window",
      buffer = buf_id,
    })
  end

  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    local ed_height, ed_width = vim.opt.lines:get(), vim.opt.columns:get()
    win_id = vim.api.nvim_open_win(buf_id, true, {
      relative = "editor",
      anchor = "NW",
      width = math.floor(ed_width / 2),
      col = math.floor(ed_width / 4),
      height = math.floor(ed_height / 2),
      row = math.floor(ed_height / 4),

      style = "minimal",
      border = "rounded",
      footer = " " .. footer .. " ",
      footer_pos = "right",
    })
  end
  return buf_id, win_id
end

---@param lines string[]
---@param title string|nil
function M.buffer(lines, title)
  local buf_id = init_buf({ footer = title })
  local buf_lines = {}
  for _, line in ipairs(lines) do
    for l in vim.gsplit(line, "\n", { plain = true, trimempty = false }) do
      table.insert(buf_lines, l)
    end
  end
  vim.api.nvim_set_option_value("modifiable", true, { scope = "local", buf = buf_id })
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, buf_lines)
  vim.api.nvim_set_option_value("modifiable", false, { scope = "local", buf = buf_id })
end

function M.error(msg)
  init_notify()
  vim.notify(msg, vim.log.levels.ERROR, {
    group = group, -- fidget
    title = title, -- nvim-notify
  })
end

function M.warn(msg)
  init_notify()
  vim.notify(msg, vim.log.levels.WARN, {
    group = group,
    title = title, -- nvim-notify
  })
end

function M.info(msg)
  init_notify()
  vim.notify(msg, vim.log.levels.INFO, {
    group = group,
    title = title, -- nvim-notify
  })
end

function M.debug(msg)
  init_notify()
  vim.notify(msg, vim.log.levels.DEBUG, {
    group = group,
    title = title, -- nvim-notify
  })
end

function M.with_confirm(prompt, action)
  if string.sub(prompt, #prompt, #prompt) ~= " " then
    prompt = prompt .. " "
  end
  vim.ui.select({ true, false }, {
    prompt = prompt,
    format_item = function(item)
      return item and "Yes" or "No"
    end,
  }, function(choice)
    if choice then action() end
  end)
end

return M
