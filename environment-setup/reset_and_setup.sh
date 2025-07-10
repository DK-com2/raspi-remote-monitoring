#!/bin/bash
"""
完全クリーンアップ + 再セットアップスクリプト
環境をリセットして最新状態で再構築します
"""

set -e

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔄 完全リセット + 再セットアップ${NC}"
echo "=================================================="

echo -e "\n${YELLOW}⚠️  この操作は以下を実行します:${NC}"
echo "1. 既存の仮想環境を完全削除"
echo "2. 一時ファイル・キャッシュをクリア"
echo "3. 最新の環境を再構築"
echo ""
echo -e "${RED}Note: Google Drive認証情報（credentials.json）は保持されます${NC}"

# 確認
read -p "続行しますか？ [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ リセットを中止しました"
    exit 1
fi

echo -e "\n${BLUE}🚀 リセット処理を開始します...${NC}"

# Step 1: クリーンアップ実行
echo -e "\n${YELLOW}📍 Phase 1: 環境のクリーンアップ${NC}"
echo "現在の環境を削除中..."

# cleanup_environment.sh を実行
if [ -f "cleanup_environment.sh" ]; then
    # 対話モードを無効化して自動実行
    bash cleanup_environment.sh
else
    echo "❌ cleanup_environment.sh が見つかりません"
    exit 1
fi

# 少し待機
echo "⏳ クリーンアップ完了を確認中..."
sleep 2

# Step 2: 再セットアップ実行
echo -e "\n${YELLOW}📍 Phase 2: 環境の再構築${NC}"
echo "最新の環境をセットアップ中..."

# setup_complete.sh を実行
if [ -f "setup_complete.sh" ]; then
    bash setup_complete.sh
else
    echo "❌ setup_complete.sh が見つかりません"
    exit 1
fi

# Step 3: 認証状態の確認
echo -e "\n${YELLOW}📍 Phase 3: 認証状態の確認${NC}"

# プロジェクトルートに移動
cd ..

# Google Drive認証ファイル確認
if [ -f "monitoring-system/data/credentials/credentials.json" ]; then
    echo "✅ Google Drive認証ファイルが保持されています"
    echo "🔧 認証テストを実行するには:"
    echo "   python environment-setup/setup_gdrive.py"
else
    echo "⚠️  Google Drive認証ファイル（credentials.json）が見つかりません"
    echo "📋 設定が必要です"
fi

# Tailscale状態確認
if command -v tailscale &> /dev/null; then
    echo "✅ Tailscaleがインストール済み"
    
    if tailscale status &> /dev/null; then
        echo "✅ Tailscale認証済み"
        echo "🌐 Tailscale IP: $(tailscale ip -4 2>/dev/null || echo '取得失敗')"
    else
        echo "🔧 Tailscale認証が必要です:"
        echo "   sudo tailscale up"
    fi
else
    echo "❌ Tailscaleがインストールされていません"
fi

# Step 4: 動作確認
echo -e "\n${YELLOW}📍 Phase 4: 動作確認${NC}"

# 仮想環境の確認
if [ -d "venv" ]; then
    echo "✅ Python仮想環境が作成されました"
    
    # 仮想環境内のライブラリ確認
    source venv/bin/activate
    
    echo "🔍 主要ライブラリの確認:"
    python -c "
import sys
libraries = ['flask', 'psutil', 'requests', 'pandas']
for lib in libraries:
    try:
        __import__(lib)
        print(f'  ✅ {lib}')
    except ImportError:
        print(f'  ❌ {lib}')
" 2>/dev/null

    deactivate
else
    echo "❌ Python仮想環境の作成に失敗しました"
fi

# 完了メッセージ
echo -e "\n${GREEN}=================================================="
echo -e "🎉 完全リセット + 再セットアップ完了！${NC}"
echo "=================================================="

echo -e "\n${BLUE}📋 次のアクション:${NC}"

echo -e "\n${YELLOW}1. Google Drive認証（必須）:${NC}"
echo "   cd environment-setup"
echo "   python setup_gdrive.py"

echo -e "\n${YELLOW}2. Tailscale認証（リモートアクセス用）:${NC}"
echo "   sudo tailscale up"

echo -e "\n${YELLOW}3. アプリケーション起動:${NC}"
echo "   cd monitoring-system"
echo "   source ../venv/bin/activate"
echo "   python app.py"

echo -e "\n${YELLOW}4. ブラウザでアクセス:${NC}"
echo "   http://localhost:5000"

echo -e "\n${GREEN}✨ 環境が最新状態で再構築されました！${NC}"
