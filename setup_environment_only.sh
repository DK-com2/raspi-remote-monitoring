#!/bin/bash
# Raspberry Pi 監視システム - 環境構築専用スクリプト
# WSL2 & Raspberry Pi 両環境対応 - Python環境・依存関係・基本設定のみ

set -e

echo "🛠️ Raspberry Pi 監視システム - 環境構築専用"
echo "=============================================="
echo ""
echo "このスクリプトは以下を実行します:"
echo "  ✅ Python仮想環境作成"
echo "  ✅ 依存関係インストール"
echo "  ✅ ディレクトリ構造作成"
echo "  ✅ 基本設定ファイル準備"
echo "  ✅ 権限設定"
echo ""
echo "⚠️ 注意: アプリケーションの起動・自動起動設定は行いません"
echo ""
read -p "環境構築を開始しますか？ (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "環境構築をキャンセルしました"
    exit 0
fi
echo ""

# 設定変数（自動検出）
CURRENT_DIR="$(pwd)"
PROJECT_DIR="$CURRENT_DIR/monitoring-system"
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
log_info "🖥️ 環境検出結果: $ENVIRONMENT"
log_debug "プロジェクトディレクトリ: $PROJECT_DIR"
log_debug "ユーザー: $USER"
log_debug "Python仮想環境: $PYTHON_VENV"
echo ""

# ==================== 基本システム要件確認 ====================
log_info "📋 基本システム要件確認..."

# OS確認
log_debug "OS情報: $(uname -a)"

# Python3確認
if ! command -v python3 &> /dev/null; then
    log_error "Python3がインストールされていません"
    log_info "インストール方法:"
    case $ENVIRONMENT in
        "raspberry_pi")
            echo "  sudo apt update && sudo apt install -y python3 python3-pip python3-venv"
            ;;
        "wsl2"|"linux")
            echo "  sudo apt update && sudo apt install -y python3 python3-pip python3-venv"
            echo "  または: sudo yum install -y python3 python3-pip"
            ;;
    esac
    exit 1
else
    PYTHON_VERSION=$(python3 --version 2>&1)
    log_info "✅ $PYTHON_VERSION"
fi

# pip確認
if ! command -v pip3 &> /dev/null; then
    log_warn "⚠️ pip3がインストールされていません"
    log_info "pip3をインストールします..."
    case $ENVIRONMENT in
        "raspberry_pi"|"wsl2"|"linux")
            sudo apt update
            sudo apt install -y python3-pip
            ;;
    esac
else
    log_info "✅ pip3確認済み"
fi

# venv確認
if ! python3 -m venv --help &> /dev/null; then
    log_warn "⚠️ python3-venvがインストールされていません"
    log_info "python3-venvをインストールします..."
    case $ENVIRONMENT in
        "raspberry_pi"|"wsl2"|"linux")
            sudo apt update
            sudo apt install -y python3-venv
            ;;
    esac
else
    log_info "✅ python3-venv確認済み"
fi

# Git確認
if ! command -v git &> /dev/null; then
    log_warn "⚠️ Gitがインストールされていません"
    log_info "Gitをインストールします..."
    case $ENVIRONMENT in
        "raspberry_pi"|"wsl2"|"linux")
            sudo apt update
            sudo apt install -y git
            ;;
    esac
else
    log_info "✅ Git確認済み"
fi

# curl確認
if ! command -v curl &> /dev/null; then
    log_warn "⚠️ curlがインストールされていません"
    log_info "curlをインストールします..."
    case $ENVIRONMENT in
        "raspberry_pi"|"wsl2"|"linux")
            sudo apt update
            sudo apt install -y curl
            ;;
    esac
else
    log_info "✅ curl確認済み"
fi

echo ""

# ==================== プロジェクト構造確認 ====================
log_info "📁 プロジェクト構造確認..."

if [ ! -d "$PROJECT_DIR" ]; then
    log_error "プロジェクトディレクトリが見つかりません: $PROJECT_DIR"
    log_error "monitoring-systemディレクトリが必要です"
    exit 1
fi

log_info "✅ プロジェクトディレクトリ確認: $PROJECT_DIR"

# 必要なディレクトリ構造を確認・作成
REQUIRED_DIRS=(
    "modules"
    "modules/network"
    "modules/recording"
    "modules/gdrive"
    "config"
    "templates"
    "utils"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$PROJECT_DIR/$dir" ]; then
        mkdir -p "$PROJECT_DIR/$dir"
        log_info "✅ ディレクトリ作成: $dir"
    else
        log_info "✅ ディレクトリ確認: $dir"
    fi
done

# __init__.pyファイル作成
INIT_FILES=(
    "modules/__init__.py"
    "modules/network/__init__.py"
    "modules/recording/__init__.py"
    "modules/gdrive/__init__.py"
    "config/__init__.py"
    "utils/__init__.py"
)

for init_file in "${INIT_FILES[@]}"; do
    if [ ! -f "$PROJECT_DIR/$init_file" ]; then
        touch "$PROJECT_DIR/$init_file"
        log_info "✅ __init__.py作成: $init_file"
    fi
done

echo ""

# ==================== Python仮想環境構築 ====================
log_info "🐍 Python仮想環境構築..."

if [ -d "$PYTHON_VENV" ]; then
    log_warn "⚠️ 既存のPython仮想環境を検出"
    echo "既存の仮想環境の処理を選択してください:"
    echo "  1) 既存環境を使用（推奨）"
    echo "  2) 既存環境を削除して再作成"
    echo "  3) スキップ"
    read -p "選択 (1-3): " -n 1 -r
    echo
    case $REPLY in
        "2")
            log_warn "既存環境を削除して再作成します..."
            rm -rf "$PYTHON_VENV"
            ;;
        "3")
            log_info "Python仮想環境構築をスキップしました"
            ;;
        *)
            log_info "既存のPython仮想環境を使用します"
            ;;
    esac
fi

if [ ! -d "$PYTHON_VENV" ]; then
    log_info "Python仮想環境を作成中..."
    python3 -m venv "$PYTHON_VENV"
    log_info "✅ Python仮想環境作成完了: $PYTHON_VENV"
fi

# 仮想環境のアクティベート
log_info "Python仮想環境をアクティベート中..."
source "$PYTHON_VENV/bin/activate"

# pipアップグレード
log_info "pipをアップグレード中..."
pip install --upgrade pip

echo ""

# ==================== 依存関係インストール ====================
log_info "📦 Python依存関係インストール..."

# requirements.txtがある場合はそれを使用
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
    log_info "requirements.txtから依存関係をインストール中..."
    pip install -r "$PROJECT_DIR/requirements.txt"
    log_info "✅ requirements.txtからのインストール完了"
else
    log_info "基本的な依存関係をインストール中..."
    
    # 基本的なWebフレームワーク
    pip install flask>=2.0.0
    
    # システム監視用
    pip install psutil>=5.8.0
    
    # HTTP通信用
    pip install requests>=2.28.0
    
    # Google Drive API用
    pip install google-auth>=2.0.0
    pip install google-auth-oauthlib>=1.0.0
    pip install google-auth-httplib2>=0.1.0
    pip install google-api-python-client>=2.0.0
    
    # 音声録音用
    pip install pyaudio || log_warn "PyAudioのインストールに失敗（音声機能で必要な場合は手動インストール）"
    pip install sounddevice>=0.4.0 || log_warn "SoundDeviceのインストールに失敗（音声機能で必要な場合は手動インストール）"
    
    # 音声処理用
    pip install scipy>=1.7.0
    pip install numpy>=1.21.0
    
    # 設定ファイル用
    pip install pyyaml>=6.0
    
    # requirements.txt生成
    pip freeze > "$PROJECT_DIR/requirements.txt"
    log_info "✅ requirements.txt生成完了"
fi

# 仮想環境の非アクティベート
deactivate

echo ""

# ==================== データディレクトリ構築 ====================
log_info "📂 データディレクトリ構築..."

DATA_DIR="$CURRENT_DIR/data"
mkdir -p "$DATA_DIR"
mkdir -p "$DATA_DIR/recordings"
mkdir -p "$DATA_DIR/credentials"
mkdir -p "$DATA_DIR/logs"
mkdir -p "$DATA_DIR/exports"

log_info "✅ データディレクトリ作成完了: $DATA_DIR"

# 権限設定
chown -R $USER:$USER "$DATA_DIR" 2>/dev/null || true
chmod -R 755 "$DATA_DIR"

log_info "✅ データディレクトリ権限設定完了"

echo ""

# ==================== 設定ファイル作成 ====================
log_info "⚙️ 基本設定ファイル作成..."

# config.yaml作成
if [ ! -f "$PROJECT_DIR/config.yaml" ]; then
    cat > "$PROJECT_DIR/config.yaml" << 'EOF'
# Raspberry Pi 監視システム設定ファイル
app:
  name: "Raspberry Pi Monitor"
  version: "1.0.0"
  debug: false
  host: "0.0.0.0"
  port: 5000

# ネットワーク監視設定
network:
  scan_interval: 30  # スキャン間隔（秒）
  timeout: 5  # タイムアウト（秒）
  devices:
    # 監視対象デバイス（例）
    - name: "ルーター"
      ip: "192.168.1.1"
      monitor: true
    - name: "DNS"
      ip: "8.8.8.8"
      monitor: true

# 録音設定
recording:
  sample_rate: 44100
  channels: 1
  duration: 10  # デフォルト録音時間（秒）
  format: "wav"
  auto_upload: true  # Google Driveへの自動アップロード

# Google Drive設定
gdrive:
  credentials_file: "data/credentials/credentials.json"
  token_file: "data/credentials/token.json"
  folder_name: "RaspberryPi_Monitor"
  auto_create_folder: true

# ログ設定
logging:
  level: "INFO"
  file: "data/logs/app.log"
  max_size: "10MB"
  backup_count: 5
EOF
    log_info "✅ config.yaml作成完了"
else
    log_info "✅ config.yaml既存確認"
fi

# 環境別設定情報ファイル作成
ENV_INFO_FILE="$CURRENT_DIR/environment_info.txt"
cat > "$ENV_INFO_FILE" << EOF
Raspberry Pi 監視システム - 環境構築情報
========================================

構築日時: $(date)
環境: $ENVIRONMENT
ユーザー: $USER
ホスト名: $(hostname)

ディレクトリ構成:
- プロジェクト: $PROJECT_DIR
- Python仮想環境: $PYTHON_VENV
- データ: $DATA_DIR

Python情報:
- バージョン: $(python3 --version 2>&1)
- pip: $(pip3 --version 2>&1)

次のステップ:
1. アプリケーションコードを監視システムディレクトリに配置
2. Google Drive認証ファイル(credentials.json)を data/credentials/ に配置
3. setup_autostart.sh でアプリケーション起動設定

使用可能なコマンド:
- 仮想環境アクティベート: source $PYTHON_VENV/bin/activate
- 仮想環境非アクティベート: deactivate
- 依存関係確認: pip list
- 設定ファイル編集: nano $PROJECT_DIR/config.yaml
EOF

log_info "✅ 環境情報ファイル作成: $ENV_INFO_FILE"

echo ""

# ==================== システム要件確認（録音機能用）====================
log_info "🎤 音声システム要件確認..."

# ALSA確認
if command -v aplay &> /dev/null; then
    log_info "✅ ALSA確認済み"
    
    # 音声デバイス一覧表示
    log_debug "利用可能な音声デバイス:"
    aplay -l 2>/dev/null | head -10 || log_warn "音声デバイス情報取得に失敗"
else
    log_warn "⚠️ ALSAが見つかりません"
    echo "Raspberry Piで録音機能を使用する場合は以下をインストール:"
    echo "  sudo apt install -y alsa-utils"
fi

# PulseAudio確認
if command -v pulseaudio &> /dev/null; then
    log_info "✅ PulseAudio確認済み"
else
    log_info "ℹ️ PulseAudio未インストール（録音機能でオプション）"
fi

# audioグループ確認
if groups $USER | grep -q audio; then
    log_info "✅ audioグループメンバーシップ確認済み"
else
    log_warn "⚠️ audioグループに属していません"
    echo "録音機能を使用する場合は以下を実行後、再ログイン:"
    echo "  sudo usermod -a -G audio $USER"
fi

echo ""

# ==================== ネットワークツール確認 ====================
log_info "🌐 ネットワークツール確認..."

# ping確認
if command -v ping &> /dev/null; then
    log_info "✅ ping確認済み"
else
    log_warn "⚠️ pingが見つかりません"
fi

# nmap確認（オプション）
if command -v nmap &> /dev/null; then
    log_info "✅ nmap確認済み"
else
    log_info "ℹ️ nmap未インストール（高度なネットワーク監視でオプション）"
    echo "インストール方法: sudo apt install -y nmap"
fi

# ss/netstat確認
if command -v ss &> /dev/null; then
    log_info "✅ ss確認済み"
elif command -v netstat &> /dev/null; then
    log_info "✅ netstat確認済み"
else
    log_warn "⚠️ ネットワーク状態確認ツールが見つかりません"
    echo "インストール方法: sudo apt install -y iproute2 net-tools"
fi

echo ""

# ==================== 権限設定 ====================
log_info "🔐 権限設定..."

# プロジェクトディレクトリ権限
chown -R $USER:$USER "$PROJECT_DIR" 2>/dev/null || true
chmod -R 755 "$PROJECT_DIR"

# Python仮想環境権限
chown -R $USER:$USER "$PYTHON_VENV" 2>/dev/null || true
chmod -R 755 "$PYTHON_VENV"

log_info "✅ 権限設定完了"

echo ""

# ==================== 環境テスト ====================
log_info "🧪 環境テスト実行..."

# Python仮想環境テスト
if [ -f "$PYTHON_VENV/bin/python" ]; then
    log_info "✅ Python仮想環境実行可能"
    
    # 仮想環境内でのパッケージ確認
    source "$PYTHON_VENV/bin/activate"
    
    # Flask確認
    if python -c "import flask; print(f'Flask {flask.__version__}')" 2>/dev/null; then
        log_info "✅ Flask正常インストール"
    else
        log_error "❌ Flaskインポートエラー"
    fi
    
    # psutil確認
    if python -c "import psutil; print(f'psutil {psutil.__version__}')" 2>/dev/null; then
        log_info "✅ psutil正常インストール"
    else
        log_error "❌ psutilインポートエラー"
    fi
    
    # Google API確認
    if python -c "import google.auth; print('Google Auth OK')" 2>/dev/null; then
        log_info "✅ Google API正常インストール"
    else
        log_warn "⚠️ Google APIインポートエラー（Google Drive機能で必要）"
    fi
    
    deactivate
else
    log_error "❌ Python仮想環境実行不可"
fi

# ディレクトリ構造確認
log_info "📁 ディレクトリ構造最終確認:"
if [ -d "$PROJECT_DIR" ]; then
    echo "  ✅ $PROJECT_DIR/"
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ -d "$PROJECT_DIR/$dir" ]; then
            echo "    ✅ $dir/"
        else
            echo "    ❌ $dir/"
        fi
    done
fi

if [ -d "$DATA_DIR" ]; then
    echo "  ✅ $DATA_DIR/"
    echo "    ✅ recordings/"
    echo "    ✅ credentials/"
    echo "    ✅ logs/"
    echo "    ✅ exports/"
fi

echo ""

# ==================== 完了報告 ====================
echo "🎉 環境構築完了！"
echo "==============================================="
echo ""
log_info "✅ 構築された環境:"
echo "  🐍 Python仮想環境: $PYTHON_VENV"
echo "  📦 依存関係: インストール済み"
echo "  📁 プロジェクト構造: 準備完了"
echo "  📂 データディレクトリ: 作成済み"
echo "  ⚙️ 基本設定: config.yaml"
echo "  🔐 権限: 設定済み"
echo ""

log_info "📋 次のステップ:"
echo ""
echo "1️⃣ アプリケーションコード配置"
echo "   monitoring-system/ ディレクトリにアプリケーションファイルを配置"
echo "   - app.py (メインアプリケーション)"
echo "   - modules/ 以下のPythonモジュール"
echo "   - templates/ 以下のHTMLテンプレート"
echo ""
echo "2️⃣ Google Drive認証設定（オプション）"
echo "   - Google Cloud Consoleでプロジェクト作成"
echo "   - Drive APIを有効化"
echo "   - サービスアカウントキーをダウンロード"
echo "   - credentials.jsonを data/credentials/ に配置"
echo ""
echo "3️⃣ アプリケーション起動・自動起動設定"
echo "   ./setup_autostart.sh を実行"
echo ""

log_info "🔧 管理コマンド:"
echo "  # Python仮想環境使用"
echo "  source $PYTHON_VENV/bin/activate"
echo ""
echo "  # 設定ファイル編集"
echo "  nano $PROJECT_DIR/config.yaml"
echo ""
echo "  # 依存関係確認"
echo "  pip list"
echo ""
echo "  # 環境情報確認"
echo "  cat $ENV_INFO_FILE"
echo ""

log_info "📄 作成されたファイル:"
echo "  📋 $PROJECT_DIR/config.yaml - アプリケーション設定"
echo "  📋 $PROJECT_DIR/requirements.txt - Python依存関係"
echo "  📋 $ENV_INFO_FILE - 環境構築情報"
echo ""

log_warn "⚠️ 重要な注意事項:"
echo "  • このスクリプトは環境構築のみ行います"
echo "  • アプリケーションの起動には別途 setup_autostart.sh が必要です"
echo "  • 録音機能を使用する場合は音声デバイスの設定が必要です"
echo "  • Google Drive機能を使用する場合は認証設定が必要です"
echo ""

log_info "✅ 環境構築スクリプト完了"
echo ""
