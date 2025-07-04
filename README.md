# Raspberry Pi ネットワーク監視システム プロジェクト

Raspberry Piを使用した遠隔ネットワーク監視システムの開発プロジェクトです。
現場でのモニター・キーボード接続作業を完全に廃止し、スマホのみでの遠隔監視を実現します。

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

## 開発状況

### Phase 1: 基本監視システム（🚧 基盤完成）

**完成した基盤:**
- **ネットワーク監視Webアプリ**: WiFi・モバイル・有線対応
- **スマホ最適化WebUI**: レスポンシブデザイン
- **自動起動システム**: systemdサービス化
- **WSL2・Raspberry Pi両対応**: 統合セットアップ

**基盤機能:**
- WiFi信号強度（dBm → %変換）
- モバイル回線対応（4G/5G）
- インターネット接続状態
- Tailscale VPN状態
- 速度測定（オンデマンド）

**今後の拡張予定:**
- IoT機器疎通テスト機能
- システム監視機能追加
- 運用面での細かい調整

### Phase 2: 拡張機能（未実装）
- システム監視（CPU・メモリ・温度）
- リモート制御機能
- 複数台一元管理

## プロジェクト構成

```
S:\python\Raspberry-Pi\
├── environment-setup\              # 環境構築ツール
│   ├── setup_environment.sh       # 環境セットアップ
│   ├── cleanup_environment.sh     # 環境クリーンアップ
│   └── *.md                       # 各種ガイド
├── monitoring-system\              # 監視システム本体（完成）
│   ├── app.py                     # メインFlaskアプリ
│   ├── templates\                 # WebUI
│   ├── autostart_setup_unified.sh # 自動起動設定
│   ├── disable_autostart.sh       # 自動起動無効化
│   └── README.md                  # 運用マニュアル
├── venv\                          # Python仮想環境
├── DESIGN_DOCUMENT.md             # 設計書・実装記録
└── README.md                      # このファイル
```

## 技術スタック

- **Backend**: Flask（軽量Webアプリケーション）
- **Frontend**: HTML/CSS/JavaScript（スマホ最適化）
- **Network**: Tailscale VPN
- **Monitoring**: psutil, subprocess
- **Deployment**: systemd（サービス化）

## クイックスタート

### 1. 環境構築
```bash
cd environment-setup
./setup_environment.sh
```

### 2. ネットワーク監視システム起動

#### 開発・テスト環境（WSL2等）
```bash
cd monitoring-system
./autostart_setup_unified.sh
# → 選択 (1/2): 1 (テストモード)
```

#### 本番環境（Raspberry Pi）
```bash
cd monitoring-system
sudo ./autostart_setup_unified.sh
# → 自動で本番設定実行
```

### 3. アクセス
- **ローカル**: `http://localhost:5000`
- **Tailscale**: `http://[tailscale-ip]:5000`
- **スマホ**: 同じURLをブラウザで開く

## 運用

### 現場設置手順
1. Raspberry Pi 電源オン
2. ネットワーク接続（WiFi/有線）
3. Tailscale認証（初回のみ）
4. 2-3分待機 → 自動起動完了
5. スマホアクセス → 監視開始

**省電力運用:**
本番環境では電力消費を抑えるため、1日1-2時間程度の起動を想定。
systemdによる自動起動機能により、電源投入時に即座監視可能。

### 管理コマンド
```bash
# 状態確認
sudo systemctl is-enabled network-monitor && sudo systemctl is-active network-monitor

# サービス管理
sudo systemctl start|stop|restart network-monitor

# 自動起動無効化
sudo ./disable_autostart.sh
```

## ドキュメント

- **[monitoring-system/README.md](monitoring-system/README.md)** - 運用マニュアル
- **[DESIGN_DOCUMENT.md](DESIGN_DOCUMENT.md)** - 設計書・実装記録
- **[environment-setup/README.md](environment-setup/README.md)** - 環境構築ガイド

## セキュリティ

- **Tailscale VPN**: 暗号化通信
- **ファイアウォール**: ポート5000は開放しない
- **アクセス制御**: 認証済みデバイスのみ

## 特徴

- **軽量設計**: 24時間連続稼働対応
- **スマホ最適化**: レスポンシブデザイン
- **セキュア接続**: Tailscale VPN使用
- **拡張可能**: モジュラー設計
- **両環境対応**: WSL2開発・Raspberry Pi本番

## 成果

**Phase 1の基盤「スマホでの遠隔監視システム」の土台が完成しました。**

- ✅ 現場でのモニター・キーボード接続作業の代替手段確立
- ✅ スマホでの基本的な遠隔監視
- ✅ 軽量で安定したシステム基盤
- ✅ 電源オン時の自動起動システム（省電力運用対応）
- ✅ セキュアなアクセス基盤

**現状:** ネットワーク監視の基盤は完成。IoT機器固有の監視・テスト機能の追加により、完全なシステムへと発展可能な状態です。