#!/bin/bash
"""
ネットワークツールセットアップスクリプト
監視に必要なネットワークコマンドをインストール
"""

set -e

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🌐 ネットワークツールセットアップ${NC}"
echo "=================================================="

echo -e "\n${YELLOW}📦 必要なネットワークツールをインストール中...${NC}"

# パッケージリスト更新
echo "・パッケージリストを更新中..."
sudo apt update

# 基本ネットワークツール
echo "・基本ネットワークツールをインストール中..."
sudo apt install -y \
    nmap \
    traceroute \
    iputils-ping \
    net-tools \
    dnsutils \
    iperf3 \
    tcpdump \
    netcat-openbsd

# 追加の便利ツール
echo "・追加ネットワークツールをインストール中..."
sudo apt install -y \
    mtr-tiny \
    whois \
    dig \
    host \
    ss \
    iftop \
    nethogs

echo -e "\n${GREEN}✅ ネットワークツールのインストール完了${NC}"

# インストール確認
echo -e "\n${YELLOW}🔍 インストール確認:${NC}"

tools=(
    "nmap:ネットワークスキャン"
    "ping:接続テスト"
    "traceroute:経路追跡"
    "dig:DNS調査"
    "iperf3:速度測定"
    "mtr:統合ネットワーク診断"
)

for tool_info in "${tools[@]}"; do
    tool=$(echo $tool_info | cut -d: -f1)
    desc=$(echo $tool_info | cut -d: -f2)
    
    if command -v $tool &> /dev/null; then
        echo "  ✅ $tool ($desc)"
    else
        echo "  ❌ $tool ($desc)"
    fi
done

# 使用例表示
echo -e "\n${BLUE}📋 主要コマンドの使用例:${NC}"

echo -e "\n${YELLOW}ネットワークスキャン:${NC}"
echo "  nmap -sn 192.168.1.0/24    # ローカルネットワークのデバイス検出"
echo "  nmap -p 1-1000 192.168.1.1 # ポートスキャン"

echo -e "\n${YELLOW}接続テスト:${NC}"
echo "  ping google.com             # 基本接続テスト"
echo "  mtr google.com              # リアルタイム経路追跡"
echo "  traceroute 8.8.8.8          # 経路追跡"

echo -e "\n${YELLOW}DNS調査:${NC}"
echo "  dig google.com              # DNS詳細情報"
echo "  nslookup example.com        # DNS解決テスト"

echo -e "\n${YELLOW}速度測定:${NC}"
echo "  iperf3 -c iperf.he.net     # インターネット速度測定"

echo -e "\n${YELLOW}ネットワーク監視:${NC}"
echo "  ss -tuln                    # 開いているポート一覧"
echo "  netstat -i                  # インターフェース統計"

echo -e "\n${GREEN}🎉 ネットワークツールセットアップ完了！${NC}"
echo "これらのツールはPythonアプリから自動的に使用されます。"
