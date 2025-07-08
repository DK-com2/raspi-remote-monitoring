#!/bin/bash
# WSL環境での簡単テストスクリプト

echo "🧪 WSL環境 テストモード"
echo "======================"

# プロジェクトディレクトリ設定
PROJECT_DIR="$(pwd)/monitoring-system"
VENV_PATH="$(pwd)/venv"

echo "📁 プロジェクト: $PROJECT_DIR"
echo "🐍 仮想環境: $VENV_PATH"

# 仮想環境有効化
if [ -f "$VENV_PATH/bin/activate" ]; then
    source "$VENV_PATH/bin/activate"
    echo "✅ Python仮想環境有効化"
else
    echo "❌ Python仮想環境が見つかりません"
    exit 1
fi

# 設定ファイル確認
if [ -f "$PROJECT_DIR/config.yaml" ]; then
    echo "✅ 設定ファイル確認"
else
    echo "❌ config.yamlが見つかりません"
    exit 1
fi

# データディレクトリ作成
mkdir -p "$(pwd)/data/recordings"
mkdir -p "$(pwd)/data/credentials"
echo "✅ データディレクトリ作成"

echo ""
echo "🚀 アプリケーション起動中..."
echo "   http://localhost:5000 でアクセス可能"
echo "   Ctrl+C で停止"
echo ""

# アプリケーション起動
cd "$PROJECT_DIR"
python app.py
