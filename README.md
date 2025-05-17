# :houses: chez.nvim

A `chezmoi` wrapper that feels at home in Neovim's command line.

:warning: **This plugin is still in the alpha stage of development.
It still lacks many features and may contain bugs.**

## Setup

Requirements:

- neovim, v0.11.0 or above
- chezmoi, available in your `PATH`

Before using this plugin, you need to call its `setup()` function:

```lua
require("chez").setup()
```

Currently, no setup options are supported. Please file a GitHub Issue if you
have any suggestions.

## Commands

This plugin provides the `:Chez` ex command, whose subcommands are used to
perform `chezmoi` operations, usually on the currently open file.

A handful of these subcommands support flags and arguments, though the full
interface for this plugin is still a work-in-progress.

See `:help :Chez-{subcmd}` for details.

### `:Chez status`

Display `chezmoi status`.

### `:Chez source`

Edit the chezmoi source of the current buffer, if managed.

### `:Chez target`

Edit the chezmoi target of the current buffer, if managed.

### `:Chez alternate`

Alternate between chezmoi source and target of the current buffer.

### `:Chez add`

Run `chezmoi add` on the current buffer's file.

### `:Chez re-add`

Run `chezmoi re-add` on the current buffer's file.

### `:Chez apply`

Run `chezmoi apply` on the current buffer's file.

### `:Chez push`

Push the current buffer's changes to its source or target.

### `:Chez pull`

Pull changes from the current buffer's source or target.

### `:Chez forget`

Run `chezmoi forget` on the current buffer's file.

### `:Chez destroy`

Run `chezmoi destroy` on the current buffer's file.

### `:Chez diff`

Open Vim diff for the source and target file of the current buffer.

### `:Chez! {args}`

Run the `chezmoi` shell command, with {args} passed directly to `chezmoi`.

## Lua API

Every `:Chez` subcommand (see above) can also be called directly
from Lua, like this:

```lua
require("chez").apply()
-- same as :Chez apply
```

Each Lua API function supports an optional {opts} table that can be used to pass
command-line options:

```lua
require("chez").destroy({ force = true })
-- same as :Chez destroy --force

require("chez").help({ "re-add" })
-- same as :Chez help re-add
```

## Events

### `ChezEnter`

`ChezEnter` is triggered when chez.nvim detects that Neovim has entered
a buffer that is managed by `chezmoi`. You can use this to configure your
own hooks, like this:

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "ChezEnter",
  callback = function(ev)
    local target = vim.b[ev.buf].chezmoi_target
    local source = vim.b[ev.buf].chezmoi_source
    if target then
      vim.notify("entered source buffer of target: " .. target)
    elseif source then
      vim.notify("entered target buffer of source: " .. source)
    else
      error("this event should not fire for unmanaged files")
      -- If you encounter this scenario, please open a GitHub issue!
    end
  end,
})
```

## Alternatives and Comparisons

-   [alker0/chezmoi.vim](https://github.com/alker0/chezmoi.vim)
    ensures syntax-highlighting for chezmoi source files and templates.
    `chez.nvim` does not currently do this.

-   [xvzc/chezmoi.nvim](https://github.com/xvzc/chezmoi.nvim)
    uses an events-based system to automatically apply source changes
    to their targets, ensuring that they stay in sync. It is similar to
    automatically using `chezmoi edit --watch` on managed files, though
    it uses built-in Neovim functions to support editing and watching
    multiple files simultaneously.

    `chez.nvim` favors managing chezmoi files with the `:Chez` command.
    Those commands are similar to running `:!chezmoi` directly, though
    they provide a convenience layer that is aware of the currently
    edited file.

    `chezmoi.nvim` also includes an integration with
    [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
    to list all managed files. `chez.nvim` does not yet provide this.
