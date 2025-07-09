#!/bin/bash
# 完全ポートクリア + サービス再起動スクリプト

echo "🔥 ポート5000完全クリア + サービス再起動"
echo "========================================="

SERVICE_NAME="raspi-monitoring"

# 1. サービス停止
echo "1. サービス停止中..."
sudo systemctl stop ${SERVICE_NAME}.service 2>/dev/null || true

# 2. ポート5000使用プロセス全停止
echo "2. ポート5000使用プロセス停止中..."
sudo pkill -f "python.*app.py" 2>/dev/null || true
sudo pkill -f "python.*5000" 2>/dev/null || true

# lsofでポート5000使用プロセスを特定して停止
PORT_PIDS=$(sudo lsof -ti :5000 2>/dev/null || true)
if [ -n "$PORT_PIDS" ]; then
    echo "  ポート5000使用プロセス: $PORT_PIDS"
    for pid in $PORT_PIDS; do
        echo "  プロセス $pid を停止中..."
        sudo kill -9 $pid 2>/dev/null || true
    done
fi

# 3. 少し待機
sleep 3

# 4. ポート確認
echo "3. ポート5000状態確認..."
if sudo lsof -i :5000 2>/dev/null; then
    echo "  ❌ まだポート5000が使用されています"
    echo "  手動で対処が必要です"
    exit 1
else
    echo "  ✅ ポート5000解放確認"
fi

# 5. サービス再起動
echo "4. サービス再起動中..."
sudo systemctl start ${SERVICE_NAME}.service
sleep 10

# 6. 起動確認
echo "5. サービス状態確認..."
if sudo systemctl is-active --quiet ${SERVICE_NAME}.service; then
    echo "  ✅ サービス起動成功"
    
    # HTTP確認
    sleep 5
    if curl -f -s http://localhost:5000 > /dev/null 2>&1; then
        echo "  ✅ HTTP応答確認成功"
        
        # Tailscale IP表示
        if command -v tailscale &> /dev/null; then
            TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
            if [ "$TAILSCALE_IP" != "未設定" ]; then
                echo ""
                echo "🎉 アクセス可能!"
                echo "  📱 Tailscale: http://$TAILSCALE_IP:5000"
                echo "  🖥️  ローカル: http://localhost:5000"
            fi
        fi
    else
        echo "  ⚠️ HTTP応答待機中..."
        echo "  少し待ってから http://localhost:5000 にアクセスしてください"
    fi
else
    echo "  ❌ サービス起動失敗"
    echo ""
    echo "エラーログ:"
    sudo journalctl -u ${SERVICE_NAME}.service -n 10 --no-pager
    exit 1
fi

echo ""
echo "✅ 完了!"
echo ""
echo "確認コマンド:"
echo "  sudo systemctl status ${SERVICE_NAME}"
echo "  sudo lsof -i :5000"
echo "  curl http://localhost:5000"

if command -v tailscale &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
    if [ "$TAILSCALE_IP" != "未設定" ]; then
        echo "  curl http://$TAILSCALE_IP:5000"
    fi
fi
