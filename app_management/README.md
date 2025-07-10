# 📱 Raspberry Pi 監視システム - アプリ管理ツール

## 🎯 概要

このディレクトリには、Raspberry Pi 監視システムアプリケーションの起動・停止・管理を行うスクリプトが含まれています。

## 📦 前提条件

- ✅ 環境構築済み（`environment-setup/setup_complete.sh` 実行済み）
- ✅ Python仮想環境作成済み（`venv/`）
- ✅ アプリケーションファイル配置済み（`monitoring-system/app.py`）

## 🚀 スクリプト一覧

### 基本操作

| スクリプト | 機能 | 用途 |
|-----------|------|------|
| `app_start.sh` | アプリ手動起動 | 開発・テスト時の手動起動 |
| `app_stop.sh` | アプリ停止 | アプリケーションの安全な停止 |
| `app_status.sh` | 状態確認 | 詳細な動作状況確認 |

### 自動起動管理

| スクリプト | 機能 | 用途 |
|-----------|------|------|
| `app_autostart.sh` | 自動起動設定 | systemdによる自動起動設定 |
| `app_remove_autostart.sh` | 自動起動解除 | 手動管理モードに切り替え |

## 📋 使用方法

### 1. 初回起動・テスト

```bash
# アプリケーション起動
./app_start.sh

# 状態確認
./app_status.sh

# アプリケーション停止
./app_stop.sh
```

### 2. 自動起動設定（本番環境）

```bash
# 自動起動設定
./app_autostart.sh

# 設定確認
./app_status.sh

# 再起動テスト
sudo reboot
```

### 3. 自動起動解除（開発環境に戻す）

```bash
# 自動起動解除
./app_remove_autostart.sh

# 手動で起動
./app_start.sh
```

## 🔧 実行権限設定

```bash
# 初回のみ実行権限を設定
chmod +x app_*.sh
```

## 📱 アクセス方法

### ローカルアクセス
- **メイン画面**: `http://localhost:5000`
- **録音機能**: `http://localhost:5000/recording`
- **Google Drive**: `http://localhost:5000/gdrive`

### Tailscale経由アクセス（推奨）
```bash
# Tailscale IP確認
tailscale ip -4

# アクセス例
# http://100.73.94.31:5000
```

## 🛠️ トラブルシューティング

### ポート競合エラー
```bash
# 状態確認
./app_status.sh

# 競合プロセス停止
./app_stop.sh

# 再起動
./app_start.sh
```

### 自動起動が動作しない
```bash
# サービス状態確認
sudo systemctl status raspi-monitoring

# ログ確認
sudo journalctl -u raspi-monitoring -f

# 再設定
./app_remove_autostart.sh
./app_autostart.sh
```

### Python仮想環境エラー
```bash
# 環境構築再実行
cd ../environment-setup
./setup_complete.sh

# アプリ再起動
cd ../app_management
./app_start.sh
```

## 📊 状態確認項目

`./app_status.sh` で確認できる項目：

- ✅ **システム情報**: ホスト名、稼働時間、ユーザー
- ✅ **アプリケーション状態**: プロセス、ポート、HTTP応答
- ✅ **Python環境**: 仮想環境、パッケージ
- ✅ **systemdサービス**: 自動起動設定
- ✅ **ネットワーク**: ローカルIP、Tailscale状態
- ✅ **ファイル構造**: 重要ファイルの存在確認

## 🔒 セキュリティ考慮事項

### Tailscale使用（推奨）
- ✅ VPN経由の安全なアクセス
- ✅ 公開IPからの直接アクセス不要
- ✅ デバイス認証による接続制限

### ローカルネットワーク使用時
- ⚠️ ファイアウォール設定推奨
- ⚠️ アクセス制限の検討

## 📝 ログ管理

### アプリケーションログ
```bash
# systemdログ確認
sudo journalctl -u raspi-monitoring -f

# 過去のログ確認
sudo journalctl -u raspi-monitoring --since "1 hour ago"
```

### 手動起動時のログ
```bash
# 手動起動時は標準出力に表示
./app_start.sh
# Ctrl+C で停止
```

## 🔄 定期メンテナンス

### 月次メンテナンス
```bash
# 状態確認
./app_status.sh

# システム更新
sudo apt update && sudo apt upgrade

# アプリ再起動
sudo systemctl restart raspi-monitoring
```

### 環境更新時
```bash
# git更新後
git pull

# 環境再構築
cd environment-setup
./reset_and_setup.sh

# 自動起動再設定
cd ../app_management
./app_autostart.sh
```

## 🎯 使用シナリオ

### 開発・テスト環境
1. `./app_start.sh` で手動起動
2. 開発・テスト実行
3. `./app_stop.sh` で停止

### 本番環境（Raspberry Pi）
1. `./app_autostart.sh` で自動起動設定
2. `sudo reboot` で動作確認
3. 定期的に `./app_status.sh` で状態確認

### 一時的な手動管理
1. `./app_remove_autostart.sh` で自動起動解除
2. `./app_start.sh` で手動起動
3. 必要に応じて `./app_autostart.sh` で再設定

## 📞 サポート情報

### 一般的な問題と解決方法

| 問題 | 原因 | 解決方法 |
|------|------|----------|
| アプリが起動しない | 環境構築不完全 | `environment-setup/setup_complete.sh` 再実行 |
| ポート競合エラー | 他のプロセスが使用中 | `./app_stop.sh` → `./app_start.sh` |
| HTTP応答なし | アプリケーションエラー | `sudo journalctl -u raspi-monitoring` でログ確認 |
| Tailscaleアクセス不可 | Tailscale未接続 | `sudo tailscale up` で接続 |
| 自動起動しない | サービス設定エラー | `./app_autostart.sh` 再実行 |

### 緊急時の対応

```bash
# すべてのプロセス強制停止
sudo pkill -f "python.*app.py"
sudo fuser -k 5000/tcp

# サービス完全リセット
./app_remove_autostart.sh
./app_autostart.sh

# 環境完全リセット
cd ../environment-setup
./reset_and_setup.sh
cd ../app_management
./app_autostart.sh
```

## 🔧 カスタマイズ

### ポート番号変更
1. `monitoring-system/config.yaml` の `port` 値を変更
2. スクリプト内の `:5000` を新しいポートに変更

### サービス名変更
1. 各スクリプトの `SERVICE_NAME` 変数を変更
2. systemdサービスを再作成

### 待機時間調整
1. `app_autostart.sh` の `ExecStartPre=/bin/sleep 15` を調整
2. 起動待機時間を環境に合わせて調整

---

📱 **Raspberry Pi 監視システム アプリ管理ツール**  
🔗 **Tailscale経由でどこからでもアクセス可能**  
⚙️ **systemdによる安定した自動起動**
