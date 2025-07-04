#!/usr/bin/env python3
"""
Google Drive接続維持スクリプト
定期実行でトークンの有効性を保つ
"""

import sys
import os
from datetime import datetime

def maintain_gdrive_connection():
    """Google Drive接続を維持"""
    try:
        from gdrive_utils import GDriveManager, DataSource
        
        print(f"🔍 Google Drive接続確認開始 - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        # マネージャー初期化
        manager = GDriveManager()
        
        # 認証確認
        if manager.authenticate():
            print("✅ 認証成功")
            
            # 接続状態確認
            status = manager.check_connection()
            if status['status'] == 'connected':
                print(f"✅ 接続正常 - ユーザー: {status.get('user_email', '不明')}")
                
                # 軽量なテストデータ送信
                test_data = {
                    "maintenance_check": True,
                    "timestamp": datetime.now().isoformat(),
                    "purpose": "connection_maintenance",
                    "status": "healthy"
                }
                
                filename = f"maintenance_check_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
                result = manager.upload_data(test_data, filename)
                
                if result['success']:
                    print(f"✅ メンテナンステスト成功 - {result['filename']}")
                    return True
                else:
                    print(f"❌ メンテナンステスト失敗 - {result['message']}")
                    return False
            else:
                print(f"❌ 接続失敗 - {status['message']}")
                return False
        else:
            print("❌ 認証失敗")
            return False
            
    except Exception as e:
        print(f"❌ エラー: {e}")
        return False

if __name__ == "__main__":
    print("🔧 Google Drive接続維持スクリプト")
    print("=" * 50)
    
    success = maintain_gdrive_connection()
    
    if success:
        print("🎉 Google Drive接続維持完了")
    else:
        print("⚠️ Google Drive接続に問題があります")
        print("📋 手動で再認証を実行してください:")
        print("   python test_gdrive_auth.py")
    
    print("=" * 50)
