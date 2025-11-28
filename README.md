# snek-nvim

Neovim plugin for Snek AI-powered inline code completions.

## Installation

Using a plugin manager, run the `.setup({})` function in your Neovim configuration file.

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
require("lazy").setup({
    {
      "your-username/snek-nvim",
      config = function()
        require("snek-nvim").setup({
          api_key = "your-api-key",
        })
      end,
    },
}, {})
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "your-username/snek-nvim",
  config = function()
    require("snek-nvim").setup({
      api_key = "your-api-key",
    })
  end,
}
```

## Configuration

```lua
require("snek-nvim").setup({
  -- Required for AI completions
  api_key = "your-api-key",

  -- Keymaps (defaults shown)
  keymaps = {
    accept_suggestion = "<Tab>",     -- Accept the full suggestion
    clear_suggestion = "<C-]>",      -- Dismiss the suggestion
    accept_word = "<C-j>",           -- Accept only the next word
  },

  -- Optional settings
  ignore_filetypes = { cpp = true }, -- Filetypes to disable completions
  disable_inline_completion = false, -- Disable ghost text suggestions
  disable_keymaps = false,           -- Don't set up default keymaps
  log_level = "info",                -- "off", "trace", "debug", "info", "warn", "error"

  -- Custom suggestion color (optional)
  color = {
    suggestion_color = "#808080",
    cterm = 244,
  },

  -- Condition to disable snek (return true to disable)
  condition = function()
    return false
  end,
})
```

### Disabling snek-nvim conditionally

You can disable snek-nvim conditionally by setting the `condition` function to return `true`.

```lua
require("snek-nvim").setup({
  api_key = "your-api-key",
  condition = function()
    return string.match(vim.fn.expand("%:t"), "secret")
  end,
})
```

This will disable snek-nvim for files with "secret" in the name.

### Programmatically checking and accepting suggestions

You can check if there is an active suggestion and accept it programmatically:

```lua
require("snek-nvim").setup({
  api_key = "your-api-key",
  disable_keymaps = true,
})

local suggestion = require('snek-nvim.completion_preview')

-- In your keymap or function:
if suggestion.has_suggestion() then
  suggestion.on_accept_suggestion()
end
```

## Commands

| Command | Description |
|---------|-------------|
| `:SnekStart` | Start the Snek LSP |
| `:SnekStop` | Stop the Snek LSP |
| `:SnekRestart` | Restart the Snek LSP |
| `:SnekToggle` | Toggle the Snek LSP on/off |
| `:SnekStatus` | Show whether Snek is running |
| `:SnekShowLog` | Open the log file |
| `:SnekClearLog` | Clear the log file |

## Lua API

The `snek-nvim.api` module provides the following functions:

```lua
local api = require("snek-nvim.api")

api.start()      -- Start snek-nvim
api.stop()       -- Stop snek-nvim
api.restart()    -- Restart snek-nvim
api.toggle()     -- Toggle snek-nvim
api.is_running() -- Returns true if snek-nvim is running
api.show_log()   -- Show logs
api.clear_log()  -- Clear logs
```

## Binary Distribution

The plugin includes pre-built binaries for macOS:

```
bin/
├── macos-arm64/snek    # Apple Silicon (M1/M2/M3)
└── macos-x86_64/snek   # Intel Macs
```

## How It Works

1. The plugin starts the Snek LSP server when you call `setup()`
2. The LSP handles document synchronization automatically
3. As you type, it sends `snek/inline` requests to get AI completions
4. Completions appear as ghost text (virtual text) at your cursor
5. Press `<Tab>` to accept the suggestion

## Supported Languages

- Rust
- Python
- JavaScript
- TypeScript
- Java
- Go
- C/C++
- Lua

## License

MIT
