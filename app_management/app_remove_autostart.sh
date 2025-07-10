#!/bin/bash
# Raspberry Pi 監視システム - 自動起動解除スクリプト

set -e

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

echo "🗑️ Raspberry Pi 監視システム - 自動起動解除"
echo "============================================"

SERVICE_NAME="raspi-monitoring"

# ==================== 現在の状態確認 ====================
log_info "📋 現在の自動起動状態確認..."

if systemctl list-unit-files | grep -q "^$SERVICE_NAME.service"; then
    echo "  📄 サービスファイル: 存在"
    
    if systemctl is-active --quiet "$SERVICE_NAME.service"; then
        echo "  🟢 サービス状態: 稼働中"
    else
        echo "  🔴 サービス状態: 停止中"
    fi
    
    if systemctl is-enabled "$SERVICE_NAME.service" >/dev/null 2>&1; then
        echo "  ✅ 自動起動: 有効"
    else
        echo "  ❌ 自動起動: 無効"
    fi
    
    # サービス詳細表示
    echo ""
    echo "  サービス詳細:"
    sudo systemctl status "$SERVICE_NAME.service" --no-pager -l | head -10
else
    log_info "✅ $SERVICE_NAME.service は設定されていません"
    echo ""
    echo "他の関連サービス確認:"
    
    OTHER_SERVICES=("network-monitor" "monitoring" "flask-app" "raspberry-pi-monitor")
    FOUND_SERVICES=()
    
    for SERVICE in "${OTHER_SERVICES[@]}"; do
        if systemctl list-unit-files | grep -q "^$SERVICE.service"; then
            FOUND_SERVICES+=("$SERVICE")
            echo "  📄 $SERVICE.service: 存在"
        fi
    done
    
    if [ ${#FOUND_SERVICES[@]} -eq 0 ]; then
        log_info "関連する自動起動サービスは見つかりませんでした"
        echo ""
        echo "🎉 自動起動設定はありません！"
        echo ""
        echo "🔧 手動でアプリを管理:"
        echo "   ./app_start.sh               # アプリ起動"
        echo "   ./app_stop.sh                # アプリ停止"
        echo "   ./app_status.sh              # 状態確認"
        echo "   ./app_autostart.sh           # 自動起動設定"
        exit 0
    else
        echo ""
        read -p "他の関連サービスも削除しますか？ (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for SERVICE in "${FOUND_SERVICES[@]}"; do
                log_info "$SERVICE.service を削除中..."
                sudo systemctl stop "$SERVICE.service" 2>/dev/null || true
                sudo systemctl disable "$SERVICE.service" 2>/dev/null || true
                sudo rm -f "/etc/systemd/system/$SERVICE.service"
                sudo rm -f "/etc/systemd/system/multi-user.target.wants/$SERVICE.service"
                log_info "✅ $SERVICE.service 削除完了"
            done
            sudo systemctl daemon-reload
            echo ""
            log_info "🎉 すべての関連サービス削除完了！"
        fi
        exit 0
    fi
fi

echo ""

# ==================== 削除確認 ====================
log_warn "⚠️ 自動起動解除について"
echo "この操作により以下が実行されます:"
echo "  • $SERVICE_NAME.service の停止"
echo "  • 自動起動設定の無効化"
echo "  • systemdサービスファイルの削除"
echo ""
echo "注意:"
echo "  • アプリは手動で起動する必要があります"
echo "  • システム再起動後は自動起動しません"
echo ""

read -p "自動起動を解除しますか？ (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "自動起動解除をキャンセルしました"
    exit 0
fi

# ==================== サービス停止・無効化 ====================
log_info "🛑 サービス停止・無効化..."

# サービス停止
if systemctl is-active --quiet "$SERVICE_NAME.service"; then
    log_info "$SERVICE_NAME.service を停止中..."
    sudo systemctl stop "$SERVICE_NAME.service"
    
    # 停止確認
    if systemctl is-active --quiet "$SERVICE_NAME.service"; then
        log_error "❌ サービス停止失敗"
        sudo systemctl kill "$SERVICE_NAME.service"
        sleep 2
    fi
    
    log_info "✅ サービス停止完了"
else
    log_info "ℹ️ サービスは既に停止中"
fi

# 自動起動無効化
if systemctl is-enabled "$SERVICE_NAME.service" >/dev/null 2>&1; then
    log_info "自動起動を無効化中..."
    sudo systemctl disable "$SERVICE_NAME.service"
    log_info "✅ 自動起動無効化完了"
else
    log_info "ℹ️ 自動起動は既に無効"
fi

# ==================== サービスファイル削除 ====================
log_info "🗑️ サービスファイル削除..."

# systemdサービスファイル削除
if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
    sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    log_info "✅ サービスファイル削除: /etc/systemd/system/$SERVICE_NAME.service"
fi

# multi-user.targetから削除
if [ -f "/etc/systemd/system/multi-user.target.wants/$SERVICE_NAME.service" ]; then
    sudo rm -f "/etc/systemd/system/multi-user.target.wants/$SERVICE_NAME.service"
    log_info "✅ target依存関係削除: multi-user.target.wants/$SERVICE_NAME.service"
fi

# systemd設定リロード
sudo systemctl daemon-reload
sudo systemctl reset-failed 2>/dev/null || true

log_info "✅ サービスファイル削除完了"

# ==================== プロセス確認・停止 ====================
log_info "🔍 関連プロセス確認..."

# app.py関連プロセス確認
if ps aux | grep "python.*app.py" | grep -v grep >/dev/null 2>&1; then
    log_warn "⚠️ app.pyプロセスがまだ実行中です"
    echo "実行中のプロセス:"
    ps aux | grep "python.*app.py" | grep -v grep
    echo ""
    
    read -p "これらのプロセスを停止しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "app.pyプロセスを停止中..."
        sudo pkill -f "python.*app.py" 2>/dev/null || true
        sleep 2
        
        # 停止確認
        if ps aux | grep "python.*app.py" | grep -v grep >/dev/null 2>&1; then
            log_warn "⚠️ 一部のプロセスが残っています。強制停止中..."
            sudo pkill -9 -f "python.*app.py" 2>/dev/null || true
            sleep 1
        fi
        
        log_info "✅ プロセス停止完了"
    fi
else
    log_info "✅ app.pyプロセスは実行されていません"
fi

# ポート5000確認
if sudo lsof -i :5000 >/dev/null 2>&1; then
    log_warn "⚠️ ポート5000がまだ使用されています"
    echo "使用プロセス:"
    sudo lsof -i :5000
    echo ""
    
    read -p "ポート5000を強制解放しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo fuser -k 5000/tcp 2>/dev/null || true
        sleep 1
        log_info "✅ ポート5000解放完了"
    fi
else
    log_info "✅ ポート5000は解放されています"
fi

# ==================== 最終確認 ====================
log_info "🔍 削除結果確認..."

echo ""
echo "📋 削除結果:"

# サービスファイル確認
if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
    echo "  ❌ サービスファイル: 残存"
else
    echo "  ✅ サービスファイル: 削除済み"
fi

# サービス一覧確認
if systemctl list-unit-files | grep -q "^$SERVICE_NAME.service"; then
    echo "  ❌ サービス登録: 残存"
else
    echo "  ✅ サービス登録: 削除済み"
fi

# プロセス確認
if ps aux | grep "python.*app.py" | grep -v grep >/dev/null 2>&1; then
    echo "  ⚠️ app.pyプロセス: 実行中"
else
    echo "  ✅ app.pyプロセス: 停止済み"
fi

# ポート確認
if sudo lsof -i :5000 >/dev/null 2>&1; then
    echo "  ⚠️ ポート5000: 使用中"
else
    echo "  ✅ ポート5000: 解放済み"
fi

echo ""
echo "🎉 自動起動解除完了！"
echo "=================================="
echo ""

# ==================== 手動管理方法表示 ====================
echo "🔧 今後の手動管理方法:"
echo "   ./app_start.sh               # アプリ手動起動"
echo "   ./app_stop.sh                # アプリ停止"
echo "   ./app_status.sh              # 状態確認"
echo "   ./app_autostart.sh           # 自動起動再設定"
echo ""

echo "📱 手動起動後のアクセス:"
echo "   ローカル: http://localhost:5000"

if command -v tailscale &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未接続")
    if [ "$TAILSCALE_IP" != "未接続" ] && [ -n "$TAILSCALE_IP" ]; then
        echo "   Tailscale: http://$TAILSCALE_IP:5000"
    else
        echo "   Tailscale: 未接続（sudo tailscale up で接続）"
    fi
fi

echo ""
echo "ℹ️ 重要な注意事項:"
echo "   • システム再起動後はアプリが自動起動しません"
echo "   • 必要に応じて ./app_start.sh で手動起動してください"
echo "   • 自動起動を再設定する場合は ./app_autostart.sh を実行"
echo ""

log_info "🗑️ 自動起動解除スクリプト完了"
