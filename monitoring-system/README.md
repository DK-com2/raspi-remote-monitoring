# 🎯 監視システム運用マニュアル

**Raspberry Pi ネットワーク監視システム 日常運用ガイド**

## 📱 日常的な使用方法

### アクセス方法

#### ローカルアクセス
- **メイン画面**: `http://localhost:5000`
- **Google Drive**: `http://localhost:5000/gdrive`
- **録音機能**: `http://localhost:5000/recording`

#### Tailscale経由アクセス（推奨）
```bash
# Tailscale IP確認
tailscale ip -4
# 例: 100.64.1.23

# スマホブラウザでアクセス
# http://100.64.1.23:5000
```

### 監視項目の見方

#### ネットワーク状態表示

**接続タイプ**
- `WiFi` - 無線LAN接続
- `Mobile` - モバイル回線接続  
- `Ethernet` - 有線LAN接続

**信号強度**
- `90-100%` - 優秀（緑色）
- `70-89%` - 良好（黄色）
- `50-69%` - 普通（オレンジ）
- `0-49%` - 弱い（赤色）

**インターネット状態**
- `✅ 接続中` - 正常
- `❌ 切断` - 問題あり
- `⏳ 確認中` - 測定中

**Tailscale VPN**
- `🔒 接続済み` - VPN経由アクセス可能
- `❌ 未接続` - VPN設定が必要
- `⚠️ 認証エラー` - 再認証が必要

### テスト機能の使用

#### Pingテスト
1. **ホスト指定**: google.com, 8.8.8.8 など
2. **テスト実行**: 「🏓 Pingテスト」ボタンクリック
3. **結果確認**: 平均レイテンシとパケットロス率

#### 速度測定
1. **測定開始**: 「⚡ 速度測定」ボタンクリック
2. **待機**: 10-30秒程度
3. **結果確認**: ダウンロード速度（Mbps）

#### 手動更新
- **データ更新**: 「🔄 手動更新」で即座に情報更新
- **自動更新**: 5秒間隔で自動実行

### 録音機能の使用

#### 基本操作
1. **デバイス選択**: マイクを選択
2. **時間設定**: 1-3600秒で指定
3. **録音開始**: 「🎤 録音開始」ボタン
4. **ファイル取得**: 完了後「📥 ダウンロード」

#### 設定項目
- **サンプルレート**: 16kHz（音声）/ 44.1kHz（音楽）
- **チャンネル**: モノラル（1ch）/ ステレオ（2ch）
- **品質**: 用途に応じて調整

### Google Drive連携

#### 状態確認
1. **接続確認**: `/gdrive` でアクセス
2. **ユーザー情報**: 認証済みアカウント表示
3. **アップロード履歴**: 最新送信データ確認

#### テストデータ送信
1. **データ選択**: テストデータ or ネットワークデータ
2. **送信実行**: 「📤 送信」ボタン
3. **結果確認**: ファイル名とリンク表示

## 🔧 管理コマンド

### 基本的な管理

#### アプリケーション状態確認
```bash
cd app_management
./app_status.sh
```

**確認項目:**
- システム情報（ホスト名、稼働時間）
- アプリケーション状態（プロセス、ポート）
- Python環境（仮想環境、パッケージ）
- ネットワーク（ローカルIP、Tailscale）

#### アプリケーション制御
```bash
# 手動起動
./app_start.sh

# 停止
./app_stop.sh

# 状態確認
./app_status.sh
```

### 自動起動管理

#### 自動起動設定
```bash
cd app_management
sudo ./app_autostart.sh
```

#### 自動起動解除
```bash
sudo ./app_remove_autostart.sh
```

#### systemdサービス管理
```bash
# サービス状態確認
sudo systemctl status raspi-monitoring

# サービス制御
sudo systemctl start raspi-monitoring    # 開始
sudo systemctl stop raspi-monitoring     # 停止
sudo systemctl restart raspi-monitoring  # 再起動

# ログ確認
sudo journalctl -u raspi-monitoring -f   # リアルタイムログ
sudo journalctl -u raspi-monitoring -n 50 # 過去50行
```

## 🛠️ トラブルシューティング

### よくある問題と解決方法

#### アプリケーション関連

**アプリが起動しない**
```bash
# 状態確認
cd app_management
./app_status.sh

# 手動起動テスト
./app_start.sh

# ログ確認
sudo journalctl -u raspi-monitoring -n 50
```

**ポート競合エラー**
```bash
# ポート使用状況確認
sudo ss -tlnp | grep :5000

# 競合プロセス停止
./app_stop.sh
sudo pkill -f "python.*app.py"

# 再起動
./app_start.sh
```

**Python環境エラー**
```bash
# 仮想環境確認
echo $VIRTUAL_ENV
which python

# 環境再構築
cd ../environment-setup
./reset_and_setup.sh
```

#### ネットワーク関連

**WiFi情報取得失敗**
```bash
# ワイヤレスツール確認
iwconfig
nmcli dev wifi

# ツール再インストール
sudo apt install wireless-tools
```

**Tailscale接続問題**
```bash
# Tailscale状態確認
tailscale status

# 再認証
sudo tailscale logout
sudo tailscale up

# サービス再起動
sudo systemctl restart tailscaled
```

**インターネット接続確認**
```bash
# DNS解決テスト
nslookup google.com

# 基本疎通テスト
ping -c 3 8.8.8.8

# ルーティング確認
route -n
ip route show
```

#### Google Drive連携

**認証エラー**
```bash
# 認証トークンリセット
rm monitoring-system/data/credentials/token.json

# 認証再実行
cd environment-setup
python setup_gdrive.py
```

#### 録音機能

**録音デバイスが見つからない**
```bash
# デバイス確認
arecord -l
lsusb | grep -i audio

# 権限確認
groups $USER
sudo usermod -a -G audio $USER
# ログアウト・ログインが必要
```

**音量が小さい**
```bash
# ALSA音量調整
alsamixer

# コマンドで調整
amixer set Mic 100%
amixer set Capture 100%

# PulseAudio音量ブースト
pactl set-source-volume alsa_input.usb-* 150%
```

### システム診断

#### 完全診断スクリプト
```bash
#!/bin/bash
# システム診断スクリプト

echo "=== システム情報 ==="
uname -a
uptime
free -h
df -h

echo "=== ネットワーク情報 ==="
ip addr show
route -n
nslookup google.com

echo "=== アプリケーション状態 ==="
cd app_management
./app_status.sh

echo "=== サービス状態 ==="
sudo systemctl status raspi-monitoring
tailscale status

echo "=== ログ（最新10行） ==="
sudo journalctl -u raspi-monitoring -n 10 --no-pager
```

## 📊 パフォーマンス監視

### リソース使用量

#### 正常な使用量目安
- **CPU使用率**: 平常時5-15%、測定時20-40%
- **メモリ使用量**: 50-150MB
- **ディスク使用量**: プロジェクト全体で500MB-1GB
- **ネットワーク**: 1-5Mbps（速度測定時を除く）

#### 異常値の目安
- **CPU使用率**: 持続的に80%以上
- **メモリ使用量**: 500MB以上
- **ディスク使用量**: 90%以上使用
- **応答時間**: 5秒以上

### 最適化方法

#### CPU負荷軽減
```bash
# 更新頻度を下げる
cd monitoring-system
./change_update_frequency.sh
# 15秒または30秒を選択
```

#### メモリ使用量削減
```bash
# 不要なサービス停止
sudo systemctl disable bluetooth
sudo systemctl disable cups

# Python プロセス最適化
# monitoring-system/config.yaml で debug: false に設定
```

#### ディスク容量管理
```bash
# 古いログ削除
sudo journalctl --vacuum-time=7d

# 古い録音ファイル削除
find monitoring-system/data/recordings -name "*.wav" -mtime +7 -delete

# Pythonキャッシュクリア
find . -name "__pycache__" -type d -exec rm -rf {} +
```

## 🔄 定期メンテナンス

### 週次チェック（推奨）
```bash
# 1. 全般状態確認
cd app_management
./app_status.sh

# 2. ログ確認
sudo journalctl -u raspi-monitoring --since "1 week ago" | grep -i error

# 3. ディスク容量確認
df -h

# 4. ネットワーク接続テスト
ping -c 5 google.com
tailscale status
```

### 月次メンテナンス
```bash
# 1. システム更新
sudo apt update && sudo apt upgrade

# 2. Python依存関係更新
cd monitoring-system
source ../venv/bin/activate
pip list --outdated

# 3. ログローテーション
sudo journalctl --vacuum-time=30d

# 4. 古いファイル整理
find data/recordings -name "*.wav" -mtime +30 -delete
```

### 四半期メンテナンス
```bash
# 1. 完全環境更新
cd environment-setup
./reset_and_setup.sh

# 2. バックアップ作成
cp -r monitoring-system/data ~/backup_$(date +%Y%m%d)

# 3. パフォーマンス評価
# 応答時間、リソース使用量の長期傾向確認
```

## 🎯 運用のベストプラクティス

### 効率的な監視

1. **定期的なアクセス**: 1日1-2回の状態確認
2. **異常時の対応**: エラー表示時は即座にログ確認
3. **テスト実行**: 週1回程度のPing・速度テスト
4. **バックアップ**: 月1回の設定ファイルバックアップ

### セキュリティ運用

1. **Tailscale使用**: 外部アクセスはVPN経由のみ
2. **定期的な認証更新**: 3-6ヶ月毎のTailscale認証確認
3. **SSH設定**: パスワード認証無効化、鍵認証のみ
4. **ファイアウォール**: 不要ポートの閉鎖確認

### データ管理

1. **録音ファイル**: 定期的な削除または移動
2. **ログファイル**: 30日以上経過分の削除
3. **Google Drive**: 月1回のアップロード履歴確認
4. **設定ファイル**: 変更時のバックアップ作成

---

🎯 **この運用マニュアルにより、安定した遠隔監視システムの運用が可能です。**  
📱 **スマホからの快適な監視をお楽しみください！**
