# 🔧 環境構築ツール

**Raspberry Pi ネットワーク監視システム 環境構築専用**

## 🎯 概要

このディレクトリには、システム環境を自動構築するためのスクリプトが含まれています。

## 📦 スクリプト一覧

### メイン構築スクリプト

| スクリプト | 機能 | 用途 |
|-----------|------|------|
| `setup_complete.sh` | 統合セットアップ | **推奨**: 全環境を自動構築 |
| `setup_network_tools.sh` | ネットワークツール | 監視ツールのインストール |
| `setup_gdrive.py` | Google Drive認証 | クラウド連携設定 |

### メンテナンススクリプト

| スクリプト | 機能 | 用途 |
|-----------|------|------|
| `cleanup_environment.sh` | 環境クリーンアップ | 一時ファイル・キャッシュ削除 |
| `reset_and_setup.sh` | 完全リセット | 環境リセット+再構築 |

## 🚀 基本的な使用方法

### 1. 初回セットアップ（推奨）

```bash
# プロジェクトディレクトリで実行
cd environment-setup
chmod +x *.sh
./setup_complete.sh
```

**これだけで完了！** 以下が自動実行されます：
- システムパッケージ更新
- Python仮想環境作成
- 依存関係インストール
- ネットワークツール導入
- Tailscale VPNインストール

### 2. Google Drive認証設定

```bash
# 認証ファイル配置後に実行
python setup_gdrive.py
```

## 🔧 個別スクリプトの使用

### ネットワークツールのみインストール

```bash
sudo ./setup_network_tools.sh
```

**インストールされるツール:**
- nmap（ネットワークスキャン）
- traceroute（経路追跡）  
- wireless-tools（WiFi監視）
- net-tools（基本ネットワーク）
- dnsutils（DNS診断）

### 環境のクリーンアップ

```bash
# 一時ファイル削除
./cleanup_environment.sh

# 完全リセット + 再構築
./reset_and_setup.sh
```

## 🎯 対応環境

### 自動検出される環境

- **Raspberry Pi**: 自動的に本番モードで設定
- **WSL2**: テスト・開発モード
- **Ubuntu/Debian**: 手動選択可能
- **その他Linux**: 基本的な互換モード

### 動作確認済み環境

- Raspberry Pi OS (Bullseye/Bookworm)
- Ubuntu 20.04 LTS / 22.04 LTS
- Debian 11 / 12
- Windows WSL2 (Ubuntu)

## 🛠️ トラブルシューティング

### 権限エラー
```bash
# 実行権限付与
chmod +x *.sh

# sudoでのスクリプト実行
sudo ./setup_complete.sh
```

### パッケージインストールエラー
```bash
# パッケージリスト更新
sudo apt update

# 壊れた依存関係修復
sudo apt --fix-broken install

# 再試行
./setup_complete.sh
```

### Python環境エラー
```bash
# Python開発パッケージ
sudo apt install python3-dev python3-setuptools

# pip更新
python3 -m pip install --upgrade pip

# 仮想環境再作成
rm -rf ../venv
python3 -m venv ../venv
```

### ネットワークツールエラー
```bash
# 個別インストール
sudo apt install net-tools wireless-tools iputils-ping
sudo apt install nmap traceroute dnsutils
```

## 📋 セットアップ詳細

### setup_complete.sh の実行内容

1. **システム基盤構築**
   - パッケージマネージャー更新
   - 基本ツールインストール
   - Python環境確認

2. **Python仮想環境**
   - venv作成（../venv/）
   - pip更新
   - requirements.txtインストール

3. **ネットワークツール**
   - 監視用コマンドインストール
   - 疎通テストツール導入

4. **Tailscale VPN**
   - 公式インストーラー実行
   - サービス有効化

5. **ディレクトリ構造**
   - 必要フォルダ作成
   - 権限設定

### cleanup_environment.sh の動作

1. **プロセス確認**
   - 実行中アプリ検出
   - 安全停止確認

2. **ファイル削除**
   - Python仮想環境削除
   - キャッシュファイル削除
   - 一時ファイル削除

3. **設定保持**
   - credentials.json保持
   - config.yaml保持
   - 重要設定ファイル保護

## 🔄 更新・メンテナンス

### 環境更新手順

```bash
# 1. 最新コード取得
git pull

# 2. 環境リセット
./reset_and_setup.sh

# 3. アプリ再起動
cd ../app_management
sudo ./app_autostart.sh
```

### 定期メンテナンス

```bash
# 月次：パッケージ更新
sudo apt update && sudo apt upgrade

# 四半期：完全リフレッシュ
./reset_and_setup.sh
```

## 📊 作成されるファイル・フォルダ

### プロジェクト構造
```
raspi-remote-monitoring/
├── venv/                    # Python仮想環境
├── monitoring-system/       # メインアプリ
│   ├── data/               # データ保存
│   │   ├── credentials/    # 認証情報
│   │   ├── recordings/     # 録音ファイル
│   │   └── logs/          # ログファイル
│   └── requirements.txt    # Python依存関係
└── environment-setup/       # このディレクトリ
```

### システムファイル（本番環境のみ）
- `/etc/systemd/system/raspi-monitoring.service`
- `/usr/local/bin/tailscale`

## 🎯 次のステップ

環境構築完了後：

1. **Google Drive認証設定**
   ```bash
   python setup_gdrive.py
   ```

2. **アプリケーション起動**
   ```bash
   cd ../app_management
   ./app_autostart.sh
   ```

3. **動作確認**
   ```bash
   ./app_status.sh
   ```

4. **ブラウザアクセス**
   - http://localhost:5000

---

🔧 **環境構築に関する質問は、メインの [セットアップガイド](../SETUP.md) も参照してください。**
