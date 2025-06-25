# gitview.nvim

A simple git status and log viewer for Neovim.


https://github.com/user-attachments/assets/fa002c88-77ba-4f05-b3bd-00bb169946a5


## Features

### Git Status View
- 📁 Interactive git status viewer
- ✅ Stage/unstage files
- 🔍 View diffs for modified files
- 🗑️ Discard changes
- 💬 Commit and push directly from the viewer

### Git Log View
- 📊 Interactive git log viewer with graph visualization
- 🌳 Branch visualization with colors
- 📁 File changes preview for each commit
- 🔍 Quick diff view for any file in any commit

## Requirements

- Neovim >= 0.7.0
- git

## Installation

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'edo1z/gitview.nvim'
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use 'edo1z/gitview.nvim'
```

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'edo1z/gitview.nvim',
}
```

## Usage

### Commands

- `:GitStatus` - Open git status viewer
- `:GitLog` - Open git log viewer
- `:GitView` - Open git status viewer (alias)
- `:GitViewClose` - Close current viewer

### Default Keymappings

- `gs` - Open git status viewer
- `gh` - Open git log viewer (git history)

### Keybindings in Git Status View

| Key | Action |
|-----|--------|
| `j/k` | Move up/down |
| `l` | Show diff for current file |
| `s` | Stage file |
| `u` | Unstage file |
| `x` | Discard changes (with confirmation) |
| `c` | Commit staged changes |
| `p` | Push commits |
| `r` | Refresh status |
| `q` | Quit (returns to previous buffer) |
| `?` | Show help |

### Keybindings in Git Log View

| Key | Action |
|-----|--------|
| `j/k` | Move up/down |
| `l` | Show commit details |
| `r` | Refresh log |
| `q` | Quit |
| `?` | Show help |

In commit detail view:
| Key | Action |
|-----|--------|
| `j/k` | Move up/down |
| `l` | Show file diff |
| `q` | Close detail view |

## Configuration

To disable default keymappings, add this to your init.vim before loading the plugin:

```vim
let g:gitview_no_default_mappings = 1
```

Then you can set your own mappings:

```vim
nnoremap <leader>gs :GitStatus<CR>
nnoremap <leader>gl :GitLog<CR>
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Issues and PRs are welcome!

## Acknowledgments

Inspired by vim-fugitive and other great git plugins.
