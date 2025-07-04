# Raspberry Pi デプロイメントガイド

## 🍓 Raspberry Pi セットアップ手順

### 前提条件
- Raspberry Pi OS (Bookworm推奨)
- Python 3.10以上
- インターネット接続

### 1. システム更新
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3-pip python3-venv git
```

### 2. 必要なシステムツールインストール
```bash
# ネットワーク監視ツール
sudo apt install -y net-tools wireless-tools v4l-utils

# オーディオ・ビデオデバイス検出用
sudo apt install -y alsa-utils pulseaudio

# GPSデバイス用（オプション）
sudo apt install -y gpsd gpsd-clients
```

### 3. プロジェクトの配置
```bash
# Gitでクローン（推奨）
git clone [あなたのリポジトリURL] /home/pi/raspi-remote-monitoring

# または、手動コピー
scp -r S:\python\raspi-remote-monitoring pi@[ラズパイIP]:/home/pi/
```

### 4. Python環境セットアップ
```bash
cd /home/pi/raspi-remote-monitoring

# 仮想環境作成
python3 -m venv venv
source venv/bin/activate

# 依存関係インストール
pip install -r monitoring-system/requirements.txt
```

### 5. Google Drive認証
```bash
# 認証ファイルを配置
# WindowsからCredentials.jsonをコピー
scp S:\python\raspi-remote-monitoring\monitoring-system\data\credentials\credentials.json pi@[ラズパイIP]:/home/pi/raspi-remote-monitoring/monitoring-system/data/credentials/

# 認証実行（ブラウザ認証が必要）
cd monitoring-system
python test_gdrive_auth.py
```

### 6. 自動起動設定
```bash
# systemdサービス作成
sudo cp autostart_setup_unified.sh /home/pi/
sudo chmod +x /home/pi/autostart_setup_unified.sh
sudo /home/pi/autostart_setup_unified.sh
```

## 🔧 Raspberry Pi特有の調整

### ネットワーク監視の最適化
- WiFi信号強度監視の精度向上
- 有線/無線の自動判別
- Tailscale統合

### デバイス検出の拡張
- CSIカメラモジュール対応
- USB Webカメラ対応
- I2Cセンサー対応準備

### パフォーマンス最適化
- メモリ使用量の最適化
- CPU負荷の軽減
- バックグラウンド処理の調整

## 🌐 アクセス方法

### ローカルネットワーク
- http://[ラズパイIP]:5000

### Tailscale（推奨）
- http://[Tailscale IP]:5000
- 外部からの安全なアクセス

### Dynamic DNS（オプション）
- 固定ドメイン名でのアクセス
