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
echo -e "\n${YELLOW}📦 Step 1: システム基盤の構築${NC}"
echo "・パッケージマネージャーの更新"
echo "・基本ツールのインストール"

sudo apt update
sudo apt install -y python3 python3-pip python3-venv git curl wget

# Step 2: Python仮想環境
echo -e "\n${YELLOW}🐍 Step 2: Python仮想環境の構築${NC}"

# プロジェクトルートに移動
cd ..

if [ ! -d "venv" ]; then
    echo "・Python仮想環境を作成中..."
    python3 -m venv venv
fi

# 仮想環境有効化
source venv/bin/activate

# pip更新
pip install --upgrade pip

# Step 3: 依存関係インストール
echo -e "\n${YELLOW}📚 Step 3: 依存関係のインストール${NC}"

if [ -f "monitoring-system/requirements.txt" ]; then
    echo "・requirements.txtから依存関係をインストール中..."
    pip install -r monitoring-system/requirements.txt
else
    echo "・基本ライブラリを手動インストール中..."
    pip install flask psutil requests pandas numpy
    pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib
    pip install schedule PyYAML python-dotenv
fi

# Step 4: ネットワークツール
echo -e "\n${YELLOW}🌐 Step 4: ネットワークツールのインストール${NC}"

sudo apt install -y nmap traceroute iputils-ping net-tools dnsutils

# Step 5: Tailscale (オプション)
echo -e "\n${YELLOW}🔗 Step 5: Tailscale VPNのインストール${NC}"

if ! command -v tailscale &> /dev/null; then
    echo "・Tailscaleをインストール中..."
    curl -fsSL https://tailscale.com/install.sh | sh
    echo "✅ Tailscaleインストール完了"
    echo "🔧 認証が必要です: sudo tailscale up"
else
    echo "✅ Tailscaleは既にインストール済み"
fi

# Step 6: ディレクトリ構造確認
echo -e "\n${YELLOW}📁 Step 6: ディレクトリ構造の確認${NC}"

# monitoring-systemフォルダが存在しない場合は作成
if [ ! -d "monitoring-system" ]; then
    echo "・monitoring-systemフォルダを作成中..."
    mkdir -p monitoring-system
fi

# 必要なサブディレクトリ作成
mkdir -p monitoring-system/data/credentials
mkdir -p monitoring-system/data/logs
mkdir -p monitoring-system/templates
mkdir -p monitoring-system/static

echo "✅ ディレクトリ構造を確認しました"

# Step 7: Google Drive認証準備
echo -e "\n${YELLOW}🔐 Step 7: Google Drive認証の準備${NC}"

echo "📋 Google Drive連携の設定手順:"
echo "1. https://console.cloud.google.com/ でプロジェクト作成"
echo "2. Google Drive API を有効化"
echo "3. OAuth 2.0 認証情報を作成（デスクトップアプリ）"
echo "4. credentials.json を monitoring-system/data/credentials/ に配置"
echo "5. python environment-setup/setup_gdrive.py で認証テスト"

# 完了メッセージ
echo -e "\n${GREEN}=================================================="
echo -e "🎉 セットアップ完了！${NC}"
echo "=================================================="

echo -e "\n${BLUE}📋 次のステップ:${NC}"
echo "1. Google Drive認証設定："
echo "   python environment-setup/setup_gdrive.py"
echo ""
echo "2. Tailscale認証（リモートアクセス用）："
echo "   sudo tailscale up"
echo ""
echo "3. アプリケーション起動："
echo "   cd monitoring-system"
echo "   source ../venv/bin/activate"
echo "   python app.py"
echo ""
echo "4. ブラウザでアクセス："
echo "   http://localhost:5000"

echo -e "\n${GREEN}✨ 環境構築が正常に完了しました！${NC}"
