#!/usr/bin/env python3
"""
Google Drive認証セットアップスクリプト
credentials.jsonの配置確認と初期認証を実行
"""

import os
import sys
import shutil
from pathlib import Path

def check_credentials():
    """認証ファイルの確認"""
    credentials_dir = Path("monitoring-system/data/credentials")
    credentials_file = credentials_dir / "credentials.json"
    
    print("🔍 Google Drive認証設定を確認中...")
    print(f"📁 認証フォルダ: {credentials_dir.absolute()}")
    
    # フォルダ存在確認
    if not credentials_dir.exists():
        print("❌ 認証フォルダが存在しません")
        print(f"📁 フォルダを作成してください: {credentials_dir}")
        return False
    
    # credentials.json確認
    if not credentials_file.exists():
        print("❌ credentials.json が見つかりません")
        print()
        print("📋 設定手順:")
        print("1. Google Cloud Console (https://console.cloud.google.com/) にアクセス")
        print("2. 新しいプロジェクトを作成")
        print("3. Google Drive API を有効化")
        print("4. 認証情報 > OAuth 2.0 クライアント ID を作成")
        print("   - アプリケーションタイプ: デスクトップアプリケーション")
        print("5. credentials.json をダウンロード")
        print(f"6. ダウンロードしたファイルを以下に配置:")
        print(f"   {credentials_file.absolute()}")
        print()
        return False
    
    print("✅ credentials.json が見つかりました")
    return True

def test_authentication():
    """認証テスト"""
    print("\n🔐 Google Drive認証テストを開始...")
    
    try:
        # monitoring-systemディレクトリをPythonパスに追加
        monitoring_path = os.path.join(os.getcwd(), "monitoring-system")
        if monitoring_path not in sys.path:
            sys.path.insert(0, monitoring_path)
        
        # 作業ディレクトリも変更
        original_dir = os.getcwd()
        os.chdir("monitoring-system")
        
        try:
            from gdrive_utils import GDriveManager
            
            # GDriveManager初期化
            manager = GDriveManager()
            
            print("📡 Google Drive認証を試行中...")
            print("   ブラウザが開きます。Googleアカウントでログインしてください。")
            
            # 認証実行
            if manager.authenticate():
                print("✅ 認証成功!")
                
                # 接続テスト
                print("🔍 接続状態を確認中...")
                status = manager.check_connection()
                
                if status['status'] == 'connected':
                    print(f"✅ Google Drive接続成功!")
                    print(f"📧 ユーザー: {status.get('user_email', '不明')}")
                    print(f"📁 監視フォルダID: {status.get('folder_id', '不明')}")
                    
                    # テストアップロード
                    print("\n📤 テストファイルのアップロードを試行...")
                    test_data = {
                        "test": "setup_test",
                        "timestamp": "2025-06-14T10:00:00",
                        "message": "Google Drive setup test successful"
                    }
                    
                    result = manager.upload_data(test_data, "setup_test.json")
                    
                    if result['success']:
                        print("✅ テストアップロード成功!")
                        print(f"📁 ファイル名: {result['filename']}")
                        if result.get('web_link'):
                            print(f"🔗 リンク: {result['web_link']}")
                    else:
                        print(f"❌ テストアップロード失敗: {result['message']}")
                        return False
                    
                else:
                    print(f"❌ Google Drive接続失敗: {status['message']}")
                    return False
                    
            else:
                print("❌ 認証失敗")
                return False
                
        finally:
            # 元のディレクトリに戻る
            os.chdir(original_dir)
            
    except ImportError:
        print("❌ 必要なライブラリがインストールされていません")
        print("📦 以下のコマンドで依存関係をインストールしてください:")
        print("   pip install -r monitoring-system/requirements.txt")
        return False
    except Exception as e:
        print(f"❌ 認証エラー: {e}")
        return False
    
    return True

def main():
    """メイン処理"""
    print("🚀 Google Drive認証セットアップ")
    print("=" * 50)
    
    # 現在のディレクトリ確認
    current_dir = Path.cwd()
    print(f"📂 現在のディレクトリ: {current_dir}")
    
    # プロジェクトルート確認
    if not (current_dir / "monitoring-system").exists():
        print("❌ monitoring-systemフォルダが見つかりません")
        print("   raspi-remote-monitoringプロジェクトのルートディレクトリで実行してください")
        sys.exit(1)
    
    # Step 1: 認証ファイル確認
    if not check_credentials():
        print("\n❌ 認証ファイルの設定が必要です")
        sys.exit(1)
    
    # Step 2: 認証テスト
    if test_authentication():
        print("\n" + "=" * 50)
        print("🎉 Google Drive認証セットアップ完了!")
        print("📋 次のステップ:")
        print("1. Flaskアプリを起動: cd monitoring-system && python app.py")
        print("2. ブラウザでアクセス: http://localhost:5000/gdrive")
        print("3. Google Drive連携機能をテスト")
        print("=" * 50)
    else:
        print("\n❌ 認証セットアップに失敗しました")
        print("📋 トラブルシューティング:")
        print("• credentials.jsonファイルが正しいか確認")
        print("• Google Drive APIが有効化されているか確認")  
        print("• インターネット接続を確認")
        print("• ファイアウォール設定を確認")
        sys.exit(1)

if __name__ == "__main__":
    main()
