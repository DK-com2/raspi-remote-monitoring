#!/bin/bash
# ポート5000競合問題解決スクリプト

set -e

echo "🔧 ポート5000競合問題解決"
echo "========================="
echo ""

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }

SERVICE_NAME="raspi-monitoring"

# ==================== ポート使用状況確認 ====================
log_info "🔍 ポート5000使用状況確認..."

echo ""
echo "現在ポート5000を使用しているプロセス:"
if command -v ss &> /dev/null; then
    ss -tlnp | grep ":5000" || echo "  ポート5000は現在使用されていません"
elif command -v netstat &> /dev/null; then
    netstat -tlnp | grep ":5000" || echo "  ポート5000は現在使用されていません"
else
    lsof -i :5000 2>/dev/null || echo "  ポート確認ツールが見つかりません"
fi

echo ""

# プロセス確認
echo "Pythonプロセス確認:"
ps aux | grep python | grep -v grep || echo "  Pythonプロセスなし"

echo ""

# ==================== 解決方法選択 ====================
log_info "解決方法を選択してください:"
echo "  1) 競合プロセスを停止して5000番ポートを使用"
echo "  2) アプリを5001番ポートに変更"
echo "  3) 手動で調査・解決"
echo "  4) サービスを停止"
echo ""
read -p "選択 (1-4): " -n 1 -r
echo
CHOICE=$REPLY

case $CHOICE in
    "1")
        log_info "🔥 競合プロセス停止モード"
        
        # サービス停止
        if systemctl is-active --quiet ${SERVICE_NAME}.service; then
            log_info "既存サービスを停止..."
            sudo systemctl stop ${SERVICE_NAME}.service
        fi
        
        # ポート5000使用プロセス特定・停止
        log_info "ポート5000使用プロセスを確認..."
        
        PORT_PIDS=$(lsof -ti :5000 2>/dev/null || true)
        if [ -n "$PORT_PIDS" ]; then
            echo "ポート5000を使用しているプロセス:"
            for pid in $PORT_PIDS; do
                ps -p $pid -o pid,ppid,cmd --no-headers 2>/dev/null || echo "PID $pid (既に終了)"
            done
            echo ""
            
            read -p "これらのプロセスを停止しますか？ (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                for pid in $PORT_PIDS; do
                    log_info "プロセス $pid を停止中..."
                    kill $pid 2>/dev/null || true
                done
                
                sleep 3
                
                # 強制終了が必要な場合
                REMAINING_PIDS=$(lsof -ti :5000 2>/dev/null || true)
                if [ -n "$REMAINING_PIDS" ]; then
                    log_warn "強制終了が必要なプロセスがあります"
                    for pid in $REMAINING_PIDS; do
                        kill -9 $pid 2>/dev/null || true
                    done
                fi
                
                log_info "✅ プロセス停止完了"
            fi
        else
            log_info "ポート5000を使用しているプロセスが見つかりません"
        fi
        
        # サービス再起動
        log_info "サービス再起動..."
        sudo systemctl start ${SERVICE_NAME}.service
        sleep 10
        
        if sudo systemctl is-active --quiet ${SERVICE_NAME}.service; then
            log_info "✅ サービス起動成功"
            
            # HTTP確認
            if curl -f -s http://localhost:5000 > /dev/null 2>&1; then
                log_info "✅ HTTP応答確認成功"
                echo ""
                if command -v tailscale &> /dev/null; then
                    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
                    if [ "$TAILSCALE_IP" != "未設定" ]; then
                        echo "🎉 アクセス可能: http://$TAILSCALE_IP:5000"
                    fi
                fi
            else
                log_warn "⚠️ HTTP応答なし（起動中の可能性）"
            fi
        else
            log_error "❌ サービス起動失敗"
            sudo journalctl -u ${SERVICE_NAME}.service -n 10 --no-pager
        fi
        ;;
        
    "2")
        log_info "🔄 ポート5001変更モード"
        
        PROJECT_DIR="$(pwd)/monitoring-system"
        
        # サービス停止
        if systemctl is-active --quiet ${SERVICE_NAME}.service; then
            sudo systemctl stop ${SERVICE_NAME}.service
        fi
        
        # app.py のポート変更
        if [ -f "$PROJECT_DIR/app.py" ]; then
            log_info "app.py のポート番号を5001に変更中..."
            
            # バックアップ作成
            cp "$PROJECT_DIR/app.py" "$PROJECT_DIR/app.py.port5000.backup"
            
            # ポート変更
            sed -i 's/port=5000/port=5001/g' "$PROJECT_DIR/app.py"
            sed -i 's/PORT = 5000/PORT = 5001/g' "$PROJECT_DIR/app.py"
            sed -i 's/:5000/:5001/g' "$PROJECT_DIR/app.py" 2>/dev/null || true
            
            log_info "✅ ポート5001に変更完了"
        else
            log_error "app.pyが見つかりません"
            exit 1
        fi
        
        # サービス再起動
        log_info "サービス再起動..."
        sudo systemctl start ${SERVICE_NAME}.service
        sleep 10
        
        if sudo systemctl is-active --quiet ${SERVICE_NAME}.service; then
            log_info "✅ サービス起動成功（ポート5001）"
            
            # HTTP確認
            if curl -f -s http://localhost:5001 > /dev/null 2>&1; then
                log_info "✅ HTTP応答確認成功（ポート5001）"
                echo ""
                if command -v tailscale &> /dev/null; then
                    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
                    if [ "$TAILSCALE_IP" != "未設定" ]; then
                        echo "🎉 新しいアクセスURL: http://$TAILSCALE_IP:5001"
                        echo ""
                        echo "📱 各機能のURL:"
                        echo "   メイン: http://$TAILSCALE_IP:5001"
                        echo "   録音: http://$TAILSCALE_IP:5001/recording"
                        echo "   Google Drive: http://$TAILSCALE_IP:5001/gdrive"
                    fi
                fi
            else
                log_warn "⚠️ HTTP応答なし（起動中の可能性）"
            fi
        else
            log_error "❌ サービス起動失敗"
            sudo journalctl -u ${SERVICE_NAME}.service -n 10 --no-pager
        fi
        ;;
        
    "3")
        log_info "🔍 手動調査モード"
        echo ""
        echo "詳細な調査コマンド:"
        echo "  sudo systemctl status ${SERVICE_NAME}"
        echo "  sudo journalctl -u ${SERVICE_NAME} -f"
        echo "  ss -tlnp | grep :5000"
        echo "  lsof -i :5000"
        echo "  ps aux | grep python"
        echo ""
        echo "問題解決後:"
        echo "  sudo systemctl restart ${SERVICE_NAME}"
        ;;
        
    "4")
        log_info "🛑 サービス停止モード"
        sudo systemctl stop ${SERVICE_NAME}.service
        sudo systemctl disable ${SERVICE_NAME}.service
        log_info "✅ サービス停止・自動起動無効化完了"
        
        # ポート確認
        if ss -tlnp | grep -q ":5000"; then
            log_warn "⚠️ まだポート5000が使用されています"
            ss -tlnp | grep ":5000"
        else
            log_info "✅ ポート5000解放確認"
        fi
        ;;
        
    *)
        log_error "無効な選択です"
        exit 1
        ;;
esac

echo ""
log_info "🔧 ポート競合問題解決スクリプト完了"

# 現在の状態表示
echo ""
echo "📋 現在の状態:"
echo "サービス状態:"
if sudo systemctl is-active --quiet ${SERVICE_NAME}.service; then
    echo "  ✅ ${SERVICE_NAME}: 稼働中"
else
    echo "  ❌ ${SERVICE_NAME}: 停止中"
fi

echo ""
echo "ポート使用状況:"
ss -tlnp | grep ":500[01]" || echo "  ポート5000/5001は使用されていません"

exit 0
