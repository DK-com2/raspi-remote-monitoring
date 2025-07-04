# 🚀 Raspberry Pi ネットワーク監視システム - セットアップガイド

## 📋 何をインストールするか

このプロジェクトは以下の機能を提供します：

✅ **ネットワーク監視**: WiFi/有線/モバイル接続状態の監視  
✅ **接続機器スキャン**: ローカルネットワーク内のデバイス一覧  
✅ **Google Drive連携**: 監視データをクラウドに自動保存  
✅ **Tailscale VPN**: 遠隔アクセス（オプション）  
✅ **スマホ対応UI**: レスポンシブWebインターフェース  

## 🎯 推奨：ワンコマンドセットアップ

```bash
# プロジェクトフォルダで実行
cd environment-setup
chmod +x setup_complete.sh
./setup_complete.sh
```

**これだけで全ての環境が完成します！**（所要時間：約5-10分）

## 📱 セットアップ後の使用方法

### 1. アプリケーション起動
```bash
cd monitoring-system
source ../venv/bin/activate
python app.py
```

### 2. ブラウザでアクセス
- **ローカル**: `http://localhost:5000`
- **Tailscale**: `http://[tailscale-ip]:5000`

### 3. Google Drive連携設定
1. [Google Cloud Console](https://console.cloud.google.com/) でプロジェクト作成
2. Google Drive API を有効化
3. OAuth 2.0 認証情報を作成（デスクトップアプリ）
4. `credentials.json` を `data/credentials/` に配置
5. 初回アクセス時にブラウザで認証

## 🔧 個別セットアップ（必要な場合のみ）

### Google Drive認証のみ設定
```bash
python environment-setup/setup_gdrive.py
```

### ネットワークツールのみ追加
```bash
sudo ./environment-setup/setup_network_tools.sh
```

## 🛠️ トラブルシューティング

### 権限エラー
```bash
chmod +x environment-setup/*.sh
```

### 依存関係エラー
```bash
source venv/bin/activate
pip install --upgrade pip
pip install -r monitoring-system/requirements.txt
```

### 環境リセット
```bash
# 完全リセット（推奨）
./environment-setup/reset_and_setup.sh

# または段階的リセット
./environment-setup/cleanup_environment.sh
./environment-setup/setup_complete.sh
```

### Tailscale認証
```bash
sudo tailscale up
# ブラウザで認証URLにアクセス
```

## 📊 動作環境

- **推奨**: Raspberry Pi OS（Bullseye/Bookworm）
- **対応**: Ubuntu Server/Desktop、Debian
- **開発**: Windows（WSL2）、macOS

## 🎉 セットアップ完了後

以下の機能が利用可能になります：

1. **ネットワーク監視画面** (`/`)
   - 接続状態とレイテンシ監視
   - 接続機器一覧表示
   - 速度測定機能

2. **Google Drive連携** (`/gdrive`)
   - 接続状態確認
   - テストデータ送信

3. **データ送信機能** (`/gdrive/test-upload`)
   - テストデータまたはネットワークデータを選択
   - JSON形式でGoogle Driveに保存

## 📞 サポート

問題が発生した場合は、各スクリプトのログメッセージを確認してください。エラーメッセージが表示された場合は、該当する依存関係を個別にインストールしてください。
