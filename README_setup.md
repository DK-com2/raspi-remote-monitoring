# Raspberry Pi 監視システム 自動起動スクリプト

## 🚀 setup_autostart.sh の使用方法

### 実行前の準備

1. **実行権限を付与**
   ```bash
   chmod +x setup_autostart.sh
   ```

2. **必要なディレクトリ構造の確認**
   ```
   raspi-remote-monitoring/
   ├── setup_autostart.sh          # このスクリプト
   ├── monitoring-system/          # プロジェクトディレクトリ
   │   ├── app.py                   # メインアプリケーション
   │   ├── config.yaml              # 設定ファイル
   │   ├── requirements.txt         # Python依存関係
   │   └── modules/                 # モジュールディレクトリ
   │       ├── network/
   │       ├── recording/
   │       └── gdrive/
   └── venv/                        # Python仮想環境
   ```

### 🛠️ 実行モード

スクリプトを実行すると以下の選択肢が表示されます：

#### 1) 🏠 新規セットアップ（初回インストール）
- 初回セットアップ用
- 環境自動検出（WSL2/Raspberry Pi/Linux）
- Python依存関係のインストール
- systemdサービスの設定
- 自動起動化設定

#### 2) 🔄 環境リセット（更新準備）
- 既存設定のクリーンアップ
- 重要ファイルのバックアップ
- Python環境の再作成
- 更新準備用

#### 3) 🧪 テストモード（手動起動・終了）
- 本番設定でのテスト実行
- Ctrl+Cで停止可能
- systemd設定なしでテスト
- 開発・デバッグ用

#### 4) 📋 状態確認（現在の設定表示）
- 現在のシステム状態確認
- サービス状態の表示
- ネットワーク情報表示
- ログやバックアップ情報

#### 5) 🗑️ 完全アンインストール（全削除）
- 全てのファイルとサービスを削除
- 完全な環境のクリーンアップ
- **注意: すべてのデータが削除されます**

### 📱 実行方法

```bash
# スクリプト実行
./setup_autostart.sh

# 選択肢から数字を入力（1-5）
選択 (1-5): 1
```

### 🔧 環境別の動作

#### WSL2環境
- systemdの有効化確認
- テストモードまたは本番モード選択
- Windows環境での開発テスト対応

#### Raspberry Pi環境
- 自動的に本番モード
- systemdサービス自動設定
- 音声デバイス権限設定
- Tailscale連携設定

#### 一般Linux環境
- 本番/テストモード選択
- 基本的なLinux環境対応

### 📂 作成されるファイル

#### 本番モード実行後
- `/etc/systemd/system/raspi-monitoring.service` - systemdサービス
- `./test_autostart.sh` - 自動起動テスト用スクリプト
- `./system_info.txt` - システム設定情報
- `./backup_YYYYMMDD_HHMMSS/` - バックアップディレクトリ（リセット時）

### 🌐 アクセス方法

#### ローカルアクセス
- メイン画面: `http://localhost:5000`
- 録音機能: `http://localhost:5000/recording`
- Google Drive: `http://localhost:5000/gdrive`

#### Tailscaleアクセス（推奨）
- メイン画面: `http://[TailscaleのIP]:5000`
- 録音機能: `http://[TailscaleのIP]:5000/recording`
- Google Drive: `http://[TailscaleのIP]:5000/gdrive`

### 🔧 管理コマンド

```bash
# サービス状態確認
sudo systemctl status raspi-monitoring

# サービス再起動
sudo systemctl restart raspi-monitoring

# ログ監視
sudo journalctl -u raspi-monitoring -f

# 自動起動テスト
./test_autostart.sh

# 自動起動無効化
sudo systemctl disable raspi-monitoring
```

### ☁️ Google Drive設定

1. **Google Cloud Console でプロジェクト作成**
   - https://console.cloud.google.com/

2. **Drive API を有効化**
   - APIとサービス → ライブラリ → Google Drive API

3. **認証情報の作成**
   - APIとサービス → 認証情報 → サービスアカウント作成
   - JSONキーをダウンロード

4. **認証ファイルの配置**
   ```bash
   cp downloaded-credentials.json ./data/credentials/credentials.json
   ```

### 🛡️ セキュリティ設定

- systemdサービスは最小権限で実行
- Tailscale VPN経由での安全なアクセス
- UFWファイアウォール設定（SSH許可のみ）
- プライベートテンポラリディレクトリ使用

### ⚠️ トラブルシューティング

#### サービスが起動しない場合
```bash
# ログ確認
sudo journalctl -u raspi-monitoring -n 50

# 手動起動テスト
cd monitoring-system
source ../venv/bin/activate
python app.py
```

#### ポート5000が使用中の場合
```bash
# ポート使用状況確認
sudo ss -tlnp | grep :5000

# プロセス終了
sudo pkill -f "python.*app.py"
```

#### Python依存関係のエラー
```bash
# 仮想環境再作成
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r monitoring-system/requirements.txt
```

### 📝 ログファイル

- システムログ: `sudo journalctl -u raspi-monitoring`
- アプリケーションログ: アプリケーション内のログ機能を使用
- エラーログ: systemdジャーナルに出力

### 🔄 更新手順

1. 環境リセット実行
   ```bash
   ./setup_autostart.sh
   # 選択: 2 (環境リセット)
   ```

2. 新しいプログラムを `monitoring-system/` にコピー

3. 新規セットアップ実行
   ```bash
   ./setup_autostart.sh
   # 選択: 1 (新規セットアップ)
   ```

このスクリプトにより、Raspberry Pi監視システムの完全な自動起動化が実現できます。
