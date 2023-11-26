local config = require('outline.config')
local jsx = require('outline.providers.jsx')
local lsp_utils = require('outline.utils.lsp')

local M = {
  name = 'lsp',
  ---@type vim.lsp.client
  client = nil,
}

function M.get_status()
  if not M.client then
    return { 'No clients' }
  end
  return { 'client: ' .. M.client.name }
end

function M.hover_info(bufnr, params, on_info)
  local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
  local use_client

  for _, client in ipairs(clients) do
    if config.is_client_blacklisted(client) then
      goto continue
    else
      if client.server_capabilities.hoverProvider then
        use_client = client
        M.client = client
        break
      end
    end
    ::continue::
  end

  if not use_client then
    on_info(nil, {
      contents = {
        kind = 'markdown',
        content = { 'No extra information availaible' },
      },
    })
    return
  end

  use_client.request('textDocument/hover', params, on_info, bufnr)
end

---@return boolean
function M.supports_buffer(bufnr)
  local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
  local ret = false

  for _, client in ipairs(clients) do
    if config.is_client_blacklisted(client) then
      goto continue
    else
      if client.server_capabilities.documentSymbolProvider then
        M.client = client
        ret = true
        break
      end
    end
    ::continue::
  end

  return ret
end

---@param response outline.ProviderSymbol[]
---@return outline.ProviderSymbol[]
local function postprocess_symbols(response)
  local symbols = lsp_utils.flatten_response(response)

  local jsx_symbols = jsx.get_symbols()

  if #jsx_symbols > 0 then
    return lsp_utils.merge_symbols(symbols, jsx_symbols)
  else
    return symbols
  end
end

---@param on_symbols fun(symbols?:outline.ProviderSymbol[], opts?:table)
---@param opts table
function M.request_symbols(on_symbols, opts)
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(),
  }
  vim.lsp.buf_request_all(0, 'textDocument/documentSymbol', params, function(response)
    response = postprocess_symbols(response)
    on_symbols(response, opts)
  end)
end

-- No good way to update outline when LSP action complete for now

---@param sidebar outline.Sidebar
function M.code_actions(sidebar)
  sidebar:wrap_goto_location(function()
    vim.lsp.buf.code_action()
  end)
end

---@param sidebar outline.Sidebar
function M.rename_symbol(sidebar)
  sidebar:wrap_goto_location(function()
    vim.lsp.buf.rename()
  end)
end

return M
