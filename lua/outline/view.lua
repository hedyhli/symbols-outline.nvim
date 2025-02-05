local cfg = require('outline.config')
local highlight = require('outline.highlight')

---@class outline.View
local View = {}

---@class outline.View
---@field buf integer
---@field win integer

function View:new()
  return setmetatable({ buf = nil, win = nil }, { __index = View })
end

---Creates the outline window and sets it up
---@param split_command string A valid split command that is to be executed in order to create the view.
function View:setup_view(split_command)
  -- create a scratch unlisted buffer
  self.buf = vim.api.nvim_create_buf(false, true)

  -- set filetype
  vim.api.nvim_buf_set_option(self.buf, 'filetype', 'Outline')

  -- delete buffer when window is closed / buffer is hidden
  vim.api.nvim_buf_set_option(self.buf, 'bufhidden', 'delete')

  -- create a split
  vim.cmd(split_command)

  -- get current (outline) window and attach our buffer to it
  self.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(self.win, self.buf)

  -- resize if split_command not specify width like "25vsplit"
  if split_command:match('%d+') == nil then
    -- resize to a % of the current window size
    vim.cmd('vertical resize ' .. cfg.o.outline_window.width)
  end

  -- window stuff
  vim.api.nvim_win_set_option(self.win, 'spell', false)
  vim.api.nvim_win_set_option(self.win, 'signcolumn', 'no')
  vim.api.nvim_win_set_option(self.win, 'foldcolumn', '0')
  vim.api.nvim_win_set_option(self.win, 'number', false)
  vim.api.nvim_win_set_option(self.win, 'relativenumber', false)
  vim.api.nvim_win_set_option(self.win, 'winfixwidth', true)
  vim.api.nvim_win_set_option(self.win, 'list', false)
  vim.api.nvim_win_set_option(self.win, 'wrap', cfg.o.outline_window.wrap)
  vim.api.nvim_win_set_option(self.win, 'winhl', cfg.o.outline_window.winhl)
  vim.api.nvim_win_set_option(self.win, 'linebreak', true) -- only has effect when wrap=true
  vim.api.nvim_win_set_option(self.win, 'breakindent', true) -- only has effect when wrap=true
  --  Would be nice to use guides.markers.vertical as part of showbreak to keep
  --  continuity of the tree UI, but there's currently no way to style the
  --  color, apart from globally overriding hl-NonText, which will potentially
  --  mess with other theme/user settings. So just use empty spaces for now.
  vim.api.nvim_win_set_option(self.win, 'showbreak', '      ') -- only has effect when wrap=true.
  -- buffer stuff
  local tab = vim.api.nvim_get_current_tabpage()
  vim.api.nvim_buf_set_name(self.buf, 'OUTLINE_' .. tostring(tab))
  vim.api.nvim_buf_set_option(self.buf, 'modifiable', false)

  if cfg.o.outline_window.show_numbers or cfg.o.outline_window.show_relative_numbers then
    vim.api.nvim_win_set_option(self.win, 'nu', true)
  end

  if cfg.o.outline_window.show_relative_numbers then
    vim.api.nvim_win_set_option(self.win, 'rnu', true)
  end

  local cl = cfg.o.outline_window.show_cursorline
  if cl == true or cl == 'focus_in_outline' then
    vim.api.nvim_win_set_option(self.win, 'cursorline', true)
  end
end

---Close view window and remove winnr/bufnr fields
function View:close()
  if self.win then
    local windows = vim.api.nvim_list_wins()
    local win_count = #windows
    if win_count == 1 then
      vim.api.nvim_command('q')
    else
      vim.api.nvim_win_close(self.win, true)
      self.win = nil
      self.buf = nil
    end
  end
end

---Return whether view has valid buf and win numbers
function View:is_open()
  return self.win
    and self.buf
    and vim.api.nvim_buf_is_valid(self.buf)
    and vim.api.nvim_win_is_valid(self.win)
end

---Replace all lines in buffer with given new `lines`
---@param lines string[]
function View:rewrite_lines(lines)
  if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
    vim.api.nvim_buf_set_option(self.buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(self.buf, 'modifiable', false)
  end
end

function View:clear_all_ns()
  if self.buf then
    highlight.clear_all_ns(self.buf)
  end
end

---Ensure all existing highlights are already cleared before calling!
---@param hl outline.HL[]
---@param nodes outline.FlatSymbol[]
---@param details string[]
---@param linenos string[]
function View:add_hl_and_ns(hl, nodes, details, linenos)
  highlight.items(self.buf, hl)
  if cfg.o.outline_items.highlight_hovered_item then
    highlight.hovers(self.buf, nodes)
  end
  if cfg.o.outline_items.show_symbol_details then
    highlight.details(self.buf, details)
  end

  -- Note on hl_mode:
  -- When hide_cursor + cursorline enabled, we want the lineno to also take on
  -- the cursorline background so wherever the cursor is, it appears blended.
  -- We want 'replace' even for `hide_cursor=false cursorline=true` because
  -- vim's native line numbers do not get highlighted by cursorline.
  if cfg.o.outline_items.show_symbol_lineno then
    -- stylua: ignore start
    highlight.linenos(
      self.buf, linenos,
      (cfg.o.outline_window.hide_cursor and 'combine') or 'replace'
    )
    -- stylua: ignore end
  end
end

return View
