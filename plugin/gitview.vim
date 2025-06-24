" gitview.nvim - A simple git file viewer for Neovim
" Maintainer: edo1z
" License: MIT

if exists('g:loaded_gitview')
  finish
endif
let g:loaded_gitview = 1

" デフォルトのキーマッピング（ユーザーが無効化可能）
if !exists('g:gitview_no_default_mappings')
  nnoremap <silent> <leader>gv :lua require('gitview').open()<CR>
endif

" コマンド定義
command! GitView lua require('gitview').open()
command! GitViewClose lua require('gitview').close()