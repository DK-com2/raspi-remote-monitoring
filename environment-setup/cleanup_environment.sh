#!/bin/bash
"""
環境クリーンアップスクリプト
プロジェクトを初期状態に戻します
"""

set -e

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧹 環境クリーンアップスクリプト${NC}"
echo "=================================================="

# プロジェクトルートに移動
cd ..

echo -e "\n${YELLOW}🔍 現在の環境を確認中...${NC}"

# 仮想環境の確認
if [ -d "venv" ]; then
    echo "✅ Python仮想環境が見つかりました"
    VENV_EXISTS=true
else
    echo "❌ Python仮想環境が見つかりません"
    VENV_EXISTS=false
fi

# プロセス確認
if pgrep -f "python.*app.py" > /dev/null; then
    echo "⚠️  Flaskアプリが実行中です"
    echo "🛑 アプリを停止してください: Ctrl+C または kill コマンド"
    read -p "続行しますか？ [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ クリーンアップを中止しました"
        exit 1
    fi
fi

echo -e "\n${YELLOW}🗑️  クリーンアップを開始します...${NC}"

# Step 1: Python仮想環境の削除
if [ "$VENV_EXISTS" = true ]; then
    echo "・Python仮想環境を削除中..."
    
    # 仮想環境が有効化されている場合は無効化
    if [ -n "$VIRTUAL_ENV" ]; then
        deactivate 2>/dev/null || true
    fi
    
    rm -rf venv
    echo "✅ Python仮想環境を削除しました"
else
    echo "ℹ️  Python仮想環境は存在しません（スキップ）"
fi

# Step 2: 一時ファイルの削除
echo -e "\n${YELLOW}🧹 一時ファイルを削除中...${NC}"

# Python キャッシュファイル
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true
find . -type f -name "*.pyo" -delete 2>/dev/null || true

# ログファイル
if [ -d "monitoring-system/data/logs" ]; then
    rm -rf monitoring-system/data/logs/*
    echo "✅ ログファイルを削除しました"
fi

# Google Drive認証トークン（credentials.jsonは保持）
if [ -f "monitoring-system/data/credentials/token.json" ]; then
    rm -f monitoring-system/data/credentials/token.json
    echo "✅ Google Drive認証トークンを削除しました"
fi

# 一時的なテストファイル
find . -name "test_*.json" -delete 2>/dev/null || true
find . -name "*.tmp" -delete 2>/dev/null || true

echo "✅ 一時ファイルの削除が完了しました"

# Step 3: システムパッケージの確認
echo -e "\n${YELLOW}📦 システムパッケージの確認...${NC}"

echo "ℹ️  以下のパッケージがインストールされています:"
PACKAGES="python3 python3-pip python3-venv nmap traceroute tailscale"

for package in $PACKAGES; do
    if dpkg -l | grep -q "^ii.*$package "; then
        echo "  ✅ $package"
    else
        echo "  ❌ $package (未インストール)"
    fi
done

echo -e "\n${BLUE}💡 Note: システムパッケージは削除されません${NC}"
echo "   必要に応じて手動で削除してください:"
echo "   sudo apt remove nmap traceroute"
echo "   sudo apt remove --purge tailscale"

# 完了メッセージ
echo -e "\n${GREEN}=================================================="
echo -e "🎉 クリーンアップ完了！${NC}"
echo "=================================================="

echo -e "\n${BLUE}📋 次のステップ:${NC}"
echo "1. 環境を再構築する場合："
echo "   ./environment-setup/setup_complete.sh"
echo ""
echo "2. 完全リセット（推奨）："
echo "   ./environment-setup/reset_and_setup.sh"
echo ""
echo "3. 個別セットアップ："
echo "   - Google Drive認証: python environment-setup/setup_gdrive.py"
echo "   - Tailscale認証: sudo tailscale up"

echo -e "\n${GREEN}✨ 環境が初期状態に戻りました${NC}"
