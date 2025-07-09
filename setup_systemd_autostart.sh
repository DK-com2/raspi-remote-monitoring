#!/bin/bash
# Raspberry Pi 監視システム - systemd自動起動設定専用スクリプト
# app.pyの自動起動 + Tailscale環境対応

set -e

echo "🚀 Raspberry Pi 監視システム - systemd自動起動設定"
echo "=================================================="
echo ""
echo "このスクリプトは以下を実行します:"
echo "  ✅ systemdサービス設定"
echo "  ✅ app.pyの自動起動設定"
echo "  ✅ Tailscale環境対応"
echo "  ✅ 起動テスト実行"
echo ""
read -p "systemd設定を開始しますか？ (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "設定をキャンセルしました"
    exit 0
fi
echo ""

# 設定変数（自動検出）
CURRENT_DIR="$(pwd)"
PROJECT_DIR="$CURRENT_DIR/monitoring-system"
SERVICE_NAME="raspi-monitoring"
USER="$(whoami)"
PYTHON_VENV="$CURRENT_DIR/venv"

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

# 環境判定関数
detect_environment() {
    if grep -q Microsoft /proc/version 2>/dev/null; then
        echo "wsl2"
    elif [ -f /proc/device-tree/model ] && grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        echo "raspberry_pi"
    elif [ -f /etc/os-release ] && grep -q "Raspbian\|Raspberry Pi OS" /etc/os-release; then
        echo "raspberry_pi"
    else
        echo "linux"
    fi
}

ENVIRONMENT=$(detect_environment)

echo ""
log_info "🖥️ 環境: $ENVIRONMENT"
log_debug "プロジェクト: $PROJECT_DIR"
log_debug "サービス名: $SERVICE_NAME"
log_debug "ユーザー: $USER"
log_debug "Python仮想環境: $PYTHON_VENV"
echo ""

# ==================== 前提条件確認 ====================
log_info "📋 前提条件確認..."

# app.py存在確認
if [ ! -f "$PROJECT_DIR/app.py" ]; then
    log_error "app.pyが見つかりません: $PROJECT_DIR/app.py"
    log_error "先にアプリケーションファイルを配置してください"
    exit 1
fi
log_info "✅ app.py確認: $PROJECT_DIR/app.py"

# Python仮想環境確認
if [ ! -d "$PYTHON_VENV" ] || [ ! -f "$PYTHON_VENV/bin/python" ]; then
    log_error "Python仮想環境が見つかりません: $PYTHON_VENV"
    log_error "先に環境構築を実行してください"
    exit 1
fi
log_info "✅ Python仮想環境確認: $PYTHON_VENV"

# systemd確認
if ! systemctl --version >/dev/null 2>&1; then
    log_error "systemdが利用できません"
    if [ "$ENVIRONMENT" = "wsl2" ]; then
        log_error "WSL2でsystemdを有効化してください:"
        log_error "  sudo tee /etc/wsl.conf << EOF"
        log_error "  [boot]"
        log_error "  systemd=true"
        log_error "  EOF"
        log_error "  その後 wsl --shutdown で再起動"
    fi
    exit 1
fi
log_info "✅ systemd確認済み"

# 依存関係確認
log_info "Python依存関係確認..."
source "$PYTHON_VENV/bin/activate"

# Flask確認
if ! python -c "import flask" 2>/dev/null; then
    log_error "Flaskがインストールされていません"
    log_error "先に依存関係をインストールしてください: pip install flask"
    deactivate
    exit 1
fi

# 基本的な依存関係を確認・インストール
REQUIRED_PACKAGES=(
    "flask"
    "psutil"
    "requests"
    "pyyaml"
)

for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! python -c "import $package" 2>/dev/null; then
        log_warn "⚠️ $package が見つかりません。インストール中..."
        pip install "$package"
    fi
done

deactivate
log_info "✅ 依存関係確認完了"

echo ""

# ==================== 既存サービス確認・停止 ====================
log_info "🔍 既存サービス確認..."

if systemctl is-active --quiet ${SERVICE_NAME}.service 2>/dev/null; then
    log_warn "⚠️ サービスが既に稼働中です"
    log_info "既存サービスを停止します..."
    sudo systemctl stop ${SERVICE_NAME}.service
    log_info "✅ サービス停止完了"
fi

if systemctl is-enabled ${SERVICE_NAME}.service >/dev/null 2>&1; then
    log_info "既存の自動起動設定を一旦無効化..."
    sudo systemctl disable ${SERVICE_NAME}.service
fi

echo ""

# ==================== app.py本番用設定 ====================
log_info "⚙️ app.py本番用設定..."

# バックアップ作成
if [ ! -f "$PROJECT_DIR/app.py.backup" ]; then
    cp "$PROJECT_DIR/app.py" "$PROJECT_DIR/app.py.backup"
    log_info "✅ app.pyバックアップ作成"
fi

# debug=Falseに変更（本番用）
if grep -q "debug=True" "$PROJECT_DIR/app.py"; then
    sed -i 's/debug=True/debug=False/g' "$PROJECT_DIR/app.py"
    log_info "✅ debug=False に変更（本番モード）"
fi

# host設定確認
if ! grep -q "host.*0.0.0.0" "$PROJECT_DIR/app.py"; then
    log_warn "⚠️ app.pyでhost='0.0.0.0'の設定を確認してください"
    log_info "Tailscaleアクセスには host='0.0.0.0' が必要です"
fi

echo ""

# ==================== systemdサービスファイル作成 ====================
log_info "📄 systemdサービスファイル作成..."

sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null << EOF
[Unit]
Description=Raspberry Pi Monitoring System
Documentation=Raspberry Pi network monitoring with Tailscale access
After=network-online.target tailscaled.service
Wants=network-online.target
RequiresMountsFor=/home

[Service]
Type=simple
User=${USER}
Group=${USER}
WorkingDirectory=${PROJECT_DIR}
Environment=PATH=${PYTHON_VENV}/bin:/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=${PROJECT_DIR}
Environment=PYTHONUNBUFFERED=1

# Tailscale起動待機
ExecStartPre=/bin/sleep 15
ExecStart=${PYTHON_VENV}/bin/python ${PROJECT_DIR}/app.py

# 再起動設定
Restart=always
RestartSec=10
StartLimitInterval=300
StartLimitBurst=5

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

echo ""

# ==================== 権限設定 ====================
log_info "🔐 権限設定..."

# プロジェクトディレクトリ権限
chown -R $USER:$USER "$PROJECT_DIR" 2>/dev/null || true
chmod +x "$PROJECT_DIR/app.py"

# データディレクトリ権限
DATA_DIR="$CURRENT_DIR/data"
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

echo ""

# ==================== Tailscale確認・設定 ====================
log_info "🔒 Tailscale確認・設定..."

if ! command -v tailscale &> /dev/null; then
    log_warn "⚠️ Tailscaleがインストールされていません"
    echo ""
    echo "Tailscaleのインストール方法:"
    echo "  curl -fsSL https://tailscale.com/install.sh | sh"
    echo "  sudo tailscale up"
    echo ""
    read -p "Tailscaleをインストールしますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Tailscaleインストール中..."
        curl -fsSL https://tailscale.com/install.sh | sh
        log_info "✅ Tailscaleインストール完了"
        
        log_info "Tailscale接続開始..."
        sudo tailscale up
        log_info "✅ Tailscale接続完了"
    else
        log_warn "Tailscaleなしで続行します"
    fi
else
    log_info "✅ Tailscale確認済み"
    
    # Tailscale状態確認
    if tailscale status >/dev/null 2>&1; then
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未接続")
        if [ "$TAILSCALE_IP" != "未接続" ]; then
            log_info "✅ Tailscale接続中: $TAILSCALE_IP"
        else
            log_warn "⚠️ Tailscale未接続"
            read -p "Tailscaleに接続しますか？ (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo tailscale up
                TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未接続")
            fi
        fi
    fi
fi

# Tailscale自動起動設定
if command -v tailscale &> /dev/null; then
    sudo systemctl enable tailscaled.service
    log_info "✅ Tailscale自動起動設定完了"
fi

echo ""

# ==================== サービス有効化・起動 ====================
log_info "🚀 サービス有効化・起動..."

# systemd設定リロード
sudo systemctl daemon-reload

# サービス有効化
sudo systemctl enable ${SERVICE_NAME}.service
log_info "✅ サービス自動起動有効化"

# サービス起動
log_info "サービス起動中..."
sudo systemctl start ${SERVICE_NAME}.service

# 起動待機
log_info "起動待機中..."
sleep 20

echo ""

# ==================== 起動確認・テスト ====================
log_info "✅ 起動確認・テスト..."

# サービス状態確認
if sudo systemctl is-active --quiet ${SERVICE_NAME}.service; then
    log_info "✅ サービス稼働中"
else
    log_error "❌ サービス起動失敗"
    echo ""
    echo "エラーログ:"
    sudo journalctl -u ${SERVICE_NAME}.service -n 20 --no-pager
    exit 1
fi

# ポート確認
if ss -tlnp | grep -q ":5000"; then
    log_info "✅ ポート5000でリスン中"
else
    log_warn "⚠️ ポート5000でリスンしていません"
    log_info "少し待ってから再確認します..."
    sleep 10
    if ss -tlnp | grep -q ":5000"; then
        log_info "✅ ポート5000でリスン確認"
    else
        log_warn "⚠️ ポート確認に失敗"
    fi
fi

# HTTP応答確認
log_info "HTTP応答確認中..."
sleep 5
if curl -f -s http://localhost:5000 > /dev/null 2>&1; then
    log_info "✅ HTTP応答確認成功"
else
    log_warn "⚠️ HTTP応答確認失敗"
    log_info "アプリケーション起動を待機中..."
    
    # 追加の待機とリトライ
    for i in {1..6}; do
        sleep 10
        if curl -f -s http://localhost:5000 > /dev/null 2>&1; then
            log_info "✅ HTTP応答確認成功（${i}回目のリトライ）"
            break
        fi
        log_info "リトライ中... ($i/6)"
    done
fi

echo ""

# ==================== アクセス情報表示 ====================
log_info "📱 アクセス情報表示..."

echo ""
echo "🎉 Raspberry Pi 監視システム 自動起動設定完了！"
echo "================================================"
echo ""

# ローカルアクセス情報
echo "🏠 ローカルアクセス:"
echo "   http://localhost:5000"

# ネットワークアクセス情報
echo ""
echo "🌐 ネットワークアクセス:"
if command -v ip &> /dev/null; then
    LOCAL_IPS=$(ip addr show | grep -E 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1)
    echo "$LOCAL_IPS" | while read ip; do
        [ -n "$ip" ] && echo "   http://$ip:5000"
    done
fi

# Tailscaleアクセス情報
echo ""
echo "🔒 Tailscaleアクセス:"
if command -v tailscale &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
    if [ "$TAILSCALE_IP" != "未設定" ] && [ -n "$TAILSCALE_IP" ]; then
        echo "   📱 メイン画面: http://$TAILSCALE_IP:5000"
        echo "   🎤 録音機能: http://$TAILSCALE_IP:5000/recording"
        echo "   ☁️ Google Drive: http://$TAILSCALE_IP:5000/gdrive"
        echo "   📊 ネットワーク監視: http://$TAILSCALE_IP:5000/network"
        echo ""
        echo "🔗 QRコード生成（スマホ用）:"
        echo "   https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=http://$TAILSCALE_IP:5000"
    else
        echo "   ❌ Tailscale未接続"
        echo "   接続方法: sudo tailscale up"
    fi
else
    echo "   ❌ Tailscale未インストール"
fi

echo ""

# ==================== 管理コマンド情報 ====================
echo "🔧 管理コマンド:"
echo "   sudo systemctl status ${SERVICE_NAME}       # 状態確認"
echo "   sudo systemctl restart ${SERVICE_NAME}      # 再起動"
echo "   sudo systemctl stop ${SERVICE_NAME}         # 停止"
echo "   sudo systemctl disable ${SERVICE_NAME}      # 自動起動無効"
echo "   sudo journalctl -u ${SERVICE_NAME} -f       # ログ監視"
echo ""

# ==================== API エンドポイントテスト ====================
log_info "🧪 API エンドポイントテスト..."

API_ENDPOINTS=(
    "/api/network-status"
    "/api/recording/devices"
    "/api/gdrive-status"
)

for endpoint in "${API_ENDPOINTS[@]}"; do
    if curl -f -s "http://localhost:5000$endpoint" > /dev/null 2>&1; then
        echo "  ✅ $endpoint"
    else
        echo "  ❌ $endpoint (要確認)"
    fi
done

echo ""

# ==================== テストスクリプト作成 ====================
log_info "📝 テストスクリプト作成..."

cat > ${CURRENT_DIR}/test_service.sh << 'EOF'
#!/bin/bash
echo "🧪 Raspberry Pi 監視システム サービステスト"
echo "==========================================="

SERVICE_NAME="raspi-monitoring"

# サービス状態確認
echo "🔍 サービス状態:"
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "  ✅ サービス: 稼働中"
else
    echo "  ❌ サービス: 停止中"
    sudo systemctl status $SERVICE_NAME --no-pager
    exit 1
fi

if systemctl is-enabled $SERVICE_NAME >/dev/null 2>&1; then
    echo "  ✅ 自動起動: 有効"
else
    echo "  ❌ 自動起動: 無効"
fi

# ポート確認
echo ""
echo "🌐 ネットワーク状態:"
if ss -tlnp | grep -q ":5000"; then
    echo "  ✅ ポート5000: リスン中"
else
    echo "  ❌ ポート5000: 未使用"
fi

# HTTP応答確認
echo ""
echo "📡 HTTP応答確認:"
if curl -f -s http://localhost:5000 > /dev/null; then
    echo "  ✅ ローカルアクセス: 正常"
else
    echo "  ❌ ローカルアクセス: 異常"
fi

# Tailscale確認
echo ""
echo "🔒 Tailscale状態:"
if command -v tailscale &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未接続")
    if [ "$TAILSCALE_IP" != "未接続" ]; then
        echo "  ✅ Tailscale IP: $TAILSCALE_IP"
        echo "  📱 アクセスURL: http://$TAILSCALE_IP:5000"
        
        # Tailscale経由のHTTP確認
        if curl -f -s "http://$TAILSCALE_IP:5000" > /dev/null 2>&1; then
            echo "  ✅ Tailscaleアクセス: 正常"
        else
            echo "  ⚠️ Tailscaleアクセス: 要確認"
        fi
    else
        echo "  ❌ Tailscale: 未接続"
    fi
else
    echo "  ❌ Tailscale: 未インストール"
fi

# 最新ログ表示
echo ""
echo "📜 最新ログ (最新5行):"
sudo journalctl -u $SERVICE_NAME -n 5 --no-pager 2>/dev/null || echo "  ログ取得失敗"

echo ""
echo "🎉 テスト完了"
EOF

chmod +x ${CURRENT_DIR}/test_service.sh
log_info "✅ テストスクリプト作成: test_service.sh"

echo ""

# ==================== 最終確認・再起動提案 ====================
echo "⚠️ 重要な確認事項:"
echo "  • Google Drive機能を使用する場合は credentials.json を設定"
echo "  • 録音機能を使用する場合は再ログインでaudioグループ有効化"
echo "  • ファイアウォール使用時はポート5000の考慮が必要"
echo ""

log_info "✅ systemd自動起動設定完了！"
echo ""

# 再起動提案
read -p "自動起動テストのため今すぐ再起動しますか？ (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "5秒後に再起動します..."
    echo "再起動後は以下で確認:"
    echo "  ./test_service.sh"
    echo "  tailscale ip -4"
    sleep 5
    sudo reboot
else
    log_info "手動で再起動してテストしてください"
    echo ""
    echo "再起動後の確認方法:"
    echo "  ./test_service.sh"
    echo "  sudo systemctl status ${SERVICE_NAME}"
    if command -v tailscale &> /dev/null; then
        FINAL_TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
        if [ "$FINAL_TAILSCALE_IP" != "未設定" ] && [ -n "$FINAL_TAILSCALE_IP" ]; then
            echo "  スマホアクセス: http://$FINAL_TAILSCALE_IP:5000"
        fi
    fi
fi

echo ""
log_info "🎯 systemd自動起動設定スクリプト完了"

exit 0
