# Tabú

## Description

GUI for neovim tabs.

## Requirements

- [neovim](https://github.com/neovim/neovim) (>= 7.0)
- [plenary](https://github.com/nvim-lua/plenary.nvim)

## Keybindings

### Default actions

```lua
{
  "j" = "move down",
  "k" = "move up"
  ["<ESC>"] = "close preview windows",
  ["<CR>"] = "select tab",
}
```

### Development

Open neovim with the following command:
```sh
nvim --cmd "set rtp+=./" lua/tabu/init.lua
```

### TODO

- Delete tab
