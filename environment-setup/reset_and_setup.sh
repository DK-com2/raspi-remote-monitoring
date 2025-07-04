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

echo -e "${YELLOW}🔄 完全リセット + 再セットアップ${NC}"
echo "=================================================="
echo "このスクリプトは以下を実行します："
echo "1. 環境クリーンアップ"
echo "2. 最新セットアップ実行"
echo ""

read -p "実行しますか？ [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "キャンセルしました。"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Step 1: クリーンアップ
echo -e "\n${BLUE}Step 1: 環境クリーンアップ${NC}"
if [ -f "$SCRIPT_DIR/cleanup_environment.sh" ]; then
    bash "$SCRIPT_DIR/cleanup_environment.sh"
else
    echo -e "${RED}cleanup_environment.sh が見つかりません${NC}"
    exit 1
fi

# Step 2: 再セットアップ
echo -e "\n${BLUE}Step 2: 再セットアップ実行${NC}"
if [ -f "$SCRIPT_DIR/setup_complete.sh" ]; then
    bash "$SCRIPT_DIR/setup_complete.sh"
else
    echo -e "${RED}setup_complete.sh が見つかりません${NC}"
    exit 1
fi

echo -e "\n${GREEN}🎉 完全リセット + 再セットアップ完了！${NC}"
echo "環境が最新状態で再構築されました。"
