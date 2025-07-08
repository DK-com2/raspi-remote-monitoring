# Raspberry Pi 録音機能 セットアップガイド

## 概要

既存のRaspberry Piネットワーク監視システムに録音機能を追加しました。Webブラウザから任意の時間を録音し、ファイルをダウンロードできます。

## 機能

- **Web録音制御**: ブラウザから録音の開始/停止
- **デバイス選択**: 複数の録音デバイスから選択可能
- **品質設定**: サンプルレート、チャンネル数の調整
- **リアルタイム監視**: 録音進捗の表示
- **ファイル管理**: 録音ファイルの一覧表示とダウンロード
- **時間指定**: 1秒から3600秒（1時間）まで設定可能

## セットアップ手順

### 1. 必要なパッケージのインストール

```bash
# ALSA録音ツール
sudo apt update
sudo apt install alsa-utils

# 音量調整ツール（オプション）
sudo apt install sox
```

### 2. 録音デバイスの確認

```bash
# 利用可能な録音デバイスを確認
arecord -l

# 録音テスト（10秒間）
arecord -d 10 -f cd test.wav
aplay test.wav
```

### 3. アプリケーションの起動

```bash
# プロジェクトディレクトリに移動
cd S:\python\raspi-remote-monitoring\monitoring-system

# 録音機能付きアプリを起動
python app_with_recording.py
```

または既存のapp.pyを置き換える場合：

```bash
# バックアップ作成
cp app.py app_original.py

# 新しいアプリに置き換え
cp app_with_recording.py app.py

# 通常通り起動
python app.py
```

### 4. マイクの音量調整（必要に応じて）

```bash
# ALSAミキサーで音量調整
alsamixer

# またはコマンドで直接調整
amixer set Mic 80%
amixer set Capture 80%

# PulseAudioで音量を上げる場合
pactl set-source-volume alsa_input.usb-* 150%
```

## 使用方法

### 1. Webインターフェースへのアクセス

```
http://[ラズパイのIP]:5000/recording
```

または

```
http://localhost:5000/recording  (ラズパイ上から)
```

### 2. 録音手順

1. **デバイス選択**: ドロップダウンから録音デバイスを選択
2. **時間設定**: 録音時間を秒単位で入力（1-3600秒）
3. **品質設定**: サンプルレートとチャンネル数を選択
4. **録音開始**: 「🎤 録音開始」ボタンをクリック
5. **進捗確認**: リアルタイムで経過時間と残り時間を表示
6. **録音停止**: 自動停止または「⏹️ 停止」ボタンで手動停止

### 3. ファイル管理

- **一覧表示**: 録音完了後、ファイル一覧に自動表示
- **ダウンロード**: 「📥 ダウンロード」ボタンでファイル取得
- **ファイル更新**: 「🔄 更新」ボタンで一覧を最新状態に

## ファイル構造

```
monitoring-system/
├── app_with_recording.py          # 録音機能付きメインアプリ
├── templates/
│   ├── recording.html             # 録音機能HTML
│   └── network_monitor.html       # メインページ（録音リンク追加済み）
└── data/
    └── recordings/                # 録音ファイル保存ディレクトリ
        ├── recording_20250108_143022.wav
        └── recording_20250108_143115.wav
```

## API エンドポイント

### 録音制御

- `GET /recording` - 録音機能ページ
- `GET /api/recording/devices` - 利用可能デバイス一覧
- `POST /api/recording/start` - 録音開始
- `POST /api/recording/stop` - 録音停止
- `GET /api/recording/status` - 録音状態取得

### ファイル管理

- `GET /api/recording/list` - 録音ファイル一覧
- `GET /api/recording/download/<filename>` - ファイルダウンロード

## 設定例

### 高品質録音（音楽用）
- サンプルレート: 48kHz
- チャンネル: ステレオ
- 時間: 必要に応じて

### 音声録音（会話用）
- サンプルレート: 16kHz
- チャンネル: モノラル
- 時間: 必要に応じて

### 長時間録音
- サンプルレート: 22.05kHz
- チャンネル: モノラル
- 時間: 3600秒（1時間）

## トラブルシューティング

### 1. 録音デバイスが見つからない

```bash
# USBマイクの接続確認
lsusb

# カード情報確認
cat /proc/asound/cards

# デバイスファイル確認
ls -la /dev/snd/
```

### 2. 録音音量が小さい

```bash
# マイクゲイン確認・調整
amixer -c 3 contents
amixer -c 3 set Mic 100%
amixer -c 3 set Capture 100%

# PulseAudioで音量ブースト
pactl set-source-volume alsa_input.usb-* 200%
```

### 3. 権限エラー

```bash
# ユーザーをaudioグループに追加
sudo usermod -a -G audio $USER

# ログアウト・ログインして反映
```

### 4. プロセスが残る場合

```bash
# 録音プロセス確認
ps aux | grep arecord

# 強制終了
sudo pkill arecord
```

## セキュリティ注意事項

1. **アクセス制限**: 外部からのアクセスを制限する場合は、ファイアウォール設定を調整
2. **ファイル管理**: 録音ファイルは定期的に整理・削除
3. **権限管理**: 録音機能の使用者を制限する場合は、認証機能を追加

## 拡張機能案

- **自動アップロード**: Google Driveへの自動アップロード
- **スケジュール録音**: 指定時刻での自動録音
- **音声解析**: 録音ファイルの音量レベル分析
- **圧縮機能**: MP3形式での保存オプション
- **ストリーミング**: リアルタイム音声ストリーミング

## 更新履歴

- **v1.0**: 基本的な録音機能を実装
- **v1.1**: デバイス選択機能とUI改善
- **v1.2**: ファイル管理機能を追加

---

このガイドに従って録音機能をセットアップし、ご質問やトラブルがあればお知らせください。