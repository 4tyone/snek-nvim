local u = require("snek-nvim.util")
local config = require("snek-nvim.config")
local preview = require("snek-nvim.completion_preview")
local binary_locator = require("snek-nvim.lsp.binary_locator")
local log = require("snek-nvim.logger")

local loop = u.uv

---@class LspHandler
local LspHandler = {
  client_id = nil,
  augroup = nil,
  debounce_timer = nil,
  current_request_id = 0,
  cancel_current_request = nil, -- Function to cancel current request
}

LspHandler.DEBOUNCE_MS = 400

function LspHandler:start()
  if self.client_id and vim.lsp.get_client_by_id(self.client_id) then
    log:debug("Snek LSP is already running")
    return
  end

  local binary_path = binary_locator.get_binary_path()
  if not binary_path then
    log:error("Snek binary not found")
    return
  end

  -- Verify binary exists
  local stat = vim.loop.fs_stat(binary_path)
  if not stat then
    log:error("Snek binary not found at: " .. binary_path)
    return
  end

  local workspace_dir = vim.fn.getcwd()

  local client_id = vim.lsp.start_client({
    name = "snek",
    cmd = { binary_path, "--workspace-dir", workspace_dir },
    root_dir = workspace_dir,
    capabilities = vim.lsp.protocol.make_client_capabilities(),
    settings = {
      snek = {
        apiKey = config.api_key or "",
      },
    },
    on_init = function(client)
      log:trace("Snek LSP initialized")
    end,
    on_exit = function(code, signal)
      log:debug(string.format("Snek LSP exited with code %d, signal %d", code, signal))
      self.client_id = nil
    end,
    on_error = function(code, err)
      log:error(string.format("Snek LSP error: code=%s, err=%s", tostring(code), tostring(err)))
    end,
    handlers = {
      ["workspace/configuration"] = function(err, result, ctx)
        local response = {}
        for _, item in ipairs(result.items or {}) do
          if item.section == "snek.apiKey" then
            table.insert(response, config.api_key or "")
          else
            table.insert(response, vim.NIL)
          end
        end
        return response
      end,
    },
  })

  if client_id then
    self.client_id = client_id
    self:setup_autocmds()
    -- Attach to current buffer after autocmds are set up
    vim.schedule(function()
      local bufnr = vim.api.nvim_get_current_buf()
      if vim.api.nvim_buf_is_valid(bufnr) then
        local attached = vim.lsp.buf_attach_client(bufnr, client_id)
        log:debug("Attached to buffer " .. bufnr .. ": " .. tostring(attached))
      end
    end)
    log:trace("Snek LSP started with client_id: " .. client_id)
  else
    log:error("Failed to start Snek LSP")
  end
end

function LspHandler:is_running()
  if not self.client_id then
    return false
  end
  return vim.lsp.get_client_by_id(self.client_id) ~= nil
end

function LspHandler:stop()
  self:teardown_autocmds()
  if self.client_id then
    local client = vim.lsp.get_client_by_id(self.client_id)
    if client then
      client.stop()
    end
    self.client_id = nil
    log:trace("Snek LSP stopped")
  end
end

function LspHandler:setup_autocmds()
  self.augroup = vim.api.nvim_create_augroup("snek", { clear = true })

  -- Attach LSP to new buffers and notify on buffer switch
  vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost" }, {
    group = self.augroup,
    callback = function(event)
      if self.client_id and vim.api.nvim_buf_is_valid(event.buf) then
        -- Only attach to file buffers
        local bufname = vim.api.nvim_buf_get_name(event.buf)
        if bufname == "" then
          return
        end

        local client = vim.lsp.get_client_by_id(self.client_id)
        if not client then
          return
        end

        local clients = vim.lsp.get_clients({ bufnr = event.buf, name = "snek" })
        if #clients == 0 then
          local attached = vim.lsp.buf_attach_client(event.buf, self.client_id)
          log:debug("BufEnter attach to " .. bufname .. ": " .. tostring(attached))
        else
          -- Buffer already attached, but Snek LSP only tracks one doc
          -- Re-notify the LSP about this document becoming active
          local uri = vim.uri_from_fname(bufname)
          local text = table.concat(vim.api.nvim_buf_get_lines(event.buf, 0, -1, false), "\n")
          local filetype = vim.bo[event.buf].filetype or ""

          client.notify("textDocument/didOpen", {
            textDocument = {
              uri = uri,
              languageId = filetype,
              version = 1,
              text = text,
            },
          })
          log:debug("Re-notified didOpen for: " .. bufname)
        end
      end
    end,
  })

  -- Request completion on text changes in insert mode
  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
    group = self.augroup,
    callback = function(event)
      if config.ignore_filetypes[vim.bo.ft] or vim.tbl_contains(config.ignore_filetypes, vim.bo.filetype) then
        return
      end
      -- Clear existing suggestion before requesting new one
      preview:dispose_inlay()
      self:request_completion()
    end,
  })

  -- Clear ghost text when cursor moves in insert mode
  vim.api.nvim_create_autocmd({ "CursorMovedI" }, {
    group = self.augroup,
    callback = function()
      -- Dispose if cursor moved without text change (e.g., arrow keys)
      preview:dispose_inlay()
    end,
  })

  -- Clear ghost text when leaving insert mode
  vim.api.nvim_create_autocmd({ "InsertLeave" }, {
    group = self.augroup,
    callback = function()
      preview:dispose_inlay()
    end,
  })

  -- Setup custom highlight if configured
  if config.color and config.color.suggestion_color and config.color.cterm then
    vim.api.nvim_create_autocmd({ "VimEnter", "ColorScheme" }, {
      group = self.augroup,
      pattern = "*",
      callback = function()
        vim.api.nvim_set_hl(0, "SnekSuggestion", {
          fg = config.color.suggestion_color,
          ctermfg = config.color.cterm,
        })
        preview.suggestion_group = "SnekSuggestion"
      end,
    })
  end
end

function LspHandler:teardown_autocmds()
  if self.augroup then
    vim.api.nvim_del_augroup_by_id(self.augroup)
    self.augroup = nil
  end
end

function LspHandler:request_completion()
  -- Cancel any pending debounce timer
  if self.debounce_timer then
    self.debounce_timer:stop()
    self.debounce_timer:close()
    self.debounce_timer = nil
  end

  -- Cancel any in-flight request
  if self.cancel_current_request then
    self.cancel_current_request()
    self.cancel_current_request = nil
  end

  -- Debounce the request
  self.debounce_timer = loop.new_timer()
  self.debounce_timer:start(self.DEBOUNCE_MS, 0, vim.schedule_wrap(function()
    self:do_request_completion()
    if self.debounce_timer then
      self.debounce_timer:stop()
      self.debounce_timer:close()
      self.debounce_timer = nil
    end
  end))
end

function LspHandler:do_request_completion()
  if not self:is_running() then
    return
  end

  local client = vim.lsp.get_client_by_id(self.client_id)
  if not client then
    return
  end

  local buffer = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local file_path = vim.api.nvim_buf_get_name(buffer)

  if file_path == "" then
    return
  end

  local text_split = u.get_text_before_after_cursor(cursor)
  if not text_split.text_before_cursor then
    return
  end

  -- Increment request ID for this request
  self.current_request_id = self.current_request_id + 1
  local request_id = self.current_request_id

  local uri = vim.uri_from_fname(file_path)

  local params = {
    text_document = {
      uri = uri,
    },
    position = {
      line = cursor[1] - 1,
      character = cursor[2],
    },
  }

  local success, req_id = client.request("snek/inline", params, function(err, result)
    -- Ignore response if this request was superseded
    if request_id ~= self.current_request_id then
      return
    end

    self.cancel_current_request = nil

    if err then
      log:debug("Completion error: " .. vim.inspect(err))
      return
    end

    if not result or not result.completion or result.completion == "" then
      preview:dispose_inlay()
      return
    end

    -- Verify cursor hasn't moved
    local current_cursor = vim.api.nvim_win_get_cursor(0)
    if current_cursor[1] ~= cursor[1] or current_cursor[2] ~= cursor[2] then
      return
    end

    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buffer) then
        local current_text_split = u.get_text_before_after_cursor(current_cursor)
        preview:render_with_inlay(
          buffer,
          0,
          result.completion,
          current_text_split.text_after_cursor or "",
          current_text_split.text_before_cursor or ""
        )
      end
    end)
  end, buffer)

  -- Store cancel function
  if success and req_id then
    self.cancel_current_request = function()
      client.cancel_request(req_id)
    end
  end
end

return LspHandler
