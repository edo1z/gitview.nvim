-- gitview/log.lua
-- Git log表示モジュール

local M = {}
local api = vim.api
local fn = vim.fn

local log_buf = nil
local log_win = nil
local detail_buf = nil
local detail_win = nil

-- Git logを取得（グラフとブランチ情報付き）
local function get_git_log(limit)
  limit = limit or 100
  -- グラフ、装飾（ブランチ名）、全ブランチ、カラー付きで取得
  local output = fn.system('git log --graph --pretty=format:"|%h|%d|%s|%an|%ar" --all --color=always -' .. limit)
  local logs = {}
  
  for line in output:gmatch("[^\r\n]+") do
    -- |で区切られたフィールドを解析
    local parts = {}
    local pattern = "([^|]*)"
    for part in line:gmatch(pattern) do
      if part ~= "" or #parts > 0 then  -- 最初の空文字列は無視
        table.insert(parts, part)
      end
    end
    
    if #parts >= 5 then
      -- グラフ部分を含む最初のフィールドを処理
      local graph_and_hash = parts[1]
      local graph = ""
      local hash = ""
      
      -- グラフ部分（|, *, \, / などの文字）とハッシュを分離
      local hash_start = graph_and_hash:find("%x%x%x%x%x%x%x")
      if hash_start then
        graph = graph_and_hash:sub(1, hash_start - 1)
        hash = graph_and_hash:sub(hash_start, hash_start + 6)
      else
        -- ハッシュが見つからない場合は全体をグラフとして扱う
        graph = graph_and_hash
      end
      
      table.insert(logs, {
        graph = graph,
        hash = hash,
        refs = parts[2] or "",  -- ブランチ名、タグなど
        message = parts[3] or "",
        author = parts[4] or "",
        date = parts[5] or ""
      })
    end
  end
  
  return logs
end

-- コミットの詳細を取得
local function get_commit_detail(hash)
  local detail = {}
  
  -- コミット情報
  detail.info = fn.system('git show --no-patch --format="%H%n%an <%ae>%n%ad%n%n%s%n%n%b" ' .. hash)
  
  -- 変更されたファイル一覧
  local files_output = fn.system('git show --name-status --format="" ' .. hash)
  detail.files = {}
  
  for line in files_output:gmatch("[^\r\n]+") do
    local status, path = line:match("^([AMDRC])%s+(.+)$")
    if status and path then
      table.insert(detail.files, {
        status = status,
        path = path
      })
    end
  end
  
  return detail
end

-- Diffウィンドウ用の変数
local file_diff_win = nil
local file_diff_buf = nil

-- ファイルのdiffを表示
local function show_file_diff(hash, file_path)
  -- 通常のunified diff
  local diff_output = fn.system('git show ' .. hash .. ' -- ' .. fn.shellescape(file_path))
  
  -- 既存のDiffウィンドウがあれば再利用、なければ新規作成
  local win_valid = file_diff_win and pcall(api.nvim_win_is_valid, file_diff_win) and api.nvim_win_is_valid(file_diff_win)
  
  if win_valid then
    -- 既存のウィンドウを使用、バッファの内容だけ更新
    vim.bo[file_diff_buf].modifiable = true
    api.nvim_buf_set_lines(file_diff_buf, 0, -1, false, vim.split(diff_output, '\n'))
    vim.bo[file_diff_buf].modifiable = false
  else
    -- 新規ウィンドウを作成
    vim.cmd('rightbelow vsplit')
    file_diff_win = api.nvim_get_current_win()
    file_diff_buf = api.nvim_create_buf(false, true)
    api.nvim_win_set_buf(file_diff_win, file_diff_buf)
    vim.bo[file_diff_buf].buftype = 'nofile'
    vim.bo[file_diff_buf].filetype = 'diff'
    api.nvim_buf_set_lines(file_diff_buf, 0, -1, false, vim.split(diff_output, '\n'))
    vim.bo[file_diff_buf].modifiable = false
  end
  
  -- 元のウィンドウに戻る
  api.nvim_set_current_win(detail_win)
end

-- ログバッファのキーマップ
local function setup_log_keymaps(buf, log_data)
  local opts = { noremap = true, silent = true }
  
  -- ターミナルバッファ用の設定
  api.nvim_buf_set_keymap(buf, 'n', 'j', 'j', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'k', 'k', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'l', ':lua require("gitview.log").show_detail()<CR>', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'q', ':lua require("gitview.log").close()<CR>', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'r', ':lua require("gitview.log").refresh()<CR>', opts)
  api.nvim_buf_set_keymap(buf, 'n', '?', ':lua require("gitview.log").show_help()<CR>', opts)
  
  -- データを保存
  api.nvim_buf_set_var(buf, 'log_data', log_data)
end

-- 詳細バッファのキーマップ
local function setup_detail_keymaps(buf, hash, files)
  local opts = { noremap = true, silent = true }
  
  api.nvim_buf_set_keymap(buf, 'n', 'j', 'j', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'k', 'k', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'l', ':lua require("gitview.log").show_file_diff()<CR>', opts)
  api.nvim_buf_set_keymap(buf, 'n', 'q', ':lua require("gitview.log").close_detail()<CR>', opts)
  
  -- データを保存
  api.nvim_buf_set_var(buf, 'commit_hash', hash)
  api.nvim_buf_set_var(buf, 'file_data', files)
end

-- メイン関数：Git logを開く
function M.open()
  -- 新しいタブで開く
  vim.cmd('tabnew')
  
  -- ターミナルバッファで開く（カラー表示のため）
  -- ブランチ名を明るい色で表示するフォーマット
  local cmd = [[git log --graph --pretty=format:"%C(yellow)%h%C(reset) %C(bold cyan)%d%C(reset) %s %C(dim white)- %an, %ar%C(reset)" --all --color=always -100]]
  vim.fn.termopen(cmd)
  
  log_buf = api.nvim_get_current_buf()
  log_win = api.nvim_get_current_win()
  
  -- ターミナルモードを抜ける
  vim.cmd('stopinsert')
  
  -- ターミナルバッファの設定
  vim.bo[log_buf].bufhidden = 'wipe'
  vim.bo[log_buf].modifiable = false
  
  -- ログデータも取得（詳細表示用）
  local log_data = get_git_log(100)
  
  -- キーマップ設定
  setup_log_keymaps(log_buf, log_data)
end

-- 詳細を表示
function M.show_detail()
  local line = api.nvim_win_get_cursor(0)[1]
  local log_data = api.nvim_buf_get_var(log_buf, 'log_data')
  
  -- ターミナルバッファの場合、実際のコミット行を見つける
  local terminal_lines = api.nvim_buf_get_lines(log_buf, 0, -1, false)
  local current_line = terminal_lines[line] or ""
  
  -- 行からハッシュを抽出（7文字の16進数）
  local hash_pattern = "%x%x%x%x%x%x%x"
  local hash = current_line:match(hash_pattern)
  
  if hash then
    local detail = get_commit_detail(hash)
    
    -- 既存の詳細ウィンドウがあれば再利用、なければ新規作成
    local win_valid = detail_win and pcall(api.nvim_win_is_valid, detail_win) and api.nvim_win_is_valid(detail_win)
    
    if win_valid then
      -- 既存のウィンドウを使用、バッファの内容だけ更新
      vim.bo[detail_buf].modifiable = true
    else
      -- 新規ウィンドウを作成
      vim.cmd('rightbelow split')
      detail_win = api.nvim_get_current_win()
      detail_buf = api.nvim_create_buf(false, true)
      api.nvim_win_set_buf(detail_win, detail_buf)
      vim.bo[detail_buf].buftype = 'nofile'
    end
    
    -- 詳細を表示
    local lines = vim.split(detail.info, '\n')
    table.insert(lines, "")
    table.insert(lines, "Changed Files:")
    table.insert(lines, "==============")
    
    for _, file in ipairs(detail.files) do
      table.insert(lines, string.format("[%s] %s", file.status, file.path))
    end
    
    api.nvim_buf_set_lines(detail_buf, 0, -1, false, lines)
    vim.bo[detail_buf].modifiable = false
    
    setup_detail_keymaps(detail_buf, hash, detail.files)
  end
end

-- ファイルのdiffを表示
function M.show_file_diff()
  local line = api.nvim_win_get_cursor(0)[1]
  local hash = api.nvim_buf_get_var(detail_buf, 'commit_hash')
  local file_data = api.nvim_buf_get_var(detail_buf, 'file_data')
  
  -- ファイルリストの開始位置を見つける
  local file_start_line = 0
  local lines = api.nvim_buf_get_lines(detail_buf, 0, -1, false)
  for i, l in ipairs(lines) do
    if l == "Changed Files:" then
      file_start_line = i + 2  -- "Changed Files:" と "==============" をスキップ
      break
    end
  end
  
  local file_line = line - file_start_line + 1
  if file_line > 0 and file_line <= #file_data then
    show_file_diff(hash, file_data[file_line].path)
  end
end

-- 詳細ウィンドウを閉じる
function M.close_detail()
  if detail_buf and api.nvim_buf_is_valid(detail_buf) then
    api.nvim_buf_delete(detail_buf, {force = true})
  end
end

-- リフレッシュ
function M.refresh()
  if log_buf and api.nvim_buf_is_valid(log_buf) then
    -- 現在のカーソル位置を保存
    local cursor_pos = api.nvim_win_get_cursor(log_win)
    
    -- バッファをクリアして再実行
    vim.bo[log_buf].modifiable = true
    api.nvim_buf_set_lines(log_buf, 0, -1, false, {})
    
    -- ターミナルコマンドを再実行（色付き）
    local cmd = [[git log --graph --pretty=format:"%C(yellow)%h%C(reset) %C(bold cyan)%d%C(reset) %s %C(dim white)- %an, %ar%C(reset)" --all --color=always -100]]
    vim.fn.termopen(cmd)
    vim.cmd('stopinsert')
    vim.bo[log_buf].modifiable = false
    
    -- ログデータも再取得
    local log_data = get_git_log(100)
    api.nvim_buf_set_var(log_buf, 'log_data', log_data)
    
    -- カーソル位置を復元
    pcall(api.nvim_win_set_cursor, log_win, cursor_pos)
  end
end

-- 全て閉じる
function M.close()
  M.close_detail()
  if log_buf and api.nvim_buf_is_valid(log_buf) then
    api.nvim_buf_delete(log_buf, {force = true})
  end
  -- ウィンドウIDをリセット
  log_win = nil
  detail_win = nil
  file_diff_win = nil
  vim.cmd('tabclose')
end

-- ヘルプ
function M.show_help()
  print([[
Git Log Help:
  j/k     - Move up/down
  l       - Show commit detail
  r       - Refresh log
  q       - Quit
  
In detail view:
  j/k     - Move up/down
  l       - Show file diff
  q       - Close detail
  
Shows:
  - Graph lines showing branch connections
  - Branch names in parentheses (HEAD -> main, origin/main, etc.)
  - Commit hash, message, author, and time
  ]])
end

return M