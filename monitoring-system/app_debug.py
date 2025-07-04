#!/usr/bin/env python3
"""
デバッグ版アプリ - バックグラウンド処理を無効化
"""

from flask import Flask, render_template, jsonify, request
from datetime import datetime

# Google Drive連携機能
from gdrive_utils import GDriveManager, DataSource

app = Flask(__name__)

# 簡易版ネットワークデータ（バックグラウンド処理なし）
network_data = {
    'last_update': datetime.now().strftime('%H:%M:%S'),
    'ping_latency': 'テスト中',
    'internet_speed': 'テスト中',
    'connection_status': 'debug_mode',
    'network_interfaces': [],
    'tailscale_status': 'unknown',
    'tailscale_ip': None,
    'connected_devices': []
}

# Google Drive用グローバル変数
gdrive_data = {
    'connection_status': 'not_configured',
    'last_check': None,
    'user_email': None,
    'last_upload': None,
    'message': '未設定'
}

# Google Drive初期化
try:
    gdrive_manager = GDriveManager()
    print("✅ Google Drive manager initialized")
except Exception as e:
    print(f"❌ Google Drive initialization failed: {e}")
    gdrive_manager = None

@app.route('/')
def index():
    """メイン画面"""
    return render_template('network_monitor.html')

@app.route('/api/network-status')
def network_status():
    """ネットワーク状態API（デバッグ版）"""
    return jsonify(network_data)

# Google Drive関連ルート
@app.route('/gdrive')
def gdrive_dashboard():
    """Google Drive状態確認画面"""
    return render_template('gdrive_status.html')

@app.route('/api/gdrive-status')
def api_gdrive_status():
    """Google Drive状態API"""
    global gdrive_data
    
    if gdrive_manager:
        try:
            # 認証確認（まだ認証していない場合のみ）
            if not gdrive_manager._authenticated:
                print("🔐 Google Drive認証を確認中...")
                auth_success = gdrive_manager.authenticate()
                if not auth_success:
                    gdrive_data.update({
                        'status': 'authentication_failed',
                        'message': '認証に失敗しました。credentials.jsonを確認してください。',
                        'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    })
                    return jsonify(gdrive_data)
            
            # 接続状態確認
            status = gdrive_manager.check_connection()
            gdrive_data.update(status)
            
        except Exception as e:
            print(f"❌ Google Drive API error: {e}")
            gdrive_data.update({
                'status': 'error',
                'message': f'エラー: {str(e)}',
                'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            })
    else:
        gdrive_data.update({
            'status': 'not_available',
            'message': 'Google Drive機能が無効です'
        })
    
    return jsonify(gdrive_data)

@app.route('/gdrive/test-upload')
def test_upload_page():
    """テスト送信画面"""
    return render_template('test_upload.html')

@app.route('/api/gdrive-test-upload', methods=['POST'])
def api_test_upload():
    """テストファイル送信API"""
    global gdrive_data
    
    if not gdrive_manager:
        return jsonify({
            'success': False,
            'message': 'Google Drive機能が無効です'
        }), 500
    
    try:
        # リクエストデータ取得
        request_data = request.get_json() or {}
        data_type = request_data.get('data_type', 'test')
        
        # データ生成
        if data_type == 'network':
            data = DataSource.create_network_data(network_data)
        else:
            data = DataSource.create_test_data()
        
        filename = DataSource.get_filename(data_type)
        
        # Google Driveにアップロード
        result = gdrive_manager.upload_data(data, filename)
        
        # アップロード結果を保存
        if result['success']:
            gdrive_data['last_upload'] = {
                'filename': result['filename'],
                'upload_time': result['upload_time'],
                'data_type': data_type,
                'file_id': result.get('file_id'),
                'web_link': result.get('web_link')
            }
        
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'アップロードエラー: {str(e)}'
        }), 500

if __name__ == '__main__':
    print("🚀 Starting Debug Network Monitor App...")
    print("📍 Access via: http://localhost:8080")
    print("⚠️  Debug mode: バックグラウンド処理無効")
    
    app.run(host='0.0.0.0', port=8080, debug=True)
