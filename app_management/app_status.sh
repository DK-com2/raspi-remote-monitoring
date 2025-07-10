#!/bin/bash
# Raspberry Pi 監視システム - 状態確認スクリプト

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }
log_header() { echo -e "${CYAN}$1${NC}"; }

echo "📊 Raspberry Pi 監視システム - 状態確認"
echo "========================================"
echo ""

# ディレクトリ設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MONITORING_DIR="$PROJECT_ROOT/monitoring-system"
VENV_DIR="$PROJECT_ROOT/venv"

# ==================== システム基本情報 ====================
log_header "🖥️ システム基本情報"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ホスト名: $(hostname)"
echo "現在時刻: $(date)"
echo "稼働時間: $(uptime -p)"
echo "ユーザー: $(whoami)"
echo "プロジェクト: $PROJECT_ROOT"
echo ""

# ==================== アプリケーション状態 ====================
log_header "🚀 アプリケーション状態"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# app.pyプロセス確認
if ps aux | grep "python.*app.py" | grep -v grep >/dev/null 2>&1; then
    echo "  ✅ app.pyプロセス: 実行中"
    echo "     詳細:"
    ps aux | grep "python.*app.py" | grep -v grep | while read line; do
        PID=$(echo $line | awk '{print $2}')
        ELAPSED=$(echo $line | awk '{print $10}')
        echo "       PID: $PID, 実行時間: $ELAPSED"
    done
else
    echo "  ❌ app.pyプロセス: 停止中"
fi

# ポート5000確認
echo ""
if sudo lsof -i :5000 >/dev/null 2>&1; then
    echo "  ✅ ポート5000: 使用中"
    echo "     使用プロセス:"
    sudo lsof -i :5000 | grep -v COMMAND | while read line; do
        echo "       $line"
    done
else
    echo "  ❌ ポート5000: 未使用"
fi

# HTTP応答確認
echo ""
if curl -f -s --max-time 5 http://localhost:5000 > /dev/null 2>&1; then
    echo "  ✅ HTTP応答: 正常"
    
    # API エンドポイントテスト
    echo "     APIテスト:"
    
    API_ENDPOINTS=(
        "/api/network-status:ネットワーク状態"
        "/api/recording/devices:録音デバイス"
        "/api/gdrive-status:Google Drive状態"
        "/api/tailscale-status:Tailscale状態"
    )
    
    for endpoint_info in "${API_ENDPOINTS[@]}"; do
        endpoint=$(echo $endpoint_info | cut -d: -f1)
        name=$(echo $endpoint_info | cut -d: -f2)
        
        if curl -f -s --max-time 3 "http://localhost:5000$endpoint" > /dev/null 2>&1; then
            echo "       ✅ $name"
        else
            echo "       ❌ $name"
        fi
    done
else
    echo "  ❌ HTTP応答: 異常"
fi

echo ""

# ==================== Python仮想環境状態 ====================
log_header "🐍 Python仮想環境状態"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -d "$VENV_DIR" ]; then
    echo "  ✅ 仮想環境ディレクトリ: 存在"
    
    if [ -f "$VENV_DIR/bin/python" ]; then
        echo "  ✅ Python実行ファイル: 存在"
        PYTHON_VERSION=$("$VENV_DIR/bin/python" --version 2>&1)
        echo "     バージョン: $PYTHON_VERSION"
    else
        echo "  ❌ Python実行ファイル: 不在"
    fi
    
    # アクティブ状態確認
    if [ -n "$VIRTUAL_ENV" ]; then
        echo "  ✅ アクティブ状態: 有効 ($VIRTUAL_ENV)"
    else
        echo "  ⚠️ アクティブ状態: 無効"
    fi
    
    # 主要パッケージ確認
    echo "     主要パッケージ:"
    PACKAGES=("flask" "psutil" "requests" "pyyaml")
    for package in "${PACKAGES[@]}"; do
        if "$VENV_DIR/bin/python" -c "import $package" 2>/dev/null; then
            VERSION=$("$VENV_DIR/bin/python" -c "import $package; print($package.__version__)" 2>/dev/null || echo "不明")
            echo "       ✅ $package ($VERSION)"
        else
            echo "       ❌ $package"
        fi
    done
else
    echo "  ❌ 仮想環境ディレクトリ: 不在"
fi

echo ""

# ==================== systemdサービス状態 ====================
log_header "⚙️ systemdサービス状態"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SERVICES=("raspi-monitoring" "network-monitor" "monitoring" "flask-app")

for SERVICE in "${SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "^$SERVICE.service"; then
        echo "  📄 $SERVICE.service:"
        
        if systemctl is-active --quiet "$SERVICE.service"; then
            echo "     🟢 状態: 稼働中"
        else
            echo "     🔴 状態: 停止中"
        fi
        
        if systemctl is-enabled "$SERVICE.service" >/dev/null 2>&1; then
            echo "     ✅ 自動起動: 有効"
        else
            echo "     ❌ 自動起動: 無効"
        fi
    else
        echo "  ❌ $SERVICE.service: 未設定"
    fi
done

echo ""

# ==================== ネットワーク情報 ====================
log_header "🌐 ネットワーク情報"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ローカルIP
echo "  🏠 ローカルIP:"
if command -v ip &> /dev/null; then
    LOCAL_IPS=$(ip addr show | grep -E 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1)
    if [ -n "$LOCAL_IPS" ]; then
        echo "$LOCAL_IPS" | while read ip; do
            [ -n "$ip" ] && echo "     http://$ip:5000"
        done
    else
        echo "     取得できませんでした"
    fi
else
    echo "     IPコマンドが利用できません"
fi

# Tailscale状態
echo ""
echo "  🔒 Tailscale:"
if command -v tailscale &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未接続")
    if [ "$TAILSCALE_IP" != "未接続" ] && [ -n "$TAILSCALE_IP" ]; then
        echo "     ✅ 接続済み: $TAILSCALE_IP"
        echo "     📱 アクセス: http://$TAILSCALE_IP:5000"
        
        # 接続テスト
        if curl -f -s --max-time 3 "http://$TAILSCALE_IP:5000" > /dev/null 2>&1; then
            echo "     ✅ Tailscale経由HTTP: 正常"
        else
            echo "     ⚠️ Tailscale経由HTTP: 応答なし"
        fi
    else
        echo "     ❌ 未接続"
        echo "     接続方法: sudo tailscale up"
    fi
else
    echo "     ❌ 未インストール"
    echo "     インストール: curl -fsSL https://tailscale.com/install.sh | sh"
fi

echo ""

# ==================== ファイル・ディレクトリ状態 ====================
log_header "📁 ファイル・ディレクトリ状態"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 主要ファイル確認
FILES=(
    "$MONITORING_DIR/app.py:メインアプリケーション"
    "$MONITORING_DIR/config.yaml:設定ファイル"
    "$PROJECT_ROOT/data/credentials/credentials.json:Google Drive認証"
)

for file_info in "${FILES[@]}"; do
    file_path=$(echo $file_info | cut -d: -f1)
    file_name=$(echo $file_info | cut -d: -f2)
    
    if [ -f "$file_path" ]; then
        file_size=$(ls -lh "$file_path" | awk '{print $5}')
        file_date=$(ls -l "$file_path" | awk '{print $6, $7, $8}')
        echo "  ✅ $file_name ($file_size, $file_date)"
    else
        echo "  ❌ $file_name: 不在"
    fi
done

# データディレクトリ
echo ""
echo "  📂 データディレクトリ:"
DATA_DIRS=(
    "$PROJECT_ROOT/data/recordings:録音ファイル"
    "$PROJECT_ROOT/data/credentials:認証ファイル"
    "$PROJECT_ROOT/data/logs:ログファイル"
)

for dir_info in "${DATA_DIRS[@]}"; do
    dir_path=$(echo $dir_info | cut -d: -f1)
    dir_name=$(echo $dir_info | cut -d: -f2)
    
    if [ -d "$dir_path" ]; then
        file_count=$(find "$dir_path" -type f 2>/dev/null | wc -l)
        echo "     ✅ $dir_name ($file_count ファイル)"
    else
        echo "     ❌ $dir_name: 不在"
    fi
done

echo ""

# ==================== 推奨アクション ====================
log_header "💡 推奨アクション"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# アプリが停止中の場合
if ! ps aux | grep "python.*app.py" | grep -v grep >/dev/null 2>&1; then
    echo "  🚀 アプリケーションを起動: ./app_start.sh"
fi

# HTTP応答がない場合
if ! curl -f -s --max-time 5 http://localhost:5000 > /dev/null 2>&1; then
    echo "  🔧 アプリケーション再起動: ./app_stop.sh && ./app_start.sh"
fi

# Tailscale未接続の場合
if command -v tailscale &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未接続")
    if [ "$TAILSCALE_IP" = "未接続" ] || [ -z "$TAILSCALE_IP" ]; then
        echo "  🔒 Tailscale接続: sudo tailscale up"
    fi
else
    echo "  📦 Tailscaleインストール: curl -fsSL https://tailscale.com/install.sh | sh"
fi

# Google Drive認証ファイル不在の場合
if [ ! -f "$PROJECT_ROOT/data/credentials/credentials.json" ]; then
    echo "  ☁️ Google Drive設定: credentials.jsonを data/credentials/ に配置"
fi

# systemdサービス未設定の場合
SERVICE_EXISTS=false
for SERVICE in "${SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "^$SERVICE.service"; then
        SERVICE_EXISTS=true
        break
    fi
done

if ! $SERVICE_EXISTS; then
    echo "  ⚙️ 自動起動設定: ./app_autostart.sh"
fi

echo ""

# ==================== 管理コマンド ====================
log_header "🔧 管理コマンド"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ./app_start.sh               # アプリ手動起動"
echo "  ./app_stop.sh                # アプリ停止"
echo "  ./app_autostart.sh           # 自動起動設定"
echo "  ./app_remove_autostart.sh    # 自動起動解除"
echo ""
echo "  tailscale ip -4              # Tailscale IP確認"
echo "  sudo systemctl status raspi-monitoring  # サービス状態"
echo "  sudo journalctl -u raspi-monitoring -f  # ログ監視"
echo ""

echo "📊 状態確認完了！"
