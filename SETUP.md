# 🛠️ セットアップガイド

**Raspberry Pi ネットワーク監視システム 統合セットアップガイド**

## 📋 事前準備

### システム要件
- **開発環境**: Windows (WSL2), macOS, Ubuntu
- **本番環境**: Raspberry Pi OS (Bookworm推奨)
- **Python**: 3.10以上
- **ネットワーク**: WiFi/有線/モバイル回線

### 必要なアカウント
- **Google アカウント** (Google Drive連携用)
- **Tailscale アカウント** (リモートアクセス用・無料)

## 🐧 環境構築

### ワンコマンドセットアップ（推奨）

```bash
# 1. プロジェクトをクローン
git clone [your-repo-url] raspi-remote-monitoring
cd raspi-remote-monitoring

# 2. 環境構築スクリプト実行
cd environment-setup
chmod +x setup_complete.sh
./setup_complete.sh
```

**これだけで基本環境が完成します！**（所要時間：5-10分）

### 個別セットアップ（必要な場合のみ）

#### Python環境のみ
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r monitoring-system/requirements.txt
```

#### ネットワークツールのみ
```bash
sudo ./environment-setup/setup_network_tools.sh
```

#### 環境リセット
```bash
./environment-setup/cleanup_environment.sh
./environment-setup/setup_complete.sh
```

## 🔧 アプリケーション設定

### 基本起動テスト

```bash
# 手動起動でテスト
cd monitoring-system
source ../venv/bin/activate
python app.py

# ブラウザでアクセス
# http://localhost:5000
```

### 自動起動設定

#### WSL2/開発環境
```bash
cd app_management
chmod +x app_*.sh
./app_autostart.sh
# → テストモード選択
```

#### Raspberry Pi/本番環境
```bash
cd app_management
sudo ./app_autostart.sh
# → 自動的に本番モード設定
```

### 管理コマンド

```bash
# 状態確認
./app_status.sh

# サービス管理
sudo systemctl start|stop|restart raspi-monitoring

# 自動起動解除
./app_remove_autostart.sh
```

## 📱 追加機能設定

### Google Drive連携

#### 1. Google Cloud Console設定
1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. 新しいプロジェクトを作成
3. Google Drive API を有効化
4. 認証情報 > OAuth 2.0 クライアント ID を作成
   - **アプリケーションタイプ**: デスクトップアプリケーション
5. `credentials.json` をダウンロード

#### 2. 認証ファイル配置
```bash
# ダウンロードしたファイルを配置
cp credentials.json monitoring-system/data/credentials/
```

#### 3. 認証実行
```bash
cd environment-setup
python setup_gdrive.py
# ブラウザで認証を完了
```

#### 4. 接続確認
```bash
# アプリ起動後、ブラウザでアクセス
# http://localhost:5000/gdrive
```

### 録音機能設定

#### 必要パッケージインストール
```bash
# ALSA録音ツール
sudo apt update
sudo apt install -y alsa-utils sox

# 録音デバイス確認
arecord -l
```

#### 音量調整
```bash
# ALSAミキサーで調整
alsamixer

# またはコマンドで調整
amixer set Mic 80%
amixer set Capture 80%
```

#### 録音機能テスト
```bash
# 10秒間テスト録音
arecord -d 10 -f cd test.wav
aplay test.wav

# アプリでの録音テスト
# http://localhost:5000/recording
```

### Tailscale VPN設定

#### 1. アカウント作成
- https://tailscale.com/ で無料アカウント作成
- Google/GitHub/Microsoft アカウント利用可能

#### 2. Raspberry Pi側設定
```bash
# インストール（環境構築で自動実行済み）
curl -fsSL https://tailscale.com/install.sh | sh

# 認証
sudo tailscale up
# 表示されるURLをブラウザで開いて認証
```

#### 3. IPアドレス確認
```bash
tailscale ip -4
# 例: 100.64.1.23
```

#### 4. スマホアプリ設定
1. App Store/Google Play で「Tailscale」をダウンロード
2. 同じアカウントでログイン
3. Raspberry Pi が自動表示される

#### 5. リモートアクセス
```bash
# スマホブラウザで以下にアクセス
# http://[Tailscale IP]:5000
```

## 🎯 本番デプロイ (Raspberry Pi)

### 1. Raspberry Pi OS準備

```bash
# システム更新
sudo apt update && sudo apt upgrade -y

# 基本ツール
sudo apt install -y python3-pip python3-venv git curl wget
sudo apt install -y net-tools wireless-tools v4l-utils
```

### 2. プロジェクト配置

```bash
# Gitクローン（推奨）
git clone [your-repo-url] /home/pi/raspi-remote-monitoring

# または手動コピー
scp -r /path/to/raspi-remote-monitoring pi@[ラズパイIP]:/home/pi/
```

### 3. 自動起動設定

```bash
cd /home/pi/raspi-remote-monitoring
cd environment-setup
./setup_complete.sh

cd ../app_management
sudo ./app_autostart.sh
```

### 4. 動作確認

```bash
# 状態確認
./app_status.sh

# サービス確認
sudo systemctl status raspi-monitoring

# アクセステスト
curl http://localhost:5000
```

### 5. 最終設定

```bash
# Google Drive認証
cd environment-setup
python setup_gdrive.py

# Tailscale認証
sudo tailscale up

# 最終動作確認
cd ../app_management
./app_status.sh
```

## 🔄 更新・メンテナンス

### 定期更新

```bash
# システム更新
sudo apt update && sudo apt upgrade -y

# プロジェクト更新
cd raspi-remote-monitoring
git pull

# 環境更新
cd environment-setup
./reset_and_setup.sh

# 自動起動再設定
cd ../app_management
sudo ./app_autostart.sh
```

### バックアップ

```bash
# 重要ファイルのバックアップ
cp monitoring-system/data/credentials/credentials.json ~/backup/
cp monitoring-system/config.yaml ~/backup/

# 設定情報のバックアップ
sudo systemctl status raspi-monitoring > ~/backup/service_status.txt
tailscale status > ~/backup/tailscale_status.txt
```

### ログ確認

```bash
# アプリケーションログ
sudo journalctl -u raspi-monitoring -f

# システムログ
sudo journalctl --since "1 hour ago"

# エラーログ
sudo journalctl -p err
```

## 🛠️ トラブルシューティング

### 環境構築エラー

```bash
# 権限エラー
chmod +x environment-setup/*.sh
chmod +x app_management/*.sh

# Python環境エラー
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r monitoring-system/requirements.txt

# 依存関係エラー
sudo apt install python3-dev python3-setuptools
pip install --upgrade setuptools wheel
```

### アプリケーションエラー

```bash
# ポート競合
sudo ss -tlnp | grep :5000
sudo pkill -f "python.*app.py"

# サービス起動失敗
sudo systemctl daemon-reload
sudo systemctl reset-failed raspi-monitoring
sudo systemctl restart raspi-monitoring

# 手動起動テスト
cd monitoring-system
source ../venv/bin/activate
python app.py
```

### Google Drive連携エラー

```bash
# 認証リセット
rm monitoring-system/data/credentials/token.json
cd environment-setup
python setup_gdrive.py

# API有効化確認
# Google Cloud Console で Google Drive API が有効か確認

# ファイアウォール問題
# 認証時にポート8080が使用される場合があります
```

### Tailscale接続エラー

```bash
# サービス再起動
sudo systemctl restart tailscaled
sudo tailscale up

# 接続状態確認
tailscale status
tailscale ping [デバイス名]

# デバイス認証リセット
sudo tailscale logout
sudo tailscale up
```

### 録音機能エラー

```bash
# デバイス確認
arecord -l
lsusb

# 権限設定
sudo usermod -a -G audio $USER
# ログアウト・ログインが必要

# 音量調整
alsamixer
amixer set Mic 100%
amixer set Capture 100%

# プロセス確認
ps aux | grep arecord
sudo pkill arecord
```

## 🎯 運用シナリオ

### 現場設置手順

1. **Raspberry Pi 電源オン**
2. **WiFi接続確認** (事前設定推奨)
3. **2-3分待機** → 自動起動完了
4. **Tailscale認証** (初回のみ)
5. **スマホでアクセス開始**

### 日常監視

1. **Tailscaleアプリ起動** (スマホ)
2. **ブラウザアクセス**: `http://[Tailscale IP]:5000`
3. **ネットワーク状態確認**
4. **必要に応じてテスト実行**

### 定期メンテナンス

**月次:**
- アプリケーション状態確認
- システム更新
- ログローテーション

**四半期:**
- Google Drive認証確認
- Tailscale接続テスト
- バックアップ実行

## 🌐 アクセス方法

### ローカルアクセス
- **メイン画面**: `http://localhost:5000`
- **Google Drive**: `http://localhost:5000/gdrive`
- **録音機能**: `http://localhost:5000/recording`

### Tailscale経由アクセス（推奨）
- **メイン画面**: `http://[Tailscale IP]:5000`
- **Google Drive**: `http://[Tailscale IP]:5000/gdrive`
- **録音機能**: `http://[Tailscale IP]:5000/recording`

## 🔒 セキュリティ設定

### 推奨設定

```bash
# UFWファイアウォール
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow from 192.168.0.0/16 to any port 5000  # ローカルネットワークのみ

# SSH設定
sudo nano /etc/ssh/sshd_config
# PasswordAuthentication no  # 鍵認証のみ
# Port 2222                  # デフォルトポート変更
sudo systemctl restart sshd
```

### Tailscale セキュリティ
- デバイス認証必須
- エンドツーエンド暗号化
- 100台まで無料利用可能

---

🎉 **セットアップ完了後は「監視システム運用マニュアル」を参照して日常運用を開始してください。**
