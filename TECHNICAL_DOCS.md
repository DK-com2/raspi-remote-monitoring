# 🔧 技術仕様・開発者ガイド

**Raspberry Pi ネットワーク監視システム 技術仕様書**

## 🏗️ システム設計

### アーキテクチャ概要

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   スマホ        │    │   Raspberry Pi   │    │  Google Drive   │
│   (Tailscale)   │◄──►│   監視システム    │◄──►│   クラウド保存   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         │                        │                        │
    ┌────▼────┐              ┌────▼────┐              ┌────▼────┐
    │ Web UI  │              │  Flask  │              │ Drive   │
    │ (HTML)  │              │  App    │              │ API     │
    └─────────┘              └─────────┘              └─────────┘
```

### 技術スタック

#### フロントエンド
- **HTML5**: セマンティックマークアップ
- **CSS3**: レスポンシブデザイン、Flexbox/Grid
- **JavaScript**: Vanilla JS、非同期通信（fetch API）
- **デザイン**: Material Design風、グラデーション

#### バックエンド
- **Flask 2.3+**: 軽量Webフレームワーク
- **Python 3.10+**: メインプログラミング言語
- **psutil**: システム監視ライブラリ
- **subprocess**: システムコマンド実行

#### インフラ
- **systemd**: サービス管理・自動起動
- **Tailscale**: VPNによる安全な通信
- **Google Drive API**: クラウドストレージ連携

## 🔌 API仕様

### ネットワーク監視 API

#### `GET /api/network-data`
現在のネットワーク状態を取得

**レスポンス例:**
```json
{
  "timestamp": "2025-07-10T10:30:00",
  "connection_type": "wifi",
  "interface": "wlan0",
  "signal_strength": 75,
  "ssid": "MyNetwork",
  "internet_status": true,
  "ping_latency": 12.5,
  "tailscale": {
    "status": "connected",
    "ip": "100.64.1.23"
  }
}
```

### Google Drive API

#### `GET /api/gdrive-status`
Google Drive接続状態確認

**レスポンス:**
```json
{
  "status": "connected",
  "user_email": "user@example.com",
  "folder_id": "1ABC...XYZ",
  "last_upload": "2025-07-10T09:15:00",
  "file_count": 42
}
```

## 🧩 モジュール構成

### ネットワーク監視モジュール (`modules/network/`)

#### `monitor.py` - メイン監視機能
```python
class NetworkMonitor:
    def get_connection_type(self) -> tuple
    def get_wifi_signal_strength(self, interface: str) -> int
    def get_mobile_signal_strength(self, interface: str) -> int
    def check_internet_connectivity(self) -> dict
    def get_tailscale_status(self) -> dict
    def ping_test(self, host: str, count: int = 4) -> dict
```

### Google Drive連携モジュール (`modules/gdrive/`)

#### `manager.py` - Drive管理
```python
class GDriveManager:
    def authenticate(self) -> bool
    def check_connection(self) -> dict
    def upload_data(self, data: dict, filename: str) -> dict
    def upload_file(self, file_path: str) -> dict
    def list_files(self, limit: int = 50) -> list
    def delete_file(self, file_id: str) -> bool
```

## 🔧 カスタマイズガイド

### 新しい監視項目の追加

#### 1. データ取得関数の作成
```python
# modules/network/monitor.py に追加
def get_custom_metric(self) -> dict:
    """カスタム監視項目の取得"""
    try:
        # カスタムロジック実装
        result = subprocess.run(['custom-command'], 
                              capture_output=True, text=True)
        return {
            "value": parse_custom_output(result.stdout),
            "status": "success"
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}
```

#### 2. API エンドポイントの追加
```python
# app.py に追加
@app.route('/api/custom-metric')
def get_custom_metric():
    monitor = NetworkMonitor()
    data = monitor.get_custom_metric()
    return jsonify(data)
```

### UI テーマのカスタマイズ

#### カラーテーマ変更
```css
/* templates/network_monitor.html の<style>セクション */
:root {
    --primary-color: #2196F3;    /* ブルー → 任意の色 */
    --secondary-color: #FFC107;  /* アンバー → 任意の色 */
    --background-start: #1a1a2e; /* ダーク → 任意の色 */
    --background-end: #16213e;   /* ダーク → 任意の色 */
}
```

## 🚀 拡張機能開発

### プラグインシステムの実装

#### プラグイン基底クラス
```python
# modules/plugin_base.py
from abc import ABC, abstractmethod

class MonitoringPlugin(ABC):
    @abstractmethod
    def get_name(self) -> str:
        pass
    
    @abstractmethod
    def get_data(self) -> dict:
        pass
    
    @abstractmethod
    def get_config_schema(self) -> dict:
        pass
```

## 📊 パフォーマンス最適化

### メモリ使用量最適化

#### 循環参照の回避
```python
# 適切なオブジェクト管理
class NetworkMonitor:
    def __init__(self):
        self._cache = {}
        self._cache_ttl = {}
    
    def get_cached_data(self, key: str, ttl: int = 60):
        now = time.time()
        if key in self._cache and now - self._cache_ttl.get(key, 0) < ttl:
            return self._cache[key]
        return None
    
    def set_cached_data(self, key: str, data: any):
        self._cache[key] = data
        self._cache_ttl[key] = time.time()
        
        # キャッシュサイズ制限
        if len(self._cache) > 100:
            oldest_key = min(self._cache_ttl.keys(), 
                           key=lambda k: self._cache_ttl[k])
            del self._cache[oldest_key]
            del self._cache_ttl[oldest_key]
```

## 🔒 セキュリティ実装

### 認証・認可

#### 基本認証の実装
```python
from functools import wraps
from flask import request, abort
import hashlib
import secrets

class AuthManager:
    def __init__(self):
        self.api_keys = {}  # 実際はデータベースまたは設定ファイル
    
    def generate_api_key(self, user_id: str) -> str:
        api_key = secrets.token_urlsafe(32)
        key_hash = hashlib.sha256(api_key.encode()).hexdigest()
        self.api_keys[key_hash] = user_id
        return api_key
    
    def validate_api_key(self, api_key: str) -> bool:
        key_hash = hashlib.sha256(api_key.encode()).hexdigest()
        return key_hash in self.api_keys

def require_auth(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        api_key = request.headers.get('X-API-Key')
        if not api_key or not auth_manager.validate_api_key(api_key):
            abort(401)
        return f(*args, **kwargs)
    return decorated_function
```

## 🧪 テスト実装

### ユニットテスト

#### テスト構造
```python
# tests/test_network_monitor.py
import unittest
from unittest.mock import patch, MagicMock
from modules.network.monitor import NetworkMonitor

class TestNetworkMonitor(unittest.TestCase):
    def setUp(self):
        self.monitor = NetworkMonitor()
    
    @patch('subprocess.run')
    def test_get_wifi_signal_strength(self, mock_subprocess):
        # モックレスポンス
        mock_subprocess.return_value = MagicMock(
            stdout="wlan0     IEEE 802.11  ESSID:TestSSID\n" +
                   "          Signal level=-50 dBm",
            returncode=0
        )
        
        result = self.monitor.get_wifi_signal_strength("wlan0")
        
        self.assertEqual(result, 75)  # -50dBm ≈ 75%
        mock_subprocess.assert_called_once()
```

## 🚀 デプロイメント

### Docker化

#### Dockerfile
```dockerfile
# Dockerfile
FROM python:3.11-slim

# システムパッケージインストール
RUN apt-get update && apt-get install -y \
    net-tools \
    wireless-tools \
    iputils-ping \
    alsa-utils \
    && rm -rf /var/lib/apt/lists/*

# ワーキングディレクトリ設定
WORKDIR /app

# Python依存関係インストール
COPY monitoring-system/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコピー
COPY monitoring-system/ ./monitoring-system/
COPY environment-setup/ ./environment-setup/

# 設定ディレクトリ作成
RUN mkdir -p /app/data/credentials /app/data/recordings

# 非rootユーザー作成
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

# ポート公開
EXPOSE 5000

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/api/network-data || exit 1

# アプリケーション起動
CMD ["python", "monitoring-system/app.py"]
```

#### docker-compose.yml
```yaml
# docker-compose.yml
version: '3.8'

services:
  monitoring:
    build: .
    ports:
      - "5000:5000"
    volumes:
      - ./data:/app/data
      - /dev/snd:/dev/snd  # 音声デバイスアクセス用
    devices:
      - /dev/snd  # ALSAデバイス
    network_mode: host    # ネットワーク監視用
    environment:
      - FLASK_ENV=production
      - PYTHONUNBUFFERED=1
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/network-data"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## 📚 参考資料

### 外部ライブラリ

- **Flask**: https://flask.palletsprojects.com/
- **psutil**: https://github.com/giampaolo/psutil
- **Google API Client**: https://github.com/googleapis/google-api-python-client
- **Tailscale**: https://tailscale.com/kb/

### システム要件

- **Python**: 3.10以上
- **RAM**: 最低512MB、推奨1GB以上
- **ストレージ**: 最低4GB、推奨8GB以上
- **ネットワーク**: WiFi/有線LAN/モバイル対応

### ライセンス

本プロジェクトはMITライセンスの下で公開されています。

---

📖 **このドキュメントは開発者向けの技術仕様書です。**  
👤 **ユーザー向けの情報は「セットアップガイド」および「運用マニュアル」を参照してください。**
