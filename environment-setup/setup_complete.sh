#!/bin/bash
"""
【メイン】統合セットアップスクリプト
すべての環境構築を一括実行
"""

set -e

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Raspberry Pi ネットワーク監視システム${NC}"
echo -e "${BLUE}   統合セットアップスクリプト${NC}"
echo "=================================================="

# Step 1: システム基盤
echo -e "\n${BLUE}📦 Step 1: システム基盤セットアップ${NC}"
sudo apt update
sudo apt install -y python3 python3-pip python3-venv git curl

# Step 2: Python環境
echo -e "\n${BLUE}🐍 Step 2: Python仮想環境作成${NC}"
cd "$(dirname "$0")/.."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip

# Step 3: 基本依存関係
echo -e "\n${BLUE}📦 Step 3: 基本ライブラリインストール${NC}"
pip install Flask==2.3.3 psutil==5.9.5 requests==2.31.0

# Step 4: Google Drive依存関係
echo -e "\n${BLUE}🗂️ Step 4: Google Drive連携ライブラリ${NC}"
pip install PyYAML==6.0.1 google-api-python-client==2.108.0 google-auth-httplib2==0.1.1 google-auth-oauthlib==1.1.0

# Step 5: デバイス検出ツール（ラズパイOS用）
echo -e "\n${BLUE}🔍 Step 5: デバイス検出ツール${NC}"
sudo apt install -y v4l-utils alsa-utils usbutils

# Step 6: Tailscale（オプション）
echo -e "\n${BLUE}🔒 Step 6: Tailscale VPN（オプション）${NC}"
read -p "Tailscaleをインストールしますか？ [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    curl -fsSL https://tailscale.com/install.sh | sh
    echo "Tailscaleインストール完了。認証は手動で実行してください："
    echo "  sudo tailscale up"
fi

echo -e "\n${GREEN}✅ セットアップ完了！${NC}"
echo "=================================================="
echo "📋 インストール内容："
echo "  ✅ Python仮想環境 (venv/)"
echo "  ✅ Flask Webアプリケーション"
echo "  ✅ Google Drive連携機能"
echo "  ✅ デバイス検出機能（カメラ、マイク、GPS）"
echo "  ✅ Tailscale VPN（選択時）"
echo ""
echo "🚀 使用方法："
echo "  1. cd monitoring-system"
echo "  2. source ../venv/bin/activate"
echo "  3. python app.py"
echo "  4. ブラウザでアクセス: http://localhost:5000"
echo ""
echo "📱 Google Drive設定："
echo "  1. Google Cloud Consoleで認証情報作成"
echo "  2. credentials.jsonをdata/credentials/に配置"
echo "  3. 初回アクセス時にブラウザで認証"
