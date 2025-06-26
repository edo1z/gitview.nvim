-- gitview/branch.lua
-- Git branch表示モジュール

local M = {}
local api = vim.api
local fn = vim.fn

local branch_buf = nil
local branch_win = nil

-- ポップアップウィンドウのサイズを計算
local function calculate_popup_size()
  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.5)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  return {
    width = width,
    height = height,
    row = row,
    col = col
  }
end

-- キーマップ設定
local function setup_keymaps(buf)
  local opts = { noremap = true, silent = true }
  
  -- qで閉じる
  api.nvim_buf_set_keymap(buf, 'n', 'q', ':lua require("gitview.branch").close()<CR>', opts)
  
  -- ESCでも閉じる
  api.nvim_buf_set_keymap(buf, 'n', '<ESC>', ':lua require("gitview.branch").close()<CR>', opts)
end

-- ブランチリストを表示
function M.open()
  -- 既にウィンドウが開いている場合は閉じる
  if branch_win and api.nvim_win_is_valid(branch_win) then
    M.close()
    return
  end
  
  -- git branch -vvaの出力を取得（worktreeの情報も含む）
  local output = fn.system('git branch -vva')
  local lines = vim.split(output, '\n')
  
  -- 空行を削除
  local filtered_lines = {}
  for _, line in ipairs(lines) do
    if line ~= '' then
      table.insert(filtered_lines, line)
    end
  end
  
  -- バッファを作成
  branch_buf = api.nvim_create_buf(false, true)
  
  -- バッファの設定
  vim.bo[branch_buf].buftype = 'nofile'
  vim.bo[branch_buf].bufhidden = 'wipe'
  vim.bo[branch_buf].swapfile = false
  
  -- 内容を設定（modifiableをtrueにしてから）
  vim.bo[branch_buf].modifiable = true
  api.nvim_buf_set_lines(branch_buf, 0, -1, false, filtered_lines)
  vim.bo[branch_buf].modifiable = false
  
  -- ポップアップウィンドウのサイズと位置を計算
  local size = calculate_popup_size()
  
  -- ポップアップウィンドウを作成
  branch_win = api.nvim_open_win(branch_buf, true, {
    relative = 'editor',
    width = size.width,
    height = size.height,
    row = size.row,
    col = size.col,
    style = 'minimal',
    border = 'rounded',
    title = ' Git Branches ',
    title_pos = 'center'
  })
  
  -- ウィンドウオプション
  vim.wo[branch_win].number = false
  vim.wo[branch_win].relativenumber = false
  vim.wo[branch_win].wrap = false
  vim.wo[branch_win].cursorline = true
  
  -- キーマップを設定
  setup_keymaps(branch_buf)
  
  -- 現在のブランチがある行にカーソルを移動
  for i, line in ipairs(filtered_lines) do
    if line:match('^%*') then
      api.nvim_win_set_cursor(branch_win, {i, 0})
      break
    end
  end
end

-- ウィンドウを閉じる
function M.close()
  if branch_win and api.nvim_win_is_valid(branch_win) then
    api.nvim_win_close(branch_win, true)
  end
  branch_win = nil
  branch_buf = nil
end

return M