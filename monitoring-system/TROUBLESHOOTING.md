# 🛠️ トラブルシューティングガイド

**Raspberry Pi 監視システム 詳細トラブルシューティング**

## 📋 目次

1. [Crontab管理機能の問題](#crontab管理機能の問題)
2. [アプリケーション起動の問題](#アプリケーション起動の問題)
3. [ネットワーク関連の問題](#ネットワーク関連の問題)
4. [録音機能の問題](#録音機能の問題)
5. [Google Drive連携の問題](#google-drive連携の問題)
6. [systemdサービスの問題](#systemdサービスの問題)
7. [権限とユーザー管理の問題](#権限とユーザー管理の問題)
8. [診断ツールとデバッグ手順](#診断ツールとデバッグ手順)

---

## Crontab管理機能の問題

### 問題: 「crontabエラー: crontabs/administrator/: fopen: 許可がありません」

**症状:**
- crontab管理画面で「サービス状態エラー」が表示される
- 「crontabエラー: crontabs/administrator/: fopen: 許可がありません」エラーメッセージ
- 手動でのcrontab実行（`app_start.sh`）は正常だが、自動起動（`app_autostart.sh`）では失敗

**原因分析:**
```bash
# 問題の根本原因
groups administrator
# 結果例: administrator adm dialout cdrom sudo audio video...
# → crontabグループが含まれていない

ls -la /var/spool/cron/crontabs/administrator
# 結果例: -rw------- 1 administrator crontab 1172 Jul 12 16:24
# → ファイルはcrontabグループ所有だが、ユーザーがグループに属していない
```

**なぜ手動実行では成功するのか:**
- **対話的セッション**: ログインシェルではPAM認証による特別な権限処理
- **setuid権限**: crontabコマンド自体が特権実行される
- **ユーザーセッション**: 一時的なcrontabアクセスが許可される

**なぜsystemdサービスでは失敗するのか:**
- **非対話的実行**: PAM認証が行われない
- **制限された権限**: systemdサービスは最小権限で実行
- **グループ不足**: crontabグループに属していないため直接ファイルアクセス不可

**解決方法:**
```bash
# 1. administratorユーザーをcrontabグループに追加
sudo usermod -a -G crontab administrator

# 2. グループ追加の確認
groups administrator
# crontabが追加されていることを確認

# 3. systemdサービス再起動（グループ変更を反映）
sudo systemctl restart raspi-monitoring.service

# 4. 動作確認
curl -s http://localhost:5000/api/crontab-status | python3 -m json.tool

# 5. ブラウザでcrontab管理画面を確認
# http://IPアドレス:5000/crontab
```

**検証コマンド:**
```bash
# 修正前の状態確認
echo "=== ユーザーグループ（修正前）==="
groups administrator

echo "=== crontabファイル権限 ==="
sudo ls -la /var/spool/cron/crontabs/administrator

echo "=== crontabサービス状態 ==="
sudo systemctl status cron

# 修正後の確認
echo "=== 修正実行 ==="
sudo usermod -a -G crontab administrator

echo "=== ユーザーグループ（修正後）==="
groups administrator

echo "=== サービス再起動 ==="
sudo systemctl restart raspi-monitoring.service

echo "=== API動作確認 ==="
curl -s http://localhost:5000/api/crontab-status
```

**その他の解決方法（代替案）:**

**方法2: systemdサービス設定でグループ追加**
```bash
sudo systemctl edit raspi-monitoring.service

# 以下を追加:
[Service]
SupplementaryGroups=crontab

# 反映
sudo systemctl daemon-reload
sudo systemctl restart raspi-monitoring.service
```

**方法3: app.pyでsudo使用（最終手段）**
```python
# app.pyのapi_crontab_status()関数を修正
result = subprocess.run(['sudo', '-u', 'administrator', 'crontab', '-l'], ...)
```

---

## アプリケーション起動の問題

### 問題: app_start.shは成功するが、app_autostart.shで環境変数エラー

**症状:**
- 手動起動スクリプト（`app_start.sh`）は正常動作
- 自動起動設定（`app_autostart.sh`）でAPIエラーが発生
- systemdサービスでの実行時に環境変数不足

**原因:**
systemdサービスと手動実行では実行環境が大きく異なる

**環境比較:**
```bash
# 手動実行時の環境
USER=administrator
HOME=/home/administrator
PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
SHELL=/bin/bash
LOGNAME=administrator

# systemdサービス実行時の環境
USER=administrator      # systemdが設定
HOME=/home/administrator # systemdが設定
PATH=/minimal/path      # 最小限のPATH
LOGNAME=???             # 設定されない場合がある
```

**解決方法:**
app.pyでsubprocessを実行する際に、明示的に環境変数を設定する

```python
# 修正例: api_crontab_status()関数
env = os.environ.copy()
env.update({
    'PATH': '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
    'USER': os.environ.get('USER', 'administrator'),
    'HOME': os.environ.get('HOME', '/home/administrator'),
    'LOGNAME': os.environ.get('USER', 'administrator')
})

result = subprocess.run(['crontab', '-l'], env=env, ...)
```

### 問題: ポート競合エラー

**症状:**
```
OSError: [Errno 98] Address already in use
```

**診断:**
```bash
# ポート使用状況確認
sudo ss -tlnp | grep :5000
sudo lsof -i :5000

# プロセス確認
ps aux | grep python | grep app.py
```

**解決方法:**
```bash
# 競合プロセス停止
./app_stop.sh
sudo pkill -f "python.*app.py"
sudo fuser -k 5000/tcp

# 再起動
./app_start.sh
```

---

## ネットワーク関連の問題

### 問題: WiFi情報取得失敗

**症状:**
- ネットワーク画面でWiFi情報が「取得失敗」
- 信号強度が表示されない

**診断:**
```bash
# WiFiインターフェース確認
iwconfig
nmcli dev wifi

# ワイヤレスツール確認
which iwconfig
which iw
```

**解決方法:**
```bash
# 必要ツールインストール
sudo apt update
sudo apt install wireless-tools iw

# NetworkManager確認
sudo systemctl status NetworkManager
sudo nmcli dev status
```

### 問題: Tailscale接続失敗

**症状:**
- Tailscale管理画面で「未接続」表示
- 外部からのアクセスができない

**診断:**
```bash
# Tailscale状態確認
tailscale status
tailscale ip

# サービス状態確認
sudo systemctl status tailscaled
```

**解決方法:**
```bash
# 再認証
sudo tailscale logout
sudo tailscale up

# サービス再起動
sudo systemctl restart tailscaled

# 自動起動設定
sudo systemctl enable tailscaled
```

---

## 録音機能の問題

### 問題: 録音デバイスが見つからない

**症状:**
- 録音画面でデバイス一覧が空
- 「No audio devices found」エラー

**診断:**
```bash
# オーディオデバイス確認
arecord -l
lsusb | grep -i audio

# PulseAudioデバイス確認
pactl list sources short
```

**解決方法:**
```bash
# audioグループ追加
sudo usermod -a -G audio administrator
# ログアウト・ログインが必要

# ALSA設定確認
sudo alsa force-reload

# PulseAudio再起動
pulseaudio -k
pulseaudio --start
```

### 問題: 録音音量が小さい

**診断:**
```bash
# 現在の音量レベル確認
amixer get Mic
amixer get Capture

# PulseAudio音量確認
pactl list sources
```

**解決方法:**
```bash
# ALSA音量調整
amixer set Mic 100%
amixer set Capture 100%

# PulseAudio音量ブースト
pactl set-source-volume alsa_input.usb-* 150%

# GUI音量調整
alsamixer
```

---

## Google Drive連携の問題

### 問題: 認証エラー「credentials.jsonが見つかりません」

**症状:**
- Google Drive画面で認証失敗
- アップロード機能が使用できない

**診断:**
```bash
# 認証ファイル確認
ls -la monitoring-system/data/credentials/
```

**解決方法:**
```bash
# Google Drive設定再実行
cd environment-setup
python setup_gdrive.py

# 手動で認証ファイル配置
# credentials.jsonをGoogle Cloud Consoleからダウンロード
# monitoring-system/data/credentials/に配置
```

### 問題: アップロードエラー

**診断:**
```bash
# ネットワーク接続確認
ping -c 3 google.com

# 認証トークン確認
ls -la monitoring-system/data/credentials/token.json

# Google Drive APIクォータ確認
```

**解決方法:**
```bash
# 認証トークンリセット
rm monitoring-system/data/credentials/token.json

# 再認証実行
cd environment-setup
python setup_gdrive.py
```

---

## systemdサービスの問題

### 問題: サービス起動失敗

**症状:**
```bash
sudo systemctl status raspi-monitoring
# Failed to start Raspberry Pi Monitoring System
```

**診断:**
```bash
# 詳細ログ確認
sudo journalctl -u raspi-monitoring -n 50 --no-pager

# サービスファイル確認
sudo systemctl cat raspi-monitoring

# ファイル権限確認
ls -la /etc/systemd/system/raspi-monitoring.service
```

**解決方法:**
```bash
# サービスファイル再作成
cd app_management
sudo ./app_remove_autostart.sh
sudo ./app_autostart.sh

# 手動設定確認
sudo systemctl daemon-reload
sudo systemctl enable raspi-monitoring
sudo systemctl start raspi-monitoring
```

### 問題: サービスの環境変数エラー

**症状:**
- systemdサービスでPython ImportError
- モジュールが見つからないエラー

**解決方法:**
```bash
# systemdサービス設定を修正
sudo systemctl edit raspi-monitoring

# 以下を追加:
[Service]
Environment=PATH=/home/administrator/Documents/raspi-remote-monitoring/venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=/home/administrator/Documents/raspi-remote-monitoring/monitoring-system

sudo systemctl daemon-reload
sudo systemctl restart raspi-monitoring
```

---

## 権限とユーザー管理の問題

### 問題: ファイル権限エラー

**症状:**
- 録音ファイル保存失敗
- 設定ファイル読み書きエラー

**診断:**
```bash
# プロジェクトディレクトリ権限確認
ls -la /home/administrator/Documents/raspi-remote-monitoring/
ls -la monitoring-system/data/

# 現在のユーザー確認
whoami
groups
```

**解決方法:**
```bash
# 権限修正
sudo chown -R administrator:administrator /home/administrator/Documents/raspi-remote-monitoring/
chmod -R 755 /home/administrator/Documents/raspi-remote-monitoring/
chmod -R 777 /home/administrator/Documents/raspi-remote-monitoring/data/
```

### 問題: sudoなしでsystemctl実行エラー

**解決方法:**
```bash
# administratorユーザーがsudoグループに属しているか確認
groups administrator

# sudoグループ追加（必要に応じて）
sudo usermod -a -G sudo administrator
```

---

## 診断ツールとデバッグ手順

### 完全診断スクリプト

```bash
#!/bin/bash
# comprehensive_diagnosis.sh - システム完全診断

echo "🔍 Raspberry Pi 監視システム 完全診断"
echo "========================================"

echo ""
echo "📊 システム基本情報"
echo "----------------"
echo "ホスト名: $(hostname)"
echo "稼働時間: $(uptime -p)"
echo "OS: $(lsb_release -d | cut -f2)"
echo "カーネル: $(uname -r)"
echo "CPU: $(lscpu | grep 'Model name' | awk -F: '{print $2}' | xargs)"
echo "メモリ使用量: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo "ディスク使用量: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"

echo ""
echo "👤 ユーザー・権限情報"
echo "------------------"
echo "現在のユーザー: $(whoami)"
echo "ユーザーグループ: $(groups)"
echo "sudo権限: $(sudo -n true 2>&1 && echo "あり" || echo "なし")"

echo ""
echo "🔧 プロジェクト状態"
echo "----------------"
PROJECT_ROOT="/home/administrator/Documents/raspi-remote-monitoring"
if [ -d "$PROJECT_ROOT" ]; then
    echo "プロジェクトルート: 存在 ($PROJECT_ROOT)"
    echo "仮想環境: $([ -d "$PROJECT_ROOT/venv" ] && echo "存在" || echo "なし")"
    echo "app.py: $([ -f "$PROJECT_ROOT/monitoring-system/app.py" ] && echo "存在" || echo "なし")"
    echo "設定ファイル: $([ -f "$PROJECT_ROOT/monitoring-system/config.yaml" ] && echo "存在" || echo "なし")"
    
    # ディレクトリ権限
    echo "権限確認:"
    ls -la "$PROJECT_ROOT" | head -5
else
    echo "❌ プロジェクトルートが見つかりません"
fi

echo ""
echo "🖥️ サービス状態"
echo "-------------"
echo "raspi-monitoring サービス:"
if systemctl is-active --quiet raspi-monitoring; then
    echo "  状態: 稼働中"
    echo "  自動起動: $(systemctl is-enabled raspi-monitoring 2>/dev/null || echo '無効')"
    echo "  PID: $(systemctl show raspi-monitoring -p MainPID --value 2>/dev/null)"
else
    echo "  状態: 停止中"
fi

echo ""
echo "🌐 ネットワーク状態"
echo "----------------"
# ローカルIP
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "ローカルIP: $LOCAL_IP"

# インターネット接続
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "インターネット接続: 正常"
else
    echo "インターネット接続: エラー"
fi

# Tailscale
if command -v tailscale >/dev/null 2>&1; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "未接続")
    echo "Tailscale IP: $TAILSCALE_IP"
    echo "Tailscale状態: $(tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4 || echo "不明")"
else
    echo "Tailscale: 未インストール"
fi

echo ""
echo "🎤 オーディオデバイス"
echo "------------------"
if command -v arecord >/dev/null 2>&1; then
    AUDIO_DEVICES=$(arecord -l 2>/dev/null | grep -c "card")
    echo "録音デバイス数: $AUDIO_DEVICES"
    echo "audioグループ: $(groups | grep -q audio && echo "所属済み" || echo "未所属")"
else
    echo "ALSA: 未インストール"
fi

echo ""
echo "📅 Crontab状態"
echo "-------------"
echo "crontabグループ: $(groups | grep -q crontab && echo "所属済み" || echo "未所属")"
if crontab -l >/dev/null 2>&1; then
    CRON_JOBS=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l)
    echo "アクティブジョブ数: $CRON_JOBS"
else
    echo "crontab: アクセスエラーまたは未設定"
fi

echo ""
echo "🔗 ポート状態"
echo "------------"
if command -v ss >/dev/null 2>&1; then
    echo "ポート5000: $(ss -tln | grep :5000 >/dev/null && echo "使用中" || echo "利用可能")"
    if ss -tln | grep :5000 >/dev/null; then
        echo "使用プロセス:"
        sudo ss -tlnp | grep :5000
    fi
else
    echo "ss コマンドが利用できません"
fi

echo ""
echo "📝 最新ログ (10行)"
echo "----------------"
if systemctl list-unit-files | grep -q raspi-monitoring; then
    sudo journalctl -u raspi-monitoring -n 10 --no-pager 2>/dev/null || echo "ログ取得エラー"
else
    echo "raspi-monitoring サービスが見つかりません"
fi

echo ""
echo "🧪 API動作テスト"
echo "---------------"
if curl -s --max-time 5 http://localhost:5000/api/network-status >/dev/null 2>&1; then
    echo "ネットワークAPI: 正常"
else
    echo "ネットワークAPI: エラー"
fi

if curl -s --max-time 5 http://localhost:5000/api/crontab-status >/dev/null 2>&1; then
    echo "CrontabAPI: 正常"
else
    echo "CrontabAPI: エラー"
fi

echo ""
echo "✅ 診断完了"
echo "=========="
echo "問題がある場合は、上記の情報をもとにTROUBLESHOOTING.mdを参照してください。"
```

### 段階的デバッグ手順

**レベル1: 基本確認**
```bash
cd app_management
./app_status.sh
```

**レベル2: 詳細ログ確認**
```bash
sudo journalctl -u raspi-monitoring -f
# 別ターミナルでアプリにアクセスして動作確認
```

**レベル3: 手動実行テスト**
```bash
cd app_management
./app_stop.sh
./app_start.sh
# 問題の切り分け
```

**レベル4: 環境再構築**
```bash
cd environment-setup
./reset_and_setup.sh
```

**レベル5: 完全診断**
```bash
# 上記の完全診断スクリプトを実行
chmod +x comprehensive_diagnosis.sh
./comprehensive_diagnosis.sh
```

---

## 📞 サポート情報

### ログ収集方法

問題報告の際は以下の情報を収集してください：

```bash
# ログ収集スクリプト
#!/bin/bash
LOGDIR="debug_logs_$(date +%Y%m%d_%H%M%S)"
mkdir $LOGDIR

# システム情報
uname -a > $LOGDIR/system_info.txt
free -h >> $LOGDIR/system_info.txt
df -h >> $LOGDIR/system_info.txt

# サービス状態
sudo systemctl status raspi-monitoring > $LOGDIR/service_status.txt
sudo journalctl -u raspi-monitoring -n 100 > $LOGDIR/service_logs.txt

# ネットワーク情報
ip addr show > $LOGDIR/network_info.txt
tailscale status >> $LOGDIR/network_info.txt 2>&1

# 権限情報
groups > $LOGDIR/user_info.txt
ls -la /home/administrator/Documents/raspi-remote-monitoring/ > $LOGDIR/file_permissions.txt

# 設定ファイル
cp monitoring-system/config.yaml $LOGDIR/ 2>/dev/null || echo "config.yaml not found" > $LOGDIR/config_error.txt

echo "ログ収集完了: $LOGDIR/"
tar czf ${LOGDIR}.tar.gz $LOGDIR/
echo "アーカイブ作成: ${LOGDIR}.tar.gz"
```


---

🛠️ **このトラブルシューティングガイドで解決しない場合は、ログ収集スクリプトの結果とともにお問い合わせください。**