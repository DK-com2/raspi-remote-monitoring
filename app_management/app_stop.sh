#!/bin/bash
# Raspberry Pi 監視システム - アプリ停止スクリプト

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

echo "🛑 Raspberry Pi 監視システム - アプリ停止"
echo "========================================"

# ==================== 実行中プロセス確認 ====================
log_info "🔍 実行中プロセス確認..."

# app.py関連プロセス検索
APP_PIDS=$(ps aux | grep "python.*app.py" | grep -v grep | awk '{print $2}' || true)

if [ -z "$APP_PIDS" ]; then
    log_info "✅ app.pyプロセスは実行されていません"
else
    echo "実行中のapp.pyプロセス:"
    ps aux | grep "python.*app.py" | grep -v grep
    echo ""
    
    log_info "プロセス停止中..."
    
    # 各プロセスを安全に停止
    for PID in $APP_PIDS; do
        if ps -p $PID > /dev/null 2>&1; then
            log_debug "PID $PID を停止中..."
            
            # まず SIGTERM で安全な停止を試行
            kill $PID 2>/dev/null || true
            
            # 停止を待機
            for i in {1..10}; do
                if ! ps -p $PID > /dev/null 2>&1; then
                    log_info "✅ PID $PID 正常停止"
                    break
                fi
                sleep 1
            done
            
            # まだ実行中の場合は強制終了
            if ps -p $PID > /dev/null 2>&1; then
                log_warn "⚠️ PID $PID 強制停止中..."
                kill -9 $PID 2>/dev/null || true
                sleep 1
                
                if ps -p $PID > /dev/null 2>&1; then
                    log_error "❌ PID $PID 停止失敗"
                else
                    log_info "✅ PID $PID 強制停止完了"
                fi
            fi
        fi
    done
fi

# ==================== ポート5000解放確認 ====================
log_info "🔍 ポート5000解放確認..."

if sudo lsof -i :5000 >/dev/null 2>&1; then
    log_warn "⚠️ ポート5000がまだ使用されています"
    echo "使用中のプロセス:"
    sudo lsof -i :5000
    echo ""
    
    read -p "強制的にポート5000を解放しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "ポート5000を強制解放中..."
        sudo fuser -k 5000/tcp 2>/dev/null || true
        sleep 2
        
        if sudo lsof -i :5000 >/dev/null 2>&1; then
            log_error "❌ ポート5000解放失敗"
            sudo lsof -i :5000
        else
            log_info "✅ ポート5000解放完了"
        fi
    fi
else
    log_info "✅ ポート5000は解放されています"
fi

# ==================== Python仮想環境確認 ====================
log_info "🐍 Python仮想環境確認..."

# VIRTUAL_ENV環境変数確認
if [ -n "$VIRTUAL_ENV" ]; then
    log_warn "⚠️ Python仮想環境がアクティブです: $VIRTUAL_ENV"
    log_info "仮想環境を非アクティブ化します"
    deactivate 2>/dev/null || true
fi

# ==================== systemdサービス確認 ====================
log_info "⚙️ systemdサービス確認..."

SERVICES=("raspi-monitoring" "network-monitor" "monitoring" "flask-app")

for SERVICE in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$SERVICE.service" 2>/dev/null; then
        log_warn "⚠️ systemdサービス $SERVICE.service が稼働中です"
        
        read -p "$SERVICE.service を停止しますか？ (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "$SERVICE.service を停止中..."
            sudo systemctl stop "$SERVICE.service"
            log_info "✅ $SERVICE.service 停止完了"
        fi
    fi
done

# ==================== 最終確認 ====================
log_info "🔍 最終確認..."

echo ""
echo "📋 停止結果:"

# プロセス確認
if ps aux | grep "python.*app.py" | grep -v grep >/dev/null 2>&1; then
    echo "  ❌ app.pyプロセス: 実行中"
    ps aux | grep "python.*app.py" | grep -v grep
else
    echo "  ✅ app.pyプロセス: 停止済み"
fi

# ポート確認
if sudo lsof -i :5000 >/dev/null 2>&1; then
    echo "  ❌ ポート5000: 使用中"
else
    echo "  ✅ ポート5000: 解放済み"
fi

# Python仮想環境確認
if [ -n "$VIRTUAL_ENV" ]; then
    echo "  ⚠️ Python仮想環境: アクティブ ($VIRTUAL_ENV)"
else
    echo "  ✅ Python仮想環境: 非アクティブ"
fi

echo ""
echo "🎉 アプリ停止処理完了！"
echo ""
echo "🔧 次の操作:"
echo "   ./app_start.sh               # アプリ再起動"
echo "   ./app_status.sh              # 状態確認"
echo "   ./app_autostart.sh           # 自動起動設定"
echo ""
