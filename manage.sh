#!/bin/bash
# Raspberry Pi 監視システム 管理スクリプト
# モジュラー版専用

SERVICE_NAME="raspi-monitoring"
PROJECT_DIR="$(pwd)/monitoring-system"
DATA_DIR="$(pwd)/data"

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

show_help() {
    echo "Raspberry Pi 監視システム 管理スクリプト"
    echo "=========================================="
    echo ""
    echo "使用方法: $0 [コマンド]"
    echo ""
    echo "コマンド:"
    echo "  status      - サービス状態表示"
    echo "  start       - サービス開始"
    echo "  stop        - サービス停止"
    echo "  restart     - サービス再起動"
    echo "  logs        - ログ表示（リアルタイム）"
    echo "  test        - 動作テスト"
    echo "  info        - システム情報表示"
    echo "  gdrive      - Google Drive設定確認"
    echo "  backup      - 設定バックアップ"
    echo "  update      - システム更新"
    echo "  help        - このヘルプを表示"
    echo ""
}

check_service_status() {
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_info "✅ サービス稼働中"
        return 0
    else
        log_warn "❌ サービス停止中"
        return 1
    fi
}

show_status() {
    echo "Raspberry Pi 監視システム 状態確認"
    echo "==================================="
    echo ""
    
    # サービス状態
    echo "📊 サービス状態:"
    if check_service_status; then
        echo "  状態: 稼働中"
        echo "  起動時間: $(systemctl show $SERVICE_NAME --property=ActiveEnterTimestamp --value | cut -d' ' -f2-3)"
    else
        echo "  状態: 停止中"
    fi
    
    # ポート状態
    echo ""
    echo "🌐 ネットワーク状態:"
    if ss -tlnp | grep -q ":5000"; then
        echo "  ポート5000: リスン中"
    else
        echo "  ポート5000: 閉じている"
    fi
    
    # HTTP応答確認
    if curl -f -s http://localhost:5000 > /dev/null 2>&1; then
        echo "  HTTP応答: 正常"
    else
        echo "  HTTP応答: エラー"
    fi
    
    # Tailscale状態
    echo ""
    echo "🔗 Tailscale状態:"
    if command -v tailscale &> /dev/null; then
        if tailscale status &> /dev/null; then
            TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "取得失敗")
            echo "  状態: 接続中"
            echo "  IP: $TAILSCALE_IP"
        else
            echo "  状態: 未接続"
        fi
    else
        echo "  状態: 未インストール"
    fi
    
    # ディスク使用量
    echo ""
    echo "💾 ディスク使用量:"
    echo "  プロジェクト: $(du -sh $PROJECT_DIR 2>/dev/null | cut -f1 || echo "不明")"
    echo "  データ: $(du -sh $DATA_DIR 2>/dev/null | cut -f1 || echo "不明")"
    if [ -d "$DATA_DIR/recordings" ]; then
        echo "  録音ファイル: $(du -sh $DATA_DIR/recordings 2>/dev/null | cut -f1 || echo "不明")"
    fi
    
    # メモリ使用量
    echo ""
    echo "🧠 メモリ使用量:"
    if pgrep -f "python.*app.py" > /dev/null; then
        PID=$(pgrep -f "python.*app.py")
        MEM=$(ps -p $PID -o %mem --no-headers 2>/dev/null | tr -d ' ' || echo "不明")
        echo "  Python プロセス: ${MEM}%"
    else
        echo "  Python プロセス: 実行されていません"
    fi
}

run_test() {
    echo "🧪 動作テスト実行中..."
    echo ""
    
    # サービス状態テスト
    if check_service_status; then
        echo "✅ サービス状態: OK"
    else
        echo "❌ サービス状態: NG"
        return 1
    fi
    
    # HTTP応答テスト
    if curl -f -s http://localhost:5000 > /dev/null 2>&1; then
        echo "✅ HTTP応答: OK"
    else
        echo "❌ HTTP応答: NG"
        return 1
    fi
    
    # API エンドポイントテスト
    echo ""
    echo "🔌 API エンドポイントテスト:"
    
    # ネットワーク監視API
    if curl -f -s http://localhost:5000/api/network-status > /dev/null 2>&1; then
        echo "  ✅ ネットワーク監視API: OK"
    else
        echo "  ❌ ネットワーク監視API: NG"
    fi
    
    # 録音デバイスAPI
    if curl -f -s http://localhost:5000/api/recording/devices > /dev/null 2>&1; then
        echo "  ✅ 録音デバイスAPI: OK"
    else
        echo "  ❌ 録音デバイスAPI: NG"
    fi
    
    # Google Drive API
    if curl -f -s http://localhost:5000/api/gdrive-status > /dev/null 2>&1; then
        echo "  ✅ Google Drive API: OK"
    else
        echo "  ❌ Google Drive API: NG"
    fi
    
    # ファイル一覧API
    if curl -f -s http://localhost:5000/api/gdrive-files > /dev/null 2>&1; then
        echo "  ✅ ファイル管理API: OK"
    else
        echo "  ❌ ファイル管理API: NG"
    fi
    
    echo ""
    echo "🎉 動作テスト完了"
    
    # Tailscale IP表示
    if command -v tailscale &> /dev/null; then
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未設定")
        echo ""
        echo "📱 外部アクセスURL:"
        echo "   メイン: http://${TAILSCALE_IP}:5000"
        echo "   録音: http://${TAILSCALE_IP}:5000/recording"
        echo "   Drive: http://${TAILSCALE_IP}:5000/gdrive"
    fi
}

show_info() {
    echo "Raspberry Pi 監視システム 情報"
    echo "==============================="
    echo ""
    
    # システム情報
    echo "💻 システム情報:"
    echo "  ホスト名: $(hostname)"
    echo "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || echo "不明")"
    echo "  カーネル: $(uname -r)"
    echo "  アーキテクチャ: $(uname -m)"
    
    # ハードウェア情報（Raspberry Pi用）
    if [ -f /proc/device-tree/model ]; then
        echo "  モデル: $(cat /proc/device-tree/model | tr -d '\0')"
    fi
    
    # プロジェクト情報
    echo ""
    echo "📁 プロジェクト情報:"
    echo "  プロジェクトディレクトリ: $PROJECT_DIR"
    echo "  データディレクトリ: $DATA_DIR"
    echo "  サービス名: $SERVICE_NAME"
    
    # Python環境
    echo ""
    echo "🐍 Python環境:"
    PYTHON_PATH="$(pwd)/venv/bin/python"
    if [ -f "$PYTHON_PATH" ]; then
        echo "  Python: $($PYTHON_PATH --version 2>&1)"
        echo "  仮想環境: 有効"
    else
        echo "  Python: システム版"
        echo "  仮想環境: 無効"
    fi
    
    # モジュール情報
    echo ""
    echo "📦 モジュール情報:"
    if [ -d "$PROJECT_DIR/modules" ]; then
        echo "  ✅ モジュラー構造"
        echo "  ネットワーク: $([ -d "$PROJECT_DIR/modules/network" ] && echo "有効" || echo "無効")"
        echo "  録音: $([ -d "$PROJECT_DIR/modules/recording" ] && echo "有効" || echo "無効")"
        echo "  Google Drive: $([ -d "$PROJECT_DIR/modules/gdrive" ] && echo "有効" || echo "無効")"
    else
        echo "  ❌ モジュール構造エラー"
    fi
    
    # ネットワーク情報
    echo ""
    echo "🌐 ネットワーク情報:"
    if command -v ip &> /dev/null; then
        ip addr show | grep -E 'inet ' | grep -v 127.0.0.1 | while read line; do
            echo "  $(echo $line | awk '{print $2}')"
        done
    else
        ifconfig | grep -E 'inet ' | grep -v 127.0.0.1 | while read line; do
            echo "  $(echo $line | awk '{print $2}')"
        done
    fi
    
    # 容量情報
    echo ""
    echo "💾 ストレージ情報:"
    df -h / | tail -n 1 | awk '{print "  ルート: " $3 "/" $2 " (" $5 " 使用)"}'
    if [ -d "$DATA_DIR" ]; then
        echo "  データ: $(du -sh $DATA_DIR | cut -f1)"
    fi
}

check_gdrive() {
    echo "☁️ Google Drive 設定確認"
    echo "========================="
    echo ""
    
    # 認証ファイル確認
    CRED_FILE="$DATA_DIR/credentials/credentials.json"
    TOKEN_FILE="$DATA_DIR/credentials/token.json"
    
    echo "📄 認証ファイル:"
    if [ -f "$CRED_FILE" ]; then
        echo "  ✅ credentials.json: 存在"
        FILE_SIZE=$(stat -f%z "$CRED_FILE" 2>/dev/null || stat -c%s "$CRED_FILE" 2>/dev/null || echo "0")
        echo "     サイズ: ${FILE_SIZE} bytes"
    else
        echo "  ❌ credentials.json: 未設定"
        echo "     Google Cloud Consoleから取得して配置してください"
        echo "     配置先: $CRED_FILE"
    fi
    
    if [ -f "$TOKEN_FILE" ]; then
        echo "  ✅ token.json: 存在"
        echo "     認証済み"
    else
        echo "  ⚠️ token.json: 未生成"
        echo "     初回認証が必要です"
    fi
    
    # API接続テスト
    echo ""
    echo "🔌 API接続テスト:"
    if curl -f -s http://localhost:5000/api/gdrive-status > /dev/null 2>&1; then
        echo "  ✅ Google Drive API: 応答正常"
        
        # 実際のステータス取得
        RESPONSE=$(curl -s http://localhost:5000/api/gdrive-status 2>/dev/null)
        if echo "$RESPONSE" | grep -q "connected"; then
            echo "  ✅ Google Drive: 接続済み"
            USER_EMAIL=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('user_email', '不明'))" 2>/dev/null || echo "不明")
            echo "     ユーザー: $USER_EMAIL"
        else
            echo "  ⚠️ Google Drive: 未接続"
        fi
    else
        echo "  ❌ Google Drive API: エラー"
    fi
    
    # 設定手順表示
    if [ ! -f "$CRED_FILE" ]; then
        echo ""
        echo "🔧 Google Drive設定手順:"
        echo "1. Google Cloud Console (https://console.cloud.google.com) にアクセス"
        echo "2. 新しいプロジェクトを作成"
        echo "3. Google Drive API を有効化"
        echo "4. 認証情報 > OAuth 2.0 クライアントID を作成"
        echo "5. アプリケーションの種類: デスクトップアプリケーション"
        echo "6. JSONファイルをダウンロード"
        echo "7. ファイル名を credentials.json に変更"
        echo "8. $CRED_FILE に配置"
        echo "9. アプリを再起動して認証実行"
    fi
}

backup_config() {
    echo "💾 設定バックアップ実行中..."
    
    BACKUP_DIR="$HOME/raspi-monitoring-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # 設定ファイルバックアップ
    if [ -f "$PROJECT_DIR/config.yaml" ]; then
        cp "$PROJECT_DIR/config.yaml" "$BACKUP_DIR/"
        log_info "✅ config.yaml をバックアップ"
    fi
    
    # Google Drive認証情報バックアップ
    if [ -d "$DATA_DIR/credentials" ]; then
        cp -r "$DATA_DIR/credentials" "$BACKUP_DIR/"
        log_info "✅ Google Drive認証情報をバックアップ"
    fi
    
    # systemdサービスファイルバックアップ
    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        sudo cp "/etc/systemd/system/${SERVICE_NAME}.service" "$BACKUP_DIR/"
        sudo chown $USER:$USER "$BACKUP_DIR/${SERVICE_NAME}.service"
        log_info "✅ systemdサービスファイルをバックアップ"
    fi
    
    # カスタム設定ファイルバックアップ
    if [ -f "$PROJECT_DIR/config/settings.py" ]; then
        cp "$PROJECT_DIR/config/settings.py" "$BACKUP_DIR/"
        log_info "✅ settings.py をバックアップ"
    fi
    
    # バックアップ情報ファイル作成
    cat > "$BACKUP_DIR/backup_info.txt" << EOF
Raspberry Pi 監視システム バックアップ情報
==========================================

バックアップ日時: $(date)
システム: $(hostname)
プロジェクト: $PROJECT_DIR
データディレクトリ: $DATA_DIR

含まれるファイル:
$(ls -la "$BACKUP_DIR/" | tail -n +2)

復元手順:
1. credentials/ フォルダを $DATA_DIR/ にコピー
2. config.yaml を $PROJECT_DIR/ にコピー
3. settings.py を $PROJECT_DIR/config/ にコピー
4. ${SERVICE_NAME}.service を /etc/systemd/system/ にコピー
5. sudo systemctl daemon-reload
6. sudo systemctl restart ${SERVICE_NAME}
EOF
    
    echo ""
    log_info "✅ バックアップ完了: $BACKUP_DIR"
    echo "📁 バックアップ内容:"
    ls -la "$BACKUP_DIR/"
}

update_system() {
    echo "🔄 システム更新実行中..."
    
    # サービス停止
    log_info "サービス一時停止..."
    sudo systemctl stop $SERVICE_NAME
    
    # Python依存関係更新
    log_info "Python依存関係更新..."
    VENV_PATH="$(pwd)/venv"
    if [ -d "$VENV_PATH" ]; then
        source "$VENV_PATH/bin/activate"
        
        if [ -f "$PROJECT_DIR/requirements.txt" ]; then
            pip install --upgrade -r "$PROJECT_DIR/requirements.txt"
        else
            pip install --upgrade flask psutil requests google-auth google-auth-oauthlib google-auth-httplib2 google-api-python-client pyaudio sounddevice scipy numpy pyyaml
        fi
        
        log_info "✅ Python依存関係更新完了"
    else
        log_warn "⚠️ Python仮想環境が見つかりません"
    fi
    
    # Git更新（もしGitリポジトリの場合）
    if [ -d "$(pwd)/.git" ]; then
        log_info "Git更新確認中..."
        git fetch
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "no-remote")
        
        if [ "$LOCAL" != "$REMOTE" ] && [ "$REMOTE" != "no-remote" ]; then
            echo "更新が利用可能です。更新しますか？ (y/N): "
            read -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git pull
                log_info "✅ Git更新完了"
            fi
        else
            log_info "ℹ️ 最新版です"
        fi
    fi
    
    # サービス再起動
    log_info "サービス再起動..."
    sudo systemctl start $SERVICE_NAME
    sleep 5
    
    if check_service_status; then
        log_info "✅ 更新完了 - サービス正常稼働中"
    else
        log_error "❌ 更新後のサービス起動に失敗"
        sudo journalctl -u $SERVICE_NAME -n 10 --no-pager
    fi
}

# メイン処理
case "$1" in
    "status")
        show_status
        ;;
    "start")
        log_info "サービス開始中..."
        sudo systemctl start $SERVICE_NAME
        sleep 3
        check_service_status
        ;;
    "stop")
        log_info "サービス停止中..."
        sudo systemctl stop $SERVICE_NAME
        log_info "✅ サービス停止完了"
        ;;
    "restart")
        log_info "サービス再起動中..."
        sudo systemctl restart $SERVICE_NAME
        sleep 5
        check_service_status
        ;;
    "logs")
        log_info "ログ表示中（Ctrl+C で終了）..."
        sudo journalctl -u $SERVICE_NAME -f
        ;;
    "test")
        run_test
        ;;
    "info")
        show_info
        ;;
    "gdrive")
        check_gdrive
        ;;
    "backup")
        backup_config
        ;;
    "update")
        update_system
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        echo "不明なコマンド: $1"
        echo ""
        show_help
        exit 1
        ;;
esac