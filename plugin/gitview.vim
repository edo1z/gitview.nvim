" gitview.nvim - A simple git status and log viewer for Neovim
" Maintainer: edo1z
" License: MIT

if exists('g:loaded_gitview')
  finish
endif
let g:loaded_gitview = 1

" デフォルトのキーマッピング（ユーザーが無効化可能）
if !exists('g:gitview_no_default_mappings')
  nnoremap <silent> gs :lua require('gitview').open()<CR>
  nnoremap <silent> gh :lua require('gitview.log').open()<CR>
endif

" コマンド定義
command! GitStatus lua require('gitview').open()
command! GitLog lua require('gitview.log').open()
command! GitBranch lua require('gitview.branch').open()
command! GitView lua require('gitview').open()
command! GitViewClose lua require('gitview').close()