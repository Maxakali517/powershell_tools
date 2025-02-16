# ---------------------------------------------------------
# 新旧IPアドレス一括置換スクリプト
# ---------------------------------------------------------

# オプションパラメータ（0：オフ、1：オン）
$dryrun_flag = 1  # ドライランするか
$backup_flag = 0  # バックアップを作成するか
$logging_flag = 0 # 実行ログCSVを出力するか

# dryrun_flag = 0 (ドライランせずに実際に置換を行う)になっている場合、警告を表示する
if (!$dryrun_flag) {
    Write-Host "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
    Write-Host "Enter押下すると実際に置換操作を行います。中止する場合はCtrl + C"
    Write-Host "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
    Pause
}

# 変数定義、初期化
$target_paths = Import-Csv ".\target_paths.csv"
$migration_addresses = Import-Csv ".\migration_addresses.csv"
$replace_list = @() # 置換の結果、差分が出た行の一覧 を定義・初期化
$process_list = @() # 各ファイルに対する処理結果の一覧 を定義・初期化
[string]$success_code = "Success" # 処理の成功時に［result_XX］に格納する文字列
[string]$log_prefix_info = "[info]" # コンソールに表示する実行ログ（通常）の先頭文字列
[string]$log_prefix_error = "[Error]" # コンソールに表示する実行ログ（エラー）の先頭文字列

# target_pathsから作業中のサーバ名に一致するレコードのみを抽出し、新たな変数に代入
$my_target_paths = ($target_paths | Where-Object { $_.server_name -eq $(HOSTNAME.EXE) }).ipv4_address

foreach ($my_target_path in $my_target_paths) {
    # result_get_contentを取得（すぐ下のprocess_listへの行追加でプロパティとして使用します）
    try {
        [void](Get-Content $my_target_path -ErrorAction Stop)
        $result_get_content = $success_code
        Write-Host "$($log_prefix_info)対象ファイルの取得に成功しました：$($my_target_path)"
    }
    catch {
        $result_get_content = $Error[0].CategoryInfo.Category
        Write-Host "$($log_prefix_error)対象ファイルの取得で［$($result_get_content)］が発生しました：$($my_target_path)"
    }

    # process_listへの行追加
    $process_list += [PSCustomObject]@{
        server_name        = $(HOSTNAME.EXE)
        target_path        = $my_target_path
        result_get_content = $result_get_content
        result_backup      = ""
        result_set_content = ""
    }
    
}

# バックアップ作成（オプション）
if ($backup_flag) {
    foreach ($process in $process_list) {
        if ($process.result_get_content -eq $success_code) {
            try {
                Copy-Item `
                    -Path $process.target_path `
                    -Destination "$($process.target_path)_$((Get-Date).ToString("yyyyMMdd")).backup" `
                    -ErrorAction Stop
                $process.result_backup = $success_code
                Write-Host "$($log_prefix_info)バックアップの作成に成功しました：$($process.target_path)"
            }
            catch {
                $process.result_backup = $Error[0].CategoryInfo.Category
                Write-Host "$($log_prefix_error)バックアップの作成が[$($process.result_backup)]で失敗しました：$($process.target_path)"                
            }
        }
    }
}

# 置換処理
foreach ($process in $process_list) {
    if ($process.result_get_content -eq $success_code) {
        $work_content_before = $work_content_after = Get-Content $process.target_path
        
        # 旧IPアドレス　→　プレースホルダー　へ置換
        for ($i = 0; $i -lt $migration_addresses.Length; $i++) {
            $work_content_after = $work_content_after.Replace($migration_addresses[$i].old_ipv4_address, $migration_addresses[$i].placeholder)
        }
        # プレースホルダー　→　新IPアドレス　へ置換
        for ($i = 0; $i -lt $migration_addresses.Length; $i++) {
            $work_content_after = $work_content_after.Replace($migration_addresses[$i].placeholder, $migration_addresses[$i].new_ipv4_address)
        }
    
        # 置換後の文字列でファイル上書き
        if (!$dryrun_flag) {
            try {
                Set-Content -Path $process.target_path -Value $work_content_after
                $process.result_set_content = $success_code
                Write-Host "$($log_prefix_info)置換に成功しました：$($process.target_path)"
            }
            catch {
                $process.result_set_content = $Error[0].CategoryInfo.Category
                Write-Host "$($log_prefix_error)置換が[$($process.result_set_content)]で失敗しました：$($process.target_path)"      
            }
        }
    
        # 置換の結果、差分が出た行の一覧を書き出し
        for ($lineNumber = 0; $lineNumber -lt [math]::Max($work_content_before.Length, $work_content_after.Length); $lineNumber++) {
            $beforeLine = if ($lineNumber -lt $work_content_before.Length) { $work_content_before[$lineNumber] } else { "" }
            $afterLine = if ($lineNumber -lt $work_content_after.Length) { $work_content_after[$lineNumber] } else { "" }
    
            if ($beforeLine -ne $afterLine) {
                $replace_list += [PSCustomObject]@{
                    server_name = $(HOSTNAME.EXE)
                    target_path = $process.target_path
                    line_number = $lineNumber + 1
                    before      = $beforeLine
                    after       = $afterLine
                }
            }
        }
    }
}

# ログファイル生成
if ($logging_flag) {
    $replace_list | Export-Csv -Path ".\replace_list_$(HOSTNAME.EXE).csv"
    $process_list | Export-Csv -Path ".\process_list_$(HOSTNAME.EXE).csv"
}

$replace_list | Format-Table -AutoSize
$process_list | Format-Table -AutoSize

Write-Host "処理は全て完了しました"
Pause
