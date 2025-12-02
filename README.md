# 🐍 snek-nvim

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-green)](https://neovim.io/)

**Lightning-fast AI code completions for Neovim, powered by Cerebras**

Open-source inline code completions that understand your project context. Built on the [Snek LSP](https://github.com/yourusername/snek-lsp).

---

## ✨ Features

- ⚡ **Blazing Fast** - Powered by Cerebras (1800+ tokens/sec, sub-100ms latency)
- 🎯 **Context-Aware** - Uses markdown files and code snippets for intelligent suggestions
- 👻 **Ghost Text** - Non-intrusive inline completions
- 🎨 **Customizable** - Keymaps, colors, and behavior
- 🔌 **LSP-Based** - Integrates seamlessly with Neovim's LSP ecosystem
- 🆓 **100% Open Source** - MIT licensed, no telemetry

## 🚀 Why Cerebras?

Snek uses **Cerebras exclusively** for the best possible user experience:

- **1,800+ tokens/second** - 10x faster than traditional GPU inference
- **Sub-100ms latency** - Completions appear instantly as you type
- **Best UX** - No laggy, stuttering suggestions

> **Note:** You'll need a Cerebras API key (free tier available at [cloud.cerebras.ai](https://cloud.cerebras.ai/))

## 📦 Installation

### Prerequisites

- Neovim 0.9+
- A [Cerebras API key](https://cloud.cerebras.ai/) (free tier available!)

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/snek-nvim",
  config = function()
    require("snek-nvim").setup({
      api_key = "your-cerebras-api-key",  -- Get from https://cloud.cerebras.ai
      model = "qwen-3-235b-a22b-instruct-2507",  -- Optional, this is the default
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "yourusername/snek-nvim",
  config = function()
    require("snek-nvim").setup({
      api_key = "your-cerebras-api-key",
      model = "qwen-3-235b-a22b-instruct-2507",
    })
  end,
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'yourusername/snek-nvim'

" In your init.vim or init.lua:
lua << EOF
require("snek-nvim").setup({
  api_key = "your-cerebras-api-key",
  model = "qwen-3-235b-a22b-instruct-2507",
})
EOF
```

## ⚙️ Configuration

### Full Configuration Example

```lua
require("snek-nvim").setup({
  -- Required: Your Cerebras API key
  api_key = "your-cerebras-api-key",

  -- Optional: Model to use (default shown)
  model = "qwen-3-235b-a22b-instruct-2507",

  -- Available models:
  -- - "qwen-3-235b-a22b-instruct-2507" (recommended - best quality/speed balance)
  -- - "llama3.1-8b" (fastest)
  -- - "llama3.1-70b" (good quality)
  -- - "llama-3.3-70b" (best quality, slowest)

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

### Environment Variables (Alternative)

Instead of hardcoding your API key, you can use environment variables:

```lua
require("snek-nvim").setup({
  api_key = vim.env.SNEK_API_KEY,  -- Set SNEK_API_KEY in your shell
  model = "qwen-3-235b-a22b-instruct-2507",
})
```

Add to your `.bashrc` or `.zshrc`:
```bash
export SNEK_API_KEY="your-cerebras-api-key"
```

## 🎯 How It Works

### 1. **Project Context**

Snek creates a `.snek/` directory in your project root:

```
your-project/
├── .snek/
│   ├── active.json            # Current session
│   └── sessions/
│       └── {session-id}/
│           ├── context/       # 📝 Markdown context files
│           │   ├── architecture.md
│           │   └── conventions.md
│           └── code_snippets.json  # Referenced code
```

### 2. **Add Context Files**

Create markdown files in `.snek/sessions/{id}/context/` to guide completions:

**Example: conventions.md**
```markdown
# Coding Conventions

- Use snake_case for variables
- All functions must have docstrings
- Prefer async/await over callbacks
```

### 3. **Get Intelligent Completions**

As you type, Snek uses your context to provide smart suggestions:
- Press `<Tab>` to accept
- Press `<C-]>` to dismiss
- Press `<C-j>` to accept only the next word

## 📝 Commands

| Command | Description |
|---------|-------------|
| `:SnekStart` | Start the Snek LSP server |
| `:SnekStop` | Stop the Snek LSP server |
| `:SnekRestart` | Restart the Snek LSP server |
| `:SnekToggle` | Toggle the Snek LSP on/off |
| `:SnekStatus` | Show whether Snek is running |
| `:SnekShowLog` | Open the log file |
| `:SnekClearLog` | Clear the log file |

## 🔌 Lua API

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

### Programmatic Suggestion Handling

```lua
require("snek-nvim").setup({
  api_key = "your-api-key",
  disable_keymaps = true,  -- Use your own keymaps
})

local suggestion = require('snek-nvim.completion_preview')

-- Custom keymap:
vim.keymap.set('i', '<C-Space>', function()
  if suggestion.has_suggestion() then
    suggestion.on_accept_suggestion()
  end
end, { desc = "Accept Snek suggestion" })
```

## 🎨 Advanced Usage

### Disable for Specific Files

```lua
require("snek-nvim").setup({
  api_key = "your-api-key",
  condition = function()
    -- Disable for files with "secret" in the name
    return string.match(vim.fn.expand("%:t"), "secret") ~= nil
  end,
})
```

### Disable for Specific Filetypes

```lua
require("snek-nvim").setup({
  api_key = "your-api-key",
  ignore_filetypes = {
    markdown = true,
    text = true,
  },
})
```

### Custom Keymaps

```lua
require("snek-nvim").setup({
  api_key = "your-api-key",
  keymaps = {
    accept_suggestion = "<C-y>",   -- Use Ctrl+y instead of Tab
    clear_suggestion = "<Esc>",     -- Use Escape to dismiss
    accept_word = "<C-w>",          -- Use Ctrl+w for word-by-word
  },
})
```

## 🛠️ Binary Distribution

The plugin includes pre-built Snek LSP binaries for macOS:

```
bin/
├── macos-arm64/snek    # Apple Silicon (M1/M2/M3/M4)
└── macos-x86_64/snek   # Intel Macs
```

The correct binary is automatically selected based on your system architecture.

For other platforms, you'll need to build the [Snek LSP](https://github.com/yourusername/snek-lsp) from source.

## 🌐 Supported Languages

- Rust (`.rs`)
- Python (`.py`)
- JavaScript (`.js`)
- TypeScript (`.ts`)
- Java (`.java`)
- Go (`.go`)
- C/C++ (`.c`, `.cpp`, `.cc`, `.cxx`)
- Lua (`.lua`)

## 🐛 Troubleshooting

### Completions not appearing

1. **Check Snek is running:** `:SnekStatus`
2. **Check logs:** `:SnekShowLog`
3. **Verify API key:** Make sure your Cerebras API key is valid
4. **Check network:** Ensure you can reach `api.cerebras.ai`

### "Binary not found" error

The plugin should auto-detect your platform. If it fails:

```lua
require("snek-nvim").setup({
  api_key = "your-api-key",
  binary_path = "/path/to/snek/binary",  -- Override auto-detection
})
```

### Completions are slow

1. Try the faster `llama3.1-8b` model
2. Reduce context files in `.snek/sessions/{id}/context/`
3. Check [Cerebras status](https://status.cerebras.ai/)

## 🤝 Contributing

We love contributions! Check out the [GitHub repository](https://github.com/yourusername/snek-nvim) to:
- Report bugs
- Request features
- Submit pull requests

Also see the main [Snek LSP repository](https://github.com/yourusername/snek-lsp) for LSP-related contributions.

## 📖 Related Projects

- [snek-lsp](https://github.com/yourusername/snek-lsp) - The LSP server powering snek-nvim
- [snek-vscode](https://github.com/yourusername/snek-vscode) - VSCode extension

## 🔒 Privacy & Security

- **No telemetry** - Snek never collects usage data
- **Local processing** - All context stays on your machine
- **API security** - Your API key is only used to call Cerebras
- **Open source** - Every line of code is auditable

## 📜 License

MIT License - see [LICENSE](./LICENSE) for details.

---

<div align="center">

**Built with ❤️ by developers, for developers**

[⭐ Star us on GitHub](https://github.com/yourusername/snek-nvim) | [🐛 Report a Bug](https://github.com/yourusername/snek-nvim/issues) | [📖 Documentation](https://github.com/yourusername/snek-lsp)

</div>
