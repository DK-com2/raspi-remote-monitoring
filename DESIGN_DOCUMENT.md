# Raspberry Pi ネットワーク監視システム 設計書・実装記録

## プロジェクト概要

### 目標
- **スマホのみで全現場のラズパイを遠隔監視・管理**
- **現場でのモニター・キーボード接続作業を完全に廃止**
- **軽量で安定したシステム構築**

### システム構成
```
スマホ（Tailscale） → 各現場のラズパイ（Tailscale）
     ↓                        ↓
同一Tailscaleネットワーク内で直接通信
```

## 実装完了状況

### Phase 1: 基本監視システム（✅ 完了）

#### 完成したシステム
- **Flask監視アプリケーション**: ネットワーク状態リアルタイム監視
- **スマホ対応WebUI**: レスポンシブデザイン実装
- **自動起動システム**: systemdサービス化対応
- **WSL2・Raspberry Pi両対応**: 統合版セットアップスクリプト

#### 監視機能詳細
```python
# 監視項目
- WiFi信号強度（dBm → %変換）
- モバイル回線対応（4G/5G信号強度）
- 有線LAN接続監視
- インターネット接続状態（Ping レイテンシ）
- Tailscale VPN状態・IP表示
- ネットワークインターフェース一覧
- インターネット速度測定（オンデマンド）
```

#### 技術仕様
- **Backend**: Flask（軽量Webフレームワーク）
- **Frontend**: HTML/CSS/JavaScript（スマホ最適化）
- **監視**: psutil, subprocess（複数コマンド対応）
- **ポート**: 5000（Tailscale VPN経由でアクセス）

## ファイル構成

```
S:\python\Raspberry-Pi\monitoring-system\
├── app.py                          # メインFlaskアプリケーション
├── templates\
│   └── network_monitor.html        # WebUI（CSS・JavaScript内蔵）
├── autostart_setup_unified.sh      # 自動起動設定（WSL2・RPi両対応）
├── disable_autostart.sh            # 自動起動無効化スクリプト
├── change_update_frequency.sh      # 更新頻度変更ツール
├── test_autostart.sh               # 動作確認（本番設定後自動作成）
└── README.md                       # 運用マニュアル
```

## 実装詳細

### 1. 環境自動判定システム

#### 判定ロジック
```bash
# 環境自動検出
detect_environment() {
    if grep -q Microsoft /proc/version; then
        echo "wsl2"           # WSL2環境 → テストモード
    elif grep -q "Raspberry Pi" /proc/device-tree/model; then
        echo "raspberry_pi"   # Raspberry Pi → 本番モード
    else
        echo "linux"          # 一般Linux → 手動選択
    fi
}
```

#### 動作モード
- **テストモード（WSL2）**: 手動起動・終了、開発用
- **本番モード（Raspberry Pi）**: 自動起動・systemdサービス化

### 2. ネットワーク監視実装

#### 接続タイプ判定
```python
def get_connection_type():
    # WiFi: wlan, wifi, wl
    # モバイル: wwan, ppp, usb, rmnet, qmi
    # 有線: eth, en
    return connection_type, interface_name
```

#### 信号強度取得（複数手法対応）
```python
# WiFi信号強度取得方法
1. iwconfig コマンド（推奨）
2. nmcli（NetworkManager）
3. /proc/net/wireless ファイル
4. iw コマンド

# モバイル信号強度
1. mmcli（ModemManager）
2. qmicli（QMI）
```

### 3. 自動起動システム

#### systemdサービス設定
```ini
[Unit]
Description=Raspberry Pi Network Monitor
After=network-online.target tailscaled.service
Requires=tailscaled.service

[Service]
Type=simple
User=pi
ExecStart=/home/pi/Raspberry-Pi/venv/bin/python /home/pi/Raspberry-Pi/monitoring-system/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

#### 起動順序
```
1. OS起動
2. ネットワーク接続確立
3. Tailscale VPN開始
4. ネットワーク監視アプリ自動起動（15秒待機後）
```

### 4. セキュリティ設計

#### Tailscale VPN重視設計
```bash
# ファイアウォール設定
- ポート5000: 開放しない（Tailscale経由のみ）
- SSH: ローカルネットワーク用に許可
- 外部直接アクセス: 完全にブロック
```

#### アクセス制御
- **本番**: Tailscale認証済みデバイスのみ
- **開発**: localhost限定


## 運用手順

### 現場設置
```bash
1. Raspberry Pi 電源オン
2. ネットワーク接続（WiFi/有線）
3. Tailscale認証（初回のみ）
4. 2-3分待機 → 自動起動完了
5. スマホアクセス → 監視開始
```

### 日常監視
```bash
1. スマホでTailscaleアプリ起動
2. ブラウザで http://[tailscale-ip]:5000 アクセス
3. 信号強度・接続状態確認
4. 必要に応じてテスト実行
```

### 管理コマンド
```bash
# 状態確認
sudo systemctl is-enabled network-monitor && sudo systemctl is-active network-monitor

# サービス管理
sudo systemctl start|stop|restart network-monitor

# ログ確認
sudo journalctl -u network-monitor -f

# 自動起動無効化
sudo ./disable_autostart.sh
```

## 成果物・効果

### 完成した機能
- ✅ 現場でのモニター・キーボード接続作業の完全廃止
- ✅ スマホのみでの遠隔監視・基本操作
- ✅ ネットワーク品質の可視化
- ✅ 軽量で安定したシステム
- ✅ WSL2開発・Raspberry Pi本番の両対応
- ✅ 24時間連続稼働の実現

### 技術的成果
- 軽量Flask監視システムの確立
- Tailscale VPNによるセキュアアクセス
- レスポンシブWebデザインによるスマホ最適化
- 環境自動判定による汎用性確保
- systemdサービス化による安定稼働

## 今後の拡張計画

### Phase 2: 高度監視・制御機能（未実装）
- **システム監視**: CPU・メモリ・温度監視追加
- **リモート制御**: システム再起動・サービス制御
- **IoTテスト**: 疎通確認・動作テスト自動化
- **ログ監視**: システムログリアルタイム表示

### Phase 3: 複数台統合管理（未実装）
- **統合ダッシュボード**: 複数台一元管理
- **アラート機能**: 異常状態通知
- **統計レポート**: 履歴データ分析
- **予防保守**: スケジューリング機能

## トラブルシューティング

### よくある問題と解決方法

#### systemd関連
```bash
# サービス状態確認
sudo systemctl status network-monitor

# 設定リロード
sudo systemctl daemon-reload
sudo systemctl reset-failed network-monitor
```

#### ネットワーク関連
```bash
# WiFi情報取得失敗
sudo apt install wireless-tools

# Tailscale接続問題
sudo tailscale up

# ポート競合
ss -tlnp | grep :5000
pkill -f 'python.*app.py'
```

### 完全リセット手順
```bash
# 1. 自動起動無効化
sudo ./disable_autostart.sh

# 2. 再設定
sudo ./autostart_setup_unified.sh
```

## 設定カスタマイズ

### 更新頻度変更
```bash
# カスタマイズツール使用
chmod +x change_update_frequency.sh
./change_update_frequency.sh

# 選択肢: 3秒/5秒/10秒/15秒/30秒/カスタム
```

### 監視項目追加
```python
# app.py の get_network_data() 関数に追加
def get_custom_monitoring():
    # カスタム監視ロジック
    return custom_data
```

## 開発環境

### 使用技術
- **開発環境**: WSL2 Ubuntu
- **本番環境**: Raspberry Pi OS
- **言語**: Python 3.9+, Bash
- **フレームワーク**: Flask
- **VPN**: Tailscale
- **サービス管理**: systemd

### 開発ツール
- **統合セットアップ**: autostart_setup_unified.sh
- **無効化ツール**: disable_autostart.sh
- **頻度変更**: change_update_frequency.sh
- **状態確認**: 管理コマンド群


## まとめ

**Phase 1の目標である「スマホのみでの遠隔監視システム」の基盤は完成しました。**

現場でのモニター・キーボード接続作業が完全に不要となり、Tailscale VPN経由でのセキュアなアクセスにより、どこからでもネットワーク状態を監視できる実用的なシステムが完成しています。

軽量で安定した実装により、Raspberry Pi環境での24時間連続稼働を実現しました。
追加でデータ転送等のテストは後日実装予定