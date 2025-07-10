#!/bin/bash
# Raspberry Pi 監視システム - 自動起動設定スクリプト

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

echo "⚙️ Raspberry Pi 監視システム - 自動起動設定"
echo "============================================"

# ディレクトリ設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MONITORING_DIR="$PROJECT_ROOT/monitoring-system"
VENV_DIR="$PROJECT_ROOT/venv"
SERVICE_NAME="raspi-monitoring"
USER="$(whoami)"

log_debug "プロジェクトルート: $PROJECT_ROOT"
log_debug "サービス名: $SERVICE_NAME"
log_debug "ユーザー: $USER"

# ==================== 前提条件確認 ====================
log_info "📋 前提条件確認..."

# app.py存在確認
if [ ! -f "$MONITORING_DIR/app.py" ]; then
    log_error "app.pyが見つかりません: $MONITORING_DIR/app.py"
    exit 1
fi

# Python仮想環境確認
if [ ! -d "$VENV_DIR" ] || [ ! -f "$VENV_DIR/bin/python" ]; then
    log_error "Python仮想環境が見つかりません: $VENV_DIR"
    exit 1
fi

# systemd確認
if ! systemctl --version >/dev/null 2>&1; then
    log_error "systemdが利用できません"
    exit 1
fi

log_info "✅ 前提条件確認完了"

# ==================== 既存競合サービス確認・削除 ====================
log_info "🔍 既存競合サービス確認..."

CONFLICT_SERVICES=("network-monitor" "monitoring" "flask-app" "raspberry-pi-monitor")

for SERVICE in "${CONFLICT_SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "^$SERVICE.service"; then
        log_warn "⚠️ 競合サービス検出: $SERVICE.service"
        
        # サービス状態確認
        if systemctl is-active --quiet "$SERVICE.service"; then
            echo "  状態: 稼働中"
        else
            echo "  状態: 停止中"
        fi
        
        if systemctl is-enabled "$SERVICE.service" >/dev/null 2>&1; then
            echo "  自動起動: 有効"
        else
            echo "  自動起動: 無効"
        fi
        
        echo ""
        read -p "$SERVICE.service を削除しますか？ (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "$SERVICE.service を削除中..."
            
            # サービス停止
            sudo systemctl stop "$SERVICE.service" 2>/dev/null || true
            
            # 自動起動無効化
            sudo systemctl disable "$SERVICE.service" 2>/dev/null || true
            
            # サービスファイル削除
            sudo rm -f "/etc/systemd/system/$SERVICE.service"
            sudo rm -f "/etc/systemd/system/multi-user.target.wants/$SERVICE.service"
            
            log_info "✅ $SERVICE.service 削除完了"
        else
            log_warn "⚠️ $SERVICE.service が残っています（競合の可能性）"
        fi
    fi
done

# systemd設定リロード
sudo systemctl daemon-reload

# ==================== 既存のraspi-monitoringサービス確認 ====================
log_info "🔍 既存のraspi-monitoringサービス確認..."

if systemctl list-unit-files | grep -q "^$SERVICE_NAME.service"; then
    log_warn "⚠️ $SERVICE_NAME.service が既に存在します"
    
    # 現在の状態表示
    if systemctl is-active --quiet "$SERVICE_NAME.service"; then
        echo "  状態: 稼働中"
    else
        echo "  状態: 停止中"
    fi
    
    if systemctl is-enabled "$SERVICE_NAME.service" >/dev/null 2>&1; then
        echo "  自動起動: 有効"
    else
        echo "  自動起動: 無効"
    fi
    
    echo ""
    read -p "既存のサービスを更新しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "既存サービスを停止・削除中..."
        sudo systemctl stop "$SERVICE_NAME.service" 2>/dev/null || true
        sudo systemctl disable "$SERVICE_NAME.service" 2>/dev/null || true
        sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        sudo systemctl daemon-reload
        log_info "✅ 既存サービス削除完了"
    else
        log_error "既存サービスが残っているため、設定を中止します"
        exit 1
    fi
fi

# ==================== 実行中プロセス停止 ====================
log_info "🛑 実行中プロセス停止..."

# app.py関連プロセス停止
if ps aux | grep "python.*app.py" | grep -v grep >/dev/null 2>&1; then
    log_warn "⚠️ app.pyプロセスが実行中です。停止します..."
    sudo pkill -f "python.*app.py" 2>/dev/null || true
    sleep 2
fi

# ポート5000使用プロセス停止
if sudo lsof -i :5000 >/dev/null 2>&1; then
    log_warn "⚠️ ポート5000使用プロセスを停止中..."
    sudo fuser -k 5000/tcp 2>/dev/null || true
    sleep 2
fi

log_info "✅ プロセス停止完了"

# ==================== systemdサービスファイル作成 ====================
log_info "📄 systemdサービスファイル作成..."

sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null << EOF
[Unit]
Description=Raspberry Pi Monitoring System
Documentation=Raspberry Pi monitoring with Tailscale access
After=network-online.target tailscaled.service
Wants=network-online.target
RequiresMountsFor=/home

[Service]
Type=simple
User=${USER}
Group=${USER}
WorkingDirectory=${MONITORING_DIR}
Environment=PATH=${VENV_DIR}/bin:/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=${MONITORING_DIR}
Environment=PYTHONUNBUFFERED=1

# Tailscale起動待機
ExecStartPre=/bin/sleep 15
ExecStart=${VENV_DIR}/bin/python ${MONITORING_DIR}/app.py

# 再起動設定
Restart=on-failure
RestartSec=10
StartLimitInterval=300
StartLimitBurst=3

# ログ設定
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

# セキュリティ設定
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

log_info "✅ systemdサービスファイル作成完了"

# ==================== 権限設定 ====================
log_info "🔐 権限設定..."

# プロジェクトディレクトリ権限
chown -R $USER:$USER "$PROJECT_ROOT" 2>/dev/null || true
chmod +x "$MONITORING_DIR/app.py"

# データディレクトリ権限
DATA_DIR="$PROJECT_ROOT/data"
if [ -d "$DATA_DIR" ]; then
    chown -R $USER:$USER "$DATA_DIR" 2>/dev/null || true
fi

# audioグループ追加（録音機能用）
if ! groups $USER | grep -q audio; then
    log_info "audioグループに追加中..."
    sudo usermod -a -G audio $USER
    log_info "✅ audioグループ追加完了（再ログイン後有効）"
fi

log_info "✅ 権限設定完了"

# ==================== Tailscale確認・設定 ====================
log_info "🔒 Tailscale確認..."

if command -v tailscale &> /dev/null; then
    log_info "✅ Tailscale確認済み"
    
    # Tailscale状態確認
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未接続")
    if [ "$TAILSCALE_IP" != "未接続" ] && [ -n "$TAILSCALE_IP" ]; then
        log_info "✅ Tailscale接続中: $TAILSCALE_IP"
    else
        log_warn "⚠️ Tailscale未接続"
        echo "接続方法: sudo tailscale up"
    fi
    
    # Tailscale自動起動確認
    if systemctl is-enabled tailscaled.service >/dev/null 2>&1; then
        log_info "✅ Tailscale自動起動有効"
    else
        log_info "Tailscale自動起動を有効化中..."
        sudo systemctl enable tailscaled.service
        log_info "✅ Tailscale自動起動設定完了"
    fi
else
    log_warn "⚠️ Tailscaleが未インストールです"
    echo "インストール方法:"
    echo "  curl -fsSL https://tailscale.com/install.sh | sh"
    echo "  sudo tailscale up"
fi

# ==================== サービス有効化・起動 ====================
log_info "🚀 サービス有効化・起動..."

# systemd設定リロード
sudo systemctl daemon-reload

# サービス有効化
sudo systemctl enable ${SERVICE_NAME}.service
log_info "✅ サービス自動起動有効化"

# サービス起動テスト
log_info "サービス起動テスト中..."
sudo systemctl start ${SERVICE_NAME}.service

# 起動待機
log_info "起動待機中... (20秒)"
sleep 20

# 起動確認
if sudo systemctl is-active --quiet ${SERVICE_NAME}.service; then
    log_info "✅ サービス起動成功"
    
    # HTTP応答確認
    if curl -f -s --max-time 10 http://localhost:5000 > /dev/null 2>&1; then
        log_info "✅ HTTP応答確認成功"
    else
        log_warn "⚠️ HTTP応答確認失敗（起動中の可能性）"
    fi
else
    log_error "❌ サービス起動失敗"
    echo ""
    echo "エラーログ:"
    sudo journalctl -u ${SERVICE_NAME}.service -n 10 --no-pager
    exit 1
fi

# ==================== アクセス情報表示 ====================
echo ""
echo "🎉 自動起動設定完了！"
echo "=================================="
echo ""

# アクセス情報
echo "📱 アクセス情報:"
echo "   ローカル: http://localhost:5000"

if command -v tailscale &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
    if [ "$TAILSCALE_IP" != "未設定" ] && [ -n "$TAILSCALE_IP" ]; then
        echo "   Tailscale: http://$TAILSCALE_IP:5000"
        echo ""
        echo "📱 各機能URL:"
        echo "   メイン: http://$TAILSCALE_IP:5000"
        echo "   録音: http://$TAILSCALE_IP:5000/recording"
        echo "   Google Drive: http://$TAILSCALE_IP:5000/gdrive"
        echo "   Tailscale管理: http://$TAILSCALE_IP:5000/tailscale"
    fi
fi

echo ""
echo "🔧 管理コマンド:"
echo "   sudo systemctl status ${SERVICE_NAME}       # 状態確認"
echo "   sudo systemctl restart ${SERVICE_NAME}      # 再起動"
echo "   sudo systemctl stop ${SERVICE_NAME}         # 停止"
echo "   sudo journalctl -u ${SERVICE_NAME} -f       # ログ監視"
echo "   ./app_remove_autostart.sh                   # 自動起動解除"
echo "   ./app_status.sh                             # 詳細状態確認"
echo ""

echo "ℹ️ 重要な注意事項:"
echo "   • 次回システム起動時から自動的にアプリが開始されます"
echo "   • audioグループ追加の場合は再ログインが必要です"
echo "   • Tailscale未接続の場合は手動で接続してください"
echo ""

# 再起動提案
read -p "自動起動テストのため今すぐ再起動しますか？ (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "5秒後に再起動します..."
    echo "再起動後の確認方法:"
    echo "  ./app_status.sh"
    if command -v tailscale &> /dev/null; then
        FINAL_TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
        if [ "$FINAL_TAILSCALE_IP" != "未設定" ] && [ -n "$FINAL_TAILSCALE_IP" ]; then
            echo "  スマホアクセス: http://$FINAL_TAILSCALE_IP:5000"
        fi
    fi
    sleep 5
    sudo reboot
else
    log_info "手動で再起動してテストしてください"
    echo ""
    echo "再起動後の確認:"
    echo "  ./app_status.sh"
    echo "  sudo systemctl status ${SERVICE_NAME}"
fi

echo ""
log_info "⚙️ 自動起動設定スクリプト完了"
