# ネットワーク監視システム

**Raspberry Pi & WSL2対応 ネットワーク監視Webアプリケーション**

## 概要

ラズパイ・Linux環境のネットワーク状態をリアルタイムでスマホから監視するWebアプリケーションです。
現場でのモニター・キーボード接続作業を廃止し、遠隔監視を実現します。

## 主な機能

### リアルタイム監視
- **WiFi信号強度**とSSID表示（dBm → %変換）
- **モバイル回線**対応（4G/5G信号強度）
- **有線LAN**接続監視
- **インターネット接続状態**（Ping レイテンシ）
- **Tailscale VPN状態**とIP表示
- **ネットワークインターフェース**一覧

### オンデマンドテスト
- **Pingテスト**（任意ホスト指定可能）
- **インターネット速度測定**（ダウンロード）
- **手動更新機能**

### スマホ最適化
- **レスポンシブデザイン**
- **タッチ操作対応**
- **5秒ごと自動更新**
- **美しいグラデーションUI**

## クイックスタート

### 1. 開発・テスト環境（WSL2等）
```bash
cd monitoring-system
chmod +x autostart_setup_unified.sh
./autostart_setup_unified.sh
# → 選択 (1/2): 1 (テストモード)
```

### 2. 本番環境（Raspberry Pi）
```bash
cd monitoring-system
chmod +x autostart_setup_unified.sh
sudo ./autostart_setup_unified.sh
# → 自動で本番設定実行
```

### 3. アクセス
- **ローカル**: `http://localhost:5000`
- **Tailscale**: `http://[tailscale-ip]:5000`
- **スマホ**: 同じURLをブラウザで開く

## 運用モード

### テストモード（WSL2・開発用）
- 手動起動・終了
- debug=True
- systemd設定なし
- 開発・デバッグ用途

### 本番モード（Raspberry Pi）
- **OS起動時自動開始**
- debug=False
- **systemdサービス化**
- **永続化設定**

## 管理コマンド

### 自動起動設定確認
```bash
# 設定状況確認
sudo systemctl is-enabled network-monitor && sudo systemctl is-active network-monitor
# 結果: enabled + active = 自動起動設定済み＆動作中
```

### サービス管理
```bash
sudo systemctl start network-monitor    # 手動開始
sudo systemctl stop network-monitor     # 停止
sudo systemctl restart network-monitor  # 再起動
sudo systemctl status network-monitor   # 詳細状態
```

### ログ確認
```bash
sudo journalctl -u network-monitor -f   # リアルタイムログ
curl http://localhost:5000              # HTTP応答確認
```

### 自動起動無効化
```bash
chmod +x disable_autostart.sh
sudo ./disable_autostart.sh
# → 完全に手動起動状態に戻す
```

## 技術仕様

### アーキテクチャ
- **Backend**: Flask（軽量Webフレームワーク）
- **Frontend**: HTML/CSS/JavaScript（スマホ最適化）
- **監視**: psutil, subprocess
- **通信**: requests, threading
- **VPN**: Tailscale連携

### 対応環境
- **開発**: WSL2, Ubuntu, 一般Linux
- **本番**: Raspberry Pi OS, Debian系Linux
- **ネットワーク**: WiFi, 有線LAN, モバイル回線

### 更新頻度
- **ネットワーク監視**: 10秒間隔
- **ブラウザ更新**: 5秒間隔  
- **速度測定**: 1分間隔（自動）

## プロジェクト構成

```
monitoring-system/
├── app.py                          # メインアプリケーション
├── templates/
│   └── network_monitor.html        # WebUI（CSS内蔵）
├── autostart_setup_unified.sh      # 自動起動設定（統合版）
├── disable_autostart.sh            # 自動起動無効化
├── test_autostart.sh               # 動作確認（本番設定後作成）
└── README.md                       # このファイル
```

## 対応ネットワーク詳細

### WiFi接続
- **信号強度**: dBm → %変換表示
- **SSID**: ネットワーク名表示
- **対応コマンド**: iwconfig, nmcli, iw, /proc/net/wireless

### モバイル回線
- **4G/5G信号強度**: RSSI値対応
- **キャリア情報**: オペレーター名表示
- **対応コマンド**: mmcli, qmicli

### 有線LAN
- **接続状態**: インターフェース監視
- **速度情報**: リンク速度表示

### Tailscale VPN
- **接続状態**: アクティブ/非アクティブ
- **VPN IP**: Tailscaleネットワーク内IP表示

## セキュリティ仕様

### ネットワークセキュリティ
- **Tailscale VPN**: 暗号化通信
- **ファイアウォール**: ポート5000は**開放しない**
- **SSH**: ローカルネットワーク用に許可

### アクセス制御
- **本番**: Tailscale認証済みデバイスのみ
- **開発**: localhost限定

## カスタマイズ

### 監視間隔変更
```python
# app.py の update_network_data() 関数
time.sleep(10)  # 10秒 → 任意の秒数
```

### 監視項目追加
```python
# app.py の get_network_data() 関数に追加
def get_your_custom_data():
    # カスタム監視ロジック
    return custom_value
```

### UI変更
```html
<!-- templates/network_monitor.html のCSS部分を編集 -->
```

## 拡張予定

このアプリケーションを基盤とした将来の機能拡張:

1. **システム監視**: CPU・メモリ・温度監視
2. **リモート制御**: 再起動・サービス制御
3. **IoTテスト**: 疎通確認・動作テスト自動化
4. **ログ監視**: システムログリアルタイム表示
5. **アラート機能**: 異常状態通知
6. **複数台管理**: 一元管理ダッシュボード

## トラブルシューティング

### WiFi情報取得失敗
```bash
sudo apt install wireless-tools
iwconfig
```

### Tailscale接続問題
```bash
sudo tailscale status
sudo tailscale up  # 再認証
```

### ポート5000使用中
```bash
ss -tlnp | grep :5000
pkill -f 'python.*app.py'  # 手動停止
```

### systemd設定確認
```bash
sudo systemctl daemon-reload
sudo systemctl reset-failed network-monitor
```

## 運用例

### 現場設置手順
1. **Raspberry Pi 電源オン**
2. **ネットワーク接続** (WiFi/有線)
3. **Tailscale認証** (初回のみ)
4. **2-3分待機** → 自動起動完了
5. **スマホアクセス** → 監視開始

### 日常監視
- **スマホ**: Tailscaleアプリ起動 → ブラウザアクセス
- **確認項目**: 信号強度, 接続状態, 速度
- **テスト実行**: Pingテスト, 速度測定

## サポート

### 設定ファイル場所
- **サービス**: `/etc/systemd/system/network-monitor.service`
- **アプリ**: `~/Raspberry-Pi/monitoring-system/app.py`
- **ログ**: `sudo journalctl -u network-monitor`

### 初期化方法
```bash
# 完全リセット
./disable_autostart.sh
# 再設定
sudo ./autostart_setup_unified.sh
```

---

**これで現場でのモニター・キーボード接続作業が完全に不要になります。**