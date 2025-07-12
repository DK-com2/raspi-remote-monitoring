#!/usr/bin/env python3
"""
Raspberry Pi 監視システム - モジュラー版
ネットワーク監視・録音・Google Drive連携機能をモジュール化
"""

from flask import Flask, render_template, jsonify, request, send_file
import threading
import time
import os
from datetime import datetime
from pathlib import Path

# 作業ディレクトリとパスの初期化
script_dir = Path(__file__).parent.absolute()
project_root = script_dir.parent  # raspi-remote-monitoring
data_dir = project_root / "data"

# 絶対パスでデータディレクトリを作成
os.makedirs(data_dir / "recordings", exist_ok=True)
os.makedirs(data_dir / "credentials", exist_ok=True)

print(f"📁 プロジェクトルート: {project_root}")
print(f"📁 データディレクトリ: {data_dir}")

# モジュールインポート
from config import settings
print(f"📝 設定情報: {settings._config.keys() if hasattr(settings, '_config') else '設定未読み込み'}")
print(f"🔍 ネットワーク設定: {settings.network}")

from modules.network import NetworkMonitor
from modules.recording import AudioRecorder
from modules.gdrive import GDriveManager, DataSource  # Google Drive連携機能

# Flaskアプリ初期化
app = Flask(__name__)

# モジュールインスタンス
network_monitor = NetworkMonitor()
audio_recorder = AudioRecorder(str(data_dir / "recordings"))

# Google Drive初期化（絶対パスで初期化）
try:
    # Google Drive用の設定を絶対パスで作成
    gdrive_config = {
        'gdrive': {
            'folder_name': os.getenv('GDRIVE_FOLDER_NAME', 'RaspberryPi-Records'),  # 環境変数でカスタマイズ可能
            'credentials_file': str(data_dir / "credentials" / "credentials.json"),
            'token_file': str(data_dir / "credentials" / "token.json")
        }
    }
    
    # 一時的に設定ファイルを作成
    import tempfile
    import yaml
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
        yaml.dump(gdrive_config, f)
        temp_config_path = f.name
    
    gdrive_manager = GDriveManager(temp_config_path)
    
    # 一時ファイルを削除
    os.unlink(temp_config_path)
    
    print("Google Drive manager initialized with absolute paths")
except Exception as e:
    print(f"Google Drive initialization failed: {e}")
    print("Google Drive機能を無効化します")
    gdrive_manager = None

# Google Drive用グローバル変数（互換性のため維持）
gdrive_data = {
    'connection_status': 'not_configured',
    'last_check': None,
    'user_email': None,
    'last_upload': None,
    'message': '未設定'
}

# ========================================
# メインページ
# ========================================

@app.route('/')
def index():
    """メインページ（モバイルダッシュボード）"""
    return render_template('mobile_dashboard.html')

@app.route('/dashboard')
def mobile_dashboard():
    """モバイルダッシュボード（メインと同じ）"""
    return render_template('mobile_dashboard.html')

@app.route('/network-monitor')
def network_monitor_legacy():
    """旧メインページ（互換性のため保持）"""
    return render_template('network_monitor.html')

@app.route('/tailscale')
def tailscale_page():
    """Tailscale管理ページ"""
    return render_template('tailscale_manage.html')

@app.route('/crontab')
def crontab_page():
    """Crontab管理ページ"""
    return render_template('crontab_manage.html')

@app.route('/devices')
def devices_page():
    """デバイス管理ページ"""
    return render_template('devices_manage.html')

@app.route('/network')
def network_page():
    """モバイル向けネットワーク詳細ページ"""
    return render_template('network_detail.html')

# ========================================
# ネットワーク監視API
# ========================================

@app.route('/api/network-status')
def network_status():
    """ネットワーク状態API"""
    return jsonify(network_monitor.get_data())

@app.route('/api/ping-test')
def api_ping_test():
    """オンデマンドPingテスト"""
    host = request.args.get('host', settings.network['ping_host'])
    latency = network_monitor.ping_test(host, settings.network['ping_count'])
    return jsonify({
        'host': host,
        'latency': latency,
        'status': 'success' if latency else 'failed',
        'timestamp': datetime.now().strftime('%H:%M:%S')
    })

@app.route('/api/speed-test')
def api_speed_test():
    """オンデマンド速度テスト"""
    speed = network_monitor.internet_speed_test()
    return jsonify({
        'speed_mbps': speed,
        'status': 'success' if speed else 'failed',
        'timestamp': datetime.now().strftime('%H:%M:%S')
    })

# ========================================
# デバイススキャンAPI
# ========================================

@app.route('/api/device-scan')
def api_device_scan():
    """簡易USBデバイススキャン（ラズパイ対応）"""
    try:
        import subprocess
        import re
        
        devices = []
        
        # lsusbコマンドでUSBデバイスを取得
        try:
            result = subprocess.run(['lsusb'], capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    if line.strip():
                        # lsusbの出力を解析
                        match = re.search(r'Bus\s+(\d+)\s+Device\s+(\d+):\s+ID\s+([0-9a-f:]+)\s+(.+)', line)
                        if match:
                            bus, device_num, device_id, description = match.groups()
                            
                            # デバイスタイプを推定
                            device_type = 'その他'
                            desc_lower = description.lower()
                            if ('audio' in desc_lower or 'sound' in desc_lower or 
                                'microphone' in desc_lower or 'mic' in desc_lower or
                                'speaker' in desc_lower or 'headphone' in desc_lower):
                                device_type = 'オーディオ'
                            elif 'camera' in desc_lower or 'webcam' in desc_lower:
                                device_type = 'カメラ'
                            elif 'storage' in desc_lower or 'disk' in desc_lower:
                                device_type = 'ストレージ'
                            elif 'keyboard' in desc_lower or 'mouse' in desc_lower:
                                device_type = '入力デバイス'
                            elif 'hub' in desc_lower:
                                device_type = 'USBハブ'
                            elif 'serial' in desc_lower or 'uart' in desc_lower:
                                device_type = 'シリアル通信'
                            elif 'root hub' in desc_lower:
                                continue  # ルートハブは表示をスキップ
                            
                            devices.append({
                                'name': description,
                                'type': device_type,
                                'bus': bus,
                                'device': device_num,
                                'id': device_id
                            })
        except subprocess.TimeoutExpired:
            print("lsusb command timed out")
        except FileNotFoundError:
            print("lsusb command not found")
        
        return jsonify({
            'devices': devices,
            'count': len(devices),
            'timestamp': datetime.now().strftime('%H:%M:%S'),
            'status': 'success' if devices else 'no_devices_found'
        })
        
    except Exception as e:
        print(f"Device scan error: {e}")
        return jsonify({
            'devices': [],
            'count': 0,
            'timestamp': datetime.now().strftime('%H:%M:%S'),
            'status': 'error',
            'error': str(e)
        }), 500

# ========================================
# Crontab管理API
# ========================================

@app.route('/api/crontab-status')
def api_crontab_status():
    """クロンタブ状態確認API（シンプル版）"""
    try:
        import subprocess
        
        # crontab -l コマンドで現在のジョブ一覧を取得
        result = subprocess.run(['crontab', '-l'], capture_output=True, text=True, timeout=10)
        
        if result.returncode == 0:
            # 成功時の処理
            all_lines = result.stdout.split('\n')
            cron_lines = []
            
            for line in all_lines:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue  # 空行やコメントをスキップ
                
                # 基本的なフィールド数チェック
                fields = line.split()
                if len(fields) >= 6:
                    cron_lines.append(line)
            
            active_jobs = len(cron_lines)
            
            return jsonify({
                'status': 'active' if active_jobs > 0 else 'inactive',
                'active_jobs': active_jobs,
                'jobs': cron_lines[:5],  # 最初の5個のジョブを表示
                'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'message': f'{active_jobs}個のアクティブジョブ' if active_jobs > 0 else 'アクティブなジョブなし'
            })
        else:
            # エラー時の処理
            error_message = 'crontabコマンドの実行に失敗しました'
            
            # よくあるエラーパターンの判定
            stderr_lower = result.stderr.lower()
            if 'no crontab' in stderr_lower:
                error_message = 'このユーザーにはcrontabが設定されていません（正常状態）'
                status = 'inactive'
            elif 'permission denied' in stderr_lower:
                error_message = 'crontabへのアクセス権限がありません'
                status = 'permission_error'
            else:
                status = 'error'
            
            return jsonify({
                'status': status,
                'active_jobs': 0,
                'jobs': [],
                'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'message': error_message
            })
            
    except subprocess.TimeoutExpired:
        return jsonify({
            'status': 'timeout',
            'active_jobs': 0,
            'jobs': [],
            'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'message': 'crontabコマンドがタイムアウトしました'
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'active_jobs': 0,
            'jobs': [],
            'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'message': f'エラー: {str(e)}'
        })

# ========================================
# Tailscale管理API
# ========================================

@app.route('/api/tailscale-status')
def api_tailscale_status():
    """Tailscale状態確認API"""
    try:
        import subprocess
        result = subprocess.run(['tailscale', 'status'], capture_output=True, text=True, timeout=10)
        
        if result.returncode == 0:
            status_lines = result.stdout.strip().split('\n')
            connected = 'offline' not in result.stdout.lower()
            
            # IP アドレスを抽出
            tailscale_ip = None
            devices_data = []
            
            for line in status_lines:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                    
                parts = line.split()
                if len(parts) >= 2:
                    ip = parts[0] if parts[0].startswith('100.') else None
                    name = parts[1] if len(parts) > 1 else 'Unknown'
                    
                    # 自分のデバイスかチェック
                    if 'self' in line.lower() or line.endswith('(self)'):
                        tailscale_ip = ip
                        name = name.replace('(self)', '').strip()
                        devices_data.append({
                            'name': f'{name} (このデバイス)',
                            'ip': ip,
                            'status': 'online'
                        })
                    elif ip:
                        devices_data.append({
                            'name': name,
                            'ip': ip,
                            'status': 'online'
                        })
            
            # 接続品質の簡易判定
            connection_quality = 'good' if connected and tailscale_ip else 'poor'
            
            # システムログの模擬データ
            logs = [
                f'{datetime.now().strftime("%H:%M:%S")} Tailscale status check completed',
                f'{datetime.now().strftime("%H:%M:%S")} Found {len(devices_data)} connected devices',
                f'{datetime.now().strftime("%H:%M:%S")} VPN IP: {tailscale_ip or "N/A"}'
            ]
            
            return jsonify({
                'status': 'connected' if connected else 'disconnected',
                'ip': tailscale_ip,
                'ip_address': tailscale_ip,  # 互換性のため両方提供
                'device_count': len(devices_data),
                'devices': devices_data,
                'connection_quality': connection_quality,
                'logs': logs,
                'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'message': 'Tailscale接続中' if connected else 'Tailscale切断中'
            })
        else:
            return jsonify({
                'status': 'error',
                'ip': None,
                'ip_address': None,
                'device_count': 0,
                'devices': [],
                'connection_quality': 'poor',
                'logs': [
                    f'{datetime.now().strftime("%H:%M:%S")} ERROR: Tailscale command failed',
                    f'{datetime.now().strftime("%H:%M:%S")} {result.stderr.strip() if result.stderr else "Unknown error"}'
                ],
                'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'message': 'Tailscaleコマンドの実行に失敗しました（未インストールの可能性）'
            })
            
    except subprocess.TimeoutExpired:
        return jsonify({
            'status': 'timeout',
            'ip': None,
            'ip_address': None,
            'device_count': 0,
            'devices': [],
            'connection_quality': 'poor',
            'logs': [
                f'{datetime.now().strftime("%H:%M:%S")} ERROR: Tailscale command timed out'
            ],
            'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'message': 'Tailscaleコマンドがタイムアウトしました'
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'ip': None,
            'ip_address': None,
            'device_count': 0,
            'devices': [],
            'connection_quality': 'poor',
            'logs': [
                f'{datetime.now().strftime("%H:%M:%S")} ERROR: {str(e)}'
            ],
            'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'message': f'エラー: {str(e)}'
        })

# ========================================
# 録音機能API
# ========================================

@app.route('/recording')
def recording_page():
    """録音機能画面"""
    return render_template('recording.html')

@app.route('/api/recording/devices')
def api_recording_devices():
    """利用可能な録音デバイス一覧"""
    devices = audio_recorder.get_audio_devices()
    return jsonify({
        'devices': devices,
        'count': len(devices),
        'timestamp': datetime.now().strftime('%H:%M:%S')
    })

@app.route('/api/recording/start', methods=['POST'])
def api_recording_start():
    """録音開始API"""
    try:
        data = request.get_json()
        
        duration = data.get('duration', 10)
        device_id = data.get('device_id', 'default')
        sample_rate = data.get('sample_rate', 44100)
        channels = data.get('channels', 2)
        
        result = audio_recorder.start_recording(
            duration=duration,
            device_id=device_id,
            sample_rate=sample_rate,
            channels=channels
        )
        
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'録音開始エラー: {str(e)}'
        }), 500

@app.route('/api/recording/stop', methods=['POST'])
def api_recording_stop():
    """録音停止API"""
    try:
        result = audio_recorder.stop_recording()
        return jsonify(result)
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'録音停止エラー: {str(e)}'
        }), 500

@app.route('/api/recording/status')
def api_recording_status():
    """録音状態取得API"""
    try:
        status = audio_recorder.get_status()
        return jsonify(status)
    except Exception as e:
        return jsonify({
            'error': f'状態取得エラー: {str(e)}',
            'timestamp': datetime.now().strftime('%H:%M:%S')
        }), 500

@app.route('/api/recording/list')
def api_recording_list():
    """録音ファイル一覧API"""
    try:
        files = audio_recorder.list_recordings()
        return jsonify({
            'files': files,
            'count': len(files),
            'timestamp': datetime.now().strftime('%H:%M:%S')
        })
    except Exception as e:
        return jsonify({
            'error': f'ファイル一覧取得エラー: {str(e)}',
            'files': [],
            'count': 0,
            'timestamp': datetime.now().strftime('%H:%M:%S')
        }), 500

@app.route('/api/recording/download/<filename>')
def api_recording_download(filename):
    """録音ファイルダウンロードAPI"""
    try:
        filepath = audio_recorder.get_file_path(filename)
        if filepath and os.path.exists(filepath):
            return send_file(
                filepath,
                as_attachment=True,
                download_name=filename,
                mimetype='audio/wav'
            )
        else:
            return jsonify({
                'error': 'ファイルが見つかりません'
            }), 404
    except Exception as e:
        return jsonify({
            'error': f'ダウンロードエラー: {str(e)}'
        }), 500

# ========================================
# Google Drive API
# ========================================

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
            if not gdrive_manager._authenticated:
                print("Attempting Google Drive authentication...")
                auth_success = gdrive_manager.authenticate()
                if not auth_success:
                    gdrive_data.update({
                        'status': 'authentication_failed',
                        'message': '認証に失敗しました。credentials.jsonを確認してください。',
                        'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    })
                    return jsonify(gdrive_data)
            
            status = gdrive_manager.check_connection()
            gdrive_data.update(status)
            
        except Exception as e:
            print(f"Google Drive API error: {e}")
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

@app.route('/api/gdrive/test-upload', methods=['POST'])
def api_gdrive_test_upload():
    """Google DriveテストアップロードAPI"""
    if not gdrive_manager:
        return jsonify({
            'success': False,
            'message': 'Google Drive機能が無効です'
        }), 500
    
    try:
        # 設定から録音ディレクトリを取得
        recordings_dir = data_dir / "recordings"
        
        if not os.path.exists(recordings_dir):
            return jsonify({
                'success': False,
                'message': f'録音ディレクトリが見つかりません: {recordings_dir}'
            }), 404
        
        # 録音ファイルを検索（最新の.wavファイル）
        recording_files = []
        for filename in os.listdir(recordings_dir):
            if filename.endswith('.wav'):
                filepath = os.path.join(recordings_dir, filename)
                file_stat = os.stat(filepath)
                recording_files.append({
                    'filename': filename,
                    'filepath': filepath,
                    'size': file_stat.st_size,
                    'mtime': file_stat.st_mtime
                })
        
        if not recording_files:
            return jsonify({
                'success': False,
                'message': 'アップロードする録音ファイルが見つかりません'
            }), 404
        
        # 最新のファイルを選択（更新時刻でソート）
        latest_file = sorted(recording_files, key=lambda x: x['mtime'], reverse=True)[0]
        
        # Google Driveにアップロード
        upload_result = gdrive_manager.upload_file(
            file_path=latest_file['filepath'],
            filename=f"raspi_recording_{latest_file['filename']}"
        )
        
        if upload_result['success']:
            # 最終アップロード情報を更新
            global gdrive_data
            gdrive_data['last_upload'] = {
                'filename': upload_result['filename'],
                'data_type': 'audio/wav',
                'upload_time': upload_result['upload_time'],
                'web_link': upload_result.get('web_link'),
                'file_size': upload_result.get('file_size'),
                'original_file': latest_file['filename']
            }
            
            return jsonify({
                'success': True,
                'message': f"録音ファイル '{latest_file['filename']}' をGoogle Driveにアップロードしました",
                'upload_info': upload_result,
                'original_file': latest_file
            })
        else:
            return jsonify({
                'success': False,
                'message': f"アップロードに失敗しました: {upload_result['message']}"
            }), 500
            
    except Exception as e:
        print(f"Google Drive test upload error: {e}")
        return jsonify({
            'success': False,
            'message': f'テストアップロードエラー: {str(e)}'
        }), 500

@app.route('/api/gdrive/recording-files')
def api_gdrive_recording_files():
    """Google Driveアップロード用録音ファイル一覧API"""
    try:
        recordings_dir = data_dir / "recordings"
        
        if not os.path.exists(recordings_dir):
            return jsonify({
                'files': [],
                'count': 0,
                'message': '録音ディレクトリが見つかりません'
            })
        
        recording_files = []
        for filename in os.listdir(recordings_dir):
            if filename.endswith('.wav'):
                filepath = os.path.join(recordings_dir, filename)
                file_stat = os.stat(filepath)
                recording_files.append({
                    'filename': filename,
                    'size': file_stat.st_size,
                    'created': datetime.fromtimestamp(file_stat.st_ctime).strftime('%Y-%m-%d %H:%M:%S'),
                    'modified': datetime.fromtimestamp(file_stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
                })
        
        # 更新時刻でソート（最新が上）
        recording_files.sort(key=lambda x: x['modified'], reverse=True)
        
        return jsonify({
            'files': recording_files,
            'count': len(recording_files),
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'directory': str(recordings_dir)
        })
        
    except Exception as e:
        print(f"Recording files list error: {e}")
        return jsonify({
            'files': [],
            'count': 0,
            'error': str(e),
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }), 500

@app.route('/api/gdrive/upload-file', methods=['POST'])
def api_gdrive_upload_file():
    """Google Drive指定ファイルアップロードAPI"""
    if not gdrive_manager:
        return jsonify({
            'success': False,
            'message': 'Google Drive機能が無効です'
        }), 500
    
    try:
        data = request.get_json()
        filename = data.get('filename')
        
        if not filename:
            return jsonify({
                'success': False,
                'message': 'ファイル名が指定されていません'
            }), 400
        
        recordings_dir = data_dir / "recordings"
        filepath = os.path.join(recordings_dir, filename)
        
        if not os.path.exists(filepath):
            return jsonify({
                'success': False,
                'message': f'ファイルが見つかりません: {filename}'
            }), 404
        
        # Google Driveにアップロード
        upload_result = gdrive_manager.upload_file(
            file_path=filepath,
            filename=f"raspi_recording_{filename}"
        )
        
        if upload_result['success']:
            # 最終アップロード情報を更新
            global gdrive_data
            gdrive_data['last_upload'] = {
                'filename': upload_result['filename'],
                'data_type': 'audio/wav',
                'upload_time': upload_result['upload_time'],
                'web_link': upload_result.get('web_link'),
                'file_size': upload_result.get('file_size'),
                'original_file': filename
            }
            
            return jsonify({
                'success': True,
                'message': f"録音ファイル '{filename}' をGoogle Driveにアップロードしました",
                'upload_info': upload_result
            })
        else:
            return jsonify({
                'success': False,
                'message': f"アップロードに失敗しました: {upload_result['message']}"
            }), 500
            
    except Exception as e:
        print(f"Google Drive file upload error: {e}")
        return jsonify({
            'success': False,
            'message': f'ファイルアップロードエラー: {str(e)}'
        }), 500

# ========================================
# バックグラウンド処理
# ========================================

def network_monitor_loop():
    """ネットワーク監視ループ"""
    while True:
        try:
            network_monitor.update_data()
            time.sleep(settings.network['update_interval'])
        except Exception as e:
            print(f"Network monitor loop error: {e}")
            time.sleep(5)

def recording_monitor_loop():
    """録音監視ループ"""
    audio_recorder.monitor_recording()

# ========================================
# アプリケーション起動
# ========================================

if __name__ == '__main__':
    print("=" * 50)
    print("🚀 Raspberry Pi モニタリングシステム (モジュラー版)")
    print("=" * 50)
    
    # 設定情報表示
    print(f"📊 設定情報:")
    print(f"  - ネットワーク更新間隔: {settings.network['update_interval']}秒")
    print(f"  - 録音保存先: {audio_recorder.save_directory}")
    print(f"  - Google Drive: {'有効' if gdrive_manager else '無効'}")
    
    # バックグラウンド処理開始
    print("🔄 バックグラウンド処理を開始...")
    
    network_thread = threading.Thread(target=network_monitor_loop, daemon=True)
    network_thread.start()
    
    recording_thread = threading.Thread(target=recording_monitor_loop, daemon=True)
    recording_thread.start()
    
    # アクセス情報表示
    print("🌐 アクセス情報:")
    print(f"  - メインページ（ダッシュボード）: http://localhost:{settings.app['port']}/")
    print(f"  - ネットワークテスト: http://localhost:{settings.app['port']}/network")
    print(f"  - 録音機能: http://localhost:{settings.app['port']}/recording")
    if gdrive_manager:
        print(f"  - Google Drive: http://localhost:{settings.app['port']}/gdrive")
    print("📝 その他の管理ページ:")
    print(f"  - 詳細監視（レガシー）: http://localhost:{settings.app['port']}/network-monitor")
    print(f"  - Tailscale管理: http://localhost:{settings.app['port']}/tailscale")
    print(f"  - Crontab管理: http://localhost:{settings.app['port']}/crontab")
    print(f"  - デバイス管理: http://localhost:{settings.app['port']}/devices")
    print("=" * 50)
    
    # Flaskアプリ開始
    app.run(
        host=settings.app['host'],
        port=settings.app['port'],
        debug=settings.app['debug']
    )
