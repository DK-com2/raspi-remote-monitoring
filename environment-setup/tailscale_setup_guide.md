# Tailscale VPN 設定ガイド

## 概要

Tailscale は簡単にセットアップできるVPNサービスです。
setup_all.sh の実行中に自動インストールされますが、認証は手動で行う必要があります。

## 初回設定

### 1. アカウント作成

https://tailscale.com/ にアクセスして無料アカウントを作成:
- Google アカウント (推奨)
- GitHub アカウント 
- Microsoft アカウント
- メールアドレス

### 2. ラズパイでの認証

setup_all.sh 実行中、または後で以下を実行:

```bash
sudo tailscale up
```

表示されるURLをブラウザで開いて認証。

### 3. スマホアプリ設定

1. App Store/Google Play で「Tailscale」をダウンロード
2. 同じアカウントでログイン
3. ラズパイが自動的に表示される

## 使用方法

### IP アドレス確認
```bash
tailscale ip -4
# 例: 100.64.1.23
```

### 接続状況確認
```bash
tailscale status
```

### スマホからアクセス
ブラウザで `http://[TailscaleのIP]:8080` にアクセス

## トラブルシューティング

### 認証エラー
```bash
sudo systemctl restart tailscaled
sudo tailscale up
```

### 接続できない
```bash
# ファイアウォール確認
sudo ufw status

# ポート確認
sudo netstat -tlnp | grep 8080
```

### デバイスが見えない
1. 同じアカウントでログインしているか確認
2. インターネット接続を確認
3. アプリでリフレッシュ実行

## セキュリティ

- エンドツーエンド暗号化
- 登録デバイス間のみ通信可能
- アカウント認証が必要
- 不要なデバイスは削除推奨

## 料金

個人利用なら20台まで永続無料。
