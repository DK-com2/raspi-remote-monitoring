#!/bin/bash
# ブラウザ更新頻度カスタマイズスクリプト

echo "ブラウザ更新頻度変更ツール"
echo "========================="

PROJECT_DIR="$(pwd)"
HTML_FILE="$PROJECT_DIR/templates/network_monitor.html"

if [ ! -f "$HTML_FILE" ]; then
    echo "エラー: network_monitor.html が見つかりません"
    exit 1
fi

# 現在の設定表示
CURRENT_INTERVAL=$(grep -o 'setInterval(updateNetworkStatus, [0-9]*' "$HTML_FILE" | grep -o '[0-9]*')

if [ -n "$CURRENT_INTERVAL" ]; then
    CURRENT_SECONDS=$((CURRENT_INTERVAL / 1000))
    echo "現在の更新間隔: ${CURRENT_SECONDS}秒"
else
    echo "現在の設定が取得できませんでした"
    exit 1
fi

echo ""
echo "新しい更新間隔を選択してください:"
echo "  1) 3秒  (高頻度監視)"
echo "  2) 5秒  (現在のデフォルト)"
echo "  3) 10秒 (バランス型)"
echo "  4) 15秒 (省電力)"
echo "  5) 30秒 (低頻度)"
echo "  6) カスタム"

read -p "選択 (1-6): " choice

case $choice in
    1) NEW_INTERVAL=3000 ;;
    2) NEW_INTERVAL=5000 ;;
    3) NEW_INTERVAL=10000 ;;
    4) NEW_INTERVAL=15000 ;;
    5) NEW_INTERVAL=30000 ;;
    6) 
        read -p "更新間隔を秒数で入力: " custom_seconds
        if [[ "$custom_seconds" =~ ^[0-9]+$ ]] && [ "$custom_seconds" -ge 1 ]; then
            NEW_INTERVAL=$((custom_seconds * 1000))
        else
            echo "無効な入力です"
            exit 1
        fi
        ;;
    *)
        echo "無効な選択です"
        exit 1
        ;;
esac

# バックアップ作成
cp "$HTML_FILE" "$HTML_FILE.backup"

# 設定変更
sed -i "s/setInterval(updateNetworkStatus, [0-9]*/setInterval(updateNetworkStatus, $NEW_INTERVAL/" "$HTML_FILE"

NEW_SECONDS=$((NEW_INTERVAL / 1000))
echo ""
echo "✅ 更新間隔を ${NEW_SECONDS}秒 に変更しました"

# サービス再起動（本番環境の場合）
if systemctl is-active --quiet network-monitor 2>/dev/null; then
    echo ""
    read -p "サービスを再起動しますか？ (y/N): " restart
    if [[ $restart =~ ^[Yy]$ ]]; then
        sudo systemctl restart network-monitor
        echo "✅ サービス再起動完了"
    else
        echo "手動でサービス再起動してください: sudo systemctl restart network-monitor"
    fi
fi

echo ""
echo "予想されるRaspberry Pi負荷:"
case $NEW_SECONDS in
    3) echo "  CPU使用率: 0.8%程度 (高頻度)" ;;
    5) echo "  CPU使用率: 0.5%程度 (標準)" ;;
    10) echo "  CPU使用率: 0.3%程度 (バランス)" ;;
    15) echo "  CPU使用率: 0.2%程度 (省電力)" ;;
    30) echo "  CPU使用率: 0.1%程度 (低負荷)" ;;
    *) echo "  CPU使用率: カスタム設定" ;;
esac

echo ""
echo "変更を元に戻す場合:"
echo "  cp $HTML_FILE.backup $HTML_FILE"