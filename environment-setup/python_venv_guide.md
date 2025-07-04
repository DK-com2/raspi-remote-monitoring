# Python仮想環境ガイド

## 基本情報

setup_all.sh 実行後、以下の構成になります:

```
~/Raspberry-Pi/
├── venv/                # Python仮想環境
├── requirements.txt     # ライブラリ一覧
└── environment-setup/   # 構築ツール
```

## 仮想環境の使い方

### 有効化
```bash
source venv/bin/activate
# プロンプトが (venv) に変わる
```

### 無効化
```bash
deactivate
```

### 状態確認
```bash
echo $VIRTUAL_ENV
which python
which pip
```

## 日常的な使用

### 開発開始時
```bash
cd ~/Raspberry-Pi
source venv/bin/activate
# 開発作業
```

### 開発終了時
```bash
deactivate
```

## ライブラリ管理

### インストール済み確認
```bash
pip list
pip list | grep flask
```

### 新しいライブラリ追加
```bash
pip install new-library
pip freeze > requirements.txt  # 更新
```

### ライブラリ更新
```bash
pip install --upgrade library-name
```

## トラブルシューティング

### 仮想環境が壊れた場合
```bash
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### パッケージが見つからない場合
```bash
# 仮想環境に入っているか確認
echo $VIRTUAL_ENV

# pip の場所確認  
which pip
```

### requirements.txt から再インストール
```bash
pip install -r requirements.txt
```

## 本番環境での注意

### 仮想環境の場所
プロジェクトルートに配置することで:
- 全サブプロジェクトから利用可能
- 標準的なPythonプロジェクト構成
- CI/CD・Docker対応

### バックアップ
```bash
pip freeze > requirements_backup.txt
```

### 環境の複製
```bash
# 別環境での再現
pip install -r requirements.txt
```
