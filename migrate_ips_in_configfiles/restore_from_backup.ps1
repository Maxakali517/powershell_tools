# ---------------------------------------------------------
# バックアップファイルを元にmigarate_ips_in_configfiles.ps1で置換を行ったファイルを元に戻すスクリプト
# ---------------------------------------------------------

# オプションパラメータ（0：オフ、1：オン）
$dryrun_flag = 0  # ドライランするか
$logging_flag = 1 # 実行ログCSVを出力するか
$remove_backup_flag = 1 # バックアップを削除するか

# dryrun_flag = 0 (ドライランせずに実際に置換を行う)になっている場合、警告を表示する
if (!$dryrun_flag) {
    Write-Host "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
    Write-Host "Enter押下するとバックアップファイルから復元を行います。中止する場合はCtrl + C"
    Write-Host "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
    Pause
    [string]$target_date = Read-Host "バックアップ対象の日付を西暦8ケタで入力してください"
    if ($target_date.Length -ne 8) {
        Write-Host "日付の入力が不正です。処理を中止します。"
        Exit
    }
}

# 変数定義、初期化
$target_paths = Import-Csv ".\target_paths.csv"
$process_list = @() # 各ファイルに対する処理結果の一覧 を定義・初期化
[string]$success_code = "Success" # 処理の成功時に［result_XX］に格納する文字列
[string]$log_prefix_info = "[info]" # コンソールに表示する実行ログ（通常）の先頭文字列
[string]$log_prefix_error = "[Error]" # コンソールに表示する実行ログ（エラー）の先頭文字列

# target_pathsから作業中のサーバ名に一致するレコードのみを抽出し、新たな変数に代入
$my_target_paths = ($target_paths | Where-Object { $_.server_name -eq $(HOSTNAME.EXE) }).ipv4_address

foreach ($my_target_path in $my_target_paths) {
    try {
        [void](Get-Content $my_target_path -ErrorAction Stop)
        $result_get_content = $success_code
        Write-Host "$($log_prefix_info)対象ファイルの取得に成功しました：$($my_target_path)"
    }
    catch {
        $result_get_content = $Error[0].CategoryInfo.Category
        Write-Host "$($log_prefix_error)対象ファイルの取得で［$($result_get_content)］が発生しました：$($my_target_path)"
    }
    try {
        [void](Get-Content "$($my_target_path)_$($target_date).backup" -ErrorAction Stop)
        $result_get_backup = $success_code
        Write-Host "$($log_prefix_info)バックアップファイルの取得に成功しました：$($my_target_path)"
    }
    catch {
        $result_get_backup = $Error[0].CategoryInfo.Category
        Write-Host "$($log_prefix_error)バックアップファイルの取得で［$($result_get_content)］が発生しました：$($my_target_path)"
    }

    # process_listへの行追加
    $process_list += [PSCustomObject]@{
        server_name            = $(HOSTNAME.EXE)
        target_path            = $my_target_path
        result_get_content     = $result_get_content
        result_get_backup      = $result_get_backup
        result_restore_content = ""
        result_remove_backup   = ""
    }
    
}

# バックアップファイルから復元
foreach ($process in $process_list) {
    if ($process.result_get_content -eq $success_code -and $process.result_get_backup -eq $success_code) {
        try {
            Copy-Item `
                -Path "$($process.target_path)_$($target_date).backup" `
                -Destination $process.target_path `
                -ErrorAction Stop
            $process.result_restore_content = $success_code
            Write-Host "$($log_prefix_info)バックアップファイルからの復元に成功しました：$($process.target_path)"
        }
        catch {
            $process.result_restore_content = $Error[0].CategoryInfo.Category
            Write-Host "$($log_prefix_error)バックアップファイルからの復元で［$($process.result_restore_content)］が発生しました：$($process.target_path)"
        }
    }
}
# バックアップを削除
if ($remove_backup_flag) {
    foreach ($process in $process_list) {
        if ($process.result_get_content -eq $success_code -and $process.result_get_backup -eq $success_code) {
            try {
                Remove-Item `
                    -Path "$($process.target_path)_$($target_date).backup" `
                    -ErrorAction Stop
                $process.result_remove_backup = $success_code
                Write-Host "$($log_prefix_info)バックアップファイルの削除に成功しました：$($process.target_path)"
            }
            catch {
                $process.result_remove_backup = $Error[0].CategoryInfo.Category
                Write-Host "$($log_prefix_error)バックアップファイルの削除で［$($process.result_remove_backup)］が発生しました：$($process.target_path)"
            }
        }
    }
}

$process_list | Format-Table -AutoSize

if ($logging_flag) {
    $process_list | Export-Csv -Path ".\restore_log_$(HOSTNAME.EXE).csv"
}