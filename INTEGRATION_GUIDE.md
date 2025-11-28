# Snek LSP Integration Guide

This guide explains how to integrate the Snek LSP binary with any IDE or editor extension.

## Core Concept

The Snek LSP is a **standalone binary** that communicates via stdin/stdout (LSP protocol). It can be integrated into any editor that supports LSP.

---

## Required Arguments

The LSP binary accepts the following command-line arguments:

### `--workspace-dir <path>` (Required)

Specifies the workspace/project root directory where the `.snek/` folder should be created.

**Examples:**
```bash
# Standard format
snek --workspace-dir /path/to/project

# Alternative format (with =)
snek --workspace-dir=/path/to/project

# Short format
snek --workspace /path/to/project
```

**Why this is important:**
- The LSP creates a `.snek/` folder in the workspace to store:
  - `active.json` - Points to the current active session
  - `sessions/{id}/` - Session data, context files, code snippets
  - `scripts/` - Utility scripts (new-session.sh, switch-session.sh)
  - `commands/` - Custom slash commands

**Fallback behavior (if not provided):**
- The LSP will search upward from the current working directory looking for an existing `.snek/` folder
- If not found, it creates `.snek/` in the current working directory
- **Important:** This may not be the project root if your editor starts the LSP from a different directory

---

## Configuration

### 1. API Key (Required for AI completions)

The API key is configured via **editor settings** and retrieved using the LSP's `workspace/configuration` capability.

**For VSCode users:**
1. Open Settings (Cmd/Ctrl + ,)
2. Search for "snek.apiKey"
3. Enter your API key

**For other editors:**
The LSP requests configuration via `workspace/configuration` with section `snek.apiKey`. Your editor integration should respond with the API key value.

**Behavior without API key:**
- LSP starts successfully
- Returns an error message when completion is requested: "API key not configured"
- The VSCode extension shows a warning in the status bar

### 2. API URL and Model (Hardcoded)

Currently hardcoded in the LSP source code (`src/lsp/server.rs`):
- API URL: `https://openai-proxy-aifp.onrender.com/v1/chat/completions`

---

## Integration Examples

### VS Code Extension (TypeScript)

```typescript
import { workspace } from 'vscode';
import { LanguageClient, ServerOptions, TransportKind, LanguageClientOptions } from 'vscode-languageclient/node';

// Get the workspace folder to pass to the LSP
const workspaceFolders = workspace.workspaceFolders;
const workspaceDir = workspaceFolders && workspaceFolders.length > 0
  ? workspaceFolders[0].uri.fsPath
  : undefined;

const serverOptions: ServerOptions = {
  command: '/path/to/snek',
  args: workspaceDir ? ['--workspace-dir', workspaceDir] : [],
  transport: TransportKind.stdio,
  options: {
    cwd: workspaceDir  // Set working directory as fallback
  }
};

const clientOptions: LanguageClientOptions = {
  documentSelector: [
    { scheme: 'file', language: 'rust' },
    { scheme: 'file', language: 'python' },
    { scheme: 'file', language: 'javascript' },
    { scheme: 'file', language: 'typescript' },
    { scheme: 'file', language: 'lua' },
    // ... add more languages as needed
  ],
  synchronize: {
    fileEvents: workspace.createFileSystemWatcher('**/*')
  }
};

const client = new LanguageClient(
  'snekLsp',
  'Snek Language Server',
  serverOptions,
  clientOptions
);

await client.start();
```

### JetBrains Plugin (Kotlin)

```kotlin
import com.intellij.openapi.project.Project
import com.intellij.platform.lsp.api.LspServerManager

val lspServerDescriptor = object : ProjectWideLspServerDescriptor(project, "Snek LSP") {
    override fun createCommandLine(): GeneralCommandLine {
        return GeneralCommandLine(
            "/path/to/snek",
            "--workspace-dir",
            project.basePath ?: ""
        )
    }
}

LspServerManager.getInstance(project).startServer(lspServerDescriptor)
```

### Neovim (Lua)

```lua
local lspconfig = require('lspconfig')
local configs = require('lspconfig.configs')

configs.snek = {
  default_config = {
    cmd = { 'snek', '--workspace-dir', vim.fn.getcwd() },
    filetypes = { 'rust', 'python', 'javascript', 'typescript', 'java', 'go', 'c', 'cpp', 'lua' },
    root_dir = function(fname)
      return vim.fn.getcwd()
    end,
  },
}

lspconfig.snek.setup{}
```

### Emacs (Elisp)

```elisp
(require 'lsp-mode)

(lsp-register-client
 (make-lsp-client
  :new-connection (lsp-stdio-connection
                   (lambda ()
                     (list "snek" "--workspace-dir" (projectile-project-root))))
  :major-modes '(rust-mode python-mode js-mode typescript-mode)
  :server-id 'snek))

(add-hook 'rust-mode-hook #'lsp)
(add-hook 'python-mode-hook #'lsp)
```

---

## LSP Custom Methods

### `snek/inline` - Get inline completion

**Request:**
```json
{
  "text_document": {
    "uri": "file:///path/to/file.rs"
  },
  "position": {
    "line": 10,
    "character": 5
  }
}
```

**Response:**
```json
{
  "completion": "let x = 42;"
}
```

---

## File Structure

When integrated, the LSP creates this structure in the workspace:

```
project/
├── .snek/
│   ├── active.json              # Current active session pointer
│   ├── scripts/                 # Utility scripts
│   │   ├── new-session.sh
│   │   └── switch-session.sh
│   ├── commands/                # Custom slash commands
│   │   └── snek.share.md
│   └── sessions/
│       └── {uuid}/
│           ├── session.json     # Session metadata (limits, version)
│           ├── code_snippets.json  # Code context references
│           └── context/         # Markdown context files
│               ├── architecture.md
│               └── conventions.md
└── your-project-files...
```

---

## Session Management

### Active Session

The LSP loads the session specified in `.snek/active.json`:
```json
{
  "schema": 1,
  "id": "aaf82595-38b4-4aef-a2c0-f7b4c2ffabae",
  "path": "sessions/aaf82595-38b4-4aef-a2c0-f7b4c2ffabae"
}
```

### Creating New Sessions

Use the provided script:
```bash
.snek/scripts/new-session.sh "my-session-name"
```

### Switching Sessions

Use the provided script:
```bash
.snek/scripts/switch-session.sh aaf82595  # First 8 chars of UUID
```

**Note:** After switching sessions, restart the LSP (reload your IDE).

---

## File Watching

The LSP automatically watches these files:

1. **`.snek/active.json`** - Detects session switches
2. **`.snek/sessions/{id}/session.json`** - Reloads session configuration
3. **`.snek/sessions/{id}/code_snippets.json`** - Updates code context
4. **`.snek/sessions/{id}/context/*.md`** - Updates markdown context
5. **Referenced code files** - Updates when source files change

**Important:** Changes to `active.json` require an LSP restart to switch sessions.

---

## Logs

The LSP outputs logs to stderr:

```bash
[SNEK] Starting Snek Language Server...
[SNEK] Workspace directory provided: /path/to/project
[SNEK] Initializing workspace...
[SNEK] Workspace root: "/path/to/project/.snek"
[SNEK] Active session: "/path/to/project/.snek/sessions/{uuid}"
[SNEK] Loaded session: {uuid} (version 0)
[SNEK] Starting file watcher...
[SNEK] API key loaded successfully
[SNEK] Server ready, listening on stdio...
```

### Error: No API Key

When the API key is not configured, completion requests will return an error:
```
[SNEK] Model API error: API key not configured. Please add your API key in VSCode settings:
File > Preferences > Settings > Search for 'snek.apiKey'
```

The VSCode extension will also show a warning in the status bar: `$(error) Snek: No API Key`

---

## Supported Languages

The LSP provides completions for:
- Rust (`.rs`)
- Python (`.py`)
- JavaScript (`.js`)
- TypeScript (`.ts`)
- Java (`.java`)
- Go (`.go`)
- C (`.c`)
- C++ (`.cpp`, `.cc`, `.cxx`)
- Lua (`.lua`)

---

## Binary Distribution

The binary is platform-specific:
- **macOS (ARM64)**: `snek` (Mach-O 64-bit executable arm64)
- **macOS (x86_64)**: Compile with `cargo build --target x86_64-apple-darwin`
- **Linux**: Compile with `cargo build --target x86_64-unknown-linux-gnu`
- **Windows**: Compile with `cargo build --target x86_64-pc-windows-msvc`

### Building for Different Platforms

```bash
# macOS ARM64 (M1/M2/M3)
cargo build --release

# macOS Intel
cargo build --release --target x86_64-apple-darwin

# Linux
cargo build --release --target x86_64-unknown-linux-gnu

# Windows
cargo build --release --target x86_64-pc-windows-msvc
```

---

## Troubleshooting

### LSP doesn't start

1. Check the binary is executable: `chmod +x /path/to/snek`
2. Verify workspace directory exists: `ls -la /path/to/workspace`
3. Check LSP logs (stderr) for error messages

### `.snek` folder created in wrong location

- Ensure `--workspace-dir` argument is passed correctly
- Verify the path is absolute, not relative

### No completions appearing

1. Check API key is configured in VSCode settings (`snek.apiKey`)
2. Look for errors in LSP logs (stderr)
3. Verify the file type is supported
4. Check network connectivity to API endpoint
5. Verify `--workspace-dir` was passed correctly to the LSP

### Session not found error

```bash
# Check active session
cat .snek/active.json

# List available sessions
ls .snek/sessions/

# Fix by pointing to an existing session or creating a new one
.snek/scripts/new-session.sh
```

---

## Advanced: Custom Context

Add custom context for better completions:

1. **Markdown files** in `.snek/sessions/{id}/context/`:
   ```bash
   echo "# Project Conventions

   - Use snake_case for variables
   - All functions must have docstrings" > .snek/sessions/{id}/context/conventions.md
   ```

2. **Code snippets** in `.snek/sessions/{id}/code_snippets.json`:
   ```json
   {
     "schema": 1,
     "snippets": [
       {
         "uri": "file:///path/to/project/src/utils.rs",
         "start_line": 0,
         "end_line": 50,
         "language_id": "rust",
         "description": "Utility functions",
         "last_modified": "2025-11-12T10:00:00Z"
       }
     ]
   }
   ```

---

## Summary

To integrate Snek LSP with any editor:

1. **Launch the binary** with `--workspace-dir` argument pointing to the project root
2. **Communicate via stdio** using LSP protocol
3. **Configure API key** via the editor's settings (e.g., `snek.apiKey` in VSCode)
4. **Call `snek/inline`** for inline completions

The LSP will:
- Create `.snek/` folder in the workspace if it doesn't exist
- Initialize a default session with context folder and scripts
- Watch for changes to context files and code snippets
- Request the API key via `workspace/configuration` after initialization

That's it! The LSP handles everything else automatically.
