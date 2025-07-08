#!/usr/bin/env python3
"""
Google Drive連携機能
Google Drive APIを使ったファイルアップロード・管理を担当
"""

import os
import json
import yaml
from datetime import datetime
from typing import Dict, Any

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload, MediaIoBaseUpload
import io

# Google Drive API のスコープ
SCOPES = ['https://www.googleapis.com/auth/drive.file']

class GDriveManager:
    """Google Drive管理クラス"""
    
    def __init__(self, config_path: str = 'config.yaml'):
        """初期化"""
        self.config = self._load_config(config_path)
        self.service = None
        self.folder_id = None
        self._authenticated = False
    
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """設定ファイル読み込み"""
        try:
            with open(config_path, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f)
        except Exception as e:
            print(f"設定ファイル読み込みエラー: {e}")
            return {
                'gdrive': {
                    'folder_name': 'raspi-monitoring',
                    'credentials_file': '../data/credentials/credentials.json',
                    'token_file': '../data/credentials/token.json'
                }
            }
    
    def authenticate(self) -> bool:
        """Google Drive認証"""
        try:
            creds = None
            token_file = self.config['gdrive']['token_file']
            credentials_file = self.config['gdrive']['credentials_file']
            
            # 既存のトークンをチェック
            if os.path.exists(token_file):
                try:
                    # ファイルサイズが0でないことを確認
                    if os.path.getsize(token_file) > 0:
                        creds = Credentials.from_authorized_user_file(token_file, SCOPES)
                    else:
                        print(f"空のトークンファイルを検出: {token_file}")
                        os.remove(token_file)  # 空のファイルを削除
                        creds = None
                except (json.JSONDecodeError, ValueError) as e:
                    print(f"トークンファイルの読み込みエラー: {e}")
                    print(f"破損したトークンファイルを削除: {token_file}")
                    os.remove(token_file)
                    creds = None
            
            # トークンが無効または存在しない場合は新規認証
            if not creds or not creds.valid:
                if creds and creds.expired and creds.refresh_token:
                    print("Refreshing expired Google Drive token...")
                    creds.refresh(Request())
                else:
                    if not os.path.exists(credentials_file):
                        print(f"認証ファイルが見つかりません: {credentials_file}")
                        print("Google Cloud Consoleから credentials.json をダウンロードして配置してください")
                        return False
                    
                    print("Starting Google Drive authentication flow...")
                    flow = InstalledAppFlow.from_client_secrets_file(credentials_file, SCOPES)
                    
                    # 環境検出とWSL2対応
                    is_wsl2 = self._is_wsl2_environment()
                    
                    if is_wsl2:
                        print("WSL2環境を検出 - コンソール認証を使用します")
                        print("\n=== Google Drive認証手順 ===")
                        print("1. 以下のURLをWindowsブラウザでアクセス")
                        print("2. Googleアカウントでログイン")
                        print("3. 表示される認証コードをコピー")
                        print("4. このコンソールに貼り付け")
                        print("================================\n")
                        creds = flow.run_console()
                    else:
                        # WSL2以外の環境ではローカルサーバー認証を試行
                        try:
                            print("ブラウザ認証を試行中...")
                            creds = flow.run_local_server(port=0, open_browser=True)
                        except Exception as e:
                            print(f"ブラウザ認証失敗: {e}")
                            print("コンソール認証に切り替えます...")
                            creds = flow.run_console()
                
                # トークンを保存
                with open(token_file, 'w') as token:
                    token.write(creds.to_json())
                print(f"認証トークンを保存: {token_file}")
            
            # Google Drive APIサービス構築
            self.service = build('drive', 'v3', credentials=creds)
            self._authenticated = True
            
            # 監視用フォルダを作成または取得
            self._setup_monitoring_folder()
            
            return True
            
        except Exception as e:
            print(f"認証エラー: {e}")
            self._authenticated = False
            return False
    
    def _is_wsl2_environment(self) -> bool:
        """WSL2環境の検出"""
        try:
            # /proc/version でWSL2を検出
            with open('/proc/version', 'r') as f:
                version_info = f.read().lower()
                return 'microsoft' in version_info and 'wsl2' in version_info
        except:
            # Windows環境やその他の場合
            return False
    
    def _setup_monitoring_folder(self) -> None:
        """監視用フォルダの作成または取得"""
        try:
            folder_name = self.config['gdrive']['folder_name']
            
            # 既存フォルダを検索
            query = f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder'"
            results = self.service.files().list(q=query, fields="files(id, name)").execute()
            folders = results.get('files', [])
            
            if folders:
                self.folder_id = folders[0]['id']
                print(f"既存フォルダを使用: {folder_name}")
            else:
                # フォルダを新規作成
                folder_metadata = {
                    'name': folder_name,
                    'mimeType': 'application/vnd.google-apps.folder'
                }
                folder = self.service.files().create(body=folder_metadata, fields='id').execute()
                self.folder_id = folder.get('id')
                print(f"新規フォルダを作成: {folder_name}")
                
        except Exception as e:
            print(f"フォルダ設定エラー: {e}")
            self.folder_id = None
    
    def check_connection(self) -> Dict[str, Any]:
        """接続状態確認"""
        try:
            if not self._authenticated:
                return {
                    'status': 'not_authenticated',
                    'message': '認証が必要です',
                    'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                }
            
            # 簡単なAPI呼び出しで接続確認
            about = self.service.about().get(fields="user,storageQuota").execute()
            
            return {
                'status': 'connected',
                'user_email': about.get('user', {}).get('emailAddress', '不明'),
                'storage_used': about.get('storageQuota', {}).get('usage', '不明'),
                'folder_id': self.folder_id,
                'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'message': '正常に接続されています'
            }
            
        except Exception as e:
            print(f"Google Drive connection check error: {e}")
            return {
                'status': 'error',
                'message': f'接続エラー: {str(e)}',
                'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
    
    def upload_data(self, data: Dict[str, Any], filename: str) -> Dict[str, Any]:
        """データをGoogle Driveにアップロード"""
        try:
            if not self._authenticated:
                return {
                    'success': False,
                    'message': '認証が必要です'
                }
            
            # JSONデータを文字列に変換
            json_data = json.dumps(data, ensure_ascii=False, indent=2)
            
            # MediaIoBaseUploadを使用してメモリ上のデータをアップロード
            media = MediaIoBaseUpload(
                io.BytesIO(json_data.encode('utf-8')),
                mimetype='application/json'
            )
            
            # ファイルメタデータ
            file_metadata = {
                'name': filename,
                'parents': [self.folder_id] if self.folder_id else []
            }
            
            # アップロード実行
            file = self.service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id,name,webViewLink'
            ).execute()
            
            return {
                'success': True,
                'file_id': file.get('id'),
                'filename': file.get('name'),
                'web_link': file.get('webViewLink'),
                'upload_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'message': 'アップロード成功'
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'アップロードエラー: {str(e)}'
            }
    
    def upload_file(self, file_path: str, filename: str = None) -> Dict[str, Any]:
        """ファイルをGoogle Driveにアップロード"""
        try:
            if not self._authenticated:
                return {
                    'success': False,
                    'message': '認証が必要です'
                }
            
            if not os.path.exists(file_path):
                return {
                    'success': False,
                    'message': f'ファイルが見つかりません: {file_path}'
                }
            
            # ファイル名の決定
            if not filename:
                filename = os.path.basename(file_path)
            
            # ファイルの MIME タイプを推定
            if filename.endswith('.wav'):
                mimetype = 'audio/wav'
            elif filename.endswith('.mp3'):
                mimetype = 'audio/mpeg'
            elif filename.endswith('.json'):
                mimetype = 'application/json'
            elif filename.endswith('.txt'):
                mimetype = 'text/plain'
            else:
                mimetype = 'application/octet-stream'
            
            # MediaFileUploadを使用してファイルをアップロード
            media = MediaFileUpload(file_path, mimetype=mimetype)
            
            # ファイルメタデータ
            file_metadata = {
                'name': filename,
                'parents': [self.folder_id] if self.folder_id else []
            }
            
            # アップロード実行
            file = self.service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id,name,webViewLink,size'
            ).execute()
            
            return {
                'success': True,
                'file_id': file.get('id'),
                'filename': file.get('name'),
                'web_link': file.get('webViewLink'),
                'file_size': file.get('size'),
                'upload_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'message': 'ファイルアップロード成功'
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'ファイルアップロードエラー: {str(e)}'
            }
    
    def list_files(self, limit: int = 10) -> Dict[str, Any]:
        """Google Driveのファイル一覧を取得"""
        try:
            if not self._authenticated:
                return {
                    'success': False,
                    'message': '認証が必要です'
                }
            
            # クエリ構築
            query = f"parents in '{self.folder_id}'" if self.folder_id else None
            
            # ファイル一覧取得
            results = self.service.files().list(
                q=query,
                pageSize=limit,
                fields="files(id,name,mimeType,size,createdTime,webViewLink)",
                orderBy="createdTime desc"
            ).execute()
            
            files = results.get('files', [])
            
            return {
                'success': True,
                'files': files,
                'count': len(files),
                'folder_id': self.folder_id,
                'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'ファイル一覧取得エラー: {str(e)}'
            }
    
    def delete_file(self, file_id: str) -> Dict[str, Any]:
        """Google Driveからファイルを削除"""
        try:
            if not self._authenticated:
                return {
                    'success': False,
                    'message': '認証が必要です'
                }
            
            # ファイル削除
            self.service.files().delete(fileId=file_id).execute()
            
            return {
                'success': True,
                'message': 'ファイル削除成功',
                'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'ファイル削除エラー: {str(e)}'
            }
