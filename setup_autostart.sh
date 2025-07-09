#!/bin/bash
# Raspberry Pi 監視システム 自動起動化・テスト統合スクリプト
# WSL2 & Raspberry Pi 両環境対応 - モジュラー版

set -e

echo "🚀 Raspberry Pi 監視システム 統合セットアップ"
echo "=============================================="
echo ""
echo "🛠️  実行モードを選択してください:"
echo "  1) 🏠 新規セットアップ（初回インストール）"
echo "  2) 🔄 環境リセット（更新準備）"
echo "  3) 🧪 テストモード（手動起動・終了）"
echo "  4) 📋 状態確認（現在の設定表示）"
echo "  5) 🗑️  完全アンインストール（全削除）"
echo ""
read -p "選択 (1-5): " -n 1 -r
echo
SETUP_MODE=$REPLY

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

# ==================== 環境リセット関数 ====================
reset_environment() {
    log_info "🔄 環境リセット開始..."
    
    # 現在の設定状態表示
    echo ""
    log_info "📋 現在の設定状態:"
    
    # systemdサービス状態確認
    if systemctl is-enabled ${SERVICE_NAME}.service >/dev/null 2>&1; then
        echo "  ✅ systemdサービス: 有効"
        if systemctl is-active --quiet ${SERVICE_NAME}.service; then
            echo "  🟢 サービス状態: 稼働中"
        else
            echo "  🔴 サービス状態: 停止中"
        fi
    else
        echo "  ❌ systemdサービス: 未設定"
    fi
    
    # ファイル存在確認
    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        echo "  ✅ サービスファイル: 存在"
    else
        echo "  ❌ サービスファイル: 不在"
    fi
    
    if [ -d "$PROJECT_DIR" ]; then
        echo "  ✅ プロジェクト: 存在"
    else
        echo "  ❌ プロジェクト: 不在"
    fi
    
    if [ -d "$PYTHON_VENV" ]; then
        echo "  ✅ Python仮想環境: 存在"
    else
        echo "  ❌ Python仮想環境: 不在"
    fi
    
    echo ""
    log_warn "⚠️  リセット対象:"
    echo "  • systemdサービスの停止・無効化"
    echo "  • サービスファイルの削除"
    echo "  • プロジェクトファイルのバックアップ"
    echo "  • Python依存関係のクリア"
    echo "  • ログファイルのアーカイブ"
    echo ""
    log_info "ℹ️  保持されるもの:"
    echo "  • データファイル (data/)"
    echo "  • Google Drive認証情報"
    echo "  • 録音ファイル"
    echo "  • 設定ファイル (config.yaml)"
    echo ""
    
    read -p "リセットを実行しますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "リセットをキャンセルしました"
        exit 0
    fi
    
    # 1. systemdサービス停止・無効化
    log_info "1. systemdサービス停止..."
    if systemctl is-active --quiet ${SERVICE_NAME}.service; then
        sudo systemctl stop ${SERVICE_NAME}.service
        log_info "  ✅ サービス停止完了"
    else
        log_info "  ℹ️  サービスは既に停止中"
    fi
    
    if systemctl is-enabled ${SERVICE_NAME}.service >/dev/null 2>&1; then
        sudo systemctl disable ${SERVICE_NAME}.service
        log_info "  ✅ 自動起動無効化完了"
    else
        log_info "  ℹ️  自動起動は既に無効"
    fi
    
    # 2. サービスファイル削除
    log_info "2. サービスファイル削除..."
    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
        sudo systemctl daemon-reload
        log_info "  ✅ サービスファイル削除完了"
    else
        log_info "  ℹ️  サービスファイルは存在しません"
    fi
    
    # 3. プロジェクトファイルのバックアップ
    log_info "3. プロジェクトファイルバックアップ..."
    if [ -d "$PROJECT_DIR" ]; then
        BACKUP_DIR="${CURRENT_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        # 設定ファイルとapp.pyのバックアップ
        cp "$PROJECT_DIR/config.yaml" "$BACKUP_DIR/" 2>/dev/null || true
        cp "$PROJECT_DIR/app.py" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "$PROJECT_DIR/config" "$BACKUP_DIR/" 2>/dev/null || true
        
        # requirements.txtのバックアップ
        cp "$PROJECT_DIR/requirements.txt" "$BACKUP_DIR/" 2>/dev/null || true
        
        log_info "  ✅ バックアップ完了: $BACKUP_DIR"
    else
        log_info "  ℹ️  プロジェクトディレクトリが存在しません"
    fi
    
    # 4. Python依存関係クリア
    log_info "4. Python依存関係クリア..."
    if [ -d "$PYTHON_VENV" ]; then
        # pipパッケージ一覧をバックアップ
        if [ -n "$BACKUP_DIR" ]; then
            source "$PYTHON_VENV/bin/activate"
            pip freeze > "$BACKUP_DIR/requirements_backup.txt" 2>/dev/null || true
            deactivate
        fi
        
        # venvを再作成
        rm -rf "$PYTHON_VENV"
        python3 -m venv "$PYTHON_VENV"
        source "$PYTHON_VENV/bin/activate"
        pip install --upgrade pip
        deactivate
        
        log_info "  ✅ Python仮想環境再作成完了"
    else
        log_info "  ℹ️  Python仮想環境が存在しません"
    fi
    
    # 5. ログファイルアーカイブ
    log_info "5. ログファイルアーカイブ..."
    if [ -n "$BACKUP_DIR" ]; then
        # systemdログのバックアップ
        sudo journalctl -u ${SERVICE_NAME}.service --no-pager > "$BACKUP_DIR/service_logs.txt" 2>/dev/null || true
        log_info "  ✅ ログアーカイブ完了"
    fi
    
    # 6. キャッシュクリア
    log_info "6. キャッシュクリア..."
    if [ -d "$PROJECT_DIR/__pycache__" ]; then
        rm -rf "$PROJECT_DIR/__pycache__"
    fi
    find "$PROJECT_DIR" -name "*.pyc" -delete 2>/dev/null || true
    find "$PROJECT_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    log_info "  ✅ キャッシュクリア完了"
    
    echo ""
    log_info "🎉 環境リセット完了！"
    echo "============================================"
    echo ""
    log_info "📁 バックアップ場所: $BACKUP_DIR"
    echo "  • config.yaml - 設定ファイル"
    echo "  • app.py - メインアプリケーション"
    echo "  • requirements_backup.txt - Pythonパッケージ一覧"
    echo "  • service_logs.txt - サービスログ"
    echo ""
    log_info "🔄 次のステップ:"
    echo "  1. 新しいプログラムをmonitoring-system/にコピー"
    echo "  2. ./setup_autostart.sh を再実行して新規セットアップを選択"
    echo "  3. 必要に応じてバックアップから設定を復元"
    echo ""
}

# ==================== 完全アンインストール関数 ====================
uninstall_completely() {
    log_warn "🗑️  完全アンインストール開始..."
    echo ""
    log_error "⚠️  警告: この操作は以下を完全に削除します！"
    echo "  • ラズパイ監視システムの全ファイル"
    echo "  • systemdサービス設定"
    echo "  • Python仮想環境"
    echo "  • データファイル（録音ファイル、Google Drive認証情報等）"
    echo "  • ログファイル"
    echo "  • バックアップファイル"
    echo ""
    echo "📝 削除対象:"
    [ -d "$PROJECT_DIR" ] && echo "  ✅ $PROJECT_DIR"
    [ -d "$PYTHON_VENV" ] && echo "  ✅ $PYTHON_VENV"
    [ -d "${CURRENT_DIR}/data" ] && echo "  ✅ ${CURRENT_DIR}/data"
    [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ] && echo "  ✅ /etc/systemd/system/${SERVICE_NAME}.service"
    find "$CURRENT_DIR" -maxdepth 1 -name "backup_*" -type d 2>/dev/null | head -5 | while read backup; do
        echo "  ✅ $backup"
    done
    
    echo ""
    read -p "本当に完全アンインストールしますか？ (yes/no): " -r
    if [[ ! $REPLY = "yes" ]]; then
        log_info "アンインストールをキャンセルしました"
        exit 0
    fi
    
    # サービス停止・無効化
    if systemctl is-active --quiet ${SERVICE_NAME}.service; then
        sudo systemctl stop ${SERVICE_NAME}.service
    fi
    if systemctl is-enabled ${SERVICE_NAME}.service >/dev/null 2>&1; then
        sudo systemctl disable ${SERVICE_NAME}.service
    fi
    
    # サービスファイル削除
    sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    sudo systemctl daemon-reload
    
    # プロジェクトファイル削除
    rm -rf "$PROJECT_DIR"
    rm -rf "$PYTHON_VENV"
    rm -rf "${CURRENT_DIR}/data"
    
    # バックアップ削除
    find "$CURRENT_DIR" -maxdepth 1 -name "backup_*" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # 管理スクリプト削除
    rm -f "${CURRENT_DIR}/test_autostart.sh"
    rm -f "${CURRENT_DIR}/system_info.txt"
    
    log_info "✅ 完全アンインストール完了"
}

# ==================== 状態確認関数 ====================
check_status() {
    log_info "📋 現在の設定状態確認"
    echo "==========================================="
    
    # システム情報
    echo "🖥️  システム情報:"
    echo "  環境: $ENVIRONMENT"
    echo "  ユーザー: $USER"
    echo "  ホスト名: $(hostname)"
    echo "  OS: $(uname -a)"
    echo ""
    
    # ファイル構造
    echo "📁 ファイル構造:"
    if [ -d "$PROJECT_DIR" ]; then
        echo "  ✅ プロジェクト: $PROJECT_DIR"
        if [ -f "$PROJECT_DIR/app.py" ]; then
            echo "    ✅ app.py"
        else
            echo "    ❌ app.py (不在)"
        fi
        if [ -f "$PROJECT_DIR/config.yaml" ]; then
            echo "    ✅ config.yaml"
        else
            echo "    ❌ config.yaml (不在)"
        fi
    else
        echo "  ❌ プロジェクト: 不在"
    fi
    
    if [ -d "$PYTHON_VENV" ]; then
        echo "  ✅ Python仮想環境: $PYTHON_VENV"
        if [ -f "$PYTHON_VENV/bin/python" ]; then
            PYTHON_VERSION=$("$PYTHON_VENV/bin/python" --version 2>&1)
            echo "    ✅ $PYTHON_VERSION"
        fi
    else
        echo "  ❌ Python仮想環境: 不在"
    fi
    
    if [ -d "${CURRENT_DIR}/data" ]; then
        echo "  ✅ データディレクトリ: ${CURRENT_DIR}/data"
        if [ -f "${CURRENT_DIR}/data/credentials/credentials.json" ]; then
            echo "    ✅ Google Drive認証"
        else
            echo "    ❌ Google Drive認証 (未設定)"
        fi
        
        RECORDING_COUNT=$(find "${CURRENT_DIR}/data/recordings" -name "*.wav" 2>/dev/null | wc -l)
        echo "    📼 録音ファイル: ${RECORDING_COUNT}個"
    else
        echo "  ❌ データディレクトリ: 不在"
    fi
    echo ""
    
    # systemdサービス状態
    echo "⚙️  systemdサービス:"
    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        echo "  ✅ サービスファイル: 存在"
        
        if systemctl is-enabled ${SERVICE_NAME}.service >/dev/null 2>&1; then
            echo "  ✅ 自動起動: 有効"
        else
            echo "  ❌ 自動起動: 無効"
        fi
        
        if systemctl is-active --quiet ${SERVICE_NAME}.service; then
            echo "  🟢 サービス状態: 稼働中"
            
            # ポート確認
            if ss -tlnp | grep -q ":5000"; then
                echo "  ✅ ポート5000: リスン中"
            else
                echo "  ❌ ポート5000: 未使用"
            fi
            
            # HTTP応答確認
            if curl -f -s http://localhost:5000 > /dev/null 2>&1; then
                echo "  ✅ HTTP応答: 正常"
            else
                echo "  ❌ HTTP応答: 異常"
            fi
        else
            echo "  🔴 サービス状態: 停止中"
        fi
    else
        echo "  ❌ サービスファイル: 不在"
        echo "  ❌ 自動起動: 未設定"
        echo "  ❌ サービス状態: 未設定"
    fi
    echo ""
    
    # ネットワーク情報
    echo "🌐 ネットワーク情報:"
    if command -v ip &> /dev/null; then
        LOCAL_IPS=$(ip addr show | grep -E 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1)
        echo "  📍 ローカルIP:"
        echo "$LOCAL_IPS" | while read ip; do
            [ -n "$ip" ] && echo "    http://$ip:5000"
        done
    fi
    
    if command -v tailscale &> /dev/null; then
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
        if [ "$TAILSCALE_IP" != "未設定" ]; then
            echo "  🔒 Tailscale: http://$TAILSCALE_IP:5000"
        else
            echo "  ❌ Tailscale: 未設定"
        fi
    else
        echo "  ❌ Tailscale: 未インストール"
    fi
    echo ""
    
    # 最近のログ
    echo "📜 最近のログ (最新5行):"
    if systemctl is-active --quiet ${SERVICE_NAME}.service; then
        sudo journalctl -u ${SERVICE_NAME}.service -n 5 --no-pager 2>/dev/null || echo "  ログを取得できませんでした"
    else
        echo "  サービスが停止中のためログなし"
    fi
    echo ""
    
    # バックアップ一覧
    echo "📦 バックアップ一覧:"
    BACKUP_COUNT=$(find "$CURRENT_DIR" -maxdepth 1 -name "backup_*" -type d 2>/dev/null | wc -l)
    if [ $BACKUP_COUNT -gt 0 ]; then
        echo "  📁 バックアップ数: ${BACKUP_COUNT}個"
        find "$CURRENT_DIR" -maxdepth 1 -name "backup_*" -type d 2>/dev/null | sort -r | head -3 | while read backup; do
            BACKUP_SIZE=$(du -sh "$backup" 2>/dev/null | cut -f1)
            BACKUP_NAME=$(basename "$backup")
            echo "    $BACKUP_NAME ($BACKUP_SIZE)"
        done
        [ $BACKUP_COUNT -gt 3 ] && echo "    ... 他 $((BACKUP_COUNT - 3))個"
    else
        echo "  📁 バックアップ: なし"
    fi
    echo ""
    
    # 管理コマンド
    echo "🔧 管理コマンド:"
    echo "  sudo systemctl status ${SERVICE_NAME}     # 詳細状態"
    echo "  sudo systemctl restart ${SERVICE_NAME}    # 再起動"
    echo "  sudo journalctl -u ${SERVICE_NAME} -f     # ログ監視"
    echo "  ./test_autostart.sh                      # テスト実行"
    echo ""
}

# ==================== メインフロー ====================

case $SETUP_MODE in
    "1")
        log_info "🏠 新規セットアップモードを選択"
        setup_new_installation
        ;;
    "2")
        log_info "🔄 環境リセットモードを選択"
        reset_environment
        ;;
    "3")
        log_info "🧪 テストモードを選択"
        run_test_mode
        ;;
    "4")
        log_info "📋 状態確認モードを選択"
        check_status
        ;;
    "5")
        log_info "🗑️ 完全アンインストールモードを選択"
        uninstall_completely
        ;;
    *)
        log_error "無効な選択です: $SETUP_MODE"
        log_error "1-5の数字を選択してください"
        exit 1
        ;;
esac

# ==================== 新規セットアップ関数 ====================
setup_new_installation() {
    log_info "🏠 新規セットアップ開始..."
    
    # 環境別処理
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

    # Python仮想環境を非アクティブ化
    deactivate

    # モード別処理
    if [ "$MODE" = "test" ]; then
        run_test_mode
    else
        setup_production_mode
    fi
}

# ==================== テストモード関数 ====================
run_test_mode() {
    log_info "🧪 テストモード実行中..."
    
    # 基本チェック
    if [ ! -d "$PROJECT_DIR" ]; then
        log_error "プロジェクトディレクトリが見つかりません: $PROJECT_DIR"
        exit 1
    fi

    if [ ! -f "$PROJECT_DIR/app.py" ]; then
        log_error "app.pyが見つかりません: $PROJECT_DIR/app.py"
        exit 1
    fi

    if [ ! -d "$PYTHON_VENV" ]; then
        log_error "Python仮想環境が見つかりません: $PYTHON_VENV"
        exit 1
    fi
    
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
        ifconfig 2>/dev/null | grep -E 'inet ' | grep -v 127.0.0.1 | awk '{print "    " $2}' | head -3
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
    DATA_DIR="$CURRENT_DIR/data"
    if [ -f "$DATA_DIR/credentials/credentials.json" ]; then
        echo "  ✅ Google Drive連携（認証ファイル有り）"
    else
        echo "  ⚠️ Google Drive連携（認証ファイル無し）"
        echo "     credentials.jsonを $DATA_DIR/credentials/ に配置してください"
    fi
    
    # Python仮想環境をアクティベート
    source "$PYTHON_VENV/bin/activate"
    
    # バックグラウンドで起動
    cd "$PROJECT_DIR"
    python app_test.py &
    APP_PID=$!
    
    # クリーンアップ関数
    cleanup_test() {
        log_info "テストアプリケーション停止中..."
        kill $APP_PID 2>/dev/null || true
        rm -f "$PROJECT_DIR/app_test.py"
        deactivate 2>/dev/null || true
        log_info "✅ テスト完了"
    }
    
    trap cleanup_test EXIT
    
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
        kill $APP_PID 2>/dev/null || true
        exit 1
    fi
}

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
        kill $APP_PID 2>/dev/null || true
        exit 1
    fi
}

# ==================== 本番モード設定関数 ====================
setup_production_mode() {
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
    DATA_DIR="$CURRENT_DIR/data"
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
    create_test_scripts
    
    # 完了メッセージ
    show_completion_message
}

# ==================== テストスクリプト作成関数 ====================
create_test_scripts() {
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
    create_test_scripts
    
    # 完了メッセージ
    show_completion_message
}

# ==================== テストスクリプト作成関数 ====================
create_test_scripts() {
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
}

# ==================== 完了メッセージ表示関数 ====================
show_completion_message() {
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
}

# ==================== メインフロー ====================

case $SETUP_MODE in
    "1")
        log_info "🏠 新規セットアップモードを選択"
        setup_new_installation
        ;;
    "2")
        log_info "🔄 環境リセットモードを選択"
        reset_environment
        ;;
    "3")
        log_info "🧪 テストモードを選択"
        run_test_mode
        ;;
    "4")
        log_info "📋 状態確認モードを選択"
        check_status
        ;;
    "5")
        log_info "🗑️ 完全アンインストールモードを選択"
        uninstall_completely
        ;;
    *)
        log_error "無効な選択です: $SETUP_MODE"
        log_error "1-5の数字を選択してください"
        exit 1
        ;;
esac

log_info "✅ スクリプト実行完了"

# スクリプトの終了
exit 0