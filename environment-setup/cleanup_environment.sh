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

echo -e "${RED}🧹 環境クリーンアップスクリプト${NC}"
echo "=================================================="
echo "⚠️  このスクリプトは以下を削除します："
echo "   - Python仮想環境 (venv/)"
echo "   - Google Drive認証情報"
echo "   - アップロードファイル"
echo "   - ログファイル"
echo ""
echo "📦 システムパッケージは保持されます："
echo "   - Python3, pip, git等の基本ツール"
echo "   - arp-scan, nmap等のネットワークツール"
echo "   - Tailscale VPN"
echo ""

read -p "本当にクリーンアップしますか？ [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "キャンセルしました。"
    exit 0
fi

cd "$(dirname "$0")/.."

echo -e "\n${BLUE}🗑️  ファイル削除中...${NC}"

# Python仮想環境削除
if [ -d "venv" ]; then
    echo "  - 仮想環境削除: venv/"
    rm -rf venv
fi

# Google Drive認証情報削除
if [ -d "monitoring-system/data" ]; then
    echo "  - 認証情報削除: monitoring-system/data/"
    rm -rf monitoring-system/data/credentials/*.json 2>/dev/null || true
    rm -rf monitoring-system/data/uploads/* 2>/dev/null || true
    rm -rf monitoring-system/data/logs/* 2>/dev/null || true
fi

# 一時ファイル削除
echo "  - 一時ファイル削除"
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "*.log" -delete 2>/dev/null || true

# .DS_Store等の不要ファイル削除
find . -name ".DS_Store" -delete 2>/dev/null || true
find . -name "Thumbs.db" -delete 2>/dev/null || true

echo -e "\n${GREEN}✅ クリーンアップ完了！${NC}"
echo "=================================================="
echo "📋 削除されたもの："
echo "  ✅ Python仮想環境"
echo "  ✅ Google Drive認証情報"
echo "  ✅ アップロードファイル"
echo "  ✅ ログファイル"
echo "  ✅ 一時ファイル"
echo ""
echo "📦 保持されたもの："
echo "  ✅ システムパッケージ"
echo "  ✅ アプリケーションコード"
echo "  ✅ 設定ファイル"
echo ""
echo "🚀 再セットアップ："
echo "   ./environment-setup/setup_complete.sh"
echo ""
echo -e "${GREEN}環境が初期状態に戻りました！${NC}"
