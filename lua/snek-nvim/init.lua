local completion_preview = require("snek-nvim.completion_preview")
local config = require("snek-nvim.config")
local commands = require("snek-nvim.commands")
local api = require("snek-nvim.api")

local M = {}

M.setup = function(args)
  config.setup(args)

  if config.disable_inline_completion then
    completion_preview.disable_inline_completion = true
  elseif not config.disable_keymaps then
    if config.keymaps.accept_suggestion ~= nil then
      vim.keymap.set(
        "i",
        config.keymaps.accept_suggestion,
        completion_preview.on_accept_suggestion,
        { noremap = true, silent = true }
      )
    end

    if config.keymaps.accept_word ~= nil then
      vim.keymap.set(
        "i",
        config.keymaps.accept_word,
        completion_preview.on_accept_suggestion_word,
        { noremap = true, silent = true }
      )
    end

    if config.keymaps.clear_suggestion ~= nil then
      vim.keymap.set(
        "i",
        config.keymaps.clear_suggestion,
        completion_preview.on_dispose_inlay,
        { noremap = true, silent = true }
      )
    end
  end

  commands.setup()
  api.start()
end

return M
