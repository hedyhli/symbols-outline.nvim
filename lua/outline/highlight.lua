local M = {
  ns = {
    hover = vim.api.nvim_create_namespace('outline-current'),
    items = vim.api.nvim_create_namespace('outline-items-highlight'),
    vt = vim.api.nvim_create_namespace('outline-virt-text'),
  },
}

---Clear all highlights in buffer
---@param bufnr integer
function M.clear_all_ns(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    pcall(function() vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1) end)
  end
end

---Clear hover highlights in buffer
---@param bufnr integer
function M.clear_hovers(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, M.ns.hover, 0, -1)
  end
end

---Add single hover highlights
---@param bufnr integer
---@param nodes outline.FlatSymbol[]
function M.hovers(bufnr, nodes)
  for line, node in ipairs(nodes) do
    if node.hovered then
      -- stylua: ignore start
      vim.api.nvim_buf_add_highlight(
        bufnr, M.ns.hover, 'OutlineCurrent', line - 1, node.prefix_length, -1
      )
      -- stylua: ignore end
    end
  end
end

---Add list of highlights `hl` for outline items
---@param bufnr integer
---@param hl_list outline.HL[]
function M.items(bufnr, hl_list)
  for _, h in ipairs(hl_list) do
    -- stylua: ignore start
    vim.api.nvim_buf_add_highlight(
      bufnr, M.ns.items, h.name, h.line - 1, h.from, h.to
    )
    -- stylua: ignore end
  end
end

---Add details virtual text
---@param bufnr integer Outline buffer
---@param details string[] Virtual text to add
function M.details(bufnr, details)
  for index, detail in ipairs(details) do
    vim.api.nvim_buf_set_extmark(bufnr, M.ns.vt, index - 1, -1, {
      virt_text = { { detail, 'OutlineDetails' } },
      virt_text_pos = 'eol',
      hl_mode = 'combine',
    })
  end
end

---Add linenos virtual text
---@param bufnr integer Outline buffer
---@param linenos string[] Must already be padded
---@param hl_mode string Valid value for `buf_set_extmark` option `hl_mode`
function M.linenos(bufnr, linenos, hl_mode)
  -- TODO: Fix lineno not appearing if text in line is truncated on the right
  -- due to narrow window, after nvim fixes virt_text_hide.
  for index, lineno in ipairs(linenos) do
    vim.api.nvim_buf_set_extmark(bufnr, M.ns.vt, index - 1, -1, {
      virt_text = { { lineno, 'OutlineLineno' } },
      virt_text_pos = 'overlay',
      virt_text_win_col = 0,
      hl_mode = hl_mode,
    })
  end
end

---Create Outline highlights with default values if they don't already exist
function M.setup()
  local get_hl_by_name

  if _G._outline_nvim_has[9] then
    get_hl_by_name = function(name)
      local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
      return { fg = hl.fg, bg = hl.bg, ctermfg = hl.ctermfg, ctermbg = hl.ctermbg }
    end
  else
    get_hl_by_name = function(name)
      ---@diagnostic disable-next-line undefined-field
      local hlrgb = vim.api.nvim_get_hl_by_name(name, true)
      ---@diagnostic disable-next-line undefined-field
      local hl = vim.api.nvim_get_hl_by_name(name, false)
      return {
        fg = hlrgb.foreground,
        bg = hlrgb.background,
        ctermfg = hl.foreground,
        ctermbg = hl.background,
      }
    end
  end

  -- Setup the OutlineCurrent highlight group if it hasn't been done already by
  -- a theme or manually set
  if vim.fn.hlexists('OutlineCurrent') == 0 then
    local cline_hl = get_hl_by_name('CursorLine')
    local string_hl = get_hl_by_name('String')

    vim.api.nvim_set_hl(0, 'OutlineCurrent', {
      bg = cline_hl.bg,
      fg = string_hl.fg,
      ctermbg = cline_hl.ctermbg,
      ctermfg = string_hl.ctermfg,
    })
  end

  -- Only inherit fg for these highlights because we do not want the other
  -- stylings messing up the alignment, nor the background so that cursorline
  -- can look normal when on top of it. This can be customized by setting these
  -- highlights before outline.setup() is called, or using winhl.
  for name, link in pairs({ Guides = 'Comment', FoldMarker = 'Normal' }) do
    if vim.fn.hlexists('Outline' .. name) == 0 then
      local h = get_hl_by_name(link)
      vim.api.nvim_set_hl(0, 'Outline' .. name, { fg = h.fg, ctermfg = h.fg })
    end
  end

  for name, link in pairs({
    Details = 'Comment',
    Lineno = 'LineNr',
    JumpHighlight = 'Visual',
    HelpTip = 'Comment',
    StatusFt = 'Type',
    StatusProvider = 'Special',
    StatusError = 'ErrorMsg',
    KeymapHelpKey = 'Special',
    KeymapHelpDisabled = 'Comment',
  }) do
    if vim.fn.hlexists('Outline' .. name) == 0 then
      vim.api.nvim_set_hl(0, 'Outline' .. name, { link = link })
    end
  end
end

return M
