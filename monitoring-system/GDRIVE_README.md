# Google Drive連携機能 - Phase 1 実装完了

## 🎉 実装内容

Phase 1の基本機能を実装しました：

### ✅ 実装された機能
1. **Google Drive認証管理**
2. **接続状態確認画面**
3. **テスト送信機能**
4. **IoT拡張対応設計**

### 📁 追加されたファイル

```
monitoring-system/
├── gdrive_utils.py              # Google Drive機能の中核
├── config.yaml                  # 設定ファイル
├── requirements.txt             # 依存関係（更新）
├── app.py                      # 既存ファイル（拡張）
├── data/                       # データ保存用
│   ├── credentials/            # 認証情報
│   ├── uploads/               # アップロード一時保存
│   └── .gitignore             # Git管理除外
└── templates/
    ├── gdrive_status.html      # Google Drive状態確認
    ├── test_upload.html        # テスト送信画面
    └── network_monitor.html    # メイン画面（リンク追加）

environment-setup/
└── setup_gdrive.py             # 認証セットアップスクリプト
```

## 🚀 セットアップ手順

### 1. 依存関係インストール
```bash
cd monitoring-system
pip install -r requirements.txt
```

### 2. Google Cloud Console設定
1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. 新しいプロジェクトを作成
3. Google Drive APIを有効化
4. 認証情報 > OAuth 2.0 クライアント IDを作成
   - アプリケーションタイプ: **デスクトップアプリケーション**
5. `credentials.json` をダウンロード

### 3. 認証ファイル配置
```bash
# credentials.jsonを以下に配置
monitoring-system/data/credentials/credentials.json
```

### 4. 認証セットアップ実行
```bash
cd raspi-remote-monitoring
python environment-setup/setup_gdrive.py
```

### 5. アプリケーション起動
```bash
cd monitoring-system
python app.py
```

## 🖥️ 使用方法

### アクセス方法
- **メイン画面**: `http://localhost:5000/`
- **Google Drive状態**: `http://localhost:5000/gdrive`
- **テスト送信**: `http://localhost:5000/gdrive/test-upload`

### 機能説明

#### 1. 接続状態確認 (`/gdrive`)
- Google Drive認証状態の確認
- ユーザー情報表示
- 最新アップロード履歴
- 自動30秒更新

#### 2. テスト送信 (`/gdrive/test-upload`)
- **テストデータ**: ランダムなIoT風データ生成
- **ネットワークデータ**: 現在のネットワーク監視データ
- JSON形式でGoogle Driveに保存

## 🔧 カスタマイズ

### 新しいデータソース追加例
```python
# gdrive_utils.py に追加
class IoTDataSource:
    @staticmethod
    def create_sensor_data():
        return {
            "sensor_id": "temp_001",
            "temperature": get_temperature_from_sensor(),  # 実際のセンサーAPI
            "timestamp": datetime.now().isoformat(),
            "data_type": "temperature_sensor"
        }
```

### 設定変更
```yaml
# config.yaml
gdrive:
  folder_name: "your-custom-folder"  # Google Driveフォルダ名
  test_data_types:
    - name: "カスタムセンサー"
      type: "custom"
```

## 🎯 Phase 2 拡張予定

1. **データソース選択UI**
2. **自動アップロード機能**
3. **スケジュール設定**
4. **実IoTセンサー対応**

## 🛠️ トラブルシューティング

### 認証エラー
```bash
# 認証情報をリセット
rm monitoring-system/data/credentials/token.json
python environment-setup/setup_gdrive.py
```

### 依存関係エラー
```bash
# 仮想環境での実行を推奨
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows
pip install -r monitoring-system/requirements.txt
```

### ファイアウォール設定
- ローカル認証時にポート8080が必要な場合があります

## 📊 動作確認

### テスト送信データ例
```json
{
  "data_type": "test",
  "device_id": "test_device_001",
  "timestamp": "2025-06-14T10:30:00.123456",
  "test_value": 42,
  "temperature": 25.3,
  "humidity": 60.8,
  "status": "test_ok",
  "battery_level": 85
}
```

## 🔗 API エンドポイント

- `GET /api/gdrive-status` - Google Drive接続状態
- `POST /api/gdrive-test-upload` - テストデータ送信

## 📈 今後の拡張性

この実装により以下が可能になります：

1. **IoTセンサー簡単統合**: DataSourceクラスの拡張のみ
2. **複数デバイス対応**: device_id による識別
3. **データ形式柔軟性**: JSON/CSV等の対応
4. **クラウド分析連携**: Google Apps Script等との組み合わせ

---

**Phase 1完了**: Google Drive基本連携とテスト送信機能が利用可能です。
