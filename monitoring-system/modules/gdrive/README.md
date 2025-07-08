# Google Drive モジュール

Raspberry Pi 監視システム用の Google Drive 連携機能を提供します。

## 構成

```
modules/gdrive/
├── __init__.py          # モジュールエクスポート
├── manager.py           # Google Drive管理（認証、アップロード、削除等）
└── data_sources.py      # データソース管理（各種データ生成）
```

## 機能

### GDriveManager クラス
- Google Drive認証（OAuth2.0、WSL2対応）
- ファイル・データのアップロード
- ファイル一覧取得
- ファイル削除
- 監視用フォルダ自動作成

### DataSource クラス
- テストデータ生成
- ネットワーク監視データ整形
- ファイル名生成

### IoTDataSource クラス（将来実装）
- 温度・湿度センサーデータ
- モーションセンサーデータ
- 照度センサーデータ

### RecordingDataSource クラス
- 録音ファイルメタデータ生成

## 使用方法

```python
from modules.gdrive import GDriveManager, DataSource

# 初期化
gdrive = GDriveManager('config.yaml')

# 認証
if gdrive.authenticate():
    # データアップロード
    data = DataSource.create_test_data()
    filename = DataSource.get_filename('test')
    result = gdrive.upload_data(data, filename)
    
    # ファイルアップロード
    result = gdrive.upload_file('/path/to/file.wav')
    
    # ファイル一覧
    files = gdrive.list_files(limit=10)
```

## API エンドポイント

### 既存の Google Drive API
- `GET /api/gdrive-status` - 接続状態確認
- `POST /api/gdrive-test-upload` - テストデータアップロード

### 新規追加
- `POST /api/recording/upload-to-gdrive/<filename>` - 録音ファイルアップロード
- `GET /api/gdrive-files?limit=20` - ファイル一覧取得
- `DELETE /api/gdrive-delete/<file_id>` - ファイル削除

## 設定

```yaml
gdrive:
  folder_name: 'raspi-monitoring'
  credentials_file: '../data/credentials/credentials.json'
  token_file: '../data/credentials/token.json'
```

## 環境対応

- **WSL2**: コンソール認証を自動選択
- **Windows/Linux**: ブラウザ認証（フォールバック: コンソール認証）

## 将来の拡張

- IoTセンサーデータの自動アップロード
- 定期的なデータバックアップ
- データ圧縮・暗号化
- 複数のクラウドストレージ対応
