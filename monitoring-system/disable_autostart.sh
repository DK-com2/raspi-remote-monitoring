#!/bin/bash
# ネットワーク監視アプリ 自動起動無効化スクリプト
# systemd設定を元に戻す

set -e

echo "🗑️ ネットワーク監視アプリ 自動起動無効化"
echo "======================================="

# 設定変数
SERVICE_NAME="network-monitor"
PROJECT_DIR="$(pwd)"

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
log_info "現在の状態確認..."

# 現在の状態表示
if sudo systemctl is-enabled ${SERVICE_NAME} >/dev/null 2>&1; then
    ENABLED_STATUS=$(sudo systemctl is-enabled ${SERVICE_NAME})
    echo "  自動起動設定: $ENABLED_STATUS"
else
    echo "  自動起動設定: 未設定"
fi

if sudo systemctl is-active ${SERVICE_NAME} >/dev/null 2>&1; then
    ACTIVE_STATUS=$(sudo systemctl is-active ${SERVICE_NAME})
    echo "  動作状況: $ACTIVE_STATUS"
else
    echo "  動作状況: 停止中"
fi

echo ""
log_warn "以下の設定を削除します:"
echo "  ❌ systemdサービス停止"
echo "  ❌ 自動起動無効化"
echo "  ❌ サービスファイル削除"
echo "  ❌ app.pyを開発用設定に戻す"

echo ""
read -p "続行しますか？ (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "キャンセルしました"
    exit 0
fi

# 1. サービス停止
echo ""
log_info "サービス停止中..."
if sudo systemctl is-active ${SERVICE_NAME} >/dev/null 2>&1; then
    sudo systemctl stop ${SERVICE_NAME}
    log_info "✅ サービス停止完了"
else
    log_info "ℹ️ サービスは既に停止中"
fi

# 2. 自動起動無効化
log_info "自動起動無効化中..."
if sudo systemctl is-enabled ${SERVICE_NAME} >/dev/null 2>&1; then
    sudo systemctl disable ${SERVICE_NAME}
    log_info "✅ 自動起動無効化完了"
else
    log_info "ℹ️ 自動起動は既に無効"
fi

# 3. systemdサービスファイル削除
log_info "サービスファイル削除中..."
if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
    sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    sudo systemctl daemon-reload
    log_info "✅ サービスファイル削除完了"
else
    log_info "ℹ️ サービスファイルは存在しません"
fi

# 4. app.pyを開発用設定に戻す
log_info "app.pyを開発用設定に戻し中..."
if [ -f "$PROJECT_DIR/app.py.backup" ]; then
    cp "$PROJECT_DIR/app.py.backup" "$PROJECT_DIR/app.py"
    log_info "✅ app.py復元完了（debug=True に戻しました）"
else
    # バックアップがない場合は手動で変更
    if grep -q "debug=False" "$PROJECT_DIR/app.py" 2>/dev/null; then
        sed -i 's/debug=False/debug=True/g' "$PROJECT_DIR/app.py"
        log_info "✅ app.py設定変更完了（debug=True に変更）"
    else
        log_info "ℹ️ app.pyは既に開発用設定"
    fi
fi

# 5. テストファイル削除（あれば）
log_info "一時ファイル削除中..."
rm -f "$PROJECT_DIR/app_test.py" 2>/dev/null || true
rm -f "$PROJECT_DIR/app_production.py" 2>/dev/null || true
rm -f "$PROJECT_DIR/test_autostart.sh" 2>/dev/null || true
log_info "✅ 一時ファイル削除完了"

# 6. 現在の状態確認
echo ""
log_info "削除後の状態確認..."

# サービス状態確認
if sudo systemctl list-unit-files | grep -q ${SERVICE_NAME} 2>/dev/null; then
    log_warn "⚠️ サービスが残っています"
else
    log_info "✅ サービス完全削除確認"
fi

# ポート使用確認
if ss -tlnp | grep -q ":5000" 2>/dev/null; then
    log_warn "⚠️ ポート5000がまだ使用中です"
    echo "     手動で停止してください: pkill -f 'python.*app.py'"
else
    log_info "✅ ポート5000解放確認"
fi

# 7. 元の手動起動方法を表示
echo ""
echo "🎉 自動起動無効化完了！"
echo "======================"
log_info "元の手動起動方法に戻りました"

echo ""
echo "📋 手動起動方法:"
echo "   cd $(basename $PROJECT_DIR)"
echo "   source ../venv/bin/activate"
echo "   python app.py"

echo ""
echo "🔗 関連コマンド:"
echo "   ps aux | grep app.py              # 動作中プロセス確認"
echo "   pkill -f 'python.*app.py'         # 手動停止"
echo "   ss -tlnp | grep :5000             # ポート使用確認"

# 8. 再設定方法
echo ""
echo "🔄 再度自動起動にしたい場合:"
echo "   ./autostart_setup_unified.sh を再実行"

echo ""
log_info "🏁 無効化処理完了"