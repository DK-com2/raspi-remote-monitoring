# 📱 Raspberry Pi ネットワーク監視システム

**スマホでの遠隔監視システム - 現場でのモニター・キーボード接続作業を完全廃止**

## 🎯 プロジェクト概要

### 目標
- **スマホのみで全現場のラズパイを遠隔監視・管理**
- **現場でのモニター・キーボード接続作業を完全廃止**
- **軽量で安定したシステム構築**

### システム構成
```
📱 スマホ (Tailscale) ◄──► 🍓 Raspberry Pi (監視システム) ◄──► ☁️ Google Drive
```

## 🚀 クイックスタート

### 1️⃣ 環境構築（5分で完了）

```bash
# プロジェクトをクローン
git clone [your-repo-url] raspi-remote-monitoring
cd raspi-remote-monitoring

# ワンコマンドセットアップ
cd environment-setup
chmod +x setup_complete.sh
./setup_complete.sh
```

### 2️⃣ アプリケーション起動

```bash
# 自動起動設定（本番環境）
cd app_management
sudo ./app_autostart.sh

# または手動起動（開発・テスト）
./app_start.sh
```

### 3️⃣ アクセス開始

- **ローカル**: `http://localhost:5000`
- **Tailscale**: `http://[tailscale-ip]:5000`
- **スマホ**: 同じURLをブラウザで開く

## 📱 主な機能

### リアルタイム監視
- **📶 WiFi信号強度**とSSID表示（dBm → %変換）
- **📱 モバイル回線**対応（4G/5G信号強度）
- **🔗 有線LAN**接続監視
- **🌍 インターネット接続状態**（Ping レイテンシ）
- **🔒 Tailscale VPN状態**とIP表示

### スマートテスト
- **🏓 Pingテスト**（任意ホスト指定可能）
- **⚡ インターネット速度測定**
- **🔄 手動更新機能**

### 追加機能
- **🎤 録音機能**: リモート音声録音・ダウンロード
- **☁️ Google Drive連携**: データ自動保存
- **📊 データ送信**: IoT風テストデータ

### スマホ最適化
- **📱 レスポンシブデザイン**
- **👆 タッチ操作対応**
- **🔄 5秒ごと自動更新**
- **🎨 美しいグラデーションUI**

## 🎯 使用シナリオ

### 現場設置手順
1. **🔌 Raspberry Pi 電源オン**
2. **📶 ネットワーク接続** (WiFi/有線)
3. **⏱️ 2-3分待機** → 自動起動完了
4. **🔒 Tailscale認証** (初回のみ)
5. **📱 スマホでアクセス開始**

### 日常監視
- **📱 スマホ**: Tailscaleアプリ起動 → ブラウザアクセス
- **✅ 確認項目**: 信号強度、接続状態、速度
- **🧪 テスト実行**: Pingテスト、速度測定

## 🔧 管理コマンド

### 状態確認
```bash
cd app_management
./app_status.sh
```

### サービス管理
```bash
sudo systemctl start|stop|restart raspi-monitoring
sudo systemctl status raspi-monitoring
```

### 自動起動切り替え
```bash
# 自動起動有効化
./app_autostart.sh

# 自動起動無効化
./app_remove_autostart.sh
```

## 📖 詳細ドキュメント

### 🛠️ セットアップが必要？
**→ [セットアップガイド](SETUP.md)** を参照
- 環境構築手順
- Google Drive連携設定
- Tailscale VPN設定
- 録音機能設定
- 本番デプロイ手順

### 📱 日常運用を開始？
**→ [監視システム運用マニュアル](monitoring-system/README.md)** を参照
- 日常的な使用方法
- 管理コマンド一覧
- トラブルシューティング
- パフォーマンス監視

### 🔧 カスタマイズ・開発？
**→ [技術仕様・開発者ガイド](TECHNICAL_DOCS.md)** を参照
- システム設計・API仕様
- モジュール構成
- カスタマイズ方法
- 拡張機能開発
- テスト・デプロイ

## 🏗️ プロジェクト構成

```
raspi-remote-monitoring/
├── 📖 README.md                    # このファイル（START HERE!）
├── 🛠️ SETUP.md                    # セットアップガイド
├── 🔧 TECHNICAL_DOCS.md            # 技術仕様・開発者向け
├── 🏗️ environment-setup/          # 環境構築ツール
├── 📱 app_management/              # アプリ管理ツール
├── 🎯 monitoring-system/           # メインアプリケーション
└── 🐍 venv/                       # Python仮想環境
```

## 🔒 セキュリティ

- **🔒 Tailscale VPN**: 暗号化通信
- **🔥 ファイアウォール**: ポート5000は開放しない
- **🔑 デバイス認証**: 認証済みデバイスのみアクセス可能

## 💡 特徴

- **⚡ 軽量設計**: 24時間連続稼働対応
- **📱 スマホ最適化**: レスポンシブデザイン
- **🔒 セキュア接続**: Tailscale VPN使用
- **🔧 拡張可能**: モジュラー設計
- **🖥️ 両環境対応**: WSL2開発・Raspberry Pi本番

## 🆘 トラブルシューティング

### よくある問題

#### アプリが起動しない
```bash
cd app_management
./app_status.sh
./app_start.sh
```

#### Tailscaleに接続できない
```bash
sudo tailscale status
sudo tailscale up
```

#### ポート競合エラー
```bash
sudo ss -tlnp | grep :5000
sudo pkill -f "python.*app.py"
./app_start.sh
```

#### 完全リセット
```bash
cd environment-setup
./reset_and_setup.sh
```

## 🎉 成果

**Phase 1の基盤「スマホでの遠隔監視システム」が完成しました。**

- ✅ 現場でのモニター・キーボード接続作業の代替手段確立
- ✅ スマホでの基本的な遠隔監視
- ✅ 軽量で安定したシステム基盤
- ✅ 電源オン時の自動起動システム（省電力運用対応）
- ✅ セキュアなアクセス基盤

**現状:** ネットワーク監視の基盤は完成。IoT機器固有の監視・テスト機能の追加により、完全なシステムへと発展可能な状態です。

---

🚀 **まずは [セットアップガイド](SETUP.md) でシステムを構築してください。**  
📱 **その後、スマホからの遠隔監視をお楽しみください！**
