#!/bin/bash
# Raspberry Pi 監視システム 自動起動化・テスト統合スクリプト
# WSL2 & Raspberry Pi 両環境対応 - モジュラー版

set -e

echo "🚀 Raspberry Pi 監視システム 統合セットアップ"
echo "=============================================="

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
    log_error "  cd environment-setup && ./setup_complete.sh"
    exit 1
fi

if [ ! -f "$PYTHON_VENV/bin/python" ]; then
    log_error "Python実行ファイルが見つかりません"
    exit 1
fi

log_info "✅ Python仮想環境確認完了"

# モジュール構造確認
log_info "モジュール構造確認..."
if [ ! -d "$PROJECT_DIR/modules" ]; then
    log_error "modulesディレクトリが見つかりません"
    exit 1
fi

if [ ! -d "$PROJECT_DIR/modules/network" ] || [ ! -d "$PROJECT_DIR/modules/recording" ] || [ ! -d "$PROJECT_DIR/modules/gdrive" ]; then
    log_error "必要なモジュールが見つかりません"
    log_error "modules/network, modules/recording, modules/gdrive が必要です"
    exit 1
fi

log_info "✅ モジュール構造確認完了"

# 依存関係確認
log_info "Python依存関係確認・インストール..."
source "$PYTHON_VENV/bin/activate"

# requirements.txtから依存関係インストール
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
    pip install -r "$PROJECT_DIR/requirements.txt"
else
    # 基本的な依存関係をインストール
    pip install flask psutil requests google-auth google-auth-oauthlib google-auth-httplib2 google-api-python-client pyaudio sounddevice scipy numpy pyyaml
fi

log_info "✅ 依存関係確認完了"

# データディレクトリ確認・作成
log_info "データディレクトリ確認..."
DATA_DIR="$CURRENT_DIR/data"
mkdir -p "$DATA_DIR/recordings"
mkdir -p "$DATA_DIR/credentials"
chown -R $USER:$USER "$DATA_DIR"
log_info "✅ データディレクトリ設定完了"

# モード別処理
if [ "$MODE" = "test" ]; then
    # ==================== テストモード ====================
    log_info "🧪 テストモード実行中..."
    
    # 本番用設定でコピー作成
    log_info "テスト用設定ファイル作成..."
    cp "$PROJECT_DIR/app.py" "$PROJECT_DIR/app.py.backup"
    
    # デバッグモード無効化（本番環境テスト）
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
    log_info "  メイン画面: http://localhost:5000"
    log_info "  録音機能: http://localhost:5000/recording"
    log_info "  Google Drive: http://localhost:5000/gdrive"
    if [ "$ENVIRONMENT" = "wsl2" ]; then
        LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
        log_info "  外部アクセス: http://${LOCAL_IP}:5000"
    fi
    echo ""
    
    # 設定表示
    log_info "機能の確認:"
    echo "  ✅ ネットワーク監視"
    echo "  ✅ 録音機能"
    if [ -f "$DATA_DIR/credentials/credentials.json" ]; then
        echo "  ✅ Google Drive連携（認証ファイル有り）"
    else
        echo "  ⚠️ Google Drive連携（認証ファイル無し）"
        echo "     credentials.jsonを $DATA_DIR/credentials/ に配置してください"
    fi
    
    # バックグラウンドで起動
    cd "$PROJECT_DIR"
    python app_test.py &
    APP_PID=$!
    
    # 起動待機
    sleep 5
    
    # HTTP応答確認
    if curl -f -s http://localhost:5000 > /dev/null 2>&1; then
        log_info "✅ HTTP応答確認成功"
        log_info "🎉 アプリケーション正常起動"
        echo ""
        log_info "ブラウザでアクセスしてテストしてください"
        log_warn "テスト終了はCtrl+Cを押してください"
        echo ""
        
        # API エンドポイントテスト
        log_info "API エンドポイントテスト:"
        if curl -f -s http://localhost:5000/api/network-status > /dev/null; then
            echo "  ✅ ネットワーク監視API"
        else
            echo "  ❌ ネットワーク監視API"
        fi
        
        if curl -f -s http://localhost:5000/api/recording/devices > /dev/null; then
            echo "  ✅ 録音デバイスAPI"
        else
            echo "  ❌ 録音デバイスAPI"
        fi
        
        if curl -f -s http://localhost:5000/api/gdrive-status > /dev/null; then
            echo "  ✅ Google Drive API"
        else
            echo "  ❌ Google Drive API"
        fi
        
        echo ""
        # フォアグラウンドに戻す
        wait $APP_PID
    else
        log_error "❌ HTTP応答なし (ポート5000)"
        # エラーログ表示
        log_error "アプリケーションログ:"
        kill $APP_PID 2>/dev/null || true
        exit 1
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
Description=Raspberry Pi Monitoring System (Modular)
Documentation=Raspberry Pi network monitoring, recording, and Google Drive integration
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
RestartSec=15
StartLimitInterval=120
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
    
    # 権限設定
    log_info "権限設定..."
    chown -R $USER:$USER "$PROJECT_DIR"
    chown -R $USER:$USER "$DATA_DIR"
    chmod +x "$PROJECT_DIR/app.py"
    
    # サービス有効化と起動
    log_info "サービス有効化..."
    sudo systemctl daemon-reload
    sudo systemctl enable ${SERVICE_NAME}.service
    
    log_info "サービス起動テスト..."
    sudo systemctl start ${SERVICE_NAME}.service
    sleep 10
    
    # 起動確認
    if sudo systemctl is-active --quiet ${SERVICE_NAME}.service; then
        log_info "✅ サービス起動成功"
        
        # ポート確認
        if ss -tlnp | grep -q ":5000"; then
            log_info "✅ ポート5000でリスン確認"
        else
            log_warn "⚠️ ポート5000でリスンしていません"
        fi
        
        # HTTP応答確認
        sleep 5
        if curl -f -s http://localhost:5000 > /dev/null; then
            log_info "✅ HTTP応答確認成功"
        else
            log_warn "⚠️ HTTP応答なし"
        fi
        
        # Tailscale IP確認
        if command -v tailscale &> /dev/null; then
            TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
            echo ""
            echo "📱 アクセスURL:"
            echo "   ローカル: http://localhost:5000"
            echo "   Tailscale: http://${TAILSCALE_IP}:5000"
            echo ""
            echo "   機能別URL:"
            echo "   📊 メイン画面: http://${TAILSCALE_IP}:5000"
            echo "   🎤 録音機能: http://${TAILSCALE_IP}:5000/recording"
            echo "   ☁️ Google Drive: http://${TAILSCALE_IP}:5000/gdrive"
        fi
        
    else
        log_error "❌ サービス起動失敗"
        echo "エラーログ:"
        sudo journalctl -u ${SERVICE_NAME}.service -n 20 --no-pager
        exit 1
    fi
    
    # 音声デバイス権限設定（録音機能用）
    log_info "音声デバイス権限設定..."
    sudo usermod -a -G audio $USER
    log_info "✅ audioグループに追加完了"
    
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
    cat > ${CURRENT_DIR}/test_autostart.sh << 'EOF'
#!/bin/bash
echo "🧪 Raspberry Pi 監視システム 自動起動テスト"

SERVICE_NAME="raspi-monitoring"

# サービス状態確認
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "✅ サービス稼働中"
else
    echo "❌ サービス停止中"
    sudo systemctl status $SERVICE_NAME
    exit 1
fi

# HTTP応答確認
if curl -f -s http://localhost:5000 > /dev/null; then
    echo "✅ HTTP応答正常"
else
    echo "❌ HTTP応答なし"
    exit 1
fi

# API エンドポイントテスト
echo "API エンドポイントテスト:"
if curl -f -s http://localhost:5000/api/network-status > /dev/null; then
    echo "  ✅ ネットワーク監視API"
else
    echo "  ❌ ネットワーク監視API"
fi

if curl -f -s http://localhost:5000/api/recording/devices > /dev/null; then
    echo "  ✅ 録音デバイスAPI"
else
    echo "  ❌ 録音デバイスAPI"
fi

if curl -f -s http://localhost:5000/api/gdrive-status > /dev/null; then
    echo "  ✅ Google Drive API"
else
    echo "  ❌ Google Drive API"
fi

# Tailscale IP表示
if command -v tailscale &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
    echo ""
    echo "📱 アクセス:"
    echo "   メイン: http://${TAILSCALE_IP}:5000"
    echo "   録音: http://${TAILSCALE_IP}:5000/recording"
    echo "   Drive: http://${TAILSCALE_IP}:5000/gdrive"
fi

echo "🎉 自動起動テスト成功"
EOF
    
    chmod +x ${CURRENT_DIR}/test_autostart.sh
    log_info "✅ テストスクリプト作成完了"
    
    # 設定情報ファイル作成
    log_info "設定情報ファイル作成..."
    cat > ${CURRENT_DIR}/system_info.txt << EOF
Raspberry Pi 監視システム - 設定情報
====================================

セットアップ日時: $(date)
プロジェクトディレクトリ: ${PROJECT_DIR}
データディレクトリ: ${DATA_DIR}
Python仮想環境: ${PYTHON_VENV}

systemdサービス名: ${SERVICE_NAME}

利用可能な機能:
- ネットワーク監視
- 録音機能
- Google Drive連携

管理コマンド:
- sudo systemctl status ${SERVICE_NAME}
- sudo systemctl restart ${SERVICE_NAME}
- sudo journalctl -u ${SERVICE_NAME} -f

テストコマンド:
- ./test_autostart.sh

Google Drive設定:
- 認証ファイル: ${DATA_DIR}/credentials/credentials.json
- トークンファイル: ${DATA_DIR}/credentials/token.json
EOF
    
    # 完了メッセージ
    echo ""
    echo "🎉 Raspberry Pi 監視システム 本番自動起動化設定完了！"
    echo "======================================================"
    log_info "次回OS再起動時から自動的にアプリが起動します"
    
    echo ""
    echo "📋 確認コマンド:"
    echo "   sudo systemctl status ${SERVICE_NAME}"
    echo "   sudo journalctl -u ${SERVICE_NAME} -f"
    echo "   ./test_autostart.sh"
    
    echo ""
    echo "🔧 管理コマンド:"
    echo "   sudo systemctl start ${SERVICE_NAME}    # 手動起動"
    echo "   sudo systemctl stop ${SERVICE_NAME}     # 停止"
    echo "   sudo systemctl restart ${SERVICE_NAME}  # 再起動"
    echo "   sudo systemctl disable ${SERVICE_NAME}  # 自動起動無効化"
    
    echo ""
    echo "📱 利用可能な機能:"
    echo "   📊 ネットワーク監視: リアルタイムネットワーク状態"
    echo "   🎤 録音機能: 音声録音・Google Driveアップロード"
    echo "   ☁️ Google Drive連携: データ自動バックアップ"
    
    echo ""
    echo "🔧 Google Drive設定:"
    echo "   1. Google Cloud Consoleでプロジェクト作成"
    echo "   2. Drive APIを有効化"
    echo "   3. 認証情報(JSON)をダウンロード"
    echo "   4. ${DATA_DIR}/credentials/credentials.json に配置"
    
    echo ""
    echo "📱 アクセス方法:"
    echo "   Tailscale設定後、スマホから http://[TailscaleのIP]:5000"
    echo "   各機能は /recording、/gdrive でアクセス可能"
    
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
        log_info "再起動後は ./test_autostart.sh でテスト可能です"
    fi
fi