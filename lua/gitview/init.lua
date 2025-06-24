-- gitview.nvim - Git log viewer for Neovim
-- A simple and fast git viewer for Neovim
-- Author: edo1z
-- License: MIT

local M = {}
local api = vim.api
local fn = vim.fn

-- ローカル変数
local status_buf = nil
local status_win = nil
local diff_buf = nil
local diff_win = nil
local previous_buf = nil  -- 前のバッファを記憶

-- ユーティリティ関数
local function create_buf(name, options)
  local buf = api.nvim_create_buf(false, true)
  
  -- デフォルトオプション
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  
  -- カスタムオプション
  if options then
    for k, v in pairs(options) do
      vim.bo[buf][k] = v
    end
  end
  
  -- バッファ名を設定（最後に）
  if name then
    pcall(function()
      api.nvim_buf_set_name(buf, name)
    end)
  end
  
  return buf
end

-- Git statusを取得
local function get_git_status()
  local status = {}
  local output = fn.system('git status --porcelain -u')
  
  for line in output:gmatch("[^\r\n]+") do
    local status_code = line:sub(1, 2)
    local file_path = line:sub(4)
    
    table.insert(status, {
      status = status_code,
      path = file_path,
      expanded = false
    })
  end
  
  return status
end

-- ツリー表示用のフォーマット
local function format_status_tree(status_data)
  local lines = {}
  local line_data = {}
  
  for _, item in ipairs(status_data) do
    local prefix = ""
    local staged = item.status:sub(1, 1)
    local unstaged = item.status:sub(2, 2)
    
    -- ステージ状態を表示
    if staged ~= " " and staged ~= "?" then
      prefix = "● "  -- ステージ済み
    else
      prefix = "○ "  -- 未ステージ
    end
    
    -- ファイル状態を表示
    if staged == "M" or unstaged == "M" then
      prefix = prefix .. "[M] "  -- Modified
    elseif staged == "A" then
      prefix = prefix .. "[A] "  -- Added  
    elseif staged == "D" or unstaged == "D" then
      prefix = prefix .. "[D] "  -- Deleted
    elseif item.status == "??" then
      prefix = "○ [?] "  -- Untracked
    else
      prefix = prefix .. "[" .. item.status .. "] "
    end
    
    table.insert(lines, prefix .. item.path)
    table.insert(line_data, item)
  end
  
  return lines, line_data
end


-- ファイルの状態を取得
local function get_file_status(file_path)
  local status_output = fn.system('git status --porcelain -- ' .. fn.shellescape(file_path))
  if status_output ~= "" then
    return status_output:sub(1, 2)
  end
  return ""
end

-- Diffを表示
local function show_diff(file_path)
  -- 現在のウィンドウを保存
  local current_win = api.nvim_get_current_win()
  
  -- ファイルの状態を確認
  local file_status = get_file_status(file_path)
  local staged = file_status:sub(1, 1)
  local unstaged = file_status:sub(2, 2)
  
  -- 通常のunified diff
  local diff_output
  
  if file_status == "??" then
    -- 新規ファイルの場合
    diff_output = "=== NEW FILE ===\n" .. fn.system('cat ' .. fn.shellescape(file_path))
  elseif staged ~= " " and unstaged ~= " " then
    -- ステージ済み＋未ステージの両方がある場合
    diff_output = fn.system('git diff HEAD -- ' .. fn.shellescape(file_path))
  elseif staged ~= " " then
    -- ステージ済みのみ
    diff_output = fn.system('git diff --cached -- ' .. fn.shellescape(file_path))
  else
    -- 未ステージのみ
    diff_output = fn.system('git diff -- ' .. fn.shellescape(file_path))
  end
  
  -- 既存のDiffウィンドウがあれば再利用、なければ新規作成
  local win_valid = diff_win and pcall(api.nvim_win_is_valid, diff_win) and api.nvim_win_is_valid(diff_win)
  
  if win_valid then
    -- 既存のウィンドウを使用、バッファの内容だけ更新
    vim.bo[diff_buf].modifiable = true
    api.nvim_buf_set_lines(diff_buf, 0, -1, false, vim.split(diff_output, '\n'))
    vim.bo[diff_buf].modifiable = false
  else
    -- 新規ウィンドウを作成（右側に）
    vim.cmd('rightbelow vsplit')
    diff_win = api.nvim_get_current_win()
    diff_buf = create_buf(nil, { filetype = 'diff' })
    api.nvim_win_set_buf(diff_win, diff_buf)
    api.nvim_win_set_width(diff_win, math.floor(vim.o.columns * 0.5))
    
    -- Diffを表示
    vim.bo[diff_buf].modifiable = true
    api.nvim_buf_set_lines(diff_buf, 0, -1, false, vim.split(diff_output, '\n'))
    vim.bo[diff_buf].modifiable = false
    
    -- 元のウィンドウに戻る
    pcall(api.nvim_set_current_win, current_win)
  end
end

-- ステータスバッファのキーマップ設定
local function setup_status_keymaps(buf, line_data)
  local opts = { noremap = true, silent = true }
  
  -- hjkl移動
  api.nvim_buf_set_keymap(buf, 'n', 'j', ':lua vim.cmd("normal! j")<CR>', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'k', ':lua vim.cmd("normal! k")<CR>', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'h', ':lua vim.cmd("normal! h")<CR>', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'l', ':lua require("mygit").show_diff_for_current_line()<CR>', opts)
  
  -- Git操作
  api.nvim_buf_set_keymap(buf, 'n', 's', ':lua require("mygit").stage_current_file()<CR>', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'u', ':lua require("mygit").unstage_current_file()<CR>', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'c', ':lua require("mygit").commit()<CR>', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'p', ':lua require("mygit").push()<CR>', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'r', ':lua require("mygit").refresh()<CR>', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'q', ':lua require("mygit").close()<CR>', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'x', ':lua require("mygit").discard_changes()<CR>', opts)  -- 変更を破棄
  
  -- ヘルプ
  api.nvim_buf_set_keymap(buf, 'n', '?', ':lua require("mygit").show_help()<CR>', opts)
end

-- メイン関数：Git Status UIを開く
function M.open()
  -- 現在のバッファを記憶
  previous_buf = api.nvim_get_current_buf()
  
  -- 既存のバッファがあれば削除
  if status_buf and api.nvim_buf_is_valid(status_buf) then
    api.nvim_buf_delete(status_buf, {force = true})
  end
  
  -- 新しいタブで開く
  vim.cmd('tabnew')
  
  -- ステータスバッファを作成
  status_buf = create_buf('GitStatus', {
    filetype = 'gitstatus'
  })
  
  status_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(status_win, status_buf)
  
  -- Git statusを取得して表示
  M.refresh()
end

-- リフレッシュ
function M.refresh()
  if not status_buf or not api.nvim_buf_is_valid(status_buf) then
    return
  end
  
  local status_data = get_git_status()
  local lines, line_data = format_status_tree(status_data)
  
  -- バッファに書き込み
  vim.bo[status_buf].modifiable = true
  api.nvim_buf_set_lines(status_buf, 0, -1, false, lines)
  vim.bo[status_buf].modifiable = false
  
  -- バッファローカル変数に保存
  api.nvim_buf_set_var(status_buf, 'line_data', line_data)
  
  -- キーマップ設定
  setup_status_keymaps(status_buf, line_data)
  
  -- ヘッダーを追加
  local header = {
    "Git Status",
    "==========",
    "",
    "Keys: j/k:move, l:diff, s:stage, u:unstage, x:discard, c:commit, p:push, r:refresh, q:quit, ?:help",
    "Status: ● staged, ○ unstaged",
    "",
  }
  
  vim.bo[status_buf].modifiable = true
  api.nvim_buf_set_lines(status_buf, 0, 0, false, header)
  vim.bo[status_buf].modifiable = false
end

-- 現在行のファイルのDiffを表示
function M.show_diff_for_current_line()
  local line = api.nvim_win_get_cursor(0)[1]
  local line_data = api.nvim_buf_get_var(status_buf, 'line_data')
  
  -- ヘッダー行をスキップ
  local data_line = line - 6  -- ヘッダーが6行
  if data_line > 0 and data_line <= #line_data then
    show_diff(line_data[data_line].path)
  end
end

-- 現在行のファイルをステージ
function M.stage_current_file()
  local line = api.nvim_win_get_cursor(0)[1]
  local line_data = api.nvim_buf_get_var(status_buf, 'line_data')
  
  local data_line = line - 6  -- ヘッダーが6行に増えたため
  if data_line > 0 and data_line <= #line_data then
    local file_path = line_data[data_line].path
    fn.system('git add ' .. fn.shellescape(file_path))
    M.refresh()
  end
end

-- 現在行のファイルをアンステージ
function M.unstage_current_file()
  local line = api.nvim_win_get_cursor(0)[1]
  local line_data = api.nvim_buf_get_var(status_buf, 'line_data')
  
  local data_line = line - 6  -- ヘッダーが6行に増えたため
  if data_line > 0 and data_line <= #line_data then
    local file_path = line_data[data_line].path
    fn.system('git reset HEAD ' .. fn.shellescape(file_path))
    M.refresh()
  end
end

-- コミット
function M.commit()
  vim.ui.input({prompt = 'Commit message: '}, function(msg)
    if msg and msg ~= '' then
      local result = fn.system('git commit -m ' .. fn.shellescape(msg))
      print(result)
      M.refresh()
    end
  end)
end

-- プッシュ
function M.push()
  print("Pushing...")
  local result = fn.system('git push')
  print(result)
end

-- 閉じる
function M.close()
  if diff_buf and api.nvim_buf_is_valid(diff_buf) then
    api.nvim_buf_delete(diff_buf, {force = true})
  end
  if status_buf and api.nvim_buf_is_valid(status_buf) then
    api.nvim_buf_delete(status_buf, {force = true})
  end
  -- ウィンドウIDをリセット
  diff_win = nil
  status_win = nil
  
  -- タブが複数ある場合のみ閉じる
  if vim.fn.tabpagenr('$') > 1 then
    vim.cmd('tabclose')
    -- 前のバッファに戻る（存在していれば）
    if previous_buf and api.nvim_buf_is_valid(previous_buf) then
      -- 現在のウィンドウで前のバッファを開く
      local win = api.nvim_get_current_win()
      api.nvim_win_set_buf(win, previous_buf)
    end
  else
    -- 最後のタブの場合は、前のバッファに戻る
    if previous_buf and api.nvim_buf_is_valid(previous_buf) then
      api.nvim_set_current_buf(previous_buf)
    else
      vim.cmd('enew')
    end
  end
  previous_buf = nil
end

-- 変更を破棄
function M.discard_changes()
  local line = api.nvim_win_get_cursor(0)[1]
  local line_data = api.nvim_buf_get_var(status_buf, 'line_data')
  
  local data_line = line - 6  -- ヘッダーが6行
  if data_line > 0 and data_line <= #line_data then
    local file_path = line_data[data_line].path
    local file_status = line_data[data_line].status
    
    -- 確認ダイアログ
    vim.ui.input({
      prompt = 'Discard changes to ' .. file_path .. '? (yes/no): '
    }, function(answer)
      if answer and (answer:lower() == 'yes' or answer:lower() == 'y') then
        if file_status == "??" then
          -- 未追跡ファイルの場合は削除
          fn.system('rm ' .. fn.shellescape(file_path))
          print("Removed untracked file: " .. file_path)
        else
          -- 追跡ファイルの場合はgit checkoutで復元
          fn.system('git checkout -- ' .. fn.shellescape(file_path))
          print("Discarded changes to: " .. file_path)
        end
        M.refresh()
      end
    end)
  end
end

-- ヘルプ表示
function M.show_help()
  print([[
MyGit Help:
  j/k     - Move up/down
  l       - Show diff for file
  s       - Stage file
  u       - Unstage file
  x       - Discard changes (restore file)
  c       - Commit
  p       - Push
  r       - Refresh
  q       - Quit
  ?       - Show this help
  ]])
end

return M