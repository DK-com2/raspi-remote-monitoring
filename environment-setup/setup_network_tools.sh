#!/bin/bash
"""
ラズパイOS用：デバイス検出ツールのセットアップ
"""

echo "🔧 ラズパイOS用デバイス検出ツールセットアップ"
echo "=================================================="

# 必要なツールをインストール
echo "📦 必要なツールをインストール中..."

# パッケージ情報更新
sudo apt update

# カメラ検出ツール
echo "  - v4l-utils をインストール中..."
sudo apt install -y v4l-utils

# オーディオ検出ツール
echo "  - alsa-utils をインストール中..."
sudo apt install -y alsa-utils

# USBデバイス検出ツール
echo "  - usbutils をインストール中..."
sudo apt install -y usbutils

echo ""
echo "✅ インストール完了！"
echo ""
echo "📋 インストールされたツール:"
echo "  - v4l-utils: カメラデバイス検出（v4l2-ctl）"
echo "  - alsa-utils: オーディオデバイス検出（arecord）"
echo "  - usbutils: USBデバイス検出（lsusb）"
echo ""
echo "🚀 Flaskアプリを再起動してください:"
echo "   python app.py"
echo ""
echo "💡 使用方法:"
echo "   - 自動スキャン: 60秒ごとに自動実行"
echo "   - 手動スキャン: Web画面の「再スキャン」ボタン"
echo ""
echo "🔍 検出可能なデバイス:"
echo "   - 🎥 カメラ: /dev/video* デバイス"
echo "   - 🎤 マイク: ALSA録音デバイス"
echo "   - 🗺️ GPS: USBおよびシリアルGPSデバイス"
