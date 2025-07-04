#!/bin/bash
# ネットワーク監視アプリ 自動起動化・テスト統合スクリプト
# WSL2 & Raspberry Pi 両環境対応

set -e

echo "🚀 ネットワーク監視アプリ 統合セットアップ"
echo "=========================================="

# 設定変数（自動検出）
CURRENT_DIR="$(pwd)"
PROJECT_DIR="$CURRENT_DIR"
SERVICE_NAME="network-monitor"
USER="$(whoami)"
PYTHON_VENV="$(dirname $CURRENT_DIR)/venv"

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

# 環境判定
ENVIRONMENT=$(detect_environment)

echo ""
log_info "環境検出結果: $ENVIRONMENT"
log_debug "プロジェクトディレクトリ: $PROJECT_DIR"
log_debug "ユーザー: $USER"
log_debug "Python仮想環境: $PYTHON_VENV"
echo ""

case $ENVIRONMENT in
    "wsl2")
        log_info "🐧 WSL2環境を検出"
        echo "実行モードを選択してください:"
        echo "  1) テストモード（手動起動・終了）"
        echo "  2) systemd設定モード（自動起動設定）"
        read -p "選択 (1/2): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[2]$ ]]; then
            # WSL2でsystemd有効化確認
            if ! systemctl is-system-running >/dev/null 2>&1; then
                log_warn "⚠️ WSL2でsystemdが無効です"
                echo "systemdを有効化しますか？"
                echo "※ /etc/wsl.conf を編集してWSL再起動が必要です"
                read -p "有効化する (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    sudo mkdir -p /etc
                    echo "[boot]" | sudo tee /etc/wsl.conf
                    echo "systemd=true" | sudo tee -a /etc/wsl.conf
                    log_info "✅ systemd設定完了"
                    log_warn "WSLを再起動してください: wsl --shutdown"
                    exit 0
                else
                    log_info "テストモードで実行します"
                    MODE="test"
                fi
            else
                log_info "systemd有効 - 本番設定を実行"
                MODE="production"
            fi
        else
            MODE="test"
        fi
        ;;
    "raspberry_pi")
        log_info "🍓 Raspberry Pi環境を検出 - 本番セットアップモード"
        MODE="production"
        ;;
    "linux")
        log_warn "⚠️ 一般Linux環境を検出"
        echo "本番セットアップを実行しますか？ (y/N): "
        read -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            MODE="production"
        else
            MODE="test"
        fi
        ;;
esac

log_info "実行モード: $MODE"
echo ""

# 共通: 基本チェック
log_info "基本環境チェック..."

if [ ! -d "$PROJECT_DIR" ]; then
    log_error "プロジェクトディレクトリが見つかりません: $PROJECT_DIR"
    exit 1
fi

if [ ! -f "$PROJECT_DIR/app.py" ]; then
    log_error "app.pyが見つかりません: $PROJECT_DIR/app.py"
    log_info "ファイル一覧:"
    ls -la "$PROJECT_DIR/"
    exit 1
fi

log_info "✅ プロジェクトファイル確認完了"

# Python仮想環境確認
log_info "Python仮想環境確認..."
if [ ! -d "$PYTHON_VENV" ]; then
    log_error "Python仮想環境が見つかりません: $PYTHON_VENV"
    log_error "先に環境構築を実行してください:"
    log_error "  cd ../environment-setup && ./setup_all.sh"
    exit 1
fi

if [ ! -f "$PYTHON_VENV/bin/python" ]; then
    log_error "Python実行ファイルが見つかりません"
    exit 1
fi

log_info "✅ Python仮想環境確認完了"

# 依存関係確認
log_info "Python依存関係確認・インストール..."
source "$PYTHON_VENV/bin/activate"
pip install flask psutil requests
log_info "✅ 依存関係確認完了"

# モード別処理
if [ "$MODE" = "test" ]; then
    # ==================== テストモード ====================
    log_info "🧪 テストモード実行中..."
    
    # 本番用設定でコピー作成
    log_info "テスト用設定ファイル作成..."
    cp "$PROJECT_DIR/app.py" "$PROJECT_DIR/app.py.backup"
    sed 's/debug=True/debug=False/g' "$PROJECT_DIR/app.py" > "$PROJECT_DIR/app_test.py"
    
    # ネットワーク情報表示
    log_info "ネットワーク情報:"
    echo "  ホスト名: $(hostname)"
    echo "  IPアドレス:"
    if command -v ip &> /dev/null; then
        ip addr show | grep -E 'inet ' | grep -v 127.0.0.1 | awk '{print "    " $2}' | head -3
    else
        ifconfig | grep -E 'inet ' | grep -v 127.0.0.1 | awk '{print "    " $2}' | head -3
    fi
    
    echo ""
    log_info "🚀 テストアプリケーション起動"
    log_warn "Ctrl+C で停止"
    echo ""
    log_info "アクセスURL:"
    log_info "  http://localhost:5000"
    if [ "$ENVIRONMENT" = "wsl2" ]; then
        log_info "  http://$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost"):5000"
    fi
    echo ""
    
    # バックグラウンドで起動
    python "$PROJECT_DIR/app_test.py" &
    APP_PID=$!
    
    # 起動待機
    sleep 3
    
    # HTTP応答確認
    if curl -f -s http://localhost:5000 > /dev/null 2>&1; then
        log_info "✅ HTTP応答確認成功"
        log_info "🎉 アプリケーション正常起動"
        echo ""
        log_info "ブラウザでアクセスしてテストしてください"
        log_warn "テスト終了はCtrl+Cを押してください"
        echo ""
        
        # フォアグラウンドに戻す
        wait $APP_PID
    else
        log_error "❌ HTTP応答なし (ポート5000)"
        # ポート8080も試す
        if curl -f -s http://localhost:8080 > /dev/null 2>&1; then
            log_info "✅ ポート8080で応答確認"
            log_warn "⚠️ アプリがポート8080で起動しています"
            log_info "アクセス: http://localhost:8080"
            wait $APP_PID
        else
            log_error "❌ ポート5000, 8080どちらも応答なし"
            kill $APP_PID 2>/dev/null || true
            exit 1
        fi
    fi
    
    # クリーンアップ
    cleanup_test() {
        log_info "テストアプリケーション停止中..."
        kill $APP_PID 2>/dev/null || true
        rm -f "$PROJECT_DIR/app_test.py"
        log_info "✅ テスト完了"
    }
    
    trap cleanup_test EXIT

else
    # ==================== 本番モード ====================
    log_info "🏭 本番セットアップモード実行中..."
    
    # 本番用設定変更
    log_info "本番用設定に変更..."
    cp "$PROJECT_DIR/app.py" "$PROJECT_DIR/app.py.backup"
    sed -i 's/debug=True/debug=False/g' "$PROJECT_DIR/app.py"
    log_info "✅ デバッグモード無効化"
    
    # systemdサービスファイル作成
    log_info "systemdサービスファイル作成..."
    sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null << EOF
[Unit]
Description=Raspberry Pi Network Monitor
Documentation=Local network monitoring dashboard
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

# 起動前の待機（ネットワーク安定化）
ExecStartPre=/bin/sleep 10
ExecStart=${PYTHON_VENV}/bin/python ${PROJECT_DIR}/app.py
ExecReload=/bin/kill -HUP \$MAINPID

# 再起動設定
Restart=always
RestartSec=10
StartLimitInterval=60
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
    
    # サービス有効化と起動
    log_info "サービス有効化..."
    sudo systemctl daemon-reload
    sudo systemctl enable ${SERVICE_NAME}.service
    
    log_info "サービス起動テスト..."
    sudo systemctl start ${SERVICE_NAME}.service
    sleep 5
    
    # 起動確認
    if sudo systemctl is-active --quiet ${SERVICE_NAME}.service; then
        log_info "✅ サービス起動成功"
        
        # ポート確認
        if ss -tlnp | grep -q ":5000"; then
            log_info "✅ ポート5000でリスン確認"
        else
            log_warn "⚠️ ポート5000でリスンしていません"
        fi
        
        # Tailscale IP確認
        if command -v tailscale &> /dev/null; then
            TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
            echo ""
            echo "📱 アクセスURL:"
            echo "   ローカル: http://localhost:5000"
            echo "   Tailscale: http://${TAILSCALE_IP}:5000"
        fi
        
    else
        log_error "❌ サービス起動失敗"
        echo "エラーログ:"
        sudo journalctl -u ${SERVICE_NAME}.service -n 10 --no-pager
        exit 1
    fi
    
    # Tailscale自動起動確認
    log_info "Tailscale自動起動確認..."
    if command -v tailscale &> /dev/null; then
        sudo systemctl enable tailscaled.service
        log_info "✅ Tailscale自動起動設定完了"
    else
        log_warn "⚠️ Tailscaleが未インストールです"
        echo "   以下でインストール可能:"
        echo "   curl -fsSL https://tailscale.com/install.sh | sh"
        echo "   sudo tailscale up"
    fi
    
    # SSH自動起動確認
    log_info "SSH自動起動確認..."
    sudo systemctl enable ssh.service
    log_info "✅ SSH自動起動設定完了"
    
    # ファイアウォール設定（Tailscale使用のためスキップ）
    log_info "ファイアウォール設定確認..."
    if command -v ufw &> /dev/null; then
        # Tailscale使用時はポート開放不要
        # SSHのみ許可（ローカルネットワーク用）
        sudo ufw --force enable
        sudo ufw allow ssh
        log_info "✅ SSH用ファイアウォール設定完了（Tailscale使用）"
        log_info "ℹ️ Tailscale VPN経由のアクセスのためポート5000開放は不要"
    else
        log_info "ℹ️ UFW未インストール - Tailscale使用時は問題なし"
    fi
    
    # 自動起動テスト用スクリプト作成
    log_info "テストスクリプト作成..."
    cat > ${PROJECT_DIR}/test_autostart.sh << 'EOF'
#!/bin/bash
echo "🧪 自動起動テスト"

# サービス状態確認
if systemctl is-active --quiet network-monitor; then
    echo "✅ サービス稼働中"
else
    echo "❌ サービス停止中"
    sudo systemctl status network-monitor
    exit 1
fi

# HTTP応答確認
if curl -f -s http://localhost:5000 > /dev/null; then
    echo "✅ HTTP応答正常"
else
    echo "❌ HTTP応答なし"
    exit 1
fi

# Tailscale IP表示
if command -v tailscale &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
    echo "📱 アクセス: http://${TAILSCALE_IP}:5000"
fi

echo "🎉 自動起動テスト成功"
EOF
    
    chmod +x ${PROJECT_DIR}/test_autostart.sh
    log_info "✅ テストスクリプト作成完了"
    
    # 完了メッセージ
    echo ""
    echo "🎉 本番自動起動化設定完了！"
    echo "============================="
    log_info "次回OS再起動時から自動的にアプリが起動します"
    
    echo ""
    echo "📋 確認コマンド:"
    echo "   sudo systemctl status ${SERVICE_NAME}"
    echo "   sudo journalctl -u ${SERVICE_NAME} -f"
    echo "   ${PROJECT_DIR}/test_autostart.sh"
    
    echo ""
    echo "🔧 管理コマンド:"
    echo "   sudo systemctl start ${SERVICE_NAME}    # 手動起動"
    echo "   sudo systemctl stop ${SERVICE_NAME}     # 停止"
    echo "   sudo systemctl restart ${SERVICE_NAME}  # 再起動"
    echo "   sudo systemctl disable ${SERVICE_NAME}  # 自動起動無効化"
    
    echo ""
    echo "📱 アクセス方法:"
    echo "   Tailscale設定後、スマホから http://[TailscaleのIP]:5000"
    
    # 再起動提案
    echo ""
    read -p "今すぐ再起動して自動起動をテストしますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "5秒後に再起動します..."
        sleep 5
        sudo reboot
    else
        log_info "手動で再起動してテストしてください: sudo reboot"
    fi
fi