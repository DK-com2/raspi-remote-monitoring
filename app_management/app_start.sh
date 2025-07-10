#!/bin/bash
# Raspberry Pi 監視システム - アプリ手動起動スクリプト

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

echo "🚀 Raspberry Pi 監視システム - アプリ起動"
echo "=========================================="

# ディレクトリ設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MONITORING_DIR="$PROJECT_ROOT/monitoring-system"
VENV_DIR="$PROJECT_ROOT/venv"

log_debug "プロジェクトルート: $PROJECT_ROOT"
log_debug "監視システム: $MONITORING_DIR"
log_debug "Python仮想環境: $VENV_DIR"

# ==================== 前提条件確認 ====================
log_info "📋 前提条件確認..."

# app.py存在確認
if [ ! -f "$MONITORING_DIR/app.py" ]; then
    log_error "app.pyが見つかりません: $MONITORING_DIR/app.py"
    log_error "先に環境構築を実行してください:"
    log_error "  cd environment-setup && ./setup_complete.sh"
    exit 1
fi

# Python仮想環境確認
if [ ! -d "$VENV_DIR" ] || [ ! -f "$VENV_DIR/bin/python" ]; then
    log_error "Python仮想環境が見つかりません: $VENV_DIR"
    log_error "先に環境構築を実行してください:"
    log_error "  cd environment-setup && ./setup_complete.sh"
    exit 1
fi

log_info "✅ 前提条件確認完了"

# ==================== 競合プロセス確認・停止 ====================
log_info "🔍 競合プロセス確認..."

# ポート5000使用プロセス確認
if sudo lsof -i :5000 >/dev/null 2>&1; then
    log_warn "⚠️ ポート5000が既に使用されています"
    
    echo "使用中のプロセス:"
    sudo lsof -i :5000
    echo ""
    
    read -p "競合プロセスを停止しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "競合プロセスを停止中..."
        
        # app.py関連プロセス停止
        sudo pkill -f "python.*app.py" 2>/dev/null || true
        
        # ポート5000使用プロセス強制停止
        sudo fuser -k 5000/tcp 2>/dev/null || true
        
        # 少し待機
        sleep 2
        
        # 停止確認
        if sudo lsof -i :5000 >/dev/null 2>&1; then
            log_error "❌ プロセス停止に失敗しました"
            log_error "手動で停止してから再実行してください:"
            sudo lsof -i :5000
            exit 1
        else
            log_info "✅ 競合プロセス停止完了"
        fi
    else
        log_error "競合プロセスが存在するため起動を中止します"
        exit 1
    fi
else
    log_info "✅ ポート5000は使用可能です"
fi

# ==================== Python仮想環境確認 ====================
log_info "🐍 Python仮想環境確認..."

# 仮想環境アクティベート
source "$VENV_DIR/bin/activate"

# 必要なパッケージ確認
REQUIRED_PACKAGES=("flask" "psutil" "requests" "pyyaml")
for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! python -c "import $package" 2>/dev/null; then
        log_error "必要なパッケージが見つかりません: $package"
        log_error "環境構築を実行してください:"
        log_error "  cd environment-setup && ./setup_complete.sh"
        deactivate
        exit 1
    fi
done

log_info "✅ Python依存関係確認完了"

# ==================== アプリケーション起動 ====================
log_info "🚀 アプリケーション起動中..."

# 作業ディレクトリ変更
cd "$MONITORING_DIR"

# config.yaml設定確認
if [ -f "config.yaml" ]; then
    HOST=$(grep "host:" config.yaml | awk '{print $2}' | tr -d '"' || echo "0.0.0.0")
    PORT=$(grep "port:" config.yaml | awk '{print $2}' || echo "5000")
    log_debug "設定確認 - Host: $HOST, Port: $PORT"
else
    log_warn "⚠️ config.yamlが見つかりません。デフォルト設定を使用します"
    HOST="0.0.0.0"
    PORT="5000"
fi

# アプリケーション起動（バックグラウンド）
log_info "Python app.py を起動中..."
python app.py &
APP_PID=$!

# 起動待機
log_info "起動待機中... (15秒)"
sleep 15

# 起動確認
if ps -p $APP_PID > /dev/null 2>&1; then
    log_info "✅ アプリケーションプロセス起動確認 (PID: $APP_PID)"
else
    log_error "❌ アプリケーション起動失敗"
    deactivate
    exit 1
fi

# HTTP応答確認
log_info "HTTP応答確認中..."
if curl -f -s http://localhost:$PORT > /dev/null 2>&1; then
    log_info "✅ HTTP応答確認成功"
else
    log_warn "⚠️ HTTP応答なし（起動中の可能性があります）"
fi

# ==================== アクセス情報表示 ====================
echo ""
echo "🎉 アプリケーション起動完了！"
echo "=================================="
echo ""

# ローカルアクセス
echo "🏠 ローカルアクセス:"
echo "   http://localhost:$PORT"
echo ""

# ネットワークアクセス
echo "🌐 ネットワークアクセス:"
if command -v ip &> /dev/null; then
    LOCAL_IPS=$(ip addr show | grep -E 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1)
    echo "$LOCAL_IPS" | while read ip; do
        [ -n "$ip" ] && echo "   http://$ip:$PORT"
    done
else
    echo "   IPアドレス取得に失敗しました"
fi
echo ""

# Tailscale アクセス
echo "🔒 Tailscale アクセス:"
if command -v tailscale &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
    if [ "$TAILSCALE_IP" != "未設定" ] && [ -n "$TAILSCALE_IP" ]; then
        echo "   📱 メイン画面: http://$TAILSCALE_IP:$PORT"
        echo "   🎤 録音機能: http://$TAILSCALE_IP:$PORT/recording"
        echo "   ☁️ Google Drive: http://$TAILSCALE_IP:$PORT/gdrive"
        echo "   🔧 Tailscale管理: http://$TAILSCALE_IP:$PORT/tailscale"
        echo ""
        echo "🔗 QRコード生成（スマホ用）:"
        echo "   https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=http://$TAILSCALE_IP:$PORT"
    else
        echo "   ❌ Tailscale未接続"
        echo "   接続方法: sudo tailscale up"
    fi
else
    echo "   ❌ Tailscale未インストール"
    echo "   インストール: curl -fsSL https://tailscale.com/install.sh | sh"
fi

echo ""
echo "🔧 管理コマンド:"
echo "   ./app_stop.sh                # アプリ停止"
echo "   ./app_status.sh              # 状態確認"
echo "   ./app_autostart.sh           # 自動起動設定"
echo ""

echo "ℹ️ アプリ停止: ./app_stop.sh または Ctrl+C"
echo ""

# プロセス終了を待機（フォアグラウンド化）
trap "echo; log_info 'アプリケーション終了中...'; kill $APP_PID 2>/dev/null; deactivate; exit 0" INT

log_info "アプリケーション実行中... (Ctrl+C で停止)"
wait $APP_PID

# 仮想環境非アクティベート
deactivate
