# gitview.nvim

A simple and fast git log viewer for Neovim.

![gitview demo](https://user-images.githubusercontent.com/placeholder.gif)

## Features

- 📊 Interactive git log viewer with graph visualization
- 📁 File changes preview
- 🔍 Quick diff view for any commit
- ⚡ Fast navigation with vim keybindings
- 🗑️ Discard uncommitted changes (for untracked files)
- 🔄 Return to previous buffer when closing

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
  config = function()
    require('gitview').setup()
  end,
}
```

## Usage

### Commands

- `:GitView` - Open git log viewer
- `:GitViewClose` - Close git log viewer

### Default Keymapping

- `<leader>gv` - Toggle git log viewer

### Keybindings in GitView

| Key | Action |
|-----|--------|
| `Enter` | Show commit diff |
| `d` | Show file changes |
| `q` | Close window (returns to previous buffer) |
| `x` | Discard changes (for untracked files) |
| `j/k` | Navigate commits |
| `gg/G` | Go to first/last commit |

## Configuration

```lua
require('gitview').setup({
  -- Disable default keymapping
  no_default_mappings = false,
  
  -- Window configuration
  window = {
    width = 0.8,  -- 80% of screen width
    height = 0.8, -- 80% of screen height
  },
  
  -- Custom keymapping
  keymaps = {
    toggle = '<leader>gv',
  },
})
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Issues and PRs are welcome!

## Acknowledgments

Inspired by vim-fugitive and other great git plugins.