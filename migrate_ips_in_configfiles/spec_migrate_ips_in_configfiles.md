# `migrate_ips_in_configfiles.ps1`仕様書

**設定ファイルフルパスのリスト**と**旧新IPアドレスのリスト**を基にIPアドレスの自動置換を行います。

---

## `migrate_ips_in_configfiles.ps1`と同じディレクトリに必要なCSV

- `target_paths.csv`　→　配列`$target_paths`に対応

| server_name | target_path |
| ----------- | ----------- |
| サーバ名        | 対象ファイルのフルパス |

- `migration_addresses.csv`　→　配列`$migration_addresses`に対応

| old_ipv4_address | placeholder | new_ipv4_address |
| ---------------- | ----------- | ---------------- |
| 旧IPアドレス          | プレースホルダー    | 新IPアドレス          |

---

## オプションパラメータ

* `$dryrun_flag`:
  
  * `0`: ドライランしない（実際に置換を行う）
  
  * `1`: ドライランする（実際に置換を行わない）

* `$backup_flag`:
  
  * `0`: バックアップを作成しない
  
  * `1`: バックアップを作成する

* `$logging_flag`:
  
  * `0`: 実行ログCSVを出力しない
  
  * `1`: 実行ログCSVを出力する
    
    

## 処理概要

1. **ドライランモードの確認**
   
   - ドライランモードが無効な場合、警告メッセージを表示し、一時停止します。

2. **変数定義と初期化**
   
   * CSVファイルからターゲットパスと移行アドレスを読み込み、処理リストと置換リストを初期化します。
   
   * 成功時のコードやログのプレフィックスを設定します。
   
   * `migrate_ips_in_configfiles.ps1`と同じディレクトリファイルにある以下ファイルをそれぞれ`Import-Csv`でロードし、それぞれをオブジェクトの配列として定義する。
     
     * `target_paths.csv`　→　配列`$target_paths`に対応
     
     * `migration_addresses.csv`　→　配列`$migration_addresses`に対応
     
     * 以下はスクリプト内で使用する変数
       
       | 変数名                | 説明                         |
       | ------------------ | -------------------------- |
       | `success_code`     | 処理の成功時に［result_XX］に格納する文字列 |
       | `log_prefix_info`  | コンソールに表示する実行ログ（通常）の先頭文字列   |
       | `log_prefix_error` | コンソールに表示する実行ログ（エラー）の先頭文字列  |

3. **ターゲットパスの取得**
   
   * 作業中のサーバー名に一致するターゲットパスを抽出し、各ファイルについての処理結果を取得します。
   
   * `$target_paths`の`server_name`プロパティが`hostname.exe`の実行結果と一致するレコードのみを抽出し、<br>`$my_target_paths`（`String`の配列）<br>

4. **バックアップの作成（オプション）**
   
   * バックアップを作成するオプションが有効な場合、ターゲットファイルのバックアップを作成します。
   
   * `$process_list`の中で`result_get_content = $success_code`となっている行それぞれに対して対象ファイルと同ディレクトリにバックアップを作成する。形式は以下。<br>`$($process.target_path)_$((Get-Date).ToString("yyyyMMdd")).backup`

5. **置換処理**
   
   * 旧IPアドレスをプレースホルダーに置換し、次にプレースホルダーを新IPアドレスに置換します。
   
   * `$process_list`の中で`result_get_content = $success_code`となっている行それぞれに対して、以下置換を実行する。
     
     1. `$migration_addresses`のそれぞれ（`$i`）に対して`$migration_addresses[$($i)].old_ipv4_address`を`$migration_addresses[$($i)].placeholder`に置き換える。（`$migraton_addresses`の要素数分繰り返す）
     
     2. `$migration_addresses`のそれぞれ（`$i`）に対して`$migration_addresses[$($i)].placeholder`を`$migration_addresses[$($i)].new_ipv4_address`に置き換える。（`$migraton_addresses`の要素数分繰り返す）
   
   * ドライランが無効な場合、置換後の内容でファイルを上書きします。
   
   * 置換結果の差分を取得し、置換リストに追加します。

6. **ログファイルの生成（オプション）**
   
   - 実行ログCSVを出力するオプションが有効な場合、置換リストと処理リストをCSVファイルとして出力します。

7. **処理の完了メッセージ**
   
   - 処理が全て完了したことを示すメッセージを表示し、一時停止します。
     
     

## 出力

- `replace_list_[ホスト名].csv`　→　配列`$replace_list`に対応
  1行1行が置換した行に対応。（`target_paths.csv`よりもレコード数が多くなる）
  
  | server_name | target_path | line_number | before | after |
  | ----------- | ----------- | ----------- | ------ | ----- |
  | サーバ名        | 対象ファイルのフルパス | 置換した行番号     | 置換前    | 置換後   |

- `process_list_[ホスト名].csv`　→　配列`$process_list`に対応
  `target_paths.csv`の`レコード単位で処理結果を記載。
  
  | server_name | target_path | result_get_content | result_backup     | result_set_content |
  | ----------- | ----------- | ------------------ | ----------------- | ------------------ |
  | サーバ名        | 対象ファイルのフルパス | 対象ファイルの取得結果        | 対象ファイルのバックアップ作成結果 | 対象ファイルの上書き結果       |


